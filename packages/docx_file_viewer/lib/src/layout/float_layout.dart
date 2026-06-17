/// Geometry + text-wrap solving for floating drawings (Plan §H.1/§H.2).
///
/// This module is **pure**: it turns an anchored drawing's OOXML placement
/// (relativeFrom × align/offset, size, wrap, dist margins) into a rectangle in
/// the page's *body-content* coordinate system, and answers "how wide is a line
/// of text in this vertical band, given these floats?". Both the paginator (to
/// reserve space while packing) and the renderer (to position the drawing and
/// lay out wrapped lines) consume it, so measurement ≡ rendering (§2.4.6).
///
/// Coordinate system: origin at the **top-left of the body content region**
/// (the area inside the page margins/header/footer). `x` runs left→right in
/// `[0, contentWidth]`; `y` runs top→down from the body top. Page-relative
/// placements legitimately produce negative coordinates (a drawing in the
/// margin), which the renderer positions with an unclipped `Stack`/`Positioned`.
library;

import 'package:docx_creator/docx_creator.dart';

import '../pagination/page_model.dart';
import '../utils/docx_units.dart';

/// How a float affects (or doesn't) the flow of body text beside it.
enum FloatFlow {
  /// Reserves a side band — text wraps in the remaining width (`square`/`tight`/
  /// `through`; the latter two approximated as `square`, §8.2 #1).
  side,

  /// Reserves the full width of every band it overlaps — no text beside it
  /// (`topAndBottom`).
  fullWidth,

  /// No effect on flow — drawn as a back/front layer (`behindText`/`inFront`/
  /// `none`).
  layer,
}

/// The placement inputs of one floating drawing, in resolved pixels — extracted
/// from the AST by [floatPlacementOf] so the geometry math is AST-agnostic.
class FloatPlacement {
  const FloatPlacement({
    required this.width,
    required this.height,
    required this.hFrom,
    required this.vFrom,
    this.hAlign,
    this.vAlign,
    this.hOffsetPx,
    this.vOffsetPx,
    this.distLeftPx = 0,
    this.distRightPx = 0,
    this.distTopPx = 0,
    this.distBottomPx = 0,
    required this.wrap,
    this.zOrder = 0,
  });

  final double width;
  final double height;
  final DocxHorizontalPositionFrom hFrom;
  final DocxVerticalPositionFrom vFrom;
  final DrawingHAlign? hAlign;
  final DrawingVAlign? vAlign;

  /// Absolute offset within the reference frame (`wp:posOffset`), or null when
  /// the drawing is aligned ([hAlign]/[vAlign]) instead.
  final double? hOffsetPx;
  final double? vOffsetPx;

  /// Wrap margins (`distT/B/L/R`) added around the drawing when reserving space.
  final double distLeftPx;
  final double distRightPx;
  final double distTopPx;
  final double distBottomPx;

  final DocxTextWrap wrap;

  /// `relativeHeight` (z-order): higher paints later (on top).
  final int zOrder;

  FloatFlow get flow => switch (wrap) {
        DocxTextWrap.square ||
        DocxTextWrap.tight ||
        DocxTextWrap.through =>
          FloatFlow.side,
        DocxTextWrap.topAndBottom => FloatFlow.fullWidth,
        DocxTextWrap.none ||
        DocxTextWrap.behindText ||
        DocxTextWrap.inFrontOfText =>
          FloatFlow.layer,
      };
}

/// Which side band a `side`-flow float reserves for text to wrap beside, or
/// [none] when it is **not** wrapped as a side band — a centered or
/// offset-positioned float renders as a centered block above/below the text
/// instead. Shared by the renderer's bucketing and [localSideFloatRects] so the
/// two agree (measure ≡ render): a float that renders as a centered block must
/// not also carve a side band in the measured height (§8.2 #31).
enum SideBand { left, right, none }

