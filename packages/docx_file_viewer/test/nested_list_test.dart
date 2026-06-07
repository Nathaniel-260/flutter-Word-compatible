import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/theme/docx_view_theme.dart';
import 'package:docx_file_viewer/src/widget_generator/list_builder.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewConfig = DocxViewConfig();
  const viewTheme = DocxViewTheme();

  ListBuilder makeBuilder() {
    final paraBuilder = ParagraphBuilder(config: viewConfig, theme: viewTheme);
    return ListBuilder(
      config: viewConfig,
      theme: viewTheme,
      paragraphBuilder: paraBuilder,
    );
  }

  /// Collects the marker glyphs from each list item (the leading [Text] widget
  /// of every row), in document order.
  List<String> markersOf(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();

  group('Nested lists', () {
    testWidgets('3.1 nested bullet list cascades •, ◦, ▪ by depth',
        (tester) async {
      final list = DocxList(items: const [
        DocxListItem([DocxText('Level 1')], level: 0),
        DocxListItem([DocxText('Level 2')], level: 1),
        DocxListItem([DocxText('Level 3')], level: 2),
        DocxListItem([DocxText('Back to level 1')], level: 0),
      ]);

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: makeBuilder().build(list))));

      expect(markersOf(tester), ['•', '◦', '▪', '•']);
    });

    testWidgets('3.2 nested numbered list cascades 1. → a. → i.',
        (tester) async {
      final list = DocxList(isOrdered: true, items: const [
        DocxListItem([DocxText('Step 1')], level: 0),
        DocxListItem([DocxText('Sub a')], level: 1),
        DocxListItem([DocxText('Roman i')], level: 2),
        DocxListItem([DocxText('Step 2')], level: 0),
      ]);

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: makeBuilder().build(list))));

      expect(markersOf(tester), ['1.', 'a.', 'i.', '2.']);
    });

    testWidgets('3.3 checklist item suppresses the bullet marker',
        (tester) async {
      final list = DocxList(items: const [
        DocxListItem([DocxCheckbox(isChecked: false), DocxText('Task')]),
        DocxListItem([DocxCheckbox(isChecked: true), DocxText('Done')]),
      ]);

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: makeBuilder().build(list))));

      // No '•' bullet is emitted; the checkbox glyph itself is the marker.
      expect(markersOf(tester).where((m) => m == '•'), isEmpty);
    });

    testWidgets('checklist detection skips leading whitespace before checkbox',
        (tester) async {
      // HTML parsing can leave a stray whitespace text node before the box.
      final list = DocxList(items: const [
        DocxListItem(
            [DocxText('  '), DocxCheckbox(isChecked: false), DocxText('Task')]),
      ]);

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: makeBuilder().build(list))));

      expect(markersOf(tester).where((m) => m == '•'), isEmpty);
    });

    testWidgets('Hebrew (gematria) numbering renders א, ב … יא, טו, טז',
        (tester) async {
      final list = DocxList(
        isOrdered: true,
        style: DocxListStyle.hebrew,
        items: List.generate(
          16,
          (i) => DocxListItem([DocxText('סעיף ${i + 1}')]),
        ),
      );

      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(child: makeBuilder().build(list)))));

      final markers = markersOf(tester);
      expect(markers[0], 'א.');
      expect(markers[1], 'ב.');
      expect(markers[9], 'י.');
      expect(markers[10], 'יא.');
      // 15/16 use the conventional טו/טז spellings, not יה/יו.
      expect(markers[14], 'טו.');
      expect(markers[15], 'טז.');
    });

    testWidgets('Hebrew list renders RTL and indents nesting from the start',
        (tester) async {
      final list = DocxList(items: const [
        DocxListItem([DocxText('פריט ברמה ראשונה')], level: 0),
        DocxListItem([DocxText('תת-פריט ברמה שנייה')], level: 1),
      ]);

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: makeBuilder().build(list))));

      // Each item is wrapped in an RTL Directionality.
      final directions = tester
          .widgetList<Directionality>(find.descendant(
            of: find.byType(Column),
            matching: find.byType(Directionality),
          ))
          .map((d) => d.textDirection)
          .toList();
      expect(directions, isNotEmpty);
      expect(directions.every((d) => d == TextDirection.rtl), isTrue);

      // Indentation uses directional padding (start side), so it mirrors under
      // RTL instead of pushing content the wrong way.
      final paddings = tester
          .widgetList<Padding>(find.byType(Padding))
          .map((p) => p.padding)
          .whereType<EdgeInsetsDirectional>()
          .toList();
      expect(paddings.length, greaterThanOrEqualTo(2));
      // Level 1 indents further from the start than level 0.
      expect(paddings[1].start, greaterThan(paddings[0].start));
    });

    testWidgets('numbered list nested in a bullet list keeps its numbers',
        (tester) async {
      // Parent is unordered; the level-1 items carry an ordered override, as
      // the parsers now emit for mixed nesting.
      final list = DocxList(items: const [
        DocxListItem([DocxText('Bullet')], level: 0),
        DocxListItem(
          [DocxText('Numbered child')],
          level: 1,
          overrideStyle: DocxListStyle(numberFormat: DocxNumberFormat.decimal),
        ),
      ]);

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: makeBuilder().build(list))));

      final markers = markersOf(tester);
      expect(markers.first, '•');
      // Level 1 cascades decimal → lowerAlpha, so the override renders 'a.'.
      expect(markers, contains('a.'));
    });
  });
}
