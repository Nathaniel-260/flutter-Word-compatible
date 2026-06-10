import 'package:xml/xml.dart';

import '../../../../docx_creator.dart';
import 'field_instruction.dart';

/// Parses inline content (runs, text, hyperlinks, fields, bookmarks).
class InlineParser {
  /// The context for the current reader session.
  final ReaderContext context;

  /// Creates an [InlineParser] with the specified [context].
  InlineParser(this.context);

  /// Parse inline children from a container element.
  ///
  /// Handles Word complex fields, which span several sibling `w:r` elements
  /// (`fldChar begin → instrText… → separate → result… → end`) as well as the
  /// simple `w:fldSimple` form, collapsing each into a single field node.
  List<DocxInline> parseChildren(Iterable<XmlNode> nodes,
      {DocxStyle? parentStyle}) {
    final children = <DocxInline>[];

    // Complex-field accumulator. Non-null instruction = currently inside a
    // field. `depth` tracks nested fields (e.g. a field inside another field's
    // result) so only the outermost begin/end drive finalization.
    StringBuffer? fieldInstr;
    var inResult = false;
    var depth = 0;
    final cached = <DocxInline>[];

    void finalizeField() {
      final instr = fieldInstr!.toString();
      final node =
          FieldInstruction.parse(instr, cachedText: _cachedText(cached));
      children
          .add(node ?? DocxUnknownField(instr, cachedResult: List.of(cached)));
      fieldInstr = null;
      inResult = false;
      cached.clear();
    }

    for (var child in nodes) {
      if (child is! XmlElement) continue;
      final local = child.name.local;

      if (local == 'bookmarkStart') {
        final name = child.getAttribute('w:name');
        // _GoBack is Word's invisible "return to last edit" bookmark — skip it.
        if (name != null && name.isNotEmpty && name != '_GoBack') {
          children.add(DocxBookmark(name));
        }
        continue;
      }
      if (local == 'bookmarkEnd') continue;

      if (local == 'r') {
        // Word may pack a whole field (begin/instrText/separate/end) into a
        // single run, or split it across runs. Walk the run's children in
        // document order so both forms work. A run with no field-control
        // children is handled as a single unit (its content parsed once).
        final hasFieldControl = child.getElement('w:fldChar') != null ||
            child.getElement('w:instrText') != null;

        if (!hasFieldControl) {
          final run = parseRun(child, parentStyle: parentStyle);
          if (fieldInstr == null) {
            children.add(run);
          } else if (inResult || depth > 0) {
            cached.add(run); // cached result content (in its own run)
          }
          // else: a content run inside the instruction region — ignored.
          continue;
        }

        // Field-control run: the run's textual content (if any) is parsed once
        // (parseRun already merges a run's w:t children) and attached at the
        // point it first appears in the child order.
        DocxInline? content;
        var contentAttached = false;
        DocxInline runContent() =>
            content ??= parseRun(child, parentStyle: parentStyle);

        for (final rc in child.children.whereType<XmlElement>()) {
          switch (rc.name.local) {
            case 'fldChar':
              final t = rc.getAttribute('w:fldCharType');
              if (t == 'begin') {
                if (fieldInstr != null) {
                  depth++; // nested field — swallowed into the outer result
                } else {
                  fieldInstr = StringBuffer();
                  inResult = false;
                  cached.clear();
                }
              } else if (t == 'separate') {
                if (fieldInstr != null && depth == 0) inResult = true;
              } else if (t == 'end') {
                if (fieldInstr != null) {
                  if (depth > 0) {
                    depth--;
                  } else {
                    finalizeField();
                  }
                }
              }
              break;
            case 'instrText':
              if (fieldInstr != null && depth == 0 && !inResult) {
                fieldInstr!.write(rc.innerText);
              }
              break;
            case 'rPr':
              break; // run properties — not content
            default:
              // Content (w:t / w:br / w:tab / w:drawing / …); parseRun already
              // merged the run's content, so attach it at most once.
              if (contentAttached) break;
              contentAttached = true;
              if (fieldInstr == null) {
                children.add(runContent());
              } else if (inResult || depth > 0) {
                cached.add(runContent());
              }
              // else: instruction region — ignored.
              break;
          }
        }
        continue;
      }

      if (local == 'fldSimple') {
        final instr = child.getAttribute('w:instr') ?? '';
        final inner = parseChildren(child.children, parentStyle: parentStyle);
        final node =
            FieldInstruction.parse(instr, cachedText: _cachedText(inner));
        final field = node ?? DocxUnknownField(instr, cachedResult: inner);
        (fieldInstr != null ? cached : children).add(field);
        continue;
      }

      if (local == 'hyperlink') {
        final parsed = _parseHyperlink(child, parentStyle: parentStyle);
        (fieldInstr != null ? cached : children).addAll(parsed);
        continue;
      }

      if (['ins', 'del', 'smartTag', 'sdt'].contains(local)) {
        // Handle inline containers (Track Changes, Smart Tags, etc.)
        var contentNodes = child.children;
        if (local == 'sdt') {
          final content = child.findAllElements('w:sdtContent').firstOrNull;
          if (content != null) contentNodes = content.children;
        }
        final parsed = parseChildren(contentNodes, parentStyle: parentStyle);
        (fieldInstr != null ? cached : children).addAll(parsed);
        continue;
      }
    }

    // Unterminated field (malformed XML): don't lose its result text.
    if (fieldInstr != null) children.addAll(cached);

    return children;
  }

