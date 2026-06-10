import 'package:xml/xml.dart';

import '../core/enums.dart';
import '../reader/docx_reader/models/docx_font.dart';
import 'docx_hyperlink_registry.dart';
import 'docx_node.dart';

/// A styled text run within a paragraph.
///
/// ## Basic
/// ```dart
/// DocxText('Hello')
/// ```
///
/// ## Styled
/// ```dart
/// DocxText.bold('Important')
/// DocxText.italic('Emphasis')
/// DocxText('Custom', color: DocxColor.red, fontSize: 14)
/// DocxText('Brand', color: DocxColor('#4285F4'))
/// ```
class DocxText extends DocxInline {
  final String content;
  final DocxFontWeight fontWeight;
  final DocxFontStyle fontStyle;
  final List<DocxTextDecoration> decorations;

  /// Underline pattern (e.g. [DocxUnderlineStyle.double], [DocxUnderlineStyle.wave]).
  ///
  /// Only meaningful when [decorations] contains [DocxTextDecoration.underline].
  /// When null the underline defaults to [DocxUnderlineStyle.single].
  final DocxUnderlineStyle? underlineStyle;

  /// Underline color. When null the underline follows the text [color].
  final DocxColor? underlineColor;

  final DocxColor? color;
  final DocxHighlight highlight;
  final String? shadingFill; // Background color hex
  final double? fontSize;

  /// Theme color reference (e.g. 'accent1').
  final String? themeColor;

  /// Theme color tint.
  final String? themeTint;

  /// Theme color shade.
  final String? themeShade;

  /// Theme fill (shading) for background.
  final String? themeFill;
  final String? themeFillTint;
  final String? themeFillShade;

  /// Legacy font family (single string). Use [fonts] for granular control.
  final String? fontFamily;

  /// granular font properties.
  final DocxFont? fonts;
  final double? characterSpacing;
  final String? href;

  final bool isSuperscript;
  final bool isSubscript;
  final bool isAllCaps;
  final bool isSmallCaps;
  final bool isDoubleStrike;
  final bool isOutline;
  final bool isShadow;
  final bool isEmboss;
  final bool isImprint;

  /// Complex-script (RTL) run direction (`w:rtl`). Selects which `*Cs`
  /// properties apply. Null when unset.
  final bool? rtl;

  /// Complex-script font size in points (`w:szCs`) — the size for
  /// Hebrew/Arabic characters in this run. Null falls back to [fontSize].
  final double? fontSizeCs;

  /// Complex-script bold (`w:bCs`).
  final bool? boldCs;

  /// Complex-script italic (`w:iCs`).
  final bool? italicCs;

  /// Kerning activation threshold in half-points (`w:kern w:val`); kerning is
  /// applied at this font size and above.
  final int? kernMinHalfPoints;

  /// Vertical raise (positive) / lower (negative) from the baseline in
  /// half-points (`w:position`). Not the same as super/subscript.
  final int? raiseLowerHalfPoints;

  /// Horizontal character scaling percent (`w:w`); 100 = normal.
  final int? charScalePercent;

  /// Compress/expand the run's text to this width in twips (`w:fitText`).
  final int? fitTextTwips;

  /// Hidden text (`w:vanish`). The render/measure layer is expected to skip
  /// these runs (Part C's SpanFactory); the flag is preserved here for that and
  /// for round-trip. (The current viewer does not yet suppress hidden text.)
  final bool hidden;

  /// East-Asian emphasis mark (`w:em`).
  final DocxEmphasisMark? emphasisMark;

  /// Text border (box around text), from w:bdr element
  final DocxBorderSide? textBorder;

