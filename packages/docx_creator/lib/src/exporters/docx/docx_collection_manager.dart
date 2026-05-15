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

    void visitNode(DocxNode node) {
      if (node is DocxText && node.isLink) {
        texts.add(node);
      } else if (node is DocxParagraph) {
        for (final c in node.children) {
          visitNode(c);
        }
      } else if (node is DocxTable) {
        for (final row in node.rows) {
          for (final cell in row.cells) {
            for (final c in cell.children) {
              visitNode(c);
            }
          }
        }
      } else if (node is DocxList) {
        for (final item in node.items) {
          for (final c in item.children) {
            visitNode(c);
          }
        }
      }
    }

    for (final el in state.doc.elements) {
      visitNode(el);
    }
    if (state.doc.section?.header != null) {
      for (final c in state.doc.section!.header!.children) {
        visitNode(c);
      }
    }
    if (state.doc.section?.footer != null) {
      for (final c in state.doc.section!.footer!.children) {
        visitNode(c);
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

  // ---------------------------------------------------------------------------
  // Custom list style detection
  // ---------------------------------------------------------------------------

  static bool _isCustomListStyle(DocxListStyle style, bool isOrdered) {
    if (isOrdered) {
      return style.numberFormat != DocxNumberFormat.decimal ||
          style.fontFamily != null ||
          style.fontSize != null ||
          style.fontWeight != DocxFontWeight.normal ||
          style.color != DocxColor.black ||
          style.indentPerLevel != 720 ||
          style.hangingIndent != 360;
    } else {
      return style.bullet != '•' ||
          style.fontFamily != null ||
          style.fontSize != null ||
          style.fontWeight != DocxFontWeight.normal ||
          style.color != DocxColor.black ||
          style.indentPerLevel != 720 ||
          style.hangingIndent != 360;
    }
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
