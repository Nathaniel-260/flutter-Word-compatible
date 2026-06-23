import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/theme/docx_view_theme.dart';
import 'package:docx_file_viewer/src/utils/block_index_counter.dart';
import 'package:docx_file_viewer/src/widget_generator/image_builder.dart';
import 'package:docx_file_viewer/src/widget_generator/list_builder.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:docx_file_viewer/src/widget_generator/shape_builder.dart';
import 'package:docx_file_viewer/src/widget_generator/table_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock ParagraphBuilder
class MockParagraphBuilder extends ParagraphBuilder {
  MockParagraphBuilder()
      : super(
          config: const DocxViewConfig(),
          theme: DocxViewTheme.light(),
        );

  @override
  Widget build(DocxParagraph paragraph,
      {BlockIndexCounter? counter, Color? inheritedBackground}) {
    return const Text('Paragraph');
  }
}

void main() {
  testWidgets('TableBuilder creates basic table', (WidgetTester tester) async {
    final theme = DocxViewTheme.light();
    final config = const DocxViewConfig();
    final paragraphBuilder = MockParagraphBuilder();

    final builder = TableBuilder(
      theme: theme,
      config: config,
      paragraphBuilder: paragraphBuilder,
      listBuilder: ListBuilder(
          theme: theme, config: config, paragraphBuilder: paragraphBuilder),
      imageBuilder: ImageBuilder(config: config),
      shapeBuilder: ShapeBuilder(config: config),
    );

    final table = DocxTable(
      rows: [
        DocxTableRow(cells: [
          DocxTableCell.text('Cell 1'),
          DocxTableCell.text('Cell 2'),
        ]),
        DocxTableRow(cells: [
          DocxTableCell.text('Cell 3'),
          DocxTableCell.text('Cell 4'),
        ]),
      ],
      gridColumns: [1000, 1000], // Twips
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(table)),
    ));

    expect(find.byType(Column), findsWidgets);
    expect(find.text('Paragraph'), findsNWidgets(4));
    expect(find.byType(Row), findsWidgets);
  });

  testWidgets('TableBuilder handles gridSpan', (WidgetTester tester) async {
    final theme = DocxViewTheme.light();
    final config = const DocxViewConfig();
    final paragraphBuilder = MockParagraphBuilder();

    final builder = TableBuilder(
      theme: theme,
      config: config,
      paragraphBuilder: paragraphBuilder,
      listBuilder: ListBuilder(
          theme: theme, config: config, paragraphBuilder: paragraphBuilder),
      imageBuilder: ImageBuilder(config: config),
      shapeBuilder: ShapeBuilder(config: config),
    );

    final table = DocxTable(
      rows: [
        DocxTableRow(cells: [
          // Span 2 columns
          DocxTableCell(
            children: [
              DocxParagraph(children: [DocxText('Spanned')])
            ],
            colSpan: 2,
          ),
        ]),
        DocxTableRow(cells: [
          DocxTableCell.text('Cell 3'),
          DocxTableCell.text('Cell 4'),
        ]),
      ],
      gridColumns: [1000, 1000],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(table)),
    ));

    expect(find.text('Paragraph'), findsNWidgets(3));
  });

  testWidgets('TableBuilder handles vertical merge',
      (WidgetTester tester) async {
    final theme = DocxViewTheme.light();
    final config = const DocxViewConfig();
    final paragraphBuilder = MockParagraphBuilder();

    final builder = TableBuilder(
      theme: theme,
      config: config,
      paragraphBuilder: paragraphBuilder,
      listBuilder: ListBuilder(
          theme: theme, config: config, paragraphBuilder: paragraphBuilder),
      imageBuilder: ImageBuilder(config: config),
      shapeBuilder: ShapeBuilder(config: config),
    );

    final table = DocxTable(
      rows: [
        DocxTableRow(cells: [
          // Row 1, Col 1: Start merge (rowSpan=2)
          DocxTableCell(
            children: [
              DocxParagraph(children: [DocxText('Merged')])
            ],
            rowSpan: 2,
          ),
          DocxTableCell.text('R1C2'),
        ]),
        DocxTableRow(cells: [
          // Row 2, Col 1: Omitted (skipped)
          DocxTableCell.text('R2C2'),
        ]),
      ],
      gridColumns: [1000, 1000],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(table)),
    ));

    // We expect 3 paragraphs
    expect(find.text('Paragraph'), findsNWidgets(3));
  });

  testWidgets('bidiVisual mirrors the visual column order',
      (WidgetTester tester) async {
    final builder = _builder();
    final table = DocxTable(
      rows: [
        DocxTableRow(cells: [
          DocxTableCell.text('A'),
          DocxTableCell.text('B'),
        ]),
      ],
      gridColumns: [1000, 1000],
      bidiVisual: true,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(table)),
    ));

    // The cell row is laid out right-to-left (first logical cell on the right).
    final rtlRows = tester
        .widgetList<Row>(find.byType(Row))
        .where((r) => r.textDirection == TextDirection.rtl);
    expect(rtlRows, isNotEmpty);
  });

  testWidgets('textDirection tbRl rotates the cell content',
      (WidgetTester tester) async {
    final builder = _builder();
    final table = DocxTable(
      rows: [
        DocxTableRow(cells: [
          DocxTableCell(
            textDirection: DocxCellTextDirection.tbRl,
            children: const [
              DocxParagraph(children: [DocxText('rotated')])
            ],
          ),
        ]),
      ],
      gridColumns: [2000],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(table)),
    ));

    final rotated = tester
        .widgetList<RotatedBox>(find.byType(RotatedBox))
        .where((b) => b.quarterTurns == 1);
    expect(rotated, isNotEmpty);
  });

  testWidgets('default cell uses Word margins (108tw sides, 0 vertical)',
      (WidgetTester tester) async {
    final builder = _builder();
    final table = DocxTable(
      rows: [
        DocxTableRow(cells: [DocxTableCell.text('A')]),
      ],
      gridColumns: [2000],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(table)),
    ));

    final padded = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.padding)
        .whereType<EdgeInsets>()
        .where((e) => e.top == 0 && e.bottom == 0 && e.left > 7 && e.left < 8);
    expect(padded, isNotEmpty); // 108tw ≈ 7.2px sides
  });

  testWidgets('bordered cells keep their left+right (RTL-safe outer borders)',
      (WidgetTester tester) async {
    final builder = _builder();
    const b = DocxBorderSide(style: DocxBorder.single, size: 8);
    final table = DocxTable(
      rows: [
        DocxTableRow(cells: [DocxTableCell.text('A'), DocxTableCell.text('B')]),
      ],
      gridColumns: [1000, 1000],
      bidiVisual: true, // RTL table: outer side borders must not go missing
      style: const DocxTableStyle(
        borderTop: b,
        borderBottom: b,
        borderLeft: b,
        borderRight: b,
        borderInsideH: b,
        borderInsideV: b,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(table)),
    ));

    // Every cell draws both physical side borders, so the table's outer left and
    // right edges are present regardless of RTL mirroring.
    final cellBorders = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.border)
        .whereType<Border>()
        .where((bd) => bd.top.style == BorderStyle.solid)
        .toList();
    expect(cellBorders, isNotEmpty);
    expect(
      cellBorders.every((bd) =>
          bd.left.style == BorderStyle.solid &&
          bd.right.style == BorderStyle.solid),
      isTrue,
    );
  });

  testWidgets('dashed/dotted cell borders render visibly (item 46)',
      (WidgetTester tester) async {
    final builder = _builder();
    for (final style in const [DocxBorder.dashed, DocxBorder.dotted]) {
      final b = DocxBorderSide(style: style, size: 8);
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [DocxTableCell.text('A')]),
        ],
        gridColumns: [1000],
        style: DocxTableStyle(
            borderTop: b, borderBottom: b, borderLeft: b, borderRight: b),
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: builder.build(table))));

      final cellBorders = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .whereType<Border>()
          .where((bd) => bd.top.style == BorderStyle.solid)
          .toList();
      // A dashed/dotted border is at least a *visible* solid line — never the
      // invisible BorderStyle.none it collapsed to before.
      expect(cellBorders, isNotEmpty, reason: 'style $style must be visible');
    }
  });

  testWidgets('vertical merge continuation inherits the leader fill',
      (WidgetTester tester) async {
    final builder = _builder();
    final table = DocxTable(
      rows: [
        DocxTableRow(cells: [
          DocxTableCell(
            rowSpan: 2,
            shadingFill: 'D9E2F3', // light blue, like Word's shaded merged cell
            children: const [
              DocxParagraph(children: [DocxText('North')])
            ],
          ),
          DocxTableCell.text('120'),
        ]),
        DocxTableRow(cells: [DocxTableCell.text('plus')]),
      ],
      gridColumns: [1000, 1000],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(table)),
    ));

    final expected = const Color(0xFFD9E2F3);
    // At least two cell containers carry the merged fill: the leader and its
    // continuation placeholder (so the merge reads as one continuous block).
    final filled = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == expected)
        .length;
    expect(filled, greaterThanOrEqualTo(2));
  });

  testWidgets('vertical merge shows no internal horizontal rule',
      (WidgetTester tester) async {
    final builder = _builder();
    const b = DocxBorderSide(style: DocxBorder.single, size: 8);
    final table = DocxTable(
      rows: [
        DocxTableRow(cells: [
          DocxTableCell(rowSpan: 2, children: const [
            DocxParagraph(children: [DocxText('Merged')])
          ]),
          DocxTableCell.text('R1'),
        ]),
        DocxTableRow(cells: [DocxTableCell.text('R2')]),
      ],
      gridColumns: [1000, 1000],
      style: const DocxTableStyle(
        borderTop: b,
        borderBottom: b,
        borderLeft: b,
        borderRight: b,
        borderInsideH: b,
        borderInsideV: b,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(table)),
    ));

    final cellBorders = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.border)
        .whereType<Border>()
        .toList();

    // The merge leader draws its top but suppresses its bottom (no internal rule
    // across the merge); the continuation placeholder suppresses its top.
    expect(
      cellBorders.any((bd) =>
          bd.top.style == BorderStyle.solid &&
          bd.bottom.style == BorderStyle.none),
      isTrue,
      reason: 'merge leader must have a top but no internal bottom rule',
    );
    expect(
      cellBorders.any((bd) => bd.top.style == BorderStyle.none),
      isTrue,
      reason: 'merge continuation must suppress its top rule',
    );
  });

  testWidgets('§F.3 trHeight exact clips to a fixed height',
      (WidgetTester tester) async {
    final builder = _builder();
    final table = DocxTable(
      rows: [
        DocxTableRow(
          height: 300, // 20px exact
          heightRule: DocxTableRowHeightRule.exact,
          cells: [DocxTableCell.text('tall content here')],
        ),
      ],
      gridColumns: [2000],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(table)),
    ));

    // An exact row is a fixed-height SizedBox with a clip (not a ConstrainedBox).
    final fixed = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((s) => s.height != null && (s.height! - 20).abs() < 0.01);
    expect(fixed, isNotEmpty);
    expect(find.byType(ClipRect), findsWidgets);
  });
}

TableBuilder _builder() {
  final theme = DocxViewTheme.light();
  const config = DocxViewConfig();
  final paragraphBuilder = MockParagraphBuilder();
  return TableBuilder(
    theme: theme,
    config: config,
    paragraphBuilder: paragraphBuilder,
    listBuilder: ListBuilder(
        theme: theme, config: config, paragraphBuilder: paragraphBuilder),
    imageBuilder: ImageBuilder(config: config),
    shapeBuilder: ShapeBuilder(config: config),
  );
}