  const DocxText(
    this.content, {
    this.fontWeight = DocxFontWeight.normal,
    this.fontStyle = DocxFontStyle.normal,
    this.decorations = const [],
    this.underlineStyle,
    this.underlineColor,
    this.color,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.fontSize,
    this.themeColor,
    this.themeTint,
    this.themeShade,
    this.themeFill,
    this.themeFillTint,
    this.themeFillShade,
    this.fontFamily,
    this.fonts,
    this.characterSpacing,
    this.href,
    this.isSuperscript = false,
    this.isSubscript = false,
    this.isAllCaps = false,
    this.isSmallCaps = false,
    this.isDoubleStrike = false,
    this.isOutline = false,
    this.isShadow = false,
    this.isEmboss = false,
    this.isImprint = false,
    this.rtl,
    this.fontSizeCs,
    this.boldCs,
    this.italicCs,
    this.kernMinHalfPoints,
    this.raiseLowerHalfPoints,
    this.charScalePercent,
    this.fitTextTwips,
    this.hidden = false,
    this.emphasisMark,
    this.textBorder,
    super.id,
  });

  // ============================================================
  // SIMPLE CONSTRUCTORS
  // ============================================================

  /// Bold text.
  const DocxText.bold(
    this.content, {
    this.color,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    this.themeFill,
    this.themeFillTint,
    this.themeFillShade,
    super.id,
  })  : fontWeight = DocxFontWeight.bold,
        fontStyle = DocxFontStyle.normal,
        decorations = const [],
        underlineStyle = null,
        underlineColor = null,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        rtl = null,
        fontSizeCs = null,
        boldCs = null,
        italicCs = null,
        kernMinHalfPoints = null,
        raiseLowerHalfPoints = null,
        charScalePercent = null,
        fitTextTwips = null,
        hidden = false,
        emphasisMark = null,
        textBorder = null;

