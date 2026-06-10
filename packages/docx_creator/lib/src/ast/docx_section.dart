import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../core/defaults.dart';
import '../core/enums.dart';
import 'docx_background_image.dart';
import 'docx_block.dart';
import 'docx_image.dart';
import 'docx_inline.dart';
import 'docx_node.dart';
import 'docx_table.dart';

/// Customizable heading style.
///
/// ```dart
/// final h1Style = DocxHeadingStyle(
///   fontSize: 28,
///   color: DocxColor('#2E74B5'),
///   fontFamily: 'Georgia',
///   spacingBefore: 300,
/// );
///
/// DocxParagraph.heading(DocxHeadingLevel.h1, 'Title', style: h1Style)
/// ```
class DocxHeadingStyle {
  final double fontSize;
  final DocxColor? color;
  final String? fontFamily;
  final bool bold;
  final int spacingBefore;
  final int spacingAfter;
  final DocxAlign align;

  const DocxHeadingStyle({
    this.fontSize = 24,
    this.color,
    this.fontFamily,
    this.bold = true,
    this.spacingBefore = 240,
    this.spacingAfter = 120,
    this.align = DocxAlign.left,
  });

  /// Default styles for each heading level
  static DocxHeadingStyle forLevel(DocxHeadingLevel level) {
    switch (level) {
      case DocxHeadingLevel.h1:
        return const DocxHeadingStyle(fontSize: 24, spacingBefore: 300);
      case DocxHeadingLevel.h2:
        return const DocxHeadingStyle(fontSize: 20, spacingBefore: 240);
      case DocxHeadingLevel.h3:
        return const DocxHeadingStyle(fontSize: 16, spacingBefore: 200);
      case DocxHeadingLevel.h4:
        return const DocxHeadingStyle(fontSize: 14, spacingBefore: 160);
      case DocxHeadingLevel.h5:
        return const DocxHeadingStyle(fontSize: 12, spacingBefore: 120);
      case DocxHeadingLevel.h6:
        return const DocxHeadingStyle(fontSize: 11, spacingBefore: 100);
    }
  }

  DocxHeadingStyle copyWith({
    double? fontSize,
    DocxColor? color,
    String? fontFamily,
    bool? bold,
    int? spacingBefore,
    int? spacingAfter,
    DocxAlign? align,
  }) {
    return DocxHeadingStyle(
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      fontFamily: fontFamily ?? this.fontFamily,
      bold: bold ?? this.bold,
      spacingBefore: spacingBefore ?? this.spacingBefore,
      spacingAfter: spacingAfter ?? this.spacingAfter,
      align: align ?? this.align,
    );
  }
}

/// Document section with page layout and headers/footers.
///
/// ```dart
/// DocxSectionDef(
///   backgroundColor: DocxColor('#F5F5F5'),
///   header: DocxHeader.text('My Document'),
///   footer: DocxFooter.pageNumbers(),
/// )
/// ```
class DocxSectionDef extends DocxSection {
  final DocxPageOrientation orientation;
  final DocxPageSize pageSize;
  final int? customWidth;
  final int? customHeight;
  final int marginTop;
  final int marginBottom;
  final int marginLeft;
  final int marginRight;

  /// מרחק הכותרת העליונה (header) מקצה העמוד העליון (w:header, twips).
  /// בד"כ קטן מ-[marginTop] — ה-header יושב באזור השוליים העליונים.
  final int marginHeader;

  /// מרחק הכותרת התחתונה (footer) מקצה העמוד התחתון (w:footer, twips).
  /// בד"כ קטן מ-[marginBottom] — ה-footer יושב באזור השוליים התחתונים.
  final int marginFooter;

  /// מרווח כריכה (w:gutter, twips) — נוסף לשוליים בצד הכריכה (ברירת מחדל: שמאל).
  final int gutter;

  final DocxSectionBreak breakType;

  /// The primary (`default`) header/footer — used on every page unless a
  /// first-page or even-page variant applies.
  final DocxHeader? header;
  final DocxFooter? footer;

  /// First-page variant (`w:type="first"`), active when [titlePage] is set.
  final DocxHeader? firstHeader;
  final DocxFooter? firstFooter;