  /// Concatenated visible text of [inlines], used as a field's cached value.
  /// Only [DocxText] contributes — line breaks/tabs in a cached result are not
  /// meaningful for a page-number value, which is the only thing we display.
  static String? _cachedText(List<DocxInline> inlines) {
    final buf = StringBuffer();
    for (final inline in inlines) {
      if (inline is DocxText) buf.write(inline.content);
    }
    final text = buf.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Parse a single run (w:r) element.
  DocxInline parseRun(XmlElement run, {DocxStyle? parentStyle}) {
    // Check for line break — מבחין בין מעבר שורה למעבר עמוד (w:type="page").
    final br = run.findAllElements('w:br').firstOrNull;
    if (br != null) {
      final isPage = br.getAttribute('w:type') == 'page';
      return DocxLineBreak(isPageBreak: isPage);
    }
    // Check for tab
    if (run.findAllElements('w:tab').isNotEmpty) {
      return const DocxTab();
    }

    // Check for drawings (handled separately by MediaHandler)
    final drawing = run.findAllElements('w:drawing').firstOrNull ??
        run.findAllElements('w:pict').firstOrNull;
    if (drawing != null) {
      // Return placeholder - actual parsing done by MediaHandler
      return _parseDrawing(drawing);
    }

    // Check for footnote reference
    final footnoteRef = run.findAllElements('w:footnoteReference').firstOrNull;
    if (footnoteRef != null) {
      final idAttr = footnoteRef.getAttribute('w:id');
      final id = int.tryParse(idAttr ?? '0') ?? 0;
      return DocxFootnoteRef(footnoteId: id);
    }

    // Check for endnote reference
    final endnoteRef = run.findAllElements('w:endnoteReference').firstOrNull;
    if (endnoteRef != null) {
      final idAttr = endnoteRef.getAttribute('w:id');
      final id = int.tryParse(idAttr ?? '0') ?? 0;
      return DocxEndnoteRef(endnoteId: id);
    }

    // Parse formatting
    final rPr = run.getElement('w:rPr');
    String? rStyle;
    if (rPr != null) {
      final rStyleElem = rPr.getElement('w:rStyle');
      if (rStyleElem != null) {
        rStyle = rStyleElem.getAttribute('w:val');
      }
    }

    // 1. Base style = Parent Paragraph Style (if any) or Default
    var baseStyle = parentStyle ?? context.resolveStyle('DefaultParagraphFont');

    // 2. Run Style (Character Style) - Overrides paragraph style properties
    if (rStyle != null) {
      final cStyle = context.resolveStyle(rStyle);
      baseStyle = baseStyle.merge(cStyle);
    }

    // 3. Direct Properties - Parse directly from XML (these are explicit)
    final parsedProps = DocxStyle.fromXml('temp', rPr: rPr);

    // 4. Merged properties for formatting checks (bold, italic, etc.)
    final finalProps = baseStyle.merge(parsedProps);

    // Extract text
    final textElem = run.getElement('w:t');
    if (textElem != null) {
      // IMPORTANT: Only use DIRECT properties for font-related output
      // This ensures we don't override table style inheritance
      // Font properties should only be emitted if they were explicitly set in source
      final directFontSize = parsedProps.fontSize;
      final directFonts = parsedProps.fonts;
      final directFontFamily = parsedProps.fontFamily;
      final directColor = parsedProps.color;

      // For fonts: use direct if specified, otherwise use inherited from style
      final effectiveFonts = directFonts ?? finalProps.fonts;
      final effectiveFontFamily = directFontFamily ?? finalProps.fontFamily;

      final effectiveColor = directColor ?? finalProps.color;

      return DocxText(
        textElem.innerText,
        fontWeight: finalProps.fontWeight ?? DocxFontWeight.normal,
        fontStyle: finalProps.fontStyle ?? DocxFontStyle.normal,
        decorations: finalProps.decorations,
        underlineStyle: finalProps.underlineStyle,
        underlineColor: finalProps.underlineColor,
        color: effectiveColor,
        shadingFill: parsedProps.shadingFill, // Only direct shading
        fontSize: directFontSize ??
            finalProps.fontSize, // Use inherited if not direct
        fontFamily: effectiveFontFamily, // Use inherited if not direct
        fonts: effectiveFonts, // Use inherited if not direct
        highlight: finalProps.highlight ?? DocxHighlight.none,
        isSuperscript: finalProps.isSuperscript ?? false,
        isSubscript: finalProps.isSubscript ?? false,
        isAllCaps: finalProps.isAllCaps ?? false,
        isSmallCaps: finalProps.isSmallCaps ?? false,
        isDoubleStrike: finalProps.isDoubleStrike ?? false,
        isOutline: finalProps.isOutline ?? false,
        isShadow: finalProps.isShadow ?? false,
        isEmboss: finalProps.isEmboss ?? false,
        isImprint: finalProps.isImprint ?? false,
        textBorder: finalProps.textBorder,
        themeColor: effectiveColor?.themeColor,
        themeTint: effectiveColor?.themeTint,
        themeShade: effectiveColor?.themeShade,
        themeFill: parsedProps.themeFill,
        themeFillTint: parsedProps.themeFillTint,
        themeFillShade: parsedProps.themeFillShade,
        characterSpacing: finalProps.characterSpacing,
      );
    }

    return DocxRawInline(run.toXmlString());
  }

  List<DocxInline> _parseHyperlink(XmlElement hyperlink,
      {DocxStyle? parentStyle}) {
    final results = <DocxInline>[];
    final rId = hyperlink.getAttribute('r:id');
    String? href;
    if (rId != null) {
      final rel = context.getRelationship(rId);
      if (rel != null) href = rel.target;
    }

    for (var grandChild in hyperlink.findAllElements('w:r')) {
      final run = parseRun(grandChild, parentStyle: parentStyle);
      if (run is DocxText && href != null) {
        final newDecorations = List<DocxTextDecoration>.from(run.decorations);
        if (!newDecorations.contains(DocxTextDecoration.underline)) {
          newDecorations.add(DocxTextDecoration.underline);
        }
        results.add(run.copyWith(
          href: href,
          decorations: newDecorations,
          color: DocxColor.blue,
        ));
      } else {
        results.add(run);
      }
    }
    return results;
  }

  DocxInline _parseDrawing(XmlElement drawing) {
    // Detect if this is floating/anchored
    final isAnchor = drawing.findAllElements('wp:anchor').isNotEmpty;

    // Check for image
    final blip = drawing.findAllElements('a:blip').firstOrNull ??
        drawing.findAllElements('v:imagedata').firstOrNull;
    if (blip != null) {
      final embedId = blip.getAttribute('r:embed') ?? blip.getAttribute('r:id');
      if (embedId != null) {
        final rel = context.getRelationship(embedId);
        if (rel != null) {
          // Read image from archive
          String target = rel.target;
          if (!target.startsWith('/')) target = 'word/$target';
          final imageBytes = context.readBytes(target);
          if (imageBytes != null) {
            // Get dimensions
            double width = 100, height = 100;
            final extent = drawing.findAllElements('wp:extent').firstOrNull ??
                drawing.findAllElements('a:ext').firstOrNull;
            if (extent != null) {
              final cx = extent.getAttribute('cx');
              final cy = extent.getAttribute('cy');
              if (cx != null) width = int.parse(cx) / 914400 * 72;
              if (cy != null) height = int.parse(cy) / 914400 * 72;
            }

            // Determine extension from file path
            String ext = 'png';
            if (target.contains('.')) {
              ext = target.split('.').last.toLowerCase();
            }

            // Parse floating image properties if anchored
            if (isAnchor) {
              final anchor = drawing.findAllElements('wp:anchor').first;

              // ============================================================
              // True-Fidelity: Parse all anchor-level attributes
              // ============================================================
              final distT =
                  int.tryParse(anchor.getAttribute('distT') ?? '0') ?? 0;
              final distB =
                  int.tryParse(anchor.getAttribute('distB') ?? '0') ?? 0;
              final distL =
                  int.tryParse(anchor.getAttribute('distL') ?? '114300') ??
                      114300;
              final distR =
                  int.tryParse(anchor.getAttribute('distR') ?? '114300') ??
                      114300;
              final simplePos = anchor.getAttribute('simplePos') == '1';
              final relativeHeight = int.tryParse(
                      anchor.getAttribute('relativeHeight') ?? '251658240') ??
                  251658240;
              final locked = anchor.getAttribute('locked') == '1';
              final layoutInCell = anchor.getAttribute('layoutInCell') != '0';
              final allowOverlap = anchor.getAttribute('allowOverlap') != '0';

              // Parse effect extent
              int effectExtentL = 0, effectExtentT = 0;
              int effectExtentR = 0, effectExtentB = 0;
              final effectExtent =
                  anchor.findAllElements('wp:effectExtent').firstOrNull;
              if (effectExtent != null) {
                effectExtentL =
                    int.tryParse(effectExtent.getAttribute('l') ?? '0') ?? 0;
                effectExtentT =
                    int.tryParse(effectExtent.getAttribute('t') ?? '0') ?? 0;
                effectExtentR =
                    int.tryParse(effectExtent.getAttribute('r') ?? '0') ?? 0;
                effectExtentB =
                    int.tryParse(effectExtent.getAttribute('b') ?? '0') ?? 0;
              }

              // Capture unknown attributes for round-trip
              const knownAnchorAttrs = {
                'distT',
                'distB',
                'distL',
                'distR',
                'simplePos',
                'relativeHeight',
                'behindDoc',
                'locked',
                'layoutInCell',
                'allowOverlap',
              };
              final anchorExtensions = XmlExtensionMap.extractFromElement(
                anchor,
                knownAttributes: knownAnchorAttrs,
              );

              // Parse horizontal position
              double? hOffset;
              DrawingHAlign? hAlign;
              DocxHorizontalPositionFrom hFrom =
                  DocxHorizontalPositionFrom.column;
              final posH = anchor.findAllElements('wp:positionH').firstOrNull;
              if (posH != null) {
                final rel = posH.getAttribute('relativeFrom');
                if (rel != null) {
                  hFrom = DocxHorizontalPositionFrom.values.firstWhere(
                    (e) => e.name == rel,
                    orElse: () => DocxHorizontalPositionFrom.column,
                  );
                }

                final alignNode = posH.findAllElements('wp:align').firstOrNull;
                if (alignNode != null) {
                  final val = alignNode.innerText;
                  hAlign = DrawingHAlign.values.firstWhere(
                    (e) => e.name == val,
                    orElse: () => DrawingHAlign.left,
                  );
                } else {
                  final posOffset =
                      posH.findAllElements('wp:posOffset').firstOrNull;
                  if (posOffset != null) {
                    final val = int.tryParse(posOffset.innerText);
                    if (val != null) hOffset = val / 914400 * 72;
                  }
                }
              }

              // Parse vertical position
              double? vOffset;
              DrawingVAlign? vAlign;
              DocxVerticalPositionFrom vFrom =
                  DocxVerticalPositionFrom.paragraph;
              final posV = anchor.findAllElements('wp:positionV').firstOrNull;
              if (posV != null) {
                final rel = posV.getAttribute('relativeFrom');
                if (rel != null) {
                  vFrom = DocxVerticalPositionFrom.values.firstWhere(
                    (e) => e.name == rel,
                    orElse: () => DocxVerticalPositionFrom.paragraph,
                  );
                }

                final alignNode = posV.findAllElements('wp:align').firstOrNull;
                if (alignNode != null) {
                  final val = alignNode.innerText;
                  vAlign = DrawingVAlign.values.firstWhere(
                    (e) => e.name == val,
                    orElse: () => DrawingVAlign.top,
                  );
                } else {
                  final posOffset =
                      posV.findAllElements('wp:posOffset').firstOrNull;
                  if (posOffset != null) {
                    final val = int.tryParse(posOffset.innerText);
                    if (val != null) vOffset = val / 914400 * 72;
                  }
                }
              }

              // Parse wrap mode
              DocxTextWrap wrapMode = DocxTextWrap.square;
              if (anchor.findAllElements('wp:wrapNone').isNotEmpty) {
                wrapMode = DocxTextWrap.none;
              } else if (anchor.findAllElements('wp:wrapSquare').isNotEmpty) {
                wrapMode = DocxTextWrap.square;
              } else if (anchor.findAllElements('wp:wrapTight').isNotEmpty) {
                wrapMode = DocxTextWrap.tight;
              } else if (anchor.findAllElements('wp:wrapThrough').isNotEmpty) {
                wrapMode = DocxTextWrap.through;
              } else if (anchor
                  .findAllElements('wp:wrapTopAndBottom')
                  .isNotEmpty) {
                wrapMode = DocxTextWrap.topAndBottom;
              }

              // Check if behind text
              final behindDoc = anchor.getAttribute('behindDoc') == '1';
              if (behindDoc) {
                wrapMode = DocxTextWrap.behindText;
              }

              // Extract real alt text (descr attributes)
              String? altText;
              final docPr = drawing.findAllElements('wp:docPr').firstOrNull ??
                  drawing.findAllElements('pic:cNvPr').firstOrNull;
              if (docPr != null) {
                altText =
                    docPr.getAttribute('descr') ?? docPr.getAttribute('name');
              }

              return DocxInlineImage(
                bytes: imageBytes,
                extension: ext,
                width: width,
                height: height,
                altText: altText,
                positionMode: isAnchor
                    ? DocxDrawingPosition.floating
                    : DocxDrawingPosition.inline,
                textWrap: wrapMode,
                x: hOffset,
                y: vOffset,
                hAlign: hAlign,
                vAlign: vAlign,
                hPositionFrom: hFrom,
                vPositionFrom: vFrom,
                // True-Fidelity attributes
                distT: distT,
                distB: distB,
                distL: distL,
                distR: distR,
                simplePos: simplePos,
                relativeHeight: relativeHeight,
                locked: locked,
                layoutInCell: layoutInCell,
                allowOverlap: allowOverlap,
                effectExtentL: effectExtentL,
                effectExtentT: effectExtentT,
                effectExtentR: effectExtentR,
                effectExtentB: effectExtentB,
                anchorExtensions:
                    anchorExtensions.isEmpty ? null : anchorExtensions,
              );
            }

            // Inline image
            return DocxInlineImage(
              bytes: imageBytes,
              extension: ext,
              width: width,
              height: height,
              positionMode: DocxDrawingPosition.inline,
            );
          }
        }
      }
    }

    // Check for shape
    final wsp = drawing.findAllElements('wsp:wsp').firstOrNull;
    if (wsp != null) {
      return _parseShape(drawing, wsp);
    }

    // Fallback
    return DocxRawInline(drawing.toXmlString());
  }

  DocxShape _parseShape(XmlElement drawingNode, XmlElement wsp) {
    // Determine position mode (inline vs floating)
    final isInline = drawingNode.findAllElements('wp:inline').isNotEmpty;
    final position =
        isInline ? DocxDrawingPosition.inline : DocxDrawingPosition.floating;

    // Read dimensions from extent (1 pt = 12700 EMU)
    double width = 100;
    double height = 100;
    final extent = drawingNode.findAllElements('wp:extent').firstOrNull;
    if (extent != null) {
      final cx = int.tryParse(extent.getAttribute('cx') ?? '');
      final cy = int.tryParse(extent.getAttribute('cy') ?? '');
      if (cx != null && cy != null) {
        width = cx / 12700.0;
        height = cy / 12700.0;
      }
    }

    // Read preset geometry
    var preset = DocxShapePreset.rect;
    final prstGeom = wsp.findAllElements('a:prstGeom').firstOrNull;
    if (prstGeom != null) {
      final prstName = prstGeom.getAttribute('prst');
      if (prstName != null) {
        for (var p in DocxShapePreset.values) {
          if (p.name == prstName) {
            preset = p;
            break;
          }
        }
      }
    }

    // Read fill color
    DocxColor? fillColor;
    final solidFill = wsp.findAllElements('a:solidFill').firstOrNull;
    if (solidFill != null) {
      final srgbClr = solidFill.findAllElements('a:srgbClr').firstOrNull;
      if (srgbClr != null) {
        final val = srgbClr.getAttribute('val');
        if (val != null) {
          fillColor = DocxColor(val);
        }
      }
    }

    // Read outline color and width
    DocxColor? outlineColor;
    double outlineWidth = 1;
    final ln = wsp.findAllElements('a:ln').firstOrNull;
    if (ln != null) {
      final wAttr = ln.getAttribute('w');
      if (wAttr != null) {
        final wEmu = int.tryParse(wAttr);
        if (wEmu != null) {
          outlineWidth = wEmu / 12700.0;
        }
      }
      final lnFill = ln.findAllElements('a:solidFill').firstOrNull;
      if (lnFill != null) {
        final srgbClr = lnFill.findAllElements('a:srgbClr').firstOrNull;
        if (srgbClr != null) {
          final val = srgbClr.getAttribute('val');
          if (val != null) {
            outlineColor = DocxColor(val);
          }
        }
      }
    }

    // Read text content
    String? text;
    final txbx = wsp.findAllElements('wsp:txbx').firstOrNull;
    if (txbx != null) {
      final textContent =
          txbx.findAllElements('w:t').map((t) => t.innerText).join();
      if (textContent.isNotEmpty) {
        text = textContent;
      }
    }

    return DocxShape(
      width: width,
      height: height,
      preset: preset,
      position: position,
      fillColor: fillColor,
      outlineColor: outlineColor,
      outlineWidth: outlineWidth,
      text: text,
    );
  }
}
