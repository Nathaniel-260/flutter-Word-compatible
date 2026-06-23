import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';
import '../font_loader/font_metrics_registry.dart';
import '../font_loader/font_resolver.dart';
import '../theme/docx_view_theme.dart';
import 'float_layout.dart';
import 'symbol_map.dart';

/// The canonical paragraph [InlineSpan] plus the [PlaceholderDimensions] for
/// any [WidgetSpan]s it contains, in span order.
///
/// A [TextPainter] cannot lay out a span tree with placeholders until it is
/// told their sizes via [TextPainter.setPlaceholderDimensions]; bundling the
/// span with its placeholder list lets the measurer feed them in one call.
class MeasurementSpans {
  const MeasurementSpans(this.root, this.placeholders, this.segments);

  /// Root span (style = the body default; children fully specify geometry).
  final InlineSpan root;

  /// Placeholder dimensions for the [WidgetSpan]s in [root], in order.
  final List<PlaceholderDimensions> placeholders;

  /// Maps character ranges of the laid-out text (the painter's offset space,
  /// including placeholder/`U+FFFC` chars) back to the source inline that
  /// produced them, in order. The paginator uses this to turn a line-boundary
  /// character offset into a paragraph split point (Plan §D.4 / §6.4).
  final List<SpanSegment> segments;
}

/// One contiguous run of characters in a measured paragraph's text, attributed
/// to the [inline] (an original child of the paragraph) that produced it.
///
/// [inline] is null for synthetic, non-child content such as the first-line
/// indent placeholder. [atomic] runs (images, tabs, fields, breaks) are never
/// split through their interior — the slicer keeps or drops them whole.
class SpanSegment {
  const SpanSegment({
    required this.start,
    required this.length,
    required this.inline,
    required this.atomic,
  });

  /// Start offset in the painter's text space.
  final int start;

  /// Number of characters this run contributes (placeholders count as 1).
  final int length;

  /// The source inline, or null for synthetic content (first-line indent).
  final DocxInline? inline;

  /// True when the run cannot be split through its middle (only [DocxText] is
  /// splittable).
  final bool atomic;

  int get end => start + length;
}

/// One script-homogeneous slice of a [DocxText] run, already resolved to its
/// final [TextStyle] (Plan §L.1). A run mixing Latin and Hebrew/Arabic is cut
/// into several of these so each is laid out with the script's own font
/// (`w:ascii` vs `w:cs`), size (`w:sz` vs `w:szCs`) and bold/italic. [start] and
/// [end] are offsets into the run's resolved content (post caps-transform); the
/// slices tile the content exactly, so a single-script run yields one segment
/// identical to the pre-Part-L span.
class RunSegment {
  const RunSegment(this.text, this.style, this.start, this.end);

  final String text;
  final TextStyle style;
  final int start;
  final int end;
}

/// Single source of truth for turning a [DocxText] run into a Flutter
/// [TextStyle] and an [InlineSpan] (Plan §C.1).
///
/// Both the renderer ([ParagraphBuilder]) and the measurer ([TextMeasurer])
/// build spans through this class so that **what is measured is exactly what is
/// painted** — any divergence would make pagination lie. The renderer layers
/// purely visual, geometry-neutral effects (search highlight background, link
/// recogniser, hyperlink colour) on top of [resolveRunStyle]; those never
/// change line breaking or height, so measurement parity is preserved.
class SpanFactory {
  SpanFactory({
    required this.theme,
    required this.config,
    this.docxTheme,
  });

  final DocxViewTheme theme;
  final DocxViewConfig config;
  final DocxTheme? docxTheme;

  /// Resolves Word font names to available families and per-script fallback
  /// chains (Plan §L.2/§L.3). Built once from the config; the availability check
  /// reads the process-wide embedded/system font registries.
  late final FontResolver _fontResolver = FontResolver(
    substitutions: config.fontSubstitutions,
    extraFallbacks: config.customFontFallbacks,
  );

  /// Resolves the [TextStyle.height] multiplier for `auto` line spacing
  /// (`lineSpacing / 240`, where 240 twips = one single line). For
  /// `exact`/`atLeast` this returns null — those are handled by [resolveStrut],
  /// which forces a per-line box the way Word does. Shared by the renderer and
  /// the measurer so both lay lines out identically (Plan §C.2).
  double? resolveLineHeightScale(DocxParagraph paragraph) {
    if (paragraph.lineSpacing == null) return null;
    switch (paragraph.lineRule ?? 'auto') {
      case 'exact':
      case 'atLeast':
        return null; // see resolveStrut
      default:
        return paragraph.lineSpacing! / 240.0;
    }
  }

