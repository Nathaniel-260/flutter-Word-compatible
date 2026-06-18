import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/pagination/page_context.dart';
import 'package:docx_file_viewer/src/pagination/paginator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Part K.3 — STYLEREF computed per page during pagination (the running head of
/// a reference book). Geometry mirrors [paginator_test.dart]: 600×400 page.
const double _pageW = 600;
const double _pageH = 400;

void main() {
  late Paginator paginator;
  late TextMeasurer measurer;

  setUp(() {
    const config = DocxViewConfig(
      pageWidth: _pageW,
      pageHeight: _pageH,
      enableSelection: false,
    );
    final spanFactory = SpanFactory(
      theme: DocxViewTheme.light(),
      config: config,
      docxTheme: DocxTheme.empty(),
    );
    measurer = TextMeasurer(spanFactory: spanFactory);
    paginator = Paginator(measurer: measurer, config: config);
  });

  DocxParagraph heading(String text) =>
      DocxParagraph(styleId: 'Heading1', children: [DocxText(text)]);
  DocxParagraph filler(int i) =>
      DocxParagraph(children: [DocxText('Filler body line number $i')]);

  // A header that runs a STYLEREF "Heading 1".
  DocxSectionDef sectionWithStyleRefHeader() => DocxSectionDef(
        header: DocxHeader(children: const [
          DocxParagraph(children: [DocxStyleRef('Heading 1')]),
        ]),
      );

  String key(String s) => PageContext.normalizeStyleKey(s);

  test('per page, STYLEREF resolves to the last Heading 1 up to that page', () {
    final elements = <DocxNode>[
      heading('Chapter Alpha'),
      for (var i = 0; i < 30; i++) filler(i),
      heading('Chapter Beta'),
      for (var i = 30; i < 60; i++) filler(i),
    ];
    final doc = DocxBuiltDocument(
      elements: elements,
      section: sectionWithStyleRefHeader(),
    );

    final res = paginator.paginate(doc);
    expect(res.pages.length, greaterThan(1));

    // First page begins under "Chapter Alpha".
    expect(res.pages.first.styleRefLast[key('Heading1')], 'Chapter Alpha');
    // The last page is under "Chapter Beta" (it appears before that page ends,
    // or is carried over from an earlier page).
    expect(res.pages.last.styleRefLast[key('Heading1')], 'Chapter Beta');
  });

  test('a page with no Heading 1 carries over the previous running value', () {
    // One heading then enough filler to span 3+ pages: later pages have no
    // heading of their own and must show the carried-over value.
    final elements = <DocxNode>[
      heading('Only Heading'),
      for (var i = 0; i < 80; i++) filler(i),
    ];
    final doc = DocxBuiltDocument(
      elements: elements,
      section: sectionWithStyleRefHeader(),
    );

    final res = paginator.paginate(doc);
    expect(res.pages.length, greaterThan(2));
    for (final page in res.pages) {
      expect(page.styleRefLast[key('Heading1')], 'Only Heading');
    }
  });

  test(
      '\\l (first-on-page) differs from default when two headings share a page',
      () {
    // Two headings with little content between them so both land on page 1.
    final elements = <DocxNode>[
      heading('First'),
      filler(0),
      heading('Second'),
      filler(1),
    ];
    final doc = DocxBuiltDocument(
      elements: elements,
      section: sectionWithStyleRefHeader(),
    );

    final res = paginator.paginate(doc);
    final p0 = res.pages.first;
    expect(p0.styleRefFirst[key('Heading1')], 'First');
    expect(p0.styleRefLast[key('Heading1')], 'Second');
  });

  test('no STYLEREF anywhere → no per-page tracking (maps stay empty)', () {
    final doc = DocxBuiltDocument(
      elements: [heading('Title'), filler(0)],
      section: const DocxSectionDef(), // header without STYLEREF
    );
    final res = paginator.paginate(doc);
    expect(res.pages.first.styleRefLast, isEmpty);
    expect(res.pages.first.styleRefFirst, isEmpty);
  });

  test('matches a custom style name from styles.xml (international names)', () {
    // styleId "a3" whose display name is a Hebrew "כותרת" — the STYLEREF names
    // the display name, so the styleId→name map must bridge them.
    const stylesXml = '''
<?xml version="1.0"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:styleId="a3">
    <w:name w:val="כותרת"/>
  </w:style>
</w:styles>''';
    final doc = DocxBuiltDocument(
      elements: [
        DocxParagraph(styleId: 'a3', children: const [DocxText('פרק ראשון')]),
        for (var i = 0; i < 4; i++) filler(i),
      ],
      stylesXml: stylesXml,
      section: DocxSectionDef(
        header: DocxHeader(children: const [
          DocxParagraph(children: [DocxStyleRef('כותרת')]),
        ]),
      ),
    );
    final res = paginator.paginate(doc);
    expect(res.pages.first.styleRefLast[key('כותרת')], 'פרק ראשון');
  });
}
