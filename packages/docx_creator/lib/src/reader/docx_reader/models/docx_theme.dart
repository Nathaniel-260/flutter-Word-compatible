import 'dart:typed_data';

import '../../../../docx_creator.dart';

/// Represents the complete theme and style information from a DOCX document.
///
/// This class captures:
/// - Document defaults (default paragraph and run styles)
/// - Named styles (Normal, Heading1, etc.)
/// - Theme colors (accent colors, hyperlink colors, etc.)
/// - Theme fonts (major/minor fonts for headings and body)
/// - Numbering definitions
///
/// Use [DocxTheme] to understand the full styling context of a document.
class DocxTheme {
  /// Document default paragraph properties.
  final DocxStyle? defaultParagraphStyle;

  /// Document default run (character) properties.
  final DocxStyle? defaultRunStyle;

  /// Named styles map (styleId -> DocxStyle).
  final Map<String, DocxStyle> styles;

  /// Theme colors from theme1.xml.
  final DocxThemeColors colors;

  /// Theme fonts from theme1.xml.
  final DocxThemeFonts fonts;

  /// Latent style defaults (for styles not explicitly defined).
  final Map<String, LatentStyleDef> latentStyles;

  const DocxTheme({
    this.defaultParagraphStyle,
    this.defaultRunStyle,
    this.styles = const {},
    this.colors = const DocxThemeColors(),
    this.fonts = const DocxThemeFonts(),
    this.latentStyles = const {},
  });

  /// Creates an empty theme with defaults.
  factory DocxTheme.empty() => const DocxTheme();

  /// Gets a style by ID, returning null if not found.
  DocxStyle? getStyle(String styleId) => styles[styleId];

  /// Gets all styles of a specific type.
  List<DocxStyle> getStylesByType(String type) {
    return styles.values.where((s) => s.type == type).toList();
  }

  /// Gets all paragraph styles.
  List<DocxStyle> get paragraphStyles => getStylesByType('paragraph');

  /// Gets all character (run) styles.
  List<DocxStyle> get characterStyles => getStylesByType('character');

  /// Gets all table styles.
  List<DocxStyle> get tableStyles => getStylesByType('table');

  /// Gets all numbering styles.
  List<DocxStyle> get numberingStyles => getStylesByType('numbering');

  /// Gets the Normal paragraph style.
  DocxStyle? get normalStyle => styles['Normal'];

  /// Gets heading styles (Heading1, Heading2, etc.).
  List<DocxStyle> get headingStyles {
    return styles.entries
        .where((e) => e.key.startsWith('Heading'))
        .map((e) => e.value)
        .toList();
  }
}

/// Theme color definitions from theme1.xml.
///
/// Colors in OOXML themes use a scheme-based system where colors are
/// defined by role (accent1, accent2, etc.) rather than fixed values.
class DocxThemeColors {
  /// Dark 1 color (typically black or near-black).
  final String dk1;

  /// Light 1 color (typically white or near-white).
  final String lt1;

  /// Dark 2 color.
  final String dk2;

  /// Light 2 color.
  final String lt2;

  /// Accent colors (1-6).
  final String accent1;
  final String accent2;
  final String accent3;
  final String accent4;
  final String accent5;
  final String accent6;

  /// Hyperlink color.
  final String hlink;

  /// Followed hyperlink color.
  final String folHlink;

  const DocxThemeColors({
    this.dk1 = '000000',
    this.lt1 = 'FFFFFF',
    this.dk2 = '1F497D',
    this.lt2 = 'EEECE1',
    this.accent1 = '4F81BD',
    this.accent2 = 'C0504D',
    this.accent3 = '9BBB59',
    this.accent4 = '8064A2',
    this.accent5 = '4BACC6',
    this.accent6 = 'F79646',
    this.hlink = '0000FF',
    this.folHlink = '800080',
  });

  /// Gets a color by scheme name.
  ///
  /// Supports standard names (dk1, lt1, accent1-6, hlink, folHlink)
  /// and OOXML aliases (text1/2, background1/2).
  String? getColor(String schemeName) {
    switch (schemeName) {
      // `w:themeColor` (ST_ThemeColor) tokens use the `dark*`/`light*`/
      // `hyperlink` spelling, while a clrScheme element uses `dk*`/`lt*`/`hlink`.
      // Map both so a run/border `w:themeColor="dark1"` or `"hyperlink"` resolves
      // (13-theme.md items 3, 6) instead of falling back to black.
      case 'dk1':
      case 'text1': // OOXML alias for dk1
      case 'dark1': // ST_ThemeColor token
        return dk1;
      case 'lt1':
      case 'background1': // OOXML alias for lt1
      case 'light1': // ST_ThemeColor token
        return lt1;
      case 'dk2':
      case 'text2': // OOXML alias for dk2
      case 'dark2': // ST_ThemeColor token
        return dk2;
      case 'lt2':
      case 'background2': // OOXML alias for lt2
      case 'light2': // ST_ThemeColor token
        return lt2;
      case 'accent1':
        return accent1;
      case 'accent2':
        return accent2;
      case 'accent3':
        return accent3;
      case 'accent4':
        return accent4;
      case 'accent5':
        return accent5;
      case 'accent6':
        return accent6;
      case 'hlink':
      case 'hyperlink': // ST_ThemeColor token
        return hlink;
      case 'folHlink':
      case 'followedHyperlink': // ST_ThemeColor token
        return folHlink;
      default:
        return null;
    }
  }