/// Classifies [p]'s horizontal placement into a [SideBand]. Only `side`-flow
/// floats aligned to the left/right content edge — directly, or via
/// `inside`/`outside` resolved by [pageIsRtl] — wrap text beside them; centered,
/// offset-positioned (no alignment), or non-`side` floats return [SideBand.none].
SideBand sideBandOf(FloatPlacement p, {bool pageIsRtl = false}) {
  if (p.flow != FloatFlow.side) return SideBand.none;
  final align = p.hAlign;
  if (align == null) return SideBand.none; // offset-positioned → centered block
  return switch (align) {
    DrawingHAlign.left => SideBand.left,
    DrawingHAlign.right => SideBand.right,
    DrawingHAlign.inside => pageIsRtl ? SideBand.right : SideBand.left,
    DrawingHAlign.outside => pageIsRtl ? SideBand.left : SideBand.right,
    DrawingHAlign.center => SideBand.none,
  };
}

/// A float resolved to a body-coordinate rectangle, carrying everything the
/// paginator/renderer need: where to draw it ([left]/[top]/[width]/[height]),
/// the exclusion box for wrapping ([marginLeft]…[marginBottom]), and its flow
/// mode + z-order.
class FloatRect {
  const FloatRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.flow,
    required this.zOrder,
    this.marginLeft = 0,
    this.marginRight = 0,
    this.marginTop = 0,
    this.marginBottom = 0,
  });

  /// Drawing box (where the image/shape paints), in body-content coordinates.
  final double left;
  final double top;
  final double width;
  final double height;

  /// Wrap (`dist*`) margins, already added into the exclusion box getters below.
  final double marginLeft;
  final double marginRight;
  final double marginTop;
  final double marginBottom;

  final FloatFlow flow;
  final int zOrder;

  double get right => left + width;
  double get bottom => top + height;

  /// Exclusion box used for wrapping = drawing box grown by the `dist*` margins.
  double get exLeft => left - marginLeft;
  double get exRight => right + marginRight;
  double get exTop => top - marginTop;
  double get exBottom => bottom + marginBottom;

  /// True when this float can steal width from a line spanning [lineTop,
  /// lineBottom] (vertical overlap of the exclusion box, and a flow that reserves
  /// space).
  bool overlapsBand(double lineTop, double lineBottom) =>
      flow != FloatFlow.layer &&
      exTop < lineBottom - _eps &&
      exBottom > lineTop + _eps;
}

/// The horizontal extent available to a line of text after floats are removed.
/// [blocked] is true when no usable width remains (the line must be pushed below
/// the float, e.g. a `topAndBottom` float or a side float that leaves <[minWidth]).
class LineExtent {
  const LineExtent(this.left, this.width, {this.blocked = false});

  /// Left edge of the usable run, in body-content coordinates.
  final double left;

  /// Usable width for the line.
  final double width;

  /// True when the band is unusable for text (move the line down past the float).
  final bool blocked;

  static const LineExtent none = LineExtent(0, 0, blocked: true);
}

/// A floating drawing resolved onto a specific page: the AST node to render and
/// its body-coordinate [rect]. Stored on [PageModel] by the paginator and drawn
/// as a `Positioned` layer by the renderer (Plan §H.2 step 4).
class PlacedFloat {
  const PlacedFloat({required this.drawing, required this.rect});

  /// The floating [DocxInlineImage] or [DocxShape] to paint.
  final DocxInline drawing;

  /// Where it sits, in body-content coordinates (see [FloatRect]).
  final FloatRect rect;
}

const double _eps = 0.01;

