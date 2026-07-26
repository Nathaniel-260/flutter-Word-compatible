import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('HTML CSS value/unit parsing', () {
    test('converts font-size px to points', () async {
      final nodes =
          await DocxParser.fromHtml('<p><span style="font-size: 16px;">x</span></p>');
      final para = nodes.single as DocxParagraph;
      final text = para.children.single as DocxText;
      expect(text.fontSize, 12); // 16px * 0.75 = 12pt
    });

    test('converts font-size em to points using the default base size',
        () async {
      final nodes = await DocxParser.fromHtml(
          '<p><span style="font-size: 1.5em;">x</span></p>');
      final para = nodes.single as DocxParagraph;
      final text = para.children.single as DocxText;
      expect(text.fontSize, 18); // 1.5 * 12pt base
    });

    test('recognizes uppercase/minified style declarations', () async {
      final nodes = await DocxParser.fromHtml(
          '<p><span style="FONT-WEIGHT:BOLD;text-align:center">x</span></p>');
      final para = nodes.single as DocxParagraph;
      final text = para.children.single as DocxText;
      expect(text.fontWeight, DocxFontWeight.bold);
    });

    test('treats numeric font-weight 600+ as bold', () async {
      final nodes = await DocxParser.fromHtml(
          '<p><span style="font-weight: 800;">x</span></p>');
      final para = nodes.single as DocxParagraph;
      final text = para.children.single as DocxText;
      expect(text.fontWeight, DocxFontWeight.bold);
    });

    test('does not treat font-weight below 600 as bold', () async {
      final nodes = await DocxParser.fromHtml(
          '<p><span style="font-weight: 400;">x</span></p>');
      final para = nodes.single as DocxParagraph;
      final text = para.children.single as DocxText;
      expect(text.fontWeight, DocxFontWeight.normal);
    });

    test('parses hsl() colors', () async {
      final nodes = await DocxParser.fromHtml(
          '<p><span style="color: hsl(0, 100%, 50%);">x</span></p>');
      final para = nodes.single as DocxParagraph;
      final text = para.children.single as DocxText;
      expect(text.color?.hex, 'FF0000');
    });

    test('applies a class-based text-align even in uppercase form',
        () async {
      final html = '<p style="TEXT-ALIGN: CENTER;">x</p>';
      final nodes = await DocxParser.fromHtml(html);
      final para = nodes.single as DocxParagraph;
      expect(para.align, DocxAlign.center);
    });

    test('applies margin-left/text-indent as paragraph indentation',
        () async {
      final html =
          '<p style="margin-left: 40px; text-indent: 20px;">Indented</p>';
      final nodes = await DocxParser.fromHtml(html);
      final para = nodes.single as DocxParagraph;
      expect(para.indentLeft, 600); // 40px * 0.75pt/px * 20twips/pt
      expect(para.indentFirstLine, 300);
    });

    test('maps every class in a grouped selector to the same style',
        () async {
      final html = '''
<html><head><style>.foo, .bar { color: #FF0000; }</style></head>
<body><p class="foo">A</p><p class="bar">B</p></body></html>
''';
      final nodes = await DocxParser.fromHtml(html);
      final a = (nodes[0] as DocxParagraph).children.single as DocxText;
      final b = (nodes[1] as DocxParagraph).children.single as DocxText;
      expect(a.color?.hex, 'FF0000');
      expect(b.color?.hex, 'FF0000');
    });
  });
}
