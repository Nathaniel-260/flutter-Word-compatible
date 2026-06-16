import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/widgets.dart';

import '../layout/float_text_layout.dart';

/// Renders a paragraph's text wrapped around its side floats (Plan §H.2,
/// §8.2 #29). Text flows beside each float for the float's height, then resumes
/// full width below it — Word's `square`/`tight` wrap.
///
/// Uses [layoutFloatWrap] — the very function the paginator measures with — so
/// the painted height matches the page-packing height (measure ≡ render). Falls
/// back to a plain [RichText] when the text contains a `WidgetSpan` (an inline
/// image among the wrapped text), which cannot be sliced across lines.
class FloatWrapText extends StatelessWidget {
  const FloatWrapText({
    super.key,
    required this.textSpan,
    required this.sideFloats,
    required this.buildFloat,
    required this.direction,
    this.textAlign = TextAlign.start,
    this.fallback,
  });

  /// The paragraph's text content (no float placeholders).
  final InlineSpan textSpan;

  /// The side-flow floats anchored in this paragraph, in document order.
  final List<DocxInline> sideFloats;

  /// Builds the widget for one float (image/shape), sized to its rect by a
  /// `FittedBox`.
  final Widget Function(DocxInline) buildFloat;

  final TextDirection direction;
  final TextAlign textAlign;

  /// Built when the text cannot be wrapped (a `WidgetSpan` is present).
  final Widget Function()? fallback;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 1000.0;
        final rects = localSideFloatRects(
          sideFloats,
          contentWidth: width,
          pageIsRtl: direction == TextDirection.rtl,
        );
        final result = layoutFloatWrap(
          text: textSpan,
          floats: rects,
          contentWidth: width,
          direction: direction,
        );
        if (result == null) {
          return fallback?.call() ??
              RichText(
                text: textSpan,
                textDirection: direction,
                textAlign: textAlign,
              );
        }
        return SizedBox(
          width: width,
          height: result.height,
          child: Stack(
            children: [
              for (final line in result.lines)
                Positioned(
                  top: line.top,
                  left: line.left,
                  width: line.width,
                  child: RichText(
                    text: line.span,
                    textDirection: direction,
                    textAlign: textAlign,
                  ),
                ),
              for (var i = 0; i < rects.length && i < sideFloats.length; i++)
                Positioned(
                  left: rects[i].left,
                  top: rects[i].top,
                  width: rects[i].width,
                  height: rects[i].height,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: buildFloat(sideFloats[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