/// Reads a drawing's resolved placement, or null when it is inline / not a
/// drawing we position (only floating images and shapes participate).
FloatPlacement? floatPlacementOf(DocxInline inline) {
  if (inline is DocxInlineImage &&
      inline.positionMode == DocxDrawingPosition.floating) {
    return FloatPlacement(
      width: DocxUnits.pointsToPixels(inline.width),
      height: DocxUnits.pointsToPixels(inline.height),
      hFrom: inline.hPositionFrom,
      vFrom: inline.vPositionFrom,
      hAlign: inline.hAlign,
      vAlign: inline.vAlign,
      hOffsetPx: inline.x == null ? null : DocxUnits.pointsToPixels(inline.x!),
      vOffsetPx: inline.y == null ? null : DocxUnits.pointsToPixels(inline.y!),
      distLeftPx: DocxUnits.emuToPixels(inline.distL),
      distRightPx: DocxUnits.emuToPixels(inline.distR),
      distTopPx: DocxUnits.emuToPixels(inline.distT),
      distBottomPx: DocxUnits.emuToPixels(inline.distB),
      wrap: inline.textWrap,
      zOrder: inline.relativeHeight,
    );
  }
  if (inline is DocxShape && inline.position == DocxDrawingPosition.floating) {
    return FloatPlacement(
      width: DocxUnits.pointsToPixels(inline.width),
      height: DocxUnits.pointsToPixels(inline.height),
      hFrom: inline.horizontalFrom,
      vFrom: inline.verticalFrom,
      hAlign: inline.horizontalAlign,
      vAlign: inline.verticalAlign,
      hOffsetPx: inline.horizontalOffset == null
          ? null
          : DocxUnits.pointsToPixels(inline.horizontalOffset!),
      vOffsetPx: inline.verticalOffset == null
          ? null
          : DocxUnits.pointsToPixels(inline.verticalOffset!),
      wrap: inline.behindDocument ? DocxTextWrap.behindText : inline.textWrap,
      zOrder: 0,
    );
  }
  return null;
}

/// Resolves [p] to a body-coordinate [FloatRect] for a page of geometry [geo],
/// where the anchoring paragraph starts at [anchorTopPx] within the body (used
/// for paragraph/line-relative vertical placement). [pageIsRtl] flips
/// inside/outside alignment.
FloatRect resolveFloatRect(
  FloatPlacement p, {
  required PageGeometry geo,
  required double anchorTopPx,
  bool pageIsRtl = false,
}) {
  final contentWidth = geo.contentWidth;
  final bodyHeight = geo.bodyHeight;

  // --- Horizontal reference frame (in body-content x) ---------------------
  final (double refLeft, double refWidth) = switch (p.hFrom) {
    DocxHorizontalPositionFrom.page => (-geo.padLeft, geo.pageWidth),
    DocxHorizontalPositionFrom.leftMargin => (-geo.padLeft, geo.padLeft),
    DocxHorizontalPositionFrom.rightMargin => (contentWidth, geo.padRight),
    // margin/column/character/inside/outside ≈ the body text column.
    _ => (0.0, contentWidth),
  };

  double left;
  if (p.hOffsetPx != null) {
    left = refLeft + p.hOffsetPx!;
  } else {
    final align = p.hAlign ?? DrawingHAlign.left;
    left = switch (align) {
      DrawingHAlign.left => refLeft,
      DrawingHAlign.center => refLeft + (refWidth - p.width) / 2,
      DrawingHAlign.right => refLeft + refWidth - p.width,
      DrawingHAlign.inside =>
        pageIsRtl ? refLeft + refWidth - p.width : refLeft,
      DrawingHAlign.outside =>
        pageIsRtl ? refLeft : refLeft + refWidth - p.width,
    };
  }

  // --- Vertical reference frame (in body-content y) -----------------------
  final (double refTop, double refHeight) = switch (p.vFrom) {
    DocxVerticalPositionFrom.page => (-geo.bodyTop, geo.pageHeight),
    DocxVerticalPositionFrom.topMargin => (
        geo.padTop - geo.bodyTop,
        geo.padTop
      ),
    DocxVerticalPositionFrom.margin => (0.0, bodyHeight),
    DocxVerticalPositionFrom.bottomMargin => (bodyHeight, geo.padBottom),
    // paragraph/line/text → relative to the anchoring paragraph's top.
    _ => (anchorTopPx, (bodyHeight - anchorTopPx).clamp(0.0, bodyHeight)),
  };

  double top;
  if (p.vOffsetPx != null) {
    top = refTop + p.vOffsetPx!;
  } else if (p.vAlign != null) {
    top = switch (p.vAlign!) {
      DrawingVAlign.top || DrawingVAlign.inside => refTop,
      DrawingVAlign.center => refTop + (refHeight - p.height) / 2,
      DrawingVAlign.bottom ||
      DrawingVAlign.outside =>
        refTop + refHeight - p.height,
    };
  } else {
    top = refTop;
  }

  return FloatRect(
    left: left,
    top: top,
    width: p.width,
    height: p.height,
    flow: p.flow,
    zOrder: p.zOrder,
    marginLeft: p.distLeftPx,
    marginRight: p.distRightPx,
    marginTop: p.distTopPx,
    marginBottom: p.distBottomPx,
  );
}

