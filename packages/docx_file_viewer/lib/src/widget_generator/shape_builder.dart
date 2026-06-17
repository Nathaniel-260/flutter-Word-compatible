import 'dart:math' as math;

import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';

/// Builds Flutter widgets from [DocxShape] and [DocxShapeBlock] elements
/// (Plan §H.3 — preset geometry + fill/outline + transforms).
///
/// Rectangles, rounded rectangles and ellipses render with a [BoxDecoration]
/// (so their text/clip behaviour is exact); every other geometric preset is
/// painted from a real [Path] produced by [shapePresetPath] using `dart:math`
/// (no hand-rolled trig). Colour resolution lives in one place ([_resolveColor])
/// and the painter receives already-resolved [Color]s, so there is no duplicate
/// theme logic.
class ShapeBuilder {
  final DocxViewConfig config;
  final DocxTheme? docxTheme;

  /// Renders the block content of a text box (`DocxShape.textBlocks`) by
  /// re-entering the document generator (Plan §H). Set by the generator; when
  /// null (or a shape has no [DocxShape.textBlocks]) the flat [DocxShape.text]
  /// is rendered as a single centred label instead.
  final Widget Function(List<DocxBlock> blocks)? textBlockBuilder;

  ShapeBuilder({required this.config, this.docxTheme, this.textBlockBuilder});

  /// Build a block-level shape widget.
  Widget buildBlockShape(DocxShapeBlock shapeBlock) {
    final shape = shapeBlock.shape;
    final alignment = switch (shapeBlock.align) {
      DocxAlign.center => Alignment.center,
      DocxAlign.right => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: alignment,
      child: _buildShape(shape),
    );
  }

  /// Build an inline shape widget.
  Widget buildInlineShape(DocxShape shape) => _buildShape(shape);

