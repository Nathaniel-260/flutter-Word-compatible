import 'dart:convert';

import 'package:docx_creator/docx_creator.dart';

import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart'; // Ensure this is accessible or export it
import 'package:docx_file_viewer/src/widgets/float_wrap_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Valid 1x1 PNG
  final validPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');

  group('Reproduction Tests', () {
    testWidgets('Floating Image Right Alignment pushes text to end (Bug Repro)',
        (tester) async {
      // Setup
      final config = DocxViewConfig();
      final builder = ParagraphBuilder(
        config: config,
        theme: DocxViewTheme(),
      );

      // Paragraph: "Start" -> Image(Right side float) -> "End"
      final paragraph = DocxParagraph(children: [
        DocxText('Start '),
        DocxInlineImage(
          width: 100,
          height: 100,
          bytes: validPng,
          extension: '.png',
          positionMode: DocxDrawingPosition.floating,
          textWrap: DocxTextWrap.square,
          hAlign: DrawingHAlign.right,
        ),
        DocxText('End'),
      ]);

      final widget = builder.build(paragraph);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      // The text wraps beside the right float via the band-aware layout
      // (§8.2 #29) — no content is lost, the float renders once.
      expect(find.byType(FloatWrapText), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      final textContents = [
        for (final e in find.byType(RichText).evaluate())
          (e.widget as RichText).text.toPlainText(),
      ];
      final fullContent = textContents.join('');
      expect(fullContent, contains('Start '));
      expect(fullContent, contains('End'));
    });

    testWidgets('Font Family from DocxText.fonts is ignored (Bug Repro)',
        (tester) async {
      // Setup
      final config = DocxViewConfig();
      final builder = ParagraphBuilder(
        config: config,
        theme: DocxViewTheme(),
      );

      const targetFont = 'MyCustomFont';

      final text = DocxText(
        'Themed Text',
        // Simulate Reader producing both legacy and new properties
        fontFamily: 'LegacyFallbackFont',
        fonts: const DocxFont(ascii: targetFont),
      );

      final paragraph = DocxParagraph(children: [text]);
      final widget = builder.build(paragraph);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      // Find Span
      final richTextFinder = find.byType(RichText);
      final selectableTextFinder = find.byType(SelectableText);

      TextStyle style;
      if (richTextFinder.evaluate().isNotEmpty) {
        final rt = tester.widget<RichText>(richTextFinder.first);
        style = rt.text.style!;
        // Or children spans
        final span = rt.text as TextSpan;
        style = span.children![0].style!;
      } else {
        final st = tester.widget<SelectableText>(selectableTextFinder.first);
        final span = st.textSpan!;
        style = span.children![0].style!;
      }

      // If bug exists, this might be null or default

      expect(style.fontFamily, targetFont);
    });
  });

  test('DocxWidgetGenerator yields pages in paged mode', () {
    const config = DocxViewConfig(pageMode: DocxPageMode.paged, pageWidth: 794);
    final generator = DocxWidgetGenerator(config: config);

    // Create a mock document with 1 paragraph
    final doc = DocxBuiltDocument(
      elements: [
        DocxParagraph(children: [DocxText('Test Page 1')]),
      ],
      // Default section required
      section: DocxSectionDef(),
    );

    final widgets = generator.generateWidgets(doc);

    // Expecting 1 page container
    expect(widgets.length, 1);
    expect(widgets.first, isA<Container>());
  });
}
