import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/pagination/paginator.dart';
import 'package:flutter_test/flutter_test.dart';

/// 05-section-sectpr.md item 32: the binding gutter sits on the leading edge —
/// the left margin by default, the right margin when `w:rtlGutter` is set.
void main() {
  late Paginator paginator;

  setUp(() {
    const config = DocxViewConfig(
        pageWidth: 600, pageHeight: 400, enableSelection: false);
    final spanFactory = SpanFactory(
        theme: DocxViewTheme.light(),
        config: config,
        docxTheme: DocxTheme.empty());
    paginator =
        Paginator(measurer: TextMeasurer(spanFactory: spanFactory), config: config);
  });

  ({double left, double right}) padsFor({required bool rtlGutter}) {
    final doc = DocxBuiltDocument(
      elements: const [DocxParagraph(children: [DocxText('x')])],
      section: DocxSectionDef(
        marginLeft: 1440, // 96px
        marginRight: 1440, // 96px
        gutter: 720, // 48px
        rtlGutter: rtlGutter,
      ),
    );
    final g = paginator.paginate(doc).pages.first.geometry;
    return (left: g.padLeft, right: g.padRight);
  }

  test('default (LTR) gutter adds to the left margin', () {
    final p = padsFor(rtlGutter: false);
    expect(p.left, closeTo(144, 0.01)); // 96 + 48
    expect(p.right, closeTo(96, 0.01));
  });

  test('rtlGutter adds to the right margin instead', () {
    final p = padsFor(rtlGutter: true);
    expect(p.left, closeTo(96, 0.01));
    expect(p.right, closeTo(144, 0.01)); // 96 + 48
  });
}