  /// Even-page variant (`w:type="even"`), active when the document's
  /// `evenAndOddHeaders` setting is on.
  final DocxHeader? evenHeader;
  final DocxFooter? evenFooter;

  /// Page-number display format for this section (`w:pgNumType w:fmt`).
  final DocxPageNumberFormat pageNumberFormat;

  /// Starting page number for this section (`w:pgNumType w:start`); null means
  /// the numbering continues from the previous section.
  final int? pageNumberStart;

  /// Heading level whose number prefixes the page number (`w:chapStyle`), or
  /// null for no chapter prefix.
  final int? chapterStyleLevel;

  /// Separator between chapter number and page number (`w:chapSep`).
  final DocxChapterSeparator chapterSeparator;

  /// Whether the first page uses the [firstHeader]/[firstFooter] (`w:titlePg`).
  final bool titlePage;

  /// Background color for all pages in this section.
  final DocxColor? backgroundColor;

  /// Background image for all pages in this section.
  ///
  /// If both [backgroundColor] and [backgroundImage] are set,
  /// the image will be rendered on top of the color.
  final DocxBackgroundImage? backgroundImage;

  const DocxSectionDef({
    this.orientation = DocxPageOrientation.portrait,
    this.pageSize = DocxPageSize.letter,
    this.customWidth,
    this.customHeight,
    this.marginTop = kDefaultMarginTop,
    this.marginBottom = kDefaultMarginBottom,
    this.marginLeft = kDefaultMarginLeft,
    this.marginRight = kDefaultMarginRight,
    this.marginHeader = kDefaultHeaderDistance,
    this.marginFooter = kDefaultFooterDistance,
    this.gutter = 0,
    this.breakType = DocxSectionBreak.nextPage,
    this.header,
    this.footer,
    this.firstHeader,
    this.firstFooter,
    this.evenHeader,
    this.evenFooter,
    this.pageNumberFormat = DocxPageNumberFormat.decimal,
    this.pageNumberStart,
    this.chapterStyleLevel,
    this.chapterSeparator = DocxChapterSeparator.hyphen,
    this.titlePage = false,
    this.backgroundColor,
    this.backgroundImage,
    super.id,
  });

  /// The header that applies to a page, given its position. [isFirstPage] is
  /// relative to the section; [isEvenPage] uses the document's even/odd setting.
  DocxHeader? headerFor({bool isFirstPage = false, bool isEvenPage = false}) {
    if (isFirstPage && titlePage && firstHeader != null) return firstHeader;
    if (isEvenPage && evenHeader != null) return evenHeader;
    return header;
  }

  /// The footer that applies to a page — see [headerFor].
  DocxFooter? footerFor({bool isFirstPage = false, bool isEvenPage = false}) {
    if (isFirstPage && titlePage && firstFooter != null) return firstFooter;
    if (isEvenPage && evenFooter != null) return evenFooter;
    return footer;
  }

  /// Returns a copy with specified modifications.
  DocxSectionDef copyWith({
    DocxPageOrientation? orientation,
    DocxPageSize? pageSize,
    int? customWidth,
    int? customHeight,
    int? marginTop,
    int? marginBottom,
    int? marginLeft,
    int? marginRight,
    int? marginHeader,
    int? marginFooter,
    int? gutter,
    DocxSectionBreak? breakType,
    DocxHeader? header,
    DocxFooter? footer,
    DocxHeader? firstHeader,
    DocxFooter? firstFooter,
    DocxHeader? evenHeader,
    DocxFooter? evenFooter,
    DocxPageNumberFormat? pageNumberFormat,
    int? pageNumberStart,
    int? chapterStyleLevel,
    DocxChapterSeparator? chapterSeparator,
    bool? titlePage,
    DocxColor? backgroundColor,
    DocxBackgroundImage? backgroundImage,
  }) {
    return DocxSectionDef(
      orientation: orientation ?? this.orientation,
      pageSize: pageSize ?? this.pageSize,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      marginHeader: marginHeader ?? this.marginHeader,
      marginFooter: marginFooter ?? this.marginFooter,
      gutter: gutter ?? this.gutter,
      breakType: breakType ?? this.breakType,
      header: header ?? this.header,
      footer: footer ?? this.footer,
      firstHeader: firstHeader ?? this.firstHeader,
      firstFooter: firstFooter ?? this.firstFooter,
      evenHeader: evenHeader ?? this.evenHeader,
      evenFooter: evenFooter ?? this.evenFooter,
      pageNumberFormat: pageNumberFormat ?? this.pageNumberFormat,
      pageNumberStart: pageNumberStart ?? this.pageNumberStart,
      chapterStyleLevel: chapterStyleLevel ?? this.chapterStyleLevel,
      chapterSeparator: chapterSeparator ?? this.chapterSeparator,
      titlePage: titlePage ?? this.titlePage,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      id: id,
    );
  }

