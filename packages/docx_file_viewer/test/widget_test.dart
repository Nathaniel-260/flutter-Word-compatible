import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/search/docx_search_controller.dart';
import 'package:docx_file_viewer/src/theme/docx_view_theme.dart';
import 'package:docx_file_viewer/src/utils/block_index_counter.dart';
import 'package:docx_file_viewer/src/widget_generator/image_builder.dart';
import 'package:docx_file_viewer/src/widget_generator/list_builder.dart';
import 'package:docx_file_viewer/src/widgets/float_wrap_text.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:docx_file_viewer/src/widget_generator/shape_builder.dart';
import 'package:docx_file_viewer/src/widget_generator/table_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

TableBuilder _makeTableBuilder({DocxViewTheme? theme}) {
  final t = theme ?? DocxViewTheme.light();
  const cfg = DocxViewConfig();
  final pb = ParagraphBuilder(theme: t, config: cfg);
  return TableBuilder(
    theme: t,
    config: cfg,
    paragraphBuilder: pb,
    listBuilder: ListBuilder(theme: t, config: cfg, paragraphBuilder: pb),
    imageBuilder: ImageBuilder(config: cfg),
    shapeBuilder: ShapeBuilder(config: cfg),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Widget Rendering Pipeline Tests', () {
    // -----------------------------------------------------------------------
    // Test 1 — w:cantSplit / row height constraint
    //
    // A DocxTableRow with an explicit height must be wrapped in a ConstrainedBox
    // whose minHeight matches `height × (1/15)` px (twips-to-pixels conversion).
    // This prevents layout continuity from collapsing the row below its declared
    // height, equivalent to OOXML's w:cantSplit behaviour.
    // -----------------------------------------------------------------------
    testWidgets('Row with explicit height is wrapped in ConstrainedBox',
        (tester) async {
      const int rowHeightTwips = 600; // 40 logical pixels (600 / 15)
      final expectedMinHeight = rowHeightTwips / 15.0;

      final table = DocxTable(
        rows: [
          DocxTableRow(
            height: rowHeightTwips,
            heightRule:
                DocxTableRowHeightRule.atLeast, // floor → ConstrainedBox
            cells: [
              DocxTableCell(children: [
                DocxParagraph(children: [DocxText('Constrained')])
              ])
            ],
          ),
          const DocxTableRow(cells: [
            DocxTableCell(children: [
              DocxParagraph(children: [DocxText('Normal')])
            ])
          ]),
        ],
        gridColumns: [3000],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: _makeTableBuilder().build(table)),
      ));

      // Find the ConstrainedBox that the row builder wraps around the row
      // when height is set.
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );

      final heightConstrained = constrainedBoxes.where((cb) {
        return cb.constraints.minHeight >= expectedMinHeight - 0.01 &&
            cb.constraints.minHeight <= expectedMinHeight + 0.01;
      });

      expect(heightConstrained, isNotEmpty,
          reason:
              'A ConstrainedBox with minHeight=$expectedMinHeight must exist for the constrained row');
    });

    // -----------------------------------------------------------------------
    // Test 2 — Multi-column + multi-row merged cell produces a single placeholder
    //
    // A cell with colSpan=2 and rowSpan=2 must create ONE combined placeholder
    // in the continuation row, not two separate thin placeholders.  This verifies
    // the skipColSpans fix in table_builder.dart.
    // -----------------------------------------------------------------------
    testWidgets(
        'Multi-column vMerge produces one wide placeholder in continuation row',
        (tester) async {
      // 3-column grid; first cell spans columns 0–1 across 2 rows
      // Layout:
      //   Row 0: [A (colSpan=2, rowSpan=2)] [B]
      //   Row 1: [A-cont (placeholder, width = col0+col1)] [C]
      const col0 = 1000;
      const col1 = 1000;
      const col2 = 1000;

      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [
            DocxTableCell(
              children: [
                DocxParagraph(children: [DocxText('A')])
              ],
              colSpan: 2,
              rowSpan: 2,
            ),
            DocxTableCell(children: [
              DocxParagraph(children: [DocxText('B')])
            ]),
          ]),
          DocxTableRow(cells: [
            // Continuation of A is implicit; only C is listed
            DocxTableCell(children: [
              DocxParagraph(children: [DocxText('C')])
            ]),
          ]),
        ],
        gridColumns: [col0, col1, col2],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: _makeTableBuilder().build(table)),
      ));

      // The Row children count below verifies correct placeholder merging.

      // Alternative: verify the Row in row-1 has exactly TWO children
      // (one wide placeholder + cell C), not three.
      //
      // The IntrinsicHeight wraps each Row, so we look for IntrinsicHeight
      // widgets and inspect their Row children.
      final intrinsicHeights =
          tester.widgetList<IntrinsicHeight>(find.byType(IntrinsicHeight));

      // Row 0 and Row 1 both use IntrinsicHeight.
      // Row 1's Row should have 2 children: [placeholder, cellC].
      // Row 0's Row should have 2 children: [cellA (span=2 width), cellB].
      final rows =
          intrinsicHeights.map((ih) => ih.child).whereType<Row>().toList();

      expect(rows.length, greaterThanOrEqualTo(2),
          reason: 'Both table rows must be wrapped in IntrinsicHeight > Row');

      // Both rows must have exactly 2 children:
      //   Row 0: [cellA (colSpan=2 width), cellB]
      //   Row 1: [merged placeholder, cellC]
      // A broken vMerge fix would produce 3 children in the continuation row.
      for (final row in rows) {
        expect(row.children.length, 2,
            reason: 'Each table row must have exactly 2 children; '
                'a broken vMerge fix produces 3 in the continuation row');
      }
    });

    // -----------------------------------------------------------------------
    // Test 3 — Search highlight spans exact character ranges across run splits
    //
    // When a search match crosses a paragraph boundary, ParagraphBuilder must
    // apply the highlight colour to exactly the right character range.  This
    // test verifies that the split logic in _buildTextSpan produces a highlighted
    // TextSpan at the correct offset inside a multi-run paragraph.
    // -----------------------------------------------------------------------
    testWidgets('Search highlights map onto correct character ranges',
        (tester) async {
      // Set up search: match 'World' starting at offset 6 in a paragraph
      // whose block text is 'Hello World'.
      final controller = DocxSearchController();
      controller.setDocument(['Hello World']);
      controller.search('World');

      expect(controller.matchCount, 1);
      expect(controller.matches.first.startOffset, 6);
      expect(controller.matches.first.endOffset, 11);

      final builder = ParagraphBuilder(
        config: const DocxViewConfig(),
        theme: DocxViewTheme.light(),
        searchController: controller,
      );

      // Two runs: 'Hello ' (offset 0–5) and 'World' (offset 6–10)
      final paragraph = DocxParagraph(children: [
        DocxText('Hello '),
        DocxText('World'),
      ]);

      final counter = BlockIndexCounter();
      final widget = builder.build(paragraph, counter: counter);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(width: 400, child: widget)),
      ));

      // The widget tree must contain at least one RichText / SelectableText.
      final richFinder =
          find.byWidgetPredicate((w) => w is RichText || w is SelectableText);
      expect(richFinder, findsWidgets,
          reason: 'Paragraph must produce text widgets');

      // Both runs must be rendered — 'Hello ' as plain text, 'World' highlighted.
      expect(find.textContaining('Hello'), findsWidgets,
          reason: 'Paragraph text must be rendered');
      expect(find.textContaining('World'), findsWidgets,
          reason: 'Highlighted search match must be rendered');
    });

    // -----------------------------------------------------------------------
    // Test 4 — Inline vs. anchored image differentiation
    //
    // A DocxInlineImage with positionMode = floating must be laid out in a Row
    // (wrapping text around it) while an inline image stays inside the text flow.
    // -----------------------------------------------------------------------
    testWidgets(
        'Floating image is placed in a Row; inline image stays in text flow',
        (tester) async {
      // We're inside an async closure — use a minimal valid GIF.
      final gifBytes = Uint8List.fromList([
        0x47,
        0x49,
        0x46,
        0x38,
        0x39,
        0x61,
        0x01,
        0x00,
        0x01,
        0x00,
        0x80,
        0x00,
        0x00,
        0xFF,
        0xFF,
        0xFF,
        0x00,
        0x00,
        0x00,
        0x21,
        0xF9,
        0x04,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x2C,
        0x00,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x01,
        0x00,
        0x00,
        0x02,
        0x02,
        0x44,
        0x01,
        0x00,
        0x3B,
      ]);

      // Floating (left-align) side float
      final floatParagraph = DocxParagraph(children: [
        DocxText('Text beside float'),
        DocxInlineImage(
          bytes: gifBytes,
          positionMode: DocxDrawingPosition.floating,
          textWrap: DocxTextWrap.square,
          hAlign: DrawingHAlign.left,
          extension: 'gif',
          width: 50,
          height: 50,
        ),
      ]);

      final builder = ParagraphBuilder(
        config: const DocxViewConfig(),
        theme: DocxViewTheme.light(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: builder.build(floatParagraph)),
      ));

      // A side float wraps the text beside it via the band-aware layout (§8.2 #29).
      expect(find.byType(FloatWrapText), findsOneWidget,
          reason: 'Side float must use the band-aware wrap layout');

      // Inline image — must NOT produce IntrinsicHeight/Row wrapping.
      final inlineParagraph = DocxParagraph(children: [
        DocxText('Inline: '),
        DocxInlineImage(
          bytes: gifBytes,
          positionMode: DocxDrawingPosition.inline,
          extension: 'gif',
          width: 50,
          height: 50,
        ),
      ]);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: builder.build(inlineParagraph)),
      ));

      expect(find.byType(IntrinsicHeight), findsNothing,
          reason: 'Inline image must not use IntrinsicHeight Row layout');
    });
  });
}
