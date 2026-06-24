import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// QA-03 follow-ups (03-run-rpr.md review):
///   • E7 — [SpanFactory.resolveSingleLineHeightPx] must read the *script* of the
///     first run's first glyph, not always prefer `w:szCs`.
///   • E1 — a bordered run (`w:bdr`) is measured with [TextScaler.noScaling]; the
///     renderer must pin the same scaler so the box stays measure ≡ render even
///     under an OS text-scale factor ≠ 1.0.
void main() {
  late SpanFactory spanFactory;
  late ParagraphBuilder builder;

  setUp(() {
    final t = DocxViewTheme.light();
    const config = DocxViewConfig(enableSelection: false);
    final dt = DocxTheme.empty();
    spanFactory = SpanFactory(theme: t, config: config, docxTheme: dt);
    builder = ParagraphBuilder(theme: t, config: config, docxTheme: dt);
  });

  group('E7 — single-line height is script-aware (sz vs szCs)', () {
    test('Latin-opening run uses w:sz, not w:szCs', () {
      // First glyph is strong Latin → effective size is `w:sz` (10pt).
      final latinFirst = DocxParagraph(children: const [
        DocxText('Hello שלום', fontSize: 10, fontSizeCs: 20),
      ]);
      expect(spanFactory.resolveSingleLineHeightPx(latinFirst),
          closeTo(10 * 1.333, 0.01));
    });

    test('Hebrew-opening run uses w:szCs', () {
      // First glyph is complex (Hebrew) → effective size is `w:szCs` (20pt).
      final hebrewFirst = DocxParagraph(children: const [
        DocxText('שלום Hello', fontSize: 10, fontSizeCs: 20),
      ]);
      expect(spanFactory.resolveSingleLineHeightPx(hebrewFirst),
          closeTo(20 * 1.333, 0.01));
    });

    test('explicit w:rtl forces a leading neutral to complex → szCs', () {
      // A run opening with a neutral char (here a parenthesis) is Latin on its
      // own, but an explicit `w:rtl` forces the neutral into the complex script
      // (matching resolveRunSegments), so the line height reads `w:szCs`.
      // (ASCII digits stay Latin — Word keeps 0-9 in the ascii font — so they
      // are deliberately *not* used here.)
      final rtlNeutral = DocxParagraph(children: const [
        DocxText('(test)', fontSize: 10, fontSizeCs: 20, rtl: true),
      ]);
      expect(spanFactory.resolveSingleLineHeightPx(rtlNeutral),
          closeTo(20 * 1.333, 0.01));
    });
  });

  group('E1 — bordered box is text-scale invariant', () {
    Finder borderedBox() => find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).border != null);

    testWidgets('box size does not grow with the OS text-scale factor',
        (tester) async {
      final p = DocxParagraph(children: const [
        DocxText('שלום A',
            textBorder:
                DocxBorderSide(style: DocxBorder.single, size: 8, space: 6)),
      ]);

      Future<Size> boxSizeUnder(TextScaler scaler) async {
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 400, child: builder.build(p)),
              ),
            );
          }),
        ));
        return tester.getSize(borderedBox());
      }

      final base = await boxSizeUnder(TextScaler.noScaling);
      final scaled = await boxSizeUnder(const TextScaler.linear(2.0));
      // Without the fix the inner Text.rich would scale 2× and the box would be
      // wider/taller than the measurer reserved.
      expect(scaled.width, closeTo(base.width, 0.5),
          reason: 'box width must be scale-invariant');
      expect(scaled.height, closeTo(base.height, 0.5),
          reason: 'box height must be scale-invariant');
    });
  });
}
