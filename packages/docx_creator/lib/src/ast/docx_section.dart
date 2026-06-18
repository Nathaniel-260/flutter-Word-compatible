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

/// A single explicit column definition within a [DocxColumns] layout
/// (`w:col`).
class DocxColumn {
  /// Column width in twips.
  final int? widthTwips;

  /// Space after this column in twips.
  final int? spaceTwips;

  const DocxColumn({this.widthTwips, this.spaceTwips});
}

/// Multi-column layout for a section (`w:cols`).
class DocxColumns {
  /// Number of columns (`w:num`).
  final int count;

  /// Default space between columns in twips (`w:space`).
  final int spaceTwips;

  /// Whether all columns have equal width (`w:equalWidth`).
  final bool equalWidth;

  /// Explicit per-column widths/spacing (`w:col`), when not equal width.
  final List<DocxColumn>? explicit;

  /// Whether a separator line is drawn between columns (`w:sep`).
  final bool separator;

  const DocxColumns({
    this.count = 1,
    this.spaceTwips = 720,
    this.equalWidth = true,
    this.explicit,
    this.separator = false,
  });
}

/// Page border definition for a section (`w:pgBorders`).
class DocxPageBorders {
  final DocxPageBorderDisplay display;
  final DocxPageBorderOffsetFrom offsetFrom;

  /// Whether the border is drawn behind text (`w:zOrder="back"`).
  final bool zOrderBack;

  final DocxBorderSide? top;
  final DocxBorderSide? bottom;
  final DocxBorderSide? left;
  final DocxBorderSide? right;

