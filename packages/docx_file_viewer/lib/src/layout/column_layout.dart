import 'package:docx_creator/docx_creator.dart';

/// Resolves [DocxColumns] into a list of column pixel-widths that fills
/// [contentWidth] exactly (Plan §I.1).
///
/// For equal-width layouts the available space is divided evenly after
/// subtracting the inter-column gaps. For explicit layouts the `w:col` widths
/// are taken verbatim (Word already bakes the correct values). If the explicit
/// list is shorter than [DocxColumns.count] the last explicit width is repeated.
List<double> resolveColumnWidths(DocxColumns cols, double contentWidth) {
  final n = cols.count.clamp(1, 64);
  final explicit = cols.explicit;
  if (!cols.equalWidth && explicit != null && explicit.isNotEmpty) {
    return List.generate(n, (i) {
      final c = i < explicit.length ? explicit[i] : explicit.last;
      return ((c.widthTwips ?? 0) / 15.0).clamp(0.0, contentWidth);
    });
  }
  // Equal width: subtract all gaps then divide.
  final gapPx = cols.spaceTwips / 15.0;
  final totalGap = gapPx * (n - 1);
  final colW = ((contentWidth - totalGap) / n).clamp(0.0, contentWidth);
  return List.filled(n, colW);
}

/// Gap in pixels between adjacent columns (the default `w:space`). Used for
/// equal-width layouts where every gap is the same; for per-column gaps in
/// explicit layouts use [resolveColumnGaps].
double columnGapPx(DocxColumns cols) => cols.spaceTwips / 15.0;

/// Resolves the [n]-1 inter-column gaps in pixels (Plan §I.1).
///
/// Equal-width layouts use the single default `w:space` for every gap. Explicit
/// (`w:equalWidth="0"`) layouts honour each `w:col`'s own `w:space` (the space
/// *after* that column), falling back to the section default when a column omits
/// it — this matches Word, where explicit columns carry their own spacing and
/// using the default for all of them would mis-size the row (and can overflow).
List<double> resolveColumnGaps(DocxColumns cols, int n) {
  if (n <= 1) return const [];
  final defaultGap = cols.spaceTwips / 15.0;
  final explicit = cols.explicit;
  if (!cols.equalWidth && explicit != null && explicit.isNotEmpty) {
    return List.generate(n - 1, (i) {
      final c = i < explicit.length ? explicit[i] : explicit.last;
      final sp = c.spaceTwips;
      return sp != null ? sp / 15.0 : defaultGap;
    });
  }
  return List.filled(n - 1, defaultGap);
}
