import 'package:docx_creator/docx_creator.dart';

/// A tab stop resolved to pixels, ready for layout (Plan §C.3).
class ResolvedTabStop {
  const ResolvedTabStop({
    required this.posPx,
    required this.alignment,
    this.leader = DocxTabLeader.none,
  });

  /// Distance from the paragraph's *leading* edge (left in LTR, right in RTL).
  final double posPx;
  final DocxTabAlignment alignment;
  final DocxTabLeader leader;
}

/// One positioned segment of a tabbed line, in **leading-edge coordinates**
/// (distance from the paragraph's start edge). The renderer maps these to
/// physical x according to direction, so the engine itself is direction-blind.
class PositionedSegment {
  const PositionedSegment({
    required this.index,
    required this.start,
    required this.width,
    required this.leader,
    required this.gapStart,
  });

  /// Index of this segment in the input list.
  final int index;

  /// Leading-edge offset of the segment's start.
  final double start;

  /// Measured width of the segment.
  final double width;

  /// Leader that fills the gap that precedes this segment.
  final DocxTabLeader leader;

  /// Leading-edge offset where the gap before this segment begins. The leader
  /// fills `[gapStart, start)`.
  final double gapStart;

  /// Leading-edge offset of the segment's trailing end.
  double get end => start + width;
}

/// Computes tab-stop positions and segment placement for a single logical line
/// (Plan §C.3). Pure and direction-agnostic; works in leading-edge coordinates.
///
/// Supported alignments: `left`, `center`, `right`. `decimal` is approximated
/// as `right` (the integer part right-aligns to the stop — exact decimal-point
/// alignment is a documented limitation). `bar` stops draw a vertical rule at
/// their position and do not act as advance targets.
class TabEngine {
  const TabEngine({this.defaultTabStopTwips = 720});

  /// Document default tab interval (`w:defaultTabStop`, settings.xml). Word's
  /// default is 720 twips (½").
  final int defaultTabStopTwips;

  static const double _twipsToPx = 1 / 15.0;

  // Defensive upper bound: a crafted DOCX could carry an absurd tab position;
  // clamp so it can't blow up downstream layout/canvas math. Far beyond any
  // real page width (~800px), so legitimate stops are untouched.
  static const double _maxPosPx = 100000.0;

  double get _defaultIntervalPx => defaultTabStopTwips * _twipsToPx;

  /// Resolves a paragraph's explicit tab stops to pixels, dropping `clear`
  /// entries and sorting by position. Bar stops are kept (they are drawn) but
  /// are skipped when advancing — see [_nextStop].
  List<ResolvedTabStop> resolveStops(DocxParagraph paragraph) {
    final stops = <ResolvedTabStop>[];
    for (final t in paragraph.tabStops) {
      if (t.alignment == DocxTabAlignment.clear) continue;
      stops.add(ResolvedTabStop(
        posPx: (t.posTwips * _twipsToPx).clamp(0.0, _maxPosPx),
        alignment: t.alignment,
        leader: t.leader,
      ));
    }
    stops.sort((a, b) => a.posPx.compareTo(b.posPx));
    return stops;
  }

  /// Bar stops (vertical rules) from a paragraph, in leading-edge pixels.
  List<double> barStops(DocxParagraph paragraph) => [
        for (final t in paragraph.tabStops)
          if (t.alignment == DocxTabAlignment.bar)
            (t.posTwips * _twipsToPx).clamp(0.0, _maxPosPx),
      ];

  /// The next advance stop strictly greater than [cursor]. Explicit non-bar
  /// stops win; beyond the last one, the default interval is used.
  ResolvedTabStop _nextStop(double cursor, List<ResolvedTabStop> stops) {
    for (final s in stops) {
      if (s.alignment == DocxTabAlignment.bar) continue;
      if (s.posPx > cursor + 0.01) return s;
    }
    final interval = _defaultIntervalPx;
    final next = ((cursor / interval).floor() + 1) * interval;
    return ResolvedTabStop(
      posPx: next,
      alignment: DocxTabAlignment.left,
    );
  }

  /// Places each segment of a tabbed line.
  ///
  /// [widths] are the measured segment widths; [tabsBefore] is how many tab
  /// characters precede each segment (`tabsBefore[0]` is usually 0). The lists
  /// must be the same length. [startCursor] is the leading-edge offset of the
  /// first segment (e.g. the paragraph indent).
  List<PositionedSegment> position({
    required List<double> widths,
    required List<int> tabsBefore,
    required List<ResolvedTabStop> stops,
    double startCursor = 0,
  }) {
    assert(widths.length == tabsBefore.length);
    final result = <PositionedSegment>[];
    var cursor = startCursor;

    for (var i = 0; i < widths.length; i++) {
      final w = widths[i];
      final tabs = tabsBefore[i];

      if (tabs == 0) {
        result.add(PositionedSegment(
          index: i,
          start: cursor,
          width: w,
          leader: DocxTabLeader.none,
          gapStart: cursor,
        ));
        cursor += w;
        continue;
      }

      final gapStart = cursor;
      // Intermediate tabs just hop to successive stops (left-align jumps).
      ResolvedTabStop stop = _nextStop(cursor, stops);
      for (var t = 1; t < tabs; t++) {
        cursor = stop.posPx;
        stop = _nextStop(cursor, stops);
      }

      double start;
      switch (stop.alignment) {
        case DocxTabAlignment.center:
          start = stop.posPx - w / 2;
          break;
        case DocxTabAlignment.right:
        case DocxTabAlignment.decimal:
        case DocxTabAlignment.end:
          start = stop.posPx - w;
          break;
        case DocxTabAlignment.left:
        case DocxTabAlignment.start:
        case DocxTabAlignment.bar:
        case DocxTabAlignment.clear:
          start = stop.posPx;
          break;
      }

      // A segment may not back up over earlier content.
      if (start < gapStart) start = gapStart;

      result.add(PositionedSegment(
        index: i,
        start: start,
        width: w,
        leader: stop.leader,
        gapStart: gapStart,
      ));
      cursor = start + w;
    }

    return result;
  }
}
