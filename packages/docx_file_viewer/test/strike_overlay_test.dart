import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/font_loader/font_metrics_registry.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 03-run-rpr.md items 14/15: a `w:strike`/`w:dstrike` run is drawn by a
/// line-aware paint overlay (`_StrikeOverlay`/`_StrikeLinesPainter`) over the
/// flowing text — crisp, centred line(s) like Word — instead of Flutter's own
/// line-through. The text stays flowing so Hebrew bidi order and wrapping are
/// preserved (an inline box would reverse a run of struck words under bidi).
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
    FontMetricsRegistry.registerRatio('Arial', 1.15);
    FontMetricsRegistry.registerRatio('David', 1.0);
  });

  tearDown(FontMetricsRegistry.clear);

  bool spansHaveLineThrough(List<InlineSpan> spans) {
    for (final s in spans) {
      if (s is TextSpan) {
        if (s.style?.decoration?.contains(TextDecoration.lineThrough) ??
            false) {
          return true;
        }
        if (s.children != null && spansHaveLineThrough(s.children!)) return true;
      }
    }
    return false;
  }

  test('the default (non-overlay) path keeps the run\'s own line-through', () {
    // Lists / drop caps / selection keep Flutter's line-through; the overlay
    // path (verified in the widget test below) strips it and paints instead.
    const run = DocxText('שלום', isDoubleStrike: true);
    expect(spansHaveLineThrough(builder.buildInlineSpans(const [run])), isTrue);
  });

  testWidgets('a struck paragraph wires up the strike overlay painter',
      (tester) async {
    final p = DocxParagraph(
      isRtl: true,
      children: const [
        DocxText('טקסט עם '),
        DocxText('קו חוצה', decorations: [DocxTextDecoration.strikethrough]),
        DocxText(', '),
        DocxText('קו חוצה כפול', isDoubleStrike: true),
        DocxText('.'),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 260, child: builder.build(p)),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);

    // The strike overlay widget is wired in (private type matched by name).
    expect(
        find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_StrikeText'),
        findsOneWidget);

    // The rendered text flows with NO Flutter line-through (the overlay draws it).
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    expect(spansHaveLineThrough([rich.text]), isFalse);
  });

  testWidgets('measure ≡ render is preserved for a struck paragraph',
      (tester) async {
    final p = DocxParagraph(
      isRtl: true,
      children: const [
        DocxText('טקסט רגיל עם '),
        DocxText('קו חוצה כפול', isDoubleStrike: true),
        DocxText(' וטקסט נוסף ארוך מספיק כדי לעטוף לכמה שורות עבור בדיקת '
            'זהות-המדידה לאורך רוחב הפסקה כאן.'),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 200, child: builder.build(p)),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    final measured =
        measurer.measureParagraph(p, 200.0, direction: TextDirection.rtl);
    final rendered = tester.getSize(find.byType(RichText).first).height;
    expect(measured.textHeight, closeTo(rendered, 0.5),
        reason: 'measured ${measured.textHeight} vs rendered $rendered');
  });
}
