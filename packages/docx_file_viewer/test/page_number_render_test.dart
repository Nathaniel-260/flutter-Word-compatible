import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Collects the plain text of every RichText in the tree.
  List<String> richTexts(WidgetTester tester) => tester
      .widgetList<RichText>(find.byType(RichText))
      .map((r) => r.text.toPlainText())
      .toList();

  testWidgets('footer PAGE/NUMPAGES render per-page across a paged document',
      (tester) async {
    // Enough body paragraphs to spill onto several short pages.
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

    final doc = DocxBuiltDocument(
      elements: body,
      section: DocxSectionDef(footer: footer),
    );

    const config = DocxViewConfig(
      pageMode: DocxPageMode.paged,
      pageHeight: 260, // force multiple short pages
      enableSelection: false, // body/footer render as RichText
      enableZoom: false,
    );
    final widgets = DocxWidgetGenerator(config: config).generateWidgets(doc);
    expect(widgets.length, greaterThanOrEqualTo(2),
        reason: 'expected the document to paginate');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: widgets),
        ),
      ),
    ));

    final texts = richTexts(tester);
    final total = widgets.length;
    // Each page's footer shows its own number, all sharing the same total.
    expect(texts, contains('Page 1 of $total'));
    expect(texts, contains('Page 2 of $total'));
    // The cached "1" is not repeated on every page.
    final footers = texts.where((t) => t.startsWith('Page ')).toSet();
    expect(footers.length, greaterThanOrEqualTo(2));
  });
}
