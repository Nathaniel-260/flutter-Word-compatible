import 'dart:math' as math;

import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/widgets.dart';

import 'span_factory.dart';
import 'table_layout.dart';

/// Computes the per-grid-column minimum widths for an **autofit** [table]: the
/// width below which a column must not shrink, or its longest unbreakable word
/// would be clipped (the CSS `table-layout:auto` content floor). The result is
/// fed to [resolveTableColumnWidths] as `minColumnWidths`; `fixed` tables and
/// nested tables (infinite available width) ignore it.
///
/// **Deterministic by construction.** It builds spans through [spanFactory] (the
/// same span construction the measurer uses) and lays them out on an unscaled
/// [TextPainter]. The paginator and the renderer hold *separate* span factories,
/// but both are built from the same theme/config/document, so they derive the
/// **identical** vector — keeping measurement ≡ rendering for table widths
/// (QA F3). Returns an all-zero vector when there is nothing to floor.
List<double> computeMinColumnWidths(DocxTable table, SpanFactory spanFactory) {
  final n = table.resolvedGridColumns.length;
  if (n == 0) return const <double>[];
  final mins = List<double>.filled(n, 0.0);

  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  );
  try {
    for (final row in table.rows) {
      var gridIndex = row.gridBefore;
      for (final cell in row.cells) {
        final span = cell.colSpan > 0 ? cell.colSpan : 1;
        final word = _cellLongestWordPx(cell, spanFactory, painter);
        if (word > 0) {
          final margins = resolveCellMargins(table, cell);
          // The covered column(s) must hold the word plus the cell's side
          // margins. A spanning cell shares its minimum across the columns it
          // covers (their widths sum), so the floor stays correct without
          // over-inflating a single column.
          final colMin = (word + margins.left + margins.right) / span;
          for (var k = 0; k < span; k++) {
            final idx = gridIndex + k;
            if (idx >= 0 && idx < n && colMin > mins[idx]) mins[idx] = colMin;
          }
        }
        gridIndex += span;
      }
    }
  } finally {
    painter.dispose();
  }
  return mins;
}

/// The widest unbreakable token (px) anywhere in [cell]'s text content.
double _cellLongestWordPx(
    DocxTableCell cell, SpanFactory sf, TextPainter painter) {
  var maxW = 0.0;
  for (final block in cell.children) {
    if (block is DocxParagraph) {
      maxW = math.max(maxW, _inlinesLongestWordPx(block.children, sf, painter));
    } else if (block is DocxList) {
      for (final item in block.items) {
        maxW =
            math.max(maxW, _inlinesLongestWordPx(item.children, sf, painter));
      }
    }
    // A nested DocxTable is bounded by its own cells; it imposes no content
    // floor on the parent column (Plan §F.1: a nested grid is honoured as-is).
  }
  return maxW;
}

double _inlinesLongestWordPx(
    List<DocxInline> inlines, SpanFactory sf, TextPainter painter) {
  var maxW = 0.0;
  for (final inline in inlines) {
    if (inline is! DocxText) continue;
    final content = inline.content;
    if (content.trim().isEmpty) continue;
    for (final word in content.split(_whitespace)) {
      if (word.isEmpty) continue;
      // Build and lay out the single word exactly as the measurer builds cell
      // text, at unbounded width → its intrinsic (un-wrapped) px width.
      final built =
          sf.buildMeasurementSpans([inline.copyWith(content: word)],
              skipHidden: true);
      final root = built.root;
      // Hidden runs (w:vanish) build to nothing → no contribution.
      if (root is TextSpan && (root.children?.isEmpty ?? root.text == null)) {
        continue;
      }
      painter
        ..text = root
        ..layout();
      if (painter.width > maxW) maxW = painter.width;
    }
  }
  return maxW;
}

final RegExp _whitespace = RegExp(r'\s+');