  /// The paragraph's nominal single-line height in px, used to convert line-unit
  /// spacing (`w:beforeLines`/`w:afterLines`, hundredths of a line) to pixels.
  /// Shared by the renderer and the measurer so a line-unit spacing produces an
  /// identical footprint in both (measure ≡ render).
  ///
  /// For `exact`/`atLeast` line spacing the line is the absolute strut height
  /// ([resolveStrut]'s `lineSpacing/15`). Otherwise it is the effective font size
  /// (first run — a complex/Hebrew run reads `szCs` first, like [resolveRunStyle];
  /// else the theme default) × the `auto` line-height scale (`lineSpacing/240`,
  /// default 1.0). This nominal ignores the font's intrinsic leading and any
  /// super/subscript shrink — a small, documented approximation for a rare
  /// feature (02-units.md ב.2).
  double resolveSingleLineHeightPx(DocxParagraph paragraph) {
    final rule = paragraph.lineRule ?? 'auto';
    if ((rule == 'exact' || rule == 'atLeast') &&
        paragraph.lineSpacing != null) {
      return (paragraph.lineSpacing! / 15.0).clamp(1.0, 2000.0);
    }
    double? fontPt;
    for (final c in paragraph.children) {
      if (c is DocxText) {
        fontPt = c.fontSizeCs ?? c.fontSize;
        break;
      }
    }
    final fontPx =
        (fontPt != null ? fontPt * 1.333 : theme.defaultTextStyle.fontSize) ??
            16.0;
    final scale = resolveLineHeightScale(paragraph) ?? 1.0;
    return fontPx * scale;
  }

  /// Converts a line-unit spacing value (hundredths of a line) to px for
  /// [paragraph], or null when [hundredthsOfLine] is null. Centralised so the
  /// renderer and measurer agree.
  double? lineUnitSpacingPx(DocxParagraph paragraph, int? hundredthsOfLine) =>
      hundredthsOfLine == null
          ? null
          : hundredthsOfLine / 100.0 * resolveSingleLineHeightPx(paragraph);

  /// Resolves the paragraph [StrutStyle] for `exact`/`atLeast` line spacing
  /// (Plan §C.2). `exact` forces every line to the given height
  /// ([StrutStyle.forceStrutHeight]); `atLeast` makes it a minimum (the line
  /// grows for taller content). `auto`/unset → null (the height multiplier from
  /// [resolveLineHeightScale] is used instead).
  ///
  /// `lineSpacing` is an absolute height in twips here; twips→px at 96 DPI is
  /// `/15` (240tw = 16px), consistent with [DocxUnits].
  StrutStyle? resolveStrut(DocxParagraph paragraph) {
    if (paragraph.lineSpacing == null) return null;
    final rule = paragraph.lineRule ?? 'auto';
    if (rule != 'exact' && rule != 'atLeast') return null;
    final linePx = (paragraph.lineSpacing! / 15.0).clamp(1.0, 2000.0);
    return StrutStyle(
      fontSize: linePx,
      height: 1.0,
      forceStrutHeight: rule == 'exact',
    );
  }

  /// Applies Word's caps transform to a run's text. `allCaps` uppercases the
  /// glyphs (visual only — the source string is preserved for search/copy).
  /// `smallCaps` is *not* an uppercase transform: it is rendered with the
  /// OpenType `smcp` feature in [resolveRunStyle], which turns only lowercase
  /// letters into small capitals while leaving real uppercase at full height —
  /// exactly Word's behaviour, and a fidelity fix over the former
  /// uppercase-everything-then-shrink approximation (03-run-rpr.md item 13).
  String resolveContent(DocxText text) {
    if (text.isAllCaps) {
      return text.content.toUpperCase();
    }
    return text.content;
  }

