import 'package:html/dom.dart' as dom;

import '../../../docx_creator.dart';
import '../../utils/document_builder.dart';
import 'color_utils.dart';
import 'image_parser.dart';
import 'inline_parser.dart';
import 'list_parser.dart';
import 'parser_context.dart';
import 'style_context.dart';
import 'table_parser.dart';

/// Parses HTML block-level elements.
class HtmlBlockParser {
  final HtmlParserContext context;
  late final HtmlInlineParser _inlineParser;
  late final HtmlTableParser _tableParser;
  late final HtmlListParser _listParser;
  late final HtmlImageParser _imageParser;

  HtmlBlockParser(this.context) {
    _inlineParser = HtmlInlineParser(context);
    _tableParser = HtmlTableParser(context, _inlineParser);
    _listParser = HtmlListParser(context, _inlineParser);
    _imageParser = HtmlImageParser();

    _tableParser.setBlockParser(this);
    _listParser.setBlockParser(this);
  }

  /// Parse child nodes into DocxNode elements.
  Future<List<DocxNode>> parseChildren(List<dom.Node> nodes,
      {HtmlStyleContext? styleContext}) async {
    final results = <DocxNode>[];
    for (var node in nodes) {
      final parsed = await parseNode(node, styleContext: styleContext);
      results.addAll(parsed);
    }
    return results;
  }

