import 'package:xml/xml.dart';

import '../core/enums.dart';
import 'docx_block.dart';
import 'docx_inline.dart';
import 'docx_node.dart';

/// Writes a [DocxCellMargins] as a `w:tblCellMar`/`w:tcMar` element ([tag]),
/// emitting only the sides that are set (each as a `dxa` width).
void _buildCellMargins(XmlBuilder builder, String tag, DocxCellMargins m) {
  builder.element(tag, nest: () {
    void side(String name, int? value) {
      if (value == null) return;
      builder.element(name, nest: () {
        builder.attribute('w:w', value.toString());
        builder.attribute('w:type', 'dxa');
      });
    }

    side('w:top', m.top);
    side('w:left', m.left);
    side('w:bottom', m.bottom);
    side('w:right', m.right);
  });
}

/// Table styling options.
///
/// Use these to create professional looking tables.
class DocxTableStyle {
  /// Border style for all borders.
  final DocxBorder border;

  /// Border color (hex).
  final String borderColor;

  /// Border width in eighths of a point (4 = 0.5pt, 8 = 1pt).
  final int borderWidth;

  /// Header row background color.
  final String? headerFill;

  /// Alternating row colors (zebra striping).
  final String? evenRowFill;
  final String? oddRowFill;

  /// Cell padding in twips, or null to use Word defaults.
  final int? cellPadding;

  /// Detailed border overrides.
  final DocxBorderSide? borderTop;
  final DocxBorderSide? borderBottom;
  final DocxBorderSide? borderLeft;
  final DocxBorderSide? borderRight;
  final DocxBorderSide? borderInsideH;
  final DocxBorderSide? borderInsideV;

  /// Global table background color (shading).
  final String? fill;

  const DocxTableStyle({
    this.border = DocxBorder.single,
    this.borderColor = 'auto',
    this.borderWidth = 4,
    this.headerFill,
    this.evenRowFill,
    this.oddRowFill,
    this.cellPadding,
    this.borderTop,
    this.borderBottom,
    this.borderLeft,
    this.borderRight,
    this.borderInsideH,
    this.borderInsideV,
    this.fill,
  });

  /// Simple grid style with borders.
  static const grid = DocxTableStyle(
    border: DocxBorder.single,
    borderColor: 'auto',
  );

  /// Plain style with no borders.
  static const plain = DocxTableStyle(
    border: DocxBorder.none,
  );

  DocxTableStyle copyWith({
    DocxBorder? border,
    String? borderColor,
    String? headerFill,
    String? evenRowFill,
    String? oddRowFill,
    DocxBorderSide? borderTop,
    DocxBorderSide? borderBottom,
    DocxBorderSide? borderLeft,
    DocxBorderSide? borderRight,
    DocxBorderSide? borderInsideH,
    DocxBorderSide? borderInsideV,
    String? fill,
  }) {
    return DocxTableStyle(
      border: border ?? this.border,
      borderColor: borderColor ?? this.borderColor,
      headerFill: headerFill ?? this.headerFill,
      evenRowFill: evenRowFill ?? this.evenRowFill,
      oddRowFill: oddRowFill ?? this.oddRowFill,
      borderTop: borderTop ?? this.borderTop,
      borderBottom: borderBottom ?? this.borderBottom,
      borderLeft: borderLeft ?? this.borderLeft,
      borderRight: borderRight ?? this.borderRight,
      borderInsideH: borderInsideH ?? this.borderInsideH,
      borderInsideV: borderInsideV ?? this.borderInsideV,
      fill: fill ?? this.fill,
    );
  }

  /// Header highlighted with gray background.
  static const headerHighlight = DocxTableStyle(headerFill: 'E0E0E0');

  /// Zebra striping for readability.
  static const zebra = DocxTableStyle(
    headerFill: 'E0E0E0',
    evenRowFill: 'F5F5F5',
  );

  /// Professional blue header.
  static const professional = DocxTableStyle(
    headerFill: '4472C4',
    borderColor: '4472C4',
  );
}

/// Horizontal anchor position for floating tables.
enum DocxTableHAnchor {
  text,
  margin,
  page,
}

