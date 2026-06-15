import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/utils/block_index_counter.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';
import '../layout/table_layout.dart';
import '../layout/table_min_widths.dart';
import '../theme/docx_view_theme.dart';
import 'image_builder.dart';
import 'list_builder.dart';
import 'paragraph_builder.dart';
import 'shape_builder.dart';

/// Builds Flutter widgets from [DocxTable] elements using native layout.
class TableBuilder {
  final DocxViewTheme theme;
  final DocxViewConfig config;
  final ParagraphBuilder paragraphBuilder;
  final ListBuilder listBuilder;
  final ImageBuilder imageBuilder;
  final ShapeBuilder shapeBuilder;
  final DocxTheme? docxTheme;

  TableBuilder({
    required this.theme,
    required this.config,
    required this.paragraphBuilder,
    required this.listBuilder,
    required this.imageBuilder,
    required this.shapeBuilder,
    this.docxTheme,
  });

  // Content-width floors (longest-word px per grid column), memoised by table
  // identity so a table re-built on relayout is not re-measured. Derived from
  // the same span construction the paginator's measurer uses, so the painted
  // widths match the measured ones (QA F3).
  final Map<DocxTable, List<double>> _minColWidths = {};

  List<double> _minWidthsOf(DocxTable table) => _minColWidths.putIfAbsent(
      table, () => computeMinColumnWidths(table, paragraphBuilder.spanFactory));

