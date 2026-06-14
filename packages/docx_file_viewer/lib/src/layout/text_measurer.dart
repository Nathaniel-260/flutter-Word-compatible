import 'dart:collection';
import 'dart:ui' as ui;

import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/widgets.dart';

import 'span_factory.dart';

/// The result of measuring one block at a given width (Plan §C.2/§4.3).
///
/// All heights are in logical pixels. [textHeight] is the laid-out content
/// height (what the renderer's `RichText` produces); [totalHeight] adds the
/// paragraph's before/after spacing, matching the rendered block footprint.
class BlockMeasurement {
  const BlockMeasurement({
    required this.source,
    required this.textHeight,
    required this.spacingBefore,
    required this.spacingAfter,
    required this.lineCount,
    required this.lineMetrics,
    required this.firstBaseline,
    required this.lastBaseline,
  });

  /// The paragraph this measurement is for. Used to verify a cache hit by
  /// identity, since the cache key hashes [identityHashCode] (not unique).
  final DocxParagraph source;

  /// Height of the laid-out inline content (no paragraph spacing).
  final double textHeight;

  /// Baseline of the first line (distance from the content top), and of the
  /// last line — used by the paginator to align across page boundaries.
  final double firstBaseline;
  final double lastBaseline;

  /// Space above the content (`w:spacing w:before`), in pixels.
  final double spacingBefore;

  /// Space below the content (`w:spacing w:after`), in pixels.
  final double spacingAfter;

  /// Number of visual lines the content wrapped to.
  final int lineCount;

  /// Per-line metrics (baseline, ascent, height, …) for the paginator's
  /// line-level split points (Part D). Empty for a zero-content block.
  final List<ui.LineMetrics> lineMetrics;

  /// Full vertical footprint of the block: spacing + content.
  double get totalHeight => spacingBefore + textHeight + spacingAfter;
}

/// Line-boundary layout of a paragraph, used by the paginator to pick a split
/// point (Plan §D.4 / §6.4).
///
/// [lineStartChar] and [lineTop] both have length `lineCount + 1`. Entry `k`
/// gives the character offset (painter text space) and the cumulative top-Y of
/// visual line `k`; the final entry is the paragraph end / total content height.
class ParagraphLayout {
  const ParagraphLayout({
    required this.lineStartChar,
    required this.lineTop,
    required this.segments,
  });

  final List<int> lineStartChar;
  final List<double> lineTop;
  final List<SpanSegment> segments;

  int get lineCount => lineTop.length - 1;
}

/// Measures paragraph height/line layout with a single recycled [TextPainter]
/// and an LRU cache (Plan §C.2). The painter is **not** thread-safe; like all
/// `TextPainter` work it must run on the UI thread (§4.4).
///
/// The measurer builds spans through the same [SpanFactory] the renderer uses,
/// so measured height equals rendered height — pagination can trust it.
class TextMeasurer {
  TextMeasurer({
    required this.spanFactory,
    this.maxCacheEntries = 4000,
  });

  final SpanFactory spanFactory;

  /// Hard cap on cached measurements (§2.3 / §4.3): LRU eviction past this.
  final int maxCacheEntries;

  // A blank line is measured with a zero-width space so an empty paragraph
  // occupies one line height (Word measures it via the paragraph-mark run).
  static const String _blankLine = '​';

  final TextPainter _painter = TextPainter(
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  );

  // Insertion-ordered map used as an LRU: most-recently-used is re-inserted at
  // the end, eviction removes from the front.
  final LinkedHashMap<(int, int, int), BlockMeasurement> _cache =
      LinkedHashMap();

  int _styleEpoch = 0;

  // Diagnostics for the cache DoD test.
  int _layoutCount = 0;
  int _cacheHits = 0;

  /// Number of real [TextPainter] layouts performed (cache misses).
  int get layoutCount => _layoutCount;

  /// Number of measurements served from the cache.
  int get cacheHits => _cacheHits;

