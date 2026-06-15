import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/utils/page_fit.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:flutter/material.dart';
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

  // QA F4: the slot wraps the page's natural footprint (page size *including*
  // its outer margin band). It must scale uniformly (aspect preserved) and show
  // a fitting page at 100% — the old BoxFit.fill + margin-less slot distorted
  // the page and rendered it slightly under 100%.
  group('buildPageFitSlot', () {
    // A page footprint of 300x400 (portrait aspect 0.75) used as the child.
    const slotW = 300.0;
    const slotH = 400.0;

    Future<Size> pumpSlot(WidgetTester tester, double viewport) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: viewport,
            child: buildPageFitSlot(
              slotWidth: slotW,
              slotHeight: slotH,
              maxWidth: viewport,
              child: const SizedBox(width: slotW, height: slotH),
            ),
          ),
        ),
      ));
      // The FittedBox fills the scaled SizedBox, so its size reflects the scale.
      return tester.getSize(find.byType(FittedBox));
    }

    testWidgets('a page wider than the viewport shrinks uniformly',
        (tester) async {
      final size = await pumpSlot(tester, 150); // half of 300
      expect(size.width, closeTo(150, 0.5), reason: 'scaled to fit width');
      expect(size.height, closeTo(200, 0.5), reason: '400 * 0.5');
      expect(size.width / size.height, closeTo(slotW / slotH, 1e-6),
          reason: 'aspect ratio preserved (no distortion)');
    });

    testWidgets('a page that fits is shown at 100%', (tester) async {
      final size = await pumpSlot(tester, 1000); // wider than the page
      expect(size.width, closeTo(slotW, 0.5));
      expect(size.height, closeTo(slotH, 0.5));
    });
  });

  // QA F4: the slot footprint the wrapper measures must include the page's outer
  // margin band on every side; otherwise it scales/fits the wrong size and the
  // page renders slightly under 100% and distorted.
  test('pageSlot footprint includes the outer page margin on both sides', () {
    const config = DocxViewConfig(pageWidth: 600, pageHeight: 800);
    final gen = DocxWidgetGenerator(config: config);
    const band = DocxWidgetGenerator.pageOuterMargin * 2;
    expect(gen.pageSlotWidth(), gen.pageDisplayWidth() + band);
    expect(gen.pageSlotHeight(), gen.pageDisplayHeight() + band);
  });
}
