import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/search/docx_search_controller.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §M.1: search navigates to a match's *page* (block→page map) and injects
/// highlights into lazily-built pages with a seeded counter — no document-wide
/// regeneration and no per-block GlobalKeys.
void main() {
  const config = DocxViewConfig(
    pageMode: DocxPageMode.paged,
    pageHeight: 260,
    enableSelection: false,
  );

  group('pageForBlock (Plan §M.1)', () {
    test('maps every page\'s first/last body block to that page', () {
      final body = <DocxNode>[
        for (var i = 0; i < 40; i++)
          DocxParagraph(children: [DocxText('Paragraph $i')]),
      ];
      final doc =
          DocxBuiltDocument(elements: body, section: const DocxSectionDef());
      final gen = DocxWidgetGenerator(config: config);
      gen.generateWidgets(doc); // populates lastPagination
      final result = gen.lastPagination!;
      expect(result.pageCount, greaterThan(1),
          reason: 'the doc must span several pages for the map to matter');

      // No header here, so body block indices start at 0. Each short paragraph
      // is one slice → one block. Walk the real pages to derive the expected
      // first/last block of each page and check the map agrees.
      var start = 0;
      for (var i = 0; i < result.pages.length; i++) {
        final count = result.pages[i].slices.length;
        expect(gen.pageForBlock(doc, start), i,
            reason: 'first body block of page $i');
        expect(gen.pageForBlock(doc, start + count - 1), i,
            reason: 'last body block of page $i');
        start += count;
      }
      // A block index past the last body block (e.g. footer) clamps to the last
      // page rather than throwing.
      expect(gen.pageForBlock(doc, start + 5), result.pages.length - 1);
    });

    test('header blocks map to page 0 and offset the body', () {
      final header = DocxHeader(children: [
        DocxParagraph(children: const [DocxText('Running head')]),
      ]);
      final body = <DocxNode>[
        for (var i = 0; i < 30; i++)
          DocxParagraph(children: [DocxText('Body $i')]),
      ];
      final doc = DocxBuiltDocument(
        elements: body,
        section: DocxSectionDef(header: header),
      );
      final gen = DocxWidgetGenerator(config: config);
      gen.generateWidgets(doc);
      final result = gen.lastPagination!;

      // One header paragraph → block 0 is the header, mapping to page 0.
      expect(gen.pageForBlock(doc, 0), 0);
      // The first body block (index 1) is also on page 0.
      expect(gen.pageForBlock(doc, 1), 0);
      // Sanity: the very last body block sits on the last page.
      final lastBody =
          1 + result.pages.fold<int>(0, (n, p) => n + p.slices.length) - 1;
      expect(gen.pageForBlock(doc, lastBody), result.pages.length - 1);
    });

    test('returns -1 before any pagination', () {
      final gen = DocxWidgetGenerator(config: config);
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph(children: const [DocxText('x')])
      ], section: const DocxSectionDef());
      expect(gen.pageForBlock(doc, 0), -1);
    });
  });

  testWidgets('a search match on a later page lands on that page, highlighted',
      (tester) async {
    // 'NEEDLE' appears once, deep in the document, so it must fall on a later
    // page. The match's block index → that page via the map; building that page
    // with search active seeds the highlight counter so the text renders there.
    final body = <DocxNode>[
      for (var i = 0; i < 40; i++)
        DocxParagraph(
            children: [DocxText(i == 33 ? 'a NEEDLE here' : 'filler $i')]),
    ];
    final doc =
        DocxBuiltDocument(elements: body, section: const DocxSectionDef());
    final search = DocxSearchController();
    final gen = DocxWidgetGenerator(config: config, searchController: search);
    gen.generateWidgets(doc);
    final result = gen.lastPagination!;

    search.setDocument(gen.extractTextForSearch(doc));
    search.search('NEEDLE');
    expect(search.matchCount, 1);

    final match = search.matches.first;
    final page = gen.pageForBlock(doc, match.blockIndex);
    expect(page, greaterThan(0), reason: 'the needle is on a later page');

    // Build just that page lazily, with search active, and confirm the matched
    // text renders on it (highlight injection through the seeded counter).
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child:
              gen.buildPageWidget(doc, result.pages, page, finalResult: result),
        ),
      ),
    ));
    // Selection is off → paragraphs render as RichText. Walk every span and
    // confirm the matched text not only renders here but is *highlighted* (the
    // seeded counter injected the match) — the current match gets an orange
    // background. Checking the style, not just text presence, is what proves the
    // highlight landed on the right page.
    TextSpan? highlighted;
    for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
      rt.text.visitChildren((span) {
        if (span is TextSpan &&
            span.text == 'NEEDLE' &&
            span.style?.backgroundColor != null) {
          highlighted = span;
          return false; // stop
        }
        return true;
      });
      if (highlighted != null) break;
    }
    expect(highlighted, isNotNull,
        reason: 'the match must render highlighted on its mapped page');
    expect(highlighted!.style!.backgroundColor, Colors.orange.shade300,
        reason: 'the current match uses the current-match highlight colour');
  });
}