  /// Italic text.
  const DocxText.italic(
    this.content, {
    this.color,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    this.themeFill,
    this.themeFillTint,
    this.themeFillShade,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.italic,
        decorations = const [],
        underlineStyle = null,
        underlineColor = null,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        rtl = null,
        fontSizeCs = null,
        boldCs = null,
        italicCs = null,
        kernMinHalfPoints = null,
        raiseLowerHalfPoints = null,
        charScalePercent = null,
        fitTextTwips = null,
        hidden = false,
        emphasisMark = null,
        textBorder = null;

  /// Bold and italic text.
  const DocxText.boldItalic(
    this.content, {
    this.color,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    this.themeFill,
    this.themeFillTint,
    this.themeFillShade,
    super.id,
  })  : fontWeight = DocxFontWeight.bold,
        fontStyle = DocxFontStyle.italic,
        decorations = const [],
        underlineStyle = null,
        underlineColor = null,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        rtl = null,
        fontSizeCs = null,
        boldCs = null,
        italicCs = null,
        kernMinHalfPoints = null,
        raiseLowerHalfPoints = null,
        charScalePercent = null,
        fitTextTwips = null,
        hidden = false,
        emphasisMark = null,
        textBorder = null;

  /// Underlined text.
  ///
  /// Use [style] to pick the underline pattern (single, double, wave, …) and
  /// [underlineColor] to color the line independently of the text.
  const DocxText.underline(
    this.content, {
    DocxUnderlineStyle style = DocxUnderlineStyle.single,
    this.underlineColor,
    this.color,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    this.themeFill,
    this.themeFillTint,
    this.themeFillShade,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decorations = const [DocxTextDecoration.underline],
        underlineStyle = style,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        rtl = null,
        fontSizeCs = null,
        boldCs = null,
        italicCs = null,
        kernMinHalfPoints = null,
        raiseLowerHalfPoints = null,
        charScalePercent = null,
        fitTextTwips = null,
        hidden = false,
        emphasisMark = null,
        textBorder = null;

  /// Strikethrough text.
  const DocxText.strike(
    this.content, {
    this.color,
    this.highlight = DocxHighlight.none,
    this.shadingFill,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    this.themeFill,
    this.themeFillTint,
    this.themeFillShade,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decorations = const [DocxTextDecoration.strikethrough],
        underlineStyle = null,
        underlineColor = null,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        rtl = null,
        fontSizeCs = null,
        boldCs = null,
        italicCs = null,
        kernMinHalfPoints = null,
        raiseLowerHalfPoints = null,
        charScalePercent = null,
        fitTextTwips = null,
        hidden = false,
        emphasisMark = null,
        textBorder = null;

  /// Hyperlink text.
  const DocxText.link(
    this.content, {
    required this.href,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    this.shadingFill,
    this.themeFill,
    this.themeFillTint,
    this.themeFillShade,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decorations = const [DocxTextDecoration.underline],
        underlineStyle = null,
        underlineColor = null,
        color = DocxColor.blue,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        rtl = null,
        fontSizeCs = null,
        boldCs = null,
        italicCs = null,
        kernMinHalfPoints = null,
        raiseLowerHalfPoints = null,
        charScalePercent = null,
        fitTextTwips = null,
        hidden = false,
        emphasisMark = null,
        textBorder = null;

  /// Inline code text.
  const DocxText.code(this.content,
      {this.fontSize,
      this.shadingFill,
      this.color,
      this.themeFill,
      this.themeFillTint,
      this.themeFillShade,
      super.id})
      : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decorations = const [],
        underlineStyle = null,
        underlineColor = null,
        highlight = DocxHighlight.none,
        fontFamily = 'Courier New',
        fonts = null,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        rtl = null,
        fontSizeCs = null,
        boldCs = null,
        italicCs = null,
        kernMinHalfPoints = null,
        raiseLowerHalfPoints = null,
        charScalePercent = null,
        fitTextTwips = null,
        hidden = false,
        emphasisMark = null,
        textBorder = null;

  /// Highlighted text.
  const DocxText.highlighted(
    this.content, {
    this.highlight = DocxHighlight.yellow,
    this.shadingFill,
    this.fontSize,
    this.fontFamily,
    this.fonts,
    this.color = DocxColor.black,
    this.themeFill,
    this.themeFillTint,
    this.themeFillShade,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decorations = const [],
        underlineStyle = null,
        underlineColor = null,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        rtl = null,
        fontSizeCs = null,
        boldCs = null,
        italicCs = null,
        kernMinHalfPoints = null,
        raiseLowerHalfPoints = null,
        charScalePercent = null,
        fitTextTwips = null,
        hidden = false,
        emphasisMark = null,
        textBorder = null;

  /// Superscript text (e.g., x²).
  const DocxText.superscript(this.content,
      {this.fontSize,
      this.shadingFill,
      this.themeFill,
      this.themeFillTint,
      this.themeFillShade,
      super.id})
      : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decorations = const [],
        underlineStyle = null,
        underlineColor = null,
        color = null,
        highlight = DocxHighlight.none,
        fontFamily = null,
        fonts = null,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = true,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        rtl = null,
        fontSizeCs = null,
        boldCs = null,
        italicCs = null,
        kernMinHalfPoints = null,
        raiseLowerHalfPoints = null,
        charScalePercent = null,
        fitTextTwips = null,
        hidden = false,
        emphasisMark = null,
        textBorder = null;

  /// Subscript text (e.g., H₂O).
  const DocxText.subscript(this.content,
      {this.fontSize,
      this.shadingFill,
      this.themeFill,
      this.themeFillTint,
      this.themeFillShade,
      super.id})
      : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decorations = const [],
        underlineStyle = null,
        underlineColor = null,
        color = null,
        highlight = DocxHighlight.none,
        fontFamily = null,
        fonts = null,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = true,
        isAllCaps = false,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        rtl = null,
        fontSizeCs = null,
        boldCs = null,
        italicCs = null,
        kernMinHalfPoints = null,
        raiseLowerHalfPoints = null,
        charScalePercent = null,
        fitTextTwips = null,
        hidden = false,
        emphasisMark = null,
        textBorder = null;

  /// ALL CAPS text.
  const DocxText.allCaps(
    this.content, {
    this.fontSize,
    this.fontFamily,
    this.fonts,
    this.shadingFill,
    this.themeFill,
    this.themeFillTint,
    this.themeFillShade,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decorations = const [],
        underlineStyle = null,
        underlineColor = null,
        color = null,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = true,
        isSmallCaps = false,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        rtl = null,
        fontSizeCs = null,
        boldCs = null,
        italicCs = null,
        kernMinHalfPoints = null,
        raiseLowerHalfPoints = null,
        charScalePercent = null,
        fitTextTwips = null,
        hidden = false,
        emphasisMark = null,
        textBorder = null;

  /// Small Caps text.
  const DocxText.smallCaps(
    this.content, {
    this.fontSize,
    this.fontFamily,
    this.fonts,
    this.shadingFill,
    this.themeFill,
    this.themeFillTint,
    this.themeFillShade,
    super.id,
  })  : fontWeight = DocxFontWeight.normal,
        fontStyle = DocxFontStyle.normal,
        decorations = const [],
        underlineStyle = null,
        underlineColor = null,
        color = null,
        highlight = DocxHighlight.none,
        characterSpacing = null,
        href = null,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        isSuperscript = false,
        isSubscript = false,
        isAllCaps = false,
        isSmallCaps = true,
        isDoubleStrike = false,
        isOutline = false,
        isShadow = false,
        isEmboss = false,
        isImprint = false,
        rtl = null,
        fontSizeCs = null,
        boldCs = null,
        italicCs = null,
        kernMinHalfPoints = null,
        raiseLowerHalfPoints = null,
        charScalePercent = null,
        fitTextTwips = null,
        hidden = false,
        emphasisMark = null,
        textBorder = null;

  // ============================================================
  // COPYWITH
  // ============================================================

  DocxText copyWith({
    String? content,
    DocxFontWeight? fontWeight,
    DocxFontStyle? fontStyle,
    List<DocxTextDecoration>? decorations,
    DocxUnderlineStyle? underlineStyle,
    DocxColor? underlineColor,
    DocxColor? color,
    DocxHighlight? highlight,
    String? shadingFill,
    double? fontSize,
    String? themeColor,
    String? themeTint,
    String? themeShade,
    String? themeFill,
    String? themeFillTint,
    String? themeFillShade,
    String? fontFamily,
    DocxFont? fonts,
    double? characterSpacing,
    String? href,
    bool? isSuperscript,
    bool? isSubscript,
    bool? isAllCaps,
    bool? isSmallCaps,
    bool? isDoubleStrike,
    bool? isOutline,
    bool? isShadow,
    bool? isEmboss,
    bool? isImprint,
    bool? rtl,
    double? fontSizeCs,
    bool? boldCs,
    bool? italicCs,
    int? kernMinHalfPoints,
    int? raiseLowerHalfPoints,
    int? charScalePercent,
    int? fitTextTwips,
    bool? hidden,
    DocxEmphasisMark? emphasisMark,
    DocxBorderSide? textBorder,
  }) {
    return DocxText(
      content ?? this.content,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      decorations: decorations ?? this.decorations,
      underlineStyle: underlineStyle ?? this.underlineStyle,
      underlineColor: underlineColor ?? this.underlineColor,
      color: color ?? this.color,
      highlight: highlight ?? this.highlight,
      shadingFill: shadingFill ?? this.shadingFill,
      fontSize: fontSize ?? this.fontSize,
      themeColor: themeColor ?? this.themeColor,
      themeTint: themeTint ?? this.themeTint,
      themeShade: themeShade ?? this.themeShade,
      themeFill: themeFill ?? this.themeFill,
      themeFillTint: themeFillTint ?? this.themeFillTint,
      themeFillShade: themeFillShade ?? this.themeFillShade,
      fontFamily: fontFamily ?? this.fontFamily,
      fonts: fonts ?? this.fonts,
      characterSpacing: characterSpacing ?? this.characterSpacing,
      href: href ?? this.href,
      isSuperscript: isSuperscript ?? this.isSuperscript,
      isSubscript: isSubscript ?? this.isSubscript,
      isAllCaps: isAllCaps ?? this.isAllCaps,
      isSmallCaps: isSmallCaps ?? this.isSmallCaps,
      isDoubleStrike: isDoubleStrike ?? this.isDoubleStrike,
      isOutline: isOutline ?? this.isOutline,
      isShadow: isShadow ?? this.isShadow,
      isEmboss: isEmboss ?? this.isEmboss,
      isImprint: isImprint ?? this.isImprint,
      rtl: rtl ?? this.rtl,
      fontSizeCs: fontSizeCs ?? this.fontSizeCs,
      boldCs: boldCs ?? this.boldCs,
      italicCs: italicCs ?? this.italicCs,
      kernMinHalfPoints: kernMinHalfPoints ?? this.kernMinHalfPoints,
      raiseLowerHalfPoints: raiseLowerHalfPoints ?? this.raiseLowerHalfPoints,
      charScalePercent: charScalePercent ?? this.charScalePercent,
      fitTextTwips: fitTextTwips ?? this.fitTextTwips,
      hidden: hidden ?? this.hidden,
      emphasisMark: emphasisMark ?? this.emphasisMark,
      textBorder: textBorder ?? this.textBorder,
      id: id,
    );
  }

  // ============================================================
  // COMPUTED
  // ============================================================

  bool get isBold => fontWeight == DocxFontWeight.bold;
  bool get isItalic => fontStyle == DocxFontStyle.italic;
  bool get isUnderline => decorations.contains(DocxTextDecoration.underline);
  bool get isStrike => decorations.contains(DocxTextDecoration.strikethrough);

  /// The effective underline pattern to render/write: the explicit
  /// [underlineStyle] when set, otherwise [DocxUnderlineStyle.single] when the
  /// run is underlined, else `null`.
  DocxUnderlineStyle? get effectiveUnderlineStyle {
    if (underlineStyle != null) return underlineStyle;
    return isUnderline ? DocxUnderlineStyle.single : null;
  }
  DocxTextDecoration get decoration =>
      decorations.isNotEmpty ? decorations.first : DocxTextDecoration.none;
  bool get isLink => href != null;

  String? get effectiveColorHex => color?.hex;

  // ============================================================
  // AST
  // ============================================================

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    if (isLink) {
      final rId = DocxHyperlinkRegistry.lookup(href!);
      if (rId != null) {
        builder.element('w:hyperlink', nest: () {
          builder.attribute('r:id', rId);
          _buildRun(builder);
        });
        return;
      }
    }
    _buildRun(builder);
  }

  void _buildRun(XmlBuilder builder) {
    builder.element(
      'w:r',
      nest: () {
        if (_hasFormatting) {
          builder.element(
            'w:rPr',
            nest: () {
              // 1. rFonts
              final effectiveFonts = fonts ??
                  (fontFamily != null ? DocxFont.family(fontFamily!) : null);
              if (effectiveFonts != null) {
                builder.element(
                  'w:rFonts',
                  nest: () {
                    if (effectiveFonts.ascii != null) {
                      builder.attribute('w:ascii', effectiveFonts.ascii!);
                    }
                    if (effectiveFonts.hAnsi != null) {
                      builder.attribute('w:hAnsi', effectiveFonts.hAnsi!);
                    }
                    if (effectiveFonts.cs != null) {
                      builder.attribute('w:cs', effectiveFonts.cs!);
                    }
                    if (effectiveFonts.eastAsia != null) {
                      builder.attribute('w:eastAsia', effectiveFonts.eastAsia!);
                    }
                    if (effectiveFonts.hint != null) {
                      builder.attribute('w:hint', effectiveFonts.hint!);
                    }
                    if (effectiveFonts.asciiTheme != null) {
                      builder.attribute(
                          'w:asciiTheme', effectiveFonts.asciiTheme!);
                    }
                    if (effectiveFonts.hAnsiTheme != null) {
                      builder.attribute(
                          'w:hAnsiTheme', effectiveFonts.hAnsiTheme!);
                    }
                    if (effectiveFonts.csTheme != null) {
                      builder.attribute('w:csTheme', effectiveFonts.csTheme!);
                    }
                    if (effectiveFonts.eastAsiaTheme != null) {
                      builder.attribute(
                          'w:eastAsiaTheme', effectiveFonts.eastAsiaTheme!);
                    }
                  },
                );
              }

              // 2. b (Bold)
              if (isBold) builder.element('w:b');

              // 2.5 bCs (complex-script bold)
              if (boldCs != null) {
                builder.element('w:bCs', nest: () {
                  if (!boldCs!) builder.attribute('w:val', '0');
                });
              }

              // 3. i (Italic)
              if (isItalic) builder.element('w:i');

              // 3.5 iCs (complex-script italic)
              if (italicCs != null) {
                builder.element('w:iCs', nest: () {
                  if (!italicCs!) builder.attribute('w:val', '0');
                });
              }

              // 4. caps (All Caps)
              if (isAllCaps) builder.element('w:caps');

              // 5. smallCaps
              if (isSmallCaps) builder.element('w:smallCaps');

              // 6. strike
              if (isStrike) builder.element('w:strike');

              // 7. dstrike
              if (isDoubleStrike) builder.element('w:dstrike');

              // 8. outline
              if (isOutline) builder.element('w:outline');

              // 9. shadow
              if (isShadow) builder.element('w:shadow');

              // 10. emboss
              if (isEmboss) builder.element('w:emboss');

              // 11. imprint
              if (isImprint) builder.element('w:imprint');

              // 11.5 vanish (hidden text)
              if (hidden) builder.element('w:vanish');

              // 12. color
              if (effectiveColorHex != null) {
                builder.element(
                  'w:color',
                  nest: () {
                    builder.attribute('w:val', effectiveColorHex!);
                  },
                );
              }

              // 13. spacing
              if (characterSpacing != null) {
                builder.element(
                  'w:spacing',
                  nest: () {
                    builder.attribute(
                      'w:val',
                      characterSpacing!.toInt().toString(),
                    );
                  },
                );
              }

              // 13.5 w (horizontal character scaling, percent)
              if (charScalePercent != null) {
                builder.element('w:w', nest: () {
                  builder.attribute('w:val', charScalePercent.toString());
                });
              }

              // 13.6 kern (kerning threshold, half-points)
              if (kernMinHalfPoints != null) {
                builder.element('w:kern', nest: () {
                  builder.attribute('w:val', kernMinHalfPoints.toString());
                });
              }

              // 13.7 position (raise/lower from baseline, half-points)
              if (raiseLowerHalfPoints != null) {
                builder.element('w:position', nest: () {
                  builder.attribute('w:val', raiseLowerHalfPoints.toString());
                });
              }

              // 14. sz (Font Size)
              if (fontSize != null) {
                builder.element(
                  'w:sz',
                  nest: () {
                    builder.attribute(
                      'w:val',
                      (fontSize! * 2).toInt().toString(),
                    );
                  },
                );
              }

              // 14.5 szCs (complex-script size) — uses fontSizeCs when set,
              // otherwise mirrors the ASCII size, matching Word's output.
              final csSize = fontSizeCs ?? fontSize;
              if (csSize != null) {
                builder.element(
                  'w:szCs',
                  nest: () {
                    builder.attribute('w:val', (csSize * 2).toInt().toString());
                  },
                );
              }

              // 15. highlight
              if (highlight != DocxHighlight.none) {
                builder.element(
                  'w:highlight',
                  nest: () {
                    builder.attribute('w:val', highlight.name);
                  },
                );
              }

              // 16. u (Underline) — pattern + optional independent color.
              final uStyle = effectiveUnderlineStyle;
              if (uStyle != null && uStyle != DocxUnderlineStyle.none) {
                builder.element(
                  'w:u',
                  nest: () {
                    builder.attribute('w:val', uStyle.xmlValue);
                    final uc = underlineColor;
                    if (uc != null) {
                      builder.attribute('w:color', uc.hex);
                      if (uc.themeColor != null) {
                        builder.attribute('w:themeColor', uc.themeColor!);
                      }
                      if (uc.themeTint != null) {
                        builder.attribute('w:themeTint', uc.themeTint!);
                      }
                      if (uc.themeShade != null) {
                        builder.attribute('w:themeShade', uc.themeShade!);
                      }
                    }
                  },
                );
              }

              // 17. bdr (Text Border)
              if (textBorder != null) {
                builder.element(
                  'w:bdr',
                  nest: () {
                    builder.attribute('w:val', textBorder!.style.xmlValue);
                    builder.attribute('w:sz', textBorder!.size.toString());
                    builder.attribute('w:space', textBorder!.space.toString());
                    builder.attribute('w:color', textBorder!.color.hex);
                  },
                );
              }

              // 18. shd (Shading)
              if (shadingFill != null || themeFill != null) {
                builder.element(
                  'w:shd',
                  nest: () {
                    builder.attribute('w:val', 'clear');
                    builder.attribute('w:color', 'auto');
                    if (shadingFill != null) {
                      builder.attribute('w:fill', shadingFill!);
                    }
                    if (themeFill != null) {
                      builder.attribute('w:themeFill', themeFill!);
                    }
                    if (themeFillTint != null) {
                      builder.attribute('w:themeFillTint', themeFillTint!);
                    }
                    if (themeFillShade != null) {
                      builder.attribute('w:themeFillShade', themeFillShade!);
                    }
                  },
                );
              }

              // 18.5 fitText (compress/expand to a fixed width, twips)
              if (fitTextTwips != null) {
                builder.element('w:fitText', nest: () {
                  builder.attribute('w:val', fitTextTwips.toString());
                });
              }

              // 19. vertAlign
              if (isSuperscript || isSubscript) {
                builder.element(
                  'w:vertAlign',
                  nest: () {
                    builder.attribute(
                      'w:val',
                      isSuperscript ? 'superscript' : 'subscript',
                    );
                  },
                );
              }

              // 20. rtl (complex-script run direction)
              if (rtl != null) {
                builder.element('w:rtl', nest: () {
                  if (!rtl!) builder.attribute('w:val', '0');
                });
              }

              // 21. em (emphasis mark)
              if (emphasisMark != null) {
                builder.element('w:em', nest: () {
                  builder.attribute('w:val', emphasisMark!.xmlValue);
                });
              }
            },
          );
        }

        final lines = content.split(RegExp(r'\r?\n'));
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.isNotEmpty) {
            builder.element(
              'w:t',
              nest: () {
                if (line.startsWith(' ') || line.endsWith(' ')) {
                  builder.attribute('xml:space', 'preserve');
                }
                builder.text(line);
              },
            );
          }
          if (i < lines.length - 1) {
            builder.element('w:br');
          }
        }
      },
    );
  }

  bool get _hasFormatting =>
      isBold ||
      isItalic ||
      decorations.isNotEmpty ||
      isDoubleStrike ||
      isOutline ||
      isShadow ||
      isEmboss ||
      isImprint ||
      isAllCaps ||
      isSmallCaps ||
      isSuperscript ||
      isSubscript ||
      effectiveColorHex != null ||
      fontSize != null ||
      fontFamily != null ||
      fonts != null ||
      highlight != DocxHighlight.none ||
      characterSpacing != null ||
      textBorder != null ||
      themeFill != null ||
      themeFillTint != null ||
      themeFillShade != null ||
      rtl != null ||
      fontSizeCs != null ||
      boldCs != null ||
      italicCs != null ||
      kernMinHalfPoints != null ||
      raiseLowerHalfPoints != null ||
      charScalePercent != null ||
      fitTextTwips != null ||
      hidden ||
      emphasisMark != null;
}

/// A line break.
class DocxLineBreak extends DocxInline {
  /// האם זהו מעבר עמוד (`w:br w:type="page"`) ולא מעבר שורה רגיל.
  /// מנוע התצוגה משתמש בזה כדי לשבור לעמוד חדש במצב paged.
  final bool isPageBreak;

  const DocxLineBreak({super.id, this.isPageBreak = false});

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:r',
      nest: () {
        builder.element('w:br', nest: () {
          if (isPageBreak) builder.attribute('w:type', 'page');
        });
      },
    );
  }
}

/// A tab character.
class DocxTab extends DocxInline {
  const DocxTab({super.id});

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:r',
      nest: () {
        builder.element('w:tab');
      },
    );
  }
}

/// A symbol character from a symbol font (`w:sym`), e.g. Wingdings/Symbol.
///
/// [charCode] is the raw `w:char` value (Word stores these in the F000–F0FF
/// private-use area); [glyphIndex] strips that offset to the font's own slot,
/// which the renderer (Part K) maps to a glyph or an equivalent Unicode char.
class DocxSymbol extends DocxInline {
  /// Raw code point from `w:char` (typically 0xF000–0xF0FF).
  final int charCode;

  /// Symbol font name from `w:font` (e.g. "Wingdings").
  final String? font;

  const DocxSymbol({required this.charCode, this.font, super.id});

  /// The glyph slot within [font], with the F000 private-use offset removed.
  int get glyphIndex =>
      (charCode >= 0xF000 && charCode <= 0xF0FF) ? charCode - 0xF000 : charCode;

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(
        DocxText(String.fromCharCode(glyphIndex), fontFamily: font),
      );

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:r', nest: () {
      builder.element('w:sym', nest: () {
        if (font != null) builder.attribute('w:font', font!);
        builder.attribute(
            'w:char', charCode.toRadixString(16).toUpperCase().padLeft(4, '0'));
      });
    });
  }
}

/// A positional tab (`w:ptab`) — a tab whose stop is computed relative to the
/// margin/indent rather than a fixed tab-stop list. Rendered by Part C.
class DocxPositionalTab extends DocxInline {
  /// Alignment of content at the positional tab (left/center/right).
  final DocxTabAlignment alignment;

  /// What the tab position is measured from.
  final DocxPtabRelativeTo relativeTo;

  /// Leader character filling the gap.
  final DocxTabLeader leader;

  const DocxPositionalTab({
    this.alignment = DocxTabAlignment.left,
    this.relativeTo = DocxPtabRelativeTo.margin,
    this.leader = DocxTabLeader.none,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(const DocxTab());

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:r', nest: () {
      builder.element('w:ptab', nest: () {
        builder.attribute('w:alignment', alignment.xmlValue);
        builder.attribute('w:relativeTo', relativeTo.xmlValue);
        builder.attribute('w:leader', leader.xmlValue);
      });
    });
  }
}

/// A clickable checkbox (form field).
class DocxCheckbox extends DocxInline {
  final bool isChecked;
  final double? fontSize;
  final DocxFontWeight fontWeight;
  final DocxFontStyle fontStyle;
  final DocxColor? color;

