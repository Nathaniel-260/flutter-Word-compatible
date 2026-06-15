import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/table_layout.dart';
import 'package:docx_file_viewer/src/layout/table_min_widths.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// QA F3: the `table-layout:auto` content floor (longest-word px per column) is
/// now wired into both the paginator and the renderer. A long word must expand
/// its column instead of overflowing the cell, and — critically — the two passes
/// must derive the *same* floor so measurement stays ≡ rendering.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SpanFactory makeSpanFactory() => SpanFactory(
        theme: DocxViewTheme.light(),
        config: const DocxViewConfig(enableSelection: false),
        docxTheme: DocxTheme.empty(),
      );

  const longWord = 'Supercalifragilisticexpialidocious';

  DocxTable narrowTableWithLongWord() => DocxTable(
        layout: DocxTableLayout.autofit,
        gridColumns: const [100, 100], // both far narrower than the long word
        rows: [
          DocxTableRow(cells: [
            DocxTableCell(children: [
              DocxParagraph(children: [DocxText(longWord)])
            ]),
            DocxTableCell(children: [
              DocxParagraph(children: [DocxText('x')])
            ]),
          ]),
        ],
      );

  test('a long word produces a column floor wide enough to hold it', () {
    final mins = computeMinColumnWidths(narrowTableWithLongWord(), makeSpanFactory());
    expect(mins.length, 2);
    expect(mins[0], greaterThan(150),
        reason: 'the long word forces a real content floor on column 0');
    expect(mins[1], lessThan(mins[0]),
        reason: 'the short cell needs almost no floor');
  });

  test('the floor raises the crushed column when autofit resolves widths', () {
    final table = narrowTableWithLongWord();
    final mins = computeMinColumnWidths(table, makeSpanFactory());

    final without =
        resolveTableColumnWidths(table, availableWidth: 220).columns;
    final with_ = resolveTableColumnWidths(table,
            availableWidth: 220, minColumnWidths: mins)
        .columns;

    // The grid is in twips (100tw ≈ 6.7px), so without a floor column 0 stays
    // tiny and the long word would overflow/wrap.
    expect(without[0], closeTo(100 / 15, 0.5),
        reason: 'without the floor the grid keeps column 0 at its 100tw cell');
    expect(with_[0], greaterThanOrEqualTo(mins[0] - 0.5),
        reason: 'with the floor column 0 holds the whole word (Word expands it)');
  });

  test('two identically-configured factories yield identical floors '
      '(the measure≡render guarantee)', () {
    final table = narrowTableWithLongWord();
    // The paginator and the renderer build *separate* span factories from the
    // same theme/config/document; the floor must come out byte-identical.
    final a = computeMinColumnWidths(table, makeSpanFactory());
    final b = computeMinColumnWidths(table, makeSpanFactory());
    expect(a, b);
  });

  testWidgets('a long word expands its autofit column in the rendered table',
      (tester) async {
    final doc = DocxBuiltDocument(elements: [narrowTableWithLongWord()]);
    const config = DocxViewConfig(
      pageMode: DocxPageMode.continuous,
      fitPageToWidth: false,
      enableSelection: false,
    );
    final widgets = DocxWidgetGenerator(config: config).generateWidgets(doc);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        // Wide viewport so the (floored) table is not scaled down by FittedBox.
        body: SizedBox(
          width: 700,
          child: ListView(children: widgets),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);

    final wordText = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains(longWord));
    expect(wordText, findsOneWidget);
    // The column expanded for the word: its laid-out width is far beyond the
    // un-floored 100px grid cell (without the fix it would wrap inside ~100px).
    expect(tester.getSize(wordText).width, greaterThan(150),
        reason: 'the floored column lets the long word lay out wide, not '
            'crushed into the 100px grid cell');
  });
}