/// Vertical anchor position for floating tables.
enum DocxTableVAnchor {
  text,
  margin,
  page,
}

/// Floating table position properties.
///
/// Used to position a table relative to the page, margin, or text.
class DocxTablePosition {
  /// Horizontal anchor (what the X position is relative to).
  final DocxTableHAnchor hAnchor;

  /// Vertical anchor (what the Y position is relative to).
  final DocxTableVAnchor vAnchor;

  /// X position in twips (from the horizontal anchor).
  final int? tblpX;

  /// Y position in twips (from the vertical anchor).
  final int? tblpY;

  /// Left margin from surrounding text in twips.
  final int leftFromText;

  /// Right margin from surrounding text in twips.
  final int rightFromText;

  /// Top margin from surrounding text in twips.
  final int topFromText;

  /// Bottom margin from surrounding text in twips.
  final int bottomFromText;

  const DocxTablePosition({
    this.hAnchor = DocxTableHAnchor.margin,
    this.vAnchor = DocxTableVAnchor.text,
    this.tblpX,
    this.tblpY,
    this.leftFromText = 180,
    this.rightFromText = 180,
    this.topFromText = 0,
    this.bottomFromText = 0,
  });

  /// Center the table horizontally.
  static const centered = DocxTablePosition(
    hAnchor: DocxTableHAnchor.margin,
    tblpX: 0,
  );

  /// Align table to right margin.
  static const right = DocxTablePosition(
    hAnchor: DocxTableHAnchor.margin,
  );
}

/// Table look flags (conditional formatting).
class DocxTableLook {
  final bool firstRow;
  final bool lastRow;
  final bool firstColumn;
  final bool lastColumn;
  final bool noHBand;
  final bool noVBand;

  const DocxTableLook({
    this.firstRow = true,
    this.lastRow = false,
    this.firstColumn = true,
    this.lastColumn = false,
    this.noHBand = false,
    this.noVBand = true,
  });

  /// Calculates the hex value for w:val attribute based on flags.
  String get hex {
    int val = 0;
    if (firstRow) val |= 0x0020;
    if (lastRow) val |= 0x0040;
    if (firstColumn) val |= 0x0080;
    if (lastColumn) val |= 0x0100;
    if (noHBand) val |= 0x0200;
    if (noVBand) val |= 0x0400;
    return val.toRadixString(16).padLeft(4, '0').toUpperCase();
  }
}

/// A table element in the document.
class DocxTable extends DocxBlock {
  /// Table rows.
  final List<DocxTableRow> rows;

  /// Table styling.
  final DocxTableStyle style;

  /// Table look (conditional formatting).
  final DocxTableLook look;

  /// Table width value.
  final int? width;

  /// Table width type.
  final DocxWidthType widthType;

  /// Whether first row is a header.
  final bool hasHeader;

  /// Table horizontal alignment (left, center, right).
  final DocxAlign? alignment;

  /// Floating table position properties.
  final DocxTablePosition? position;

  /// Table style ID (e.g., "TableGrid", "MediumShading1-Accent1").
  final String? styleId;

  /// Table overlap setting (e.g., "never" for floating tables).
  final String? tblOverlap;

  /// Visual right-to-left table (`w:bidiVisual`): column order is mirrored.
  final bool bidiVisual;

  /// Sizing algorithm (`w:tblLayout`).
  final DocxTableLayout layout;

  /// Indent of the whole table from the leading margin in twips (`w:tblInd`).
  final int? indentTwips;

  /// Default cell margins for the table (`w:tblCellMar`); per-cell `w:tcMar`
  /// overrides these. Word's built-in default is left/right 108tw, top/bottom 0.
  final DocxCellMargins? defaultCellMargins;

  /// Spacing between cells in twips (`w:tblCellSpacing`); rare.
  final int? cellSpacingTwips;

  final List<int>? gridColumns;

