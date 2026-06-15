import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/layout/numbering_resolver.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §G — the document-wide [NumberingResolver]: one pass in document order
/// keeping counters per `(numId, ilvl)` so markers continue across interrupting
/// blocks, table cells and same-`numId` lists, with Word's restart, legal and
/// format semantics.
void main() {
  DocxListItem li(String text, {int level = 0}) =>
      DocxListItem([DocxText(text)], level: level);

  // A simple single-level ordered list.
  DocxList numbered(
    int numId,
    List<DocxListItem> items, {
    String fmtRaw = 'decimal',
    DocxNumberFormat fmt = DocxNumberFormat.decimal,
    String lvlText = '%1.',
    int start = 1,
  }) =>
      DocxList(
        isOrdered: true,
        numId: numId,
        levels: [
          DocxListLevel(
            level: 0,
            format: fmt,
            numFmtRaw: fmtRaw,
            lvlText: lvlText,
            start: start,
          ),
        ],
        items: items,
      );

  // A 3-level "legal" list; per-level options are configurable.
  DocxList multilevel(
    int numId,
    List<DocxListItem> items, {
    bool isLglLevel1 = false,
    int? lvlRestartLevel1,
    DocxNumberFormat level0Fmt = DocxNumberFormat.decimal,
    String level0Raw = 'decimal',
    DocxNumberFormat level1Fmt = DocxNumberFormat.decimal,
    String level1Raw = 'decimal',
  }) =>
      DocxList(
        isOrdered: true,
        numId: numId,
        levels: [
          DocxListLevel(
              level: 0, format: level0Fmt, numFmtRaw: level0Raw, lvlText: '%1'),
          DocxListLevel(
            level: 1,
            format: level1Fmt,
            numFmtRaw: level1Raw,
            lvlText: '%1.%2',
            isLgl: isLglLevel1,
            lvlRestart: lvlRestartLevel1,
          ),
          const DocxListLevel(
              level: 2, format: DocxNumberFormat.decimal, lvlText: '%1.%2.%3'),
        ],
        items: items,
      );

  Map<DocxListItem, String> resolve(List<DocxNode> elements,
          {DocxSectionDef? section, List<DocxFootnote>? footnotes}) =>
      NumberingResolver().resolveDocument(
        DocxBuiltDocument(
          elements: elements,
          section: section,
          footnotes: footnotes,
        ),
      );

  group('continuation', () {
    test('a list continues after an interrupting paragraph (same numId)', () {
      final a = [li('one'), li('two'), li('three')];
      final b = [li('four'), li('five')];
      final labels = resolve([
        numbered(1, a),
        DocxParagraph(children: const [DocxText('a break')]),
        numbered(1, b),
      ]);

      expect(
          [...a, ...b].map((it) => labels[it]), ['1.', '2.', '3.', '4.', '5.']);
    });

    test('different numIds number independently (start applies per numId)', () {
      final a = [li('a1'), li('a2')];
      final b = [li('b1'), li('b2')];
      final labels = resolve([numbered(1, a), numbered(2, b)]);
      // List 2 (its own numId) restarts at 1 rather than continuing list 1.
      expect(a.map((it) => labels[it]), ['1.', '2.']);
      expect(b.map((it) => labels[it]), ['1.', '2.']);
    });

    test('a list inside a table cell continues the body counter', () {
      final body = [li('1'), li('2')];
      final inCell = [li('3')];
      final table = DocxTable(rows: [
        DocxTableRow(cells: [
          DocxTableCell(children: [numbered(1, inCell)]),
        ]),
      ]);
      final labels = resolve([numbered(1, body), table]);
      expect(body.map((it) => labels[it]), ['1.', '2.']);
      expect(labels[inCell.first], '3.');
    });
  });

  group('multilevel / legal', () {
    test('compound %1.%2.%3 with default restart', () {
      final items = [
        li('a', level: 0),
        li('b', level: 1),
        li('c', level: 2),
        li('d', level: 2),
        li('e', level: 1),
        li('f', level: 0),
      ];
      final labels = resolve([multilevel(1, items)]);
      expect(items.map((it) => labels[it]),
          ['1', '1.1', '1.1.1', '1.1.2', '1.2', '2']);
    });

    test('isLgl forces every component to decimal', () {
      // Level 0 is upper-roman, level 1 lower-alpha — but level 1 is legal, so
      // both components render decimal.
      final items = [li('main', level: 0), li('sub', level: 1)];
      final labels = resolve([
        multilevel(
          1,
          items,
          isLglLevel1: true,
          level0Fmt: DocxNumberFormat.upperRoman,
          level0Raw: 'upperRoman',
          level1Fmt: DocxNumberFormat.lowerAlpha,
          level1Raw: 'lowerAlpha',
        ),
      ]);
      expect(labels[items[0]], 'I'); // level 0 keeps its own roman format
      expect(labels[items[1]], '1.1'); // level 1 is legal → all decimal
    });

    test('lvlRestart=0 keeps the deep counter running across higher levels',
        () {
      final items = [
        li('a', level: 0),
        li('b', level: 1),
        li('c', level: 1),
        li('d', level: 0),
        li('e', level: 1),
      ];
      final labels = resolve([multilevel(1, items, lvlRestartLevel1: 0)]);
      // Without restart, level-1 continues (…1.2 → 2.3) instead of resetting.
      expect(items.map((it) => labels[it]), ['1', '1.1', '1.2', '2', '2.3']);
    });

    test('default restart resets the deep counter under a new parent', () {
      final items = [
        li('a', level: 0),
        li('b', level: 1),
        li('c', level: 1),
        li('d', level: 0),
        li('e', level: 1),
      ];
      final labels = resolve([multilevel(1, items)]);
      expect(items.map((it) => labels[it]), ['1', '1.1', '1.2', '2', '2.1']);
    });
  });

  group('formats', () {
    test('Hebrew gematria (hebrew1) with טו/טז and a high value', () {
      final items = List.generate(16, (i) => li('s${i + 1}'));
      final labels = resolve([
        numbered(1, items, fmtRaw: 'hebrew1', fmt: DocxNumberFormat.hebrew)
      ]);
      final out = items.map((it) => labels[it]).toList();
      expect(out[0], 'א.');
      expect(out[9], 'י.');
      expect(out[10], 'יא.');
      expect(out[14], 'טו.'); // 15 → טו, not יה
      expect(out[15], 'טז.'); // 16 → טז, not יו

      // A high value (תשפ"ו = 786) renders without a separator geresh.
      final one = [li('only')];
      final high = resolve([
        numbered(1, one,
            fmtRaw: 'hebrew1', fmt: DocxNumberFormat.hebrew, start: 786)
      ]);
      expect(high[one.first], 'תשפו.');
    });

    test('hebrew2 is the Hebrew alphabet ordinal', () {
      final items = List.generate(23, (i) => li('x${i + 1}'));
      final labels = resolve([
        numbered(1, items, fmtRaw: 'hebrew2', fmt: DocxNumberFormat.hebrew)
      ]);
      final out = items.map((it) => labels[it]).toList();
      expect(out[0], 'א.');
      expect(out[21], 'ת.'); // 22nd letter
      expect(out[22], 'אא.'); // bijective wrap past the alphabet
    });

    test('decimalZero zero-pads single digits', () {
      final items = List.generate(11, (i) => li('n${i + 1}'));
      final labels = resolve([numbered(1, items, fmtRaw: 'decimalZero')]);
      final out = items.map((it) => labels[it]).toList();
      expect(out[0], '01.');
      expect(out[8], '09.');
      expect(out[9], '10.');
      expect(out[10], '11.');
    });

    test('numFmt="none" yields an empty (present) label', () {
      final items = [li('a'), li('b')];
      final labels =
          resolve([numbered(1, items, fmtRaw: 'none', lvlText: '%1')]);
      // Present in the map (so the renderer treats it as a numbered item) but
      // with no visible marker.
      expect(labels.containsKey(items[0]), isTrue);
      expect(labels[items[0]], '');
    });
  });

  group('stories', () {
    test('a footer list is numbered independently of the body', () {
      final body = [li('1'), li('2')];
      final footerItems = [li('f')];
      final section = DocxSectionDef(
        footer: DocxFooter(children: [numbered(1, footerItems)]),
      );
      final labels = resolve([numbered(1, body)], section: section);
      expect(body.map((it) => labels[it]), ['1.', '2.']);
      // Footer story restarts at 1 even though it shares the numId.
      expect(labels[footerItems.first], '1.');
    });
  });

  group('end-to-end through the widget generator', () {
    testWidgets(
        'continued list renders 1,2,3,4 across an interrupting paragraph',
        (tester) async {
      const config = DocxViewConfig(pageMode: DocxPageMode.continuous);
      final a = [li('one'), li('two')];
      final b = [li('three'), li('four')];
      final doc = DocxBuiltDocument(elements: [
        numbered(1, a),
        DocxParagraph(children: const [DocxText('paragraph break')]),
        numbered(1, b),
      ]);

      final widgets = DocxWidgetGenerator(config: config).generateWidgets(doc);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: widgets),
          ),
        ),
      ));

      final markers = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((m) => RegExp(r'^\d+\.$').hasMatch(m))
          .toList();
      expect(markers, ['1.', '2.', '3.', '4.']);
    });
  });
}