  /// Resolves the geometry-and-visual base [TextStyle] for a [DocxText] run.
  ///
  /// This is the *only* place run formatting becomes a [TextStyle]; the result
  /// is shared by measurement and rendering. [lineHeight] is the paragraph's
  /// resolved line-height scale (`TextStyle.height`), or null for the theme
  /// default.
  ///
  /// [script] selects which of the run's per-script properties apply (Plan
  /// §L.1): a complex-script segment uses the `w:cs` font, `w:szCs` size and
  /// `w:bCs`/`w:iCs` bold/italic (each falling back to the Latin property when
  /// the complex one is unset, matching documents that only set `w:b`/`w:sz`),
  /// while a Latin segment uses the `w:ascii`/`w:hAnsi` font, `w:sz` and
  /// `w:b`/`w:i`. For a single-script run this is identical to the pre-Part-L
  /// style.
  TextStyle resolveRunStyle(
    DocxText text, {
    double? lineHeight,
    DocxScript script = DocxScript.latin,
  }) {
    final isComplex = script == DocxScript.complex;

    final bool boldEffective =
        isComplex ? (text.boldCs ?? text.isBold) : text.isBold;
    final fontWeight = boldEffective ? FontWeight.bold : FontWeight.normal;

    final bool italicEffective =
        isComplex ? (text.italicCs ?? text.isItalic) : text.isItalic;
    final fontStyle = italicEffective ? FontStyle.italic : FontStyle.normal;

    // Decorations (underline pattern + strike). Flutter shares a single
    // decorationStyle/colour/thickness across all decorations on a span, so the
    // underline pattern wins over the double-strike style when both are present.
    TextDecoration decoration = TextDecoration.none;
    final decorations = <TextDecoration>[];
    TextDecorationStyle decorationStyle = TextDecorationStyle.solid;
    double? decorationThickness;
    Color? decorationColor;

    final uStyle = text.effectiveUnderlineStyle;
    if (uStyle != null && uStyle != DocxUnderlineStyle.none) {
      decorations.add(TextDecoration.underline);
      final mapped = mapUnderline(uStyle);
      decorationStyle = mapped.$1;
      decorationThickness = mapped.$2;
      if (text.underlineColor != null) {
        decorationColor = resolveColor(
          text.underlineColor!.hex,
          text.underlineColor!.themeColor,
          text.underlineColor!.themeTint,
          text.underlineColor!.themeShade,
        );
      }
    }

    if (text.isStrike || text.isDoubleStrike) {
      decorations.add(TextDecoration.lineThrough);
      if (text.isDoubleStrike) {
        // Flutter shares a single decorationStyle across all of a span's
        // decorations, so a run with both `w:dstrike` and an underline cannot be
        // single-underline + double-strike. Chosen compromise (03-run-rpr.md
        // item 15): the double wins — the strike keeps its doubling (the
        // author's intent), even though a coexisting underline then also renders
        // double. Paint-only → measure ≡ render is untouched.
        decorationStyle = TextDecorationStyle.double;
      }
    }

    if (decorations.isNotEmpty) {
      decoration = TextDecoration.combine(decorations);
    }

    Color? textColor;
    if (text.color != null) {
      textColor = resolveColor(
        text.color!.hex,
        text.themeColor ?? text.color!.themeColor,
        text.themeTint ?? text.color!.themeTint,
        text.themeShade ?? text.color!.themeShade,
      );
    }

    Color? backgroundColor;
    if (text.shadingFill != null || text.themeFill != null) {
      backgroundColor = resolveColor(
        text.shadingFill,
        text.themeFill,
        text.themeFillTint,
        text.themeFillShade,
      );
    }
    if (backgroundColor == null && text.highlight != DocxHighlight.none) {
      backgroundColor = highlightToColor(text.highlight);
    }

    final double? rawPt =
        isComplex ? (text.fontSizeCs ?? text.fontSize) : text.fontSize;
    double? fontSize =
        rawPt != null ? rawPt * 1.333 : theme.defaultTextStyle.fontSize;

    // Per-script requested family (Plan §L.1): a complex segment reads the
    // `w:cs`/`w:csTheme` slot, a Latin segment the `w:ascii`/`w:hAnsi` slots.
    // Each falls back to the run's other font slots and the legacy `fontFamily`
    // so text is never left without a family.
    String? requested;
    if (isComplex) {
      if (docxTheme != null && text.fonts?.csTheme != null) {
        requested = docxTheme!.fonts.getFont(text.fonts!.csTheme!);
      }
      requested ??= text.fonts?.cs;
      requested ??= text.fonts?.ascii ?? text.fonts?.hAnsi;
    } else {
      if (docxTheme != null) {
        final themeFontName = text.fonts?.asciiTheme ??
            text.fonts?.hAnsiTheme ??
            text.fonts?.eastAsiaTheme;
        if (themeFontName != null) {
          requested = docxTheme!.fonts.getFont(themeFontName);
        }
      }
      requested ??=
          text.fonts?.ascii ?? text.fonts?.hAnsi ?? text.fonts?.family;
    }
    requested ??= text.fontFamily;

    // Map the requested name to a family Flutter can render (embedded / system /
    // metric clone), then attach the per-script fallback chain so a stray glyph
    // degrades gracefully instead of dropping to a tofu box (§L.2/§L.3).
    String? fontFamily = _fontResolver.resolve(requested);
    final fontFamilyFallback = _fontResolver.fallbacksFor(script);
    if (fontFamily == null) {
      if (fontFamilyFallback.isNotEmpty) {
        fontFamily = fontFamilyFallback.first;
      } else if (config.customFontFallbacks.isNotEmpty) {
        fontFamily = config.customFontFallbacks.first;
      }
    }

    if (text.isSuperscript || text.isSubscript) {
      fontSize = (fontSize ?? 14) * 0.7;
    }

    List<Shadow>? shadows;
    if (text.isShadow) {
      shadows = [
        Shadow(
          color: Colors.black.withValues(alpha: 0.3),
          offset: const Offset(1, 1),
          blurRadius: 2,
        ),
      ];
    } else if (text.isEmboss) {
      shadows = [
        Shadow(
          color: Colors.white.withValues(alpha: 0.7),
          offset: const Offset(-1, -1),
          blurRadius: 1,
        ),
        Shadow(
          color: Colors.black.withValues(alpha: 0.3),
          offset: const Offset(1, 1),
          blurRadius: 1,
        ),
      ];
    } else if (text.isImprint) {
      shadows = [
        Shadow(
          color: Colors.black.withValues(alpha: 0.3),
          offset: const Offset(-1, -1),
          blurRadius: 1,
        ),
        Shadow(
          color: Colors.white.withValues(alpha: 0.5),
          offset: const Offset(1, 1),
          blurRadius: 1,
        ),
      ];
    }

    Paint? foreground;
    if (text.isOutline) {
      foreground = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = textColor ?? Colors.black;
      textColor = null;
    }

    // Kerning (`w:kern`): Word enables pair kerning at/above the given size.
    // Flutter's 'kern' feature is usually on by default; enabling it explicitly
    // when requested keeps measurement and rendering identical. Sub/superscript
    // already claim fontFeatures, so only set kern when they don't.
    final wantsKern = text.kernMinHalfPoints != null &&
        text.kernMinHalfPoints! > 0 &&
        (fontSize ?? 0) >= (text.kernMinHalfPoints! / 2.0 * 96.0 / 72.0);

    // Build the feature list additively so small-caps can coexist with kerning.
    // Sub/superscript claim the vertical-variant slot, so smcp/kern are not
    // combined with them (matching the pre-existing behaviour).
    final bool variantClaimed = text.isSuperscript || text.isSubscript;
    final features = <FontFeature>[];
    if (text.isSuperscript) features.add(const FontFeature.superscripts());
    if (text.isSubscript) features.add(const FontFeature.subscripts());
    // smallCaps (`w:smallCaps`): real OpenType small caps — lowercase → small
    // capitals, real uppercase stays full height (Word's behaviour). Falls back
    // gracefully to plain lowercase for a font without an `smcp` table (rare;
    // the common Word/clone fonts ship it). `caps` already uppercased, so smcp
    // is a no-op there and is skipped (03-run-rpr.md item 13).
    if (text.isSmallCaps && !text.isAllCaps && !variantClaimed) {
      features.add(const FontFeature.enable('smcp'));
    }
    if (wantsKern && !variantClaimed) {
      features.add(const FontFeature.enable('kern'));
    }
    final List<FontFeature>? fontFeatures = features.isEmpty ? null : features;

    return TextStyle(
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
      decorationStyle: decorationStyle,
      decorationColor: decorationColor,
      decorationThickness: decorationThickness,
      color: foreground == null
          ? (textColor ?? theme.defaultTextStyle.color)
          : null,
      foreground: foreground,
      backgroundColor: backgroundColor,
      // characterSpacing (`w:spacing`/letterSpacing) is in twips; convert at
      // 96 DPI (twips/15) to stay consistent with [DocxUnits].
      letterSpacing:
          text.characterSpacing != null ? text.characterSpacing! / 15.0 : null,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      // Single spacing → the run font's own line-height ratio (what Word uses),
      // so density matches Word per-font instead of a fixed multiplier. Explicit
      // multiples (1.5/double) keep their value; unknown fonts fall back to the
      // theme default. See [FontMetricsRegistry].
      height: lineHeight ??
          FontMetricsRegistry.lineHeightFor(fontFamily) ??
          theme.defaultTextStyle.height,
      shadows: shadows,
      fontFeatures: fontFeatures,
    );
  }

