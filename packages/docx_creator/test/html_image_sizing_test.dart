import 'dart:convert';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/utils/image_resolver.dart';
import 'package:test/test.dart';

void main() {
  // 1×1 transparent PNG. Small + guaranteed-decodable header so
  // `ImageResolver.intrinsicSizePt` can return a real (px,px) reading.
  const base64Png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
  final src = 'data:image/png;base64,$base64Png';

  // CSS px → DOCX pt (72 / 96).
  const double pxToPt = 72.0 / 96.0;

  group('HtmlImageParser sizing (Issue #86)', () {
    test('CSS style width/height is honored and converted to points',
        () async {
      final html = '<img src="$src" style="width: 600px; height: 400px">';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes, hasLength(1));
      final image = nodes.single as DocxImage;
      // 600 px × 72/96 = 450 pt (just under the 451 pt cap, no scaling).
      expect(image.width, closeTo(450.0, 0.001));
      expect(image.height, closeTo(300.0, 0.001));
    });

    test('pixel attributes are converted to points', () async {
      final html = '<img src="$src" width="200" height="150">';
      final nodes = await DocxParser.fromHtml(html);

      final image = nodes.single as DocxImage;
      expect(image.width, closeTo(200 * pxToPt, 0.001));
      expect(image.height, closeTo(150 * pxToPt, 0.001));
    });

    test('CSS style takes precedence over width/height attributes', () async {
      final html =
          '<img src="$src" width="999" height="999" style="width: 320px; height: 240px">';
      final nodes = await DocxParser.fromHtml(html);

      final image = nodes.single as DocxImage;
      expect(image.width, closeTo(320 * pxToPt, 0.001));
      expect(image.height, closeTo(240 * pxToPt, 0.001));
    });

    test('CSS pt units are accepted as-is', () async {
      final html = '<img src="$src" style="width: 180pt; height: 120pt">';
      final nodes = await DocxParser.fromHtml(html);

      final image = nodes.single as DocxImage;
      expect(image.width, closeTo(180.0, 0.001));
      expect(image.height, closeTo(120.0, 0.001));
    });

    test('oversized CSS dimensions are capped at page content width', () async {
      // 1000 px × 72/96 = 750 pt, above the ~451 pt cap. Should scale to
      // 451 pt wide, keeping the 2:1 aspect ratio → 225.5 pt tall.
      final html = '<img src="$src" style="width: 1000px; height: 500px">';
      final nodes = await DocxParser.fromHtml(html);

      final image = nodes.single as DocxImage;
      expect(image.width, closeTo(451.0, 0.001));
      expect(image.height, closeTo(225.5, 0.001));
    });

    test('uses intrinsic image size when no HTML dimensions are declared',
        () async {
      // The test PNG is 1 px × 1 px → 0.75 pt × 0.75 pt.
      final html = '<img src="$src">';
      final nodes = await DocxParser.fromHtml(html);

      final image = nodes.single as DocxImage;
      expect(image.width, closeTo(1 * pxToPt, 0.001));
      expect(image.height, closeTo(1 * pxToPt, 0.001));
    });

    test('malformed base64 still renders placeholder paragraph', () async {
      final html = '<img src="data:image/png;base64,NOTBASE64" alt="Broken">';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.single, isA<DocxParagraph>());
    });
  });

  group('ImageResolver.intrinsicSizePt', () {
    test('returns header-derived size in points for valid PNG', () {
      final bytes = base64Decode(base64Png);
      final size = ImageResolver.intrinsicSizePt(bytes);
      expect(size, isNotNull);
      expect(size!.$1, closeTo(1 * pxToPt, 0.001));
      expect(size.$2, closeTo(1 * pxToPt, 0.001));
    });

    test('returns null for non-image bytes', () {
      final bytes = utf8.encode('this is not an image');
      expect(ImageResolver.intrinsicSizePt(bytes), isNull);
    });
  });

  group('ImageResolver.resolve', () {
    test('caller-supplied points win over intrinsic reading', () async {
      final result = await ImageResolver.resolve(
        src,
        width: 240,
        height: 180,
        useIntrinsicWhenMissing: true,
      );
      expect(result, isNotNull);
      expect(result!.width, 240);
      expect(result.height, 180);
    });

    test('falls back to intrinsic when useIntrinsicWhenMissing is true',
        () async {
      final result = await ImageResolver.resolve(
        src,
        useIntrinsicWhenMissing: true,
      );
      expect(result, isNotNull);
      expect(result!.width, closeTo(1 * pxToPt, 0.001));
      expect(result.height, closeTo(1 * pxToPt, 0.001));
    });

    test('preserves 200×150 pt default when intrinsic fallback is disabled',
        () async {
      final result = await ImageResolver.resolve(src);
      expect(result, isNotNull);
      expect(result!.width, 200);
      expect(result.height, 150);
    });

    test('returns null for empty source', () async {
      expect(await ImageResolver.resolve(''), isNull);
    });
  });
}