  const DocxPageBorders({
    this.display = DocxPageBorderDisplay.allPages,
    this.offsetFrom = DocxPageBorderOffsetFrom.text,
    this.zOrderBack = false,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  bool get hasAnySide =>
      top != null || bottom != null || left != null || right != null;
}

/// Line numbering settings for a section (`w:lnNumType`).
class DocxLineNumbering {
  /// Show every Nth line number (`w:countBy`).
  final int? countBy;

  /// Starting line number (`w:start`).
  final int? start;

  /// Distance from text to the numbers in twips (`w:distance`).
  final int? distance;

  /// When numbering restarts (`w:restart`).
  final DocxLineNumberRestart? restart;

  const DocxLineNumbering({
    this.countBy,
    this.start,
    this.distance,
    this.restart,
  });
}

/// Footnote/endnote properties for a section (`w:footnotePr`/`w:endnotePr`).
class DocxNoteProperties {
  /// Number format for the notes.
  final DocxPageNumberFormat? format;

  /// When numbering restarts (`w:numRestart`).
  final DocxNoteNumberRestart? numRestart;

  /// Where the notes are placed (`w:pos`).
  final DocxNotePosition? position;

  const DocxNoteProperties({this.format, this.numRestart, this.position});
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

  /// Multi-column layout (`w:cols`); null means a single column.
  final DocxColumns? columns;

  /// Vertical alignment of body content within the page (`w:vAlign`).
  final DocxSectionVAlign vAlign;

  /// Page borders (`w:pgBorders`).
  final DocxPageBorders? pageBorders;

  /// Line numbering (`w:lnNumType`).
  final DocxLineNumbering? lineNumbering;

  /// Right-to-left section (`w:bidi`): affects column order and gutter side.
  final bool isRtlSection;

  /// Place the binding gutter on the right (`w:rtlGutter`).
  final bool rtlGutter;

  /// Section footnote properties (`w:footnotePr`).
  final DocxNoteProperties? footnoteProperties;

  /// Section endnote properties (`w:endnotePr`).
  final DocxNoteProperties? endnoteProperties;

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
    this.columns,
    this.vAlign = DocxSectionVAlign.top,
    this.pageBorders,
    this.lineNumbering,
    this.isRtlSection = false,
    this.rtlGutter = false,
    this.footnoteProperties,
    this.endnoteProperties,
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
    DocxColumns? columns,
    DocxSectionVAlign? vAlign,
    DocxPageBorders? pageBorders,
    DocxLineNumbering? lineNumbering,
    bool? isRtlSection,
    bool? rtlGutter,
    DocxNoteProperties? footnoteProperties,
    DocxNoteProperties? endnoteProperties,
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
      columns: columns ?? this.columns,
      vAlign: vAlign ?? this.vAlign,
      pageBorders: pageBorders ?? this.pageBorders,
      lineNumbering: lineNumbering ?? this.lineNumbering,
      isRtlSection: isRtlSection ?? this.isRtlSection,
      rtlGutter: rtlGutter ?? this.rtlGutter,
      footnoteProperties: footnoteProperties ?? this.footnoteProperties,
      endnoteProperties: endnoteProperties ?? this.endnoteProperties,
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
        // footnotePr / endnotePr come first in CT_SectPr.
        if (footnoteProperties != null) {
          _buildNoteProperties(builder, 'w:footnotePr', footnoteProperties!);
        }
        if (endnoteProperties != null) {
          _buildNoteProperties(builder, 'w:endnotePr', endnoteProperties!);
        }

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

        // Page borders
        if (pageBorders != null && pageBorders!.hasAnySide) {
          builder.element('w:pgBorders', nest: () {
            builder.attribute('w:offsetFrom', pageBorders!.offsetFrom.xmlValue);
            builder.attribute('w:display', pageBorders!.display.xmlValue);
            if (pageBorders!.zOrderBack) {
              builder.attribute('w:zOrder', 'back');
            }
            _buildSectionBorder(builder, 'w:top', pageBorders!.top);
            _buildSectionBorder(builder, 'w:left', pageBorders!.left);
            _buildSectionBorder(builder, 'w:bottom', pageBorders!.bottom);
            _buildSectionBorder(builder, 'w:right', pageBorders!.right);
          });
        }

        // Line numbering
        if (lineNumbering != null) {
          builder.element('w:lnNumType', nest: () {
            final ln = lineNumbering!;
            if (ln.countBy != null) {
              builder.attribute('w:countBy', ln.countBy.toString());
            }
            if (ln.start != null) {
              builder.attribute('w:start', ln.start.toString());
            }
            if (ln.distance != null) {
              builder.attribute('w:distance', ln.distance.toString());
            }
            if (ln.restart != null) {
              builder.attribute('w:restart', ln.restart!.xmlValue);
            }
          });
        }

        // Columns
        if (columns != null) {
          final cols = columns!;
          builder.element('w:cols', nest: () {
            builder.attribute('w:num', cols.count.toString());
            builder.attribute('w:space', cols.spaceTwips.toString());
            builder.attribute('w:equalWidth', cols.equalWidth ? '1' : '0');
            if (cols.separator) builder.attribute('w:sep', '1');
            if (!cols.equalWidth && cols.explicit != null) {
              for (final col in cols.explicit!) {
                builder.element('w:col', nest: () {
                  if (col.widthTwips != null) {
                    builder.attribute('w:w', col.widthTwips.toString());
                  }
                  if (col.spaceTwips != null) {
                    builder.attribute('w:space', col.spaceTwips.toString());
                  }
                });
              }
            }
          });
        }

        // Vertical alignment (omit the top default)
        if (vAlign != DocxSectionVAlign.top) {
          builder.element('w:vAlign', nest: () {
            builder.attribute('w:val', vAlign.xmlValue);
          });
        }

        // RTL section + gutter
        if (isRtlSection) builder.element('w:bidi');
        if (rtlGutter) builder.element('w:rtlGutter');
      },
    );
  }

  void _buildNoteProperties(
      XmlBuilder builder, String tag, DocxNoteProperties np) {
    builder.element(tag, nest: () {
      if (np.position != null) {
        builder.element('w:pos', nest: () {
          builder.attribute('w:val', np.position!.xmlValue);
        });
      }
      if (np.format != null) {
        // The DocxPageNumberFormat enum names match the OOXML numFmt tokens.
        builder.element('w:numFmt', nest: () {
          builder.attribute('w:val', np.format!.name);
        });
      }
      if (np.numRestart != null) {
        builder.element('w:numRestart', nest: () {
          builder.attribute('w:val', np.numRestart!.xmlValue);
        });
      }
    });
  }

  void _buildSectionBorder(
      XmlBuilder builder, String tag, DocxBorderSide? side) {
    if (side == null) return;
    builder.element(tag, nest: () {
      builder.attribute('w:val', side.xmlStyle);
      builder.attribute('w:sz', side.size.toString());
      builder.attribute('w:space', side.space.toString());
      builder.attribute(
          'w:color', side.color == DocxColor.auto ? 'auto' : side.color.hex);
    });
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
    case DocxPageNumberFormat.hebrew1:
    case DocxPageNumberFormat.hebrew2:
      // Hebrew numbering has no `\*` field-switch mnemonic; it is carried by the
      // section's `w:pgNumType w:fmt`, so the field instruction adds nothing.
      return '';
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

/// `STYLEREF` field — the text of the nearest paragraph carrying [styleName]
/// (Plan §K.3). Common in the running heads of reference books (a dictionary or
/// a religious text shows the current entry/chapter in the header).
///
/// The value is **pagination-dependent**, like `PAGE`: by default it is the text
/// of the *first* paragraph of that style on the current page; [useLastOnPage]
/// (the `\l` switch) selects the *last* such paragraph on the page instead.
/// (Word: "\l — inserts the text of the last paragraph … on the page, instead of
/// the first.") When no such paragraph appears on the page the value carried in
/// from before it is used; when pagination cannot resolve it at all the
/// [cachedText] (Word's last-computed value) is shown so the header is never
/// blank.
///
/// [styleName] is the value Word stores in the field — usually the style's
/// display name (e.g. `Heading 1`), sometimes its id; the viewer matches either.
class DocxStyleRef extends DocxInline {
  final String styleName;

  /// `\l` switch — use the *last* matching paragraph on the page rather than the
  /// default *first*. The classic dictionary header pairs a default STYLEREF
  /// (first entry on the page) with a `\l` one (last entry on the page).
  final bool useLastOnPage;

  final String? cachedText;

  const DocxStyleRef(
    this.styleName, {
    this.useLastOnPage = false,
    this.cachedText,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    // Quote the style name so a multi-word name (e.g. "Heading 1") round-trips.
    final l = useLastOnPage ? r' \l' : '';
    _buildFieldXml(builder, ' STYLEREF "$styleName"$l ');
  }
}