  /// Returns effective grid columns.
  ///
  /// If [gridColumns] is set, returns it.
  /// Otherwise, calculates columns based on the first row's cells.
  /// If [width] type is auto/pct (or null), assumes ~9022 twips (A4 printable width)
  /// and distributes evenly if cell widths are missing.
  List<int> get resolvedGridColumns {
    if (gridColumns != null && gridColumns!.isNotEmpty) {
      return gridColumns!;
    }

    if (rows.isEmpty) return [];

    final firstRowCells = rows.first.cells;
    final int columnCount = firstRowCells.length;
    if (columnCount == 0) return [];

    // Check if we have explicit cell widths
    final hasCellWidths = firstRowCells.every((c) => c.width != null);
    if (hasCellWidths) {
      return firstRowCells.map((c) => c.width!).toList();
    }

    // Distribute total available width
    // Standard A4 (11906) - Margins (1440*2) = 9026. Rounding to 9022 as suggested.
    const int totalWidth = 9022;
    // For now, simple equal distribution if widths are missing
    final colWidth = (totalWidth / columnCount).floor();
    return List<int>.filled(columnCount, colWidth);
  }

  /// Whether this table is floating (has custom positioning).
  bool get isFloating => position != null;

  const DocxTable({
    required this.rows,
    this.style = const DocxTableStyle(),
    this.width,
    this.widthType = DocxWidthType.auto,
    this.hasHeader = true,
    this.alignment,
    this.position,
    this.styleId,
    this.tblOverlap,
    this.bidiVisual = false,
    this.layout = DocxTableLayout.autofit,
    this.indentTwips,
    this.defaultCellMargins,
    this.cellSpacingTwips,
    this.look = const DocxTableLook(),
    this.gridColumns,
    super.id,
  });

  /// Creates a table from a 2D list of strings.
  factory DocxTable.fromData(
    List<List<String>> data, {
    bool hasHeader = true,
    DocxTableStyle style = const DocxTableStyle(),
    String? styleId,
  }) {
    final rows = <DocxTableRow>[];
    for (int i = 0; i < data.length; i++) {
      final isHeader = hasHeader && i == 0;
      final isEven = i % 2 == 0;

      String? rowFill;
      if (isHeader && style.headerFill != null) {
        rowFill = style.headerFill;
      } else if (!isHeader) {
        rowFill = isEven ? style.evenRowFill : style.oddRowFill;
      }

      final cells = data[i]
          .map(
            (text) => DocxTableCell.text(
              text,
              isBold: isHeader,
              shadingFill: rowFill,
            ),
          )
          .toList();
      rows.add(DocxTableRow(cells: cells));
    }
    return DocxTable(
        rows: rows, style: style, hasHeader: hasHeader, styleId: styleId);
  }

