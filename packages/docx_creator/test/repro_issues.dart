import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('Reproduction of Issues', () {
    test('H1 with nested bold text should maintain children', () async {
      final html = '<h1>Title <b>Bold</b></h1>';
      final elements = await DocxParser.fromHtml(html);

      expect(elements.length, 1);
      expect(elements[0], isA<DocxParagraph>());
      final para = elements[0] as DocxParagraph;
      expect(para.styleId, 'Heading1');

      // Currently it likely has 1 child with text 'Title Bold'
      // It should have 2 children: 'Title ' and 'Bold' (bold)
      expect(para.children.length, 2);
      expect(para.children[0], isA<DocxText>());
      expect(para.children[1], isA<DocxText>());
      expect((para.children[1] as DocxText).isBold, true);
    });

    test('Multiple text decorations (Underline + Strike) should be supported',
        () async {
      final html =
          '<p><u style="text-decoration: line-through;">Underline and Strike</u></p>';
      final elements = await DocxParser.fromHtml(html);

      expect(elements.length, 1);
      final para = elements[0] as DocxParagraph;
      final text = para.children[0] as DocxText;

      expect(text.content, 'Underline and Strike');
      expect(text.isUnderline, true, reason: 'Should be underlined');
      expect(text.isStrike, true, reason: 'Should have strikethrough');
    });

    test(
        'Reproduction of Issues: Hyperlink with existing decoration (strikethrough)',
        () async {
      // Added async here as DocxParser.fromHtml is async
      const html = '<s><a href="https://example.com">link</a></s>';
      final elements =
          await DocxParser.fromHtml(html); // Changed to fromHtml and await
      final paragraph =
          elements.first as DocxParagraph; // Changed doc.elements to elements
      final text = paragraph.children.first as DocxText;

      expect(text.content, contains('link'));
      expect(text.href, equals('https://example.com'));
      expect(text.decorations, contains(DocxTextDecoration.strikethrough));
      expect(text.decorations, contains(DocxTextDecoration.underline));
    });
  });
}
