import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('HTML Nested Children', () {
    test('should parse nested formatting in spans correctly', () async {
      final html =
          '<p>Text <span>with <b>bold</b> and <i>italic</i></span>.</p>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 1);
      final p = nodes[0] as DocxParagraph;
      expect(p.children.length, 6);

      expect((p.children[0] as DocxText).content, 'Text ');
      expect((p.children[1] as DocxText).content, 'with ');

      final boldText = p.children[2] as DocxText;
      expect(boldText.content, 'bold');
      expect(boldText.fontWeight, DocxFontWeight.bold);

      expect((p.children[3] as DocxText).content, ' and ');

      final italicText = p.children[4] as DocxText;
      expect(italicText.content, 'italic');
      expect(italicText.fontStyle, DocxFontStyle.italic);

      expect((p.children[5] as DocxText).content, '.');
    });

    test('should parse nested formatting in anchors correctly', () async {
      final html = '<p><a href="url">Link with <b>bold</b></a></p>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 1);
      final p = nodes[0] as DocxParagraph;
      expect(p.children.length, 2);

      final linkPart1 = p.children[0] as DocxText;
      expect(linkPart1.content, 'Link with ');
      expect(linkPart1.href, 'url');

      final linkPart2 = p.children[1] as DocxText;
      expect(linkPart2.content, 'bold');
      expect(linkPart2.href, 'url');
      expect(linkPart2.fontWeight, DocxFontWeight.bold);
    });

    test('should parse nested images in spans correctly', () async {
      final html =
          '<p>Text <span><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==" alt="img"></span></p>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 1);
      final p = nodes[0] as DocxParagraph;
      expect(p.children.length, 2);
      expect(p.children[1], isA<DocxInlineImage>());
      expect((p.children[1] as DocxInlineImage).altText, 'img');
    });

    test('should parse nested blocks in div correctly', () async {
      final html = '<div><p>P1</p><div><p>P2</p><p>P3</p></div></div>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 3);
      expect(nodes[0], isA<DocxParagraph>());
      expect(nodes[1], isA<DocxParagraph>());
      expect(nodes[2], isA<DocxParagraph>());

      expect((nodes[0] as DocxParagraph).children[0], isA<DocxText>());
      expect(
          ((nodes[0] as DocxParagraph).children[0] as DocxText).content, 'P1');
      expect(
          ((nodes[1] as DocxParagraph).children[0] as DocxText).content, 'P2');
      expect(
          ((nodes[2] as DocxParagraph).children[0] as DocxText).content, 'P3');
    });

    test('should parse multiple blocks in li correctly', () async {
      final html = '<ul><li><p>Para 1</p><p>Para 2</p></li></ul>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 1);
      final list = nodes[0] as DocxList;
      expect(list.items.length, 2);
      expect(((list.items[0].children[0]) as DocxText).content, 'Para 1');
      expect(((list.items[1].children[0]) as DocxText).content, 'Para 2');
    });

    test('should parse span inside div correctly without break', () async {
      final html = '<div>Text <span>inside span</span> and more text.</div>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 1);
      expect(nodes[0], isA<DocxParagraph>());
      final p = nodes[0] as DocxParagraph;
      expect(p.children.length, 3);
      expect((p.children[0] as DocxText).content, 'Text ');
      expect((p.children[1] as DocxText).content, 'inside span');
      expect((p.children[2] as DocxText).content, ' and more text.');
    });
  });

  group('Markdown Nested Children', () {
    test('should parse nested formatting correctly', () async {
      final markdown = 'Outer **Bold _Italic_** end.';
      final nodes = await DocxParser.fromMarkdown(markdown);

      expect(nodes.length, 1);
      final p = nodes[0] as DocxParagraph;

      final boldItalic =
          p.children.firstWhere((c) => c is DocxText && c.content == 'Italic')
              as DocxText;
      expect(boldItalic.fontWeight, DocxFontWeight.bold);
      expect(boldItalic.fontStyle, DocxFontStyle.italic);
    });

    test('should parse rich content in table cells correctly', () async {
      final markdown = '''
| Header |
| --- |
| **Bold** [Link](url) |
''';
      final nodes = await DocxParser.fromMarkdown(markdown);

      expect(nodes.length, 1);
      final table = nodes[0] as DocxTable;

      // Header cell
      final headerCell = table.rows[0].cells[0];
      final headerText =
          (headerCell.children[0] as DocxParagraph).children[0] as DocxText;
      expect(headerText.content, 'Header');
      expect(headerText.fontWeight, DocxFontWeight.bold);

      // Body cell
      final bodyCell = table.rows[1].cells[0];
      final bodyPara = bodyCell.children[0] as DocxParagraph;

      final boldText = bodyPara.children[0] as DocxText;
      expect(boldText.content, 'Bold');
      expect(boldText.fontWeight, DocxFontWeight.bold);

      final linkText = bodyPara.children[2] as DocxText;
      expect(linkText.content, 'Link');
      expect(linkText.href, 'url');
    });
  });
}
