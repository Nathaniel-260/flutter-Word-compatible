import 'dart:math' as math;

import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';

/// Builds Flutter [Image] widgets from [DocxImage]/[DocxInlineImage] elements,
/// applying the drawing transform (rotation / mirror / crop, Plan §H.3) and
/// decoding at display resolution to bound RAM (§2.4 rule 2).
class ImageBuilder {
  final DocxViewConfig config;

  ImageBuilder({required this.config});

  /// Build a block-level image widget.
  Widget buildBlockImage(DocxImage image) {
    final inline = image.asInline;
    final Widget imageWidget =
        _transformed(inline, onError: () => _blockError(image));

    // Apply alignment
    Alignment alignment;
    switch (image.align) {
      case DocxAlign.center:
        alignment = Alignment.center;
        break;
      case DocxAlign.right:
        alignment = Alignment.centerRight;
        break;
      default:
        alignment = Alignment.centerLeft;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: alignment,
      child: imageWidget,
    );
  }

  /// Build an inline (or floating-as-inline) image widget with its transform.
  Widget buildInlineImage(DocxInlineImage image) =>
      _transformed(image, onError: () => _inlineError(image));

  // ---------------------------------------------------------------------------
  // Transform stack (Plan §H.3): crop → mirror → rotate, mirroring how Word
  // composes `a:srcRect` then `a:xfrm` (flip then rot) about the shape centre.
  // ---------------------------------------------------------------------------

  Widget _transformed(DocxInlineImage image,
      {required Widget Function() onError}) {
    Widget w = _cropped(image, onError);

    if (image.flipH || image.flipV) {
      w = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          image.flipH ? -1.0 : 1.0,
          image.flipV ? -1.0 : 1.0,
          1.0,
        ),
        child: w,
      );
    }
    if (image.rotation != 0) {
      w = Transform.rotate(
        angle: image.rotation * math.pi / 180.0,
        child: w,
      );
    }
    return w;
  }

  /// The base image, cropped to `a:srcRect` when present. Without a crop this is
  /// a plain decoded image; with one, the full image is scaled up so the visible
  /// window equals the display box, then clipped (no whole-image decode waste —
  /// `cacheWidth` still tracks the scaled size).
  Widget _cropped(DocxInlineImage image, Widget Function() onError) {
    final w = image.width;
    final h = image.height;
    if (!image.hasCrop) {
      return _decoded(image, w, h, BoxFit.contain, onError);
    }
    final visW = 1 - image.cropLeft - image.cropRight;
    final visH = 1 - image.cropTop - image.cropBottom;
    if (visW <= 0.01 || visH <= 0.01) {
      // Degenerate crop — fall back to the uncropped image rather than nothing.
      return _decoded(image, w, h, BoxFit.contain, onError);
    }
    final fullW = w / visW;
    final fullH = h / visH;
    return ClipRect(
      child: SizedBox(
        width: w,
        height: h,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: fullW,
          maxWidth: fullW,
          minHeight: fullH,
          maxHeight: fullH,
          child: Transform.translate(
            offset: Offset(-image.cropLeft * fullW, -image.cropTop * fullH),
            child: _decoded(image, fullW, fullH, BoxFit.fill, onError),
          ),
        ),
      ),
    );
  }

  /// Decodes [image] at the displayed size × devicePixelRatio (`cacheWidth`/
  /// `cacheHeight`), so a large source bitmap shown small never decodes at native
  /// resolution (§2.4 rule 2). The size is known from the AST — no decode needed
  /// to learn it.
  Widget _decoded(DocxInlineImage image, double w, double h, BoxFit fit,
      Widget Function() onError) {
    return Builder(builder: (context) {
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
      final cw = (w * dpr).ceil();
      final ch = (h * dpr).ceil();
      return Image.memory(
        image.bytes,
        width: w,
        height: h,
        fit: fit,
        cacheWidth: cw > 0 ? cw : null,
        cacheHeight: ch > 0 ? ch : null,
        errorBuilder: (context, error, stackTrace) => onError(),
      );
    });
  }

  Widget _blockError(DocxImage image) {
    return Container(
      width: image.width,
      height: image.height,
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'Image not available',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _inlineError(DocxInlineImage image) {
    return Container(
      width: image.width,
      height: image.height,
      color: Colors.grey.shade200,
      child: Icon(Icons.broken_image, size: 24, color: Colors.grey.shade400),
    );
  }
}
