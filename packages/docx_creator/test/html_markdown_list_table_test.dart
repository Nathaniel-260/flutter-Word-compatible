import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('HTML list/dl parsing', () {
    test('preserves nested list start index', () async {
      final nodes =
          await DocxParser.fromHtml('<ol start="5"><li>Five</li><li>Six</li></ol>');
      final list = nodes.single as DocxList;
      expect(list.startIndex, 5);
    });

    test('stamps a nested sublist with an override style for its own type',
        () async {
      final html = '<ol><li>A<ul><li>B</li></ul></li></ol>';
      final nodes = await DocxParser.fromHtml(html);
      final list = nodes.single as DocxList;

      expect(list.items.length, 2);
      expect(list.items[0].level, 0);
      expect(list.items[1].level, 1);
      expect(list.items[1].overrideStyle?.bullet, DocxListStyle.disc.bullet);
    });

    test('renders <dl>/<dt>/<dd> as separate paragraphs, not garbled text',
        () async {
      final html = '<dl><dt>Term</dt><dd>Definition</dd></dl>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 2);
      final dt = (nodes[0] as DocxParagraph).children.single as DocxText;
      final dd = (nodes[1] as DocxParagraph).children.single as DocxText;
      expect(dt.content, 'Term');
      expect(dt.fontWeight, DocxFontWeight.bold);
      expect(dd.content, 'Definition');
    });
  });

  group('Markdown table alignment', () {
    test('applies column alignment from the delimiter row', () async {
      final md = '''
| Left | Center | Right |
|:-----|:------:|------:|
| L    | C      | R     |
''';
      final nodes = await MarkdownParser.parse(md);
      final table = nodes.single as DocxTable;
      final dataRow = table.rows[1];

      expect((dataRow.cells[0].children.single as DocxParagraph).align,
          DocxAlign.left);
      expect((dataRow.cells[1].children.single as DocxParagraph).align,
          DocxAlign.center);
      expect((dataRow.cells[2].children.single as DocxParagraph).align,
          DocxAlign.right);
    });

    test('marks the header row as a header row', () async {
      final md = '| H |\n|---|\n| v |\n';
      final nodes = await MarkdownParser.parse(md);
      final table = nodes.single as DocxTable;
      expect(table.rows[0].isHeader, isTrue);
      expect(table.rows[1].isHeader, isFalse);
    });
  });

  group('Markdown list structure', () {
    test('merges a loose multi-paragraph list item into one entry', () async {
      final md = '1. First paragraph.\n\n   Second paragraph, same item.\n'
          '2. Second item.\n';
      final nodes = await MarkdownParser.parse(md);
      final list = nodes.single as DocxList;

      expect(list.items.length, 2);
      final combined = list.items[0].children
          .whereType<DocxText>()
          .map((t) => t.content)
          .join();
      expect(combined, contains('First paragraph.'));
      expect(combined, contains('Second paragraph, same item.'));
    });

    test('preserves an ordered list start number', () async {
      final md = '5. Five\n6. Six\n';
      final nodes = await MarkdownParser.parse(md);
      final list = nodes.single as DocxList;
      expect(list.startIndex, 5);
    });

    test('stamps a nested sublist with its own type override', () async {
      final md = '- Level 1\n  1. Level 2\n  2. Level 2 item 2\n- Level 1 again\n';
      final nodes = await MarkdownParser.parse(md);
      final list = nodes.single as DocxList;

      final nestedItems = list.items.where((i) => i.level == 1).toList();
      expect(nestedItems, isNotEmpty);
      for (final item in nestedItems) {
        expect(item.overrideStyle?.numberFormat, DocxNumberFormat.decimal);
      }
    });
  });
}
