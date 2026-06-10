/// Style and formatting enums/classes for `docx_ai_creator`.
library;

// ============================================================
// TEXT & PARAGRAPH ALIGNMENT
// ============================================================

/// Text alignment within a paragraph or table cell.
enum DocxAlign { left, center, right, justify }

extension DocxAlignExtension on DocxAlign {
  String get xmlValue {
    switch (this) {
      case DocxAlign.left:
        return 'start';
      case DocxAlign.center:
        return 'center';
      case DocxAlign.right:
        return 'end';
      case DocxAlign.justify:
        return 'both';
    }
  }
}

// ============================================================
// VERTICAL TEXT ALIGNMENT
// ============================================================

/// Vertical text alignment within a line (e.g., relative to an image).
enum DocxTextAlignment { auto, baseline, bottom, center, top }

extension DocxTextAlignmentExtension on DocxTextAlignment {
  String get xmlValue => name;
}

// ============================================================
// COLOR (Flexible Class)
// ============================================================

/// A color value for text, backgrounds, and borders.
///
/// ## Predefined Colors
/// ```dart
/// DocxText('Red', color: DocxColor.red)
/// DocxText('Blue', color: DocxColor.blue)
/// ```
///
/// ## Custom Hex Colors
/// ```dart
/// DocxText('Brand', color: DocxColor('#4285F4'))
/// DocxText('Custom', color: DocxColor('FF5722'))
/// ```
class DocxColor {
  /// The hex color value (without #).
  final String hex;

  /// Theme color reference (e.g. 'accent1').
  final String? themeColor;

  /// Theme color tint.
  final String? themeTint;

  /// Theme color shade.
  final String? themeShade;

  /// Private const constructor for predefined colors.
  const DocxColor._(this.hex,
      {this.themeColor, this.themeTint, this.themeShade});

  /// Creates a color from a hex string.
  ///
  /// Accepts formats: 'RRGGBB', '#RRGGBB', '0xRRGGBB'
  factory DocxColor(String value,
      {String? themeColor, String? themeTint, String? themeShade}) {
    String hex = value.toUpperCase();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.startsWith('0X')) hex = hex.substring(2);
    return DocxColor._(hex,
        themeColor: themeColor, themeTint: themeTint, themeShade: themeShade);
  }

  /// Creates a color from a hex string, removing # or 0x prefix.
  factory DocxColor.fromHex(String value) => DocxColor(value);

  // Predefined colors
  static const auto = DocxColor._('auto');
  static const black = DocxColor._('000000');
  static const white = DocxColor._('FFFFFF');
  static const red = DocxColor._('FF0000');
  static const blue = DocxColor._('0000FF');
  static const green = DocxColor._('00FF00');
  static const yellow = DocxColor._('FFFF00');
  static const orange = DocxColor._('FFA500');
  static const purple = DocxColor._('800080');
  static const gray = DocxColor._('808080');
  static const lightGray = DocxColor._('D3D3D3');
  static const darkGray = DocxColor._('404040');
  static const cyan = DocxColor._('00FFFF');
  static const magenta = DocxColor._('FF00FF');
  static const pink = DocxColor._('FFC0CB');
  static const brown = DocxColor._('8B4513');
  static const navy = DocxColor._('000080');
  static const teal = DocxColor._('008080');
  static const lime = DocxColor._('32CD32');
  static const gold = DocxColor._('FFD700');
  static const silver = DocxColor._('C0C0C0');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DocxColor && hex == other.hex;

  @override
  int get hashCode => hex.hashCode;

  @override
  String toString() => 'DocxColor($hex)';
}

// ============================================================
// BORDERS
// ============================================================

/// Border styles for tables, paragraphs, and sections.
enum DocxBorder { none, single, double, dashed, dotted, thick, triple }

extension DocxBorderExtension on DocxBorder {
  String get xmlValue {
    switch (this) {
      case DocxBorder.none:
        return 'nil';
      case DocxBorder.single:
        return 'single';
      case DocxBorder.double:
        return 'double';
      case DocxBorder.dashed:
        return 'dashed';
      case DocxBorder.dotted:
        return 'dotted';
      case DocxBorder.thick:
        return 'thick';
      case DocxBorder.triple:
        return 'triple';
    }
  }
}

/// Defines a single border side properties.
class DocxBorderSide {
  final DocxBorder style;
  final DocxColor color;

  /// Border width in eighths of a point (4 = 0.5pt, 8 = 1pt).
  final int size;
  final int space;

  /// Theme color reference (e.g. 'accent1').
  final String? themeColor;

  /// Theme color tint (e.g. '66' for 40% lighter).
  final String? themeTint;

  /// Theme color shade (e.g. '80' for 20% darker).
  final String? themeShade;

  /// Raw XML value for border style if it doesn't match [DocxBorder] enum.
  final String? rawVal;

  const DocxBorderSide({
    this.style = DocxBorder.single,
    this.color = DocxColor.black,
    this.size = 4,
    this.space = 0,
    this.themeColor,
    this.themeTint,
    this.themeShade,
    this.rawVal,
  });

