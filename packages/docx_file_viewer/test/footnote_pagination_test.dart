import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/pagination/page_model.dart';
import 'package:docx_file_viewer/src/pagination/paginator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Part J — footnotes/endnotes on the page (pagination layer).
///
/// Geometry mirrors [paginator_test.dart]: 600×400 page, 96px margins →
/// content 408px, body 208px.
const double _pageW = 600;
const double _pageH = 400;
const double _bodyH = _pageH - 96 - 96; // 208

void main() {
  late DocxViewConfig config;
  late TextMeasurer measurer;
  late Paginator paginator;

  setUp(() {
    config = const DocxViewConfig(
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

  DocxParagraph para(String text) => DocxParagraph(children: [DocxText(text)]);

  DocxParagraph paraWithFootnote(String text, int id) => DocxParagraph(
        children: [DocxText(text), DocxFootnoteRef(footnoteId: id)],
      );

  // Height of one single-line body paragraph at the content width.
  double paraHeight() => measurer
      .measureParagraph(para('Filler line'), _pageW - 96 - 96)
      .totalHeight;

  // Concatenated text of every paragraph slice on [page], in order.
  String pageText(PageModel page) {
    final sb = StringBuffer();
    for (final slice in page.slices) {
      final block = slice.block;
      if (block is DocxParagraph) {
        for (final c in block.children) {
          if (c is DocxText) sb.write(c.content);
        }
      }
    }
    return sb.toString();
  }

  test('a footnote reference places its note at the foot of the same page', () {
    final doc = DocxBuiltDocument(
      elements: [paraWithFootnote('Body with a note', 1)],
      footnotes: [
        DocxFootnote(footnoteId: 1, content: [para('The footnote text.')]),
      ],
    );

    final res = paginator.paginate(doc);

    expect(res.pages.length, 1);
    final page = res.pages.single;
    expect(page.footnotes.map((f) => f.id), [1]);
    expect(page.footnotes.single.label, '1');
    expect(page.footnotesHeight, greaterThan(0));
    expect(res.footnoteLabels, {1: '1'});
    // The note's reference and its body live on the same page (§J.1).
    expect(res.footnotePages[1], page.absoluteIndex);
  });

  test('the footnote band never lets a page overflow its body height', () {
    final elements = <DocxNode>[];
    for (var i = 0; i < 40; i++) {
      if (i % 7 == 0) {
        elements.add(paraWithFootnote('Para $i with note', i + 1));
      } else {
        elements.add(para('Para $i body line'));
      }
    }
    final footnotes = [
      for (var i = 0; i < 40; i += 7)
        DocxFootnote(footnoteId: i + 1, content: [para('Note for para $i.')]),
    ];
    final res = paginator
        .paginate(DocxBuiltDocument(elements: elements, footnotes: footnotes));

    for (final page in res.pages) {
      expect(page.usedHeight + page.footnotesHeight,
          lessThanOrEqualTo(_bodyH + 0.5),
          reason: 'body + footnote band must fit the page (§J.2)');
      // Every note rendered on a page is referenced on that same page.
      for (final fn in page.footnotes) {
        expect(res.footnotePages[fn.id], page.absoluteIndex);
      }
    }
  });

  test('a footnote pushes the line that no longer fits to the next page (§J.2)',
      () {
    final h = paraHeight();
    // Fill the body so all K one-line paragraphs fit exactly, leaving < one
    // line of slack — not enough for the last line *plus* its footnote band.
    final k = (_bodyH / h).floor();
    expect(k, greaterThan(2));

    List<DocxNode> body({required bool withNote}) => [
          for (var i = 0; i < k - 1; i++) para('Plain line $i'),
          if (withNote) paraWithFootnote('Last line', 1) else para('Last line'),
        ];

    final without =
        paginator.paginate(DocxBuiltDocument(elements: body(withNote: false)));
    final with_ = paginator.paginate(DocxBuiltDocument(
      elements: body(withNote: true),
      footnotes: [
        DocxFootnote(footnoteId: 1, content: [para('A footnote at the foot.')]),
      ],
    ));

    expect(without.pages.length, 1, reason: 'without a note all lines fit');
    expect(with_.pages.length, 2,
        reason: 'the note band evicts the last line to page 2');
    expect(with_.pages[0].footnotes, isEmpty);
    expect(with_.pages[1].footnotes.map((f) => f.id), [1]);
    expect(pageText(with_.pages[1]), contains('Last line'));
  });

  test('eachPage restart numbers footnotes 1,1 on consecutive pages (§J.4)',
      () {
    final h = paraHeight();
    final k = (_bodyH / h).floor();
    // ref on page 1, fillers to overflow, ref on page 2.
    final elements = <DocxNode>[
      paraWithFootnote('First page note', 1),
      for (var i = 0; i < k; i++) para('Filler $i'),
      paraWithFootnote('Second page note', 2),
    ];
    final footnotes = [
      DocxFootnote(footnoteId: 1, content: [para('Note one.')]),
      DocxFootnote(footnoteId: 2, content: [para('Note two.')]),
    ];

    final eachPage = paginator.paginate(DocxBuiltDocument(
      elements: elements,
      footnotes: footnotes,
      footnoteProperties:
          const DocxNoteProperties(numRestart: DocxNoteNumberRestart.eachPage),
    ));
    expect(eachPage.pages.length, greaterThanOrEqualTo(2));
    expect(eachPage.footnoteLabels, {1: '1', 2: '1'});

    final continuous = paginator
        .paginate(DocxBuiltDocument(elements: elements, footnotes: footnotes));
    expect(continuous.footnoteLabels, {1: '1', 2: '2'});
  });

  test('eachSect restart numbers footnotes 1,1 across sections (§J.4)', () {
    final elements = <DocxNode>[
      paraWithFootnote('Section one note', 1),
      const DocxSectionBreakBlock(DocxSectionDef()),
      paraWithFootnote('Section two note', 2),
    ];
    final footnotes = [
      DocxFootnote(footnoteId: 1, content: [para('Note one.')]),
      DocxFootnote(footnoteId: 2, content: [para('Note two.')]),
    ];

    final eachSect = paginator.paginate(DocxBuiltDocument(
      elements: elements,
      footnotes: footnotes,
      footnoteProperties:
          const DocxNoteProperties(numRestart: DocxNoteNumberRestart.eachSect),
    ));
    expect(eachSect.footnoteLabels, {1: '1', 2: '1'});

    // Without a restart the numbering runs continuously across the sections.
    final continuous = paginator
        .paginate(DocxBuiltDocument(elements: elements, footnotes: footnotes));
    expect(continuous.footnoteLabels, {1: '1', 2: '2'});
  });

  test('repeated paginate() on one instance restarts endnote numbering', () {
    final doc = DocxBuiltDocument(
      elements: [
        DocxParagraph(children: [
          const DocxText('Body'),
          const DocxEndnoteRef(endnoteId: 1),
        ]),
      ],
      endnotes: [
        DocxEndnote(endnoteId: 1, content: [para('Only endnote')]),
      ],
    );

    final first = paginator.paginate(doc);
    final second = paginator.paginate(doc);
    expect(first.endnoteLabels, {1: '1'});
    // A second run on the same instance must not continue from the first
    // (_endnoteNumber is reset), otherwise the mark would read '2'.
    expect(second.endnoteLabels, {1: '1'});
  });

  test('hebrew1 footnote format numbers with gematria (§J.4)', () {
    final doc = DocxBuiltDocument(
      elements: [
        paraWithFootnote('Aleph', 1),
        paraWithFootnote('Bet', 2),
      ],
      footnotes: [
        DocxFootnote(footnoteId: 1, content: [para('ראשונה')]),
        DocxFootnote(footnoteId: 2, content: [para('שנייה')]),
      ],
      footnoteProperties:
          const DocxNoteProperties(format: DocxPageNumberFormat.hebrew1),
    );

    final res = paginator.paginate(doc);
    expect(res.footnoteLabels, {1: 'א', 2: 'ב'});
  });

  test('endnotes flow at the document end with continuous numbering (§J.5)',
      () {
    final doc = DocxBuiltDocument(
      elements: [
        DocxParagraph(children: [
          const DocxText('Body one'),
          const DocxEndnoteRef(endnoteId: 1),
        ]),
        DocxParagraph(children: [
          const DocxText('Body two'),
          const DocxEndnoteRef(endnoteId: 2),
        ]),
      ],
      endnotes: [
        DocxEndnote(endnoteId: 1, content: [para('First endnote body')]),
        DocxEndnote(endnoteId: 2, content: [para('Second endnote body')]),
      ],
    );

    final res = paginator.paginate(doc);
    expect(res.endnoteLabels, {1: '1', 2: '2'});

    // The endnote bodies are flowed as trailing content (after the body), not in
    // a footnote band.
    final allText = res.pages.map(pageText).join('\n');
    expect(allText, contains('First endnote body'));
    expect(allText, contains('Second endnote body'));
    for (final page in res.pages) {
      expect(page.footnotes, isEmpty);
    }
  });
}
