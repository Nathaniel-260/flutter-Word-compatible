import 'package:docx_creator/docx_creator.dart';

import 'docx_export_state.dart';

/// Pre-processes the document before generation to collect and catalogue items
/// like images, bullet lists, fonts, and sets up appropriate counters/IDs.
class DocxCollectionManager {
  static void collect(DocxExportState state) {
    // Register document fonts
    for (final font in state.doc.fonts) {
      state.fontManager.registerFont(font);
    }

    // Process background image
    if (state.doc.section?.backgroundImage != null) {
      state.backgroundImage = state.doc.section!.backgroundImage;
      state.backgroundImage!.setRelationshipId('rIdBg');
      final ext = state.backgroundImage!.normalizedExtension;
      state.images['word/media/background.$ext'] = state.backgroundImage!.bytes;
    }

    // Collect hyperlinks and assign relationship IDs
    _collectHyperlinks(state);

    // Process images recursively
    _collectImagesGrouped(state);

    final allImages = <DocxInlineImage>{
      ...state.groupedImages['body']!,
      ...state.groupedImages['header']!,
      ...state.groupedImages['footer']!,
    };

    for (final img in allImages) {
      state.imageCounter++;
      final rId = 'rId${state.imageCounter + 10}';
      img.setRelationshipId(rId, state.uniqueIdCounter++);
      final mediaPath =
          'word/media/image${state.imageCounter}.${img.extension}';
      state.imageMediaPaths[img] = mediaPath;
      state.images[mediaPath] = img.bytes;
    }

    // Process lists recursively
    _collectLists(state);
  }

  static void _collectImagesGrouped(DocxExportState state) {
    final bodyImages = <DocxInlineImage>[];
    final headerImages = <DocxInlineImage>[];
    final footerImages = <DocxInlineImage>[];

    for (final element in state.doc.elements) {
      _collectImagesFromNode(element, bodyImages);
    }
    if (state.doc.section?.header != null) {
      for (final child in state.doc.section!.header!.children) {
        _collectImagesFromNode(child, headerImages);
      }
    }
    if (state.doc.section?.footer != null) {
      for (final child in state.doc.section!.footer!.children) {
        _collectImagesFromNode(child, footerImages);
      }
    }

    state.groupedImages = {
      'body': bodyImages,
      'header': headerImages,
      'footer': footerImages,
    };
  }

  static void _collectImagesFromNode(
      DocxNode node, List<DocxInlineImage> images) {
    if (node is DocxImage) {
      images.add(node.asInline);
    } else if (node is DocxInlineImage) {
      images.add(node);
    } else if (node is DocxParagraph) {
      for (final child in node.children) {
        _collectImagesFromNode(child, images);
      }
    } else if (node is DocxTable) {
      for (final row in node.rows) {
        for (final cell in row.cells) {
          for (final child in cell.children) {
            _collectImagesFromNode(child, images);
          }
        }
      }
    } else if (node is DocxList) {
      for (final item in node.items) {
        for (final child in item.children) {
          _collectImagesFromNode(child, images);
        }
      }
    } else if (node is DocxHeader) {
      for (final child in node.children) {
        _collectImagesFromNode(child, images);
      }
    } else if (node is DocxFooter) {
      for (final child in node.children) {
        _collectImagesFromNode(child, images);
      }
    }
  }

