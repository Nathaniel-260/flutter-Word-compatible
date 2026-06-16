import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/widgets.dart';

import 'float_layout.dart';

/// Real text-wrapping around floating drawings (Plan §H.2, §8.2 #29).
///
/// Word's `square`/`tight` wrap lets body text flow *beside* a float for the
/// float's height, then resume full width below it. Flutter's text engine lays a
/// paragraph out at a single constant width, so this module reproduces the
/// behaviour by laying the paragraph out **line by line**: for each line it asks
/// [lineExtent] how wide the usable band is at that vertical position (given the
/// float exclusion rects), lays out exactly one line of text in that band, then
/// advances. Both the renderer ([FloatWrapText]) and the paginator consume the
/// same [layoutFloatWrap], so measure ≡ render (§2.4.6).
///
/// All coordinates are paragraph-local: origin at the paragraph's top-left, `x`
/// in `[0, contentWidth]`, `y` growing downward.

/// One laid-out line: the [span] slice to paint and where it sits.
class FloatWrapLine {
  const FloatWrapLine({
    required this.span,
    required this.top,
    required this.left,
    required this.width,
  });

  final InlineSpan span;
  final double top;
  final double left;
  final double width;
}

/// The result of [layoutFloatWrap]: the placed [lines] and the total [height]
/// (which always clears the tallest space-reserving float).
class FloatWrapResult {
  const FloatWrapResult({required this.lines, required this.height});

  final List<FloatWrapLine> lines;
  final double height;
}

/// Lays [text] out flowing around [floats] within [contentWidth].
///
/// Returns null — signalling the caller to fall back to a simpler layout — when
/// the text contains a placeholder (`WidgetSpan`), since a widget cannot be
/// sliced across lines.
FloatWrapResult? layoutFloatWrap({
  required InlineSpan text,
  required List<FloatRect> floats,
  required double contentWidth,
  required TextDirection direction,
  double minWidth = 24.0,
}) {
  if (contentWidth <= 0) return const FloatWrapResult(lines: [], height: 0);
  final plain = text.toPlainText(includeSemanticsLabels: false);
  // U+FFFC is the object-replacement char a WidgetSpan contributes.
  if (plain.contains('￼')) return null;
  if (plain.isEmpty) {
    return FloatWrapResult(lines: const [], height: _floatsHeight(floats, 0));
  }

  final painter = TextPainter(
    textDirection: direction,
    textScaler: TextScaler.noScaling,
  );

  // Nominal line height for band selection, from a full-width layout.
  painter.text = text;
  painter.layout(maxWidth: contentWidth);
  final nominalMetrics = painter.computeLineMetrics();
  final nominalLineH =
      nominalMetrics.isEmpty ? painter.height : nominalMetrics.first.height;

  final lines = <FloatWrapLine>[];
  var y = 0.0;
  var start = 0;
  var guard = plain.length + 8; // anti-stall backstop

  while (start < plain.length && guard-- > 0) {
    final band = lineExtent(
      floats,
      lineTop: y,
      lineBottom: y + nominalLineH,
      contentWidth: contentWidth,
      minWidth: minWidth,
    );
    if (band.blocked) {
      final ny = nextUsableY(
        floats,
        fromY: y,
        lineHeight: nominalLineH,
        contentWidth: contentWidth,
        maxY: y + nominalLineH * (plain.length + 2),
        minWidth: minWidth,
      );
      y = ny > y ? ny : y + nominalLineH; // always make progress
      continue;
    }

    final tail = _sliceSpan(text, start, plain.length)!;
    painter.text = tail;
    painter.layout(maxWidth: band.width);
    var n = painter.getLineBoundary(const TextPosition(offset: 0)).end;
    final metrics = painter.computeLineMetrics();
    var lineH = metrics.isEmpty ? nominalLineH : metrics.first.height;

    if (n <= 0) {
      // A single token is wider than the band — place it full width so the
      // layout never stalls (the float overlaps it, as Word also does for an
      // unbreakable word wider than the column).
      painter.layout(maxWidth: contentWidth);
      n = painter.getLineBoundary(const TextPosition(offset: 0)).end;
      if (n <= 0) n = plain.length - start; // last resort: the whole tail
      final m2 = painter.computeLineMetrics();
      lineH = m2.isEmpty ? nominalLineH : m2.first.height;
      lines.add(FloatWrapLine(
        span: _sliceSpan(text, start, start + n)!,
        top: y,
        left: 0,
        width: contentWidth,
      ));
    } else {
      lines.add(FloatWrapLine(
        span: _sliceSpan(text, start, start + n)!,
        top: y,
        left: band.left,
        width: band.width,
      ));
    }
    y += lineH;
    start += n;
  }

  painter.dispose();
  return FloatWrapResult(lines: lines, height: _floatsHeight(floats, y));
}