  DocxTable copyWith({
    List<DocxTableRow>? rows,
    DocxTableStyle? style,
    int? width,
    DocxWidthType? widthType,
    bool? hasHeader,
    DocxAlign? alignment,
    DocxTablePosition? position,
    String? styleId,
    String? tblOverlap,
    bool? bidiVisual,
    DocxTableLayout? layout,
    int? indentTwips,
    DocxCellMargins? defaultCellMargins,
    int? cellSpacingTwips,
    DocxTableLook? look,
    List<int>? gridColumns,
  }) {
    return DocxTable(
      rows: rows ?? this.rows,
      style: style ?? this.style,
      width: width ?? this.width,
      widthType: widthType ?? this.widthType,
      hasHeader: hasHeader ?? this.hasHeader,
      alignment: alignment ?? this.alignment,
      position: position ?? this.position,
      styleId: styleId ?? this.styleId,
      tblOverlap: tblOverlap ?? this.tblOverlap,
      bidiVisual: bidiVisual ?? this.bidiVisual,
      layout: layout ?? this.layout,
      indentTwips: indentTwips ?? this.indentTwips,
      defaultCellMargins: defaultCellMargins ?? this.defaultCellMargins,
      cellSpacingTwips: cellSpacingTwips ?? this.cellSpacingTwips,
      look: look ?? this.look,
      gridColumns: gridColumns ?? this.gridColumns,
      id: id,
    );
  }

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitTable(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    builder.element(
      'w:tbl',
      nest: () {
        // Table properties
        builder.element(
          'w:tblPr',
          nest: () {
            builder.element(
              'w:tblStyle',
              nest: () {
                builder.attribute('w:val', styleId ?? 'TableGrid');
              },
            );

            // Floating table position (tblpPr must be early)
            if (position != null) {
              builder.element(
                'w:tblpPr',
                nest: () {
                  builder.attribute(
                      'w:leftFromText', position!.leftFromText.toString());
                  builder.attribute(
                      'w:rightFromText', position!.rightFromText.toString());
                  builder.attribute(
                      'w:topFromText', position!.topFromText.toString());
                  builder.attribute(
                      'w:bottomFromText', position!.bottomFromText.toString());
                  builder.attribute('w:vertAnchor', position!.vAnchor.name);
                  builder.attribute('w:horzAnchor', position!.hAnchor.name);
                  if (position!.tblpX != null) {
                    builder.attribute('w:tblpX', position!.tblpX.toString());
                  }
                  if (position!.tblpY != null) {
                    builder.attribute('w:tblpY', position!.tblpY.toString());
                  }
                },
              );
            }

            // Table Overlap (for floating tables)
            if (tblOverlap != null) {
              builder.element('w:tblOverlap', nest: () {
                builder.attribute('w:val', tblOverlap!);
              });
            }

            // Visual RTL table
            if (bidiVisual) builder.element('w:bidiVisual');

            builder.element(
              'w:tblW',
              nest: () {
                builder.attribute('w:w', (width ?? 0).toString());
                builder.attribute('w:type', widthType.name);
              },
            );

            // Table alignment (justification)
            if (alignment != null) {
              builder.element(
                'w:jc',
                nest: () {
                  builder.attribute('w:val', alignment!.xmlValue);
                },
              );
            }

            // Spacing between cells
            if (cellSpacingTwips != null) {
              builder.element('w:tblCellSpacing', nest: () {
                builder.attribute('w:w', cellSpacingTwips.toString());
                builder.attribute('w:type', 'dxa');
              });
            }

            // Table indent from the leading margin
            if (indentTwips != null) {
              builder.element('w:tblInd', nest: () {
                builder.attribute('w:w', indentTwips.toString());
                builder.attribute('w:type', 'dxa');
              });
            }

            // Borders - only emit if explicitly set or no style ID
            final hasExplicitBorders = style.borderTop != null ||
                style.borderBottom != null ||
                style.borderLeft != null ||
                style.borderRight != null ||
                style.borderInsideH != null ||
                style.borderInsideV != null;

            if (hasExplicitBorders || styleId == null) {
              builder.element(
                'w:tblBorders',
                nest: () {
                  // Helper to resolve border
                  void buildSide(String tag, DocxBorderSide? side) {
                    if (side != null) {
                      builder.element(tag, nest: () {
                        builder.attribute('w:val', side.xmlStyle);
                        builder.attribute('w:sz', side.size.toString());
                        builder.attribute('w:space', side.space.toString());
                        if (side.color != DocxColor.auto) {
                          builder.attribute('w:color', side.color.hex);
                        } else {
                          builder.attribute('w:color', 'auto');
                        }
                        if (side.themeColor != null) {
                          builder.attribute('w:themeColor', side.themeColor!);
                        }
                        if (side.themeTint != null) {
                          builder.attribute('w:themeTint', side.themeTint!);
                        }
                        if (side.themeShade != null) {
                          builder.attribute('w:themeShade', side.themeShade!);
                        }
                      });
                    } else if (styleId == null &&
                        style.border != DocxBorder.none) {
                      // Fallback to global style only if no styleId
                      _buildBorder(builder, tag);
                    }
                  }

                  buildSide('w:top', style.borderTop);
                  buildSide('w:bottom', style.borderBottom);
                  buildSide('w:left', style.borderLeft);
                  buildSide('w:right', style.borderRight);
                  buildSide('w:insideH', style.borderInsideH);
                  buildSide('w:insideV', style.borderInsideV);
                },
              );
            }

            // Table shading (global)
            if (style.fill != null) {
              builder.element('w:shd', nest: () {
                builder.attribute('w:fill', style.fill!.replaceAll('#', ''));
                builder.attribute('w:val', 'clear');
              });
            }

            // Table layout algorithm (fixed vs autofit). Word omits it for the
            // autofit default, so only emit the explicit fixed case.
            if (layout == DocxTableLayout.fixed) {
              builder.element('w:tblLayout', nest: () {
                builder.attribute('w:type', layout.xmlValue);
              });
            }

            // Default cell margins — explicit margins take priority over the
            // legacy uniform [DocxTableStyle.cellPadding].
            if (defaultCellMargins != null && !defaultCellMargins!.isEmpty) {
              _buildCellMargins(builder, 'w:tblCellMar', defaultCellMargins!);
            } else if (style.cellPadding != null) {
              final pad = DocxCellMargins(
                top: style.cellPadding,
                left: style.cellPadding,
                bottom: style.cellPadding,
                right: style.cellPadding,
              );
              _buildCellMargins(builder, 'w:tblCellMar', pad);
            }

            // Table Look (Must be last)
            builder.element('w:tblLook', nest: () {
              builder.attribute('w:val', look.hex);
              builder.attribute('w:firstRow', look.firstRow ? '1' : '0');
              builder.attribute('w:lastRow', look.lastRow ? '1' : '0');
              builder.attribute('w:firstColumn', look.firstColumn ? '1' : '0');
              builder.attribute('w:lastColumn', look.lastColumn ? '1' : '0');
              builder.attribute('w:noHBand', look.noHBand ? '1' : '0');
              builder.attribute('w:noVBand', look.noVBand ? '1' : '0');
            });
          },
        );
        // Table Grid - use preserved values or calculate from cells
        // Table Grid
        builder.element('w:tblGrid', nest: () {
          final cols = resolvedGridColumns;
          for (var colWidth in cols) {
            builder.element('w:gridCol', nest: () {
              builder.attribute('w:w', colWidth.toString());
            });
          }
        });

        // Rows
        final cols = resolvedGridColumns;
        for (int i = 0; i < rows.length; i++) {
          rows[i].buildXmlWithStyle(
            builder,
            style,
            isHeader: hasHeader && i == 0,
            isEven: i % 2 == 0,
            gridCols: cols,
          );
        }
      },
    );
  }

