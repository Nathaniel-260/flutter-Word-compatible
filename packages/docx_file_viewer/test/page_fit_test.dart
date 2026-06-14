import 'package:docx_file_viewer/src/utils/page_fit.dart';
import 'package:flutter_test/flutter_test.dart';

/// `fitPageToWidth` policy: scale a fixed-size page down to the viewport, never
/// up, so line/page breaks (computed at the real page width) stay constant while
/// the page is always fully visible.
void main() {
  const a4 = 794.0;

  test('a narrow viewport scales the page down to fit', () {
    expect(pageFitScale(400, a4), closeTo(400 / a4, 1e-9));
    expect(pageFitScale(a4 / 2, a4), closeTo(0.5, 1e-9));
  });

  test('a viewport at least as wide as the page shows it at 100%', () {
    expect(pageFitScale(a4, a4), 1.0);
    expect(pageFitScale(1200, a4), 1.0);
  });

  test('degenerate viewports fall back to 100% (no crash on first layout)', () {
    expect(pageFitScale(double.infinity, a4), 1.0);
    expect(pageFitScale(0, a4), 1.0);
    expect(pageFitScale(double.nan, a4), 1.0);
    expect(pageFitScale(400, 0), 1.0);
  });
}
