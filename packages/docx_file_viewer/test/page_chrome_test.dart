import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:docx_file_viewer/src/widgets/page_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Part E — page chrome: fixed page height, vertical alignment (`w:vAlign`),
/// page borders (`w:pgBorders`), section background, and Hebrew page numbers.
void main() {
  const config = DocxViewConfig(
    pageMode: DocxPageMode.paged,
    pageWidth: 400,
    pageHeight: 600,
    enableSelection: false,
    enableZoom: false,
  );

  List<String> richTexts(WidgetTester tester) => tester
      .widgetList<RichText>(find.byType(RichText))
      .map((r) => r.text.toPlainText())
      .toList();

  // The page paper Container is the one carrying the drop shadow.
  Finder pageContainer() => find.byWidgetPredicate((w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).boxShadow != null);

  Future<void> pumpFirstPage(WidgetTester tester, DocxBuiltDocument doc) async {
    final widgets = DocxWidgetGenerator(config: config).generateWidgets(doc);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: widgets.first)),
    ));
  }

  DocxParagraph para(String t) => DocxParagraph(children: [DocxText(t)]);

  testWidgets('page renders at the exact fixed height (§E.2)', (tester) async {
    final doc = DocxBuiltDocument(
      elements: [para('Short body')],
      section: const DocxSectionDef(),
    );
    await pumpFirstPage(tester, doc);

    expect(tester.takeException(), isNull);
    expect(tester.getSize(pageContainer().first).height, 600);
  });

  testWidgets('w:vAlign maps to PageBody alignment/stretch (§E.1.3)',
      (tester) async {
    for (final (align, expectedAlign, expectedStretch) in const [
      (DocxSectionVAlign.top, Alignment.topCenter, false),
      (DocxSectionVAlign.center, Alignment.center, false),
      (DocxSectionVAlign.bottom, Alignment.bottomCenter, false),
      (DocxSectionVAlign.both, Alignment.topCenter, true),
    ]) {
      final doc = DocxBuiltDocument(
        elements: [para('Body')],
        section: DocxSectionDef(vAlign: align),
      );
      await pumpFirstPage(tester, doc);
      expect(
        find.byWidgetPredicate((w) =>
            w is PageBody &&
            w.alignment == expectedAlign &&
            w.stretch == expectedStretch),
        findsOneWidget,
        reason: 'vAlign $align → align=$expectedAlign stretch=$expectedStretch',
      );
    }
  });

  testWidgets('an over-tall body clips without asserting and warns in debug',
      (tester) async {
    // A keepLines paragraph far taller than the content region cannot be split,
    // so the paginator clamps it onto one page — exercising the fixed-height
    // clip path. It must not assert, and must warn (debug telltale, §D.2.6/§E).
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) {
      if (m != null) messages.add(m);
    };
    try {
      final huge = DocxParagraph(
        keepLines: true,
        children: [DocxText('overflow ${'word ' * 2000}')],
      );
      await pumpFirstPage(tester,
          DocxBuiltDocument(elements: [huge], section: const DocxSectionDef()));

      expect(tester.takeException(), isNull,
          reason: 'fixed height clips; it must never assert/crash');
      expect(messages.any((m) => m.contains('overflows the content region')),
          isTrue,
          reason: 'the debug overflow telltale must fire');
    } finally {
      debugPrint = original;
    }
  });

  testWidgets(
      'w:pgBorders draws a PageBorderPainter only when present (§E.1.4)',
      (tester) async {
    Finder borderPaint() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PageBorderPainter);

    // No borders → no painter.
    await pumpFirstPage(
        tester,
        DocxBuiltDocument(
            elements: [para('x')], section: const DocxSectionDef()));
    expect(borderPaint(), findsNothing);

    // Double red top+bottom+left+right → painter present.
    const side = DocxBorderSide(style: DocxBorder.double, color: DocxColor.red);
    await pumpFirstPage(
      tester,
      DocxBuiltDocument(
        elements: [para('x')],
        section: const DocxSectionDef(
          pageBorders:
              DocxPageBorders(top: side, bottom: side, left: side, right: side),
        ),
      ),
    );
    expect(borderPaint(), findsOneWidget);
  });

  testWidgets('dashed/dotted/triple page borders render without error (item 13)',
      (tester) async {
    Finder borderPaint() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PageBorderPainter);
    for (final style in const [
      DocxBorder.dashed,
      DocxBorder.dotted,
      DocxBorder.triple,
    ]) {
      final side = DocxBorderSide(style: style, color: DocxColor.black, size: 16);
      await pumpFirstPage(
        tester,
        DocxBuiltDocument(
          elements: [para('x')],
          section: DocxSectionDef(
            pageBorders: DocxPageBorders(
                top: side, bottom: side, left: side, right: side),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'style $style must paint');
      expect(borderPaint(), findsOneWidget, reason: 'style $style');
    }
  });

  testWidgets('zOrder=back paints the frame behind the body (item 12)',
      (tester) async {
    const side = DocxBorderSide(color: DocxColor.black);
    final doc = DocxBuiltDocument(
      elements: [para('x')],
      section: const DocxSectionDef(
        pageBorders: DocxPageBorders(
          zOrderBack: true,
          top: side,
          bottom: side,
          left: side,
          right: side,
        ),
      ),
    );
    await pumpFirstPage(tester, doc);
    expect(tester.takeException(), isNull);
    // The page Stack lists the border CustomPaint *before* the PageBody, so it
    // paints underneath (front would list it last).
    final stack = tester.widgetList<Stack>(find.byType(Stack)).firstWhere((s) =>
        s.children.any((c) =>
            c is Positioned &&
            c.child is CustomPaint &&
            (c.child as CustomPaint).painter is PageBorderPainter));
    final borderIdx = stack.children.indexWhere((c) =>
        c is Positioned &&
        c.child is CustomPaint &&
        (c.child as CustomPaint).painter is PageBorderPainter);
    final bodyIdx = stack.children.indexWhere(
        (c) => c is Positioned && c.child is PageBody);
    expect(borderIdx, lessThan(bodyIdx),
        reason: 'back frame must precede the body in the Stack');
  });

  testWidgets('firstPage-only borders are gated by the page position (§E.1.4)',
      (tester) async {
    const side = DocxBorderSide(color: DocxColor.black);
    final doc = DocxBuiltDocument(
      elements: [
        for (var i = 0; i < 40; i++) para('Paragraph number $i for spilling'),
      ],
      section: const DocxSectionDef(
        pageBorders: DocxPageBorders(
          display: DocxPageBorderDisplay.firstPage,
          top: side,
          bottom: side,
        ),
      ),
    );
    final widgets = DocxWidgetGenerator(config: config).generateWidgets(doc);
    expect(widgets.length, greaterThan(1), reason: 'should paginate');

    Finder borderIn(Widget page) => find.descendant(
          of: find.byWidget(page),
          matching: find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is PageBorderPainter),
        );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [for (final w in widgets) Center(child: w)]),
      ),
    ));
    // First page has the border; a later page does not.
    expect(borderIn(widgets.first), findsOneWidget);
    expect(borderIn(widgets.last), findsNothing);
  });

  testWidgets('section background colour fills the page paper (§E.1.1)',
      (tester) async {
    final doc = DocxBuiltDocument(
      elements: [para('x')],
      section: const DocxSectionDef(backgroundColor: DocxColor.red),
    );
    await pumpFirstPage(tester, doc);

    final container = tester.widget<Container>(pageContainer().first);
    final color = (container.decoration as BoxDecoration).color;
    expect(color, const Color(0xFFFF0000));
  });

  testWidgets('Hebrew page numbers render via the footer field (§E.2)',
      (tester) async {
    final doc = DocxBuiltDocument(
      elements: [para('Body')],
      section: DocxSectionDef(
        pageNumberFormat: DocxPageNumberFormat.hebrew1,
        footer: DocxFooter(children: [
          DocxParagraph(children: const [DocxPageNumber()]),
        ]),
      ),
    );
    await pumpFirstPage(tester, doc);

    // Page 1 in hebrew1 (gematria) is א.
    expect(richTexts(tester), contains('א'));
  });
}