  Widget _buildShape(DocxShape shape) {
    final fill = _resolveColor(shape.fillColor);
    final outline = _resolveColor(shape.outlineColor);
    final gradient = _resolveGradient(shape.gradientFill);
    final size = Size(shape.width, shape.height);

    Widget body;
    switch (shape.preset) {
      case DocxShapePreset.rect:
        body = _decorated(shape, fill, gradient, outline, null);
      case DocxShapePreset.roundRect:
        // Word's default corner radius is ~⅙ of the shorter side.
        final r = math.min(shape.width, shape.height) * 0.1667;
        body = _decorated(
            shape, fill, gradient, outline, BorderRadius.circular(r));
      case DocxShapePreset.ellipse:
        // A true ellipse (not a stadium): elliptical corner radii = half-extent.
        body = _decorated(
            shape,
            fill,
            gradient,
            outline,
            BorderRadius.all(
                Radius.elliptical(shape.width / 2, shape.height / 2)));
      default:
        final path = shapePresetPath(shape.preset, size);
        if (path == null) {
          // Unsupported preset → a rounded box so it is visible (§8.2).
          body = _decorated(
              shape, fill, gradient, outline, BorderRadius.circular(4));
        } else {
          body = _painted(shape, path, fill, gradient, outline);
        }
    }

    // Mirror (`a:xfrm@flipH/flipV`) then rotate (`@rot`), matching Word's order.
    if (shape.flipH || shape.flipV) {
      body = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
            shape.flipH ? -1 : 1, shape.flipV ? -1 : 1, 1),
        child: body,
      );
    }
    if (shape.rotation != 0) {
      body = Transform.rotate(
        angle: shape.rotation * math.pi / 180,
        child: body,
      );
    }
    return body;
  }

  /// A rect/roundRect/ellipse rendered with a [BoxDecoration]. A [gradient]
  /// (when present) takes precedence over the solid [fill].
  Widget _decorated(
    DocxShape shape,
    Color? fill,
    Gradient? gradient,
    Color? outline,
    BorderRadius? radius,
  ) {
    return Container(
      width: shape.width,
      height: shape.height,
      clipBehavior: radius != null ? Clip.antiAlias : Clip.hardEdge,
      decoration: BoxDecoration(
        color: gradient != null ? null : (fill ?? Colors.grey.shade200),
        gradient: gradient,
        border: shape.outlineColor != null
            ? Border.all(
                color: outline ?? Colors.black, width: shape.outlineWidth)
            : null,
        borderRadius: radius,
      ),
      child: _shapeTextContent(shape),
    );
  }

  /// A geometric preset painted from [path], with the text content overlaid.
  Widget _painted(DocxShape shape, Path path, Color? fill, Gradient? gradient,
      Color? outline) {
    final isLine = _isLinePreset(shape.preset);
    return SizedBox(
      width: shape.width,
      height: shape.height,
      child: CustomPaint(
        painter: _ShapePainter(
          path: path,
          // A line/connector has no area to fill; everything else fills (Word
          // defaults an unfilled autoshape to a light grey).
          fill: isLine ? null : (fill ?? Colors.grey.shade200),
          gradient: isLine ? null : gradient,
          stroke: isLine ? (outline ?? fill ?? Colors.black) : outline,
          strokeWidth: shape.outlineWidth,
        ),
        child: _shapeTextContent(shape),
      ),
    );
  }

  /// Converts a [DocxGradientFill] to a Flutter [Gradient] (linear via [angle],
  /// or radial), or null when there is nothing to draw. Stops are sorted and
  /// clamped; a single stop is duplicated so the gradient has the ≥2 colours
  /// Flutter requires.
  Gradient? _resolveGradient(DocxGradientFill? g) {
    if (g == null || g.stops.isEmpty) return null;
    final sorted = [...g.stops]
      ..sort((a, b) => a.position.compareTo(b.position));
    var colors = [
      for (final s in sorted) _resolveColor(s.color) ?? _parseHex(s.color.hex)
    ];
    var stops = [for (final s in sorted) s.position.clamp(0.0, 1.0)];
    if (colors.length == 1) {
      colors = [colors.first, colors.first];
      stops = [0.0, 1.0];
    }
    if (g.type == DocxGradientType.radial) {
      return RadialGradient(colors: colors, stops: stops);
    }
    // OOXML `ang` is clockwise from the +x axis; map it to begin/end points on
    // the unit square through the centre.
    final rad = g.angle * math.pi / 180;
    final dx = math.cos(rad);
    final dy = math.sin(rad);
    return LinearGradient(
      begin: Alignment(-dx, -dy),
      end: Alignment(dx, dy),
      colors: colors,
      stops: stops,
    );
  }

  /// The content drawn inside a shape: rich text-box blocks when available
  /// (clipped, top-aligned), else the flat text as a centred label, else null.
  Widget? _shapeTextContent(DocxShape shape) {
    final blocks = shape.textBlocks;
    if (blocks != null && blocks.isNotEmpty && textBlockBuilder != null) {
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxHeight: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: textBlockBuilder!(blocks),
          ),
        ),
      );
    }
    if (shape.text != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            shape.text!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _contrastColor(_resolveColor(shape.fillColor)),
            ),
          ),
        ),
      );
    }
    return null;
  }

  // --- Colour resolution (single source for builder + painter) -------------

  /// Resolves a [DocxColor] (theme colour + tint/shade, else direct hex) to a
  /// Flutter [Color], or null when it carries no usable value (`auto`/empty).
  Color? _resolveColor(DocxColor? color) {
    if (color == null) return null;
    Color? base;
    final themeColor = color.themeColor;
    if (themeColor != null && docxTheme != null) {
      final hex = docxTheme!.colors.getColor(themeColor);
      if (hex != null) base = _parseHex(hex);
    }
    if (base == null && color.hex != 'auto') {
      base = _parseHex(color.hex);
    }
    if (base == null) return null;

    final tint = color.themeTint;
    if (tint != null) {
      final v = int.tryParse(tint, radix: 16);
      if (v != null) {
        base = Color.alphaBlend(
            Colors.white.withValues(alpha: 1 - v / 255.0), base);
      }
    }
    final shade = color.themeShade;
    if (shade != null) {
      final v = int.tryParse(shade, radix: 16);
      if (v != null) {
        base = Color.alphaBlend(
            Colors.black.withValues(alpha: 1 - v / 255.0), base);
      }
    }
    return base;
  }

  Color _contrastColor(Color? fill) =>
      (fill ?? Colors.grey.shade200).computeLuminance() > 0.5
          ? Colors.black
          : Colors.white;
}

/// Parses a `RRGGBB`/`AARRGGBB` hex string (with optional `#`/`0x`) to a [Color],
/// defaulting to grey on malformed input.
Color _parseHex(String hex) {
  final clean = hex.replaceAll('#', '').replaceAll('0x', '');
  if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
  if (clean.length == 8) return Color(int.parse(clean, radix: 16));
  return Colors.grey;
}

/// True for presets that are a stroke, not a filled area.
bool _isLinePreset(DocxShapePreset p) =>
    p == DocxShapePreset.line || p == DocxShapePreset.straightConnector1;

