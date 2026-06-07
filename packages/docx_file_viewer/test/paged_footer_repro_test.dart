import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Mirrors the real DocxView paged path: pages are emitted into a
  // ListView.builder, each item wrapped in Center. The ListView gives each
  // page an *unbounded* main-axis (vertical) height — the condition that
  // triggers the "RenderBox was not laid out / child.hasSize is not true"
  // cascade reported at the end of a paged document with a footer.
  // A table whose cell contains another table. The parent row is wrapped in an
  // IntrinsicHeight; rendering the nested table with the page-level LayoutBuilder
  // autofit wrapper throws "LayoutBuilder does not support returning intrinsic
  // dimensions", which is the real root cause behind the reported crash.
  DocxTable nestedTable() {
    final inner = DocxTable(
      gridColumns: const [1200, 1200],
      rows: const [
        DocxTableRow(cells: [
          DocxTableCell(children: [
            DocxParagraph(children: [DocxText('inner A')])
          ]),
          DocxTableCell(children: [
            DocxParagraph(children: [DocxText('inner B')])
          ]),
        ]),
      ],
    );
    return DocxTable(
      gridColumns: const [4000, 4000],
      rows: [
        DocxTableRow(cells: [
          DocxTableCell(children: [inner]),
          const DocxTableCell(children: [
            DocxParagraph(children: [DocxText('outer cell')])
          ]),
        ]),
      ],
    );
  }

  testWidgets('paged document with a footer and nested table lays out cleanly',
      (tester) async {
    final body = <DocxNode>[
      for (var i = 0; i < 40; i++)
        DocxParagraph(children: [DocxText('Paragraph number $i with some text.')]),
      nestedTable(),
    ];

    final doc = DocxBuiltDocument(
      elements: body,
      section: DocxSectionDef(
        footer: DocxFooter.text('Footer line'),
      ),
    );

    final generator = DocxWidgetGenerator(
      config: const DocxViewConfig(pageMode: DocxPageMode.paged),
    );
    final widgets = generator.generateWidgets(doc);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: widgets.length,
            itemBuilder: (context, i) => Center(child: widgets[i]),
          ),
        ),
      ),
    );

    // Scroll to the very end (where the lazy ListView builds the last pages).
    await tester.fling(find.byType(ListView), const Offset(0, -5000), 1000);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
