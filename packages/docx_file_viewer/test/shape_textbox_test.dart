import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:docx_file_viewer/src/widget_generator/shape_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §H — a text box (`DocxShape.textBlocks`) renders its real block content
/// by re-entering the generator, instead of a single flat centred string.
void main() {
  testWidgets('an inline text box renders its block content', (tester) async {
    const config = DocxViewConfig(pageMode: DocxPageMode.continuous);
    final shape = DocxShape(
      width: 220,
      height: 90,
      position: DocxDrawingPosition.inline,
      textBlocks: [
        DocxParagraph(children: [
          DocxText('Boxed heading', fontWeight: DocxFontWeight.bold),
        ]),
        DocxParagraph(children: [DocxText('A second line in the box')]),
      ],
    );
    final doc = DocxBuiltDocument(
      elements: [
        DocxParagraph(children: [shape])
      ],
    );

    final widgets = DocxWidgetGenerator(config: config).generateWidgets(doc);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: Column(children: widgets)),
      ),
    ));

    expect(find.textContaining('Boxed heading'), findsOneWidget);
    expect(find.textContaining('A second line in the box'), findsOneWidget);
  });

  testWidgets('ShapeBuilder falls back to flat text without a block builder',
      (tester) async {
    // No textBlockBuilder wired → the flat [text] is rendered as a centred label.
    final builder = ShapeBuilder(config: const DocxViewConfig());
    final shape = DocxShape(width: 120, height: 60, text: 'Flat label');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: builder.buildInlineShape(shape))),
    ));

    expect(find.text('Flat label'), findsOneWidget);
  });

  testWidgets('text-box blocks win over flat text when a builder is wired',
      (tester) async {
    final builder = ShapeBuilder(
      config: const DocxViewConfig(),
      textBlockBuilder: (blocks) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final b in blocks)
            if (b is DocxParagraph)
              Text((b.children.first as DocxText).content),
        ],
      ),
    );
    final shape = DocxShape(
      width: 120,
      height: 60,
      text: 'flat fallback',
      textBlocks: [
        DocxParagraph(children: [DocxText('rich content')]),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: builder.buildInlineShape(shape))),
    ));

    expect(find.text('rich content'), findsOneWidget);
    expect(find.text('flat fallback'), findsNothing);
  });
}