/// Builds the outline [Path] for a geometric [preset] inside a [size] box, or
/// null when the preset is handled by a [BoxDecoration] (rect/roundRect/ellipse)
/// or has no dedicated geometry yet. Pure (no painting) so it is unit-testable.
///
/// All trigonometry uses `dart:math`; coordinates are in the local box where
/// `(0,0)` is top-left and `(w,h)` is bottom-right.
Path? shapePresetPath(DocxShapePreset preset, Size size) {
  final w = size.width;
  final h = size.height;
  switch (preset) {
    case DocxShapePreset.triangle:
      return Path()
        ..moveTo(w / 2, 0)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    case DocxShapePreset.rtTriangle:
      return Path()
        ..moveTo(0, 0)
        ..lineTo(0, h)
        ..lineTo(w, h)
        ..close();
    case DocxShapePreset.diamond:
      return Path()
        ..moveTo(w / 2, 0)
        ..lineTo(w, h / 2)
        ..lineTo(w / 2, h)
        ..lineTo(0, h / 2)
        ..close();
    case DocxShapePreset.parallelogram:
      final off = w * 0.25;
      return Path()
        ..moveTo(off, 0)
        ..lineTo(w, 0)
        ..lineTo(w - off, h)
        ..lineTo(0, h)
        ..close();
    case DocxShapePreset.trapezoid:
      final off = w * 0.25;
      return Path()
        ..moveTo(off, 0)
        ..lineTo(w - off, 0)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    case DocxShapePreset.pentagon:
      return _regularPolygon(size, 5);
    case DocxShapePreset.hexagon:
      return _regularPolygon(size, 6);
    case DocxShapePreset.heptagon:
      return _regularPolygon(size, 7);
    case DocxShapePreset.octagon:
      return _regularPolygon(size, 8);
    case DocxShapePreset.star4:
      return _star(size, 4);
    case DocxShapePreset.star5:
      return _star(size, 5);
    case DocxShapePreset.star6:
      return _star(size, 6);
    case DocxShapePreset.rightArrow:
      return _hArrow(size, pointingRight: true);
    case DocxShapePreset.leftArrow:
      return _hArrow(size, pointingRight: false);
    case DocxShapePreset.downArrow:
      return _vArrow(size, pointingDown: true);
    case DocxShapePreset.upArrow:
      return _vArrow(size, pointingDown: false);
    case DocxShapePreset.leftRightArrow:
      return _hDoubleArrow(size);
    case DocxShapePreset.upDownArrow:
      return _vDoubleArrow(size);
    case DocxShapePreset.chevron:
      return _chevron(size);
    case DocxShapePreset.plus:
    case DocxShapePreset.cross:
      return _plus(size);
    case DocxShapePreset.line:
    case DocxShapePreset.straightConnector1:
      return Path()
        ..moveTo(0, 0)
        ..lineTo(w, h);
    default:
      return null;
  }
}

/// A regular [n]-gon inscribed in [size]'s ellipse, first vertex at the top.
Path _regularPolygon(Size size, int n) {
  final cx = size.width / 2;
  final cy = size.height / 2;
  final path = Path();
  for (var i = 0; i < n; i++) {
    final a = -math.pi / 2 + i * 2 * math.pi / n;
    final x = cx + cx * math.cos(a);
    final y = cy + cy * math.sin(a);
    i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
  }
  return path..close();
}

/// A [points]-pointed star inscribed in [size]'s ellipse, first point at the top.
Path _star(Size size, int points, {double innerRatio = 0.4}) {
  final cx = size.width / 2;
  final cy = size.height / 2;
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final outer = i.isEven;
    final rx = (outer ? cx : cx * innerRatio);
    final ry = (outer ? cy : cy * innerRatio);
    final a = -math.pi / 2 + i * math.pi / points;
    final x = cx + rx * math.cos(a);
    final y = cy + ry * math.sin(a);
    i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
  }
  return path..close();
}

/// A horizontal block arrow (head at the right when [pointingRight]).
Path _hArrow(Size size, {required bool pointingRight}) {
  final w = size.width;
  final h = size.height;
  final headW = math.min(w * 0.4, h);
  final top = h * 0.3;
  final bot = h * 0.7;
  final path = Path();
  if (pointingRight) {
    path
      ..moveTo(0, top)
      ..lineTo(w - headW, top)
      ..lineTo(w - headW, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w - headW, h)
      ..lineTo(w - headW, bot)
      ..lineTo(0, bot);
  } else {
    path
      ..moveTo(w, top)
      ..lineTo(headW, top)
      ..lineTo(headW, 0)
      ..lineTo(0, h / 2)
      ..lineTo(headW, h)
      ..lineTo(headW, bot)
      ..lineTo(w, bot);
  }
  return path..close();
}

