import 'dart:math' as math;

import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Resolves a Word color (`DocxColor`, hex without `#`, or `auto`) to a Flutter
/// [Color]. Theme-colored borders/backgrounds fall back to [fallback] (theme
/// color resolution for chrome is deferred — Plan §8.2). Returns null only when
/// the hex is malformed.
Color? resolveDocxColor(DocxColor color, Color fallback) {
  if (color.themeColor != null) return fallback;
  final hex = color.hex;
  if (hex.toLowerCase() == 'auto') return fallback;
  // DOCX colors are RGB (6 hex). An 8-hex value is treated as AARRGGBB; Word
  // never emits one, so this branch is defensive only.
  if (hex.length == 6 || hex.length == 8) {
    final argb = hex.length == 6 ? 'ff$hex' : hex;
    final value = int.tryParse(argb, radix: 16);
    if (value != null) return Color(value);
  }
  return null;
}

/// Lays the page body out inside the fixed content region (Plan §E.1.3): the
/// child takes its natural height (so it never asserts), is aligned vertically
/// per `w:vAlign`, and overflow is clipped to the region.
///
/// Because the page height is now fixed ([Clip.hardEdge]), an over-tall body —
/// from any measure/layout divergence with the Part-D paginator — would lose
/// text *silently*. For a fidelity viewer (sacred texts) that is the worst
/// failure mode, so in debug builds this warns when the body exceeds the region
/// (release still clips). When [stretch] is set (`w:vAlign="both"`), the child is
/// given the full region height to justify *only when it fits*; otherwise it
/// falls back to natural height + clip rather than asserting.
class PageBody extends SingleChildRenderObjectWidget {
  const PageBody({
    super.key,
    this.alignment = Alignment.topCenter,
    this.stretch = false,
    required Widget super.child,
  });

  final Alignment alignment;
  final bool stretch;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPageBody(alignment, stretch);

  @override
  void updateRenderObject(BuildContext context, RenderPageBody renderObject) {
    renderObject
      ..alignment = alignment
      ..stretch = stretch;
  }
}

class RenderPageBody extends RenderShiftedBox {
  RenderPageBody(this._alignment, this._stretch) : super(null);