/// The greater of [textBottom] and the bottom of any space-reserving float — a
/// tall float beside short text still occupies its full height.
double _floatsHeight(List<FloatRect> floats, double textBottom) {
  var h = textBottom;
  for (final f in floats) {
    if (f.flow != FloatFlow.layer && f.exBottom > h) h = f.exBottom;
  }
  return h;
}

/// Returns the slice of [span] covering plain-text characters `[start, end)`, or
/// null when the range is empty. Walks the [TextSpan] tree (text first, then
/// children — Flutter's order) keeping styles and gesture recognizers on each
/// slice. A non-text span (placeholder) counts as one character; callers bail on
/// placeholders before reaching here.
InlineSpan? _sliceSpan(InlineSpan span, int start, int end) =>
    _sliceWalk(span, start, end, _Cursor());

class _Cursor {
  int pos = 0;
}

InlineSpan? _sliceWalk(InlineSpan span, int start, int end, _Cursor c) {
  if (span is TextSpan) {
    String? newText;
    final text = span.text;
    if (text != null && text.isNotEmpty) {
      final s = c.pos;
      final e = s + text.length;
      final a = start < s ? s : start;
      final b = end > e ? e : end;
      if (b > a) newText = text.substring(a - s, b - s);
      c.pos = e;
    }
    List<InlineSpan>? newChildren;
    final children = span.children;
    if (children != null) {
      for (final child in children) {
        final sliced = _sliceWalk(child, start, end, c);
        if (sliced != null) (newChildren ??= <InlineSpan>[]).add(sliced);
      }
    }
    if (newText == null && newChildren == null) return null;
    return TextSpan(
      text: newText,
      style: span.style,
      children: newChildren,
      recognizer: span.recognizer,
    );
  }
  // Placeholder / unknown: occupies one character.
  final at = c.pos;
  c.pos += 1;
  return (start <= at && at < end) ? span : null;
}

/// Resolves the paragraph-local exclusion rectangles for the side floats among
/// [inlines], at [contentWidth]. Used by both the renderer and the paginator so
/// the wrap geometry is identical (measure ≡ render). Only `side`-flow floats
/// participate (full-width/layer floats are handled elsewhere); the float sits at
/// its horizontal alignment/offset and at its vertical offset from the paragraph
/// top (paragraph/line/char-anchored floats; others pin to the top).
List<FloatRect> localSideFloatRects(
  List<DocxInline> inlines, {
  required double contentWidth,
  bool pageIsRtl = false,
}) {
  final rects = <FloatRect>[];
  for (final inline in inlines) {
    final p = floatPlacementOf(inline);
    if (p == null || p.flow != FloatFlow.side) continue;

    final width = p.width;
    final height = p.height;
    double left;
    if (p.hOffsetPx != null) {
      left = p.hOffsetPx!;
    } else {
      final align = p.hAlign ?? DrawingHAlign.left;
      left = switch (align) {
        DrawingHAlign.left => 0,
        DrawingHAlign.center => (contentWidth - width) / 2,
        DrawingHAlign.right => contentWidth - width,
        DrawingHAlign.inside => pageIsRtl ? contentWidth - width : 0,
        DrawingHAlign.outside => pageIsRtl ? 0 : contentWidth - width,
      };
    }
    final top = p.vOffsetPx ?? 0.0;

    rects.add(FloatRect(
      left: left,
      top: top,
      width: width,
      height: height,
      flow: FloatFlow.side,
      zOrder: p.zOrder,
      marginLeft: p.distLeftPx,
      marginRight: p.distRightPx,
      marginTop: p.distTopPx,
      marginBottom: p.distBottomPx,
    ));
  }
  return rects;
}