  int get effectiveWidth {
    if (pageSize == DocxPageSize.custom && customWidth != null) {
      return customWidth!;
    }
    switch (pageSize) {
      case DocxPageSize.letter:
        return 12240;
      case DocxPageSize.a4:
        return 11906;
      case DocxPageSize.legal:
        return 12240;
      case DocxPageSize.tabloid:
        return 15840;
      case DocxPageSize.custom:
        return customWidth ?? 12240;
    }
  }

  int get effectiveHeight {
    if (pageSize == DocxPageSize.custom && customHeight != null) {
      return customHeight!;
    }
    switch (pageSize) {
      case DocxPageSize.letter:
        return 15840;
      case DocxPageSize.a4:
        return 16838;
      case DocxPageSize.legal:
        return 20160;
      case DocxPageSize.tabloid:
        return 24480;
      case DocxPageSize.custom:
        return customHeight ?? 15840;
    }
  }

  @override
  void accept(DocxVisitor visitor) => visitor.visitSection(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:sectPr',
      nest: () {
        final isLandscape = orientation == DocxPageOrientation.landscape;
        builder.element(
          'w:pgSz',
          nest: () {
            builder.attribute(
              'w:w',
              (isLandscape ? effectiveHeight : effectiveWidth).toString(),
            );
            builder.attribute(
              'w:h',
              (isLandscape ? effectiveWidth : effectiveHeight).toString(),
            );
            if (isLandscape) builder.attribute('w:orient', 'landscape');
          },
        );
        builder.element(
          'w:pgMar',
          nest: () {
            builder.attribute('w:top', marginTop.toString());
            builder.attribute('w:right', marginRight.toString());
            builder.attribute('w:bottom', marginBottom.toString());
            builder.attribute('w:left', marginLeft.toString());
            builder.attribute('w:header', marginHeader.toString());
            builder.attribute('w:footer', marginFooter.toString());
            if (gutter != 0) builder.attribute('w:gutter', gutter.toString());
          },
        );
      },
    );
  }
}

/// Header content for a document section.
///
/// ## Simple
/// ```dart
/// DocxHeader.text('My Document')
/// ```
///
/// ## Styled
/// ```dart
/// DocxHeader.styled('Title', color: DocxColor.blue, fontSize: 14)
/// ```
///
/// ## Rich Content
/// ```dart
/// DocxHeader(children: [
///   DocxParagraph(children: [
///     DocxText.bold('Company Name'),
///     DocxText(' - Confidential'),
///   ]),
/// ])
/// ```
class DocxHeader extends DocxSection {
  final List<DocxBlock> children;

  const DocxHeader({required this.children, super.id});

  /// Simple text header.
  factory DocxHeader.text(String text, {DocxAlign align = DocxAlign.center}) {
    return DocxHeader(
      children: [
        DocxParagraph(align: align, children: [DocxText(text)]),
      ],
    );
  }

  /// Styled text header.
  factory DocxHeader.styled(
    String text, {
    DocxColor? color,
    double? fontSize,
    String? fontFamily,
    bool bold = false,
    DocxAlign align = DocxAlign.center,
  }) {
    return DocxHeader(
      children: [
        DocxParagraph(
          align: align,
          children: [
            DocxText(
              text,
              color: color,
              fontSize: fontSize,
              fontFamily: fontFamily,
              fontWeight: bold ? DocxFontWeight.bold : DocxFontWeight.normal,
            ),
          ],
        ),
      ],
    );
  }

