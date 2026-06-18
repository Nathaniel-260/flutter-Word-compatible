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

/// Gap in pixels between adjacent columns.
double columnGapPx(DocxColumns cols) => cols.spaceTwips / 15.0;
