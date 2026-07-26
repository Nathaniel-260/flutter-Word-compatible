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
    final startIndex =
        int.tryParse(element.attributes['start'] ?? '') ?? 1;

    // A nested sublist's own bullet/numbered style so it can be applied as
    // a per-item override once flattened below (DocxListItem has no way to
    // carry a nested DocxList directly - list items only hold inline
    // content - so the nested list's items are flattened into this one,
    // stamped with an override so at least their indentation/bullet glyph
    // still reflects their own type. See docx_creator/CLAUDE.md-style note:
    // full per-item numbering-format switching within a single numId would
    // require the abstract numbering definition to vary by level, which
    // this exporter doesn't currently support.
    DocxListStyle nestedOverrideStyle(bool nestedOrdered) =>
        nestedOrdered ? DocxListStyle.decimal : DocxListStyle.disc;

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
              for (var nestedItem in result.items) {
                items.add(nestedItem.copyWith(
                  overrideStyle: nestedItem.overrideStyle ??
                      nestedOverrideStyle(result.isOrdered),
                ));
              }
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

        // Flatten nested items into this list, stamped with an override
        // reflecting the nested list's own type (see note above).
        for (var nested in nestedLists) {
          for (var nestedItem in nested.items) {
            items.add(nestedItem.copyWith(
              overrideStyle: nestedItem.overrideStyle ??
                  nestedOverrideStyle(nested.isOrdered),
            ));
          }
        }
      }
    }

    return DocxList(items: items, isOrdered: ordered, startIndex: startIndex);
  }
}
