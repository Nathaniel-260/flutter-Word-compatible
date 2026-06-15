import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §H.2 step 4 — the paged renderer draws topAndBottom + front floats as a
/// positioned layer (once), and keeps behindText on the page background.
void main() {
  const config = DocxViewConfig(pageWidth: 600, pageHeight: 400);

  DocxBuiltDocument docWithFloat(DocxTextWrap wrap, {DrawingHAlign? hAlign}) =>
      DocxBuiltDocument(elements: [
        DocxParagraph(children: [
          DocxText('anchor paragraph'),
          DocxInlineImage(
            bytes: _gif(),
            extension: 'gif',
            width: 80,
            height: 60,
            positionMode: DocxDrawingPosition.floating,
            textWrap: wrap,
            hAlign: hAlign,
          ),
        ]),
        for (var i = 0; i < 3; i++)
          DocxParagraph(children: [DocxText('body $i')]),
      ]);

  Future<void> pumpDoc(WidgetTester tester, DocxBuiltDocument doc) async {
    final widgets = DocxWidgetGenerator(config: config).generateWidgets(doc);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: widgets),
        ),
      ),
    ));
  }

  testWidgets('topAndBottom float renders exactly once (stripped from body)',
      (tester) async {
    await pumpDoc(tester, docWithFloat(DocxTextWrap.topAndBottom));
    // One Image only → not double-rendered (layer + in-flow Row).
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Positioned), findsWidgets);
  });

  testWidgets('front (wrapNone) float renders once in the layer',
      (tester) async {
    await pumpDoc(tester, docWithFloat(DocxTextWrap.none));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('behindText float stays on the page background (no Image widget)',
      (tester) async {
    await pumpDoc(tester, docWithFloat(DocxTextWrap.behindText));
    // Rendered via DecorationImage, not an Image widget, and not double-drawn.
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('side float keeps the legacy in-flow Row path (one Image)',
      (tester) async {
    await pumpDoc(
        tester, docWithFloat(DocxTextWrap.square, hAlign: DrawingHAlign.right));
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Row), findsWidgets);
  });
}

Uint8List _gif() => Uint8List.fromList([
      0x47, 0x49, 0x46, 0x38, 0x39, 0x61, //
      0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00,
      0xff, 0xff, 0xff, 0x00, 0x00, 0x00,
      0x21, 0xf9, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
      0x02, 0x02, 0x44, 0x01, 0x00, 0x3b,
    ]);
