import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 04-paragraph-ppr.md item 25: paragraph shading must paint a *theme* fill
/// (`w:shd w:themeFill`), not only an explicit hex `w:fill`. The background is
/// resolved through the same path as the run's `auto` colour.
void main() {
  final docxTheme = DocxTheme(
    colors: DocxThemeColors(accent1: 'FF0000'),
  );

  Container? decoratedContainer(WidgetTester tester) {
    for (final c
        in tester.widgetList<Container>(find.byType(Container)).cast<Container>()) {
      if (c.decoration is BoxDecoration &&
          (c.decoration as BoxDecoration).color != null) {
        return c;
      }
    }
    return null;
  }

  testWidgets('explicit hex fill still paints (regression)', (tester) async {
    final builder = ParagraphBuilder(
        config: const DocxViewConfig(), theme: const DocxViewTheme(), docxTheme: docxTheme);
    const p = DocxParagraph(shadingFill: '00FF00', children: [DocxText('x')]);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: builder.build(p))));
    final c = decoratedContainer(tester);
    expect(c, isNotNull);
    expect((c!.decoration as BoxDecoration).color, const Color(0xFF00FF00));
  });

  testWidgets('theme fill paints from the document theme (item 25)',
      (tester) async {
    final builder = ParagraphBuilder(
        config: const DocxViewConfig(), theme: const DocxViewTheme(), docxTheme: docxTheme);
    const p = DocxParagraph(themeFill: 'accent1', children: [DocxText('x')]);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: builder.build(p))));
    final c = decoratedContainer(tester);
    expect(c, isNotNull);
    expect((c!.decoration as BoxDecoration).color, const Color(0xFFFF0000));
  });
}
