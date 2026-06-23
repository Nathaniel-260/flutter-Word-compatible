import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 03-run-rpr.md item 37: a run border (`w:bdr`) is an atomic box. The geometry
/// (w:space padding + w:sz border width) is shared via [SpanFactory.textBorderBox]
/// so the measurer reserves exactly the box the renderer paints (measure ≡ render),
/// and `w:space` is honoured as the inner padding.
void main() {
  late SpanFactory spanFactory;
  late TextMeasurer measurer;
  late ParagraphBuilder builder;

  setUp(() {
    final t = DocxViewTheme.light();
    const config = DocxViewConfig(enableSelection: false);
    final dt = DocxTheme.empty();
    spanFactory = SpanFactory(theme: t, config: config, docxTheme: dt);
    measurer = TextMeasurer(spanFactory: spanFactory);
    builder = ParagraphBuilder(theme: t, config: config, docxTheme: dt);
  });

  test('textBorderBox: w:space (pt)→px padding, w:sz/8→border width', () {
    final box = spanFactory.textBorderBox(
        const DocxBorderSide(style: DocxBorder.single, size: 8, space: 6));
    expect(box, isNotNull);
    expect(box!.borderWidth, closeTo(1.0, 0.001)); // 8 eighth-points = 1pt
    expect(box.padH, closeTo(6 * 96 / 72, 0.001)); // 6pt → 8px
    // Larger space → larger padding.
    final wide = spanFactory.textBorderBox(
        const DocxBorderSide(style: DocxBorder.single, size: 8, space: 12));
    expect(wide!.padH, greaterThan(box.padH));
    // No / none border → null.
    expect(spanFactory.textBorderBox(null), isNull);
    expect(spanFactory.textBorderBox(const DocxBorderSide.none()), isNull);
  });

  test('a bordered run is one atomic placeholder in the measurer', () {
    const run = DocxText('שלום A',
        textBorder: DocxBorderSide(style: DocxBorder.single, size: 8, space: 6));
    final built = spanFactory.buildMeasurementSpans(const [run]);
    // One WidgetSpan box → one placeholder, one atomic (unsplittable) segment.
    expect(built.placeholders, hasLength(1));
    expect(built.segments, hasLength(1));
    expect(built.segments.single.atomic, isTrue);
    expect(built.segments.single.length, 1);
  });

  testWidgets('bordered run: measure ≡ render (Hebrew+Latin)', (tester) async {
    final p = DocxParagraph(
      isRtl: true,
      children: const [
        DocxText('שלום A',
            textBorder:
                DocxBorderSide(style: DocxBorder.single, size: 8, space: 6)),
      ],
    );
    final measured =
        measurer.measureParagraph(p, 400, direction: TextDirection.rtl);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 400, child: builder.build(p)),
        ),
      ),
    ));
    // The outer paragraph RichText height includes the boxed run (a middle-
    // aligned placeholder); it must equal the measured content height.
    final rendered = tester.getSize(find.byType(RichText).first).height;
    expect(measured.textHeight, closeTo(rendered, 0.5),
        reason: 'measured ${measured.textHeight} vs rendered $rendered');
  });
}
