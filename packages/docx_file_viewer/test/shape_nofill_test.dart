import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/widget_generator/shape_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 09-drawing-images.md item 24: a shape with an explicit `a:noFill` is
/// transparent — it must NOT paint the grey placeholder used when no fill colour
/// is known.
void main() {
  final builder = ShapeBuilder(config: const DocxViewConfig());

  List<Color?> decorationColors(WidgetTester tester) => tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .map((d) => d.color)
      .toList();

  testWidgets('noFill rect is transparent, never grey', (tester) async {
    final shape = DocxShape(
        width: 80, height: 40, preset: DocxShapePreset.rect, noFill: true);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: builder.buildInlineShape(shape))));
    final colors = decorationColors(tester);
    expect(colors, contains(Colors.transparent));
    expect(colors, isNot(contains(Colors.grey.shade200)));
  });

  testWidgets('unknown-fill rect still falls back to grey (baseline)',
      (tester) async {
    final shape =
        DocxShape(width: 80, height: 40, preset: DocxShapePreset.rect);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: builder.buildInlineShape(shape))));
    expect(decorationColors(tester), contains(Colors.grey.shade200));
  });
}