  void _buildBorder(XmlBuilder builder, String tag) {
    builder.element(
      tag,
      nest: () {
        builder.attribute('w:val', style.border.xmlValue);
        builder.attribute('w:sz', style.borderWidth.toString());
        builder.attribute('w:space', '0');
        builder.attribute('w:color', style.borderColor);
      },
    );
  }
}

/// A row within a [DocxTable].
class DocxTableRow extends DocxNode {
  /// Cells in this row.
  final List<DocxTableCell> cells;

  /// Row height in twips (null = auto).
  final int? height;

  /// How [height] is interpreted (`w:trHeight w:hRule`): [DocxTableRowHeightRule.exact]
  /// clips content to the height, [atLeast] treats it as a minimum.
  ///
  /// Defaults to [DocxTableRowHeightRule.exact] so a height set programmatically
  /// is enforced (issue #74). The reader sets this explicitly from `w:hRule`,
  /// mapping a bare `w:trHeight` (no rule) to [atLeast] — Word's default.
  final DocxTableRowHeightRule heightRule;

  /// Whether this row is a header row (repeats on new pages).
  final bool isHeader;

  /// Conditional formatting style flags (e.g., '100000000000' for header row).
  final String? cnfStyle;

  /// Row may not break across a page boundary (`w:cantSplit`).
  final bool cantSplit;

  /// Number of grid columns skipped before the first cell (`w:gridBefore`).
  final int gridBefore;

  /// Number of grid columns skipped after the last cell (`w:gridAfter`).
  final int gridAfter;

  /// Preferred width of the skipped leading columns in twips (`w:wBefore`).
  final int? wBefore;

  /// Preferred width of the skipped trailing columns in twips (`w:wAfter`).
  final int? wAfter;

