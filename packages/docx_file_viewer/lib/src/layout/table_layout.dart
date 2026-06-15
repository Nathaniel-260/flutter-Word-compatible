import 'package:docx_creator/docx_creator.dart';

/// Table column-width resolution (Plan §F.1).
///
/// This is a **pure, widget-free module** shared by the paginator (which uses it
/// to measure a table's row heights for page packing) and the table renderer (so
/// the widths a table is *measured* at equal the widths it is *painted* at — the
/// measurement≡rendering invariant the whole engine rests on).

/// twips → logical pixels at 96 DPI (1 px = 15 twips).
const double kTwipsToPx = 1 / 15.0;

/// Word's built-in default cell side margins (`w:tblCellMar`): 108 twips left and
/// right, 0 top and bottom. Used when neither the table nor the cell specifies
/// margins.
const int kDefaultCellSideMarginTwips = 108;

/// `w:tblW w:type="pct"` is expressed in fiftieths of a percent (5000 = 100%).
const double _pctDenominator = 5000.0;

/// Resolved px width of every grid column of a table, one entry per `w:gridCol`.
///
/// A spanning cell (`w:gridSpan`) covers several consecutive entries; the
/// renderer/measurer sums them via [cellContentWidthPx]. Widths are symmetric —
/// `w:bidiVisual` mirrors only the *visual* column order, not the widths — so
/// this list stays in logical (grid) order.
class TableColumnLayout {
  const TableColumnLayout(this.columns);

  final List<double> columns;

  double get totalWidth => columns.fold(0.0, (a, b) => a + b);

  int get columnCount => columns.length;
}

/// Resolves the px width of every grid column for [table] (Plan §F.1).
///
/// - **fixed** (`w:tblLayout="fixed"`): the grid/`tcW` widths are authoritative
///   and honoured verbatim; a fixed table may overflow [availableWidth] (Word
///   does not shrink it — the renderer scales/clips). `w:tblW` is informational
///   in this mode and does not rescale the grid (matches Word).
/// - **autofit**: the grid encodes Word's last content fit, so it is honoured and
///   only scaled *down* proportionally when it would exceed [availableWidth]. When
///   [minColumnWidths] is supplied (the longest-word px of each column) no column
///   is scaled below its content minimum — the deficit is taken from columns that
///   still have slack (the CSS `table-layout:auto` floor).
/// - `w:tblW pct` → a percentage of [availableWidth]; `w:tblW dxa` → an absolute
///   twips width.
/// - `w:tblInd` shifts the table inward, reducing the width available to autofit.
///
/// Pass `availableWidth: double.infinity` when the caller has no width bound (a
/// nested table, whose enclosing cell already constrains it): the grid is then
/// used verbatim.
TableColumnLayout resolveTableColumnWidths(
  DocxTable table, {
  required double availableWidth,
  List<double>? minColumnWidths,
}) {
  final grid = table.resolvedGridColumns;
  final n = grid.length;
  if (n == 0) return const TableColumnLayout(<double>[]);

  final indentPx = (table.indentTwips ?? 0) * kTwipsToPx;
  final double usable;
  if (!availableWidth.isFinite) {
    usable = double.infinity;
  } else {
    final u = availableWidth - (indentPx > 0 ? indentPx : 0.0);
    usable = u < 1.0 ? 1.0 : u;
  }

  var gridPx = grid.map((tw) => tw * kTwipsToPx).toList();
  var gridSum = gridPx.fold(0.0, (a, b) => a + b);
  if (gridSum <= 0) {
    // Degenerate grid (all-zero): fall back to an equal split of the usable
    // width so the table at least lays out.
    final w = (usable.isFinite ? usable : 0.0) / n;
    gridPx = List<double>.filled(n, w > 0 ? w : 1.0);
    gridSum = gridPx.fold(0.0, (a, b) => a + b);
  }

  // Target total table width from `w:tblW`, if any.
  double? target;
  switch (table.widthType) {
    case DocxWidthType.pct:
      if (table.width != null && availableWidth.isFinite) {
        target = (table.width! / _pctDenominator) * availableWidth;
      }
      break;
    case DocxWidthType.dxa:
      if (table.width != null && table.width! > 0) {
        target = table.width! * kTwipsToPx;
      }
      break;
    case DocxWidthType.auto:
      break;
  }

  if (table.layout == DocxTableLayout.fixed) {
    // Fixed layout: the grid/`tcW` widths are authoritative and `w:tblW` is
    // informational, so the grid is used verbatim (the table may overflow — Word
    // does not shrink a fixed table; the renderer scales/clips).
    return TableColumnLayout(gridPx);
  }

  // Autofit: honour the grid (or `w:tblW`), capped to the usable width.
  var tableWidth = target ?? gridSum;
  if (usable.isFinite && tableWidth > usable) tableWidth = usable;
  var widths = (tableWidth - gridSum).abs() > 0.5 && gridSum > 0
      ? _scale(gridPx, gridSum, tableWidth)
      : List<double>.of(gridPx);

  if (minColumnWidths != null && minColumnWidths.length == n) {
    widths = _applyMinWidths(widths, minColumnWidths);
  }
  return TableColumnLayout(widths);
}

