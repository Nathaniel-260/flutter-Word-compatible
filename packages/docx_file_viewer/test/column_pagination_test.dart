import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/column_layout.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/pagination/block_slice.dart';
import 'package:docx_file_viewer/src/pagination/paginator.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixed page geometry for all tests.
const double _pageW = 600;
const double _pageH = 800;
// 1440 twips ≈ 96px margin on each side → contentW = 408px, bodyH = 608px
const double _bodyH = _pageH - 96 - 96; // 608

// Column spacing: 720 twips = 48px.
const int _colSpaceTw = 720;

// DocxViewConfig overrides page size to _pageW×_pageH, so DocxSectionDef
// only needs margins and column layout.
DocxSectionDef _twoColSection({bool rtl = false, bool separator = false}) =>
    DocxSectionDef(
      marginLeft: 1440,
      marginRight: 1440,
      marginTop: 1440,
      marginBottom: 1440,
      isRtlSection: rtl,
      columns: DocxColumns(
        count: 2,
        spaceTwips: _colSpaceTw,
        separator: separator,
      ),
    );

DocxBuiltDocument _doc(List<DocxNode> elements, DocxSectionDef section) =>
    DocxBuiltDocument(elements: elements, section: section);

DocxParagraph _para(String text) => DocxParagraph(children: [DocxText(text)]);

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

  // ──────────────────────────────────────────────────────────────────────
  // resolveColumnWidths helper
  // ──────────────────────────────────────────────────────────────────────

  group('resolveColumnWidths', () {
    test('equal-width 2 cols: each gets (contentW - gap) / 2', () {
      const cols = DocxColumns(count: 2, spaceTwips: 720);
      final widths = resolveColumnWidths(cols, 408);
      expect(widths.length, 2);
      // gap = 720 * (1/15) px = 48px; colW = (408 - 48) / 2 = 180
      expect(widths[0], closeTo(180, 1));
      expect(widths[1], closeTo(180, 1));
    });

    test('equal-width 3 cols', () {
      const cols = DocxColumns(count: 3, spaceTwips: 720);
      final widths = resolveColumnWidths(cols, 408);
      expect(widths.length, 3);
      // gaps = 48 * 2 = 96; colW = (408 - 96) / 3 = 104
      expect(widths[0], closeTo(104, 1));
    });

    test('explicit widths used when equalWidth=false', () {
      const cols = DocxColumns(
        count: 2,
        spaceTwips: 720,
        equalWidth: false,
        explicit: [
          DocxColumn(widthTwips: 3000),
          DocxColumn(widthTwips: 1500),
        ],
      );
      final widths = resolveColumnWidths(cols, 408);
      expect(widths.length, 2);
      // 3000 tw * (1/15) px/tw = 200px; 1500 tw = 100px
      expect(widths[0], closeTo(200, 1));
      expect(widths[1], closeTo(100, 1));
    });

    test('count=1 returns single width equal to contentWidth', () {
      const cols = DocxColumns(count: 1, spaceTwips: 720);
      final widths = resolveColumnWidths(cols, 408);
      expect(widths.length, 1);
      expect(widths[0], closeTo(408, 1));
    });
  });

  // ──────────────────────────────────────────────────────────────────────
  // Paginator: basic two-column layout
  // ──────────────────────────────────────────────────────────────────────

  group('two-column pagination', () {
    test('blocks are distributed across two columns on one page', () {
      // Measure how tall one short paragraph is in a column (~180px wide).
      final section = _twoColSection();
      // colWidths: (408 - 48) / 2 = 180px each
      final colW = (408.0 - 48.0) / 2; // 180

      // Create paragraphs short enough to each fit in a column.
      // Each paragraph should be roughly one line tall (< colH = bodyH = 608px).
      final paras = [
        _para('Alpha'),
        _para('Beta'),
        _para('Gamma'),
        _para('Delta'),
      ];

      // Measure height of one para at colW to decide how many fit per column.
      final h = measurer.measureParagraph(paras[0], colW).totalHeight;
      expect(h, greaterThan(0));

      // Fill enough paras to span two columns (but stay on one page).
      final perCol = (_bodyH / h).floor();
      final total = perCol * 2;
      final manyParas = List.generate(total, (i) => _para('Para $i'));

      final doc = _doc(manyParas, section);
      final result = paginator.paginate(doc);

      // All blocks should fit in one page (two columns of [perCol] each).
      expect(result.pages.length, 1);
      final page = result.pages.first;

      // Slices with columnIndex 0 and 1 should both be present.
      final col0 = page.slices.where((s) => s.columnIndex == 0).toList();
      final col1 = page.slices.where((s) => s.columnIndex == 1).toList();
      expect(col0.length, greaterThan(0));
      expect(col1.length, greaterThan(0));
      // Column 0 fills first, column 1 comes after.
      expect(col0.length + col1.length, total);
    });

    test('overflow from col 1 spills to a new page col 0', () {
      final section = _twoColSection();
      final colW = (408.0 - 48.0) / 2;
      final h = measurer.measureParagraph(_para('X'), colW).totalHeight;
      final perCol = (_bodyH / h).floor();

      // Two full columns + one extra block → should go to page 2 col 0.
      final paras = List.generate(perCol * 2 + 1, (i) => _para('P$i'));
      final result = paginator.paginate(_doc(paras, section));

      expect(result.pages.length, 2);
      // The extra block is on page 2, column 0.
      final p2Slices = result.pages[1].slices;
      expect(p2Slices.length, 1);
      expect(p2Slices.first.columnIndex, 0);
    });

    test('column break forces advance to next column', () {
      final section = _twoColSection();
      // A paragraph with a column break: before and after parts.
      final paraWithBreak = DocxParagraph(children: [
        DocxText('Before'),
        const DocxLineBreak(isColumnBreak: true),
        DocxText('After'),
      ]);
      final doc = _doc([paraWithBreak], section);
      final result = paginator.paginate(doc);

      expect(result.pages.length, 1);
      final slices = result.pages.first.slices;
      // 'Before' → col 0; 'After' → col 1.
      final col0 = slices.where((s) => s.columnIndex == 0).toList();
      final col1 = slices.where((s) => s.columnIndex == 1).toList();
      expect(col0.length, 1);
      expect(col1.length, 1);
      // Verify the text content.
      final b0 = col0.first.block as DocxParagraph;
      final b1 = col1.first.block as DocxParagraph;
      expect(b0.children.whereType<DocxText>().first.content, 'Before');
      expect(b1.children.whereType<DocxText>().first.content, 'After');
    });

    test('column break on last column opens new page', () {
      final section = _twoColSection();
      // Fill col 0, then force a column break at the start of col 1, then more
      // content → goes to page 2.
      final colW = (408.0 - 48.0) / 2;
      final h = measurer.measureParagraph(_para('X'), colW).totalHeight;
      final perCol = (_bodyH / h).floor();

      final blocks = <DocxNode>[
        ...List.generate(perCol, (i) => _para('Col0-$i')),
        // Column break from col 1 → page 2 col 0.
        DocxParagraph(children: [
          DocxText('End1'),
          const DocxLineBreak(isColumnBreak: true),
        ]),
        _para('Page2'),
      ];
      final result = paginator.paginate(_doc(blocks, section));
      expect(result.pages.length, greaterThanOrEqualTo(2));

      // 'Page2' must be on a page 2 column 0.
      final lastPage = result.pages.last;
      final page2Col0 =
          lastPage.slices.where((s) => s.columnIndex == 0).toList();
      expect(page2Col0, isNotEmpty);
      final lastBlock = page2Col0.last.block as DocxParagraph;
      expect(
        lastBlock.children.whereType<DocxText>().map((t) => t.content).join(),
        contains('Page2'),
      );
    });

    test('single-column section: all slices have columnIndex 0', () {
      const singleSection = DocxSectionDef(
        marginLeft: 1440,
        marginRight: 1440,
        marginTop: 1440,
        marginBottom: 1440,
      );
      final paras = List.generate(5, (i) => _para('Para $i'));
      final result = paginator.paginate(_doc(paras, singleSection));
      for (final page in result.pages) {
        for (final slice in page.slices) {
          expect(slice.columnIndex, 0,
              reason: 'single-column slices must have columnIndex 0');
        }
      }
    });
  });

  // ──────────────────────────────────────────────────────────────────────
  // RTL column order
  // ──────────────────────────────────────────────────────────────────────

  group('RTL two-column', () {
    test('paginator assigns column indices identically to LTR', () {
      // The paginator fills columns left-to-right regardless of RTL (the
      // renderer reverses visual order). Verify that indices are still 0 and 1.
      final rtlSection = _twoColSection(rtl: true);
      final colW = (408.0 - 48.0) / 2;
      final h = measurer.measureParagraph(_para('א'), colW).totalHeight;
      final perCol = (_bodyH / h).floor();
      final paras = List.generate(perCol * 2, (i) => _para('ס$i'));
      final result = paginator.paginate(_doc(paras, rtlSection));

      expect(result.pages.length, 1);
      final col0 = result.pages.first.slices.where((s) => s.columnIndex == 0);
      final col1 = result.pages.first.slices.where((s) => s.columnIndex == 1);
      expect(col0.length, perCol);
      expect(col1.length, perCol);
    });
  });

  // ──────────────────────────────────────────────────────────────────────
  // BlockSlice columnIndex
  // ──────────────────────────────────────────────────────────────────────

  group('BlockSlice', () {
    test('default columnIndex is 0', () {
      final slice = BlockSlice(_para('X'), 10.0);
      expect(slice.columnIndex, 0);
    });

    test('copyWith preserves columnIndex when not given', () {
      final slice = BlockSlice(_para('X'), 10.0, columnIndex: 1);
      final copy = slice.copyWith(height: 20.0);
      expect(copy.columnIndex, 1);
      expect(copy.height, 20.0);
    });

    test('copyWith can override columnIndex', () {
      final slice = BlockSlice(_para('X'), 10.0, columnIndex: 1);
      final copy = slice.copyWith(columnIndex: 2);
      expect(copy.columnIndex, 2);
    });

    test('toString includes columnIndex', () {
      final slice = BlockSlice(_para('X'), 42.0, columnIndex: 3);
      expect(slice.toString(), contains('col=3'));
    });
  });
}
