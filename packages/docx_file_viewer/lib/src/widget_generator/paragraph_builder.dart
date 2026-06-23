import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/search/docx_search_controller.dart';
import 'package:docx_file_viewer/src/utils/block_index_counter.dart';
import 'package:docx_file_viewer/src/utils/text_direction_detector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../docx_view_config.dart';
import '../layout/bidi_align.dart';
import '../layout/float_layout.dart';
import '../layout/span_factory.dart';
import '../layout/tab_engine.dart';
import '../theme/docx_view_theme.dart';
import '../widgets/drop_cap_text.dart';
import '../widgets/float_wrap_text.dart';
import '../widgets/tabbed_line.dart';
import 'image_builder.dart';
import 'shape_builder.dart';

/// Builds Flutter widgets from [DocxParagraph] elements.
class ParagraphBuilder {
  final DocxViewTheme theme;
  final DocxViewConfig config;
  final DocxTheme? docxTheme;
  final DocxSearchController? searchController;
  final void Function(int id)? onFootnoteTap;
  final void Function(int id)? onEndnoteTap;

  /// Called when an internal link (anchor to a bookmark) is tapped, with the
  /// bookmark name (Plan §K.2). When null the tap is ignored.
  final void Function(String bookmark)? onInternalLink;

  /// Called when an external hyperlink is tapped, with the url (Plan §K.2). When
  /// null the viewer falls back to launching the url via `url_launcher`.
  final void Function(String url)? onExternalLink;

  /// Shared run→span source of truth (Plan §C.1); the measurer uses the same
  /// instance-equivalent factory so measured geometry matches rendered.
  final SpanFactory _spanFactory;

  /// The shared run→span factory, exposed so sibling builders (e.g.
  /// [TableBuilder]'s content-width floor) measure with the *same* span
  /// construction the paginator's measurer uses — keeping measure ≡ render.
  SpanFactory get spanFactory => _spanFactory;

  /// Renders inline and in-flow (side/center) images through the same transform
  /// stack (crop → flip → rotate, Plan §H.3) and display-resolution decode as
  /// block/layered images, so every image path bounds RAM and honours crop. Only
  /// needs [config]; created lazily so test instantiations need not pass one.
  late final ImageBuilder _imageBuilder = ImageBuilder(config: config);

  /// Shared shape renderer (preset geometry, fill/outline, and text-box block
  /// content via re-entry, Plan §H). Set by the generator so an in-flow shape
  /// renders identically to a layered one; null in standalone/test use, where
  /// [_buildInlineShape] falls back to a plain fill/outline box.
  ShapeBuilder? shapeBuilder;

  /// `footnoteId → display label` and `endnoteId → display label` computed by the
  /// paginator (Plan §J.4). Set by the generator after pagination so a reference
  /// mark renders the number Word shows (which depends on numbering format and
  /// per-page/section restart, not the raw id). Empty before pagination /
  /// standalone use, where the mark falls back to the id.
  Map<int, String> footnoteLabels = const {};
  Map<int, String> endnoteLabels = const {};

  /// A paragraph's own shading fill as a [Color], falling back to an [inherited]
  /// background (the enclosing cell's fill). The result is threaded explicitly
  /// through the build/span helpers as the `autoBackground` argument (never held
  /// as mutable state) so an `auto` run colour resolves against the shading the
  /// text actually sits on, with no risk of a stale value leaking between
  /// paragraphs (item 15). Render-only — colour never affects measurement.
  Color? _effectiveBackground(DocxParagraph p, Color? inherited) {
    if (p.shadingFill != null || p.themeFill != null) {
      return _spanFactory.resolveColor(
              p.shadingFill, p.themeFill, p.themeFillTint, p.themeFillShade) ??
          inherited;
    }
    return inherited;
  }

  // Used for search highlighting

  ParagraphBuilder({
    required this.theme,
    required this.config,
    this.searchController,
    this.onFootnoteTap,
    this.onEndnoteTap,
    this.onInternalLink,
    this.onExternalLink,
    this.docxTheme,
  }) : _spanFactory = SpanFactory(
          theme: theme,
          config: config,
          docxTheme: docxTheme,
        );

  /// Build a widget from a [DocxParagraph].
  ///
  /// Search highlights are injected at build time from the live match set (Plan
  /// §M.1). The [counter] only keeps this paragraph's block index aligned with
  /// the search index — no per-block [GlobalKey] is registered (navigation
  /// scrolls to the match's page instead).
  Widget build(DocxParagraph paragraph,
      {BlockIndexCounter? counter, Color? inheritedBackground}) {
    List<SearchMatch>? matches;

    if (counter != null && searchController != null) {
      final blockIndex = counter.value;
      matches = searchController!.matches
          .where((m) => m.blockIndex == blockIndex)
          .toList();
      counter.increment();
    }

    return _buildNativeParagraph(paragraph,
        matches: matches,
        autoBackground: _effectiveBackground(paragraph, inheritedBackground));
  }

  /// Build a paragraph widget, excluding specific floating images.
  /// Used when specific floats are being handled separately at the block level.
  Widget buildExcludingFloats(
      DocxParagraph paragraph, Set<DocxInline> excludedFloats,
      {BlockIndexCounter? counter, Color? inheritedBackground}) {
    List<SearchMatch>? matches;

    if (counter != null && searchController != null) {
      final blockIndex = counter.value;
      matches = searchController!.matches
          .where((m) => m.blockIndex == blockIndex)
          .toList();
      counter.increment();
    }

    return _buildNativeParagraph(paragraph,
        excludedFloats: excludedFloats,
        matches: matches,
        autoBackground: _effectiveBackground(paragraph, inheritedBackground));
  }

