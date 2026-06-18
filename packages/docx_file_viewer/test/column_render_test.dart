import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/column_layout.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Part I — the paged renderer lays a multi-column section out as a row of
/// columns (`_buildMultiColumnBody`): columns side by side, a visible `w:sep`
/// rule when requested, and reversed column order for RTL sections. The
/// pagination tests cover column assignment; these cover the *render* path that
/// the pagination tests cannot reach.
void main() {
  const config = DocxViewConfig(pageWidth: 600, pageHeight: 400);

  // A 2-column section; a single paragraph with a column break puts 'COLZERO'
  // in column 0 and 'COLONE' in column 1 deterministically (no fill guessing).
  DocxBuiltDocument breakDoc({bool rtl = false, bool separator = false}) =>
      DocxBuiltDocument(
        elements: [
          DocxParagraph(children: [
            const DocxText('COLZERO'),
            const DocxLineBreak(isColumnBreak: true),
            const DocxText('COLONE'),
          ]),
        ],
        section: DocxSectionDef(
          marginLeft: 1440,
          marginRight: 1440,
          marginTop: 1440,
          marginBottom: 1440,
          isRtlSection: rtl,
          columns: DocxColumns(
            count: 2,
            spaceTwips: 720,
            separator: separator,
          ),
        ),
      );

  Future<void> pump(WidgetTester tester, DocxBuiltDocument doc) async {
    final widgets = DocxWidgetGenerator(config: config).generateWidgets(doc);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: Column(children: widgets)),
      ),
    ));
  }

  // ──────────────────────────────────────────────────────────────────────
  // resolveColumnGaps (per-column w:space)
  // ──────────────────────────────────────────────────────────────────────

  group('resolveColumnGaps', () {
    test('equal-width: every gap is the default w:space', () {
      const cols = DocxColumns(count: 3, spaceTwips: 720);
      final gaps = resolveColumnGaps(cols, 3);
      expect(gaps, hasLength(2));
      expect(gaps[0], closeTo(48, 0.5)); // 720 / 15
      expect(gaps[1], closeTo(48, 0.5));
    });

    test('explicit: each column carries its own w:space, default fills gaps',
        () {
      const cols = DocxColumns(
        count: 3,
        spaceTwips: 720,
        equalWidth: false,
        explicit: [
          DocxColumn(widthTwips: 2000, spaceTwips: 300),
          DocxColumn(widthTwips: 2000), // no space → falls back to default
          DocxColumn(widthTwips: 2000),
        ],
      );
      final gaps = resolveColumnGaps(cols, 3);
      expect(gaps[0], closeTo(20, 0.5)); // 300 / 15
      expect(gaps[1], closeTo(48, 0.5)); // default 720 / 15
    });

    test('single column has no gaps', () {
      const cols = DocxColumns(count: 1, spaceTwips: 720);
      expect(resolveColumnGaps(cols, 1), isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────────────
  // Render layout
  // ──────────────────────────────────────────────────────────────────────

  testWidgets('LTR: column 0 renders to the left of column 1', (tester) async {
    await pump(tester, breakDoc());

    final left = find.textContaining('COLZERO', findRichText: true);
    final right = find.textContaining('COLONE', findRichText: true);
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);
    // Column 0 is to the left of column 1 in an LTR section.
    expect(tester.getTopLeft(left).dx, lessThan(tester.getTopLeft(right).dx));
  });

  testWidgets('RTL: column 0 renders to the right of column 1', (tester) async {
    await pump(tester, breakDoc(rtl: true));

    final colZero = find.textContaining('COLZERO', findRichText: true);
    final colOne = find.textContaining('COLONE', findRichText: true);
    expect(colZero, findsOneWidget);
    expect(colOne, findsOneWidget);
    // RTL reverses the visual order: logical column 0 sits on the right.
    expect(tester.getTopLeft(colZero).dx,
        greaterThan(tester.getTopLeft(colOne).dx));
  });

  testWidgets('w:sep draws a visible full-height rule between columns',
      (tester) async {
    await pump(tester, breakDoc(separator: true));

    // The separator is the 1px-wide Container in the inter-column gap. Before
    // the fix it had no height and collapsed to zero — invisible.
    final sep = find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxWidth == 1);
    expect(sep, findsOneWidget);
    expect(tester.getSize(sep).height, greaterThan(1),
        reason: 'the column separator must span the column height, not 0px');
  });

  testWidgets('no separator when w:sep is off (gap is an empty spacer)',
      (tester) async {
    await pump(tester, breakDoc(separator: false));

    final sep = find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxWidth == 1);
    expect(sep, findsNothing);
  });
}
