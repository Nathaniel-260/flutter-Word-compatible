import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/widget_generator/shape_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §H.3 — preset shape geometry (real `dart:math` paths, no hand-rolled
/// trig) + fill/outline + transforms.
void main() {
  const size = Size(100, 80);

  Rect bounds(DocxShapePreset p) => shapePresetPath(p, size)!.getBounds();

  group('shapePresetPath — decoration presets return null', () {
    test('rect/roundRect/ellipse are handled by BoxDecoration', () {
      expect(shapePresetPath(DocxShapePreset.rect, size), isNull);
      expect(shapePresetPath(DocxShapePreset.roundRect, size), isNull);
      expect(shapePresetPath(DocxShapePreset.ellipse, size), isNull);
    });
  });

  group('shapePresetPath — edge-touching shapes fill the box', () {
    for (final p in const [
      DocxShapePreset.triangle,
      DocxShapePreset.diamond,
      DocxShapePreset.rightArrow,
      DocxShapePreset.plus,
    ]) {
      test('$p bounds == full box', () {
        final b = bounds(p);
        expect(b.left, closeTo(0, 0.01));
        expect(b.top, closeTo(0, 0.01));
        expect(b.width, closeTo(100, 0.01));
        expect(b.height, closeTo(80, 0.01));
      });
    }
  });

  group('shapePresetPath — interior/exterior membership', () {
    test('triangle (apex top): centroid in, top-left corner out', () {
      final path = shapePresetPath(DocxShapePreset.triangle, size)!;
      expect(path.contains(const Offset(50, 55)), isTrue);
      expect(path.contains(const Offset(3, 3)), isFalse);
    });

    test('diamond: centre in, corner out', () {
      final path = shapePresetPath(DocxShapePreset.diamond, size)!;
      expect(path.contains(const Offset(50, 40)), isTrue);
      expect(path.contains(const Offset(3, 3)), isFalse);
    });

    test('right arrow: shaft + tip in, top-right corner out', () {
      final path = shapePresetPath(DocxShapePreset.rightArrow, size)!;
      expect(path.contains(const Offset(10, 40)), isTrue); // shaft
      expect(path.contains(const Offset(95, 40)), isTrue); // near the tip
      expect(path.contains(const Offset(98, 3)), isFalse); // above the head
    });

    test('star5: centre in, corner out, fits inside the box', () {
      final path = shapePresetPath(DocxShapePreset.star5, size)!;
      expect(path.contains(const Offset(50, 40)), isTrue);
      expect(path.contains(const Offset(2, 2)), isFalse);
      final b = path.getBounds();
      // Real trig keeps every vertex within the box (the old Taylor-series
      // approximation produced wildly out-of-range coordinates).
      expect(b.left, greaterThanOrEqualTo(-0.01));
      expect(b.top, greaterThanOrEqualTo(-0.01));
      expect(b.right, lessThanOrEqualTo(100.01));
      expect(b.bottom, lessThanOrEqualTo(80.01));
    });

    test('regular hexagon: centre in, sits within the box, top vertex centred',
        () {
      final path = shapePresetPath(DocxShapePreset.hexagon, size)!;
      expect(path.contains(const Offset(50, 40)), isTrue);
      final b = path.getBounds();
      expect(b.left, greaterThanOrEqualTo(-0.01));
      expect(b.right, lessThanOrEqualTo(100.01));
      // First vertex is the top-centre point.
      expect(path.contains(const Offset(50, 2)), isTrue);
    });
  });

  group('shapePresetPath — lines', () {
    test('line/connector produce a non-null (open) path', () {
      expect(shapePresetPath(DocxShapePreset.line, size), isNotNull);
      expect(
          shapePresetPath(DocxShapePreset.straightConnector1, size), isNotNull);
    });
  });

  group('ShapeBuilder rendering', () {
    DocxShape shape(DocxShapePreset preset,
            {double rotation = 0, bool flipH = false}) =>
        DocxShape(
          width: 100,
          height: 80,
          preset: preset,
          fillColor: DocxColor('4472C4'),
          rotation: rotation,
          flipH: flipH,
        );

    Future<void> pump(WidgetTester tester, DocxShape s) async {
      final w =
          ShapeBuilder(config: const DocxViewConfig()).buildInlineShape(s);
      await tester
          .pumpWidget(MaterialApp(home: Scaffold(body: Center(child: w))));
    }

    testWidgets('a star renders via CustomPaint', (tester) async {
      await pump(tester, shape(DocxShapePreset.star5));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets(
        'an ellipse renders as a decorated box (no CustomPaint geometry)',
        (tester) async {
      await pump(tester, shape(DocxShapePreset.ellipse));
      final container = tester.widget<Container>(find.descendant(
          of: find.byType(Center).last, matching: find.byType(Container)));
      final deco = container.decoration as BoxDecoration;
      expect(deco.borderRadius, isA<BorderRadius>());
      expect(deco.color, const Color(0xFF4472C4));
    });

    testWidgets('rotation wraps the shape in a Transform', (tester) async {
      await pump(tester, shape(DocxShapePreset.rect, rotation: 45));
      expect(find.byType(Transform), findsWidgets);
    });

    testWidgets('flipH wraps the shape in a Transform', (tester) async {
      await pump(tester, shape(DocxShapePreset.rightArrow, flipH: true));
      expect(find.byType(Transform), findsWidgets);
    });
  });
}