  /// All accent colors as a list.
  List<String> get accents =>
      [accent1, accent2, accent3, accent4, accent5, accent6];
}

/// Theme font definitions from theme1.xml.
class DocxThemeFonts {
  /// Major font (used for headings).
  final String majorLatin;
  final String majorEastAsia;
  final String majorComplexScript;

  /// Minor font (used for body text).
  final String minorLatin;
  final String minorEastAsia;
  final String minorComplexScript;

  /// Hebrew-specific theme font from `<a:font script="Hebr">` inside the
  /// major/minor font definition (13-theme.md E2). Word lets a theme override
  /// the generic complex-script font (`<a:cs>`) per script; for Hebrew — this
  /// package's primary RTL target — that override is what `w:cstheme` should
  /// resolve to. Empty when the theme has no Hebrew-specific entry (then the
  /// generic `<a:cs>` font is used). Other scripts (Arabic/CJK) still fall back
  /// to `<a:cs>` — a documented narrowing of the full per-script model.
  final String majorHebrew;
  final String minorHebrew;

  const DocxThemeFonts({
    this.majorLatin = 'Calibri Light',
    this.majorEastAsia = '',
    this.majorComplexScript = '',
    this.minorLatin = 'Calibri',
    this.minorEastAsia = '',
    this.minorComplexScript = '',
    this.majorHebrew = '',
    this.minorHebrew = '',
  });

  /// Gets the font for headings.
  String get headingFont => majorLatin;

  /// Gets the font for body text.
  String get bodyFont => minorLatin;

  /// Gets a font by theme reference name (e.g. 'majorHAnsi').
  String? getFont(String themeFontName) {
    switch (themeFontName) {
      case 'majorHAnsi':
      case 'majorAscii':
        return majorLatin;
      case 'majorEastAsia':
        return majorEastAsia;
      case 'majorBidi':
        // Hebrew-specific override wins over the generic `<a:cs>` font for this
        // package's complex (Hebrew) text (13-theme.md E2).
        return majorHebrew.isNotEmpty ? majorHebrew : majorComplexScript;
      case 'minorHAnsi':
      case 'minorAscii':
        return minorLatin;
      case 'minorEastAsia':
        return minorEastAsia;
      case 'minorBidi':
        return minorHebrew.isNotEmpty ? minorHebrew : minorComplexScript;
      default:
        return null;
    }
  }
}

/// Latent style definition for styles not explicitly defined.
class LatentStyleDef {
  final String name;
  final bool semiHidden;
  final bool unhideWhenUsed;
  final int? uiPriority;
  final bool qFormat;

  const LatentStyleDef({
    required this.name,
    this.semiHidden = false,
    this.unhideWhenUsed = false,
    this.uiPriority,
    this.qFormat = false,
  });
}

/// Numbering definition from numbering.xml.
class DocxNumberingDef {
  /// Abstract numbering ID.
  final int abstractNumId;

  /// Numbering ID (used in paragraphs).
  final int numId;

  /// Level definitions (0-8).
  final List<DocxNumberingLevel> levels;

  const DocxNumberingDef({
    required this.abstractNumId,
    required this.numId,
    this.levels = const [],
  });
}

/// A single level in a numbering definition.
class DocxNumberingLevel {
  /// Level index (0-8).
  final int level;

  /// Numbering format (decimal, bullet, lowerLetter, etc.).
  final String numFmt;

  /// Level text pattern (e.g., "%1.", "%1.%2").
  final String? lvlText;

  /// Start value.
  final int start;

  /// `w:isLgl` — legal numbering: every component of [lvlText] is rendered in
  /// decimal regardless of each referenced level's own [numFmt].
  final bool isLgl;

  /// `w:suff` — the character that follows the number: `tab` (Word default),
  /// `space`, or `nothing`. Null means unspecified (treated as `tab`).
  final String? suff;

  /// `w:lvlJc` — justification of the number itself within the indent
  /// (`left`/`start`, `center`, `right`/`end`). RTL lists commonly use `right`.
  final String? lvlJc;

  /// `w:lvlRestart` — the 1-based level whose advance restarts this level's
  /// counter. `0` means this level never restarts; null is Word's default
  /// (restart whenever any lower-numbered level advances).
  final int? lvlRestart;

  /// Indentation left (twips).
  final int? indentLeft;

  /// Hanging indent (twips).
  final int? hanging;

  /// Bullet character (for bullet lists).
  final String? bulletChar;

  /// Font for bullet character.
  final String? bulletFont;

  /// Theme font reference.
  final String? themeFont;

