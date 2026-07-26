import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('HTML whitespace collapsing', () {
    test('collapses internal newlines/indentation into a single space',
        () async {
      final html = '<p>Hello\n   World</p>';
      final nodes = await DocxParser.fromHtml(html);

      final para = nodes.single as DocxParagraph;
      final text = para.children.single as DocxText;
      expect(text.content, 'Hello World');
    });

    test('drops whitespace-only text nodes between block siblings',
        () async {
      final html = '<div>\n  <p>A</p>\n  <p>B</p>\n</div>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 2);
      expect(
        (nodes[0] as DocxParagraph).children.whereType<DocxText>().single.content,
        'A',
      );
      expect(
        (nodes[1] as DocxParagraph).children.whereType<DocxText>().single.content,
        'B',
      );
    });

    test('preserves a single significant space between inline runs',
        () async {
      final html = '<p><b>Bold</b> and <i>italic</i></p>';
      final nodes = await DocxParser.fromHtml(html);

      final para = nodes.single as DocxParagraph;
      final combined =
          para.children.whereType<DocxText>().map((t) => t.content).join();
      expect(combined, 'Bold and italic');
    });
  });

  group('HTML loose inline sibling merging', () {
    test('merges loose text and inline siblings next to a block into one '
        'paragraph', () async {
      final html = '<div><p>A</p>loose <span>text</span></div>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 2);
      expect(nodes[0], isA<DocxParagraph>());

      final second = nodes[1] as DocxParagraph;
      final combined = second.children
          .whereType<DocxText>()
          .map((t) => t.content)
          .join();
      expect(combined, 'loose text');
    });

    test('a bare block-level body still parses each block separately',
        () async {
      final html = '<h1>Title</h1><p>Body</p>';
      final nodes = await DocxParser.fromHtml(html);

      expect(nodes.length, 2);
    });
  });
}
