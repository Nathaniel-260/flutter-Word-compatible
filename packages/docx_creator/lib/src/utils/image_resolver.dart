import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'file_loader_io.dart'
    if (dart.library.js_interop) 'file_loader_web.dart';

/// Result of an image resolution. `width` and `height` are expressed in
/// DOCX **points** (72 pt = 1 inch), the same unit [DocxInlineImage] and
/// [DocxImage] expect.
class ImageResult {
  final Uint8List bytes;
  final String extension;

  /// Final on-page width in points.
  final double width;

  /// Final on-page height in points.
  final double height;
  final String altText;

  const ImageResult({
    required this.bytes,
    required this.extension,
    required this.width,
    required this.height,
    required this.altText,
  });
}

/// Utility to resolve images from various sources (URL, Base64, File)
/// and produce an [ImageResult] whose width/height are sized correctly
/// for Microsoft Word.
///
/// Sizing rules:
/// 1. Caller-provided [width] / [height] (already in **points**) win.
/// 2. Otherwise, when [useIntrinsicWhenMissing] is true, the intrinsic
///    pixel size is read from the image header (via `package:image`)
///    and converted to points using the 72/96 CSS-DPI ratio Word uses
///    when rendering drawingML.
/// 3. As a last resort, a 200×150 pt thumbnail default is used (same
///    behavior as prior versions) so the call never fails.
///
/// Finally the width is capped at `_maxContentPt` (the printable width
/// of a standard A4/Letter page) preserving aspect ratio, so oversized
/// sources never clip past the page margin.
class ImageResolver {
  ImageResolver._();

  /// Printable content width of an A4/Letter page with ~1" side margins,
  /// in DOCX points. 6.26" × 72 ≈ 451 pt. Matches the 9022-twip default
  /// used by the table/grid layout code.
  static const double _maxContentPt = 451.0;

  /// CSS pixel → DOCX point. Word's drawingML is referenced at 72 DPI
  /// while HTML/CSS pixels reference 96 DPI.
  static const double _pxToPt = 72.0 / 96.0;

  /// Last-resort fallback when no caller dims are given, no intrinsic
  /// size can be read, and [useIntrinsicWhenMissing] is false.
  static const double _fallbackWidthPt = 200.0;
  static const double _fallbackHeightPt = 150.0;

  /// Resolves an image from a source string.
  ///
  /// [source] can be:
  /// - Base64 data URI: `data:image/png;base64,...`
  /// - Remote URL: `http://...`, `https://...`
  /// - Local File Path: `/path/to/image.png` (if accessible)
  ///
  /// [width] and [height] are in **points** when supplied. When both are
  /// null/zero and [useIntrinsicWhenMissing] is true, the intrinsic size
  /// of the decoded bytes is used.
  static Future<ImageResult?> resolve(
    String source, {
    double? width,
    double? height,
    String? alt,
    bool useIntrinsicWhenMissing = false,
  }) async {
    if (source.isEmpty) return null;

    Uint8List? bytes;
    String extension = 'png';

    try {
      if (source.startsWith('data:image/')) {
        final regex = RegExp(r'data:image/(\w+);base64,(.+)');
        final match = regex.firstMatch(source);
        if (match != null) {
          extension = match.group(1)!;
          final base64Data = match.group(2)!;
          bytes = base64Decode(base64Data);
        }
      } else if (source.startsWith('http://') ||
          source.startsWith('https://')) {
        final response = await http.get(Uri.parse(source)).timeout(
              const Duration(seconds: 10),
            );
        if (response.statusCode == 200) {
          bytes = response.bodyBytes;
          extension =
              _getImageExtension(source, response.headers['content-type']);
        }
      } else {
        final loader = getFileLoader();
        if (await loader.exists(source)) {
          bytes = await loader.loadBytes(source);
          extension = _getImageExtension(source, null);
        }
      }
    } catch (_) {
      // Swallow network/IO failures so callers can fall through to a
      // placeholder. Returning null here keeps the original behavior.
    }

    if (bytes == null) return null;

    double? wPt = (width != null && width > 0) ? width : null;
    double? hPt = (height != null && height > 0) ? height : null;

    if ((wPt == null || hPt == null) && useIntrinsicWhenMissing) {
      final intrinsic = intrinsicSizePt(bytes);
      if (intrinsic != null) {
        final iW = intrinsic.$1;
        final iH = intrinsic.$2;
        if (wPt == null && hPt == null) {
          wPt = iW;
          hPt = iH;
        } else if (wPt == null) {
          // Calculate proportional width
          wPt = hPt! * (iW / iH);
        } else {
          // Calculate proportional height
          hPt = wPt * (iH / iW);
        }
      }
    }

    double finalW = wPt ?? _fallbackWidthPt;
    double finalH = hPt ?? _fallbackHeightPt;

    // Cap at page content width preserving aspect ratio.
    if (finalW > _maxContentPt) {
      finalH = finalH * (_maxContentPt / finalW);
      finalW = _maxContentPt;
    }

    return ImageResult(
      bytes: bytes,
      extension: extension,
      width: finalW,
      height: finalH,
      altText: alt ?? 'Image',
    );
  }

  /// Reads the intrinsic pixel dimensions of an image from its header
  /// (no full decode) and returns them converted to DOCX points.
  /// Returns null if the format is unrecognised or the header is
  /// malformed.
  static (double, double)? intrinsicSizePt(Uint8List bytes) {
    try {
      final decoder = img.findDecoderForData(bytes);
      if (decoder == null) return null;
      final info = decoder.startDecode(bytes);
      if (info == null) return null;
      final wPt = info.width * _pxToPt;
      final hPt = info.height * _pxToPt;
      if (wPt <= 0 || hPt <= 0) return null;
      return (wPt, hPt);
    } catch (_) {
      return null;
    }
  }

  static String _getImageExtension(String url, String? contentType) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      if (path.endsWith('.png')) return 'png';
      if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'jpeg';
      if (path.endsWith('.gif')) return 'gif';
      if (path.endsWith('.bmp')) return 'bmp';
      if (path.endsWith('.webp')) return 'webp';
      if (path.endsWith('.tiff') || path.endsWith('.tif')) return 'tiff';
    } catch (_) {}

    if (contentType != null) {
      if (contentType.contains('png')) return 'png';
      if (contentType.contains('jpeg') || contentType.contains('jpg')) {
        return 'jpeg';
      }
      if (contentType.contains('gif')) return 'gif';
      if (contentType.contains('bmp')) return 'bmp';
      if (contentType.contains('webp')) return 'webp';
      if (contentType.contains('tiff')) return 'tiff';
    }

    return 'png';
  }
}