  const DocxTableRow({
    required this.cells,
    this.height,
    this.heightRule = DocxTableRowHeightRule.exact,
    this.isHeader = false,
    this.cnfStyle,
    this.cantSplit = false,
    this.gridBefore = 0,
    this.gridAfter = 0,
    this.wBefore,
    this.wAfter,
    super.id,
  });

  DocxTableRow copyWith({
    List<DocxTableCell>? cells,
    int? height,
    DocxTableRowHeightRule? heightRule,
    bool? isHeader,
    String? cnfStyle,
    bool? cantSplit,
    int? gridBefore,
    int? gridAfter,
    int? wBefore,
    int? wAfter,
  }) {
    return DocxTableRow(
      cells: cells ?? this.cells,
      height: height ?? this.height,
      heightRule: heightRule ?? this.heightRule,
      isHeader: isHeader ?? this.isHeader,
      cnfStyle: cnfStyle ?? this.cnfStyle,
      cantSplit: cantSplit ?? this.cantSplit,
      gridBefore: gridBefore ?? this.gridBefore,
      gridAfter: gridAfter ?? this.gridAfter,
      wBefore: wBefore ?? this.wBefore,
      wAfter: wAfter ?? this.wAfter,
      id: id,
    );
  }

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitTableRow(this);
  }

  @override
  void buildXml(XmlBuilder builder) {
    buildXmlWithStyle(
      builder,
      const DocxTableStyle(),
      isHeader: isHeader,
      isEven: false,
    );
  }

  void buildXmlWithStyle(
    XmlBuilder builder,
    DocxTableStyle style, {
    required bool isHeader,
    required bool isEven,
    List<int>? gridCols,
  }) {
    builder.element(
      'w:tr',
      nest: () {
        // Row properties
        if (height != null ||
            isHeader ||
            this.isHeader ||
            cnfStyle != null ||
            cantSplit ||
            gridBefore != 0 ||
            gridAfter != 0 ||
            wBefore != null ||
            wAfter != null) {
          builder.element(
            'w:trPr',
            nest: () {
              // Conditional formatting style (must come first)
              if (cnfStyle != null) {
                builder.element('w:cnfStyle', nest: () {
                  builder.attribute('w:val', cnfStyle!);
                });
              }
              if (gridBefore != 0) {
                builder.element('w:gridBefore', nest: () {
                  builder.attribute('w:val', gridBefore.toString());
                });
              }
              if (gridAfter != 0) {
                builder.element('w:gridAfter', nest: () {
                  builder.attribute('w:val', gridAfter.toString());
                });
              }
              if (wBefore != null) {
                builder.element('w:wBefore', nest: () {
                  builder.attribute('w:w', wBefore.toString());
                  builder.attribute('w:type', 'dxa');
                });
              }
              if (wAfter != null) {
                builder.element('w:wAfter', nest: () {
                  builder.attribute('w:w', wAfter.toString());
                  builder.attribute('w:type', 'dxa');
                });
              }
              if (cantSplit) builder.element('w:cantSplit');
              if (height != null) {
                builder.element(
                  'w:trHeight',
                  nest: () {
                    builder.attribute('w:val', height.toString());
                    builder.attribute('w:hRule', heightRule.xmlValue);
                  },
                );
              }
              // Mark as header row (repeats on each page)
              if (isHeader || this.isHeader) {
                builder.element('w:tblHeader');
              }
            },
          );
        }
        int colIndex = 0;
        for (var cell in cells) {
          int? cellWidth = cell.width;
          if (cellWidth == null &&
              gridCols != null &&
              colIndex < gridCols.length) {
            // Calculate width from gridCols based on colSpan
            cellWidth = 0;
            for (int j = 0; j < cell.colSpan; j++) {
              if (colIndex + j < gridCols.length) {
                cellWidth = cellWidth! + gridCols[colIndex + j];
              }
            }
          }
          cell.buildXmlWithWidth(builder, cellWidth);
          colIndex += cell.colSpan;
        }
      },
    );
  }
}

/// A cell within a [DocxTableRow].
class DocxTableCell extends DocxNode {
  /// Block content in this cell.
  final List<DocxBlock> children;

