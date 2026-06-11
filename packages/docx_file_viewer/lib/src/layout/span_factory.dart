import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';
import '../theme/docx_view_theme.dart';

/// The canonical paragraph [InlineSpan] plus the [PlaceholderDimensions] for
/// any [WidgetSpan]s it contains, in span order.
///
/// A [TextPainter] cannot lay out a span tree with placeholders until it is
/// told their sizes via [TextPainter.setPlaceholderDimensions]; bundling the
/// span with its placeholder list lets the measurer feed them in one call.
class MeasurementSpans {
  const MeasurementSpans(this.root, this.placeholders);

  /// Root span (style = the body default; children fully specify geometry).
  final InlineSpan root;

  /// Placeholder dimensions for the [WidgetSpan]s in [root], in order.
  final List<PlaceholderDimensions> placeholders;
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

  /// Applies Word's caps transforms to a run's text. `allCaps` and `smallCaps`
  /// both uppercase the glyphs; `smallCaps` additionally shrinks them (handled
  /// as a font-size factor in [resolveRunStyle]).
  String resolveContent(DocxText text) {
    if (text.isAllCaps || text.isSmallCaps) {
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
  TextStyle resolveRunStyle(DocxText text, {double? lineHeight}) {
    final fontWeight = text.fontWeight == DocxFontWeight.bold
        ? FontWeight.bold
        : FontWeight.normal;

    final fontStyle = text.fontStyle == DocxFontStyle.italic
        ? FontStyle.italic
        : FontStyle.normal;

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
      if (text.isDoubleStrike && !text.isUnderline) {
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

    double? fontSize = text.fontSize;
    if (fontSize != null) {
      fontSize = fontSize * 1.333;
    } else {
      fontSize = theme.defaultTextStyle.fontSize;
    }

    String? fontFamily; // null → granular resolution / theme default

    if (docxTheme != null) {
      String? themeFontName;
      if (text.fonts?.asciiTheme != null) {
        themeFontName = text.fonts!.asciiTheme;
      } else if (text.fonts?.hAnsiTheme != null) {
        themeFontName = text.fonts!.hAnsiTheme;
      } else if (text.fonts?.eastAsiaTheme != null) {
        themeFontName = text.fonts!.eastAsiaTheme;
      }
      if (themeFontName != null) {
        final resolved = docxTheme!.fonts.getFont(themeFontName);
        if (resolved != null) fontFamily = resolved;
      }
    }

    if (text.fonts?.ascii != null) {
      fontFamily = text.fonts!.ascii;
    } else if (text.fonts?.hAnsi != null) {
      fontFamily = text.fonts!.hAnsi;
    } else if (text.fonts?.family != null) {
      fontFamily = text.fonts!.family;
    }

    fontFamily ??= text.fontFamily;
    if (fontFamily == null && config.customFontFallbacks.isNotEmpty) {
      fontFamily = config.customFontFallbacks.first;
    }

    if (text.isSuperscript || text.isSubscript) {
      fontSize = (fontSize ?? 14) * 0.7;
    }
    if (text.isSmallCaps && !text.isAllCaps) {
      fontSize = (fontSize ?? 14) * 0.85;
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

    List<FontFeature>? fontFeatures;
    if (text.isSuperscript || text.isSubscript) {
      fontFeatures = [
        if (text.isSuperscript) const FontFeature.superscripts(),
        if (text.isSubscript) const FontFeature.subscripts(),
      ];
    } else if (wantsKern) {
      fontFeatures = const [FontFeature.enable('kern')];
    }

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
      fontFamilyFallback: config.customFontFallbacks,
      height: lineHeight ?? theme.defaultTextStyle.height,
      shadows: shadows,
      fontFeatures: fontFeatures,
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
    }

    void addImage(double w, double h) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SizedBox(width: w, height: h),
      ));
      placeholders.add(PlaceholderDimensions(
        size: Size(w, h),
        alignment: PlaceholderAlignment.middle,
      ));
    }

    for (final inline in inlines) {
      if (inline is DocxText) {
        if (skipHidden && inline.hidden) continue; // w:vanish.
        spans.add(TextSpan(
          text: resolveContent(inline),
          style: resolveRunStyle(inline, lineHeight: lineHeight),
        ));
      } else if (inline is DocxLineBreak) {
        spans.add(const TextSpan(text: '\n'));
      } else if (inline is DocxTab) {
        // Tab width is resolved by the TabEngine during layout; for plain
        // measurement we use the renderer's placeholder width (four spaces).
        spans.add(const TextSpan(text: '    '));
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
      } else if (inline is DocxInlineImage) {
        addImage(inline.width, inline.height);
      } else if (inline is DocxShape) {
        addImage(inline.width, inline.height);
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
      } else if (inline is DocxPageNumber) {
        spans.add(_fieldSpan(inline.cachedText ?? '1', lineHeight));
      } else if (inline is DocxPageCount) {
        spans.add(_fieldSpan(inline.cachedText ?? '1', lineHeight));
      } else if (inline is DocxPageRef) {
        final text = inline.cachedText ?? '';
        if (text.isNotEmpty) spans.add(_fieldSpan(text, lineHeight));
      } else if (inline is DocxUnknownField) {
        final nested = buildMeasurementSpans(
          inline.cachedResult,
          lineHeight: lineHeight,
        );
        spans.add(nested.root);
        placeholders.addAll(nested.placeholders);
      }
      // DocxBookmark and other zero-width anchors contribute nothing.
    }

    return MeasurementSpans(
      TextSpan(style: theme.defaultTextStyle, children: spans),
      placeholders,
    );
  }

  TextSpan _fieldSpan(String text, double? lineHeight) => TextSpan(
        text: text,
        style: lineHeight != null
            ? theme.defaultTextStyle.copyWith(height: lineHeight)
            : theme.defaultTextStyle,
      );

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

  /// Maps a Word highlight enum to its rendered colour.
  Color? highlightToColor(DocxHighlight highlight) {
    switch (highlight) {
      case DocxHighlight.black:
        return Colors.black;
      case DocxHighlight.blue:
        return Colors.blue;
      case DocxHighlight.cyan:
        return Colors.cyan;
      case DocxHighlight.green:
        return Colors.green;
      case DocxHighlight.magenta:
        return const Color(0xFFFF00FF);
      case DocxHighlight.red:
        return Colors.red;
      case DocxHighlight.yellow:
        return Colors.yellow;
      case DocxHighlight.white:
        return Colors.white;
      case DocxHighlight.darkBlue:
        return Colors.blue.shade900;
      case DocxHighlight.darkCyan:
        return Colors.cyan.shade900;
      case DocxHighlight.darkGreen:
        return Colors.green.shade900;
      case DocxHighlight.darkMagenta:
        return Colors.purple.shade900;
      case DocxHighlight.darkRed:
        return Colors.red.shade900;
      case DocxHighlight.darkYellow:
        return Colors.yellow.shade800;
      case DocxHighlight.darkGray:
        return Colors.grey.shade700;
      case DocxHighlight.lightGray:
        return Colors.grey.shade300;
      case DocxHighlight.none:
        return null;
    }
  }
}
