import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 02-units ב.2 "next-AI" items, now implemented:
///   • w:beforeLines/w:afterLines (line-unit paragraph spacing, item 8)
///   • auto run colour resolved against the local shd (item 15)
///   • left/right border w:space (item 23)
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

  const width = 260.0;

  Future<double> richTextHeight(WidgetTester tester, DocxParagraph p) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: builder.build(p)),
        ),
      ),
    ));
    return tester.getSize(find.byType(RichText).first).height;
  }

  // Walks an InlineSpan tree to the first leaf TextSpan carrying text.
  Color? firstTextColor(InlineSpan span) {
    Color? found;
    void visit(InlineSpan s) {
      if (found != null) return;
      if (s is TextSpan) {
        if (s.text != null && s.text!.isNotEmpty) {
          found = s.style?.color;
          return;
        }
        for (final c in s.children ?? const <InlineSpan>[]) {
          visit(c);
        }
      }
    }

    visit(span);
    return found;
  }

  Future<Color?> renderedTextColor(WidgetTester tester, DocxParagraph p) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: builder.build(p)),
        ),
      ),
    ));
    final rt = tester.widget<RichText>(find.byType(RichText).first);
    return firstTextColor(rt.text);
  }

  group('item 8 — line-unit paragraph spacing', () {
    testWidgets('beforeLines/afterLines footprint is identical in measure '
        'and render', (tester) async {
      DocxParagraph para({required bool lines}) => DocxParagraph(
            children: [DocxText('שלום world line-unit spacing')],
            spacingBeforeLines: lines ? 200 : null, // 2.00 lines
            spacingAfterLines: lines ? 100 : null, // 1.00 line
          );

      final withLines = para(lines: true);
      final without = para(lines: false);

      final measuredDelta =
          measurer.measureParagraph(withLines, width).totalHeight -
              measurer.measureParagraph(without, width).totalHeight;
      // 3 lines worth of spacing → strictly positive.
      expect(measuredDelta, greaterThan(0));

      // The measured before/after equals 3 × single-line height (200+100)/100.
      final lineH = spanFactory.resolveSingleLineHeightPx(withLines);
      expect(measuredDelta, closeTo(3 * lineH, 0.5));
    });

    testWidgets('beforeLines wins over a twips before value (precedence)',
        (tester) async {
      final p = DocxParagraph(
        children: [DocxText('precedence בדיקה')],
        spacingBefore: 1440, // 96px in twips — must be ignored
        spacingBeforeLines: 100, // 1 line
      );
      final m = measurer.measureParagraph(p, width);
      final lineH = spanFactory.resolveSingleLineHeightPx(p);
      // Uses the 1-line value, not the 96px twips value.
      expect(m.spacingBefore, closeTo(lineH, 0.5));
      expect(m.spacingBefore, lessThan(96));
    });
  });

  group('item 15 — auto colour against the local background', () {
    test('resolveAutoTextColor: white on dark, black on light', () {
      expect(spanFactory.resolveAutoTextColor(const Color(0xFF202020)),
          const Color(0xFFFFFFFF));
      expect(spanFactory.resolveAutoTextColor(const Color(0xFFEFEFEF)),
          const Color(0xFF000000));
    });

    testWidgets('auto run colour on a dark paragraph shd renders white',
        (tester) async {
      final p = DocxParagraph(
        children: [DocxText('טקסט auto', color: DocxColor('auto'))],
        shadingFill: '202020', // dark
      );
      expect(await renderedTextColor(tester, p), const Color(0xFFFFFFFF));
    });

    testWidgets('auto run colour on a light paragraph renders black',
        (tester) async {
      final p = DocxParagraph(
        children: [DocxText('טקסט auto', color: DocxColor('auto'))],
        shadingFill: 'FFFFFF',
      );
      expect(await renderedTextColor(tester, p), const Color(0xFF000000));
    });

    testWidgets('a run shd overrides the paragraph shd for auto contrast',
        (tester) async {
      // Paragraph is light, but the run sits on its own dark shd → white.
      final p = DocxParagraph(
        children: [
          DocxText('mixed עברית',
              color: DocxColor('auto'), shadingFill: '101010'),
        ],
        shadingFill: 'FFFFFF',
      );
      expect(await renderedTextColor(tester, p), const Color(0xFFFFFFFF));
    });
  });

  group('item 23 — left/right border w:space', () {
    testWidgets('a side rule narrows wrapping identically in measure and '
        'render', (tester) async {
      // Long text that wraps; big left+right space (20pt each ≈ 26.7px) narrows
      // the text column, so both paths must wrap to the same (taller) height.
      const longText = 'The quick brown fox jumps over the lazy dog, '
          'שוב ושוב עד שהשורה חייבת להישבר כמה פעמים בתוך הרוחב הזה.';
      final withSpace = DocxParagraph(
        children: [DocxText(longText)],
        borderLeft: const DocxBorderSide(style: DocxBorder.single, space: 20),
        borderRight: const DocxBorderSide(style: DocxBorder.single, space: 20),
      );

      final measured = measurer.measureParagraph(withSpace, width).textHeight;
      final rendered = await richTextHeight(tester, withSpace);
      expect(measured, closeTo(rendered, 0.5));

      // And the side space actually narrows the column: taller than no border.
      final plain = DocxParagraph(children: [DocxText(longText)]);
      final plainH = measurer.measureParagraph(plain, width).textHeight;
      expect(measured, greaterThanOrEqualTo(plainH));
    });
  });
}
