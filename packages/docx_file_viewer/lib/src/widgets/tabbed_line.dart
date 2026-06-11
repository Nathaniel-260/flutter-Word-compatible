import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/widgets.dart';

import '../layout/tab_engine.dart';

/// Renders a single logical line whose segments are separated by tab stops
/// (Plan §C.3). Used only for paragraphs that actually contain tabs; ordinary
/// paragraphs stay on the fast `RichText` path.
///
/// Segments are measured, positioned by [TabEngine] in leading-edge
/// coordinates, then placed physically (mirrored for RTL). Leader fills and
/// `bar` rules are painted behind the text. This widget does not wrap — it
/// targets headers/footers and short tabbed lines, which is the common case;
/// wrapping tabbed body paragraphs are a documented follow-up.
class TabbedLineRenderer extends StatelessWidget {
  const TabbedLineRenderer({
    super.key,
    required this.segments,
    required this.tabsBefore,
    required this.stops,
    required this.barStops,
    required this.engine,
    required this.direction,
    required this.leaderColor,
  });

  /// One span per content segment (between tabs).
  final List<InlineSpan> segments;

  /// Tab count preceding each segment (`tabsBefore[0]` is usually 0).
  final List<int> tabsBefore;

  /// Resolved (non-bar) tab stops, leading-edge pixels.
  final List<ResolvedTabStop> stops;

  /// Bar-tab positions (vertical rules), leading-edge pixels.
  final List<double> barStops;

  final TabEngine engine;
  final TextDirection direction;
  final Color leaderColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        final widths = <double>[];
        var lineHeight = 0.0;
        for (final span in segments) {
          final painter = TextPainter(
            text: span,
            textDirection: direction,
            maxLines: 1,
          )..layout();
          widths.add(painter.width);
          if (painter.height > lineHeight) lineHeight = painter.height;
          painter.dispose(); // release the native ui.Paragraph promptly
        }
        if (lineHeight == 0) lineHeight = 16;

        final placed = engine.position(
          widths: widths,
          tabsBefore: tabsBefore,
          stops: stops,
        );

        final children = <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _LeaderPainter(
                segments: placed,
                barStops: barStops,
                direction: direction,
                lineWidth: maxWidth,
                color: leaderColor,
              ),
            ),
          ),
          for (final seg in placed)
            Positioned(
              left: direction == TextDirection.ltr ? seg.start : null,
              right: direction == TextDirection.rtl ? seg.start : null,
              top: 0,
              child: RichText(
                text: segments[seg.index],
                textDirection: direction,
                maxLines: 1,
                softWrap: false,
              ),
            ),
        ];

        return SizedBox(
          width: maxWidth,
          height: lineHeight,
          child: Stack(children: children),
        );
      },
    );
  }
}

/// Paints leader fills (dots/dashes/lines) in the gaps before tabbed segments,
/// plus `bar` vertical rules. Coordinates mirror for RTL.
class _LeaderPainter extends CustomPainter {
  _LeaderPainter({
    required this.segments,
    required this.barStops,
    required this.direction,
    required this.lineWidth,
    required this.color,
  });

  final List<PositionedSegment> segments;
  final List<double> barStops;
  final TextDirection direction;
  final double lineWidth;
  final Color color;

  double _x(double leadingOffset) => direction == TextDirection.ltr
      ? leadingOffset
      : lineWidth - leadingOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    final y = size.height - size.height * 0.28; // near the baseline

    for (final seg in segments) {
      if (seg.leader == DocxTabLeader.none) continue;
      if (seg.start - seg.gapStart < 2) continue;

      // Physical gap span [a, b], a < b.
      final p1 = _x(seg.gapStart);
      final p2 = _x(seg.start);
      final a = p1 < p2 ? p1 : p2;
      final b = p1 < p2 ? p2 : p1;

      switch (seg.leader) {
        case DocxTabLeader.underscore:
        case DocxTabLeader.heavy:
          paint.strokeWidth = seg.leader == DocxTabLeader.heavy ? 2.0 : 1.0;
          canvas.drawLine(Offset(a, y), Offset(b, y), paint);
          break;
        case DocxTabLeader.hyphen:
          _dashes(canvas, a, b, y, paint);
          break;
        case DocxTabLeader.dot:
        case DocxTabLeader.middleDot:
          _dots(canvas, a, b, y, paint);
          break;
        case DocxTabLeader.none:
          break;
      }
    }

    // Bar rules: full-height vertical lines at their positions.
    for (final bar in barStops) {
      final x = _x(bar);
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), paint..strokeWidth = 1.0);
    }
  }

  void _dots(Canvas canvas, double a, double b, double y, Paint paint) {
    const step = 4.0;
    for (var x = a + 1; x < b; x += step) {
      canvas.drawCircle(Offset(x, y), 0.7, paint);
    }
  }

  void _dashes(Canvas canvas, double a, double b, double y, Paint paint) {
    const dash = 3.0;
    const gap = 2.0;
    for (var x = a + 1; x < b; x += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(a, b), y), paint);
    }
  }

  @override
  bool shouldRepaint(_LeaderPainter old) =>
      // [segments]/[barStops] are freshly allocated on each build, so an
      // identity compare is always true; the painter is cheap and only rebuilt
      // with its parent, so just repaint.
      true;
}