  /// Splits a [DocxText] run's resolved content into script-homogeneous
  /// [RunSegment]s, each with its own resolved [TextStyle] (Plan §L.1). A
  /// run mixing Hebrew/Arabic and Latin is cut so each script is laid out with
  /// the correct font/size/weight (what Word does); a single-script run returns
  /// exactly one segment, byte-identical to the pre-Part-L single span. Used by
  /// both the measurer and the renderer so measure ≡ render.
  ///
  /// An empty run returns an empty list (it contributes no glyphs).
  List<RunSegment> resolveRunSegments(DocxText text, {double? lineHeight}) {
    final content = resolveContent(text);
    if (content.isEmpty) return const [];

    // Force otherwise-neutral characters (digits/punctuation) into the complex
    // script when the run explicitly asks for complex/RTL handling — `w:hint=cs`
    // on the fonts, an explicit `w:rtl`, or the `w:cs` flag. For genuine Hebrew
    // text the classification is already complex (no change); this only affects
    // a neutral/digit run that Word forces RTL/CS via the flag (03-run-rpr.md
    // items 39, 40). Strong Latin in the run still stays Latin.
    final forceComplex = text.fonts?.hint == 'cs' ||
        text.rtl == true ||
        text.complexScript == true;
    final runs = classifyScript(content, hintComplex: forceComplex);
    // Common case: one script → one style. Avoids per-segment substring/style
    // work for the bulk of (single-script) runs.
    final List<RunSegment> base;
    if (runs.length == 1) {
      base = [
        RunSegment(
          content,
          resolveRunStyle(text,
              lineHeight: lineHeight, script: runs.first.script),
          0,
          content.length,
        ),
      ];
    } else {
      base = [
        for (final r in runs)
          RunSegment(
            content.substring(r.start, r.end),
            resolveRunStyle(text, lineHeight: lineHeight, script: r.script),
            r.start,
            r.end,
          ),
      ];
    }

    // `w:u w:val="words"`: the underline runs under word characters only, not
    // the spaces between them (Word). Re-split each segment at whitespace and
    // drop the underline (only) from the whitespace pieces; any strike stays
    // continuous. This changes only the paint-time decoration per sub-span, not
    // glyph advances/height, and the sub-segments tile the content exactly — so
    // the painter text, line breaking, pagination split offsets and search
    // ranges are all unchanged (measure ≡ render). 03-run-rpr.md item 29.
    if (text.effectiveUnderlineStyle == DocxUnderlineStyle.words) {
      return _splitWordsUnderline(base);
    }
    return base;
  }

  /// True for a character the `words` underline does not draw under — the word
  /// separators (ASCII space and tab). Other whitespace is treated as a word
  /// character (a negligible, documented edge).
  static bool _isWordsUnderlineGap(int c) => c == 0x20 || c == 0x09;