  /// Parse a single DOM node.
  Future<List<DocxNode>> parseNode(dom.Node node,
      {HtmlStyleContext? styleContext}) async {
    if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return [];
      final built = DocumentBuilder.buildBlockElement(
        tag: 'p',
        children: [
          _inlineParser.createText(
              text, styleContext ?? const HtmlStyleContext())
        ],
      );
      return built != null ? [built] : [];
    }
    if (node is dom.Element) {
      return parseElement(node, styleContext: styleContext);
    }
    return [];
  }

  /// Parse an HTML element.
  Future<List<DocxNode>> parseElement(dom.Element element,
      {HtmlStyleContext? styleContext}) async {
    final tag = element.localName?.toLowerCase();
    if (tag == null) return [];

    final styleStr =
        context.mergeStyles(element.attributes['style'], element.classes);
    final parentCtx = styleContext ?? const HtmlStyleContext();
    final currentCtx =
        parentCtx.mergeWith(tag, styleStr, ColorUtils.parseColor);

    // Check if this element should be treated as a container of blocks
    bool hasBlockChildren = false;
    for (var node in element.nodes) {
      if (node is dom.Element && isBlockTag(node.localName?.toLowerCase())) {
        hasBlockChildren = true;
        break;
      }
    }

    // If it has block children and is a container-like tag, recurse
    if (hasBlockChildren &&
        ![
          'p',
          'h1',
          'h2',
          'h3',
          'h4',
          'h5',
          'h6',
          'table',
          'ul',
          'ol',
          'img',
          'pre',
          'code'
        ].contains(tag)) {
      return parseChildren(element.nodes, styleContext: currentCtx);
    }

    final blockContext = currentCtx.resetBackground();

    // Parse inline children
    final children =
        await _inlineParser.parseInlines(element.nodes, context: blockContext);

    final built = DocumentBuilder.buildBlockElement(
      tag: tag,
      children: children,
      textContent: _getText(element),
    );

    if (built != null &&
        tag != 'p' &&
        tag != 'div' &&
        tag != 'span' &&
        tag != 'pre' &&
        !tag.startsWith('h')) {
      return [built];
    }

    final blockStyles = _parseBlockStyles(styleStr);

    switch (tag) {
      case 'p':
      case 'div':
      case 'span':
        if (children.isEmpty) return [];
        return [
          DocxParagraph(
            children: children,
            shadingFill: blockStyles.shadingFill,
            align: blockStyles.align,
            borderTop: blockStyles.borderTop,
            borderBottomSide: blockStyles.borderBottom,
            borderLeft: blockStyles.borderLeft,
            borderRight: blockStyles.borderRight,
          )
        ];

      case 'ul':
        final list = await _listParser.parseList(element,
            ordered: false,
            styleContext:
                currentCtx.copyWith(listLevel: currentCtx.listLevel + 1));
        return [list];
      case 'ol':
        final list = await _listParser.parseList(element,
            ordered: true,
            styleContext:
                currentCtx.copyWith(listLevel: currentCtx.listLevel + 1));
        return [list];

      case 'table':
        final table = await _tableParser.parseTable(element);
        return [table];

      case 'img':
        final img = await _imageParser.parseBlockImage(element);
        return img != null ? [img] : [];

      case 'pre':
      case 'code':
        return [_parseCodeBlock(element, blockStyles.align)];

      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
      case 'blockquote':
      case 'hr':
        if (built is DocxParagraph) {
          return [
            built.copyWith(
              shadingFill: blockStyles.shadingFill ?? built.shadingFill,
              align: blockStyles.align,
              borderTop: blockStyles.borderTop,
              borderBottomSide: blockStyles.borderBottom,
              borderLeft: blockStyles.borderLeft,
              borderRight: blockStyles.borderRight,
            )
          ];
        }
        return built != null ? [built] : [];

      default:
        if (children.isEmpty) return [];
        return [
          DocxParagraph(
            children: children,
            shadingFill: blockStyles.shadingFill,
            align: blockStyles.align,
          )
        ];
    }
  }

  DocxParagraph _parseCodeBlock(dom.Element element, DocxAlign align) {
    final text = _getText(element);
    final lines = text.split('\n');
    final codeChildren = <DocxInline>[];

    for (var i = 0; i < lines.length; i++) {
      codeChildren.add(DocxText.code(lines[i], color: DocxColor.black));
      if (i < lines.length - 1) {
        codeChildren.add(DocxLineBreak());
      }
    }

    return DocxParagraph(
      shadingFill: 'F5F5F5',
      children: codeChildren,
      align: align,
    );
  }

  HtmlBlockStyles _parseBlockStyles(String style) {
    String? shadingFill;
    DocxAlign align = DocxAlign.left;

    final bgMatch = RegExp(
            r"background-color:\s*['\x22]?(#[A-Fa-f0-9]{3,6}|rgb\([0-9,\s]+\)|rgba\([0-9.,\s]+\)|[a-zA-Z]+)['\x22]?")
        .firstMatch(style);
    if (bgMatch != null) {
      final val = bgMatch.group(1);
      if (val != null) {
        shadingFill = ColorUtils.parseColor(val);
      }
    }

    if (style.contains('text-align: center')) {
      align = DocxAlign.center;
    } else if (style.contains('text-align: right')) {
      align = DocxAlign.right;
    } else if (style.contains('text-align: justify')) {
      align = DocxAlign.justify;
    }

    return HtmlBlockStyles(
      shadingFill: shadingFill,
      align: align,
      borderTop: ColorUtils.parseCssBorderProperty(style, 'border-top') ??
          ColorUtils.parseCssBorderProperty(style, 'border'),
      borderBottom: ColorUtils.parseCssBorderProperty(style, 'border-bottom') ??
          ColorUtils.parseCssBorderProperty(style, 'border'),
      borderLeft: ColorUtils.parseCssBorderProperty(style, 'border-left') ??
          ColorUtils.parseCssBorderProperty(style, 'border'),
      borderRight: ColorUtils.parseCssBorderProperty(style, 'border-right') ??
          ColorUtils.parseCssBorderProperty(style, 'border'),
    );
  }

  String _getText(dom.Node node) {
    if (node is dom.Text) return node.text;
    if (node is dom.Element) return node.text;
    return '';
  }

  /// Check if a tag is a block-level element.
  static bool isBlockTag(String? tag) {
    if (tag == null) return false;
    return [
      'p',
      'div',
      'table',
      'ul',
      'ol',
      'blockquote',
      'pre',
      'hr',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'img'
    ].contains(tag);
  }
}
