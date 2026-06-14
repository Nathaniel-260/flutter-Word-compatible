import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/layout/table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for the Part F column-width engine (Plan §F.1 / §F.4 DoD #1).
///
/// Widths are compared against values derived from twips (1px = 15tw), the same
/// conversion Word's measurements convert through, so these assert the algorithm
/// against "known values from Word" without a rendering harness.
void main() {
  // Two body cells so the derived column count matches an explicit 2-col grid.
  DocxTable table({
    required List<int> grid,
    DocxTableLayout layout = DocxTableLayout.autofit,
    DocxWidthType widthType = DocxWidthType.auto,
    int? width,
    int? indentTwips,
    DocxCellMargins? defaultCellMargins,
    DocxTableStyle style = const DocxTableStyle(),
  }) {
    return DocxTable(
      rows: [
        DocxTableRow(cells: [
          DocxTableCell.text('a'),
          DocxTableCell.text('b'),
        ]),
      ],
      gridColumns: grid,
      layout: layout,
      widthType: widthType,
      width: width,
      indentTwips: indentTwips,
      defaultCellMargins: defaultCellMargins,
      style: style,
    );
  }

  group('fixed layout', () {
    test('uses the grid verbatim (overflow tolerated)', () {
      final t = table(grid: [2000, 3000], layout: DocxTableLayout.fixed);
      final cols = resolveTableColumnWidths(t, availableWidth: 600).columns;
      expect(cols[0], closeTo(2000 * kTwipsToPx, 0.01)); // 133.33
      expect(cols[1], closeTo(3000 * kTwipsToPx, 0.01)); // 200
    });

    test('overflows the page rather than shrinking', () {
      final t = table(grid: [9000, 9000], layout: DocxTableLayout.fixed);
      final cols = resolveTableColumnWidths(t, availableWidth: 600).columns;
      expect(
          cols[0] + cols[1], closeTo(18000 * kTwipsToPx, 0.01)); // 1200 > 600
    });
  });

  group('autofit layout', () {
    test('honours the grid when it fits the page', () {
      final t = table(grid: [3000, 1000]); // 266.67px total
      final cols = resolveTableColumnWidths(t, availableWidth: 600).columns;
      expect(cols[0], closeTo(200, 0.01));
      expect(cols[1], closeTo(66.67, 0.01));
    });

    test('scales down proportionally when wider than the page', () {
      final t = table(grid: [9000, 9000]); // 1200px > 600
      final cols = resolveTableColumnWidths(t, availableWidth: 600).columns;
      expect(cols[0], closeTo(300, 0.1));
      expect(cols[1], closeTo(300, 0.1));
      expect(cols[0] + cols[1], closeTo(600, 0.1));
    });

    test('keeps proportions when scaling down', () {
      final t = table(grid: [3000, 1000]); // 3:1
      // 4000tw = 266.67px; force overflow with a 200px page.
      final cols = resolveTableColumnWidths(t, availableWidth: 200).columns;
      expect(cols[0] / cols[1], closeTo(3.0, 0.001));
      expect(cols[0] + cols[1], closeTo(200, 0.1));
    });

    test('grid verbatim under an infinite (nested) width', () {
      final t = table(grid: [3000, 1000]);
      final cols =
          resolveTableColumnWidths(t, availableWidth: double.infinity).columns;
      expect(cols[0], closeTo(200, 0.01));
      expect(cols[1], closeTo(66.67, 0.01));
    });
  });

  group('w:tblW', () {
    test('pct is a percentage of the available width', () {
      final t = table(
        grid: [1000, 1000], // equal
        widthType: DocxWidthType.pct,
        width: 2500, // 50%
      );
      final cols = resolveTableColumnWidths(t, availableWidth: 800).columns;
      expect(cols[0] + cols[1], closeTo(400, 0.1)); // 50% of 800
      expect(cols[0], closeTo(200, 0.1));
      expect(cols[1], closeTo(200, 0.1));
    });

    test('dxa is an absolute twips width', () {
      final t = table(
        grid: [1000, 1000],
        widthType: DocxWidthType.dxa,
        width: 3000, // 200px
      );
      final cols = resolveTableColumnWidths(t, availableWidth: 600).columns;
      expect(cols[0] + cols[1], closeTo(200, 0.1));
      expect(cols[0], closeTo(100, 0.1));
    });
  });

  group('w:tblInd', () {
    test('reduces the width available to autofit', () {
      final t = table(grid: [12000, 12000], indentTwips: 1440); // 96px indent
      // 24000tw = 1600px overflow; usable = 600 - 96 = 504.
      final cols = resolveTableColumnWidths(t, availableWidth: 600).columns;
      expect(cols[0] + cols[1], closeTo(504, 0.5));
    });
  });

  group('min-width floor (content autofit)', () {
    test('raises a too-narrow column and pays from columns with slack', () {
      final t = table(grid: [1000, 1000]); // both 66.67px, sum 133.33
      // Scale to a wider table to create slack, then floor column 0.
      final cols = resolveTableColumnWidths(
        t,
        availableWidth: 300, // grid 133 < 300, so kept at 133
        minColumnWidths: [120, 0],
      ).columns;
      // col0 floored to 120; total unchanged (deficit taken from col1's slack).
      expect(cols[0], closeTo(120, 0.1));
      expect(cols[0] + cols[1], closeTo(133.33, 0.1));
      expect(cols[1], closeTo(13.33, 0.1));
    });

    test('overflows when every column is already at its minimum', () {
      final t = table(grid: [1000, 1000]); // 133.33px total
      final cols = resolveTableColumnWidths(
        t,
        availableWidth: 300,
        minColumnWidths: [100, 100], // 200 > 133.33, no slack anywhere
      ).columns;
      expect(cols[0], closeTo(100, 0.1));
      expect(
          cols[1], closeTo(100, 0.1)); // table grows past the grid (Word too)
    });
  });

  group('resolveCellMargins', () {
    test('defaults to Word 108tw sides / 0 top-bottom', () {
      final t = table(grid: [1000, 1000]);
      final m = resolveCellMargins(t, null);
      expect(m.left, closeTo(kDefaultCellSideMarginTwips * kTwipsToPx, 0.001));
      expect(m.right, closeTo(kDefaultCellSideMarginTwips * kTwipsToPx, 0.001));
      expect(m.top, 0);
      expect(m.bottom, 0);
    });

    test('per-cell tcMar overrides the table default', () {
      final t = table(
        grid: [1000, 1000],
        defaultCellMargins: const DocxCellMargins(left: 200, right: 200),
      );
      final cell = DocxTableCell(
        margins: const DocxCellMargins(left: 50),
        children: const [
          DocxParagraph(children: [DocxText('x')])
        ],
      );
      final m = resolveCellMargins(t, cell);
      expect(m.left, closeTo(50 * kTwipsToPx, 0.001)); // tcMar wins
      expect(m.right, closeTo(200 * kTwipsToPx, 0.001)); // table default
    });

    test('legacy uniform cellPadding overrides the side defaults', () {
      final t = table(
        grid: [1000, 1000],
        style: const DocxTableStyle(cellPadding: 144), // 9.6px every side
      );
      final m = resolveCellMargins(t, null);
      expect(m.left, closeTo(9.6, 0.01));
      expect(m.top, closeTo(9.6, 0.01));
    });
  });

  group('cellContentWidthPx', () {
    test('sums spanned columns minus side margins', () {
      final cols = [100.0, 100.0, 100.0];
      const m = ResolvedCellMargins(7.2, 7.2, 0, 0);
      expect(cellContentWidthPx(cols, 0, 2, m), closeTo(185.6, 0.01));
    });

    test('never returns below 1px', () {
      final cols = [4.0];
      const m = ResolvedCellMargins(7.2, 7.2, 0, 0);
      expect(cellContentWidthPx(cols, 0, 1, m), 1.0);
    });
  });
}