  /// Build a widget from a [DocxTable].
  ///
  /// [nested] must be true when this table is rendered inside another table's
  /// cell. A nested table is laid out inside the parent row's [IntrinsicHeight],
  /// which queries intrinsic dimensions of its children — but the page-level
  /// autofit wrapper uses a [LayoutBuilder], which throws "does not support
  /// returning intrinsic dimensions". So for nested tables we skip the
  /// autofit/scroll wrapper and return the intrinsic-friendly table content
  /// directly (the cell already bounds its width).
  Widget build(DocxTable table,
      {BlockIndexCounter? counter, bool nested = false}) {
    if (table.rows.isEmpty) {
      return const SizedBox.shrink();
    }

    // Nested table (inside a cell): the parent row's IntrinsicHeight queries
    // intrinsic dimensions, which a LayoutBuilder cannot answer. So we skip the
    // autofit/scroll wrapper and lay the table out at its grid width verbatim —
    // the enclosing cell already bounds it (Plan §F.1: infinite available width
    // ⇒ grid honoured as-is).
    if (nested) {
      final layout =
          resolveTableColumnWidths(table, availableWidth: double.infinity);
      final content = _buildTableContent(table, layout.columns, counter);
      Widget nestedTable = SizedBox(width: layout.totalWidth, child: content);
      if (table.alignment == DocxAlign.center) {
        return Center(child: nestedTable);
      } else if (table.alignment == DocxAlign.right) {
        return Align(alignment: Alignment.centerRight, child: nestedTable);
      }
      return nestedTable;
    }

    // Top-level table: resolve column widths against the *real* available width
    // (the page body), through the same Part F engine the paginator measures
    // with — so the painted table matches the measured one. A table wider than
    // the page is scaled down proportionally (Word-like autofit) rather than
    // clipped; an equal-or-narrower one keeps its width with horizontal scroll.
    Widget scrollableTable = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBound =
              constraints.maxWidth.isFinite && constraints.maxWidth > 0;
          final layout = resolveTableColumnWidths(
            table,
            availableWidth: hasBound ? constraints.maxWidth : double.infinity,
            // Same content-width floor the paginator measured with, so a long
            // word expands its column identically in both passes (QA F3).
            minColumnWidths: hasBound ? _minWidthsOf(table) : null,
          );
          final content = _buildTableContent(table, layout.columns, counter);
          final totalWidth = layout.totalWidth;
          if (hasBound && totalWidth > constraints.maxWidth) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(width: totalWidth, child: content),
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: content,
          );
        },
      ),
    );

    // Handle Table Alignment
    if (table.alignment == DocxAlign.center) {
      return Center(child: scrollableTable);
    } else if (table.alignment == DocxAlign.right) {
      return Align(alignment: Alignment.centerRight, child: scrollableTable);
    }

    return scrollableTable;
  }

  /// Builds the table body (rows) at the resolved [colWidths], plus the
  /// table-level background. Shared by the nested and top-level paths so both
  /// render identically.
  Widget _buildTableContent(
      DocxTable table, List<double> colWidths, BlockIndexCounter? counter) {
    // Vertical-merge bookkeeping (rebuilt per call — it is consumed top-to-bottom
    // as rows are emitted).
    // skipCounts[i]: remaining rows to skip at grid column i.
    final skipCounts = List<int>.filled(colWidths.length, 0);
    // skipColSpans[i]: column-span of the merge group whose leader starts at i.
    //   > 0 → group leader spanning that many columns.
    //   -1  → subsumed by the leader to the left (do not render separately).
    final skipColSpans = List<int>.filled(colWidths.length, 1);
    // skipFill[i]: the leader cell's resolved background, so the continuation
    // placeholders of a vertical merge paint the same colour as the merged cell
    // (otherwise a shaded merged cell shows a white gap below — looks un-merged).
    final skipFill = List<Color?>.filled(colWidths.length, null);

    final rowWidgets = <Widget>[];
    for (int r = 0; r < table.rows.length; r++) {
      rowWidgets.add(_buildRow(
        table.rows[r],
        colWidths,
        skipCounts,
        skipColSpans,
        skipFill,
        table: table,
        rowIndex: r,
        totalRows: table.rows.length,
        counter: counter,
      ));
    }

    // mainAxisSize.min: this Column sits inside a horizontal SingleChildScrollView,
    // whose cross axis (vertical) constraint is passed through unchanged. In paged
    // mode the page is laid out by a ListView with an *unbounded* main-axis height,
    // so without min the Column would try to expand to infinite height → it is left
    // unsized → the sliver's `child.hasSize` assertion fires and the whole page
    // fails to paint (the "RenderBox was not laid out" cascade).
    Widget tableContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rowWidgets,
    );

    final tableFill = _resolveColor(table.style.fill, null, null, null);
    if (tableFill != null) {
      tableContent = DecoratedBox(
        decoration: BoxDecoration(color: tableFill),
        child: tableContent,
      );
    }
    return tableContent;
  }

  Widget _buildRow(
    DocxTableRow row,
    List<double> colWidths,
    List<int> skipCounts,
    List<int> skipColSpans,
    List<Color?> skipFill, {
    required DocxTable table,
    required int rowIndex,
    required int totalRows,
    BlockIndexCounter? counter,
  }) {
    final cells = <Widget>[];
    final style = table.style;
    final look = table.look;
    final totalColumns = colWidths.length;

    // Resolve named table style
    DocxStyle? namedStyle;
    if (table.styleId != null && docxTheme != null) {
      namedStyle = docxTheme!.styles[table.styleId];
    }

    // Merge named style base definition into effective table style if needed
    DocxTableStyle effectiveTableStyle = style;
    if (namedStyle != null) {
      effectiveTableStyle = style.copyWith(
        borderTop: style.borderTop ?? namedStyle.borderTop,
        borderBottom: style.borderBottom ??
            namedStyle
                .borderBottomSide, // Note: DocxStyle uses borderBottomSide for pPr/tblPr
        borderLeft: style.borderLeft ?? namedStyle.borderLeft,
        borderRight: style.borderRight ?? namedStyle.borderRight,
        borderInsideH: style.borderInsideH ??
            namedStyle.borderBetween, // Mapping between to InsideH
        borderInsideV: style
            .borderInsideV, // DocxStyle might not have InsideV explicitly mapped same way, need verification
      );

      // DocxStyle uses `borderBottom` sometimes too, check model.
      // DocxStyle AST has: borderTop, borderBottomSide, borderLeft, borderRight, borderBetween, borderBottom
      // We map DocxStyle.borderBetween -> borderInsideH usually for paragraphs, but for tables it helps to overlap.
      // Actually, Table Styles in styles.xml usually use tblPr > tblBorders which map to top/left/bottom/right/insideH/insideV.
      // The DocxStyle model has properties: borderTop, borderBottomSide, borderLeft, borderRight, borderBetween, borderBottom.
      // It seems DocxStyle might need better mapping for tables if it was primarily built for Paragraphs.
      // However, looking at DocxStyle definition, it has `borderTop`, `borderBottomSide`, etc.
      // Let's assume standard mapping for now and refine if needed.
      if (namedStyle.borderBetween != null &&
          effectiveTableStyle.borderInsideH == null) {
        effectiveTableStyle = effectiveTableStyle.copyWith(
            borderInsideH: namedStyle.borderBetween);
      }
    }

    // Determine row-level conditions
    final isHeaderRow = rowIndex == 0 && table.hasHeader && look.firstRow;
    final isLastRow = rowIndex == totalRows - 1 && look.lastRow;
    final isEvenRow = rowIndex % 2 != 0; // 0-indexed, so row 1 is even "band"

    // Resolve conditional styles for this row
    DocxStyle? rowCondStyle;
    if (isHeaderRow) {
      rowCondStyle = namedStyle?.tableConditionals['firstRow'];
    } else if (isLastRow) {
      rowCondStyle = namedStyle?.tableConditionals['lastRow'];
    } else if (!look.noHBand) {
      // Band styling
      if (isEvenRow) {
        rowCondStyle = namedStyle?.tableConditionals['band2Horz']; // Even row
      } else {
        rowCondStyle = namedStyle?.tableConditionals['band1Horz']; // Odd row
      }
    }

    // Determine row-level background based on styling (Prioritize Conditional > Direct Table Style)
    Color? rowBackground;

    if (rowCondStyle?.shadingFill != null || rowCondStyle?.themeFill != null) {
      rowBackground = _resolveColor(
          rowCondStyle!.shadingFill,
          rowCondStyle.themeFill,
          rowCondStyle.themeFillTint,
          rowCondStyle.themeFillShade);
    }

    // Fallback to direct style properties (legacy support) if no conditional override
    if (rowBackground == null) {
      if (isHeaderRow && style.headerFill != null) {
        rowBackground = _resolveColor(style.headerFill, null, null, null);
      }
      if (!isHeaderRow && !look.noHBand) {
        if (isEvenRow && style.evenRowFill != null) {
          rowBackground = _resolveColor(style.evenRowFill, null, null, null);
        } else if (!isEvenRow && style.oddRowFill != null) {
          rowBackground = _resolveColor(style.oddRowFill, null, null, null);
        }
      }
    }

    int gridIndex = 0;
    int cellIndex = 0; // Index in row.cells

    // Leading skipped grid columns (`w:gridBefore`): emit one spacer covering
    // their combined width and start the cell walk past them, so the row's first
    // real cell sits in the right grid column (mirrors the paginator's
    // measurement, which also starts at `row.gridBefore`).
    if (row.gridBefore > 0 && colWidths.isNotEmpty) {
      double lead = 0;
      final upto = row.gridBefore.clamp(0, colWidths.length);
      for (int k = 0; k < upto; k++) {
        lead += colWidths[k];
      }
      if (lead > 0) cells.add(SizedBox(width: lead));
      gridIndex = upto;
    }

    while (gridIndex < colWidths.length) {
      // Determine column conditions
      final isFirstColumn = gridIndex == 0 && look.firstColumn;

      if (skipCounts[gridIndex] > 0) {
        // --- CONTINUED CELL (Merged Placeholder) ---
        final groupSpan = skipColSpans[gridIndex];

        if (groupSpan < 0) {
          // This column is subsumed by a multi-column merge group whose leader
          // has already been rendered — skip it silently.
          skipCounts[gridIndex]--;
          gridIndex++;
        } else {
          // Group leader: accumulate the combined width of all spanned columns.
          double width = 0;
          int remainingSkips = 0;
          for (int k = 0; k < groupSpan; k++) {
            final idx = gridIndex + k;
            if (idx < colWidths.length) {
              width += colWidths[idx];
              skipCounts[idx]--;
              remainingSkips = skipCounts[idx];
            }
          }
          final isLastRowOfMerge = remainingSkips == 0;

          final border = _resolveCellBorder(
            cell: null,
            tableStyle: effectiveTableStyle,
            rowCondStyle: null,
            colCondStyle: null,
            drawTop: false, // internal to the vertical merge → no rule
            drawBottom: isLastRowOfMerge,
            isFirstRowActual: rowIndex == 0,
            isLastRowActual: rowIndex == totalRows - 1,
            isFirstColumnActual: gridIndex == 0,
            isLastColumnActual: gridIndex + groupSpan - 1 >= totalColumns - 1,
          );
          cells.add(_buildCell(
            null, // No content
            width,
            table: table,
            border: border,
            isEmpty: true,
            // Continue the merged cell's fill so the merge reads as one block.
            rowBackground: skipFill[gridIndex] ?? rowBackground,
            isHeaderRow: isHeaderRow,
            isFirstColumn: isFirstColumn,
          ));

          gridIndex += groupSpan;
        }
      } else {
        // --- NEW CELL ---
        if (cellIndex < row.cells.length) {
          final cell = row.cells[cellIndex];

          final span = cell.colSpan > 0 ? cell.colSpan : 1;
          double width = 0;
          for (int k = 0; k < span; k++) {
            if (gridIndex + k < colWidths.length) {
              width += colWidths[gridIndex + k];
            } else {
              width += 100;
            }
          }

          final rowSpan = cell.rowSpan > 1 ? cell.rowSpan : 1;

          if (rowSpan > 1) {
            // The merged cell's own fill (cell shading → row background), so its
            // continuation placeholders below paint the same colour.
            final leaderFill = _resolveColor(cell.shadingFill, cell.themeFill,
                    cell.themeFillTint, cell.themeFillShade) ??
                rowBackground;
            for (int k = 0; k < span; k++) {
              final idx = gridIndex + k;
              if (idx < skipCounts.length) {
                skipCounts[idx] = rowSpan - 1;
                // Mark the first column as group leader; the rest are subsumed.
                skipColSpans[idx] = k == 0 ? span : -1;
                skipFill[idx] = leaderFill;
              }
            }
          }

          bool hasVMerge = rowSpan > 1;

          // Check if this cell spans to last column
          final cellIsLastColumn =
              (gridIndex + span - 1) >= totalColumns - 1 && look.lastColumn;

          // Determine column conditional style
          DocxStyle? colCondStyle;
          if (isFirstColumn) {
            colCondStyle = namedStyle?.tableConditionals['firstColumn'];
          } else if (cellIsLastColumn) {
            colCondStyle = namedStyle?.tableConditionals['lastColumn'];
          }

          final border = _resolveCellBorder(
            cell: cell,
            tableStyle: effectiveTableStyle,
            rowCondStyle: rowCondStyle,
            colCondStyle: colCondStyle,
            drawTop: true,
            drawBottom:
                !hasVMerge, // a merge leader leaves its bottom to the tail
            isFirstRowActual: rowIndex == 0,
            isLastRowActual: rowIndex == totalRows - 1,
            isFirstColumnActual: gridIndex == 0,
            isLastColumnActual: (gridIndex + span - 1) >= totalColumns - 1,
          );
          cells.add(_buildCell(
            cell,
            width,
            table: table,
            border: border,
            isEmpty: false,
            rowBackground: rowBackground,
            rowCondStyle: rowCondStyle,
            colCondStyle: colCondStyle,
            isHeaderRow: isHeaderRow,
            isFirstColumn: isFirstColumn,
          ));

          gridIndex += span;
          cellIndex++;
        } else {
          if (gridIndex < colWidths.length) {
            cells.add(SizedBox(width: colWidths[gridIndex]));
          }
          gridIndex++;
        }
      }
    }

    Widget rowWidget = IntrinsicHeight(
      child: Row(
        // `w:bidiVisual`: mirror the *visual* column order (first logical cell on
        // the right) without touching the merge/width logic — Flutter lays the
        // children out right-to-left. Null inherits the ambient direction.
        textDirection: table.bidiVisual ? TextDirection.rtl : null,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cells,
      ),
    );

    if (row.height != null) {
      final hPx = row.height! * kTwipsToPx;
      if (row.heightRule == DocxTableRowHeightRule.exact) {
        // `exact`: fix the row to its height and clip taller content (Plan §F.3).
        // The row sits in a horizontal scroll view (unbounded width), so bound
        // the OverflowBox to the row's natural width (sum of the columns) — only
        // the vertical overflow is what we mean to clip.
        final rowWidth = colWidths.fold<double>(0.0, (a, b) => a + b);
        rowWidget = SizedBox(
          width: rowWidth,
          height: hPx,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              maxWidth: rowWidth,
              child: rowWidget,
            ),
          ),
        );
      } else if (row.heightRule == DocxTableRowHeightRule.atLeast) {
        // `atLeast`: a floor; content may grow the row.
        rowWidget = ConstrainedBox(
          constraints: BoxConstraints(minHeight: hPx),
          child: rowWidget,
        );
      }
      // `auto`: the height value is ignored (row sizes to content).
    }

    return rowWidget;
  }

  Widget _buildCell(
    DocxTableCell? cell,
    double width, {
    required DocxTable table,
    required Border border,
    required bool isEmpty,
    Color? rowBackground,
    bool isHeaderRow = false,
    bool isFirstColumn = false,
    DocxStyle? rowCondStyle,
    DocxStyle? colCondStyle,
    BlockIndexCounter? counter,
  }) {
    // Borders are resolved once per edge in _buildRow (Plan §F.2 conflict
    // resolution + single-owner de-duplication) and passed in ready to paint.

    // Background: Cell shading takes priority, then row background
    Color? color;
    if (cell != null) {
      color = _resolveColor(cell.shadingFill, cell.themeFill,
          cell.themeFillTint, cell.themeFillShade);
    }
    // Fall back to row background if cell has no explicit shading
    color ??= rowBackground;

    // Content
    Widget? contentWidget;
    if (!isEmpty && cell != null) {
      final children = <Widget>[];
      for (final child in cell.children) {
        if (child is DocxParagraph) {
          children.add(paragraphBuilder.build(child, counter: counter));
        } else if (child is DocxTable) {
          children
              .add(build(child, counter: counter, nested: true)); // Recursive
        } else if (child is DocxList) {
          children.add(listBuilder.build(child, counter: counter));
        } else if (child is DocxImage) {
          // Extraction skips images, so we shouldn't increment counter for them
          // BUT wait, extractTextForSearch (in DocxWidgetGenerator) only extracts from Paragraph and List inside Table.
          // It does NOT extract from Image or ShapeBlock.
          // So we should NOT pass counter to these builders if they don't consume it.
          // ImageBuilder and ShapeBuilder don't take counter in their build methods currently.
          children.add(imageBuilder.buildBlockImage(child));
        } else if (child is DocxShapeBlock) {
          children.add(shapeBuilder.buildBlockShape(child));
        } else if (child is DocxDropCap) {
          children.add(paragraphBuilder.buildDropCap(child));
        }
      }

      MainAxisAlignment mainAxis = MainAxisAlignment.start;
      if (cell.verticalAlign == DocxVerticalAlign.center) {
        mainAxis = MainAxisAlignment.center;
      }
      if (cell.verticalAlign == DocxVerticalAlign.bottom) {
        mainAxis = MainAxisAlignment.end;
      }

      contentWidget = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: mainAxis,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );

      // Vertical align wrapper
      if (cell.verticalAlign != DocxVerticalAlign.top) {
        if (cell.verticalAlign == DocxVerticalAlign.center) {
          contentWidget = Center(child: contentWidget);
        } else if (cell.verticalAlign == DocxVerticalAlign.bottom) {
          contentWidget =
              Align(alignment: Alignment.bottomLeft, child: contentWidget);
        }
      }

      // Apply conditional text styling (from named style or default header logic)
      TextStyle? cellTextStyle;

      // 1. Try Conditional Style (Row Priority then Column Priority)
      // Merge column properties on top of row properties? Or vice versa?
      // Usually First Column > Header Row in some cases, but Header Row > Banding.

      if (rowCondStyle != null) {
        if (rowCondStyle.fontWeight == DocxFontWeight.bold) {
          cellTextStyle = (cellTextStyle ?? const TextStyle())
              .copyWith(fontWeight: FontWeight.bold);
        }
        if (rowCondStyle.color != null) {
          final color = _resolveColor(
              rowCondStyle.color!.hex,
              rowCondStyle.color!.themeColor,
              rowCondStyle.color!.themeTint,
              rowCondStyle.color!.themeShade);
          if (color != null) {
            cellTextStyle =
                (cellTextStyle ?? const TextStyle()).copyWith(color: color);
          }
        }
      }

      if (colCondStyle != null) {
        if (colCondStyle.fontWeight == DocxFontWeight.bold) {
          cellTextStyle = (cellTextStyle ?? const TextStyle())
              .copyWith(fontWeight: FontWeight.bold);
        }
        if (colCondStyle.color != null) {
          final color = _resolveColor(
              colCondStyle.color!.hex,
              colCondStyle.color!.themeColor,
              colCondStyle.color!.themeTint,
              colCondStyle.color!.themeShade);
          if (color != null) {
            cellTextStyle =
                (cellTextStyle ?? const TextStyle()).copyWith(color: color);
          }
        }
      }

      // 2. Fallback to Hardcoded Header/FirstCol logic ONLY if no conditional style was found/applied
      // AND we are in a header/first-col scenario
      if (cellTextStyle == null && (isHeaderRow || isFirstColumn)) {
        // Determine text color for contrast (white text on dark backgrounds)
        Color? textColor;
        if (color != null) {
          final luminance = color.computeLuminance();
          if (luminance < 0.5) {
            textColor = Colors.white;
          }
        }

        cellTextStyle = TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
        );
      }

      if (cellTextStyle != null) {
        contentWidget = DefaultTextStyle.merge(
          style: cellTextStyle,
          child: contentWidget,
        );
      }

      // Rotated cell text (`w:textDirection`): tbRl = top→bottom (90° CW),
      // btLr = bottom→top (270° CW). The rotation wraps the cell's content only.
      switch (cell.textDirection) {
        case DocxCellTextDirection.tbRl:
        case DocxCellTextDirection.tbRlV:
          contentWidget = RotatedBox(quarterTurns: 1, child: contentWidget);
          break;
        case DocxCellTextDirection.btLr:
        case DocxCellTextDirection.tbLrV:
          contentWidget = RotatedBox(quarterTurns: 3, child: contentWidget);
          break;
        case DocxCellTextDirection.lrTb:
        case DocxCellTextDirection.lrTbV:
        case null:
          break;
      }
    }

    // Effective cell margins (`w:tcMar`/`w:tblCellMar`, Word default 108tw sides /
    // 0 top-bottom) — the same widths the paginator measured the content at.
    final margins = resolveCellMargins(table, cell);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: color,
        border: border,
      ),
      padding: EdgeInsets.fromLTRB(
          margins.left, margins.top, margins.right, margins.bottom),
      child: contentWidget,
    );
  }

  /// Resolves the [Border] to paint for one cell (Plan §F.2/§F.3).
  ///
  /// Left/right are always drawn so a table never loses its outer side borders —
  /// crucially in **RTL** tables, where the grid-first column sits visually on
  /// the right (Flutter's `Border.left`/`right` are physical, not directional).
  /// Top/bottom are gated by [drawTop]/[drawBottom] so a vertical-merge leader
  /// (`drawBottom: false`) and its continuation placeholders (`drawTop: false`)
  /// show no internal horizontal rule — the merged cell reads as one block.
  ///
  /// (A table-wide "strong border wins" conflict resolution with single-owner
  /// de-duplication needs a direction-aware grid render object to be correct in
  /// RTL; deferred — see §8.2 #22.)
  Border _resolveCellBorder({
    required DocxTableCell? cell,
    required DocxTableStyle tableStyle,
    required DocxStyle? rowCondStyle,
    required DocxStyle? colCondStyle,
    required bool drawTop,
    required bool drawBottom,
    required bool isFirstRowActual,
    required bool isLastRowActual,
    required bool isFirstColumnActual,
    required bool isLastColumnActual,
  }) {
    // Table-level default per edge: outer edges use the table border; inner edges
    // use insideH (horizontal) / insideV (vertical).
    final topTable =
        isFirstRowActual ? tableStyle.borderTop : tableStyle.borderInsideH;
    final bottomTable =
        isLastRowActual ? tableStyle.borderBottom : tableStyle.borderInsideH;
    final leftTable =
        isFirstColumnActual ? tableStyle.borderLeft : tableStyle.borderInsideV;
    final rightTable =
        isLastColumnActual ? tableStyle.borderRight : tableStyle.borderInsideV;

    final effTop = _effectiveSource(cell?.borderTop, topTable,
        rowSide: rowCondStyle?.borderTop, colSide: colCondStyle?.borderTop);
    final effBottom = _effectiveSource(cell?.borderBottom, bottomTable,
        rowSide: rowCondStyle?.borderBottomSide,
        colSide: colCondStyle?.borderBottomSide);
    final effLeft = _effectiveSource(cell?.borderLeft, leftTable,
        rowSide: rowCondStyle?.borderLeft,
        colSide: colCondStyle?.borderLeft,
        prioritizeCol: true);
    final effRight = _effectiveSource(cell?.borderRight, rightTable,
        rowSide: rowCondStyle?.borderRight,
        colSide: colCondStyle?.borderRight,
        prioritizeCol: true);

    return Border(
      top: drawTop ? _convertSide(effTop, tableStyle) : BorderSide.none,
      bottom:
          drawBottom ? _convertSide(effBottom, tableStyle) : BorderSide.none,
      left: _convertSide(effLeft, tableStyle),
      right: _convertSide(effRight, tableStyle),
    );
  }

  /// Effective *source* border for an edge by precedence (cell > conditional >
  /// table), before neighbour conflict. Conditional precedence prefers the column
  /// style for vertical edges ([prioritizeCol]) and the row style otherwise.
  DocxBorderSide? _effectiveSource(
    DocxBorderSide? cellSide,
    DocxBorderSide? tableSide, {
    DocxBorderSide? rowSide,
    DocxBorderSide? colSide,
    bool prioritizeCol = false,
  }) {
    var eff = cellSide;
    eff ??= prioritizeCol ? (colSide ?? rowSide) : (rowSide ?? colSide);
    return eff ?? tableSide;
  }

  /// Converts a resolved source border to a Flutter [BorderSide] (colour/width).
  /// Dashed/dotted collapse to a hairline-suppressed solid (no native dashes).
  BorderSide _convertSide(DocxBorderSide? eff, DocxTableStyle tableStyle) {
    if (eff == null || eff.style == DocxBorder.none) return BorderSide.none;

    Color? borderColor;
    if (eff.themeColor != null) {
      borderColor = _resolveColor(
          eff.color.hex, eff.themeColor, eff.themeTint, eff.themeShade);
    }
    if (borderColor == null && eff.color.hex != 'auto') {
      borderColor = _resolveColor(eff.color.hex, null, null, null);
    }
    borderColor ??= _resolveColor(tableStyle.borderColor, null, null, null);
    borderColor ??= Colors.black;

    final borderWidth = eff.size > 0
        ? (eff.size / 8.0).clamp(0.5, 5.0)
        : (tableStyle.borderWidth / 8.0).clamp(0.5, 5.0);

    return BorderSide(
      color: borderColor,
      width: borderWidth,
      style: eff.style == DocxBorder.dotted || eff.style == DocxBorder.dashed
          ? BorderStyle.none
          : BorderStyle.solid,
    );
  }

  /// Resolve color from hex or theme properties (tint/shade).
  Color? _resolveColor(
      String? hex, String? themeColor, String? themeTint, String? themeShade) {
    Color? baseColor;

    // 1. Try Theme Color
    if (themeColor != null && docxTheme != null) {
      final themeHex = docxTheme!.colors.getColor(themeColor);
      if (themeHex != null) {
        baseColor = _parseHex(themeHex);
      }
    }

    // 2. Fallback to direct Hex
    if (baseColor == null && hex != null && hex != 'auto') {
      baseColor = _parseHex(hex);
    }

    if (baseColor == null) return null;

    // 3. Apply Tint/Shade
    if (themeTint != null) {
      final tintVal = int.tryParse(themeTint, radix: 16);
      if (tintVal != null) {
        // In OOXML, tint is amount of color to keep, rest is white
        // Actually, alphaBlend logic:
        // tint/shade values in OOXML are complex 0-255 scaling.
        // Assuming typical implementation:
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

  Color? _parseHex(String hex) {
    if (hex == 'auto' || hex.isEmpty) return null;
    var clean = hex.replaceAll('#', '').replaceAll('0x', '');
    if (clean.length == 8) {
      // ARGB?
      return Color(int.parse('0x$clean'));
    }
    if (clean.length == 6) {
      return Color(int.parse('0xFF$clean'));
    }
    return null;
  }
}