  const DocxBorderSide.none()
      : style = DocxBorder.none,
        color = DocxColor.auto,
        size = 0,
        space = 0,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        rawVal = null;

  String get xmlStyle => rawVal ?? style.xmlValue;
}

// ============================================================
// FONT STYLING
// ============================================================

enum DocxFontWeight { normal, bold }

enum DocxFontStyle { normal, italic }

enum DocxTextDecoration { none, underline, strikethrough }

/// Underline patterns, mirroring the OOXML `ST_Underline` simple type
/// (the `w:val` attribute of the `<w:u>` element).
///
/// Enum names match the OOXML tokens 1:1, so [xmlValue] is just [Enum.name]
/// and [fromXml] is a reverse name lookup.
///
/// ```dart
/// DocxText('Wavy', underlineStyle: DocxUnderlineStyle.wave,
///     underlineColor: DocxColor.red)
/// ```
enum DocxUnderlineStyle {
  /// No underline (explicit `w:val="none"`).
  none,

  /// A single line.
  single,

  /// Underline non-space characters only (words, not the spaces between them).
  words,

  /// Two lines.
  double,

  /// A single thick line.
  thick,

  /// A dotted line.
  dotted,

  /// A thick dotted line.
  dottedHeavy,

  /// A dashed line.
  dash,

  /// A thick dashed line.
  dashedHeavy,

  /// A line of long dashes.
  dashLong,

  /// A thick line of long dashes.
  dashLongHeavy,

  /// A dash-dot line.
  dotDash,

  /// A thick dash-dot line.
  dashDotHeavy,

  /// A dash-dot-dot line.
  dotDotDash,

  /// A thick dash-dot-dot line.
  dashDotDotHeavy,

  /// A wavy line.
  wave,

  /// A thick wavy line.
  wavyHeavy,

  /// A double wavy line.
  wavyDouble,
}

extension DocxUnderlineStyleExtension on DocxUnderlineStyle {
  /// The OOXML `w:val` token for this style (matches [Enum.name]).
  String get xmlValue => name;

  /// Whether this style is a "heavy"/thick variant.
  bool get isHeavy =>
      this == DocxUnderlineStyle.thick ||
      this == DocxUnderlineStyle.dottedHeavy ||
      this == DocxUnderlineStyle.dashedHeavy ||
      this == DocxUnderlineStyle.dashLongHeavy ||
      this == DocxUnderlineStyle.dashDotHeavy ||
      this == DocxUnderlineStyle.dashDotDotHeavy ||
      this == DocxUnderlineStyle.wavyHeavy;

  /// Parse an OOXML `w:val` token into a [DocxUnderlineStyle], or `null` if the
  /// token is unknown.
  static DocxUnderlineStyle? fromXml(String? val) {
    if (val == null) return null;
    for (final s in DocxUnderlineStyle.values) {
      if (s.name == val) return s;
    }
    return null;
  }
}

/// Highlight (background) colors for text.
enum DocxHighlight {
  none,
  yellow,
  green,
  cyan,
  magenta,
  blue,
  red,
  darkBlue,
  darkCyan,
  darkGreen,
  darkMagenta,
  darkRed,
  darkYellow,
  darkGray,
  lightGray,
  black,
  white,
}

// ============================================================
// PAGE & SECTION
// ============================================================

enum DocxPageOrientation { portrait, landscape }

enum DocxPageSize { letter, a4, legal, tabloid, custom }

enum DocxSectionBreak { continuous, nextPage, evenPage, oddPage }

/// Display format for automatic page numbers — sourced from a `w:pgNumType`
/// `w:fmt` on a section or from a `\*` switch on a `PAGE`/`NUMPAGES`/`PAGEREF`
/// field. Maps onto `NumberFormatter`.
enum DocxPageNumberFormat {
  decimal,
  upperRoman,
  lowerRoman,
  upperLetter,
  lowerLetter,
}

/// Chapter/page separator for `w:pgNumType w:chapSep` (e.g. "1-1", "2.5").
enum DocxChapterSeparator { hyphen, period, colon, emDash, enDash }

/// Which header/footer variant applies to a page.
enum DocxHeaderFooterType { primary, first, even }

// ============================================================
// TABLE-SPECIFIC
// ============================================================

enum DocxVerticalAlign { top, center, bottom }

enum DocxWidthType { auto, dxa, pct }

// ============================================================
// HEADING LEVELS
// ============================================================

enum DocxHeadingLevel { h1, h2, h3, h4, h5, h6 }

extension DocxHeadingLevelExtension on DocxHeadingLevel {
  String get styleId => 'Heading${index + 1}';

  double get defaultFontSize {
    switch (this) {
      case DocxHeadingLevel.h1:
        return 24;
      case DocxHeadingLevel.h2:
        return 20;
      case DocxHeadingLevel.h3:
        return 16;
      case DocxHeadingLevel.h4:
        return 14;
      case DocxHeadingLevel.h5:
        return 12;
      case DocxHeadingLevel.h6:
        return 11;
    }
  }
}
