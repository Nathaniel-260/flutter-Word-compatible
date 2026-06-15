import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/pagination/page_model.dart';
import 'package:docx_file_viewer/src/pagination/paginator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Page geometry for the test config (mirrors [Paginator._computeGeometry] for
/// the default section: all margins 1440tw = 96px, header distance 48px, no
/// header/footer).
const double _pageW = 600;
const double _pageH = 400;
const double _contentW = _pageW - 96 - 96; // 408
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

  // Total height of one identical body paragraph at the content width.
  double bodyParaHeight(String text) => measurer
      .measureParagraph(DocxParagraph(children: [DocxText(text)]), _contentW)
      .totalHeight;

  DocxParagraph para(String text) => DocxParagraph(children: [DocxText(text)]);

  // Concatenated text of every paragraph slice across all pages, in order.
  String allText(PaginationResult res) {
    final sb = StringBuffer();
    for (final page in res.pages) {
      for (final slice in page.slices) {
        final block = slice.block;
        if (block is DocxParagraph) {
          for (final c in block.children) {
            if (c is DocxText) sb.write(c.content);
          }
        }
      }
    }
    return sb.toString();
  }

  test('paginateAsync yields the same layout as paginate (§4.4)', () async {
    final paras = List.generate(60, (i) => para('Async block number $i'));
    final doc = DocxBuiltDocument(elements: paras);

    final sync = paginator.paginate(doc);
    // sliceBudgetMs:0 forces a UI-thread yield after every group.
    final async = await paginator.paginateAsync(doc, sliceBudgetMs: 0);

    expect(async.pages.length, sync.pages.length);
    expect(
      async.pages.map((p) => p.slices.length).toList(),
      sync.pages.map((p) => p.slices.length).toList(),
      reason: 'time-slicing must not change page boundaries',
    );
  });

  test('paginateAsync streams each page via onPage in document order (§D.2.9)',
      () async {
    final paras = List.generate(40, (i) => para('Streamed block number $i'));
    final doc = DocxBuiltDocument(elements: paras);

    final streamed = <PageModel>[];
    // sliceBudgetMs:0 yields after every group, exercising the streaming path.
    final res = await paginator.paginateAsync(doc,
        sliceBudgetMs: 0, onPage: streamed.add);

    expect(res.pages.length, greaterThan(1),
        reason: 'document should span several pages');
    expect(streamed.length, res.pages.length,
        reason: 'every page is emitted exactly once');
    for (var i = 0; i < res.pages.length; i++) {
      expect(identical(streamed[i], res.pages[i]), isTrue,
          reason: 'pages stream in the same order as the final result');
    }
  });

  test('empty document still streams a single blank page via onPage', () async {
    final streamed = <PageModel>[];
    final res = await paginator.paginateAsync(
        const DocxBuiltDocument(elements: []),
        onPage: streamed.add);

    expect(streamed.length, 1);
    expect(identical(streamed.single, res.pages.single), isTrue);
    expect(streamed.single.slices, isEmpty);
  });

  test('the synchronous paginate path never invokes a stale onPage', () async {
    final doc = DocxBuiltDocument(elements: [para('one'), para('two')]);
    final streamed = <PageModel>[];
    // Run the streaming path once so _onPage is set on the instance...
    await paginator.paginateAsync(doc, onPage: streamed.add);
    streamed.clear();
    // ...then the sync path must not reuse that callback (reset clears it).
    paginator.paginate(doc);
    expect(streamed, isEmpty);
  });

  test('shouldContinue=false abandons a superseded pagination early', () async {
    final paras = List.generate(200, (i) => para('cancel me $i'));
    final doc = DocxBuiltDocument(elements: paras);

    var polled = 0;
    // sliceBudgetMs:0 yields (and polls) after the first group; returning false
    // cancels instead of laying out all ~100 pages.
    final res = await paginator.paginateAsync(doc, sliceBudgetMs: 0,
        shouldContinue: () {
      polled++;
      return false;
    });

    expect(polled, greaterThan(0), reason: 'the predicate is polled');
    expect(res.pages.length, lessThan(10),
        reason: 'cancelled long before the full ~100-page layout');
  });

  test('pagination is bounded by maxPages and flags truncated (anti-runaway)',
      () {
    // A tiny cap stands in for a pathological document (tiny page, huge body).
    final capped = Paginator(measurer: measurer, config: config, maxPages: 3);
    final paras = List.generate(200, (i) => para('overflow $i'));

    final res = capped.paginate(DocxBuiltDocument(elements: paras));

    expect(res.truncated, isTrue);
    expect(res.pages.length, lessThanOrEqualTo(3),
        reason: 'pagination stops at the cap, not the ~100 natural pages');
    expect(res.pages.length, greaterThan(0));
  });

  test('empty document yields a single blank page', () {
    final res = paginator.paginate(const DocxBuiltDocument(elements: []));
    expect(res.pages.length, 1);
    expect(res.pages.first.slices, isEmpty);
    expect(res.pageCount, 1);
  });

  test('packs identical paragraphs into ceil(N / perPage) pages', () {
    final h = bodyParaHeight('Hello world');
    final perPage = (_bodyH / h).floor();
    expect(perPage, greaterThanOrEqualTo(2));

    final n = perPage * 2 + 1; // forces exactly 3 pages
    final paras = List.generate(n, (_) => para('Hello world'));
    final res = paginator.paginate(DocxBuiltDocument(elements: paras));

    expect(res.pages.length, (n / perPage).ceil());
    // Every page stays within the body height.
    for (final page in res.pages) {
      expect(page.usedHeight, lessThanOrEqualTo(_bodyH + 0.5));
    }
  });

  test('pageBreakBefore forces a new page', () {
    final res = paginator.paginate(DocxBuiltDocument(elements: [
      para('first'),
      DocxParagraph(
        pageBreakBefore: true,
        children: [DocxText('second after break')],
      ),
    ]));
    expect(res.pages.length, 2);
    expect(res.pages[0].slices.length, 1);
    expect(res.pages[1].slices.length, 1);
  });

  test('inline page break (w:br type=page) ends the page', () {
    final res = paginator.paginate(DocxBuiltDocument(elements: [
      DocxParagraph(children: [
        DocxText('before break'),
        const DocxLineBreak(isPageBreak: true),
      ]),
      para('after break'),
    ]));
    expect(res.pages.length, 2);
  });

  test('mid-paragraph page break splits the paragraph (§D.2.5)', () {
    final res = paginator.paginate(DocxBuiltDocument(elements: [
      DocxParagraph(children: [
        DocxText('before'),
        const DocxLineBreak(isPageBreak: true),
        DocxText('after'),
      ]),
    ]));
    expect(res.pages.length, 2);
    expect(res.pages[0].slices.single.block, isA<DocxParagraph>());
    String text(PageModel p) => p.slices
        .expand((s) => (s.block as DocxParagraph).children)
        .whereType<DocxText>()
        .map((t) => t.content)
        .join();
    expect(text(res.pages[0]), 'before');
    expect(text(res.pages[1]), 'after');
  });

  test('a break-only paragraph does not create a blank page', () {
    // A paragraph whose only content is a page break must not waste a page: it
    // ends the current page, and the next block opens the next one (not a third).
    final res = paginator.paginate(DocxBuiltDocument(elements: [
      para('a'),
      DocxParagraph(children: const [DocxLineBreak(isPageBreak: true)]),
      para('b'),
    ]));
    expect(res.pages.length, 2);
    expect(res.pages.every((p) => p.slices.isNotEmpty), isTrue);
  });

  test('section break (nextPage) starts a new page and section index', () {
    final res = paginator.paginate(DocxBuiltDocument(elements: [
      para('section one'),
      const DocxSectionBreakBlock(DocxSectionDef()),
      para('section two'),
    ]));
    expect(res.pages.length, 2);
    expect(res.pages[0].sectionIndex, 0);
    expect(res.pages[1].sectionIndex, 1);
    expect(res.pages[1].isFirstPageOfSection, isTrue);
  });

  test('pgNumType start offsets the display number; NUMPAGES = page count', () {
    final paras = List.generate(3, (_) => para('x'));
    final res = paginator.paginate(DocxBuiltDocument(
      elements: paras,
      section: const DocxSectionDef(pageNumberStart: 5),
    ));
    expect(res.pages.first.pageNumber, 5);
    // Numbers increment per page from the start offset.
    for (var i = 0; i < res.pages.length; i++) {
      expect(res.pages[i].pageNumber, 5 + i);
    }
  });

  test('oddPage section break inserts a blank filler page for parity', () {
    // `w:type` describes how the section it belongs to *begins*, so the second
    // section's oddPage break lives on the document's trailing section (run1).
    // Section one ends on page 1; the next number would be 2 (even), so reaching
    // an odd page requires a blank filler page 2, putting section two on page 3.
    final res = paginator.paginate(DocxBuiltDocument(
      elements: [
        para('one'),
        const DocxSectionBreakBlock(DocxSectionDef()),
        para('three'),
      ],
      section: const DocxSectionDef(breakType: DocxSectionBreak.oddPage),
    ));
    // page 1 = section one, page 2 = blank filler, page 3 = section two.
    expect(res.pages.length, 3);
    expect(res.pages[1].isBlank, isTrue);
    expect(res.pages[1].slices, isEmpty);
    expect(res.pages[2].pageNumber.isOdd, isTrue);
    expect(res.pages[2].slices, isNotEmpty);
  });

  group('paragraph splitting (M4)', () {
    // Exact line spacing gives a deterministic 20px per line.
    DocxParagraph longExact(String text) => DocxParagraph(
          lineRule: 'exact',
          lineSpacing: 300, // 20px/line
          widowControl: false,
          children: [DocxText(text)],
        );

    test('a tall paragraph splits across pages and the text round-trips', () {
      final words = List.generate(200, (i) => 'word$i').join(' ');
      final p = longExact(words);
      final full = words;

      final res = paginator.paginate(DocxBuiltDocument(elements: [p]));
      expect(res.pages.length, greaterThan(1));

      // No page overflows its body height.
      for (final page in res.pages) {
        expect(page.usedHeight, lessThanOrEqualTo(_bodyH + 0.5));
      }
      // The head slice is a *different* (sliced) paragraph, not the original.
      expect(identical(res.pages.first.slices.first.block, p), isFalse);
      // Every character survives the split, in order.
      expect(allText(res), full);
    });

    test('keepLines paragraph is never split (moves whole)', () {
      final words = List.generate(200, (i) => 'w$i').join(' ');
      final tall = DocxParagraph(
        lineRule: 'exact',
        lineSpacing: 300,
        keepLines: true,
        children: [DocxText(words)],
      );
      final res = paginator.paginate(DocxBuiltDocument(elements: [
        para('short first'),
        tall,
      ]));
      // The tall paragraph appears whole on a page (never sliced): exactly one
      // slice references the original object.
      final wholeRefs = res.pages
          .expand((p) => p.slices)
          .where((s) => identical(s.block, tall))
          .length;
      expect(wholeRefs, 1);
    });

    test('widowControl keeps at least two lines on each side of a break', () {
      // 12 lines at 20px = 240px > body (208). Without widow control the split
      // could leave a single line; with it, both sides keep ≥ 2 lines.
      final words = List.generate(120, (i) => 'x$i').join(' ');
      final p = DocxParagraph(
        lineRule: 'exact',
        lineSpacing: 300,
        // widowControl defaults to true.
        children: [DocxText(words)],
      );
      final res = paginator.paginate(DocxBuiltDocument(elements: [p]));
      expect(res.pages.length, greaterThan(1));
      // Each page's paragraph slice must hold ≥ 2 lines (20px/line).
      for (final page in res.pages) {
        if (page.slices.isEmpty) continue;
        final block = page.slices.first.block as DocxParagraph;
        final lines = measurer.measureParagraph(block, _contentW).lineCount;
        expect(lines, greaterThanOrEqualTo(2),
            reason: 'page ${page.absoluteIndex} left a widow/orphan');
      }
    });

    test('widow guard: a 3-line para that would leave a lone line is not split',
        () {
      // Tiny page whose body fits exactly 2 lines (20px each): pageH 240 →
      // body 48. A 3-line paragraph would split fit=2/total=3 → the widow rule
      // pushes the last line down, leaving 1 line on the head — an orphan. The
      // guard must instead refuse the split and place the paragraph whole.
      final tiny = const DocxViewConfig(
        pageWidth: _pageW,
        pageHeight: 240,
        enableSelection: false,
      );
      final sf = SpanFactory(
        theme: DocxViewTheme.light(),
        config: tiny,
        docxTheme: DocxTheme.empty(),
      );
      final pg =
          Paginator(measurer: TextMeasurer(spanFactory: sf), config: tiny);

      // Exactly three visual lines via explicit breaks (width-independent).
      final p = DocxParagraph(
        lineRule: 'exact',
        lineSpacing: 300, // 20px/line
        children: const [
          DocxText('a'),
          DocxLineBreak(),
          DocxText('b'),
          DocxLineBreak(),
          DocxText('c'),
        ],
      );
      final res = pg.paginate(DocxBuiltDocument(elements: [p]));
      // Placed whole (clamped), never sliced into a 1-line orphan head.
      final refs = res.pages
          .expand((page) => page.slices)
          .where((s) => identical(s.block, p))
          .length;
      expect(refs, 1, reason: 'must not split into an orphan');
    });
  });

  test('bookmarks survive a paragraph split and map to the right page', () {
    // A bookmark in the head half maps to page 1; one in the tail half maps to
    // a later page. The split must not silently drop either (PAGEREF).
    final headWords = List.generate(120, (i) => 'h$i').join(' ');
    final tailWords = List.generate(40, (i) => 't$i').join(' ');
    final p = DocxParagraph(
      lineRule: 'exact',
      lineSpacing: 300,
      widowControl: false,
      children: [
        const DocxBookmark('top'),
        DocxText('$headWords '),
        const DocxBookmark('mid'),
        DocxText(' $tailWords'),
      ],
    );
    final res = paginator.paginate(DocxBuiltDocument(elements: [p]));
    expect(res.pages.length, greaterThan(1));
    expect(res.bookmarkPages['top'], 1, reason: 'head-half bookmark');
    expect(res.bookmarkPages['mid'], greaterThan(1),
        reason: 'tail-half bookmark');
  });

  test('an oversized non-splittable block is clamped onto one page', () {
    // A keepLines paragraph taller than the body cannot split → it is placed
    // whole (overflow tolerated, §D.2.6) rather than dropped.
    final words = List.generate(200, (i) => 'w$i').join(' ');
    final p = DocxParagraph(
      lineRule: 'exact',
      lineSpacing: 300,
      keepLines: true,
      children: [DocxText(words)],
    );
    final res = paginator.paginate(DocxBuiltDocument(elements: [p]));
    expect(res.pages.length, 1);
    expect(identical(res.pages.first.slices.first.block, p), isTrue);
    // The clamp intentionally exceeds the body height.
    expect(res.pages.first.usedHeight, greaterThan(_bodyH));
  });

  test('keepNext keeps a pair together by moving the group to a fresh page',
      () {
    final h = bodyParaHeight('filler');
    final perPage = (_bodyH / h).floor();
    expect(perPage, greaterThanOrEqualTo(2));

    // Fill all but one slot on page 1, then a keepNext pair that cannot both fit
    // in the last slot — they should move together to page 2.
    final fillers = List.generate(perPage - 1, (_) => para('filler'));
    final pair = [
      DocxParagraph(keepWithNext: true, children: [DocxText('PAIR_A')]),
      para('PAIR_B'),
    ];
    final res =
        paginator.paginate(DocxBuiltDocument(elements: [...fillers, ...pair]));

    // Find which page each pair member landed on.
    int pageOf(String text) {
      for (var i = 0; i < res.pages.length; i++) {
        for (final slice in res.pages[i].slices) {
          final b = slice.block;
          if (b is DocxParagraph &&
              b.children.any((c) => c is DocxText && c.content == text)) {
            return i;
          }
        }
      }
      return -1;
    }

    expect(pageOf('PAIR_A'), isNonNegative);
    expect(pageOf('PAIR_A'), pageOf('PAIR_B'),
        reason: 'keepNext pair must share a page');
  });

  test('bookmark map records the display page a bookmark lands on', () {
    final h = bodyParaHeight('line');
    final perPage = (_bodyH / h).floor();
    final before = List.generate(perPage, (_) => para('line')); // fills page 1
    final marked = DocxParagraph(children: const [
      DocxBookmark('target'),
      DocxText('bookmarked'),
    ]);
    final res = paginator.paginate(DocxBuiltDocument(
      elements: [...before, marked],
      section: const DocxSectionDef(pageNumberStart: 1),
    ));
    // The bookmark paragraph overflows page 1 → lands on page 2 (number 2).
    expect(res.bookmarkPages['target'], 2);
  });

  test('RTL/mixed paragraph splits without error and round-trips', () {
    final mixed =
        List.generate(80, (i) => i.isEven ? 'שלום$i' : 'world$i').join(' ');
    final p = DocxParagraph(
      isRtl: true,
      lineRule: 'exact',
      lineSpacing: 300,
      widowControl: false,
      children: [DocxText(mixed)],
    );
    final res = paginator.paginate(DocxBuiltDocument(elements: [p]));
    expect(res.pages.length, greaterThan(1));
    expect(allText(res), mixed);
  });

  group('table splitting (M5)', () {
    DocxTableRow trow(String text, {bool header = false}) => DocxTableRow(
          isHeader: header,
          cells: [
            DocxTableCell(children: [
              DocxParagraph(
                lineRule: 'exact',
                lineSpacing: 300, // 20px line
                children: [DocxText(text)],
              ),
            ]),
          ],
        );

    String rowText(DocxTableRow r) {
      final p = r.cells.first.children.first as DocxParagraph;
      return (p.children.first as DocxText).content;
    }

    test('a tall table splits between rows and round-trips body rows', () {
      final body = List.generate(20, (i) => trow('body$i'));
      final table = DocxTable(rows: [trow('HEAD', header: true), ...body]);

      final res = paginator.paginate(DocxBuiltDocument(elements: [table]));
      expect(res.pages.length, greaterThan(1));

      final seenBody = <String>[];
      for (final page in res.pages) {
        expect(page.usedHeight, lessThanOrEqualTo(_bodyH + 0.5));
        for (final slice in page.slices) {
          final t = slice.block as DocxTable;
          // Header row repeats at the top of every continuation.
          expect(t.rows.first.isHeader, isTrue);
          for (final r in t.rows.skip(1)) {
            seenBody.add(rowText(r));
          }
        }
      }
      // Every body row appears exactly once, in order.
      expect(seenBody, List.generate(20, (i) => 'body$i'));
    });

    test('a table that fits is placed whole by reference', () {
      final table = DocxTable(rows: [trow('only row')]);
      final res = paginator.paginate(DocxBuiltDocument(elements: [table]));
      expect(res.pages.length, 1);
      expect(identical(res.pages.first.slices.first.block, table), isTrue);
    });
  });

  test('slices never duplicate the inline tree for whole blocks', () {
    final p = para('shared by reference');
    final res = paginator.paginate(DocxBuiltDocument(elements: [p]));
    // A whole (un-split) block is stored by reference, not cloned.
    expect(identical(res.pages.first.slices.first.block, p), isTrue);
  });

  group('QA F8: auto-row measurement tracks content (no 18px floor)', () {
    DocxTable oneRow(DocxTableRow row) =>
        DocxTable(gridColumns: const [5000], rows: [row]);

    double measuredHeight(DocxTable t) => paginator
        .paginate(DocxBuiltDocument(elements: [t]))
        .pages
        .first
        .slices
        .first
        .height;

    test('an empty auto row imposes no minimum height', () {
      // The renderer (_buildRow) adds no floor to an auto row, so the measurer
      // must not either — the old _minRowHeightPx=18 over-estimated it.
      final h = measuredHeight(
          oneRow(const DocxTableRow(cells: [DocxTableCell(children: [])])));
      expect(h, lessThan(18.0),
          reason: 'an auto row sizes to its (empty) content, not a 18px floor');
    });

    test('an atLeast row still floors to its height (unchanged)', () {
      // 2000tw ÷ 15 = 133.3px, far above any single-line content.
      final h = measuredHeight(oneRow(DocxTableRow(
        height: 2000,
        heightRule: DocxTableRowHeightRule.atLeast,
        cells: [
          DocxTableCell(children: [para('x')])
        ],
      )));
      expect(h, closeTo(2000 / 15, 0.5));
    });
  });
}
