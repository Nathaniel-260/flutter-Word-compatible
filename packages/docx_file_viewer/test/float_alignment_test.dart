import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:docx_file_viewer/src/widgets/float_wrap_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParagraphBuilder Float Alignment', () {
    // Text + a side float now wrap together via the band-aware [FloatWrapText]
    // (§8.2 #29): text flows beside the float, the float renders once.
    Widget buildParagraph(DrawingHAlign align) {
      final image = DocxInlineImage(
        bytes: _createGradientImage(),
        extension: 'png',
        width: 50,
        height: 50,
        positionMode: DocxDrawingPosition.floating,
        textWrap: DocxTextWrap.square,
        hAlign: align,
      );
      final paragraph = DocxParagraph(children: [
        DocxText('Main content text that should be beside the image.'),
        image,
      ]);
      return ParagraphBuilder(
        config: const DocxViewConfig(),
        theme: DocxViewTheme.light(),
        docxTheme: DocxTheme.empty(),
      ).build(paragraph);
    }

    testWidgets('Text + Right side float wrap together (FloatWrapText)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: buildParagraph(DrawingHAlign.right))));

      expect(find.byType(FloatWrapText), findsOneWidget,
          reason: 'the side float wraps the text in-flow');
      expect(find.byType(Image), findsOneWidget,
          reason: 'the float image renders once');
      expect(_renderedText(), contains('Main content'),
          reason: 'the paragraph text is rendered beside the float');
    });

    testWidgets('Text + Left side float wrap together (FloatWrapText)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: buildParagraph(DrawingHAlign.left))));

      expect(find.byType(FloatWrapText), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(_renderedText(), contains('Main content'));
    });
  });
}

/// The concatenated plain text of every rendered [RichText] (the wrap splits a
/// paragraph into one RichText per line).
String _renderedText() => [
      for (final e in find.byType(RichText).evaluate())
        (e.widget as RichText).text.toPlainText(),
    ].join();

Uint8List _createGradientImage() {
  return Uint8List.fromList([
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // GIF89a
    0x01, 0x00, 0x01, 0x00, // 1x1 dimensions
    0x80, 0x00, 0x00, // Global Color Table Flag
    0xff, 0xff, 0xff, // White
    0x00, 0x00, 0x00, // Black
    0x21, 0xf9, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, // Graphic Control Extension
    0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
    0x00, // Image Descriptor
    0x02, 0x02, 0x44, 0x01, 0x00, 0x3b // Image Data + Terminator
  ]);
}
