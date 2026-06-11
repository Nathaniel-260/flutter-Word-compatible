import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Minimal valid 1x1 PNG (transparent). The inline-image placeholder size comes
// from the AST (explicit width/height), so decoding correctness is irrelevant
// to layout.
final Uint8List _png1x1 = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

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

  // Renders [p] at [width] through the real ParagraphBuilder and returns the
  // height of its RichText render box — the ground truth the measurer targets.
  Future<double> renderedHeight(
    WidgetTester tester,
    DocxParagraph p,
    double width,
  ) async {
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

  group('measureParagraph height ≡ rendered height (±0.5px)', () {
    const width = 220.0;

    Future<void> expectParity(
      WidgetTester tester,
      DocxParagraph p,
      TextDirection dir,
    ) async {
      final measured = measurer.measureParagraph(p, width, direction: dir);
      final rendered = await renderedHeight(tester, p, width);
      expect(
        measured.textHeight,
        closeTo(rendered, 0.5),
        reason: 'measured ${measured.textHeight} vs rendered $rendered',
      );
    }

    testWidgets('English LTR wrapping paragraph', (tester) async {
      final p = DocxParagraph(children: [
        DocxText('The quick brown fox jumps over the lazy dog, '
            'again and again until the line must wrap several times.'),
      ]);
      await expectParity(tester, p, TextDirection.ltr);
    });

    testWidgets('Hebrew RTL wrapping paragraph', (tester) async {
      final p = DocxParagraph(
        isRtl: true,
        children: [
          DocxText('שלום עולם זהו טקסט עברי ארוך שאמור להתפצל לכמה שורות '
              'כדי לבדוק שהמדידה תואמת בדיוק לרינדור בפועל.'),
        ],
      );
      await expectParity(tester, p, TextDirection.rtl);
    });

    testWidgets('Mixed Hebrew+English in one paragraph', (tester) async {
      final p = DocxParagraph(
        isRtl: true,
        children: [
          DocxText('שלום world זהו mixed טקסט with אנגלית and עברית together '
              'בשורה אחת long enough to wrap.'),
        ],
      );
      await expectParity(tester, p, TextDirection.rtl);
    });

    testWidgets('exact line spacing', (tester) async {
      final p = DocxParagraph(
        lineRule: 'exact',
        lineSpacing: 360,
        children: [
          DocxText('Exact line spacing paragraph that wraps across two or '
              'three lines so the per-line height is exercised.'),
        ],
      );
      await expectParity(tester, p, TextDirection.ltr);
    });

    testWidgets('paragraph with an inline image', (tester) async {
      final p = DocxParagraph(children: [
        DocxText('Before image '),
        DocxInlineImage(
          bytes: _png1x1,
          extension: 'png',
          width: 60,
          height: 40,
        ),
        DocxText(' after image and some trailing text to wrap the line.'),
      ]);
      await expectParity(tester, p, TextDirection.ltr);
    });
  });

  testWidgets('hidden (w:vanish) run is not measured or rendered',
      (tester) async {
    final visible = DocxParagraph(children: [DocxText('Visible only')]);
    final withHidden = DocxParagraph(children: [
      DocxText('Visible only'),
      DocxText(' SECRETHIDDENTEXT', hidden: true),
    ]);

    final m1 = measurer.measureParagraph(visible, 1000);
    final m2 = measurer.measureParagraph(withHidden, 1000);
    // Hidden text adds neither width (single line stays one line) nor height.
    expect(m2.textHeight, closeTo(m1.textHeight, 0.5));
    expect(m2.lineCount, 1);

    // And it must not appear in the rendered output.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(withHidden)),
    ));
    final richText = tester.widget<RichText>(find.byType(RichText).first);
    expect(richText.text.toPlainText(), isNot(contains('SECRET')));
  });

  test('exact line spacing forces the per-line box height', () {
    // 480tw / 15 = 32px forced line height.
    final p = DocxParagraph(
      lineRule: 'exact',
      lineSpacing: 480,
      children: [DocxText('single line')],
    );
    final m = measurer.measureParagraph(p, 1000);
    expect(m.lineCount, 1);
    expect(m.textHeight, closeTo(32, 1.0));
  });

  testWidgets('empty paragraph measures one body line height', (tester) async {
    final m = measurer.measureParagraph(
      const DocxParagraph(children: []),
      220,
    );
    // A blank line should occupy roughly one line of the body font, not zero.
    final fontSize = DocxViewTheme.light().defaultTextStyle.fontSize ?? 14.0;
    expect(m.textHeight, greaterThan(fontSize * 0.8));
    expect(m.lineCount, 1);
  });

  group('LRU cache', () {
    final p = DocxParagraph(children: [DocxText('cache me')]);

    test('repeated measurement at same width reuses the TextPainter', () {
      measurer.measureParagraph(p, 200);
      expect(measurer.layoutCount, 1);
      expect(measurer.cacheHits, 0);

      measurer.measureParagraph(p, 200); // identical → cached
      expect(measurer.layoutCount, 1, reason: 'no new layout');
      expect(measurer.cacheHits, 1);
    });

    test('different width is a separate entry', () {
      measurer.measureParagraph(p, 200);
      measurer.measureParagraph(p, 300);
      expect(measurer.layoutCount, 2);
      expect(measurer.cacheSize, 2);
    });

    test('invalidate() forces re-measurement', () {
      measurer.measureParagraph(p, 200);
      expect(measurer.layoutCount, 1);
      measurer.invalidate();
      expect(measurer.cacheSize, 0);
      measurer.measureParagraph(p, 200);
      expect(measurer.layoutCount, 2);
    });

    test('distinct paragraphs never cross-contaminate; hit carries its source',
        () {
      final oneLine = DocxParagraph(children: [DocxText('short')]);
      final threeLines = DocxParagraph(
        lineRule: 'exact',
        lineSpacing: 480, // 32px/line
        children: [
          DocxText('line oneline twoline three'),
        ],
      );
      final a = measurer.measureParagraph(oneLine, 1000);
      final b = measurer.measureParagraph(threeLines, 1000);
      expect(a.textHeight, lessThan(b.textHeight));
      expect(identical(a.source, oneLine), isTrue);

      // Re-measuring the first returns ITS height, not the other's.
      final aAgain = measurer.measureParagraph(oneLine, 1000);
      expect(aAgain.textHeight, a.textHeight);
      expect(identical(aAgain.source, oneLine), isTrue);
    });
  });
}