  /// Theme color reference.
  final String? themeColor;
  final String? themeTint;
  final String? themeShade;

  /// Picture bullet ID (references a numPicBullet definition).
  final int? picBulletId;

  /// Picture bullet image bytes (resolved from media folder).
  final Uint8List? picBulletImage;

  /// Explicit label formatting from the level's `w:rPr` (08-numbering.md item
  /// 22): an explicit `w:color w:val` hex, half-point `w:sz`, and bold/italic.
  /// Drive the marker's `TextStyle` so a coloured/bold number (common in Hebrew
  /// sacred texts) renders, not just the body style.
  final String? colorHex;
  final double? fontSize;
  final bool? bold;
  final bool? italic;

  const DocxNumberingLevel({
    required this.level,
    required this.numFmt,
    this.lvlText,
    this.start = 1,
    this.isLgl = false,
    this.suff,
    this.lvlJc,
    this.lvlRestart,
    this.indentLeft,
    this.hanging,
    this.bulletChar,
    this.bulletFont,
    this.themeFont,
    this.themeColor,
    this.themeTint,
    this.themeShade,
    this.picBulletId,
    this.picBulletImage,
    this.colorHex,
    this.fontSize,
    this.bold,
    this.italic,
  });

  DocxNumberingLevel copyWith({int? start}) => DocxNumberingLevel(
        level: level,
        numFmt: numFmt,
        lvlText: lvlText,
        start: start ?? this.start,
        isLgl: isLgl,
        suff: suff,
        lvlJc: lvlJc,
        lvlRestart: lvlRestart,
        indentLeft: indentLeft,
        hanging: hanging,
        bulletChar: bulletChar,
        bulletFont: bulletFont,
        themeFont: themeFont,
        themeColor: themeColor,
        themeTint: themeTint,
        themeShade: themeShade,
        picBulletId: picBulletId,
        picBulletImage: picBulletImage,
        colorHex: colorHex,
        fontSize: fontSize,
        bold: bold,
        italic: italic,
      );

  /// Returns true if this is a bullet level.
  bool get isBullet => numFmt == 'bullet';

  /// Returns true if this is a numbered level.
  bool get isNumbered => !isBullet;

  /// Returns true if this is an image bullet level.
  bool get isImageBullet => picBulletId != null || picBulletImage != null;
}

/// Section properties from document.xml.
class DocxSectionProperties {
  /// Page width in twips.
  final int pageWidth;

  /// Page height in twips.
  final int pageHeight;

  /// Page orientation.
  final DocxPageOrientation orientation;

  /// Margins in twips.
  final int marginTop;
  final int marginBottom;
  final int marginLeft;
  final int marginRight;
  final int marginHeader;
  final int marginFooter;

  /// Gutter size in twips (extra margin for binding).
  final int gutter;

  /// Gutter position ('left' or 'top').
  final String gutterPosition;

  /// Number of columns.
  final int columns;

  /// Space between columns in twips.
  final int columnSpace;

  /// Whether columns have equal width.
  final bool equalColumnWidth;

  /// Individual column widths (if not equal).
  final List<int>? columnWidths;

  /// Line between columns.
  final bool lineBetweenColumns;

  /// Section type (continuous, nextPage, evenPage, oddPage).
  final String sectionType;

  /// Header/footer references.
  final String? headerDefault;
  final String? headerFirst;
  final String? headerEven;
  final String? footerDefault;
  final String? footerFirst;
  final String? footerEven;

  /// Whether first page has different header/footer.
  final bool titlePage;

  const DocxSectionProperties({
    this.pageWidth = 12240, // Letter width
    this.pageHeight = 15840, // Letter height
    this.orientation = DocxPageOrientation.portrait,
    this.marginTop = 1440,
    this.marginBottom = 1440,
    this.marginLeft = 1440,
    this.marginRight = 1440,
    this.marginHeader = 720,
    this.marginFooter = 720,
    this.gutter = 0,
    this.gutterPosition = 'left',
    this.columns = 1,
    this.columnSpace = 720,
    this.equalColumnWidth = true,
    this.columnWidths,
    this.lineBetweenColumns = false,
    this.sectionType = 'nextPage',
    this.headerDefault,
    this.headerFirst,
    this.headerEven,
    this.footerDefault,
    this.footerFirst,
    this.footerEven,
    this.titlePage = false,
  });

  /// Creates from page size enum.
  factory DocxSectionProperties.fromPageSize(DocxPageSize size) {
    switch (size) {
      case DocxPageSize.letter:
        return const DocxSectionProperties(pageWidth: 12240, pageHeight: 15840);
      case DocxPageSize.a4:
        return const DocxSectionProperties(pageWidth: 11906, pageHeight: 16838);
      case DocxPageSize.legal:
        return const DocxSectionProperties(pageWidth: 12240, pageHeight: 20160);
      case DocxPageSize.tabloid:
        return const DocxSectionProperties(pageWidth: 12240, pageHeight: 15840);

      case DocxPageSize.custom:
        return const DocxSectionProperties();
    }
  }
}
