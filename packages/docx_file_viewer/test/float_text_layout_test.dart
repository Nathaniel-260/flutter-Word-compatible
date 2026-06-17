import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/layout/float_layout.dart';
import 'package:docx_file_viewer/src/layout/float_text_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §H.2 / §8.2 #29 — real text wrap around floats (the pure core).
void main() {
  const contentWidth = 200.0;

  // Space-separated single chars so the (monospaced test font) wraps predictably.
  InlineSpan longText([int words = 60]) => TextSpan(
        text: List.filled(words, 'a').join(' '),
        style: const TextStyle(fontSize: 10),
      );

  FloatRect sideFloat({
    required double left,
    required double width,
    required double height,
    double top = 0,
  }) =>
      FloatRect(
        left: left,
        top: top,
        width: width,
        height: height,
        flow: FloatFlow.side,
        zOrder: 0,
      );

  test('no floats → every line is full width at the left edge', () {
    final r = layoutFloatWrap(
      text: longText(),
      floats: const [],
      contentWidth: contentWidth,
      direction: TextDirection.ltr,
    )!;
    expect(r.lines, isNotEmpty);
    expect(
        r.lines.every((l) => l.left == 0 && l.width == contentWidth), isTrue);
  });

  test('a left float pushes the lines beside it to the right', () {
    final float = sideFloat(left: 0, width: 60, height: 25);
    final r = layoutFloatWrap(
      text: longText(),
      floats: [float],
      contentWidth: contentWidth,
      direction: TextDirection.ltr,
    )!;

    // The first line sits beside the float: left = float right edge, width = rest.
    expect(r.lines.first.left, 60);
    expect(r.lines.first.width, contentWidth - 60);
    // Text extends past the float's height → some line returns to full width.
    expect(r.lines.any((l) => l.left == 0 && l.width == contentWidth), isTrue);
    // Lines that sit beside the float never overlap its column.
    for (final l in r.lines) {
      if (l.top < float.exBottom) expect(l.left, 60);
    }
  });

  test('a right float keeps text on the left, narrower', () {
    final r = layoutFloatWrap(
      text: longText(),
      floats: [sideFloat(left: contentWidth - 60, width: 60, height: 25)],
      contentWidth: contentWidth,
      direction: TextDirection.ltr,
    )!;
    expect(r.lines.first.left, 0);
    expect(r.lines.first.width, contentWidth - 60);
    expect(r.lines.any((l) => l.width == contentWidth), isTrue);
  });

  test('a tall float beside short text still reserves its full height', () {
    final r = layoutFloatWrap(
      text: const TextSpan(text: 'short', style: TextStyle(fontSize: 10)),
      floats: [sideFloat(left: 0, width: 60, height: 120)],
      contentWidth: contentWidth,
      direction: TextDirection.ltr,
    )!;
    expect(r.height, greaterThanOrEqualTo(120));
  });

  test('a WidgetSpan in the text returns null (caller falls back)', () {
    const span = TextSpan(children: [
      TextSpan(text: 'hi '),
      WidgetSpan(child: SizedBox(width: 10, height: 10)),
      TextSpan(text: ' there'),
    ]);
    final r = layoutFloatWrap(
      text: span,
      floats: const [],
      contentWidth: contentWidth,
      direction: TextDirection.ltr,
    );
    expect(r, isNull);
  });

  test('the line slices preserve the original text in order', () {
    final r = layoutFloatWrap(
      text: longText(20),
      floats: [sideFloat(left: 0, width: 60, height: 25)],
      contentWidth: contentWidth,
      direction: TextDirection.ltr,
    )!;
    final joined = r.lines.map((l) => l.span.toPlainText()).join();
    expect(joined, List.filled(20, 'a').join(' '));
  });

  group('localSideFloatRects', () {
    DocxInlineImage floatImg(DocxTextWrap wrap, {DrawingHAlign? hAlign}) =>
        DocxInlineImage(
          bytes: Uint8List(0),
          extension: 'png',
          width: 90, // 90pt → 120px
          height: 60, // 60pt → 80px
          positionMode: DocxDrawingPosition.floating,
          textWrap: wrap,
          hAlign: hAlign,
        );

    test('a right-aligned side float hugs the right content edge', () {
      final rects = localSideFloatRects(
        [floatImg(DocxTextWrap.square, hAlign: DrawingHAlign.right)],
        contentWidth: 400,
      );
      expect(rects.length, 1);
      expect(rects.first.flow, FloatFlow.side);
      expect(rects.first.right, closeTo(400, 0.5)); // hugs right edge
      expect(rects.first.width, closeTo(120, 0.5)); // 90pt → 120px
    });

    test('non-side floats are excluded', () {
      final rects = localSideFloatRects(
        [
          floatImg(DocxTextWrap.topAndBottom),
          floatImg(DocxTextWrap.behindText)
        ],
        contentWidth: 400,
      );
      expect(rects, isEmpty);
    });

    test('inside/outside resolve to a left/right band by page direction', () {
      List<FloatRect> rectsFor(DrawingHAlign a, {required bool rtl}) =>
          localSideFloatRects([floatImg(DocxTextWrap.square, hAlign: a)],
              contentWidth: 400, pageIsRtl: rtl);

      // inside → left edge in LTR, right edge in RTL.
      expect(rectsFor(DrawingHAlign.inside, rtl: false).first.left,
          closeTo(0, 0.5));
      expect(rectsFor(DrawingHAlign.inside, rtl: true).first.right,
          closeTo(400, 0.5));
      // outside → mirror of inside.
      expect(rectsFor(DrawingHAlign.outside, rtl: false).first.right,
          closeTo(400, 0.5));
      expect(rectsFor(DrawingHAlign.outside, rtl: true).first.left,
          closeTo(0, 0.5));
    });

    test('a centered float carves no side band (rendered as a block)', () {
      final rects = localSideFloatRects(
        [floatImg(DocxTextWrap.square, hAlign: DrawingHAlign.center)],
        contentWidth: 400,
      );
      expect(rects, isEmpty);
    });
  });

  group('sideBandOf', () {
    FloatPlacement place(DocxTextWrap wrap, {DrawingHAlign? hAlign}) =>
        floatPlacementOf(DocxInlineImage(
          bytes: Uint8List(0),
          extension: 'png',
          width: 90,
          height: 60,
          positionMode: DocxDrawingPosition.floating,
          textWrap: wrap,
          hAlign: hAlign,
        ))!;

    test('left/right map to their band; center/null → none', () {
      expect(sideBandOf(place(DocxTextWrap.square, hAlign: DrawingHAlign.left)),
          SideBand.left);
      expect(sideBandOf(place(DocxTextWrap.square, hAlign: DrawingHAlign.right)),
          SideBand.right);
      expect(
          sideBandOf(place(DocxTextWrap.square, hAlign: DrawingHAlign.center)),
          SideBand.none);
      // No alignment (offset-positioned) → centered block.
      expect(sideBandOf(place(DocxTextWrap.square)), SideBand.none);
    });

    test('inside/outside flip with page direction', () {
      final inside = place(DocxTextWrap.square, hAlign: DrawingHAlign.inside);
      expect(sideBandOf(inside, pageIsRtl: false), SideBand.left);
      expect(sideBandOf(inside, pageIsRtl: true), SideBand.right);
      final outside = place(DocxTextWrap.square, hAlign: DrawingHAlign.outside);
      expect(sideBandOf(outside, pageIsRtl: false), SideBand.right);
      expect(sideBandOf(outside, pageIsRtl: true), SideBand.left);
    });

    test('non-side flow is never a band', () {
      expect(
          sideBandOf(
              place(DocxTextWrap.topAndBottom, hAlign: DrawingHAlign.left)),
          SideBand.none);
      expect(
          sideBandOf(place(DocxTextWrap.behindText, hAlign: DrawingHAlign.left)),
          SideBand.none);
    });
  });

  group('localCenterFloatsHeight', () {
    DocxInlineImage floatImg(DocxTextWrap wrap, {DrawingHAlign? hAlign}) =>
        DocxInlineImage(
          bytes: Uint8List(0),
          extension: 'png',
          width: 90,
          height: 60, // 60pt → 80px
          positionMode: DocxDrawingPosition.floating,
          textWrap: wrap,
          hAlign: hAlign,
        );

    test('sums centered/offset side floats, ignores left/right bands', () {
      final h = localCenterFloatsHeight([
        floatImg(DocxTextWrap.square, hAlign: DrawingHAlign.center), // 80px
        floatImg(DocxTextWrap.square, hAlign: DrawingHAlign.left), // band → 0
        floatImg(DocxTextWrap.square), // offset → 80px
      ]);
      expect(h, closeTo(160, 0.5));
    });

    test('left/right-only paragraph reserves no centered height', () {
      final h = localCenterFloatsHeight([
        floatImg(DocxTextWrap.square, hAlign: DrawingHAlign.right),
      ]);
      expect(h, 0);
    });
  });

  group('layoutFloatWrap strut', () {
    test('threads the strut into the line pitch (matches a strut-applied painter)',
        () {
      const strut = StrutStyle(fontSize: 40, height: 1.0, forceStrutHeight: true);

      // The line advance a plain strut-applied painter produces — the value the
      // measurer/renderer expect for this paragraph.
      final tp = TextPainter(
        text: longText(),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        strutStyle: strut,
      )..layout(maxWidth: contentWidth);
      final expected = tp.computeLineMetrics().first.height;
      tp.dispose();

      final r = layoutFloatWrap(
        text: longText(),
        floats: const [],
        contentWidth: contentWidth,
        direction: TextDirection.ltr,
        strut: strut,
      )!;
      final pitch = r.lines[1].top - r.lines[0].top;
      expect(pitch, closeTo(expected, 0.5),
          reason: 'the wrap pitch must equal the strut-applied painter pitch');
    });
  });
}