/// A vertical block arrow (head at the bottom when [pointingDown]).
Path _vArrow(Size size, {required bool pointingDown}) {
  final w = size.width;
  final h = size.height;
  final headH = math.min(h * 0.4, w);
  final left = w * 0.3;
  final right = w * 0.7;
  final path = Path();
  if (pointingDown) {
    path
      ..moveTo(left, 0)
      ..lineTo(left, h - headH)
      ..lineTo(0, h - headH)
      ..lineTo(w / 2, h)
      ..lineTo(w, h - headH)
      ..lineTo(right, h - headH)
      ..lineTo(right, 0);
  } else {
    path
      ..moveTo(left, h)
      ..lineTo(left, headH)
      ..lineTo(0, headH)
      ..lineTo(w / 2, 0)
      ..lineTo(w, headH)
      ..lineTo(right, headH)
      ..lineTo(right, h);
  }
  return path..close();
}

/// A double-headed horizontal arrow (heads at both ends).
Path _hDoubleArrow(Size size) {
  final w = size.width;
  final h = size.height;
  final headW = math.min(w * 0.25, h);
  final top = h * 0.3;
  final bot = h * 0.7;
  return Path()
    ..moveTo(0, h / 2)
    ..lineTo(headW, 0)
    ..lineTo(headW, top)
    ..lineTo(w - headW, top)
    ..lineTo(w - headW, 0)
    ..lineTo(w, h / 2)
    ..lineTo(w - headW, h)
    ..lineTo(w - headW, bot)
    ..lineTo(headW, bot)
    ..lineTo(headW, h)
    ..close();
}

/// A double-headed vertical arrow (heads at top and bottom).
Path _vDoubleArrow(Size size) {
  final w = size.width;
  final h = size.height;
  final headH = math.min(h * 0.25, w);
  final left = w * 0.3;
  final right = w * 0.7;
  return Path()
    ..moveTo(w / 2, 0)
    ..lineTo(w, headH)
    ..lineTo(right, headH)
    ..lineTo(right, h - headH)
    ..lineTo(w, h - headH)
    ..lineTo(w / 2, h)
    ..lineTo(0, h - headH)
    ..lineTo(left, h - headH)
    ..lineTo(left, headH)
    ..lineTo(0, headH)
    ..close();
}

/// A right-pointing chevron (`>`-like arrow band).
Path _chevron(Size size) {
  final w = size.width;
  final h = size.height;
  final notch = w * 0.3;
  return Path()
    ..moveTo(0, 0)
    ..lineTo(w - notch, 0)
    ..lineTo(w, h / 2)
    ..lineTo(w - notch, h)
    ..lineTo(0, h)
    ..lineTo(notch, h / 2)
    ..close();
}

/// A plus/cross with arms one third of the box.
Path _plus(Size size) {
  final w = size.width;
  final h = size.height;
  final x1 = w / 3;
  final x2 = w * 2 / 3;
  final y1 = h / 3;
  final y2 = h * 2 / 3;
  return Path()
    ..moveTo(x1, 0)
    ..lineTo(x2, 0)
    ..lineTo(x2, y1)
    ..lineTo(w, y1)
    ..lineTo(w, y2)
    ..lineTo(x2, y2)
    ..lineTo(x2, h)
    ..lineTo(x1, h)
    ..lineTo(x1, y2)
    ..lineTo(0, y2)
    ..lineTo(0, y1)
    ..lineTo(x1, y1)
    ..close();
}

/// Paints a preset [path]: fills with [gradient] (preferred) or [fill], then
/// strokes [stroke].
class _ShapePainter extends CustomPainter {
  final Path path;
  final Color? fill;
  final Gradient? gradient;
  final Color? stroke;
  final double strokeWidth;

  _ShapePainter({
    required this.path,
    required this.fill,
    this.gradient,
    required this.stroke,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (gradient != null) {
      canvas.drawPath(
          path,
          Paint()
            ..shader = gradient!.createShader(Offset.zero & size)
            ..style = PaintingStyle.fill);
    } else if (fill != null) {
      canvas.drawPath(
          path,
          Paint()
            ..color = fill!
            ..style = PaintingStyle.fill);
    }
    if (stroke != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = stroke!
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePainter old) =>
      old.path != path ||
      old.fill != fill ||
      old.gradient != gradient ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth;
}
