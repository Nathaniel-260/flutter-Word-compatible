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

    testWidgets('compound (legal) lvlText renders 1, 1.1, 1.1.1, 1.2',
        (tester) async {
      // Mirrors a Word multilevel "legal" list: each level's lvlText composes
      // all ancestor counters (%1.%2.%3) rather than a single component.
      const levels = [
        DocxListLevel(
            level: 0, format: DocxNumberFormat.decimal, lvlText: '%1'),
        DocxListLevel(
            level: 1, format: DocxNumberFormat.decimal, lvlText: '%1.%2'),
        DocxListLevel(
            level: 2, format: DocxNumberFormat.decimal, lvlText: '%1.%2.%3'),
      ];
      final list = DocxList(
        isOrdered: true,
        levels: levels,
        items: const [
          DocxListItem([DocxText('Agreement')], level: 0),
          DocxListItem([DocxText('Payment terms')], level: 1),
          DocxListItem([DocxText('Timing')], level: 2),
          DocxListItem([DocxText('Method')], level: 2),
          DocxListItem([DocxText('Termination')], level: 1),
        ],
      );

      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(child: makeBuilder().build(list)))));

      final markers = markersOf(tester).where((m) => m.isNotEmpty).toList();
      expect(markers, ['1', '1.1', '1.1.1', '1.1.2', '1.2']);
    });

    testWidgets('custom level start renders a list beginning at 5',
        (tester) async {
      final list = DocxList(
        isOrdered: true,
        levels: const [
          DocxListLevel(
              level: 0, format: DocxNumberFormat.decimal, lvlText: '%1)', start: 5),
        ],
        items: const [
          DocxListItem([DocxText('Fifth item')], level: 0),
          DocxListItem([DocxText('Sixth item')], level: 0),
        ],
      );

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: makeBuilder().build(list))));

      final markers = markersOf(tester).where((m) => m.isNotEmpty).toList();
      expect(markers, ['5)', '6)']);
    });

    testWidgets('mixed-format compound numbering formats each component',
        (tester) async {
      // Level 0 upper-roman, level 1 lower-alpha → "I", "I.a".
      const levels = [
        DocxListLevel(
            level: 0, format: DocxNumberFormat.upperRoman, lvlText: '%1'),
        DocxListLevel(
            level: 1, format: DocxNumberFormat.lowerAlpha, lvlText: '%1.%2'),
      ];
      final list = DocxList(
        isOrdered: true,
        levels: levels,
        items: const [
          DocxListItem([DocxText('Main')], level: 0),
          DocxListItem([DocxText('Sub')], level: 1),
        ],
      );

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: makeBuilder().build(list))));

      final markers = markersOf(tester).where((m) => m.isNotEmpty).toList();
      expect(markers, ['I', 'I.a']);
    });

    testWidgets('lower-alpha numbering continues past z as aa, ab',
        (tester) async {
      // Bijective base-26: item 26 → z, 27 → aa, 28 → ab (Word behaviour).
      final list = DocxList(
        isOrdered: true,
        style: DocxListStyle.lowerAlpha,
        items: List.generate(
          28,
          (i) => DocxListItem([DocxText('item ${i + 1}')]),
        ),
      );

      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(child: makeBuilder().build(list)))));

      final markers = markersOf(tester).where((m) => m.isNotEmpty).toList();
      expect(markers[25], 'z.');
      expect(markers[26], 'aa.');
      expect(markers[27], 'ab.');
    });

    testWidgets('marker matches body font size and aligns to its baseline',
        (tester) async {
      // Body text larger than the theme default; the marker must scale to match
      // instead of rendering small and raised like a superscript.
      const noSelect = DocxViewConfig(enableSelection: false);
      final builder = ListBuilder(
        config: noSelect,
        theme: viewTheme,
        paragraphBuilder: ParagraphBuilder(config: noSelect, theme: viewTheme),
      );
      final list = DocxList(isOrdered: true, items: const [
        DocxListItem([DocxText('פריט גדול', fontSize: 28)]),
      ]);

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: builder.build(list))));

      // Marker glyph and the body line share the same baseline (not top-pinned).
      final row = tester.widget<Row>(find.byType(Row));
      expect(row.crossAxisAlignment, CrossAxisAlignment.baseline);

      // Marker font size equals the body run's font size.
      final markerSize = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.style?.fontSize)
          .firstWhere((s) => s != null);
      final bodyRich = tester.widget<RichText>(find.descendant(
        of: find.byType(Expanded),
        matching: find.byType(RichText),
      ));
      double? bodySize;
      void visit(InlineSpan s) {
        if (bodySize != null) return;
        if (s is TextSpan) {
          if ((s.text?.isNotEmpty ?? false) && s.style?.fontSize != null) {
            bodySize = s.style!.fontSize;
            return;
          }
          s.children?.forEach(visit);
        }
      }

      visit(bodyRich.text);
      expect(bodySize, isNotNull);
      expect(markerSize, bodySize);
    });

    testWidgets('marker honours italic + bold from the level rPr (item 22)',
        (tester) async {
      // 08-numbering.md E1: the level's `w:rPr/w:i` italic was parsed and stored
      // but never applied to the marker. The marker must now render italic (as
      // it already did bold), end-to-end through DocxListStyle.fontStyle.
      final list = DocxList(
        isOrdered: true,
        style: const DocxListStyle(
          fontStyle: DocxFontStyle.italic,
          fontWeight: DocxFontWeight.bold,
        ),
        items: const [
          DocxListItem([DocxText('Item')]),
        ],
      );

      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: makeBuilder().build(list))));

      final marker = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((t) => (t.data ?? '').isNotEmpty);
      expect(marker.style?.fontStyle, FontStyle.italic);
      expect(marker.style?.fontWeight, FontWeight.bold);
    });

    test('firstSpanFontSize inherits a wrapper span size for nested text', () {
      // Parent declares the size; only the leaf child holds the text. The marker
      // sizing must still resolve 22 rather than falling back to the default.
      const spans = [
        TextSpan(
          style: TextStyle(fontSize: 22),
          children: [TextSpan(text: 'nested')],
        ),
      ];
      expect(ListBuilder.firstSpanFontSize(spans), 22);
    });

    test('firstSpanFontSize prefers an explicit child size over the wrapper',
        () {
      const spans = [
        TextSpan(
          style: TextStyle(fontSize: 22),
          children: [TextSpan(text: 'leaf', style: TextStyle(fontSize: 18))],
        ),
      ];
      expect(ListBuilder.firstSpanFontSize(spans), 18);
    });

    test('firstSpanFontSize returns null when no span declares a size', () {
      const spans = [TextSpan(text: 'plain')];
      expect(ListBuilder.firstSpanFontSize(spans), isNull);
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
