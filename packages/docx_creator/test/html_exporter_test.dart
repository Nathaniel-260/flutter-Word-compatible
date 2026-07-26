import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('HtmlExporter node coverage', () {
    final exporter = HtmlExporter();

    test('renders a basic paragraph and table', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph.heading1('Title'),
        DocxTable.fromData([
          ['A', 'B'],
        ]),
      ]);

      final html = exporter.export(doc);
      expect(html, contains('<h1'));
      expect(html, contains('Title'));
      expect(html, contains('<table>'));
    });

    test('does not drop the text content of a drop cap paragraph', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph.text('Before'),
        DocxDropCap(
          letter: 'O',
          lines: 3,
          restOfParagraph: [DocxText('nce upon a time...')],
        ),
        DocxParagraph.text('After'),
      ]);

      final html = exporter.export(doc);
      expect(html, contains('Before'));
      expect(html, contains('class="drop-cap">O</span>'));
      expect(html, contains('nce upon a time...'));
      expect(html, contains('After'));
    });

    test('renders a block shape instead of dropping it', () {
      final doc = DocxBuiltDocument(elements: [
        DocxShapeBlock.rectangle(
          width: 120,
          height: 40,
          fillColor: DocxColor('#FF0000'),
          text: 'Click Me',
        ),
      ]);

      final html = exporter.export(doc);
      expect(html, contains('Click Me'));
      expect(html, contains('background-color: #FF0000'));
    });

    test('renders TOC cached content instead of dropping it', () {
      final doc = DocxBuiltDocument(elements: [
        DocxTableOfContents(
          cachedContent: [DocxParagraph.text('Chapter 1 ... 1')],
        ),
      ]);

      final html = exporter.export(doc);
      expect(html, contains('Chapter 1 ... 1'));
      expect(html, contains('class="toc"'));
    });

    test('marks section breaks and raw XML with a comment rather than '
        'silently dropping them', () {
      final doc = DocxBuiltDocument(elements: [
        DocxSectionBreakBlock(DocxSectionDef()),
        const DocxRawXml('<w:bookmarkStart w:id="0" w:name="x"/>'),
      ]);

      final html = exporter.export(doc);
      expect(html, contains('<!-- section break -->'));
      expect(html, contains('<!-- raw OOXML content omitted -->'));
    });

    test('renders a checkbox glyph inline', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph(children: const [DocxCheckbox(isChecked: true)]),
      ]);

      expect(exporter.export(doc), contains('☒'));
    });

    test('renders footnote references linked to their definitions', () {
      final doc = DocxBuiltDocument(
        elements: [
          DocxParagraph(children: [
            DocxText('See note'),
            const DocxFootnoteRef(footnoteId: 1),
          ]),
        ],
        footnotes: [
          DocxFootnote(
            footnoteId: 1,
            content: [DocxParagraph.text('Explanation.')],
          ),
        ],
      );

      final html = exporter.export(doc);
      expect(html, contains('href="#fn-1"'));
      expect(html, contains('id="fn-1"'));
      expect(html, contains('Explanation.'));
    });
  });
}