  DocxHeader copyWith({List<DocxBlock>? children}) {
    return DocxHeader(children: children ?? this.children, id: id);
  }

  @override
  void accept(DocxVisitor visitor) => visitor.visitHeader(this);

  @override
  void buildXml(XmlBuilder builder) {
    for (var child in children) {
      child.buildXml(builder);
    }
  }
}

/// Footer content for a document section.
///
/// ## Simple
/// ```dart
/// DocxFooter.text('© 2024 Company')
/// ```
///
/// ## Page Numbers
/// ```dart
/// DocxFooter.pageNumbers()
/// ```
///
/// ## Styled
/// ```dart
/// DocxFooter.styled('Confidential', color: DocxColor.gray)
/// ```
class DocxFooter extends DocxSection {
  final List<DocxBlock> children;

  const DocxFooter({required this.children, super.id});

  /// Simple text footer.
  factory DocxFooter.text(String text, {DocxAlign align = DocxAlign.center}) {
    return DocxFooter(
      children: [
        DocxParagraph(align: align, children: [DocxText(text)]),
      ],
    );
  }

  /// Styled text footer.
  factory DocxFooter.styled(
    String text, {
    DocxColor? color,
    double? fontSize,
    String? fontFamily,
    bool bold = false,
    DocxAlign align = DocxAlign.center,
  }) {
    return DocxFooter(
      children: [
        DocxParagraph(
          align: align,
          children: [
            DocxText(
              text,
              color: color,
              fontSize: fontSize,
              fontFamily: fontFamily,
              fontWeight: bold ? DocxFontWeight.bold : DocxFontWeight.normal,
            ),
          ],
        ),
      ],
    );
  }

  /// Footer with page numbers.
  factory DocxFooter.pageNumbers({DocxAlign align = DocxAlign.center}) {
    return DocxFooter(
      children: [
        DocxParagraph(
          align: align,
          children: [
            DocxText('Page '),
            DocxPageNumber(),
            DocxText(' of '),
            DocxPageCount(),
          ],
        ),
      ],
    );
  }

