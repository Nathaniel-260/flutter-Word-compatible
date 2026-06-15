import 'package:flutter/widgets.dart';

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

/// Wraps a fixed-size [child] page so it scales **down** uniformly to fit
/// [maxWidth].
///
/// [slotWidth]/[slotHeight] are the child's *natural footprint* — the page size
/// **including** its outer margin band — so the scale ([pageFitScale]) and the
/// surrounding [SizedBox] share the child's aspect ratio. As a result a page
/// that fits is shown at exactly 100%, and a page wider than the viewport
/// shrinks with its aspect ratio preserved. `BoxFit.contain` keeps the scaling
/// uniform even if the child's intrinsic size ever drifts from the slot (it
/// letterboxes instead of distorting). Non-finite [maxWidth] (first layout
/// pass) falls back to the natural width (100%).
Widget buildPageFitSlot({
  required double slotWidth,
  required double slotHeight,
  required double maxWidth,
  required Widget child,
}) {
  final maxW = maxWidth.isFinite ? maxWidth : slotWidth;
  final scale = pageFitScale(maxW, slotWidth);
  return Container(
    width: maxW,
    height: slotHeight * scale,
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: slotWidth * scale,
      height: slotHeight * scale,
      child: FittedBox(fit: BoxFit.contain, child: child),
    ),
  );
}