  /// Column span (merge cells horizontally).
  final int colSpan;

  /// Row span (merge cells vertically).
  final int rowSpan;

  /// Vertical alignment within the cell.
  final DocxVerticalAlign verticalAlign;

  /// Background shading color hex.
  final String? shadingFill;

  /// Theme-based fill color reference.
  final String? themeFill;

  /// Theme fill tint adjustment.
  final String? themeFillTint;

  /// Theme fill shade adjustment.
  final String? themeFillShade;

  /// Cell width in twips.
  final int? width;

  /// Conditional formatting style flags.
  final String? cnfStyle;

  // Borders
  final DocxBorderSide? borderTop;
  final DocxBorderSide? borderBottom;
  final DocxBorderSide? borderLeft;
  final DocxBorderSide? borderRight;

  // Margins
  final int? marginLeft;
  final int? marginRight;

  /// Per-cell margins (`w:tcMar`); overrides the table's default cell margins.
  final DocxCellMargins? margins;

  /// Text flow direction in the cell (`w:textDirection`); null = default `lrTb`.
  final DocxCellTextDirection? textDirection;

  /// Do not wrap the cell's content (`w:noWrap`).
  final bool noWrap;

  /// Shrink text to fit the cell width (`w:tcFitText`).
  final bool tcFitText;

  /// Hide the cell's end-of-cell mark (`w:hideMark`).
  final bool hideMark;

  const DocxTableCell({
    this.children = const [],
    this.colSpan = 1,
    this.rowSpan = 1,
    this.verticalAlign = DocxVerticalAlign.center,
    this.shadingFill,
    this.themeFill,
    this.themeFillTint,
    this.themeFillShade,
    this.width,
    this.borderTop,
    this.borderBottom,
    this.borderLeft,
    this.borderRight,
    this.marginLeft,
    this.marginRight,
    this.margins,
    this.textDirection,
    this.noWrap = false,
    this.tcFitText = false,
    this.hideMark = false,
    this.cnfStyle,
    super.id,
  });

  /// Creates a cell with simple text content.
  factory DocxTableCell.text(
    String text, {
    bool isBold = false,
    DocxAlign align = DocxAlign.left,
    DocxVerticalAlign verticalAlign = DocxVerticalAlign.center,
    DocxTextAlignment? textAlignment,
    String? shadingFill,
  }) {
    return DocxTableCell(
      verticalAlign: verticalAlign,
      shadingFill: shadingFill,
      children: [
        DocxParagraph(
          align: align,
          textAlignment: textAlignment,
          children: [isBold ? DocxText.bold(text) : DocxText(text)],
        ),
      ],
    );
  }

  /// Creates a cell with rich content.
  factory DocxTableCell.rich(List<DocxInline> content, {String? shadingFill}) {
    return DocxTableCell(
      shadingFill: shadingFill,
      children: [DocxParagraph(children: content)],
    );
  }

  DocxTableCell copyWith({
    List<DocxBlock>? children,
    int? colSpan,
    int? rowSpan,
    DocxVerticalAlign? verticalAlign,
    String? shadingFill,
    int? width,
    DocxBorderSide? borderTop,
    DocxBorderSide? borderBottom,
    DocxBorderSide? borderLeft,
    DocxBorderSide? borderRight,
    int? marginLeft,
    int? marginRight,
    DocxCellMargins? margins,
    DocxCellTextDirection? textDirection,
    bool? noWrap,
    bool? tcFitText,
    bool? hideMark,
  }) {
    return DocxTableCell(
      children: children ?? this.children,
      colSpan: colSpan ?? this.colSpan,
      rowSpan: rowSpan ?? this.rowSpan,
      verticalAlign: verticalAlign ?? this.verticalAlign,
      shadingFill: shadingFill ?? this.shadingFill,
      width: width ?? this.width,
      borderTop: borderTop ?? this.borderTop,
      borderBottom: borderBottom ?? this.borderBottom,
      borderLeft: borderLeft ?? this.borderLeft,
      borderRight: borderRight ?? this.borderRight,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      margins: margins ?? this.margins,
      textDirection: textDirection ?? this.textDirection,
      noWrap: noWrap ?? this.noWrap,
      tcFitText: tcFitText ?? this.tcFitText,
      hideMark: hideMark ?? this.hideMark,
      id: id,
    );
  }