  /// Re-splits [base] segments at whitespace for a `words` underline, returning
  /// the whitespace pieces with the underline stripped (strike/overline kept).
  /// The pieces tile each segment exactly, preserving offsets.
  List<RunSegment> _splitWordsUnderline(List<RunSegment> base) {
    final out = <RunSegment>[];
    for (final s in base) {
      final stripped = _styleWithoutUnderline(s.style);
      if (identical(stripped, s.style)) {
        out.add(s); // no underline on this segment — nothing to carve out
        continue;
      }
      final text = s.text;
      var i = 0;
      while (i < text.length) {
        final gap = _isWordsUnderlineGap(text.codeUnitAt(i));
        var j = i + 1;
        while (j < text.length &&
            _isWordsUnderlineGap(text.codeUnitAt(j)) == gap) {
          j++;
        }
        out.add(RunSegment(
          text.substring(i, j),
          gap ? stripped : s.style,
          s.start + i,
          s.start + j,
        ));
        i = j;
      }
    }
    return out;
  }

  /// Returns [style] with [TextDecoration.underline] removed (keeping any
  /// line-through/overline), or the same instance when there is no underline.
  TextStyle _styleWithoutUnderline(TextStyle style) {
    final d = style.decoration;
    if (d == null || !d.contains(TextDecoration.underline)) return style;
    final kept = <TextDecoration>[
      if (d.contains(TextDecoration.lineThrough)) TextDecoration.lineThrough,
      if (d.contains(TextDecoration.overline)) TextDecoration.overline,
    ];
    return style.copyWith(
      decoration:
          kept.isEmpty ? TextDecoration.none : TextDecoration.combine(kept),
    );
  }

