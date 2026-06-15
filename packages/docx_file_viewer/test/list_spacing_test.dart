import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/theme/docx_view_theme.dart';
import 'package:docx_file_viewer/src/widget_generator/list_builder.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the list renderer reproduces Word's inter-item spacing from the
/// source paragraph (spacingBefore/After + contextualSpacing) instead of a fixed
/// gap — the formatting-demo nested list (no Normal style → 0 spacing) renders
/// tight, like Word.
void main() {
  const config = DocxViewConfig();
  const viewTheme = DocxViewTheme();

  ListBuilder makeBuilder() => ListBuilder(
        config: config,
        theme: viewTheme,
        paragraphBuilder: ParagraphBuilder(config: config, theme: viewTheme),
      );

  // A list item that carries a source paragraph with the given spacing (twips).
  DocxListItem item(String text,
      {int? before, int? after, bool contextual = false, int level = 0}) {
    final children = [DocxText(text)];
    return DocxListItem(
      children,
      level: level,
      sourceParagraph: DocxParagraph(
        children: children,
        spacingBefore: before,
        spacingAfter: after,
        contextualSpacing: contextual,
      ),
    );
  }

  /// The vertical (top, bottom) of every list-item padding, in document order.
  List<(double, double)> itemPaddings(WidgetTester tester) => tester
      .widgetList<Padding>(find.byType(Padding))
      .map((p) => p.padding)
      .whereType<EdgeInsetsDirectional>()
      .map((e) => (e.top, e.bottom))
      .toList();

  testWidgets('Word list with no resolved spacing renders tight (0/0)',
      (tester) async {
    // Mirrors formatting-demo §3.1: ListParagraph→Normal(undefined)→docDefaults
    // with no spacing → Word renders 0 before/after.
    final list = DocxList(items: [
      item('פריט ברמה ראשונה'),
      item('תת-פריט ברמה שנייה', level: 1),
      item('פריט נוסף ברמה ראשונה'),
    ]);

    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: makeBuilder().build(list))));

    expect(itemPaddings(tester), [(0.0, 0.0), (0.0, 0.0), (0.0, 0.0)]);
  });

  testWidgets('explicit paragraph spacing is honoured (twips → px)',
      (tester) async {
    final list = DocxList(items: [item('x', before: 240, after: 120)]);

    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: makeBuilder().build(list))));

    // 240tw/15 = 16px, 120tw/15 = 8px.
    expect(itemPaddings(tester), [(16.0, 8.0)]);
  });

  testWidgets('contextualSpacing collapses the gaps between sibling items',
      (tester) async {
    final list = DocxList(items: [
      item('a', before: 240, after: 240, contextual: true),
      item('b', before: 240, after: 240, contextual: true),
      item('c', before: 240, after: 240, contextual: true),
    ]);

    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: makeBuilder().build(list))));

    // Keep the gap above the first and below the last; collapse the middle.
    expect(itemPaddings(tester), [(16.0, 0.0), (0.0, 0.0), (0.0, 16.0)]);
  });

  testWidgets('factory list (no source paragraph) keeps a small default gap',
      (tester) async {
    final list = DocxList(items: const [
      DocxListItem([DocxText('one')]),
      DocxListItem([DocxText('two')]),
    ]);

    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: makeBuilder().build(list))));

    expect(itemPaddings(tester), [(2.0, 2.0), (2.0, 2.0)]);
  });
}
