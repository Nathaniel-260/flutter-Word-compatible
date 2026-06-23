import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 03-run-rpr.md item 1: an empty paragraph occupies one line (Word measures it
/// via the paragraph-mark run). The renderer used to collapse it to zero height
/// while the measurer reserved a line — a measure≠render gap now closed. The
/// line's size follows the mark run's `w:sz` when set directly.
void main() {
  late TextMeasurer measurer;
  late ParagraphBuilder builder;

  setUp(() {
    final t = DocxViewTheme.light();
    const config = DocxViewConfig(enableSelection: false);
    final dt = DocxTheme.empty();
    final spanFactory = SpanFactory(theme: t, config: config, docxTheme: dt);
    measurer = TextMeasurer(spanFactory: spanFactory);
    builder = ParagraphBuilder(theme: t, config: config, docxTheme: dt);
  });

  Future<double> renderedContentHeight(
    WidgetTester tester,
    DocxParagraph p,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 300, child: builder.build(p)),
        ),
      ),
    ));
    // The blank line is a RichText, like a normal paragraph's content — compare
    // it to the measurer's content height (no paragraph spacing).
    return tester.getSize(find.byType(RichText).first).height;
  }

  testWidgets('empty paragraph renders one line (not zero) — measure ≡ render',
      (tester) async {
    const empty = DocxParagraph(children: []);
    final measured = measurer.measureParagraph(empty, 300);
    final rendered = await renderedContentHeight(tester, empty);
    expect(rendered, greaterThan(0)); // previously collapsed to 0
    expect(measured.textHeight, closeTo(rendered, 0.5),
        reason: 'measured ${measured.textHeight} vs rendered $rendered');
  });

  testWidgets('empty paragraph height follows the mark font size',
      (tester) async {
    const small = DocxParagraph(children: [], markRunFontSize: 8);
    const large = DocxParagraph(children: [], markRunFontSize: 40);

    final hSmall = await renderedContentHeight(tester, small);
    final hLarge = await renderedContentHeight(tester, large);
    // 40pt vs 8pt → the large blank line is several times taller.
    expect(hLarge, greaterThan(hSmall * 3));

    // measure ≡ render for the explicitly-sized blank line.
    final mLarge = measurer.measureParagraph(large, 300);
    expect(mLarge.textHeight, closeTo(hLarge, 0.5),
        reason: 'measured ${mLarge.textHeight} vs rendered $hLarge');
  });

  testWidgets('a paragraph with no mark size is unchanged (body default)',
      (tester) async {
    const plain = DocxParagraph(children: []);
    const oneLine = DocxParagraph(children: [DocxText('X')]);
    final hEmpty = await renderedContentHeight(tester, plain);
    final hText = await renderedContentHeight(tester, oneLine);
    // Both are a single body-font line → same height.
    expect(hEmpty, closeTo(hText, 0.5));
  });
}
