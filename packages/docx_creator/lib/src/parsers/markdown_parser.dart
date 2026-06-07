import 'package:markdown/markdown.dart' as md;

import '../../docx_creator.dart';
import '../utils/document_builder.dart';
import '../utils/image_resolver.dart';

/// Parses Markdown content into [DocxNode] elements.
class MarkdownParser {
  MarkdownParser._();

  /// Parses Markdown string into DocxNode elements.
  static Future<List<DocxNode>> parse(String markdown) async {
    // Enable GFM (tables, strikethrough, autolinks, task lists)
    final document = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored);
    final nodes = document.parseLines(markdown.split('\n'));
    return _parseNodes(nodes);
  }

  static Future<List<DocxNode>> _parseNodes(List<md.Node> nodes) async {
    final results = <DocxNode>[];
    for (var node in nodes) {
      results.addAll(await _parseNode(node));
    }
    return results;
  }

  static Future<List<DocxNode>> _parseNode(md.Node node) async {
    if (node is md.Element) {
      return _parseElement(node);
    } else if (node is md.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return [];
      final built = DocumentBuilder.buildBlockElement(
        tag: 'p',
        children: [DocxText(_unescape(text))],
      );
      return built != null ? [built] : [];
    }
    return [];
  }

  static Future<List<DocxNode>> _parseElement(md.Element element) async {
    final tag = element.tag;

    // Check for container elements that should recurse for blocks
    if (tag == 'blockquote' || tag == 'div') {
      final children = await _parseNodes(element.children ?? []);
      if (tag == 'blockquote') {
        // For blockquote, we might want to wrap/style each child paragraph as a quote
        return children.map((node) {
          if (node is DocxParagraph) {
            return node.copyWith(
              styleId: 'Quote',
              indentLeft: 720,
            );
          }
          return node;
        }).toList();
      }
      return children;
    }

    final inlines = await _parseInlines(element.children ?? []);

    // 1. Try Shared Builder
    final built = DocumentBuilder.buildBlockElement(
      tag: tag,
      children: inlines,
      textContent: await _extractText(element),
    );

    // If built is a heading/pre/hr, return it.
    if (built != null && !['p', 'div'].contains(tag)) {
      return [built];
    }

    switch (tag) {
      // Paragraph
      case 'p':
        if (inlines.isEmpty) return [];
        final p =
            DocumentBuilder.buildBlockElement(tag: 'p', children: inlines);
        return p != null ? [p] : [];

      // Lists
      case 'ul':
        return [await _parseList(element, ordered: false)];
      case 'ol':
        return [await _parseList(element, ordered: true)];

      // Table
      case 'table':
        return [await _parseTable(element)];

      default:
        if (inlines.isNotEmpty) {
          final p =
              DocumentBuilder.buildBlockElement(tag: 'p', children: inlines);
          return p != null ? [p] : [];
        }
        return [];
    }
  }

  static Future<List<DocxInline>> _parseInlines(List<md.Node> nodes) async {
    final results = <DocxInline>[];
    for (var node in nodes) {
      results.addAll(await _parseInline(node));
    }
    return results;
  }

  static Future<List<DocxInline>> _parseInline(md.Node node) async {
    if (node is md.Text) {
      return [DocxText(_unescape(node.text))];
    }

    if (node is md.Element) {
      final children = await _parseInlines(node.children ?? []);

      switch (node.tag) {
        case 'strong':
        case 'b':
          return children.map((c) {
            if (c is DocxText) {
              return c.copyWith(fontWeight: DocxFontWeight.bold);
            }
            return c;
          }).toList();
        case 'em':
        case 'i':
          return children.map((c) {
            if (c is DocxText) {
              return c.copyWith(fontStyle: DocxFontStyle.italic);
            }
            return c;
          }).toList();
        case 'del':
        case 's':
        case 'strike':
          return children.map((c) {
            if (c is DocxText) {
              return c.copyWith(decorations: [
                ...c.decorations,
                DocxTextDecoration.strikethrough
              ]);
            }
            return c;
          }).toList();
        case 'u':
          return children.map((c) {
            if (c is DocxText) {
              return c.copyWith(decorations: [
                ...c.decorations,
                DocxTextDecoration.underline
              ]);
            }
            return c;
          }).toList();
        case 'code':
          if (children.every((c) => c is DocxText)) {
            return [
              DocxText.code(children.map((c) => (c as DocxText).content).join())
            ];
          }
          return children;
        case 'a':
          final href = node.attributes['href'] ?? '#';
          return children.map((c) {
            if (c is DocxText) {
              return c.copyWith(
                href: href,
                color: DocxColor.blue,
                decorations: [...c.decorations, DocxTextDecoration.underline],
              );
            }
            return c;
          }).toList();
        case 'br':
          return [DocxLineBreak()];
        case 'img':
          final text = await _extractText(node);
          final src = node.attributes['src'] ?? '';
          final alt = node.attributes['alt'] ?? text;
          final result = await ImageResolver.resolve(src, alt: alt);

          if (result != null) {
            return [
              DocxInlineImage(
                bytes: result.bytes,
                extension: result.extension,
                width: result.width,
                height: result.height,
                altText: result.altText,
              )
            ];
          }
          return [
            DocxText('[📷 '),
            DocxText.link(alt.isEmpty ? 'Image' : alt, href: src),
            DocxText(']'),
          ];

        case 'input':
          if (node.attributes['type'] == 'checkbox') {
            final isChecked = node.attributes.containsKey('checked');
            return [DocumentBuilder.buildCheckbox(isChecked: isChecked)];
          }
          return [];

        default:
          return children;
      }
    }

    return [];
  }

  static Future<DocxList> _parseList(
    md.Element element, {
    required bool ordered,
    int level = 0,
  }) async {
    final items = <DocxListItem>[];

    for (var child in element.children ?? []) {
      if (child is md.Element && child.tag == 'li') {
        final currentInlines = <DocxInline>[];

        void flushInlines() {
          if (currentInlines.isNotEmpty) {
            items.add(DocxListItem(List.from(currentInlines), level: level));
            currentInlines.clear();
          }
        }

        // Process children of LI
        for (var node in child.children ?? []) {
          if (node is md.Element && (node.tag == 'ul' || node.tag == 'ol')) {
            flushInlines();
            // Found nested list
            final nestedOrdered = node.tag == 'ol';
            final nested =
                await _parseList(node, ordered: nestedOrdered, level: level + 1);
            // Flattening discards the nested list's own [isOrdered]. When the
            // nested kind differs from this list (e.g. an <ol> inside a <ul>),
            // tag each item with an [overrideStyle] so the renderer/exporter
            // keep the correct markers instead of inheriting the parent's.
            items.addAll(DocxList.withOrderingOverride(
                nested.items, nestedOrdered,
                differs: nestedOrdered != ordered));
          } else if (node is md.Element && node.tag == 'p') {
            flushInlines();
            // Explicit paragraph in list item
            final inlines = await _parseInlines(node.children ?? []);
            if (inlines.isNotEmpty) {
              items.add(DocxListItem(inlines, level: level));
            }
          } else {
            // Regular inline content
            currentInlines.addAll(await _parseInline(node));
          }
        }
        flushInlines();
      }
    }

    return DocxList(items: items, isOrdered: ordered);
  }

  static Future<DocxTable> _parseTable(md.Element element) async {
    final rows = <DocxTableRow>[];

    // Find thead and tbody
    for (var child in element.children ?? []) {
      if (child is md.Element) {
        if (child.tag == 'thead' || child.tag == 'tbody') {
          for (var tr in child.children ?? []) {
            if (tr is md.Element && tr.tag == 'tr') {
              rows.add(
                  await _parseTableRow(tr, isHeader: child.tag == 'thead'));
            }
          }
        } else if (child.tag == 'tr') {
          rows.add(await _parseTableRow(child, isHeader: false));
        }
      }
    }

    return DocxTable(rows: rows, style: DocxTableStyle.headerHighlight);
  }

  static Future<DocxTableRow> _parseTableRow(md.Element tr,
      {required bool isHeader}) async {
    final cells = <DocxTableCell>[];

    for (var child in tr.children ?? []) {
      if (child is md.Element && (child.tag == 'td' || child.tag == 'th')) {
        var inlines = await _parseInlines(child.children ?? []);
        if (isHeader) {
          inlines = inlines.map((inline) {
            if (inline is DocxText) {
              return inline.copyWith(fontWeight: DocxFontWeight.bold);
            }
            return inline;
          }).toList();
        }
        cells.add(
          DocxTableCell(
            shadingFill: isHeader ? 'E0E0E0' : null,
            children: [
              DocxParagraph(
                children: inlines,
              )
            ],
          ),
        );
      }
    }

    return DocxTableRow(cells: cells);
  }

  static Future<String> _extractText(md.Node node) async {
    if (node is md.Text) return _unescape(node.text);
    if (node is md.Element) {
      final buffer = StringBuffer();
      for (var child in node.children ?? []) {
        buffer.write(await _extractText(child));
      }
      return buffer.toString();
    }
    return '';
  }

  static String _unescape(String text) {
    // Decode HTML entities (e.g., &amp; -> &, &quot; -> ")
    // This is necessary because the markdown package escapes special characters,
    // and DocxText will escape them AGAIN during XML generation, leading to double escaping.
    // We want the raw characters in our AST.

    // Quick optimization for common cases to avoid parsing
    if (!text.contains('&')) return text;

    // Use string replacement for standard XML entities
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}