  /// Current number of cached entries.
  int get cacheSize => _cache.length;

  /// Invalidates every cached measurement by bumping the style epoch. Call when
  /// the config/theme changes the effective width or fonts (§4.3) — O(1), no
  /// scan; the old entries simply never match again and age out.
  void invalidate() {
    _styleEpoch++;
    _cache.clear();
  }

  /// Measures [paragraph] laid out to [width] pixels in [direction].
  ///
  /// Repeated calls with the same block identity, width and epoch return the
  /// cached result without touching the [TextPainter].
  BlockMeasurement measureParagraph(
    DocxParagraph paragraph,
    double width, {
    TextDirection direction = TextDirection.ltr,
  }) {
    assert(width.isFinite, 'measureParagraph requires a finite width');
    final key = (
      identityHashCode(paragraph),
      width.round(),
      _styleEpoch,
    );

    final cached = _cache.remove(key);
    // identityHashCode is a hash, not a unique id: verify the source object on
    // a hit so a hash collision can never return another paragraph's height.
    if (cached != null && identical(cached.source, paragraph)) {
      _cache[key] = cached; // mark most-recently-used
      _cacheHits++;
      return cached;
    }

    final result = _measure(paragraph, width, direction);
    _put(key, result);
    return result;
  }

  BlockMeasurement _measure(
    DocxParagraph paragraph,
    double width,
    TextDirection direction,
  ) {
    _layoutCount++;
    _layoutInto(paragraph, width, direction);

    final lineMetrics = _painter.computeLineMetrics();
    final textHeight = _painter.height;

    return BlockMeasurement(
      source: paragraph,
      textHeight: textHeight,
      spacingBefore: _spacingBefore(paragraph),
      spacingAfter: _spacingAfter(paragraph),
      lineCount: lineMetrics.isEmpty ? 1 : lineMetrics.length,
      lineMetrics: lineMetrics,
      firstBaseline:
          lineMetrics.isEmpty ? textHeight : lineMetrics.first.baseline,
      lastBaseline:
          lineMetrics.isEmpty ? textHeight : lineMetrics.last.baseline,
    );
  }

  /// Lays [paragraph] out on the recycled painter at [width]/[direction] and
  /// returns the built spans (with the segment map). Shared by [_measure] and
  /// [layoutForSplit] so both lay out identically.
  MeasurementSpans _layoutInto(
    DocxParagraph paragraph,
    double width,
    TextDirection direction,
  ) {
    // TODO(plan §C.3): tabbed paragraphs render through TabEngine/
    // TabbedLineRenderer (real stop positions, single line), but here they are
    // measured as plain wrapping text with tabs as 4 spaces — so the measured
    // height can diverge from the painted height for exactly those paragraphs.
    // The paginator (Part D) must model TabEngine layout for parity. (§8.2 #12)
    final lineHeight = spanFactory.resolveLineHeightScale(paragraph);
    // First-line indent (`w:firstLine`) shifts the first line and so changes
    // where it wraps — mirror the renderer's positive-only spacer.
    final rawFirstLine = paragraph.indentFirstLine ?? 0;
    final firstLineIndentPx =
        rawFirstLine > 0 ? (rawFirstLine / 15.0).clamp(0.0, 300.0) : 0.0;
    final built = spanFactory.buildMeasurementSpans(
      paragraph.children,
      lineHeight: lineHeight,
      firstLineIndentPx: firstLineIndentPx,
      skipHidden: true, // w:vanish — not measured (matches the renderer below)
    );

    InlineSpan span = built.root;
    var placeholders = built.placeholders;

    // Empty / content-less paragraph → one line height of the body font.
    final rootChildren = (span as TextSpan).children;
    if (rootChildren == null || rootChildren.isEmpty) {
      span = TextSpan(
        text: _blankLine,
        style: spanFactory.theme.defaultTextStyle.copyWith(
          height: lineHeight ?? spanFactory.theme.defaultTextStyle.height,
        ),
      );
      placeholders = const [];
    }

    _painter
      ..textDirection = direction
      ..strutStyle = spanFactory.resolveStrut(paragraph)
      ..text = span;
    if (placeholders.isNotEmpty) {
      _painter.setPlaceholderDimensions(placeholders);
    }
    _painter.layout(maxWidth: width);
    return built;
  }

