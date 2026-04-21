import 'package:docx_creator/docx_creator.dart';
import 'package:html/dom.dart' as dom;

import '../../utils/image_resolver.dart';

/// Parses HTML `<img>` elements into DOCX image nodes.
///
/// Sizing precedence, all values converted to DOCX **points** before
/// reaching the AST:
///
/// 1. CSS declarations on the element's `style` attribute
///    (`style="width: 600px; height: 400px"`). The overwhelming majority
///    of rich-text editor output uses this form.
/// 2. HTML `width` / `height` attributes (`<img width="600" ...>`).
///    Pixels are converted to points via the 72/96 CSS-DPI ratio Word
///    uses when rendering drawingML.
/// 3. When no dimensions are declared, the intrinsic pixel size of the
///    decoded image is read from its header and converted to points.
///
/// The resolver additionally caps width at the page's printable content
/// width preserving aspect ratio, so oversized sources never clip past
/// the margin.
class HtmlImageParser {
  HtmlImageParser();

  /// 1 CSS px = 72/96 pt. HTML references 96 DPI; Word's drawingML
  /// references 72 DPI.
  static const double _pxToPt = 72.0 / 96.0;

  /// Parse an image as a block-level element.
  Future<DocxNode?> parseBlockImage(dom.Element element) async {
    final dims = _readDimensions(element);

    final result = await ImageResolver.resolve(
      element.attributes['src'] ?? '',
      width: dims.widthPt,
      height: dims.heightPt,
      alt: element.attributes['alt'],
      useIntrinsicWhenMissing: true,
    );

    if (result != null) {
      return DocxImage(
        bytes: result.bytes,
        extension: result.extension,
        width: result.width,
        height: result.height,
        altText: result.altText,
        align: DocxAlign.center,
      );
    }

    return _parseImagePlaceholder(element);
  }

  /// Parse an image as an inline element.
  Future<DocxInlineImage?> parseInlineImage(dom.Element element) async {
    final dims = _readDimensions(element);

    final result = await ImageResolver.resolve(
      element.attributes['src'] ?? '',
      width: dims.widthPt,
      height: dims.heightPt,
      alt: element.attributes['alt'],
      useIntrinsicWhenMissing: true,
    );

    if (result != null) {
      return DocxInlineImage(
        bytes: result.bytes,
        extension: result.extension,
        width: result.width,
        height: result.height,
        altText: result.altText,
      );
    }
    return null;
  }

  DocxNode? _parseImagePlaceholder(dom.Element element) {
    final src = element.attributes['src'];
    if (src == null || src.isEmpty) return null;
    final alt = element.attributes['alt'] ?? 'Image';
    return DocxParagraph(
      align: DocxAlign.center,
      children: [
        DocxText('[📷 '),
        DocxText.link(alt, href: src),
        DocxText(']'),
      ],
    );
  }

  /// Reads width/height from an element, preferring CSS `style` over
  /// HTML attributes. Returned values are in **points**, or null when
  /// the dimension is not declared at the HTML layer.
  _Dims _readDimensions(dom.Element element) {
    final style = element.attributes['style'];
    final widthPt = _readCssLength(style, 'width') ??
        _parsePxAttr(element.attributes['width']);
    final heightPt = _readCssLength(style, 'height') ??
        _parsePxAttr(element.attributes['height']);
    return _Dims(
      widthPt: widthPt,
      heightPt: heightPt,
    );
  }

  /// Extracts a numeric `propName: <n>px | <n>pt` declaration from a
  /// CSS style string, returning the value in points (**pt**).
  /// Returns null if the property is absent or malformed.
  double? _readCssLength(String? style, String propName) {
    if (style == null) return null;
    final trimmedStyle = style.trim();
    if (trimmedStyle.isEmpty) return null;

    final re = RegExp(
      '(?:^|;)\\s*$propName\\s*:\\s*([0-9.]+)\\s*(px|pt)?',
      caseSensitive: false,
    );
    final match = re.firstMatch(trimmedStyle);
    if (match == null) return null;
    final n = double.tryParse(match.group(1)!);
    if (n == null) return null;
    final unit = (match.group(2) ?? 'px').toLowerCase();
    return unit == 'pt' ? n : n * _pxToPt;
  }

  double? _parsePxAttr(String? value) {
    if (value == null) return null;
    final cleaned =
        value.replaceAll(RegExp(r'px\s*$', caseSensitive: false), '').trim();
    final n = double.tryParse(cleaned);
    return n == null ? null : n * _pxToPt;
  }
}

class _Dims {
  final double? widthPt;
  final double? heightPt;
  const _Dims({this.widthPt, this.heightPt});
}