  /// מזהה את כיוון הפסקה (RTL/LTR).
  ///
  /// מקור האמת הוא `w:bidi` מהמסמך ([DocxParagraph.isRtl], חלק A). רק כשהוא לא
  /// מסומן נופלים לזיהוי לפי תוכן (אלגוריתם "first strong": עברית/ערבית → RTL,
  /// לטינית → LTR). עוטפים את הפסקה ב-[Directionality] עם הכיוון הזה כך ש-RichText,
  /// Column ו-`TextAlign.start` מתפרשים נכון ל-RTL (קריטי למסמכי קודש עבריים).
  static TextDirection _detectDirection(DocxParagraph paragraph) =>
      paragraph.isRtl
          ? TextDirection.rtl
          : TextDirectionDetector.fromInlines(paragraph.children);

  /// Native Flutter builder for standard paragraphs.
  Widget _buildNativeParagraph(DocxParagraph paragraph,
      {Set<DocxInline>? excludedFloats,
      List<SearchMatch>? matches,
      Color? autoBackground}) {
    // Tab-stop layout (§C.3): only when the author defined explicit stops, the
    // paragraph has a tab, and its content is plain text. This keeps ordinary
    // leading-tab body paragraphs on the wrapping RichText path (the tabbed
    // renderer does not wrap) and keeps segment measurement placeholder-free.
    if (paragraph.tabStops.isNotEmpty && _isPlainTabbedLine(paragraph)) {
      return _buildTabbedParagraph(paragraph, autoBackground: autoBackground);
    }

    List<(DocxInline, DocxAlign?)> textChildren = [];

    // Separate content
    for (var child in paragraph.children) {
      bool isFloating = false;
      DocxAlign align = DocxAlign.left; // Default logic

      if (child is DocxInlineImage &&
          child.positionMode == DocxDrawingPosition.floating) {
        if (excludedFloats?.contains(child) ?? false) {
          continue; // Skip specific excluded float
        }
        isFloating = true;
        if (child.hAlign == DrawingHAlign.center) {
          align = DocxAlign.center;
        } else {
          align = child.hAlign == DrawingHAlign.right
              ? DocxAlign.right
              : DocxAlign.left;
        }
      } else if (child is DocxShape &&
          child.position == DocxDrawingPosition.floating) {
        if (excludedFloats?.contains(child) ?? false) {
          continue; // Skip specific excluded float
        }
        isFloating = true;
        if (child.horizontalAlign == DrawingHAlign.center) {
          align = DocxAlign.center;
        } else {
          align = child.horizontalAlign == DrawingHAlign.right
              ? DocxAlign.right
              : DocxAlign.left;
        }
      }

      textChildren.add((child, isFloating ? align : null));
    }

    // List of block-level widgets (rows or center blocks)
    final List<Widget> columnChildren = [];

    // Buffers for the current "Row" context
    List<DocxInline> currentLeftFloats = [];
    List<DocxInline> currentRightFloats = [];
    List<DocxInline> currentInlines = [];

    final lineHeightScale = _resolveLineHeightScale(paragraph);
    // exact/atLeast line spacing → forced/min per-line box (§C.2), matching the
    // measurer. auto spacing stays on the lineHeightScale multiplier above.
    final strut = _spanFactory.resolveStrut(paragraph);
    final direction = _detectDirection(paragraph);
    // יישור תלוי-כיוון לפי טבלת ה-BiDi המחייבת (§C.4). הכיוון נלקח מ-`w:bidi`
    // (כשקיים) או מזיהוי התוכן — ה-fallback. resolveParagraphTextAlign מחזיר
    // TextAlign פיזי, כך שאינו תלוי עוד ב-Directionality לפענוח start/end.
    final textAlign = resolveParagraphTextAlign(
      paragraph.align,
      isRtl: direction == TextDirection.rtl,
    );

    // Track current text offset for highlighting
    int currentTextOffset = 0;

    // First-line indent (w:firstLine > 0).
    // Hanging indent (w:hanging) = negative indentFirstLine: the container is
    // already shifted left by _wrapWithParagraphStyle; body lines (non-first)
    // need a positive spacer of the same magnitude to align them at indentLeft.
    final int rawFirstLine = paragraph.indentFirstLine ?? 0;
    final double firstLineIndentPx =
        rawFirstLine > 0 ? (rawFirstLine / 15.0).clamp(0.0, 300.0) : 0.0;
    final double bodyLineIndentPx =
        rawFirstLine < 0 ? ((-rawFirstLine) / 15.0).clamp(0.0, 300.0) : 0.0;
    bool isFirstFlush = true;

    // Helper to flush current buffers into a single layout row
    void flushBuffer() {
      if (currentInlines.isEmpty &&
          currentLeftFloats.isEmpty &&
          currentRightFloats.isEmpty) {
        return;
      }

      final spans = buildInlineSpans(
        currentInlines,
        lineHeight: lineHeightScale,
        matches: matches,
        startOffset: currentTextOffset,
        firstLineIndentPx: isFirstFlush ? firstLineIndentPx : bodyLineIndentPx,
        autoBackground: autoBackground,
      );
      isFirstFlush = false;

      // Update offset (skip hidden runs so search offsets stay aligned with the
      // search index, which also drops w:vanish text).
      for (final inline in currentInlines) {
        if (inline is DocxText) {
          if (inline.hidden) continue;
          currentTextOffset += inline.content.length;
        } else if (inline is DocxTab) {
          currentTextOffset += 4; // '    '.length
        } else if (inline is DocxLineBreak) {
          currentTextOffset += 1;
        } else if (inline is DocxCheckbox) {
          currentTextOffset += 2; // '☒ '
        }
      }

      final fullTextSpan =
          TextSpan(style: theme.defaultTextStyle, children: spans);

      Widget rowWidget;

      // If we have any floating elements, we MUST use the floating layout (Row)
      // to ensure they sit side-by-side with text.
      if (currentLeftFloats.isNotEmpty || currentRightFloats.isNotEmpty) {
        // Create copies to separate from buffer
        final lefts = List<DocxInline>.from(currentLeftFloats);
        final rights = List<DocxInline>.from(currentRightFloats);

        rowWidget = _buildFloatingLayout(
          textSpan: fullTextSpan,
          leftElements: lefts,
          rightElements: rights,
          textAlign: textAlign,
          direction: direction,
          lineHeightScale: lineHeightScale,
          strut: strut,
        );
      } else {
        // Standard text layout for efficiency if no floats
        if (config.enableSelection) {
          rowWidget = SelectableText.rich(
            fullTextSpan,
            textAlign: textAlign,
            strutStyle: strut,
          );
        } else {
          rowWidget = RichText(
            text: fullTextSpan,
            textAlign: textAlign,
            strutStyle: strut,
          );
        }
        // Ensure it takes width to respect alignment
        rowWidget = SizedBox(width: double.infinity, child: rowWidget);
      }

      columnChildren.add(rowWidget);

      currentLeftFloats.clear();
      currentRightFloats.clear();
      currentInlines.clear();
    }

    // Iterate through children and bucket them into Rows
    for (var child in paragraph.children) {
      if (excludedFloats?.contains(child) ?? false) {
        continue; // Skip specific excluded float
      }
      // A floating drawing that does NOT reserve a side band — full-width
      // (`topAndBottom`) or a back/front layer (`behindText`/`inFront`/`none`).
      final placement = (child is DocxInlineImage || child is DocxShape)
          ? floatPlacementOf(child)
          : null;
      if (placement != null && placement.flow != FloatFlow.side) {
        // In paged mode the paginator draws these on the page float layer /
        // page background, so they are stripped here. In continuous mode there
        // is no page model, so a full-width (`topAndBottom`) float would vanish
        // entirely — render it inline as an aligned block so it is not lost
        // (best-effort: it reserves the full content width in flow). Layer
        // floats (`behindText`/`inFront`/`none`) need page-absolute positioning
        // that continuous mode lacks and remain unsupported there (§8.2 #34).
        if (config.pageMode == DocxPageMode.continuous &&
            placement.flow == FloatFlow.fullWidth) {
          flushBuffer();
          final Widget? w = child is DocxInlineImage
              ? _imageBuilder.buildInlineImage(child)
              : (child is DocxShape ? _buildInlineShape(child) : null);
          if (w != null) {
            final hAlign = child is DocxInlineImage
                ? child.hAlign
                : (child as DocxShape).horizontalAlign;
            columnChildren.add(Align(
              alignment: switch (hAlign) {
                DrawingHAlign.right => Alignment.centerRight,
                DrawingHAlign.center => Alignment.center,
                _ => Alignment.centerLeft,
              },
              child: w,
            ));
          }
        }
        continue;
      }
      // A *side* float (square/tight/through) buckets by which side band it
      // reserves ([sideBandOf], shared with the paginator so measure ≡ render):
      // left/right wrap the text beside it (via [FloatWrapText]); a centered or
      // offset-positioned float ([SideBand.none]) breaks the row into a centred
      // block. Inline (non-floating) drawings have no placement → text flow.
      final band = placement == null
          ? null
          : sideBandOf(placement, pageIsRtl: direction == TextDirection.rtl);

      if (placement != null && band == SideBand.none) {
        // A centred-block float breaks the current Row.
        flushBuffer();

        Widget centerWidget;
        if (child is DocxInlineImage) {
          centerWidget = _imageBuilder.buildInlineImage(child);
        } else if (child is DocxShape) {
          centerWidget = _buildInlineShape(child);
        } else {
          centerWidget = const SizedBox.shrink();
        }
        columnChildren.add(Center(child: centerWidget));
      } else if (band == SideBand.left) {
        currentLeftFloats.add(child);
      } else if (band == SideBand.right) {
        currentRightFloats.add(child);
      } else {
        currentInlines.add(child);
      }
    }

    // Flush any remaining content
    flushBuffer();

    // Empty paragraph → render exactly one blank line so the painted height
    // equals the measurer's (which always reserves one line via a zero-width
    // space). Without this an empty paragraph collapsed to zero height, a
    // pre-existing measure≠render gap. The size comes from the paragraph-mark
    // run (`w:pPr/w:rPr/w:sz`) when set, else the body default — byte-identical
    // to [TextMeasurer]'s blank-line style (03-run-rpr.md item 1).
    if (columnChildren.isEmpty) {
      final markPx = paragraph.markRunFontSize != null
          ? paragraph.markRunFontSize! * 1.333
          : null;
      final blankSpan = TextSpan(
        text: '​', // zero-width space, identical to TextMeasurer._blankLine
        style: theme.defaultTextStyle.copyWith(
          fontSize: markPx,
          height: lineHeightScale ?? theme.defaultTextStyle.height,
        ),
      );
      final Widget blank = config.enableSelection
          ? SelectableText.rich(blankSpan, strutStyle: strut)
          : RichText(text: blankSpan, strutStyle: strut);
      columnChildren.add(SizedBox(width: double.infinity, child: blank));
    }

    // Final Assembly
    Widget finalContent;
    if (columnChildren.isEmpty) {
      finalContent = const SizedBox();
    } else if (columnChildren.length == 1) {
      finalContent = columnChildren.first;
    } else {
      finalContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columnChildren
            .map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: w,
                ))
            .toList(),
      );
    }

    // עטיפת הפסקה ב-Directionality: כל ה-RichText/SelectableText/Column הפנימיים
    // יורשים את הכיוון הזה (RichText יורש textDirection מה-ambient Directionality),
    // כך ש-RTL מסתדר נכון בלי להזריק textDirection לכל widget בנפרד.
    return _wrapWithParagraphStyle(
      paragraph,
      Directionality(textDirection: direction, child: finalContent),
    );
  }

  /// True when [paragraph] has at least one tab and contains only inline
  /// content the tab renderer can measure with a plain `TextPainter` (no
  /// images/shapes/checkboxes → no placeholders, and no floats).
  bool _isPlainTabbedLine(DocxParagraph paragraph) {
    var hasTab = false;
    for (final c in paragraph.children) {
      if (c is DocxTab) {
        hasTab = true;
      } else if (c is DocxInlineImage ||
          c is DocxShape ||
          c is DocxCheckbox ||
          c is DocxLineBreak) {
        // The single-line tabbed renderer (maxLines: 1, no wrap) would clip
        // everything after a line break — keep such paragraphs on the normal
        // wrapping path. Images/shapes/checkboxes need placeholder measurement.
        return false;
      }
    }
    return hasTab;
  }

  /// Renders a tab-stop line through the [TabEngine]/[TabbedLineRenderer]
  /// (§C.3). Segments are split at tabs; search highlighting is skipped on this
  /// path (rare for tabbed headers/footers) — a documented limitation.
  Widget _buildTabbedParagraph(DocxParagraph paragraph,
      {Color? autoBackground}) {
    final lineHeightScale = _resolveLineHeightScale(paragraph);
    final direction = _detectDirection(paragraph);

    final segments = <InlineSpan>[];
    final tabsBefore = <int>[];
    var current = <DocxInline>[];
    var pendingTabs = 0;

    void flush() {
      final spans = buildInlineSpans(current,
          lineHeight: lineHeightScale, autoBackground: autoBackground);
      segments.add(TextSpan(style: theme.defaultTextStyle, children: spans));
      tabsBefore.add(pendingTabs);
    }

    for (final child in paragraph.children) {
      if (child is DocxTab) {
        if (current.isNotEmpty) {
          flush();
          current = <DocxInline>[];
          pendingTabs = 1;
        } else {
          pendingTabs++;
        }
      } else {
        current.add(child);
      }
    }
    flush();

    const engine = TabEngine();
    final widget = TabbedLineRenderer(
      segments: segments,
      tabsBefore: tabsBefore,
      stops: engine.resolveStops(paragraph),
      barStops: engine.barStops(paragraph),
      engine: engine,
      direction: direction,
      leaderColor: theme.defaultTextStyle.color ?? const Color(0xFF000000),
    );

    return _wrapWithParagraphStyle(
      paragraph,
      Directionality(textDirection: direction, child: widget),
    );
  }

  /// Builds a layout that wraps text around left and/or right floating elements.
  ///
  /// Lays a paragraph's text out wrapping around its side floats (Plan §H.2,
  /// §8.2 #29) via [FloatWrapText] — text flows beside a float for its height,
  /// then full width below, matching Word. Falls back to a simple
  /// `IntrinsicHeight`+`Row` (float column beside the whole text) when the text
  /// carries a `WidgetSpan` (an inline image) that cannot be sliced across lines.
  Widget _buildFloatingLayout({
    required TextSpan textSpan,
    List<DocxInline> leftElements = const [],
    List<DocxInline> rightElements = const [],
    required TextAlign textAlign,
    required TextDirection direction,
    double? lineHeightScale,
    StrutStyle? strut,
  }) {
    const double floatSpacing = 12.0;

    // Helper to build the widget for a floating element (natural size; the wrap
    // scales it to its resolved rect with a FittedBox).
    Widget? buildFloatWidget(DocxInline? element) {
      if (element == null) return null;
      if (element is DocxInlineImage) {
        return _imageBuilder.buildInlineImage(element);
      } else if (element is DocxShape) {
        return _buildInlineShape(element);
      }
      return null;
    }

    // Build a column of floating elements (fallback layout only).
    Widget buildFloatColumn(List<DocxInline> elements) {
      if (elements.isEmpty) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: elements.map((e) {
          final widget = buildFloatWidget(e) ?? const SizedBox.shrink();
          final index = elements.indexOf(e);
          if (index < elements.length - 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: widget,
            );
          }
          return widget;
        }).toList(),
      );
    }

    // Fallback: the whole text column beside the floats (pre-§8.2 #29 behaviour).
    Widget fallbackRow() {
      final Widget textWidget = config.enableSelection
          ? SelectableText.rich(textSpan,
              textAlign: textAlign, strutStyle: strut)
          : RichText(text: textSpan, textAlign: textAlign, strutStyle: strut);
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leftElements.isNotEmpty) ...[
              buildFloatColumn(leftElements),
              const SizedBox(width: floatSpacing),
            ],
            Expanded(child: textWidget),
            if (rightElements.isNotEmpty) ...[
              const SizedBox(width: floatSpacing),
              buildFloatColumn(rightElements),
            ],
          ],
        ),
      );
    }

    return FloatWrapText(
      textSpan: textSpan,
      sideFloats: [...leftElements, ...rightElements],
      direction: direction,
      textAlign: textAlign,
      strut: strut,
      buildFloat: (el) => buildFloatWidget(el) ?? const SizedBox.shrink(),
      fallback: fallbackRow,
    );
  }

  /// Helper to apply paragraph decorations (indent, padding, shading, borders)
  /// A visible border's `w:space` (points → px at 96 DPI), or 0 when the side is
  /// absent or has no rule (`style == none`). Mirrored verbatim by
  /// [TextMeasurer] so the bordered block's footprint is identical in both.
  static double _borderSpacePx(DocxBorderSide? side) =>
      (side != null && side.style != DocxBorder.none)
          ? side.space * (96.0 / 72.0)
          : 0.0;

  Widget _wrapWithParagraphStyle(DocxParagraph paragraph, Widget content) {
    // Apply paragraph styling from DocxParagraph properties
    const double twipsToPixels = 1 / 15.0;

    // Indents are *logical*: `indentLeft` holds `w:start`/`w:left` (the leading
    // edge) and `indentRight` holds `w:end`/`w:right` (the trailing edge). Map
    // them to physical left/right by the paragraph's direction so an RTL
    // (Hebrew) paragraph's start indent lands on the right, as Word draws it
    // (04-paragraph-ppr.md items 44/45). The left+right *sum* is unchanged by
    // the swap, so the measurer (which only narrows width by border space) stays
    // 1:1. Clamped to non-negative to avoid padding assertion errors.
    final bool isRtl = _detectDirection(paragraph) == TextDirection.rtl;
    double leadingPad =
        ((paragraph.indentLeft ?? 0) * twipsToPixels).clamp(0, double.infinity);
    // Hanging indent (w:hanging): negative indentFirstLine pulls the first line
    // toward the leading edge of the body text. Approximate by reducing the
    // container's leading edge to the hanging position; body lines get a spacer
    // (added in _buildNativeParagraph) to realign at the leading indent.
    if ((paragraph.indentFirstLine ?? 0) < 0) {
      final hangingPx = ((-paragraph.indentFirstLine!) * twipsToPixels)
          .clamp(0.0, leadingPad);
      leadingPad = (leadingPad - hangingPx).clamp(0.0, double.infinity);
    }
    final double trailingPad = ((paragraph.indentRight ?? 0) * twipsToPixels)
        .clamp(0, double.infinity);
    double leftPadding = isRtl ? trailingPad : leadingPad;
    double rightPadding = isRtl ? leadingPad : trailingPad;
    // Left/right border `w:space` (CT_Border, points) — the gap Word keeps
    // between a vertical rule and the text. The measurer narrows its layout
    // width by the same amount (TextMeasurer._hBorderSpacePx) so a paragraph
    // with a side rule wraps identically in measure and render. Border sides
    // are physical, so this is applied after the logical→physical mapping.
    leftPadding += _borderSpacePx(paragraph.borderLeft);
    rightPadding += _borderSpacePx(paragraph.borderRight);
    // Default 0 (OOXML spec) when nothing is resolved — must mirror
    // [TextMeasurer._spacingBefore/_spacingAfter]. The StyleEngine already folds
    // docDefaults + the style chain into spacingBefore/After, so a null means the
    // document asks for no spacing; the old guessed 80tw inflated every body
    // paragraph and broke page-break parity with Word.
    // Line-unit spacing (`w:beforeLines`/`w:afterLines`, hundredths of a line)
    // takes precedence over the twips value when set (ISO/IEC 29500 §17.3.1.33);
    // the shared helper is mirrored by [TextMeasurer] for measure ≡ render.
    double topPadding = (_spanFactory.lineUnitSpacingPx(
                paragraph, paragraph.spacingBeforeLines) ??
            (paragraph.spacingBefore ?? 0) * twipsToPixels)
        .clamp(0, double.infinity);
    double bottomPadding = (_spanFactory.lineUnitSpacingPx(
                paragraph, paragraph.spacingAfterLines) ??
            (paragraph.spacingAfter ?? 0) * twipsToPixels)
        .clamp(0, double.infinity);

    // Top/bottom border `w:space` (CT_Border, points) — the gap Word keeps
    // between the rule and the text. Added as inner padding; the measurer adds
    // the identical amount to [TextMeasurer._spacingBefore]/[_spacingAfter] so
    // the measured footprint stays 1:1 with the painted block. (Left/right
    // `w:space` was added above to the left/right padding, mirrored by the
    // measurer narrowing the layout width.) Only a *visible* border contributes
    // — a rule-less side (`style == none`) reserves no gap.
    topPadding += _borderSpacePx(paragraph.borderTop);
    bottomPadding +=
        _borderSpacePx(paragraph.borderBottomSide ?? paragraph.borderBetween);

    // Heading detection
    if (paragraph.children.isNotEmpty) {
      final first = paragraph.children.first;
      if (first is DocxText &&
          first.fontSize != null &&
          first.fontSize! >= 20) {
        topPadding = topPadding.clamp(16, double.infinity);
        bottomPadding = bottomPadding.clamp(8, double.infinity);
      }
    }

    BoxDecoration? decoration = _buildParagraphDecoration(paragraph);

    // `w:pageBreakBefore` is realised by the paginator (paged mode), which clears
    // the flag before this builder runs. In continuous mode there are no pages,
    // and Word draws no horizontal rule for a page break — so we render the
    // paragraph normally rather than injecting a Divider artifact (item 4).

    return Container(
      padding: EdgeInsets.only(
        left: leftPadding,
        right: rightPadding,
        top: topPadding,
        bottom: bottomPadding,
      ),
      decoration: decoration,
      child: content,
    );
  }

  /// Build box decoration for paragraph with shading and borders.
  BoxDecoration? _buildParagraphDecoration(DocxParagraph paragraph) {
    Color? backgroundColor;
    if (paragraph.shadingFill != null) {
      backgroundColor = _spanFactory.parseHexColor(paragraph.shadingFill!);
    }

    // Build borders from DocxBorderSide properties
    BorderSide? topBorder;
    BorderSide? bottomBorder;
    BorderSide? leftBorder;
    BorderSide? rightBorder;

    if (paragraph.borderTop != null) {
      topBorder = _buildBorderSide(paragraph.borderTop!);
    }

    // Choose the most specific bottom border available
    // Prioritize borderBottomSide (DocxBorderSide)
    final bottomSpec = paragraph.borderBottomSide ?? paragraph.borderBetween;

    if (bottomSpec != null) {
      bottomBorder = _buildBorderSide(bottomSpec);
    }

    if (paragraph.borderLeft != null) {
      leftBorder = _buildBorderSide(paragraph.borderLeft!);
    }
    if (paragraph.borderRight != null) {
      rightBorder = _buildBorderSide(paragraph.borderRight!);
    }

    final hasBorder = topBorder != null ||
        bottomBorder != null ||
        leftBorder != null ||
        rightBorder != null;

    if (backgroundColor == null && !hasBorder) {
      return null;
    }

    return BoxDecoration(
      color: backgroundColor,
      border: hasBorder
          ? Border(
              top: topBorder ?? BorderSide.none,
              bottom: bottomBorder ?? BorderSide.none,
              left: leftBorder ?? BorderSide.none,
              right: rightBorder ?? BorderSide.none,
            )
          : null,
    );
  }

  /// Convert DocxBorderSide to Flutter BorderSide.
  BorderSide _buildBorderSide(DocxBorderSide side) {
    if (side.style == DocxBorder.none) {
      return BorderSide.none;
    }

    // Convert size from eighths of a point to pixels
    final width = (side.size / 8.0).clamp(0.5, 10.0);
    final color = _spanFactory.resolveColor(
            side.color.hex, side.themeColor, side.themeTint, side.themeShade) ??
        Colors.black;

    return BorderSide(
      color: color,
      width: width,
      style: side.style == DocxBorder.dotted
          ? BorderStyle.none
          : BorderStyle.solid,
    );
  }

  /// Build TextSpans from inline elements.
  ///
  /// [firstLineIndentPx] prepends a zero-height spacer to simulate `w:firstLine`
  /// indent. [autoBackground] is the effective document shading behind these
  /// inlines (paragraph/cell fill), used to resolve an `auto` run colour; pass
  /// null when there is no local shading (the colour then follows the theme
  /// default). Threaded explicitly so no stale background can leak in.
  List<InlineSpan> buildInlineSpans(
    List<DocxInline> inlines, {
    double? lineHeight,
    List<SearchMatch>? matches,
    int startOffset = 0,
    double firstLineIndentPx = 0.0,
    Color? autoBackground,
  }) {
    final spans = <InlineSpan>[];

    if (firstLineIndentPx > 0) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: SizedBox(width: firstLineIndentPx, height: 0),
      ));
    }

    int currentOffset = startOffset;

    for (final inline in inlines) {
      if (inline is DocxText) {
        if (inline.hidden) continue; // w:vanish — not rendered or measured.
        spans.addAll(_buildTextSpan(
          inline,
          lineHeight: lineHeight,
          matches: matches,
          offset: currentOffset,
          autoBackground: autoBackground,
        ));
        currentOffset += inline.content.length;
      } else if (inline is DocxLineBreak) {
        spans.add(const TextSpan(text: '\n'));
        currentOffset += 1;
      } else if (inline is DocxTab) {
        // Better tab rendering - use 4 spaces worth of fixed width
        spans.add(const TextSpan(text: '    '));
        currentOffset += 4;
      } else if (inline is DocxCheckbox) {
        // Render checkbox as unicode character with styling
        spans.add(_buildCheckboxSpan(inline, lineHeight: lineHeight));
        currentOffset += 2;
      } else if (inline is DocxSymbol) {
        // Symbol-font glyph (`w:sym`): map to an equivalent Unicode char so it
        // renders even without the symbol font (Plan §K.5). Not part of the
        // search index, so the offset is left unchanged.
        spans.add(_buildSymbolSpan(inline, lineHeight: lineHeight));
      } else if (inline is DocxInlineImage) {
        // Inline images with proper vertical alignment. Route through the shared
        // ImageBuilder so crop/flip/rotation (§H.3) and the display-resolution
        // decode (RAM cap, §2.4 rule 2) apply here too, not only to block/layered
        // images; it carries its own broken-image fallback.
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _imageBuilder.buildInlineImage(inline),
        ));
      } else if (inline is DocxShape) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _buildInlineShape(inline),
        ));
      } else if (inline is DocxFootnoteRef) {
        spans.add(_buildFootnoteRef(inline));
      } else if (inline is DocxEndnoteRef) {
        spans.add(_buildEndnoteRef(inline));
      } else if (inline is DocxPageNumber) {
        // Pagination substitutes the live per-page value later (milestone C);
        // until then show Word's cached value so headers/footers aren't blank.
        final text = inline.cachedText ?? '1';
        spans.add(_buildFieldSpan(text, lineHeight));
        currentOffset += text.length;
      } else if (inline is DocxPageCount) {
        final text = inline.cachedText ?? '1';
        spans.add(_buildFieldSpan(text, lineHeight));
        currentOffset += text.length;
      } else if (inline is DocxPageRef) {
        final text = inline.cachedText ?? '';
        if (text.isNotEmpty) {
          spans.add(_buildFieldSpan(text, lineHeight));
          currentOffset += text.length;
        }
      } else if (inline is DocxStyleRef) {
        // Resolved live by FieldSubstitution during pagination; before that (or
        // in continuous mode) show Word's cached value so the running head is not
        // blank (Plan §K.3).
        final text = inline.cachedText ?? '';
        if (text.isNotEmpty) {
          spans.add(_buildFieldSpan(text, lineHeight));
          currentOffset += text.length;
        }
      } else if (inline is DocxUnknownField) {
        // A field the viewer doesn't compute (TOC, REF, …): show its cached
        // result so no text is lost.
        spans.addAll(buildInlineSpans(
          inline.cachedResult,
          lineHeight: lineHeight,
          matches: matches,
          startOffset: currentOffset,
          autoBackground: autoBackground,
        ));
        for (final c in inline.cachedResult) {
          if (c is DocxText) currentOffset += c.content.length;
        }
      } else if (inline is DocxBookmark) {
        // Zero-width anchor; nothing to render.
      }
    }

    return spans;
  }

  /// A span for a `w:sym` glyph (Plan §K.5). Delegates to the shared
  /// [SpanFactory.symbolSpan] so the rendered glyph is byte-identical to what the
  /// measurer laid out (measure ≡ render).
  InlineSpan _buildSymbolSpan(DocxSymbol sym, {double? lineHeight}) =>
      _spanFactory.symbolSpan(sym, lineHeight: lineHeight);

  /// A span for an automatic field value (page number etc.) in the default
  /// body style. Styling fidelity to the field's own run is deferred.
  InlineSpan _buildFieldSpan(String text, double? lineHeight) {
    if (text.isEmpty) return const TextSpan(text: '');
    return TextSpan(
      text: text,
      style: lineHeight != null
          ? theme.defaultTextStyle.copyWith(height: lineHeight)
          : theme.defaultTextStyle,
    );
  }

  // ... (keep checkbox span same) ...

  /// Build a TextSpan for a DocxCheckbox.
  TextSpan _buildCheckboxSpan(DocxCheckbox checkbox, {double? lineHeight}) {
    final content = checkbox.isChecked ? '☒ ' : '☐ ';

    FontWeight fontWeight = checkbox.fontWeight == DocxFontWeight.bold
        ? FontWeight.bold
        : FontWeight.normal;

    FontStyle fontStyle = checkbox.fontStyle == DocxFontStyle.italic
        ? FontStyle.italic
        : FontStyle.normal;

    Color? textColor;
    if (checkbox.color != null) {
      textColor = _spanFactory.parseHexColor(checkbox.color!.hex);
    }

    return TextSpan(
      text: content,
      style: TextStyle(
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: textColor ?? theme.defaultTextStyle.color,
        fontSize: checkbox.fontSize ?? theme.defaultTextStyle.fontSize,
        height: lineHeight ?? theme.defaultTextStyle.height,
      ),
    );
  }

  /// Build the spans for a [DocxText] element. Returns a list because one run is
  /// split into multiple spans — by script (Hebrew/Latin, Plan §L.1) and again
  /// by search-match boundaries.
  List<InlineSpan> _buildTextSpan(
    DocxText text, {
    double? lineHeight,
    List<SearchMatch>? matches,
    int offset = 0,
    Color? autoBackground,
  }) {
    // Script-split run segments come from the shared [SpanFactory] so the
    // measurer (Part C/L) builds byte-identical geometry. Link colour, search
    // highlight and text-border are layered on below — all geometry-neutral.
    final segments =
        _spanFactory.resolveRunSegments(text, lineHeight: lineHeight);
    if (segments.isEmpty) return const [];

    // `auto` run colour (`w:color w:val="auto"`): resolve to black/white against
    // the *local document* shading behind this run — its own `w:shd`, else the
    // paragraph/cell fill ([autoBackground]). Only a real local fill triggers
    // this (item 15); with no local shd the colour is left to the existing
    // theme/dark-mode default (so dark reading mode keeps white70). Render-only
    // — colour never affects metrics.
    Color? autoColor;
    if (SpanFactory.isAutoColor(text.color)) {
      Color? runBg;
      if (text.shadingFill != null || text.themeFill != null) {
        runBg = _spanFactory.resolveColor(text.shadingFill, text.themeFill,
            text.themeFillTint, text.themeFillShade);
      }
      final localBg = runBg ?? autoBackground;
      if (localBg != null) {
        autoColor = _spanFactory.resolveAutoTextColor(localBg);
      }
    }

    // Tap handler (one per run; applies to every segment).
    TapGestureRecognizer? tapRecognizer;
    Color? linkColor;
    TextDecoration? linkDecoration;
    if (text.href != null && text.href!.isNotEmpty) {
      linkColor = theme.linkStyle.color;
      linkDecoration = TextDecoration.underline;
      final href = text.href!;
      tapRecognizer = TapGestureRecognizer()..onTap = () => _onLinkTap(href);
    }

    // Text border boxes the whole run as an atomic [WidgetSpan] `Container`
    // (item 37). The box geometry (horizontal `w:space` padding + border width)
    // comes from the shared [SpanFactory.textBorderBox] so the measurer reserves
    // the identical size (measure ≡ render). Rendered on the search path too —
    // the highlight is threaded into the boxed child via [_overlaySegment]
    // instead of dropping the border. Single-line (`maxLines: 1`) to match the
    // measured intrinsic width; a bordered run wider than the line is a
    // documented deviation. Mixed-script bordered text keeps its per-script
    // styles via the rich child.
    final box = _spanFactory.textBorderBox(text.textBorder);
    if (box != null) {
      final side = _buildBorderSide(text.textBorder!);
      if (side != BorderSide.none) {
        final childSpans = <InlineSpan>[];
        for (final s in segments) {
          childSpans.addAll(_overlaySegment(
            s.text,
            autoColor != null ? s.style.copyWith(color: autoColor) : s.style,
            offset + s.start,
            matches,
            tapRecognizer,
            linkColor,
            linkDecoration,
          ));
        }
        return [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: box.padH, vertical: 0),
              decoration: BoxDecoration(
                border: Border.all(
                    color: side.color, width: side.width, style: side.style),
                color: segments.first.style.backgroundColor,
              ),
              child: Text.rich(
                TextSpan(children: childSpans),
                softWrap: false,
                maxLines: 1,
              ),
            ),
          )
        ];
      }
    }

    final out = <InlineSpan>[];
    for (final s in segments) {
      out.addAll(_overlaySegment(
        s.text,
        autoColor != null ? s.style.copyWith(color: autoColor) : s.style,
        offset + s.start,
        matches,
        tapRecognizer,
        linkColor,
        linkDecoration,
      ));
    }
    return out;
  }

  /// Lays the link colour/decoration and search-match highlighting over one
  /// script segment's [content] (whose first character is at painter-text offset
  /// [globalStart]). Geometry is untouched — colour and the underline are the
  /// only overlays — so this stays byte-identical to what the measurer laid out.
  List<InlineSpan> _overlaySegment(
    String content,
    TextStyle segStyle,
    int globalStart,
    List<SearchMatch>? matches,
    TapGestureRecognizer? tapRecognizer,
    Color? linkColor,
    TextDecoration? linkDecoration,
  ) {
    final base = segStyle.copyWith(
      color: linkColor ?? segStyle.color,
      decoration: linkDecoration ?? segStyle.decoration,
    );

    if (matches == null || matches.isEmpty) {
      return [TextSpan(text: content, style: base, recognizer: tapRecognizer)];
    }

    final result = <InlineSpan>[];
    final textLength = content.length;
    final globalEnd = globalStart + textLength;

    final relevant = matches
        .where((m) => m.endOffset > globalStart && m.startOffset < globalEnd)
        .toList()
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    var cursor = 0;
    for (final match in relevant) {
      var ms = match.startOffset - globalStart;
      var me = match.endOffset - globalStart;
      if (ms < 0) ms = 0;
      if (me > textLength) me = textLength;

      if (ms > cursor) {
        result.add(TextSpan(
          text: content.substring(cursor, ms),
          style: base,
          recognizer: tapRecognizer,
        ));
      }
      if (me > ms) {
        var isCurrent = false;
        if (searchController != null) {
          final i = searchController!.currentMatchIndex;
          if (i >= 0 && i < searchController!.matches.length) {
            isCurrent = match == searchController!.matches[i];
          }
        }
        result.add(TextSpan(
          text: content.substring(ms, me),
          style: base.copyWith(
            backgroundColor:
                isCurrent ? Colors.orange.shade300 : Colors.yellow.shade200,
          ),
          recognizer: tapRecognizer,
        ));
      }
      cursor = me;
    }

    if (cursor < textLength) {
      result.add(TextSpan(
        text: content.substring(cursor),
        style: base,
        recognizer: tapRecognizer,
      ));
    }
    return result;
  }

  /// Resolves the TextStyle line-height scale via the shared [SpanFactory], so
  /// the measurer and renderer agree (Plan §C.2).
  double? _resolveLineHeightScale(DocxParagraph paragraph) =>
      _spanFactory.resolveLineHeightScale(paragraph);

  /// Build a widget for a paragraph with a drop cap.
  Widget buildDropCap(DocxDropCap dropCap) {
    // Drop-cap content sits on the page background (no local shd threaded), so
    // an `auto` colour follows the theme default.
    const pointToPx = 1.333;
    final defaultFontSize = theme.defaultTextStyle.fontSize ?? 14.0;

    double fontSizePx;
    if (dropCap.fontSize != null) {
      fontSizePx = dropCap.fontSize! * pointToPx;
    } else {
      fontSizePx = dropCap.lines * defaultFontSize * 1.2;
    }

    final color = theme.defaultTextStyle.color ?? Colors.black;
    final fontFamily = dropCap.fontFamily ?? theme.defaultTextStyle.fontFamily;

    final dropCapStyle = TextStyle(
        fontSize: fontSizePx,
        color: color,
        fontFamily: fontFamily,
        height: 1.0,
        fontWeight: FontWeight.bold);

    final painter = TextPainter(
      text: TextSpan(text: dropCap.letter, style: dropCapStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final dcWidth = painter.width;
    final dcHeight = painter.height;

    // Use theme defaults for the body text of the drop cap paragraph
    final bodyStyle = TextStyle(
      fontSize: defaultFontSize,
      color: theme.defaultTextStyle.color,
      fontFamily: theme.defaultTextStyle.fontFamily,
      height: theme.defaultTextStyle.height,
    );

    final spans = buildInlineSpans(dropCap.restOfParagraph);
    final fullTextSpan = TextSpan(children: spans, style: bodyStyle);

    String restPlainText = '';
    for (final inline in dropCap.restOfParagraph) {
      if (inline is DocxText) {
        restPlainText += inline.content;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: DropCapText(
        restPlainText, // Only the rest of paragraph text, matching textSpan
        textSpan: fullTextSpan,
        dropCap: DropCap(
          width: dcWidth,
          height: dcHeight,
          child: Text(dropCap.letter, style: dropCapStyle),
        ),
        mode: DropCapMode.inside,
        forceNoDescent: true,
        dropCapLines: dropCap.lines,
        // hSpace is in twips; convert at 96 DPI (twips/15) for consistency.
        dropCapPadding:
            EdgeInsets.only(right: (dropCap.hSpace / 15.0).clamp(4.0, 20.0)),
      ),
    );
  }

  TextSpan _buildFootnoteRef(DocxFootnoteRef ref) {
    return TextSpan(
      text: footnoteLabels[ref.footnoteId] ?? '${ref.footnoteId}',
      style: TextStyle(
        fontSize: (theme.defaultTextStyle.fontSize ?? 14) * 0.6,
        color: theme.linkStyle.color,
        fontFeatures: const [FontFeature.superscripts()],
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          onFootnoteTap?.call(ref.footnoteId);
        },
    );
  }

  TextSpan _buildEndnoteRef(DocxEndnoteRef ref) {
    return TextSpan(
      text: endnoteLabels[ref.endnoteId] ?? '${ref.endnoteId}',
      style: TextStyle(
        fontSize: (theme.defaultTextStyle.fontSize ?? 14) * 0.6,
        color: theme.linkStyle.color,
        fontFeatures: const [FontFeature.superscripts()],
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          onEndnoteTap?.call(ref.endnoteId);
        },
    );
  }

  Widget _buildInlineShape(DocxShape shape) {
    // Delegate to the shared ShapeBuilder when wired (preset geometry + text-box
    // block content); otherwise a plain fill/outline box as a safe fallback.
    final sb = shapeBuilder;
    if (sb != null) return sb.buildInlineShape(shape);
    return Container(
      width: shape.width,
      height: shape.height,
      decoration: BoxDecoration(
        color: _spanFactory.resolveColor(
            shape.fillColor?.hex,
            shape.fillColor?.themeColor,
            shape.fillColor?.themeTint,
            shape.fillColor?.themeShade),
        border: shape.outlineColor != null
            ? Border.all(
                color: _spanFactory.resolveColor(
                        shape.outlineColor!.hex,
                        shape.outlineColor!.themeColor,
                        shape.outlineColor!.themeTint,
                        shape.outlineColor!.themeShade) ??
                    Colors.black,
                width: shape.outlineWidth)
            : null,
      ),
    );
  }

  /// Routes a tapped hyperlink (Plan §K.2): an internal `#bookmark` anchor goes
  /// to [onInternalLink] (the viewer scrolls to that bookmark's page); an
  /// external url goes to [onExternalLink], or falls back to `url_launcher`.
  void _onLinkTap(String href) {
    if (href.startsWith('#') && href.length > 1) {
      onInternalLink?.call(href.substring(1));
      return;
    }
    if (onExternalLink != null) {
      onExternalLink!(href);
    } else {
      _launchUrl(href);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
