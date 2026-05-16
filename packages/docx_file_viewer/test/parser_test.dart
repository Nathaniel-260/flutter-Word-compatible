// ignore_for_file: avoid_dynamic_calls

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:docx_file_viewer/src/theme/docx_view_theme.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/widgets.dart' show WidgetSpan;
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Minimal [ReaderContext] that resolves two named styles used by the tests.
class _BodyTextContext extends ReaderContext {
  _BodyTextContext() : super(Archive());

  @override
  DocxStyle resolveStyle(String? styleId) {
    if (styleId == 'BodyText') {
      return const DocxStyle(
        id: 'BodyText',
        fontSize: 24, // 12 pt stored as half-points in docx_creator
        fonts: DocxFont(ascii: 'Times New Roman'),
      );
    }
    if (styleId == 'Heading1') {
      return const DocxStyle(
        id: 'Heading1',
        fontSize: 48, // 24 pt
        fontWeight: DocxFontWeight.bold,
        fonts: DocxFont(ascii: 'Calibri'),
      );
    }
    return super.resolveStyle(styleId);
  }
}

void main() {
  group('Parser Unit Tests', () {
    // -----------------------------------------------------------------------
    // Test 1 — Properties Cascade Rule
    // A run with no w:rPr element must inherit font and size from the parent
    // paragraph style, implementing the cascade:
    //   Document defaults → Named style → Paragraph → Run
    // -----------------------------------------------------------------------
    test(
        'Run without inline styling inherits font family and size from paragraph style',
        () {
      final context = _BodyTextContext();
      final parser = InlineParser(context);
      final parentStyle = context.resolveStyle('BodyText');

      // A bare <w:r> with only text — no w:rPr override.
      final xml = XmlDocument.parse('''
        <w:r xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:t>Hello</w:t>
        </w:r>
      ''');

      final run =
          parser.parseRun(xml.rootElement, parentStyle: parentStyle) as DocxText;

      expect(run.content, 'Hello');
      expect(run.fontSize, 24,
          reason: 'fontSize must cascade from the BodyText paragraph style');
      expect(run.fontFamily, 'Times New Roman',
          reason: 'fontFamily must cascade from the BodyText paragraph style');
    });

    // -----------------------------------------------------------------------
    // Test 2 — Table Structural Edge Cases (mixed colSpan + rowSpan)
    // A table XML node containing horizontal and vertical merges must produce
    // a DocxTable whose cells carry the correct colSpan and rowSpan values.
    // This verifies that the layout matrix builder constructs proper dimensions.
    // -----------------------------------------------------------------------
    test(
        'TableParser builds correct grid dimensions for mixed colSpan and rowSpan',
        () {
      final context = _BodyTextContext();
      final inlineParser = InlineParser(context);
      final parser = TableParser(context, inlineParser);

      // Layout:
      //   Row 0: [A (colSpan=2)]
      //   Row 1: [B (rowSpan=2)] [C]
      //   Row 2: [B-cont (skip)] [D]
      final xml = XmlDocument.parse('''
        <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:tblPr/>
          <w:tblGrid>
            <w:gridCol w:w="2000"/>
            <w:gridCol w:w="3000"/>
          </w:tblGrid>
          <w:tr>
            <w:tc>
              <w:tcPr><w:gridSpan w:val="2"/></w:tcPr>
              <w:p><w:r><w:t>A</w:t></w:r></w:p>
            </w:tc>
          </w:tr>
          <w:tr>
            <w:tc>
              <w:tcPr><w:vMerge w:val="restart"/></w:tcPr>
              <w:p><w:r><w:t>B</w:t></w:r></w:p>
            </w:tc>
            <w:tc>
              <w:p><w:r><w:t>C</w:t></w:r></w:p>
            </w:tc>
          </w:tr>
          <w:tr>
            <w:tc>
              <w:tcPr><w:vMerge/></w:tcPr>
              <w:p/>
            </w:tc>
            <w:tc>
              <w:p><w:r><w:t>D</w:t></w:r></w:p>
            </w:tc>
          </w:tr>
        </w:tbl>
      ''');

      final table = parser.parse(xml.rootElement);

      // Grid columns
      final grid = table.resolvedGridColumns;
      expect(grid.length, 2, reason: 'Two grid columns must be defined');
      expect(grid[0], 2000);
      expect(grid[1], 3000);

      // Row 0: single cell spanning both columns
      expect(table.rows[0].cells.length, 1);
      expect(table.rows[0].cells[0].colSpan, 2,
          reason: 'Row-0 cell must span 2 columns');

      // Row 1: vMerge restart cell must have rowSpan > 1
      expect(table.rows[1].cells.length, 2);
      expect(table.rows[1].cells[0].rowSpan, greaterThan(1),
          reason: 'vMerge restart cell must carry rowSpan > 1');
    });

    // -----------------------------------------------------------------------
    // Test 3 — Crash Immunity for Malformed / Extreme Content
    // The rendering pipeline must never throw for corrupt, empty, or extreme
    // input inside run text fields.
    // -----------------------------------------------------------------------
    test(
        'ParagraphBuilder renders without crashing for empty and extreme content',
        () {
      final builder = ParagraphBuilder(
        config: const DocxViewConfig(),
        theme: DocxViewTheme.light(),
      );

      // Empty paragraph
      expect(
        () => builder.build(const DocxParagraph(children: [])),
        returnsNormally,
        reason: 'Empty paragraph must not throw',
      );

      // DocxText with empty content string
      expect(
        () => builder.build(DocxParagraph(children: [DocxText('')])),
        returnsNormally,
        reason: 'Run with empty string must not throw',
      );

      // Multiple runs with mismatched / extreme values
      expect(
        () => builder.build(DocxParagraph(children: [
          const DocxText('Normal'),
          DocxText('Superscript', fontSize: 6),
          DocxText('Huge', fontSize: 200),
          DocxText(
            'Unicode \u{1F4C4}\u{1F5C3}',
          ),
        ])),
        returnsNormally,
        reason: 'Extreme font sizes and unicode content must not throw',
      );

      // Paragraph with all spacing / indent fields set to zero
      expect(
        () => builder.build(const DocxParagraph(
          children: [DocxText('Zeroed')],
          spacingBefore: 0,
          spacingAfter: 0,
          indentLeft: 0,
          indentRight: 0,
          indentFirstLine: 0,
          lineSpacing: 0,
        )),
        returnsNormally,
        reason: 'All-zero spacing and indent values must not throw',
      );
    });

    // -----------------------------------------------------------------------
    // Test 4 — w:ind w:firstLine → positive first-line indent
    // When indentFirstLine > 0, buildInlineSpans must prepend a WidgetSpan
    // spacer so the first line is visually indented relative to the body.
    // -----------------------------------------------------------------------
    test('buildInlineSpans prepends first-line indent spacer when requested',
        () {
      final builder = ParagraphBuilder(
        config: const DocxViewConfig(),
        theme: DocxViewTheme.light(),
      );

      final spansWithIndent = builder.buildInlineSpans(
        [DocxText('Body text')],
        firstLineIndentPx: 36.0,
      );

      final spansWithout = builder.buildInlineSpans(
        [DocxText('Body text')],
        // no firstLineIndentPx
      );

      // With indent: first span is a WidgetSpan (the spacer), second is the text
      expect(spansWithIndent.first, isA<WidgetSpan>(),
          reason: 'First span must be the indent WidgetSpan');
      expect(spansWithIndent.length, greaterThan(spansWithout.length),
          reason: 'Indented span list must be longer by the spacer');
    });

    // -----------------------------------------------------------------------
    // Test 5 — w:lineRule handling
    // 'exact' and 'atLeast' rules must be clamped correctly; 'auto' is the
    // default behaviour (ratio = lineSpacing / 240).
    // -----------------------------------------------------------------------
    test('_resolveLineHeightScale respects lineRule variants', () {
      final builder = ParagraphBuilder(
        config: const DocxViewConfig(),
        theme: DocxViewTheme.light(),
      );

      // Helper: build a paragraph with specific spacing + rule, then check
      // that the paragraph renders without crashing (scale is applied internally).
      void checkRenders(String? lineRule, int lineSpacing) {
        final para = DocxParagraph(
          children: [DocxText('Test')],
          lineSpacing: lineSpacing,
          lineRule: lineRule,
        );
        expect(() => builder.build(para), returnsNormally,
            reason: 'lineRule=$lineRule lineSpacing=$lineSpacing must not throw');
      }

      checkRenders('auto', 240); // 1× spacing
      checkRenders('auto', 480); // 2× spacing
      checkRenders('exact', 240); // exact single line
      checkRenders('exact', 120); // exact half-line
      checkRenders('atLeast', 360); // at-least 1.5×
      checkRenders(null, 240); // null rule → auto
    });
  });
}
