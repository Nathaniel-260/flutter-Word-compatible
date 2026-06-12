import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/pagination/page_model.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Streaming paged display (Plan §D.2.9 / §D.3 / §4.4): the generator streams
/// page models as they are laid out and builds each page widget lazily, so the
/// host can show pages as they are born with a placeholder tail.
///
/// Note on async: [DocxWidgetGenerator.paginateStreaming] yields the UI thread
/// (`Future.delayed`) for time-slicing, which never resolves inside a
/// `testWidgets` fake-async zone. So pagination runs in a plain `test()` (real
/// async) or, when a widget tree is needed, under `tester.runAsync`.
void main() {
  List<String> richTexts(WidgetTester tester) => tester
      .widgetList<RichText>(find.byType(RichText))
      .map((r) => r.text.toPlainText())
      .toList();

  DocxBuiltDocument makeDoc() {
    final body = <DocxNode>[
      for (var i = 0; i < 30; i++)
        DocxParagraph(children: [DocxText('Body paragraph number $i')]),
    ];
    final footer = DocxFooter(children: [
      DocxParagraph(children: const [
        DocxText('Page '),
        DocxPageNumber(),
        DocxText(' of '),
        DocxPageCount(),
      ]),
    ]);
    return DocxBuiltDocument(
      elements: body,
      section: DocxSectionDef(footer: footer),
    );
  }

  const config = DocxViewConfig(
    pageMode: DocxPageMode.paged,
    pageHeight: 260, // force several short pages
    enableSelection: false,
    enableZoom: false,
  );

  test('paginateStreaming emits every page and caches the result', () async {
    final doc = makeDoc();
    final gen = DocxWidgetGenerator(config: config);

    final streamed = <PageModel>[];
    final result = await gen.paginateStreaming(doc, onPage: streamed.add);

    expect(streamed.length, greaterThanOrEqualTo(2),
        reason: 'document should paginate into several pages');
    expect(streamed.length, result.pageCount,
        reason: 'every page is emitted exactly once');
    expect(identical(gen.lastPagination, result), isTrue,
        reason: 'streaming stores the result for slice-aligned search');
  });

  testWidgets('buildPageWidget renders a page with final NUMPAGES once done',
      (tester) async {
    final doc = makeDoc();
    final gen = DocxWidgetGenerator(config: config);
    final result = (await tester
        .runAsync(() => gen.paginateStreaming(doc, onPage: (_) {})))!;

    final firstPage =
        gen.buildPageWidget(doc, result.pages, 0, finalResult: result);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: firstPage)),
    ));

    expect(richTexts(tester), contains('Page 1 of ${result.pageCount}'));
  });

  testWidgets('NUMPAGES is provisional while streaming, final when complete',
      (tester) async {
    final doc = makeDoc();
    final gen = DocxWidgetGenerator(config: config);
    final result = (await tester
        .runAsync(() => gen.paginateStreaming(doc, onPage: (_) {})))!;

    // While streaming, only the pages seen so far are known: page 1 with just
    // itself visible resolves NUMPAGES to the running total (1), not the final.
    final provisional = gen.buildPageWidget(doc, [result.pages.first], 0);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: provisional)),
    ));
    expect(richTexts(tester), contains('Page 1 of 1'),
        reason: 'NUMPAGES uses the running total until pagination completes');

    // Once finalResult is supplied the same page settles to the real total.
    final settled =
        gen.buildPageWidget(doc, result.pages, 0, finalResult: result);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: settled)),
    ));
    expect(richTexts(tester), contains('Page 1 of ${result.pageCount}'));
  });

  test('page placeholder dimensions match the configured page geometry', () {
    final doc = makeDoc();
    final gen = DocxWidgetGenerator(config: config);

    // Config overrides drive the placeholder size so the scrollbar is stable.
    expect(gen.pageDisplayHeight(doc.section), 260);
    expect(gen.pageDisplayWidth(doc.section), greaterThan(0));
  });

  testWidgets('empty paged document streams one renderable blank page',
      (tester) async {
    const empty = DocxBuiltDocument(elements: []);
    final gen = DocxWidgetGenerator(config: config);
    final result = (await tester
        .runAsync(() => gen.paginateStreaming(empty, onPage: (_) {})))!;

    // Word shows a blank page for an empty document (not an "empty" message).
    expect(result.pageCount, 1);
    expect(result.truncated, isFalse);

    final blank =
        gen.buildPageWidget(empty, result.pages, 0, finalResult: result);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: blank)),
    ));
    expect(tester.takeException(), isNull);
  });
}
