import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// §2.4 item 23 — a paragraph border's `w:space` (points) is painted as inner
/// padding by [ParagraphBuilder] and mirrored by [TextMeasurer], so the *delta*
/// it adds to the block footprint is identical in measure and render
/// (measure ≡ render). We compare deltas (with vs without space) to isolate the
/// border-space contribution from the pre-existing border-width inset.
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

  const width = 240.0;
  // 4 pt top + 2 pt bottom border space → px at 96 DPI.
  const expectedDeltaPx = (4 + 2) * (96.0 / 72.0);

  DocxParagraph para({required bool withSpace}) => DocxParagraph(
        children: [DocxText('שלום world — bordered paragraph')],
        borderTop: DocxBorderSide(
          style: DocxBorder.single,
          size: 8,
          space: withSpace ? 4 : 0,
        ),
        borderBottomSide: DocxBorderSide(
          style: DocxBorder.single,
          size: 8,
          space: withSpace ? 2 : 0,
        ),
      );

  Future<double> outerHeight(WidgetTester tester, DocxParagraph p) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: builder.build(p)),
        ),
      ),
    ));
    return tester.getSize(find.byType(Container).first).height;
  }

  testWidgets('border space delta is identical in measure and render',
      (tester) async {
    final withSpace = para(withSpace: true);
    final without = para(withSpace: false);

    final measuredDelta = measurer.measureParagraph(withSpace, width).totalHeight -
        measurer.measureParagraph(without, width).totalHeight;

    final renderedDelta =
        await outerHeight(tester, withSpace) - await outerHeight(tester, without);

    expect(measuredDelta, closeTo(expectedDeltaPx, 0.5));
    expect(renderedDelta, closeTo(expectedDeltaPx, 0.5));
    expect(measuredDelta, closeTo(renderedDelta, 0.5));
  });

  testWidgets('no border space → no footprint change (no regression)',
      (tester) async {
    final plain = DocxParagraph(children: [DocxText('plain טקסט')]);
    final m = measurer.measureParagraph(plain, width);
    // spacingBefore/After are unaffected when there is no border.
    expect(m.spacingBefore, 0);
    expect(m.spacingAfter, 0);
  });

  testWidgets('a none-style border with space adds no footprint (edge ג)',
      (tester) async {
    // A rule-less side (style == none) must not reserve its w:space — there is
    // no visible border, so Word draws no gap. Guarded identically in measure
    // and render.
    final p = DocxParagraph(
      children: [DocxText('טקסט none-border')],
      borderTop: const DocxBorderSide(style: DocxBorder.none, space: 8),
    );
    final m = measurer.measureParagraph(p, width);
    expect(m.spacingBefore, 0);
  });
}