  /// Lays [paragraph] out and returns its per-line character offsets and
  /// cumulative heights for paragraph splitting (Plan §D.4). The returned
  /// [ParagraphLayout.segments] map painter offsets back to the source inlines,
  /// so the caller can cut the children via [SpanFactory.sliceInlines].
  ///
  /// Not cached — only called for the rare block that overflows a page.
  ParagraphLayout layoutForSplit(
    DocxParagraph paragraph,
    double width,
    TextDirection direction,
  ) {
    _layoutCount++;
    final built = _layoutInto(paragraph, width, direction);
    final lineMetrics = _painter.computeLineMetrics();
    final textLen = built.root.toPlainText(includePlaceholders: true).length;

    final lineCount = lineMetrics.isEmpty ? 1 : lineMetrics.length;
    final lineStartChar = List<int>.filled(lineCount + 1, 0);
    final lineTop = List<double>.filled(lineCount + 1, 0);

    var cumTop = 0.0;
    for (var k = 0; k < lineCount; k++) {
      lineTop[k] = cumTop;
      // Leading edge of the line: x=0 for LTR, x=width for RTL.
      if (k > 0) {
        final x = direction == TextDirection.rtl ? width : 0.0;
        final pos = _painter.getPositionForOffset(Offset(x, cumTop + 0.5));
        lineStartChar[k] = pos.offset;
      }
      cumTop += lineMetrics.isEmpty ? _painter.height : lineMetrics[k].height;
    }
    lineTop[lineCount] = cumTop;
    lineStartChar[lineCount] = textLen;

    return ParagraphLayout(
      lineStartChar: lineStartChar,
      lineTop: lineTop,
      segments: built.segments,
    );
  }

  /// Releases the recycled [TextPainter]'s native resources. Call when the
  /// owner (e.g. the paginator) is torn down.
  void dispose() {
    _painter.dispose();
    _cache.clear();
  }

  void _put((int, int, int) key, BlockMeasurement value) {
    _cache[key] = value;
    if (_cache.length > maxCacheEntries) {
      _cache.remove(_cache.keys.first); // evict least-recently-used
    }
  }

  // Paragraph spacing, mirroring [ParagraphBuilder._wrapWithParagraphStyle] so
  // the measured footprint matches the rendered block (twips → px at 96 DPI).
  //
  // The default when nothing is resolved is **0** (the OOXML spec default), not
  // a guessed 80tw: the StyleEngine already folds docDefaults + the named-style
  // chain into `spacingBefore/After`, so a null here means the document truly
  // asks for no spacing (e.g. a file with no `Normal` style, like Word's own
  // blank-template body). Injecting 80tw per paragraph inflated the page count
  // (~10px × every body paragraph) and broke 1:1 page-break parity with Word.
  double _spacingBefore(DocxParagraph p) {
    var top = ((p.spacingBefore ?? 0) / 15.0).clamp(0.0, double.infinity);
    if (_isHeading(p)) top = top.clamp(16.0, double.infinity);
    return top;
  }

  double _spacingAfter(DocxParagraph p) {
    var bottom = ((p.spacingAfter ?? 0) / 15.0).clamp(0.0, double.infinity);
    if (_isHeading(p)) bottom = bottom.clamp(8.0, double.infinity);
    return bottom;
  }

  bool _isHeading(DocxParagraph p) {
    if (p.children.isEmpty) return false;
    final first = p.children.first;
    return first is DocxText && first.fontSize != null && first.fontSize! >= 20;
  }
}