  const DocxCheckbox({
    this.isChecked = false,
    this.fontSize,
    this.fontWeight = DocxFontWeight.normal,
    this.fontStyle = DocxFontStyle.normal,
    this.color,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(
        DocxText(
          isChecked ? '☒' : '☐',
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          color: color,
          fontSize: fontSize,
        ),
      );

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:sdt',
      nest: () {
        builder.element(
          'w:sdtPr',
          nest: () {
            builder.element(
              'w14:checkbox',
              nest: () {
                builder.element('w14:checked', nest: () {
                  builder.attribute('w14:val', isChecked ? '1' : '0');
                });
              },
            );
            builder.element('w:alias', nest: () {
              builder.attribute('w:val', 'Checkbox');
            });
            builder.element('w:tag', nest: () {
              builder.attribute('w:val', 'checkbox');
            });
          },
        );
        builder.element(
          'w:sdtContent',
          nest: () {
            builder.element(
              'w:r',
              nest: () {
                if (fontSize != null ||
                    fontWeight == DocxFontWeight.bold ||
                    fontStyle == DocxFontStyle.italic ||
                    color != null) {
                  builder.element(
                    'w:rPr',
                    nest: () {
                      if (fontSize != null) {
                        builder.element(
                          'w:sz',
                          nest: () {
                            builder.attribute(
                              'w:val',
                              (fontSize! * 2).toInt().toString(),
                            );
                          },
                        );
                      }
                      if (fontWeight == DocxFontWeight.bold) {
                        builder.element('w:b');
                      }
                      if (fontStyle == DocxFontStyle.italic) {
                        builder.element('w:i');
                      }
                      if (color != null) {
                        builder.element('w:color', nest: () {
                          builder.attribute('w:val', color!.hex);
                        });
                      }
                    },
                  );
                }
                builder.element(
                  'w:t',
                  nest: () {
                    builder.text(isChecked ? '☒' : '☐');
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