  Alignment _alignment;
  set alignment(Alignment value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  bool _stretch;
  set stretch(bool value) {
    if (value == _stretch) return;
    _stretch = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;

    final width = constraints.maxWidth;
    // Natural height first — this never overflows the child's own constraints.
    child.layout(
      BoxConstraints(minWidth: width, maxWidth: width),
      parentUsesSize: true,
    );
    // Justify ("both") only when the content actually fits the region.
    if (_stretch && child.size.height <= size.height) {
      child.layout(
        BoxConstraints.tightFor(width: width, height: size.height),
        parentUsesSize: true,
      );
    }

    assert(() {
      final overflow = child.size.height - size.height;
      if (overflow > 0.5) {
        debugPrint('DocxView: page body overflows the content region by '
            '${overflow.toStringAsFixed(1)}px — content will be clipped '
            '(measure/layout divergence with the paginator).');
      }
      return true;
    }());

    (child.parentData! as BoxParentData).offset = _alignment.alongOffset(
      Offset(size.width - child.size.width, size.height - child.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final childOffset = (child.parentData! as BoxParentData).offset;
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (ctx, off) => ctx.paintChild(child, off + childOffset),
    );
  }
}

/// Paints a section's page-border frame (`w:pgBorders`, Plan §E.1.4).
///
/// The frame rectangle is placed relative to the content area (`offsetFrom`
/// = text, the default) or the page edge (`offsetFrom` = page), each side offset
/// by its own `w:space`. Line styles single/double/thick/triple/dashed/dotted
/// are drawn (05-section-sectpr.md item 13); other art/decorative styles still
/// fall back to a solid single line.
class PageBorderPainter extends CustomPainter {
  const PageBorderPainter({
    required this.borders,
    required this.padLeft,
    required this.padTop,
    required this.padRight,
    required this.padBottom,
    required this.defaultColor,
  });

  final DocxPageBorders borders;
  final double padLeft;
  final double padTop;
  final double padRight;
  final double padBottom;

  /// Color used for `auto` / theme-colored sides.
  final Color defaultColor;

  // `w:space` for page borders is in points; convert to px at 96 dpi.
  static double _ptToPx(int pt) => pt * 96 / 72;

  // Border width is in eighths of a point.
  static double _eighthPtToPx(int eighths) => (eighths / 8) * 96 / 72;

  @override
  void paint(Canvas canvas, Size size) {
    final fromPage = borders.offsetFrom == DocxPageBorderOffsetFrom.page;
    double space(DocxBorderSide? s) => s == null ? 0 : _ptToPx(s.space);

    // Frame rectangle edges.
    final left = fromPage ? space(borders.left) : padLeft - space(borders.left);
    final top = fromPage ? space(borders.top) : padTop - space(borders.top);
    final right = fromPage
        ? size.width - space(borders.right)
        : size.width - padRight + space(borders.right);
    final bottom = fromPage
        ? size.height - space(borders.bottom)
        : size.height - padBottom + space(borders.bottom);

    // Inward unit vectors keep the second line of a double border inside.
    _drawSide(canvas, borders.top, Offset(left, top), Offset(right, top),
        const Offset(0, 1));
    _drawSide(canvas, borders.bottom, Offset(left, bottom),
        Offset(right, bottom), const Offset(0, -1));
    _drawSide(canvas, borders.left, Offset(left, top), Offset(left, bottom),
        const Offset(1, 0));
    _drawSide(canvas, borders.right, Offset(right, top), Offset(right, bottom),
        const Offset(-1, 0));
  }

  void _drawSide(
      Canvas canvas, DocxBorderSide? side, Offset a, Offset b, Offset inward) {
    if (side == null || side.style == DocxBorder.none) return;
    final color = resolveDocxColor(side.color, defaultColor) ?? defaultColor;
    final width = math.max(0.5, _eighthPtToPx(side.size));

    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    switch (side.style) {
      case DocxBorder.double:
        canvas.drawLine(a, b, paint);
        final shift = inward * (width * 2);
        canvas.drawLine(a + shift, b + shift, paint);
      case DocxBorder.triple:
        // Three parallel hairlines (05-section-sectpr.md item 13).
        canvas.drawLine(a, b, paint);
        for (final m in [2, 4]) {
          final shift = inward * (width * m);
          canvas.drawLine(a + shift, b + shift, paint);
        }
      case DocxBorder.thick:
        canvas.drawLine(a, b, paint..strokeWidth = width * 2);
      case DocxBorder.dashed:
        _drawDashed(canvas, a, b, paint,
            dashLen: width * 3, gapLen: width * 2);
      case DocxBorder.dotted:
        // Round-capped short segments read as dots.
        _drawDashed(canvas, a, b, paint..strokeCap = StrokeCap.round,
            dashLen: width, gapLen: width * 2);
      case DocxBorder.none:
        break;
      case DocxBorder.single:
        canvas.drawLine(a, b, paint);
    }
  }

  /// Strokes an axis-aligned segment [a]→[b] as a dash/dot pattern.
  static void _drawDashed(Canvas canvas, Offset a, Offset b, Paint paint,
      {required double dashLen, required double gapLen}) {
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    final step = dashLen + gapLen;
    for (var d = 0.0; d < total; d += step) {
      final start = a + dir * d;
      final end = a + dir * math.min(d + dashLen, total);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(PageBorderPainter old) =>
      old.borders != borders ||
      old.padLeft != padLeft ||
      old.padTop != padTop ||
      old.padRight != padRight ||
      old.padBottom != padBottom ||
      old.defaultColor != defaultColor;
}
