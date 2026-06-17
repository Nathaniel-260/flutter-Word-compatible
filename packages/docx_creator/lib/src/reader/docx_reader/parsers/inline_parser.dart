import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../../../docx_creator.dart';
import '../../../utils/image_resolver.dart';
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
      {DocxStyle? parentStyle, String? paragraphStyleId}) {
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
          final run = parseRun(child,
              parentStyle: parentStyle, paragraphStyleId: paragraphStyleId);
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
        DocxInline runContent() => content ??= parseRun(child,
            parentStyle: parentStyle, paragraphStyleId: paragraphStyleId);

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
        final inner = parseChildren(child.children,
            parentStyle: parentStyle, paragraphStyleId: paragraphStyleId);
        final node =
            FieldInstruction.parse(instr, cachedText: _cachedText(inner));
        final field = node ?? DocxUnknownField(instr, cachedResult: inner);
        (fieldInstr != null ? cached : children).add(field);
        continue;
      }

      if (local == 'hyperlink') {
        final parsed = _parseHyperlink(child,
            parentStyle: parentStyle, paragraphStyleId: paragraphStyleId);
        (fieldInstr != null ? cached : children).addAll(parsed);
        continue;
      }

      // Track changes: show the final document state. Deleted/moved-from
      // content is dropped; inserted/moved-to content is shown.
      if (local == 'del' || local == 'moveFrom') {
        continue;
      }

      if (['ins', 'moveTo', 'smartTag', 'sdt'].contains(local)) {
        // Handle inline containers (Track Changes, Smart Tags, etc.)
        var contentNodes = child.children;
        if (local == 'sdt') {
          final content = child.findAllElements('w:sdtContent').firstOrNull;
          if (content != null) contentNodes = content.children;
        }
        final parsed = parseChildren(contentNodes,
            parentStyle: parentStyle, paragraphStyleId: paragraphStyleId);
        (fieldInstr != null ? cached : children).addAll(parsed);
        continue;
      }

      // mc:AlternateContent — prefer the modern mc:Choice content, falling back
      // to mc:Fallback so nothing is lost. Match by local name so a non-`mc`
      // namespace prefix still resolves.
      if (local == 'AlternateContent') {
        XmlElement? byLocal(String name) =>
            child.childElements.where((e) => e.name.local == name).firstOrNull;
        final container = byLocal('Choice') ?? byLocal('Fallback');
        if (container != null) {
          final parsed = parseChildren(container.children,
              parentStyle: parentStyle, paragraphStyleId: paragraphStyleId);
          (fieldInstr != null ? cached : children).addAll(parsed);
        }
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
  DocxInline parseRun(XmlElement run,
      {DocxStyle? parentStyle, String? paragraphStyleId}) {
    // Check for line break — מבחין בין מעבר שורה למעבר עמוד (w:type="page").
    final br = run.findAllElements('w:br').firstOrNull;
    if (br != null) {
      final isPage = br.getAttribute('w:type') == 'page';
      return DocxLineBreak(isPageBreak: isPage);
    }
    // w:cr is a hard line break, like a plain w:br.
    if (run.getElement('w:cr') != null) {
      return const DocxLineBreak();
    }
    // Non-breaking / soft hyphen → their Unicode equivalents.
    if (run.getElement('w:noBreakHyphen') != null) {
      return const DocxText('‑');
    }
    if (run.getElement('w:softHyphen') != null) {
      return const DocxText('­');
    }
    // Symbol from a symbol font.
    final sym = run.getElement('w:sym');
    if (sym != null) {
      final charHex = sym.getAttribute('w:char');
      final code = charHex == null ? null : int.tryParse(charHex, radix: 16);
      if (code != null) {
        return DocxSymbol(charCode: code, font: sym.getAttribute('w:font'));
      }
    }
    // Positional tab.
    final ptab = run.getElement('w:ptab');
    if (ptab != null) {
      return DocxPositionalTab(
        alignment:
            DocxTabAlignmentExtension.fromXml(ptab.getAttribute('w:alignment')),
        relativeTo: DocxPtabRelativeToExtension.fromXml(
            ptab.getAttribute('w:relativeTo')),
        leader: DocxTabLeaderExtension.fromXml(ptab.getAttribute('w:leader')),
      );
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

    // Direct run properties (this run's own rPr).
    final parsedProps = DocxStyle.fromXml('temp', rPr: rPr);

    // Resolve the effective run style through the Part B style engine:
    // docDefaults → paragraph-style chain ⊕ character-style chain (cross-level
    // toggle XOR) → direct. Chain handling matches ReaderContext.resolveStyle so
    // non-toggle results are unchanged; the engine adds correct toggle
    // resolution and the rPrDefault base. When only a pre-resolved [parentStyle]
    // is supplied (a legacy/external caller without a styleId) it is folded in
    // as a direct base so such callers keep working. NOTE: in that fallback a
    // run's own character style sits below this direct base rather than above it
    // (the old merge order) — a minor difference affecting external callers only.
    final direct = (paragraphStyleId == null && parentStyle != null)
        ? parentStyle.merge(parsedProps)
        : parsedProps;
    final finalProps = context.styleResolver.resolveRun(
      paragraphStyleId: paragraphStyleId,
      runStyleId: rStyle,
      direct: direct,
    );

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

      // Advanced run properties (A.2), parsed directly from this run's rPr.
      // Full style inheritance of these is Part B's StyleResolver.
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
        rtl: _toggle(rPr, 'w:rtl'),
        boldCs: _toggle(rPr, 'w:bCs'),
        italicCs: _toggle(rPr, 'w:iCs'),
        hidden: readOnOff(rPr?.getElement('w:vanish')),
        fontSizeCs: _halfPointSize(rPr, 'w:szCs'),
        kernMinHalfPoints: _intVal(rPr, 'w:kern'),
        raiseLowerHalfPoints: _intVal(rPr, 'w:position'),
        charScalePercent: _intVal(rPr, 'w:w'),
        fitTextTwips: _intVal(rPr, 'w:fitText'),
        emphasisMark: DocxEmphasisMarkExtension.fromXml(
            rPr?.getElement('w:em')?.getAttribute('w:val')),
      );
    }

    return DocxRawInline(run.toXmlString());
  }

  /// Reads a `CT_OnOff` toggle child of [rPr], or null when the element is
  /// absent (so it can be distinguished from an explicit off).
  static bool? _toggle(XmlElement? rPr, String name) {
    final el = rPr?.getElement(name);
    return el == null ? null : readOnOff(el);
  }

  /// Reads an integer `w:val` from a child element of [rPr] (the `%` suffix on
  /// `w:w` is tolerated).
  static int? _intVal(XmlElement? rPr, String name) {
    final raw = rPr?.getElement(name)?.getAttribute('w:val');
    if (raw == null) return null;
    return int.tryParse(raw.replaceAll('%', '').trim());
  }

  /// Reads a half-point size `w:val` (e.g. `w:szCs`) as points.
  static double? _halfPointSize(XmlElement? rPr, String name) {
    final hp = _intVal(rPr, name);
    return hp == null ? null : hp / 2.0;
  }

  List<DocxInline> _parseHyperlink(XmlElement hyperlink,
      {DocxStyle? parentStyle, String? paragraphStyleId}) {
    final results = <DocxInline>[];
    final rId = hyperlink.getAttribute('r:id');
    String? href;
    if (rId != null) {
      final rel = context.getRelationship(rId);
      if (rel != null) href = rel.target;
    }

    for (var grandChild in hyperlink.findAllElements('w:r')) {
      final run = parseRun(grandChild,
          parentStyle: parentStyle, paragraphStyleId: paragraphStyleId);
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
            } else {
              // VML (`w:pict`) images carry their size in the shape's CSS-like
              // `style` (e.g. width:450pt;height:300pt), not a DrawingML extent.
              final vml = _vmlShapeSize(blip, imageBytes);
              if (vml != null) {
                width = vml.$1;
                height = vml.$2;
              }
            }

            // Determine extension from file path
            String ext = 'png';
            if (target.contains('.')) {
              ext = target.split('.').last.toLowerCase();
            }

            // Drawing transform (Plan §H.3): rotation, mirror, crop. The image's
            // own `a:xfrm` lives in `pic:spPr`; the crop (`a:srcRect`) in
            // `pic:blipFill`. (`a:ext`/`a:off` were already used for the size.)
            final tf = _parseDrawingTransform(drawing);

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
                rotation: tf.rotation,
                flipH: tf.flipH,
                flipV: tf.flipV,
                cropLeft: tf.cropLeft,
                cropTop: tf.cropTop,
                cropRight: tf.cropRight,
                cropBottom: tf.cropBottom,
              );
            }

            // Inline image
            return DocxInlineImage(
              bytes: imageBytes,
              extension: ext,
              width: width,
              height: height,
              positionMode: DocxDrawingPosition.inline,
              rotation: tf.rotation,
              flipH: tf.flipH,
              flipV: tf.flipV,
              cropLeft: tf.cropLeft,
              cropTop: tf.cropTop,
              cropRight: tf.cropRight,
              cropBottom: tf.cropBottom,
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

    // Read fill: a gradient (`a:gradFill`) wins over a solid colour. Scope the
    // search to the shape's own `wsp:spPr` so a fill inside the text body
    // (`w:txbxContent`) is never mistaken for the shape fill.
    final spPr = wsp.findAllElements('wsp:spPr').firstOrNull ?? wsp;
    DocxColor? fillColor;
    DocxGradientFill? gradientFill;
    final gradFill = spPr.findElements('a:gradFill').firstOrNull;
    if (gradFill != null) {
      gradientFill = _parseGradientFill(gradFill);
    }
    if (gradientFill == null) {
      final solidFill = spPr.findElements('a:solidFill').firstOrNull;
      if (solidFill != null) {
        final srgbClr = solidFill.findAllElements('a:srgbClr').firstOrNull;
        final val = srgbClr?.getAttribute('val');
        if (val != null) fillColor = DocxColor(val);
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

    // Read text content. A text box (`wsp:txbx`) carries real block content in
    // `w:txbxContent`; re-enter block parsing so the renderer reproduces its
    // paragraphs/tables (Plan §H). The joined `w:t` string is kept as a flat
    // fallback for simple consumers.
    String? text;
    List<DocxBlock>? textBlocks;
    final txbx = wsp.findAllElements('wsp:txbx').firstOrNull;
    if (txbx != null) {
      final txbxContent = txbx.findAllElements('w:txbxContent').firstOrNull;
      if (txbxContent != null) {
        final blocks = BlockParser(context)
            .parseBlocks(txbxContent.children)
            .whereType<DocxBlock>()
            .toList();
        if (blocks.isNotEmpty) textBlocks = blocks;
      }
      final textContent =
          txbx.findAllElements('w:t').map((t) => t.innerText).join();
      if (textContent.isNotEmpty) {
        text = textContent;
      }
    }

    // Transform (rotation/mirror) from the shape's own `a:xfrm` (in wsp:spPr).
    final tf = _parseDrawingTransform(wsp);

    // Floating anchor placement + wrap mode (Plan §H.1). Previously ignored, so
    // an anchored shape rendered at its default position; now the same anchor
    // model the image branch reads is honoured for shapes too.
    var hFrom = DocxHorizontalPositionFrom.column;
    var vFrom = DocxVerticalPositionFrom.paragraph;
    DrawingHAlign? hAlign;
    DrawingVAlign? vAlign;
    double? hOffset;
    double? vOffset;
    var wrapMode = DocxTextWrap.square;
    var behindDoc = false;
    final anchor = drawingNode.findAllElements('wp:anchor').firstOrNull;
    if (anchor != null) {
      final a = _parseFloatAnchor(anchor);
      hFrom = a.hFrom;
      vFrom = a.vFrom;
      hAlign = a.hAlign;
      vAlign = a.vAlign;
      hOffset = a.hOffset;
      vOffset = a.vOffset;
      wrapMode = a.wrapMode;
      behindDoc = a.behindDoc;
    }

    return DocxShape(
      width: width,
      height: height,
      preset: preset,
      position: position,
      fillColor: fillColor,
      gradientFill: gradientFill,
      outlineColor: outlineColor,
      outlineWidth: outlineWidth,
      text: text,
      textBlocks: textBlocks,
      horizontalFrom: hFrom,
      verticalFrom: vFrom,
      horizontalAlign: hAlign,
      verticalAlign: vAlign,
      horizontalOffset: hOffset,
      verticalOffset: vOffset,
      textWrap: wrapMode,
      behindDocument: behindDoc,
      rotation: tf.rotation,
      flipH: tf.flipH,
      flipV: tf.flipV,
    );
  }

  /// Parses an `a:gradFill` into a [DocxGradientFill]: its `a:gs` stops (pos in
  /// 1/1000 %), and the direction — `a:lin@ang` (1/60000°) for a linear
  /// gradient, or `a:path` for a radial one. Returns null when no usable stop is
  /// found.
  DocxGradientFill? _parseGradientFill(XmlElement gradFill) {
    final stops = <DocxGradientStop>[];
    for (final gs in gradFill.findAllElements('a:gs')) {
      final posRaw = int.tryParse(gs.getAttribute('pos') ?? '');
      final val =
          gs.findAllElements('a:srgbClr').firstOrNull?.getAttribute('val');
      if (posRaw != null && val != null) {
        stops.add(DocxGradientStop(
            position: (posRaw / 100000.0).clamp(0.0, 1.0),
            color: DocxColor(val)));
      }
    }
    if (stops.isEmpty) return null;
    final isRadial = gradFill.findAllElements('a:path').isNotEmpty;
    final angRaw = int.tryParse(
        gradFill.findAllElements('a:lin').firstOrNull?.getAttribute('ang') ??
            '');
    return DocxGradientFill(
      type: isRadial ? DocxGradientType.radial : DocxGradientType.linear,
      angle: angRaw != null ? angRaw / 60000.0 : 0,
      stops: stops,
    );
  }

  /// Parses a drawing's transform (`a:xfrm` rotation/mirror + `a:srcRect` crop)
  /// from an element that contains them (the `pic:pic` for images, the `wsp:wsp`
  /// for shapes). Units: `rot` is 1/60000°, `srcRect` insets are 1/1000 of a
  /// percent → fraction = val / 100000.
  _DrawingTransform _parseDrawingTransform(XmlElement scope) {
    double rotation = 0;
    bool flipH = false, flipV = false;
    final xfrm = scope.findAllElements('a:xfrm').firstOrNull;
    if (xfrm != null) {
      final rot = int.tryParse(xfrm.getAttribute('rot') ?? '');
      if (rot != null) rotation = rot / 60000.0;
      final fh = xfrm.getAttribute('flipH');
      final fv = xfrm.getAttribute('flipV');
      flipH = fh == '1' || fh == 'true';
      flipV = fv == '1' || fv == 'true';
    }

    double cropL = 0, cropT = 0, cropR = 0, cropB = 0;
    final srcRect = scope.findAllElements('a:srcRect').firstOrNull;
    if (srcRect != null) {
      double frac(String name) =>
          (int.tryParse(srcRect.getAttribute(name) ?? '0') ?? 0) / 100000.0;
      cropL = frac('l');
      cropT = frac('t');
      cropR = frac('r');
      cropB = frac('b');
    }

    return _DrawingTransform(
      rotation: rotation,
      flipH: flipH,
      flipV: flipV,
      cropLeft: cropL,
      cropTop: cropT,
      cropRight: cropR,
      cropBottom: cropB,
    );
  }

  /// Parses the placement + wrap of a `wp:anchor` (shared by shapes; the image
  /// branch keeps its own inline parsing for the extra round-trip attributes).
  _FloatAnchor _parseFloatAnchor(XmlElement anchor) {
    var hFrom = DocxHorizontalPositionFrom.column;
    var vFrom = DocxVerticalPositionFrom.paragraph;
    DrawingHAlign? hAlign;
    DrawingVAlign? vAlign;
    double? hOffset;
    double? vOffset;

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
        hAlign = DrawingHAlign.values.firstWhere(
          (e) => e.name == alignNode.innerText,
          orElse: () => DrawingHAlign.left,
        );
      } else {
        final off = posH.findAllElements('wp:posOffset').firstOrNull;
        final val = off == null ? null : int.tryParse(off.innerText);
        if (val != null) hOffset = val / 914400 * 72;
      }
    }

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
        vAlign = DrawingVAlign.values.firstWhere(
          (e) => e.name == alignNode.innerText,
          orElse: () => DrawingVAlign.top,
        );
      } else {
        final off = posV.findAllElements('wp:posOffset').firstOrNull;
        final val = off == null ? null : int.tryParse(off.innerText);
        if (val != null) vOffset = val / 914400 * 72;
      }
    }

    var wrapMode = DocxTextWrap.square;
    if (anchor.findAllElements('wp:wrapNone').isNotEmpty) {
      wrapMode = DocxTextWrap.none;
    } else if (anchor.findAllElements('wp:wrapSquare').isNotEmpty) {
      wrapMode = DocxTextWrap.square;
    } else if (anchor.findAllElements('wp:wrapTight').isNotEmpty) {
      wrapMode = DocxTextWrap.tight;
    } else if (anchor.findAllElements('wp:wrapThrough').isNotEmpty) {
      wrapMode = DocxTextWrap.through;
    } else if (anchor.findAllElements('wp:wrapTopAndBottom').isNotEmpty) {
      wrapMode = DocxTextWrap.topAndBottom;
    }
    final behindDoc = anchor.getAttribute('behindDoc') == '1';
    if (behindDoc) wrapMode = DocxTextWrap.behindText;

    return _FloatAnchor(
      hFrom: hFrom,
      vFrom: vFrom,
      hAlign: hAlign,
      vAlign: vAlign,
      hOffset: hOffset,
      vOffset: vOffset,
      wrapMode: wrapMode,
      behindDoc: behindDoc,
    );
  }

  /// Size (in points) of the VML shape that owns a `v:imagedata` blip, read from
  /// the ancestor `v:shape`/`v:rect` CSS `style` (`width:W;height:H`). VML has no
  /// DrawingML `wp:extent`, so without this a `w:pict` image defaults to 100×100.
  ///
  /// When the style declares only one of width/height, the missing dimension is
  /// derived from the image's intrinsic aspect ratio (via [imageBytes]) so the
  /// picture is not distorted (falling back to a square when the ratio cannot be
  /// read). Returns null when no styled ancestor declares either dimension.
  (double, double)? _vmlShapeSize(XmlElement blip, Uint8List imageBytes) {
    double? w;
    double? h;
    for (XmlNode? n = blip.parent; n != null; n = n.parent) {
      if (n is! XmlElement) continue;
      final style = n.getAttribute('style');
      if (style == null) continue;
      final sw = _cssPoints(style, 'width');
      final sh = _cssPoints(style, 'height');
      // Take both dimensions from the *same* styled ancestor (Word emits
      // `width`+`height` together on the owning `v:shape`); never merge a width
      // from one element with a height from another, unrelated ancestor.
      if (sw != null || sh != null) {
        w = sw;
        h = sh;
        break;
      }
    }
    if (w == null && h == null) return null;
    if (w != null && h != null) return (w, h);

    // One dimension only — scale by the intrinsic aspect ratio.
    final intrinsic = ImageResolver.intrinsicSizePt(imageBytes);
    if (intrinsic != null && intrinsic.$1 > 0 && intrinsic.$2 > 0) {
      final ratio = intrinsic.$1 / intrinsic.$2; // width / height
      if (w != null) return (w, w / ratio);
      return (h! * ratio, h);
    }
    // Unknown ratio: reuse the known dimension for both (square) rather than the
    // 100×100 default, which would ignore the author's explicit size entirely.
    final known = w ?? h!;
    return (known, known);
  }

  /// Extracts a `<prop>:<n><unit>` absolute length from a VML CSS `style` string,
  /// converted to DOCX **points**. Supports the absolute units Word may emit
  /// (`pt`/`px`/`in`/`cm`/`mm`/`pc`); relative units (`em`/`ex`/`%`) and `auto`
  /// match nothing → null, so the caller keeps its fallback.
  double? _cssPoints(String style, String prop) {
    final m =
        RegExp('(?:^|;)\\s*$prop\\s*:\\s*([0-9.]+)\\s*(pt|px|in|cm|mm|pc)')
            .firstMatch(style.toLowerCase());
    if (m == null) return null;
    final value = double.tryParse(m.group(1)!);
    if (value == null) return null;
    return switch (m.group(2)!) {
      'pt' => value,
      'px' => value * 72.0 / 96.0, // CSS px (96 DPI) → pt (72 DPI)
      'in' => value * 72.0,
      'cm' => value * 72.0 / 2.54,
      'mm' => value * 72.0 / 25.4,
      'pc' => value * 12.0, // 1 pica = 12 pt
      _ => null,
    };
  }
}

/// Parsed drawing transform (rotation/mirror/crop) — see [_parseDrawingTransform].
class _DrawingTransform {
  const _DrawingTransform({
    required this.rotation,
    required this.flipH,
    required this.flipV,
    required this.cropLeft,
    required this.cropTop,
    required this.cropRight,
    required this.cropBottom,
  });
  final double rotation;
  final bool flipH;
  final bool flipV;
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;
}

/// Parsed floating-anchor placement + wrap — see [_parseFloatAnchor].
class _FloatAnchor {
  const _FloatAnchor({
    required this.hFrom,
    required this.vFrom,
    required this.hAlign,
    required this.vAlign,
    required this.hOffset,
    required this.vOffset,
    required this.wrapMode,
    required this.behindDoc,
  });
  final DocxHorizontalPositionFrom hFrom;
  final DocxVerticalPositionFrom vFrom;
  final DrawingHAlign? hAlign;
  final DrawingVAlign? vAlign;
  final double? hOffset;
  final double? vOffset;
  final DocxTextWrap wrapMode;
  final bool behindDoc;
}
