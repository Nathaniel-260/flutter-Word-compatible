/// The scale to apply to a fixed-size page so it fits the viewport width.
///
/// Returns `available / pageWidth` when the page is wider than the viewport, and
/// `1.0` otherwise — i.e. it scales **down** to fit but never enlarges a page
/// that already fits. This is purely a display zoom: the page is laid out (and
/// line/page-broken) at its real [pageWidth] first, so pagination is identical
/// regardless of window size; only the rendered page is shrunk to stay fully
/// visible instead of being clipped. Defensive against a zero/NaN/∞ viewport
/// (returns 1.0), which can occur during the first layout pass.
double pageFitScale(double available, double pageWidth) {
  if (pageWidth <= 0 || !available.isFinite || available <= 0) return 1.0;
  if (available >= pageWidth) return 1.0;
  return available / pageWidth;
}