  static void _collectLists(DocxExportState state) {
    final allLists = <DocxList>[];
    for (final element in state.doc.elements) {
      _collectListsFromNode(element, allLists);
    }
    if (state.doc.section?.header != null) {
      for (final child in state.doc.section!.header!.children) {
        _collectListsFromNode(child, allLists);
      }
    }
    if (state.doc.section?.footer != null) {
      for (final child in state.doc.section!.footer!.children) {
        _collectListsFromNode(child, allLists);
      }
    }

    int abstractNumIdCounter = 2; // 0 and 1 are reserved for default styles

    for (final list in allLists) {
      int exportedNumId;
      final sourceNumId = list.numId;

      if (sourceNumId != null &&
          state.preservedNumIds.containsKey(sourceNumId)) {
        // Reuse existing exported ID for continuity
        exportedNumId = state.preservedNumIds[sourceNumId]!;
      } else {
        // Create new exported ID
        exportedNumId = state.numIdCounter++;
        if (sourceNumId != null) {
          state.preservedNumIds[sourceNumId] = exportedNumId;
        }

        if (list.style.imageBulletBytes != null) {
          // Image Bullet List
          final bulletIndex = state.imageBullets.length;
          state.imageBullets.add(list.style.imageBulletBytes!);

          final absId = abstractNumIdCounter++;
          state.abstractNumImageBulletMap[absId] = bulletIndex;
          state.listAbstractNumMap[exportedNumId] = absId;
        } else if (list.items.any((it) => it.overrideStyle != null)) {
          // Mixed list: ordered and unordered levels coexist (e.g. a numbered
          // sub-list nested in a bulleted one). Each level needs its own format,
          // so build a dedicated per-level abstractNum.
          final absId = abstractNumIdCounter++;
          state.mixedAbstractLevelStyles[absId] = _buildMixedLevelStyles(list);
          state.listAbstractNumMap[exportedNumId] = absId;
          if (list.isOrdered && list.startIndex > 1) {
            state.listStartOverrides[exportedNumId] = list.startIndex;
          }
        } else if (_isCustomListStyle(list.style, list.isOrdered)) {
          // Custom bullet char or number format: needs its own abstractNum
          final absId = abstractNumIdCounter++;
          state.customAbstractStyles[absId] = list.style;
          state.customAbstractIsOrdered[absId] = list.isOrdered;
          state.listAbstractNumMap[exportedNumId] = absId;
          if (list.isOrdered && list.startIndex > 1) {
            state.listStartOverrides[exportedNumId] = list.startIndex;
          }
        } else {
          // Standard List
          state.listAbstractNumMap[exportedNumId] = list.isOrdered ? 1 : 0;
          // Only apply start override if this is the start of the chain (new ID)
          if (list.isOrdered && list.startIndex > 1) {
            state.listStartOverrides[exportedNumId] = list.startIndex;
          }
        }
      }

      // Note: We mutate DocxBuiltDocument.list.numId here during the export process.
      // If immutability is required in the future, this should be refactored to clone the list.
      list.numId = exportedNumId;
    }
  }

  // ---------------------------------------------------------------------------
  // Hyperlink collection
  // ---------------------------------------------------------------------------

  static void _collectHyperlinks(DocxExportState state) {
    final texts = <DocxText>[];

    for (final el in state.doc.elements) {
      _collectHyperlinksFromNode(el, texts);
    }
    if (state.doc.section?.header != null) {
      for (final c in state.doc.section!.header!.children) {
        _collectHyperlinksFromNode(c, texts);
      }
    }
    if (state.doc.section?.footer != null) {
      for (final c in state.doc.section!.footer!.children) {
        _collectHyperlinksFromNode(c, texts);
      }
    }

    int counter = 1;
    for (final text in texts) {
      final href = text.href!;
      if (!state.hyperlinkRelIds.containsKey(href)) {
        state.hyperlinkRelIds[href] = 'rIdHyperlink$counter';
        counter++;
      }
    }
  }