  /// Builds the canonical span tree + placeholder dims for a paragraph's
  /// inline content, used by the measurer (Plan §C.2). This mirrors the
  /// renderer's [InlineSpan] structure for the common (no search, no float)
  /// path so that measured height equals rendered height.
  ///
  /// TODO(plan §C.1): only [resolveRunStyle]/[resolveContent] (the [DocxText]
  /// path) are truly shared with the renderer. The structural mapping of every
  /// other inline (tab, checkbox, image, note ref, page field, line break) is
  /// re-implemented both here and in `ParagraphBuilder.buildInlineSpans`; a
  /// future edit to one can silently drift the other. Unify the inline→span
  /// switch so the renderer layers recognizers/highlights on top of it.
  ///
  /// [skipHidden] drops `w:vanish` runs (neither measured nor painted); the
  /// measurer passes `true`. The renderer's `buildInlineSpans` and the search
  /// index (`_extractFromInlines`) skip hidden runs independently, so search
  /// offsets stay aligned.
  /// [firstLineIndentPx] prepends a zero-height spacer to model `w:firstLine`.
  MeasurementSpans buildMeasurementSpans(
    List<DocxInline> inlines, {
    double? lineHeight,
    double firstLineIndentPx = 0.0,
    bool skipHidden = false,
  }) {
    final spans = <InlineSpan>[];
    final placeholders = <PlaceholderDimensions>[];
    final segments = <SpanSegment>[];
    var cursor = 0;

    // Records the contribution of an inline to the painter's text space so the
    // paginator can map a line-boundary offset back to a child (Plan §D.4).
    void seg(int len, DocxInline? inline, {bool atomic = true}) {
      if (len <= 0) return;
      segments.add(SpanSegment(
        start: cursor,
        length: len,
        inline: inline,
        atomic: atomic,
      ));
      cursor += len;
    }

    // Records a zero-width anchor (e.g. a bookmark) at the current offset so a
    // paragraph split keeps it on the correct side (PAGEREF correctness, §D.4).
    void anchorSeg(DocxInline inline) {
      segments.add(SpanSegment(
        start: cursor,
        length: 0,
        inline: inline,
        atomic: true,
      ));
    }

    if (firstLineIndentPx > 0) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: SizedBox(width: firstLineIndentPx, height: 0),
      ));
      placeholders.add(PlaceholderDimensions(
        size: Size(firstLineIndentPx, 0),
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
      ));
      seg(1, null); // the placeholder counts as one U+FFFC in the painter text
    }

    void addImage(double w, double h, DocxInline inline) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SizedBox(width: w, height: h),
      ));
      placeholders.add(PlaceholderDimensions(
        size: Size(w, h),
        alignment: PlaceholderAlignment.middle,
      ));
      seg(1, inline);
    }

    for (final inline in inlines) {
      if (inline is DocxText) {
        if (skipHidden && inline.hidden) continue; // w:vanish.
        // Script-split into per-script spans (Plan §L.1); the slices tile the
        // resolved content exactly, so the painter text — and therefore the
        // split-point mapping below — is unchanged from a single span.
        final segs = resolveRunSegments(inline, lineHeight: lineHeight);
        final box = textBorderBox(inline.textBorder);
        if (box != null && segs.isNotEmpty) {
          // Bordered run (`w:bdr`, item 37): the renderer boxes it as a
          // [WidgetSpan] `Container`, so it is an *atomic* inline box, not
          // flowing text. Model the same box here: measure the run's single-line
          // intrinsic text size and add padding + border on both axes, matching
          // the rendered `Container` exactly so measure ≡ render. A bordered run
          // is a short boxed word/phrase; one wider than the line is a
          // documented deviation (it stays single-line here).
          final tp = TextPainter(
            text: TextSpan(
              children: [for (final s in segs) TextSpan(text: s.text, style: s.style)],
            ),
            textDirection: TextDirection.ltr, // width is direction-independent
            textScaler: TextScaler.noScaling,
            maxLines: 1,
          )..layout();
          final w = tp.width + 2 * box.padH + 2 * box.borderWidth;
          final h = tp.height + 2 * box.borderWidth;
          tp.dispose();
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(width: w, height: h),
          ));
          placeholders.add(PlaceholderDimensions(
            size: Size(w, h),
            alignment: PlaceholderAlignment.middle,
          ));
          seg(1, inline); // atomic box → one U+FFFC, not splittable
        } else {
          var total = 0;
          for (final s in segs) {
            spans.add(TextSpan(text: s.text, style: s.style));
            total += s.text.length;
          }
          seg(total, inline, atomic: false); // splittable text run
        }
      } else if (inline is DocxLineBreak) {
        spans.add(const TextSpan(text: '\n'));
        seg(1, inline);
      } else if (inline is DocxTab) {
        // Tab width is resolved by the TabEngine during layout; for plain
        // measurement we use the renderer's placeholder width (four spaces).
        spans.add(const TextSpan(text: '    '));
        seg(4, inline);
      } else if (inline is DocxCheckbox) {
        spans.add(TextSpan(
          text: inline.isChecked ? '☒ ' : '☐ ',
          style: TextStyle(
            fontWeight: inline.fontWeight == DocxFontWeight.bold
                ? FontWeight.bold
                : FontWeight.normal,
            fontStyle: inline.fontStyle == DocxFontStyle.italic
                ? FontStyle.italic
                : FontStyle.normal,
            fontSize: inline.fontSize ?? theme.defaultTextStyle.fontSize,
            height: lineHeight ?? theme.defaultTextStyle.height,
          ),
        ));
        seg(2, inline);
      } else if (inline is DocxSymbol) {
        // Symbol-font glyph (`w:sym`): measured with the same text + style the
        // renderer uses (Plan §K.5) so measure ≡ render.
        final span = symbolSpan(inline, lineHeight: lineHeight);
        spans.add(span);
        seg(span.text!.length, inline);
      } else if (inline is DocxInlineImage) {
        // A *floating* drawing never adds inline height here: the renderer places
        // it out of the text flow — a side float through the band-aware wrap
        // (`FloatWrapText`, §8.2 #29), a full-width float as a paginator-reserved
        // band, a layer float as a back/front layer. The paragraph's text span
        // (this) is laid out *around* it by the same `layoutFloatWrap` the
        // paginator measures with, so measure ≡ render.
        if (_isFloatingDrawing(inline)) {
          anchorSeg(inline); // zero-width anchor for split bookkeeping
        } else {
          addImage(inline.width, inline.height, inline);
        }
      } else if (inline is DocxShape) {
        if (_isFloatingDrawing(inline)) {
          anchorSeg(inline);
        } else {
          addImage(inline.width, inline.height, inline);
        }
      } else if (inline is DocxFootnoteRef || inline is DocxEndnoteRef) {
        // Superscript reference mark; same size factor as the renderer.
        final id = inline is DocxFootnoteRef
            ? '${inline.footnoteId}'
            : '${(inline as DocxEndnoteRef).endnoteId}';
        spans.add(TextSpan(
          text: id,
          style: TextStyle(
            fontSize: (theme.defaultTextStyle.fontSize ?? 14) * 0.6,
            fontFeatures: const [FontFeature.superscripts()],
          ),
        ));
        seg(id.length, inline);
      } else if (inline is DocxPageNumber) {
        final t = inline.cachedText ?? '1';
        spans.add(_fieldSpan(t, lineHeight));
        seg(t.length, inline);
      } else if (inline is DocxPageCount) {
        final t = inline.cachedText ?? '1';
        spans.add(_fieldSpan(t, lineHeight));
        seg(t.length, inline);
      } else if (inline is DocxPageRef) {
        final text = inline.cachedText ?? '';
        if (text.isNotEmpty) {
          spans.add(_fieldSpan(text, lineHeight));
          seg(text.length, inline);
        }
      } else if (inline is DocxStyleRef) {
        // STYLEREF: measured at its cached value (the live per-page value is
        // resolved at render time, like PAGEREF) — Plan §K.3.
        final text = inline.cachedText ?? '';
        if (text.isNotEmpty) {
          spans.add(_fieldSpan(text, lineHeight));
          seg(text.length, inline);
        }
      } else if (inline is DocxUnknownField) {
        final nested = buildMeasurementSpans(
          inline.cachedResult,
          lineHeight: lineHeight,
        );
        spans.add(nested.root);
        placeholders.addAll(nested.placeholders);
        seg(nested.root.toPlainText(includePlaceholders: true).length, inline);
      } else if (inline is DocxBookmark) {
        // Zero-width anchor: contributes no glyphs, but its position is recorded
        // so a paragraph split keeps the bookmark on the correct side.
        anchorSeg(inline);
      }
      // Other zero-width anchors contribute nothing.
    }

    return MeasurementSpans(
      TextSpan(style: theme.defaultTextStyle, children: spans),
      placeholders,
      segments,
    );
  }

  /// Returns the inline children of a paragraph cut to the painter-space
  /// character range `[startChar, endChar)`, reusing every inline by reference
  /// and cloning only the [DocxText] run(s) on the boundary (§2.4 rule 1).
  ///
  /// [segments] must come from a [buildMeasurementSpans] call with the same
  /// [inlines], [skipHidden] and [firstLineIndentPx]; offsets are in that
  /// painter text space. Atomic runs (images, tabs, fields, breaks) are kept
  /// whole when their start lies inside the range and dropped otherwise.
  ///
  /// Zero-width anchors (bookmarks) are placed half-open `[startChar, endChar)`;
  /// pass [includeEndAnchors] for the tail slice (which runs to the paragraph
  /// end) so an anchor sitting at the final offset is kept rather than dropped.
  List<DocxInline> sliceInlines(
    List<DocxInline> inlines,
    List<SpanSegment> segments,
    int startChar,
    int endChar, {
    bool includeEndAnchors = false,
  }) {
    final out = <DocxInline>[];
    for (final s in segments) {
      final inline = s.inline;
      if (inline == null) continue; // synthetic (first-line indent)

      if (s.length == 0) {
        // Zero-width anchor: include by position (intersection math can never
        // catch an empty range).
        final keep = s.start >= startChar &&
            (s.start < endChar || (includeEndAnchors && s.start == endChar));
        if (keep) out.add(inline);
        continue;
      }

      // Intersection of [s.start, s.end) with [startChar, endChar).
      final lo = s.start < startChar ? startChar : s.start;
      final hi = s.end < endChar ? s.end : endChar;
      if (lo >= hi) continue; // no overlap

      if (!s.atomic && inline is DocxText) {
        final content = resolveContent(inline);
        final a = (lo - s.start).clamp(0, content.length);
        final b = (hi - s.start).clamp(0, content.length);
        if (b <= a) continue;
        if (a == 0 && b == content.length) {
          out.add(inline); // whole run — keep by reference
        } else {
          out.add(inline.copyWith(content: content.substring(a, b)));
        }
      } else {
        // Atomic run: include it whole when its start is within the range.
        if (s.start >= startChar && s.start < endChar) out.add(inline);
      }
    }
    return out;
  }

  TextSpan _fieldSpan(String text, double? lineHeight) => TextSpan(
        text: text,
        style: lineHeight != null
            ? theme.defaultTextStyle.copyWith(height: lineHeight)
            : theme.defaultTextStyle,
      );

  /// The span for a `w:sym` glyph (Plan §K.5), shared by the measurer and the
  /// renderer so measure ≡ render. A mapped glyph renders the Unicode equivalent
  /// in the body font (visible without the symbol font); an unmapped glyph keeps
  /// the symbol font with the body fonts as a fallback.
  TextSpan symbolSpan(DocxSymbol sym, {double? lineHeight}) {
    final mapped = SymbolFontMap.map(sym.font, sym.glyphIndex);
    final text = mapped ?? String.fromCharCode(sym.glyphIndex);
    final base = lineHeight != null
        ? theme.defaultTextStyle.copyWith(height: lineHeight)
        : theme.defaultTextStyle;
    final style = mapped != null
        ? base
        : base.copyWith(
            fontFamily: sym.font,
            fontFamilyFallback: [
              if (base.fontFamily != null) base.fontFamily!,
              ...config.customFontFallbacks,
            ],
          );
    return TextSpan(text: text, style: style);
  }

  /// Resolves an `auto` text colour (`w:color w:val="auto"`, ISO/IEC 29500
  /// §17.3.2.6) to black or white for contrast against the effective
  /// [background] behind the run — Word picks the colour from the shading the
  /// text actually sits on, not a global guess. A null/absent background falls
  /// back to the page background and finally the theme body colour (light page →
  /// black, so the common case is unchanged).
  Color resolveAutoTextColor(Color? background) {
    final bg = background ?? theme.backgroundColor;
    if (bg == null) {
      return theme.defaultTextStyle.color ?? const Color(0xFF000000);
    }
    return bg.computeLuminance() < 0.5
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
  }

  /// Whether [color] is an OOXML automatic colour (`w:val="auto"`), case- and
  /// representation-insensitive (the factory upper-cases, the constant does not).
  static bool isAutoColor(DocxColor? color) =>
      color != null && color.hex.toLowerCase() == 'auto';

  /// Resolves a colour from a hex value and/or theme reference, applying
  /// tint/shade. Shared with the renderer's borders/shapes.
  Color? resolveColor(
      String? hex, String? themeColor, String? themeTint, String? themeShade) {
    Color? baseColor;

    if (themeColor != null && docxTheme != null) {
      final themeHex = docxTheme!.colors.getColor(themeColor);
      if (themeHex != null) baseColor = parseHexColor(themeHex);
    }

    if (baseColor == null && hex != null && hex != 'auto') {
      baseColor = parseHexColor(hex);
    }
    if (baseColor == null) return null;

    if (themeTint != null) {
      final tintVal = int.tryParse(themeTint, radix: 16);
      if (tintVal != null) {
        final factor = tintVal / 255.0;
        baseColor = Color.alphaBlend(
            Colors.white.withValues(alpha: 1 - factor), baseColor);
      }
    }
    if (themeShade != null) {
      final shadeVal = int.tryParse(themeShade, radix: 16);
      if (shadeVal != null) {
        final factor = shadeVal / 255.0;
        baseColor = Color.alphaBlend(
            Colors.black.withValues(alpha: 1 - factor), baseColor);
      }
    }
    return baseColor;
  }

  /// Parses a 6- or 8-digit hex colour (`auto` → the body text colour), with
  /// smart inversion of near-black text on a dark background.
  Color? parseHexColor(String hex) {
    if (hex == 'auto') return theme.defaultTextStyle.color;
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 8) {
        if (hex.length == 6) buffer.write('ff');
        buffer.write(hex);
        final color = Color(int.parse(buffer.toString(), radix: 16));
        final bg = theme.backgroundColor;
        if (bg != null && bg.computeLuminance() < 0.5) {
          if (color.computeLuminance() < 0.179) return Colors.white;
        }
        return color;
      }
    } catch (_) {}
    return null;
  }

  /// Maps a Word underline pattern to the closest Flutter
  /// [TextDecorationStyle] and a relative thickness multiplier.
  (TextDecorationStyle, double) mapUnderline(DocxUnderlineStyle style) {
    switch (style) {
      case DocxUnderlineStyle.none:
      case DocxUnderlineStyle.single:
      case DocxUnderlineStyle.words:
        return (TextDecorationStyle.solid, 1.0);
      case DocxUnderlineStyle.thick:
        return (TextDecorationStyle.solid, 2.5);
      case DocxUnderlineStyle.double:
        return (TextDecorationStyle.double, 1.0);
      case DocxUnderlineStyle.dotted:
        return (TextDecorationStyle.dotted, 1.0);
      case DocxUnderlineStyle.dottedHeavy:
        return (TextDecorationStyle.dotted, 2.5);
      case DocxUnderlineStyle.dash:
      case DocxUnderlineStyle.dashLong:
      case DocxUnderlineStyle.dotDash:
      case DocxUnderlineStyle.dotDotDash:
        return (TextDecorationStyle.dashed, 1.0);
      case DocxUnderlineStyle.dashedHeavy:
      case DocxUnderlineStyle.dashLongHeavy:
      case DocxUnderlineStyle.dashDotHeavy:
      case DocxUnderlineStyle.dashDotDotHeavy:
        return (TextDecorationStyle.dashed, 2.5);
      case DocxUnderlineStyle.wave:
      case DocxUnderlineStyle.wavyDouble:
        return (TextDecorationStyle.wavy, 1.0);
      case DocxUnderlineStyle.wavyHeavy:
        return (TextDecorationStyle.wavy, 2.5);
    }
  }

  /// Maps a Word highlight to its rendered colour. `w:highlight` is a **fixed
  /// 16-colour palette** (ISO/IEC 29500 `ST_HighlightColor`), not an arbitrary
  /// RGB — these are the exact values Word paints, so we use them verbatim rather
  /// than the visibly-off Material approximations (e.g. yellow is FFFF00, not
  /// Material's FFEB3B; blue is 0000FF, not 2196F3). Render-only (a background
  /// colour never changes metrics → measure ≡ render). 03-run-rpr.md item 28.
  Color? highlightToColor(DocxHighlight highlight) {
    switch (highlight) {
      case DocxHighlight.black:
        return const Color(0xFF000000);
      case DocxHighlight.blue:
        return const Color(0xFF0000FF);
      case DocxHighlight.cyan:
        return const Color(0xFF00FFFF);
      case DocxHighlight.green:
        return const Color(0xFF00FF00);
      case DocxHighlight.magenta:
        return const Color(0xFFFF00FF);
      case DocxHighlight.red:
        return const Color(0xFFFF0000);
      case DocxHighlight.yellow:
        return const Color(0xFFFFFF00);
      case DocxHighlight.white:
        return const Color(0xFFFFFFFF);
      case DocxHighlight.darkBlue:
        return const Color(0xFF000080);
      case DocxHighlight.darkCyan:
        return const Color(0xFF008080);
      case DocxHighlight.darkGreen:
        return const Color(0xFF008000);
      case DocxHighlight.darkMagenta:
        return const Color(0xFF800080);
      case DocxHighlight.darkRed:
        return const Color(0xFF800000);
      case DocxHighlight.darkYellow:
        return const Color(0xFF808000);
      case DocxHighlight.darkGray:
        return const Color(0xFF808080);
      case DocxHighlight.lightGray:
        return const Color(0xFFC0C0C0);
      case DocxHighlight.none:
        return null;
    }
  }

  /// Geometry of a run's text-border box (`w:bdr`, 03-run-rpr.md item 37):
  /// the inner horizontal padding (from `w:space`, points → px at 96 DPI) and
  /// the border line width (from `w:sz`, eighth-points → px, clamped 0.5–10).
  /// Shared by the renderer's `Container` and the measurer's placeholder so the
  /// box is the *same* size in both (measure ≡ render). Returns null when there
  /// is no border or it is `none`/`nil`.
  ({double padH, double borderWidth})? textBorderBox(DocxBorderSide? side) {
    if (side == null || side.style == DocxBorder.none) return null;
    final borderWidth = (side.size / 8.0).clamp(0.5, 10.0);
    final padH = side.space * 96.0 / 72.0; // points → logical px
    return (padH: padH.toDouble(), borderWidth: borderWidth.toDouble());
  }
}

/// True when [inline] is a floating drawing — positioned out of the text flow by
/// the renderer (side floats via the band-aware wrap, full-width as a reserved
/// band, layer floats as a back/front layer). Such a drawing must not add inline
/// height to the measured text span. Inline (non-floating) drawings return false.
bool _isFloatingDrawing(DocxInline inline) => floatPlacementOf(inline) != null;
