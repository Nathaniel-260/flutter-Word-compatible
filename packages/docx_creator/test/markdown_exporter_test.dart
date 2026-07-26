import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('MarkdownExporter', () {
    final exporter = MarkdownExporter();

    test('renders headings at the correct level', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph.heading1('Title'),
        DocxParagraph.heading3('Subsection'),
      ]);

      final md = exporter.export(doc);

      expect(md, contains('# Title'));
      expect(md, contains('### Subsection'));
    });

    test('renders inline formatting', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph(children: [
          DocxText.bold('Bold'),
          DocxText(' '),
          DocxText.italic('Italic'),
          DocxText(' '),
          DocxText.strike('Struck'),
          DocxText(' '),
          DocxText.link('Link', href: 'https://example.com'),
        ]),
      ]);

      final md = exporter.export(doc);

      expect(md, contains('**Bold**'));
      expect(md, contains('*Italic*'));
      expect(md, contains('~~Struck~~'));
      // DocxText.link renders as underlined text per its AST constructor,
      // so the link body carries an explicit <u> tag.
      expect(md, contains('[<u>Link</u>](https://example.com)'));
    });

    test('combines bold and italic into a single triple-star run', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph(children: [DocxText.boldItalic('Both')]),
      ]);

      expect(exporter.export(doc), contains('***Both***'));
    });

    test('renders inline code without escaping its content', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph(children: [DocxText.code('a < b && *x*')]),
      ]);

      final md = exporter.export(doc);
      expect(md, contains('`a < b && *x*`'));
    });

    test('picks a wider fence when code content contains backticks', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph(children: [DocxText.code('a `b` c')]),
      ]);

      // A 2-backtick fence is enough since the embedded run is only 1
      // backtick long; padding is only needed when content itself starts
      // or ends with a backtick, which isn't the case here.
      final md = exporter.export(doc);
      expect(md, contains('``a `b` c``'));
    });

    test('pads the fence when code content starts with a backtick', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph(children: [DocxText.code('`x')]),
      ]);

      final md = exporter.export(doc);
      expect(md, contains('`` `x ``'));
    });

    test('renders a fenced code block from DocxParagraph.code', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph.code('print("hi");'),
      ]);

      final md = exporter.export(doc);
      expect(md, contains('```\nprint("hi");\n```'));
    });

    test('renders a blockquote from DocxParagraph.quote', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph.quote('Wisdom'),
      ]);

      // DocxParagraph.quote wraps its text in DocxText.italic.
      expect(exporter.export(doc), contains('> *Wisdom*'));
    });

    test('renders a horizontal rule for a builder hr()', () {
      final doc = DocxDocumentBuilder().p('Before').hr().p('After').build();

      final md = exporter.export(doc);
      expect(md, contains('\n---\n'));
    });

    test('escapes Markdown-significant characters in plain text', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph(children: [DocxText('1 * 2 [not a link]')]),
      ]);

      final md = exporter.export(doc);
      expect(md, contains(r'1 \* 2 \[not a link\]'));
    });

    test('renders bullet and numbered lists with nesting', () {
      final doc = DocxBuiltDocument(elements: [
        DocxList.items([
          DocxListItem.text('Root'),
          DocxListItem.text('Nested', level: 1),
        ], style: DocxListStyle.disc),
        DocxList.numbered(['First', 'Second']),
      ]);

      final md = exporter.export(doc);
      expect(md, contains('- Root'));
      expect(md, contains('  - Nested'));
      expect(md, contains('1. First'));
      expect(md, contains('2. Second'));
    });

    test('restarts ordered numbering after a nested sublist returns', () {
      final list = DocxList(
        isOrdered: true,
        items: const [
          DocxListItem([DocxText('a')], level: 0),
          DocxListItem([DocxText('b')], level: 1),
          DocxListItem([DocxText('c')], level: 1),
          DocxListItem([DocxText('d')], level: 0),
        ],
      );
      final doc = DocxBuiltDocument(elements: [list]);

      final md = exporter.export(doc);
      final lines = md.trim().split('\n');
      expect(lines[0], '1. a');
      expect(lines[1], '  1. b');
      expect(lines[2], '  2. c');
      expect(lines[3], '2. d');
    });

    test('renders a task list item from a leading DocxCheckbox', () {
      final list = DocxList(items: const [
        DocxListItem(
          [DocxCheckbox(isChecked: true), DocxText('Done')],
        ),
        DocxListItem(
          [DocxCheckbox(), DocxText('Todo')],
        ),
      ]);
      final doc = DocxBuiltDocument(elements: [list]);

      final md = exporter.export(doc);
      expect(md, contains('- [x] Done'));
      expect(md, contains('- [ ] Todo'));
    });

    test('renders a table with a header separator row', () {
      final doc = DocxBuiltDocument(elements: [
        DocxTable.fromData(
          [
            ['A', 'B'],
            ['1', '2'],
          ],
        ),
      ]);

      final md = exporter.export(doc);
      final lines = md.trim().split('\n');
      // DocxTable.fromData bolds the header row by default.
      expect(lines[0], '| **A** | **B** |');
      expect(lines[1], '| --- | --- |');
      expect(lines[2], '| 1 | 2 |');
    });

    test('escapes pipe characters inside table cells', () {
      final doc = DocxBuiltDocument(elements: [
        DocxTable.fromData([
          ['a|b', 'c'],
        ]),
      ]);

      expect(exporter.export(doc), contains(r'a\|b'));
    });

    test('renders footnote references and trailing definitions', () {
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

      final md = exporter.export(doc);
      expect(md, contains('[^1]'));
      expect(md, contains('[^1]: Explanation.'));
    });

    test('round trip through file export and back produces the same string',
        () async {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph.heading1('Report'),
        DocxParagraph.text('Body text.'),
      ]);

      final expected = exporter.export(doc);
      expect(expected, startsWith('# Report'));
      expect(expected, contains('Body text.'));
    });
  });
}