  static void _collectHyperlinksFromNode(DocxNode node, List<DocxText> texts) {
    if (node is DocxText && node.isLink) {
      texts.add(node);
    } else if (node is DocxParagraph) {
      for (final child in node.children) {
        _collectHyperlinksFromNode(child, texts);
      }
    } else if (node is DocxTable) {
      for (final row in node.rows) {
        for (final cell in row.cells) {
          for (final child in cell.children) {
            _collectHyperlinksFromNode(child, texts);
          }
        }
      }
    } else if (node is DocxList) {
      for (final item in node.items) {
        for (final child in item.children) {
          _collectHyperlinksFromNode(child, texts);
        }
      }
    } else if (node is DocxHeader) {
      for (final child in node.children) {
        _collectHyperlinksFromNode(child, texts);
      }
    } else if (node is DocxFooter) {
      for (final child in node.children) {
        _collectHyperlinksFromNode(child, texts);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Custom list style detection
  // ---------------------------------------------------------------------------

  static const _defaultListStyle = DocxListStyle();

  static bool _isCustomListStyle(DocxListStyle style, bool isOrdered) {
    const ref = _defaultListStyle;
    final hasCustomFormatting = style.fontFamily != null ||
        style.fontSize != null ||
        style.fontWeight != ref.fontWeight ||
        style.color != ref.color ||
        style.indentPerLevel != ref.indentPerLevel ||
        style.hangingIndent != ref.hangingIndent;
    if (isOrdered) {
      return hasCustomFormatting || style.numberFormat != ref.numberFormat;
    } else {
      return hasCustomFormatting || style.bullet != ref.bullet;
    }
  }

  /// Resolves the format for each of levels 0..8 of a mixed list, honoring a
  /// per-item [DocxListItem.overrideStyle] when present and otherwise falling
  /// back to the list's own ordering. Ordered levels using the default decimal
  /// format cascade by depth (decimal → lowerAlpha → lowerRoman), matching the
  /// viewer and the standard numbering definition.
  ///
  /// Known limitation: an OOXML `abstractNum` defines exactly one format per
  /// `ilvl`, so this collapses a level to a single format. If two sibling
  /// sub-lists of *different* kinds occupy the *same* nesting level under one
  /// parent (e.g. both a numbered and a bulleted sub-list at level 1), the
  /// first-seen override wins for that level in the exported DOCX. The viewer
  /// renders each item correctly (it is per-item), so the two can diverge in
  /// that rare case. Fully fixing it would require splitting such sub-lists into
  /// separate `numId`s instead of flattening into one list.
  static List<DocxListStyle> _buildMixedLevelStyles(DocxList list) {
    final overrideByLevel = <int, DocxListStyle>{};
    for (final item in list.items) {
      if (item.overrideStyle != null) {
        overrideByLevel.putIfAbsent(item.level, () => item.overrideStyle!);
      }
    }

    return List.generate(DocxList.maxLevels, (lvl) {
      final override = overrideByLevel[lvl];
      final base = override ?? list.style;
      final ordered = override != null
          ? override.numberFormat != DocxNumberFormat.bullet
          : list.isOrdered;

      if (ordered) {
        final fmt = base.numberFormat == DocxNumberFormat.decimal
            ? DocxList.cascadeFormatForLevel(lvl)
            : base.numberFormat;
        return DocxListStyle(
          numberFormat: fmt,
          indentPerLevel: base.indentPerLevel,
          hangingIndent: base.hangingIndent,
          fontFamily: base.fontFamily,
          fontWeight: base.fontWeight,
          color: base.color,
          fontSize: base.fontSize,
        );
      }

      final bullet = base.bullet != _defaultListStyle.bullet
          ? base.bullet
          : DocxList.bulletForLevel(lvl);
      return DocxListStyle(
        numberFormat: DocxNumberFormat.bullet,
        bullet: bullet,
        indentPerLevel: base.indentPerLevel,
        hangingIndent: base.hangingIndent,
        fontFamily: base.fontFamily,
        fontWeight: base.fontWeight,
        color: base.color,
        fontSize: base.fontSize,
      );
    });
  }

  static void _collectListsFromNode(DocxNode node, List<DocxList> lists) {
    if (node is DocxList) {
      lists.add(node);
      // Also collect nested lists within list items
      for (final item in node.items) {
        for (final child in item.children) {
          _collectListsFromNode(child, lists);
        }
      }
    } else if (node is DocxTable) {
      for (final row in node.rows) {
        for (final cell in row.cells) {
          for (final child in cell.children) {
            _collectListsFromNode(child, lists);
          }
        }
      }
    } else if (node is DocxParagraph) {
      // Paragraphs might contain inline elements with nested content
      for (final child in node.children) {
        _collectListsFromNode(child, lists);
      }
    }
  }
}
