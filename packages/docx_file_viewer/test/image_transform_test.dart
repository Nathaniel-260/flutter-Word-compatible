import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/widget_generator/image_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §H.3 — image transform rendering (rotation / mirror / crop) and
/// display-resolution decoding (RAM, §2.4 rule 2).
void main() {
  final builder = ImageBuilder(config: const DocxViewConfig());

  Future<void> pump(WidgetTester tester, Widget child,
      {double dpr = 2.0}) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(devicePixelRatio: dpr),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: child),
        ),
      ),
    );
  }

  testWidgets('plain image: no Transform, decodes at display×DPR',
      (tester) async {
    final img = DocxInlineImage(
      bytes: _gif1x1(),
      extension: 'gif',
      width: 100,
      height: 80,
    );
    await pump(tester, builder.buildInlineImage(img));

    expect(find.byType(Transform), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    expect((provider as ResizeImage).width, 200); // 100 × dpr 2
    expect(provider.height, 160);
  });

  testWidgets('rotation wraps the image in a Transform', (tester) async {
    final img = DocxInlineImage(
      bytes: _gif1x1(),
      extension: 'gif',
      width: 100,
      height: 80,
      rotation: 45,
    );
    await pump(tester, builder.buildInlineImage(img));
    expect(find.byType(Transform), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('flipH applies a mirrored Transform', (tester) async {
    final img = DocxInlineImage(
      bytes: _gif1x1(),
      extension: 'gif',
      width: 100,
      height: 80,
      flipH: true,
    );
    await pump(tester, builder.buildInlineImage(img));
    final transform = tester.widget<Transform>(find.byType(Transform));
    // Horizontal mirror → negative x-scale on the matrix.
    expect(transform.transform.entry(0, 0), -1.0);
    expect(transform.transform.entry(1, 1), 1.0);
  });

  testWidgets('crop clips the image into a window', (tester) async {
    final img = DocxInlineImage(
      bytes: _gif1x1(),
      extension: 'gif',
      width: 100,
      height: 100,
      cropLeft: 0.25,
      cropRight: 0.25,
    );
    await pump(tester, builder.buildInlineImage(img));
    expect(find.byType(ClipRect), findsOneWidget);
    expect(find.byType(OverflowBox), findsOneWidget);
    // Visible width fraction 0.5 → full image scaled to 200 logical px wide,
    // decoded at ×dpr 2 = 400.
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as ResizeImage).width, 400);
  });

  testWidgets('degenerate crop falls back to the uncropped image',
      (tester) async {
    final img = DocxInlineImage(
      bytes: _gif1x1(),
      extension: 'gif',
      width: 100,
      height: 100,
      cropLeft: 0.6,
      cropRight: 0.6, // visible width negative → fallback
    );
    await pump(tester, builder.buildInlineImage(img));
    expect(find.byType(ClipRect), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}

Uint8List _gif1x1() => Uint8List.fromList([
      0x47, 0x49, 0x46, 0x38, 0x39, 0x61, //
      0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00,
      0xff, 0xff, 0xff, 0x00, 0x00, 0x00,
      0x21, 0xf9, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
      0x02, 0x02, 0x44, 0x01, 0x00, 0x3b,
    ]);