List<double> _scale(List<double> px, double from, double to) {
  final f = to / from;
  return px.map((w) => w * f).toList();
}

/// Raises any column below its content minimum and pays for it from columns that
/// still have slack above their own minimum (CSS `table-layout:auto` floor). If
/// every column is already at its minimum the table simply overflows — as it does
/// in Word.
List<double> _applyMinWidths(List<double> widths, List<double> mins) {
  final out = List<double>.of(widths);
  var deficit = 0.0;
  for (var i = 0; i < out.length; i++) {
    if (out[i] < mins[i]) {
      deficit += mins[i] - out[i];
      out[i] = mins[i];
    }
  }
  if (deficit <= 0) return out;

  var slack = 0.0;
  for (var i = 0; i < out.length; i++) {
    final s = out[i] - mins[i];
    if (s > 0) slack += s;
  }
  if (slack <= 0) return out;

  final take = deficit < slack ? deficit : slack;
  for (var i = 0; i < out.length; i++) {
    final s = out[i] - mins[i];
    if (s > 0) out[i] -= take * (s / slack);
  }
  return out;
}

/// Effective cell margins in **pixels** (Plan §F.3): per-cell `w:tcMar` overrides
/// the table's `w:tblCellMar`, which itself defaults to Word's 108tw left/right
/// and 0 top/bottom. The legacy uniform [DocxTableStyle.cellPadding] (twips) acts
/// as the default when no structured margins are present, and the legacy per-cell
/// `marginLeft`/`marginRight` are honoured as a final fallback.
class ResolvedCellMargins {
  const ResolvedCellMargins(this.left, this.right, this.top, this.bottom);

  final double left;
  final double right;
  final double top;
  final double bottom;
}

ResolvedCellMargins resolveCellMargins(DocxTable table, DocxTableCell? cell) {
  final tblM = table.defaultCellMargins;
  final tcM = cell?.margins;
  final legacy = table.style.cellPadding;

  // Defaults: Word uses 108tw sides / 0 top-bottom; a legacy uniform cellPadding
  // (when set) overrides those defaults on every side.
  final defSide = legacy ?? kDefaultCellSideMarginTwips;
  final defVert = legacy ?? 0;

  final l = tcM?.left ?? cell?.marginLeft ?? tblM?.left ?? defSide;
  final r = tcM?.right ?? cell?.marginRight ?? tblM?.right ?? defSide;
  final t = tcM?.top ?? tblM?.top ?? defVert;
  final b = tcM?.bottom ?? tblM?.bottom ?? defVert;

  return ResolvedCellMargins(
    l * kTwipsToPx,
    r * kTwipsToPx,
    t * kTwipsToPx,
    b * kTwipsToPx,
  );
}

/// The content width (px) available inside a cell that starts at [gridIndex] and
/// spans [span] grid columns, after subtracting its left/right [margins]. Used to
/// measure cell content at exactly the width it will be painted at.
double cellContentWidthPx(
  List<double> columns,
  int gridIndex,
  int span,
  ResolvedCellMargins margins,
) {
  var w = 0.0;
  for (var k = 0; k < span; k++) {
    final idx = gridIndex + k;
    if (idx >= 0 && idx < columns.length) w += columns[idx];
  }
  final content = w - margins.left - margins.right;
  return content < 1.0 ? 1.0 : content;
}