  /// Footer with an image on the left and text on the right using an invisible table.
  factory DocxFooter.imageAndText({
    required Uint8List imageBytes,
    required String imageExtension,
    required String text,
    double imageWidth = 40,
    double imageHeight = 40,
    DocxAlign textAlign = DocxAlign.right,
  }) {
    const borderNone = DocxBorderSide(
      style: DocxBorder.none,
      size: 0,
      color: DocxColor.white,
    );

    const tableStyle = DocxTableStyle(
      borderTop: borderNone,
      borderBottom: borderNone,
      borderLeft: borderNone,
      borderRight: borderNone,
      borderInsideH: borderNone,
      borderInsideV: borderNone,
    );

    return DocxFooter(
      children: [
        DocxTable(
          width: 5000, // 100% in pct
          widthType: DocxWidthType.pct,
          style: tableStyle,
          rows: [
            DocxTableRow(
              cells: [
                DocxTableCell(
                  verticalAlign: DocxVerticalAlign.center,
                  children: [
                    DocxImage(
                      bytes: imageBytes,
                      extension: imageExtension,
                      width: imageWidth,
                      height: imageHeight,
                      align: DocxAlign.left,
                    ),
                  ],
                ),
                DocxTableCell(
                  verticalAlign: DocxVerticalAlign.center,
                  children: [
                    DocxParagraph(
                      align: textAlign,
                      children: [DocxText(text)],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  DocxFooter copyWith({List<DocxBlock>? children}) {
    return DocxFooter(children: children ?? this.children, id: id);
  }

  @override
  void accept(DocxVisitor visitor) => visitor.visitFooter(this);

  @override
  void buildXml(XmlBuilder builder) {
    for (var child in children) {
      child.buildXml(builder);
    }
  }
}

/// Emits a minimal complex field: `begin → instrText(instr) → end`.
/// The cached result run is intentionally omitted; the viewer computes the
/// live value. Shared by the field inline nodes below.
void _buildFieldXml(XmlBuilder builder, String instr) {
  builder.element('w:r',
      nest: () => builder.element('w:fldChar',
          nest: () => builder.attribute('w:fldCharType', 'begin')));
  builder.element('w:r',
      nest: () => builder.element('w:instrText', nest: () {
            builder.attribute('xml:space', 'preserve');
            builder.text(instr);
          }));
  builder.element('w:r',
      nest: () => builder.element('w:fldChar',
          nest: () => builder.attribute('w:fldCharType', 'end')));
}

/// The `\*` field switch for a page-number [format], or '' for the default.
String _formatSwitch(DocxPageNumberFormat? format) {
  switch (format) {
    case DocxPageNumberFormat.upperRoman:
      return r' \* ROMAN';
    case DocxPageNumberFormat.lowerRoman:
      return r' \* roman';
    case DocxPageNumberFormat.upperLetter:
      return r' \* ALPHABETIC';
    case DocxPageNumberFormat.lowerLetter:
      return r' \* alphabetic';
    case DocxPageNumberFormat.decimal:
      return r' \* Arabic';
    case null:
      return '';
  }
}

/// `PAGE` field — the current page number. [format] is an explicit `\*` switch;
/// when null the rendering section's `w:pgNumType` format applies.
///
/// [cachedText] is Word's last-computed value (from the field's result run); the
/// viewer shows it until pagination supplies the live per-page number.
class DocxPageNumber extends DocxInline {
  final DocxPageNumberFormat? format;
  final String? cachedText;
  const DocxPageNumber({this.format, this.cachedText, super.id});

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) =>
      _buildFieldXml(builder, ' PAGE${_formatSwitch(format)} ');
}

/// `NUMPAGES` (whole document) or `SECTIONPAGES` ([sectionScope] = true) field.
class DocxPageCount extends DocxInline {
  final bool sectionScope;
  final DocxPageNumberFormat? format;
  final String? cachedText;
  const DocxPageCount(
      {this.sectionScope = false, this.format, this.cachedText, super.id});

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) => _buildFieldXml(builder,
      ' ${sectionScope ? 'SECTIONPAGES' : 'NUMPAGES'}${_formatSwitch(format)} ');
}

/// `PAGEREF` field — the page number on which [bookmark] resides.
class DocxPageRef extends DocxInline {
  final String bookmark;

  /// `\h` switch — render as a hyperlink to the bookmark.
  final bool hyperlink;
  final DocxPageNumberFormat? format;
  final String? cachedText;
  const DocxPageRef(this.bookmark,
      {this.hyperlink = false, this.format, this.cachedText, super.id});

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) => _buildFieldXml(
      builder,
      ' PAGEREF $bookmark${hyperlink ? r' \h' : ''}'
      '${_formatSwitch(format)} ');
}

/// A field the viewer does not compute (TOC, REF, DATE, …). The [cachedResult]
/// inlines (Word's last-computed value) are shown verbatim so the text is not
/// lost, while [instruction] preserves the original field code.
class DocxUnknownField extends DocxInline {
  final String instruction;
  final List<DocxInline> cachedResult;
  const DocxUnknownField(this.instruction,
      {this.cachedResult = const [], super.id});

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:r',
        nest: () => builder.element('w:fldChar',
            nest: () => builder.attribute('w:fldCharType', 'begin')));
    builder.element('w:r',
        nest: () => builder.element('w:instrText', nest: () {
              builder.attribute('xml:space', 'preserve');
              builder.text(instruction);
            }));
    builder.element('w:r',
        nest: () => builder.element('w:fldChar',
            nest: () => builder.attribute('w:fldCharType', 'separate')));
    for (final inline in cachedResult) {
      inline.buildXml(builder);
    }
    builder.element('w:r',
        nest: () => builder.element('w:fldChar',
            nest: () => builder.attribute('w:fldCharType', 'end')));
  }
}

/// A bookmark anchor (`w:bookmarkStart`). Zero-width marker used to resolve
/// [DocxPageRef] targets to a page during pagination.
class DocxBookmark extends DocxInline {
  final String name;
  const DocxBookmark(this.name, {super.id});

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:bookmarkStart', nest: () {
      builder.attribute('w:id', '0');
      builder.attribute('w:name', name);
    });
  }
}