  @override
  void accept(DocxVisitor visitor) {
    visitor.visitTableCell(this);
  }

  void _buildBorder(XmlBuilder builder, String tag, DocxBorderSide side) {
    builder.element(tag, nest: () {
      builder.attribute('w:val', side.xmlStyle);
      builder.attribute('w:sz', side.size.toString());
      builder.attribute('w:space', side.space.toString());
      if (side.color != DocxColor.auto) {
        builder.attribute('w:color', side.color.hex);
      } else {
        builder.attribute('w:color', 'auto');
      }
      if (side.themeColor != null) {
        builder.attribute('w:themeColor', side.themeColor!);
      }
      if (side.themeTint != null) {
        builder.attribute('w:themeTint', side.themeTint!);
      }
      if (side.themeShade != null) {
        builder.attribute('w:themeShade', side.themeShade!);
      }
    });
  }

  @override
  void buildXml(XmlBuilder builder) {
    buildXmlWithWidth(builder, width);
  }

  void buildXmlWithWidth(XmlBuilder builder, int? effectiveWidth) {
    builder.element(
      'w:tc',
      nest: () {
        // Cell properties
        builder.element(
          'w:tcPr',
          nest: () {
            if (cnfStyle != null) {
              builder.element('w:cnfStyle', nest: () {
                builder.attribute('w:val', cnfStyle!);
              });
            }
            if (effectiveWidth != null) {
              builder.element(
                'w:tcW',
                nest: () {
                  builder.attribute('w:w', effectiveWidth.toString());
                  builder.attribute('w:type', 'dxa');
                },
              );
            }
            if (colSpan > 1) {
              builder.element(
                'w:gridSpan',
                nest: () {
                  builder.attribute('w:val', colSpan.toString());
                },
              );
            }
            if (rowSpan > 1) {
              builder.element(
                'w:vMerge',
                nest: () {
                  builder.attribute('w:val', 'restart');
                },
              );
            }
            // Borders (Must be before shd)
            if (borderTop != null ||
                borderBottom != null ||
                borderLeft != null ||
                borderRight != null) {
              builder.element('w:tcBorders', nest: () {
                if (borderTop != null) {
                  _buildBorder(builder, 'w:top', borderTop!);
                }
                if (borderBottom != null) {
                  _buildBorder(builder, 'w:bottom', borderBottom!);
                }
                if (borderLeft != null) {
                  _buildBorder(builder, 'w:left', borderLeft!);
                }
                if (borderRight != null) {
                  _buildBorder(builder, 'w:right', borderRight!);
                }
              });
            }
            if (shadingFill != null || themeFill != null) {
              builder.element(
                'w:shd',
                nest: () {
                  builder.attribute('w:val', 'clear');
                  builder.attribute('w:color', 'auto');
                  builder.attribute(
                      'w:fill', shadingFill?.replaceAll('#', '') ?? 'auto');
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
            // noWrap (before tcMar)
            if (noWrap) builder.element('w:noWrap');

            // Per-cell margins
            if (margins != null && !margins!.isEmpty) {
              _buildCellMargins(builder, 'w:tcMar', margins!);
            }

            // Text flow direction
            if (textDirection != null) {
              builder.element('w:textDirection', nest: () {
                builder.attribute('w:val', textDirection!.xmlValue);
              });
            }

            // Fit text to cell width
            if (tcFitText) builder.element('w:tcFitText');

            builder.element(
              'w:vAlign',
              nest: () {
                builder.attribute('w:val', verticalAlign.name);
              },
            );

            // Hide end-of-cell mark
            if (hideMark) builder.element('w:hideMark');
          },
        );

        // Content
        if (children.isEmpty) {
          builder.element('w:p');
        } else {
          for (var child in children) {
            child.buildXml(builder);
          }
        }
      },
    );
  }
}
