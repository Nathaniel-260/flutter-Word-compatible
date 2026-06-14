import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:docx_file_viewer/src/widgets/page_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression for "the body text hides under the footer" (Plan §D.2.1 / §E.1.3).
///
/// Root cause: the body region was inset by the raw bottom margin only, while
/// the footer (positioned in the margin band, and inflated by a spurious
/// Material `Divider`) could be taller than that margin — so it painted over the
/// body's last line. The fix reserves `max(margin, footerDist + footerHeight)`
/// for the body, computed once by the paginator and reused by the renderer, and
/// drops the injected divider.
void main() {
  const config = DocxViewConfig(
    pageMode: DocxPageMode.paged,
    pageWidth: 400,
    pageHeight: 600,
    enableSelection: false,
    enableZoom: false,
  );

  DocxParagraph para(String t) => DocxParagraph(children: [DocxText(t)]);

  testWidgets('a tall footer never overlaps the page body region',
      (tester) async {
    // A multi-paragraph footer taller than the bottom margin band — without the
    // reserve, the body region would extend down over it.
    final doc = DocxBuiltDocument(
      elements: [
        for (var i = 0; i < 40; i++) para('Body line $i fills the page')
      ],
      section: DocxSectionDef(
        footer: DocxFooter(children: [
          for (var i = 0; i < 4; i++)
            DocxParagraph(children: [DocxText('FOOT line $i')]),
        ]),
      ),
    );

    final widgets = DocxWidgetGenerator(config: config).generateWidgets(doc);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: widgets.first)),
    ));
    expect(tester.takeException(), isNull);

    // The body region (PageBody) bottom must sit at or above the footer's top —
    // i.e. the body is reserved out of the footer band, not painted over it.
    final bodyRect = tester.getRect(find.byType(PageBody));
    final footerLine = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('FOOT line 0'));
    expect(footerLine, findsOneWidget);
    final footerLineTop = tester.getRect(footerLine).top;

    expect(bodyRect.bottom, lessThanOrEqualTo(footerLineTop + 0.5),
        reason: 'body region must not extend over the footer '
            '(bodyBottom=${bodyRect.bottom}, footerTop=$footerLineTop)');
  });

  testWidgets('paged footer no longer injects a Material Divider',
      (tester) async {
    final doc = DocxBuiltDocument(
      elements: [para('body')],
      section: DocxSectionDef(footer: DocxFooter.text('Just a footer')),
    );
    final widgets = DocxWidgetGenerator(config: config).generateWidgets(doc);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: widgets.first)),
    ));

    expect(find.byType(Divider), findsNothing,
        reason: 'Word draws no divider above the footer; the page already '
            'reserves the footer band');
  });
}