/// Computes the usable horizontal extent for a line occupying the vertical band
/// `[lineTop, lineBottom]` (body coordinates), given the page's [floats].
///
/// Side floats shave width off the matching edge; a float sitting in the middle
/// of the column keeps text on whichever side has more room (rectangular
/// approximation of Word, §8.2 #1). A `topAndBottom` float — or a side float
/// that leaves less than [minWidth] — blocks the band entirely, signalling the
/// caller to drop the line below the float.
LineExtent lineExtent(
  List<FloatRect> floats, {
  required double lineTop,
  required double lineBottom,
  required double contentWidth,
  double minWidth = 8.0,
}) {
  var left = 0.0;
  var right = contentWidth;

  for (final f in floats) {
    if (!f.overlapsBand(lineTop, lineBottom)) continue;
    if (f.flow == FloatFlow.fullWidth) return LineExtent.none;

    final fl = f.exLeft;
    final fr = f.exRight;
    // Ignore a float entirely outside the current usable run.
    if (fr <= left + _eps || fl >= right - _eps) continue;

    final roomRight = right - fr; // usable space to the float's right
    final roomLeft = fl - left; // usable space to the float's left
    final leftAnchored = fl <= left + _eps; // hugs (or passes) the left edge
    final rightAnchored = fr >= right - _eps; // hugs (or passes) the right edge

    if (leftAnchored && !rightAnchored) {
      left = fr; // text flows to the right of a left float
    } else if (rightAnchored && !leftAnchored) {
      right = fl; // text flows to the left of a right float
    } else if (leftAnchored && rightAnchored) {
      return LineExtent.none; // spans the whole column
    } else {
      // Mid-column float: keep the wider side.
      if (roomRight >= roomLeft) {
        left = fr;
      } else {
        right = fl;
      }
    }
    if (right - left < minWidth) return LineExtent.none;
  }

  final width = right - left;
  if (width < minWidth) return LineExtent.none;
  return LineExtent(left, width);
}

/// The smallest `y` at or below [fromY] where a line of height [lineHeight] has
/// at least [minWidth] usable width (i.e. clears every blocking float). Used to
/// drop a line past a float instead of overlapping it. Returns [fromY] when the
/// band is already usable; never scans past [maxY].
double nextUsableY(
  List<FloatRect> floats, {
  required double fromY,
  required double lineHeight,
  required double contentWidth,
  required double maxY,
  double minWidth = 8.0,
}) {
  var y = fromY;
  // Candidate step-downs: the bottom edge of each blocking float above maxY.
  final edges = <double>[
    for (final f in floats)
      if (f.flow != FloatFlow.layer && f.exBottom > fromY + _eps) f.exBottom,
  ]..sort();
  var ei = 0;
  while (y < maxY) {
    final ext = lineExtent(floats,
        lineTop: y,
        lineBottom: y + lineHeight,
        contentWidth: contentWidth,
        minWidth: minWidth);
    if (!ext.blocked) return y;
    // Jump to the next float bottom edge strictly below the current y.
    while (ei < edges.length && edges[ei] <= y + _eps) {
      ei++;
    }
    if (ei >= edges.length) return y; // nothing more to clear
    y = edges[ei];
    ei++;
  }
  return y;
}
