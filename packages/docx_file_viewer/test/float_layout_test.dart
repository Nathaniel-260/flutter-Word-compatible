import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/layout/float_layout.dart';
import 'package:docx_file_viewer/src/pagination/page_model.dart';
import 'package:docx_file_viewer/src/utils/docx_units.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §H.2 — pure float geometry + band/line-extent solving.
void main() {
  // A4-ish page at 96 DPI with 1" margins.
  const geo = PageGeometry(
    pageWidth: 794,
    pageHeight: 1123,
    padLeft: 96,
    padRight: 96,
    padTop: 96,
    padBottom: 96,
    bodyTop: 96,
    bodyBottom: 96,
    headerDist: 48,
    footerDist: 48,
  );
  // contentWidth = 794 - 192 = 602; bodyHeight = 1123 - 192 = 931.

  group('resolveFloatRect — horizontal', () {
    test('column-relative right align hugs the right body edge', () {
      const p = FloatPlacement(
        width: 100,
        height: 80,
        hFrom: DocxHorizontalPositionFrom.column,
        vFrom: DocxVerticalPositionFrom.paragraph,
        hAlign: DrawingHAlign.right,
        wrap: DocxTextWrap.square,
      );
      final r = resolveFloatRect(p, geo: geo, anchorTopPx: 0);
      expect(r.left, closeTo(502, 0.01)); // 602 - 100
      expect(r.right, closeTo(602, 0.01));
      expect(r.flow, FloatFlow.side);
    });

    test('column-relative left align sits at the left body edge', () {
      const p = FloatPlacement(
        width: 120,
        height: 60,
        hFrom: DocxHorizontalPositionFrom.column,
        vFrom: DocxVerticalPositionFrom.paragraph,
        hAlign: DrawingHAlign.left,
        wrap: DocxTextWrap.square,
      );
      final r = resolveFloatRect(p, geo: geo, anchorTopPx: 0);
      expect(r.left, closeTo(0, 0.01));
    });

    test('page-relative center spans across the margins', () {
      const p = FloatPlacement(
        width: 200,
        height: 100,
        hFrom: DocxHorizontalPositionFrom.page,
        vFrom: DocxVerticalPositionFrom.page,
        hAlign: DrawingHAlign.center,
        vAlign: DrawingVAlign.top,
        wrap: DocxTextWrap.square,
      );
      final r = resolveFloatRect(p, geo: geo, anchorTopPx: 0);
      // refLeft = -96, refWidth = 794 → left = -96 + (794-200)/2 = 201.
      expect(r.left, closeTo(201, 0.01));
      // page-relative top: refTop = -bodyTop = -96.
      expect(r.top, closeTo(-96, 0.01));
    });

    test('explicit hOffset is measured from the reference frame', () {
      const p = FloatPlacement(
        width: 50,
        height: 50,
        hFrom: DocxHorizontalPositionFrom.column,
        vFrom: DocxVerticalPositionFrom.paragraph,
        hOffsetPx: 30,
        wrap: DocxTextWrap.square,
      );
      final r = resolveFloatRect(p, geo: geo, anchorTopPx: 0);
      expect(r.left, closeTo(30, 0.01));
    });

    test('RTL flips inside/outside alignment', () {
      const p = FloatPlacement(
        width: 100,
        height: 50,
        hFrom: DocxHorizontalPositionFrom.column,
        vFrom: DocxVerticalPositionFrom.paragraph,
        hAlign: DrawingHAlign.inside,
        wrap: DocxTextWrap.square,
      );
      final ltr = resolveFloatRect(p, geo: geo, anchorTopPx: 0);
      final rtl =
          resolveFloatRect(p, geo: geo, anchorTopPx: 0, pageIsRtl: true);
      expect(ltr.left, closeTo(0, 0.01)); // inside = left in LTR
      expect(rtl.left, closeTo(502, 0.01)); // inside = right in RTL
    });
  });

  group('resolveFloatRect — vertical', () {
    test('paragraph-relative offset sits below the anchor top', () {
      const p = FloatPlacement(
        width: 50,
        height: 50,
        hFrom: DocxHorizontalPositionFrom.column,
        vFrom: DocxVerticalPositionFrom.paragraph,
        vOffsetPx: 40,
        wrap: DocxTextWrap.square,
      );
      final r = resolveFloatRect(p, geo: geo, anchorTopPx: 200);
      expect(r.top, closeTo(240, 0.01));
    });

    test('margin-relative bottom align rests at the body bottom', () {
      const p = FloatPlacement(
        width: 50,
        height: 50,
        hFrom: DocxHorizontalPositionFrom.column,
        vFrom: DocxVerticalPositionFrom.margin,
        vAlign: DrawingVAlign.bottom,
        wrap: DocxTextWrap.square,
      );
      final r = resolveFloatRect(p, geo: geo, anchorTopPx: 0);
      expect(r.top, closeTo(931 - 50, 0.01));
    });
  });

  group('lineExtent', () {
    FloatRect side(double left, double width,
            {double top = 100,
            double height = 100,
            FloatFlow flow = FloatFlow.side}) =>
        FloatRect(
          left: left,
          top: top,
          width: width,
          height: height,
          flow: flow,
          zOrder: 0,
        );

    test('right float shrinks the line from the right', () {
      final f = side(502, 100); // hugs right edge (602)
      final ext =
          lineExtent([f], lineTop: 120, lineBottom: 140, contentWidth: 602);
      expect(ext.blocked, isFalse);
      expect(ext.left, closeTo(0, 0.01));
      expect(ext.width, closeTo(502, 0.01));
    });

    test('left float shrinks the line from the left', () {
      final f = side(0, 120);
      final ext =
          lineExtent([f], lineTop: 120, lineBottom: 140, contentWidth: 602);
      expect(ext.left, closeTo(120, 0.01));
      expect(ext.width, closeTo(482, 0.01));
    });

    test('a line outside the float band keeps the full width', () {
      final f = side(0, 120, top: 100, height: 50); // band [100,150]
      final ext =
          lineExtent([f], lineTop: 200, lineBottom: 220, contentWidth: 602);
      expect(ext.left, 0);
      expect(ext.width, closeTo(602, 0.01));
    });

    test('topAndBottom float blocks the whole band', () {
      final f = side(200, 200, flow: FloatFlow.fullWidth);
      final ext =
          lineExtent([f], lineTop: 120, lineBottom: 140, contentWidth: 602);
      expect(ext.blocked, isTrue);
    });

    test('layer (behindText) float never affects flow', () {
      final f = side(0, 600, flow: FloatFlow.layer);
      final ext =
          lineExtent([f], lineTop: 120, lineBottom: 140, contentWidth: 602);
      expect(ext.blocked, isFalse);
      expect(ext.width, closeTo(602, 0.01));
    });

    test('mid-column float keeps the wider side', () {
      // Float [100,250] → roomLeft=100, roomRight=602-250=352 → keep right.
      final f = side(100, 150);
      final ext =
          lineExtent([f], lineTop: 120, lineBottom: 140, contentWidth: 602);
      expect(ext.left, closeTo(250, 0.01));
      expect(ext.width, closeTo(352, 0.01));
    });

    test('left + right floats both shave their edges', () {
      final l = side(0, 100);
      final r = side(502, 100);
      final ext =
          lineExtent([l, r], lineTop: 120, lineBottom: 140, contentWidth: 602);
      expect(ext.left, closeTo(100, 0.01));
      expect(ext.width, closeTo(402, 0.01));
    });

    test('left float leaving < minWidth blocks the band', () {
      final f = side(0, 596); // hugs left, leaves 6px (<8) → blocked
      final ext =
          lineExtent([f], lineTop: 120, lineBottom: 140, contentWidth: 602);
      expect(ext.blocked, isTrue);
    });

    test('dist margins widen the exclusion box', () {
      final f = FloatRect(
        left: 502,
        top: 100,
        width: 100,
        height: 100,
        flow: FloatFlow.side,
        zOrder: 0,
        marginLeft: 12,
      );
      final ext =
          lineExtent([f], lineTop: 120, lineBottom: 140, contentWidth: 602);
      // exLeft = 502 - 12 = 490 → usable width 490.
      expect(ext.width, closeTo(490, 0.01));
    });
  });

  group('nextUsableY', () {
    test('drops the line below a topAndBottom float', () {
      final f = FloatRect(
        left: 100,
        top: 200,
        width: 300,
        height: 100,
        flow: FloatFlow.fullWidth,
        zOrder: 0,
      ); // exBottom = 300
      final y = nextUsableY([f],
          fromY: 210, lineHeight: 18, contentWidth: 602, maxY: 931);
      expect(y, closeTo(300, 0.01));
    });

    test('returns the starting y when already usable', () {
      final y = nextUsableY([],
          fromY: 50, lineHeight: 18, contentWidth: 602, maxY: 931);
      expect(y, 50);
    });
  });

  group('floatPlacementOf', () {
    test('inline image → null (not positioned as a float)', () {
      final img = DocxInlineImage(bytes: _bytes(), extension: 'png');
      expect(floatPlacementOf(img), isNull);
    });

    test('floating image → placement with px sizes and wrap', () {
      final img = DocxInlineImage(
        bytes: _bytes(),
        extension: 'png',
        width: 72, // 1 inch → 96 px (×1.333)
        height: 36,
        positionMode: DocxDrawingPosition.floating,
        hAlign: DrawingHAlign.right,
        textWrap: DocxTextWrap.square,
      );
      final p = floatPlacementOf(img)!;
      expect(p.width, closeTo(DocxUnits.pointsToPixels(72), 0.01));
      expect(p.flow, FloatFlow.side);
      expect(p.hAlign, DrawingHAlign.right);
    });

    test('behindText image → layer flow', () {
      final img = DocxInlineImage(
        bytes: _bytes(),
        extension: 'png',
        positionMode: DocxDrawingPosition.floating,
        textWrap: DocxTextWrap.behindText,
      );
      expect(floatPlacementOf(img)!.flow, FloatFlow.layer);
    });
  });
}

Uint8List _bytes() => Uint8List.fromList(List<int>.filled(8, 0));
