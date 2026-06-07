import 'package:docx_creator/docx_creator.dart';
import 'package:html/dom.dart' as dom;

import 'block_parser.dart';
import 'inline_parser.dart';
import 'parser_context.dart';

/// Parses HTML list elements (ul, ol).
class HtmlListParser {
  final HtmlParserContext context;
  final HtmlInlineParser inlineParser;
  HtmlBlockParser? blockParser;

  HtmlListParser(this.context, this.inlineParser);

  void setBlockParser(HtmlBlockParser parser) {
    blockParser = parser;
  }

  /// Parse a list element (ul or ol).
  Future<DocxList> parseList(
    dom.Element element, {
    required bool ordered,
    int level = 0,
    HtmlStyleContext? styleContext,
  }) async {
    final items = <DocxListItem>[];
    final currentLevel = (styleContext != null && styleContext.listLevel >= 0)
        ? styleContext.listLevel
        : level;

    for (var child in element.children) {
      if (child.localName == 'li') {
        if (blockParser != null) {
          final results = await blockParser!.parseChildren(child.nodes,
              styleContext: (styleContext ?? const HtmlStyleContext())
                  .copyWith(listLevel: currentLevel));
          for (var result in results) {
            if (result is DocxParagraph) {
              items.add(DocxListItem(result.children, level: currentLevel));
            } else if (result is DocxList) {
              items.addAll(DocxList.withOrderingOverride(
                  result.items, result.isOrdered,
                  differs: result.isOrdered != ordered));
            }
          }
          continue;
        }

        final inlines = <DocxInline>[];
        final nestedLists = <DocxList>[];

        for (var node in child.nodes) {
          if (node is dom.Element) {
            if (node.localName == 'ul') {
              nestedLists.add(await parseList(node,
                  ordered: false,
                  level: currentLevel + 1,
                  styleContext:
                      styleContext?.copyWith(listLevel: currentLevel + 1)));
              continue;
            } else if (node.localName == 'ol') {
              nestedLists.add(await parseList(node,
                  ordered: true,
                  level: currentLevel + 1,
                  styleContext:
                      styleContext?.copyWith(listLevel: currentLevel + 1)));
              continue;
            }
          }
          inlines.addAll(
              await inlineParser.parseInline(node, context: styleContext));
        }

        // Add current item
        if (inlines.isNotEmpty) {
          items.add(DocxListItem(inlines, level: currentLevel));
        }

        // Flatten nested items into this list, preserving each nested list's
        // own ordering when it differs from this one.
        for (var nested in nestedLists) {
          items.addAll(DocxList.withOrderingOverride(
              nested.items, nested.isOrdered,
              differs: nested.isOrdered != ordered));
        }
      }
    }

    return DocxList(items: items, isOrdered: ordered);
  }
}
