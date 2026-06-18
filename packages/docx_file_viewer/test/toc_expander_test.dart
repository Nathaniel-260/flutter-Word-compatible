import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/pagination/toc_expander.dart';
import 'package:flutter_test/flutter_test.dart';

/// Part K.1 — a Table of Contents is shown as its cached paragraphs so it flows
/// and renders through the normal paragraph path (leader tabs + live PAGEREF).
void main() {
  group('expandTocBlocks', () {
    test('replaces a TOC block with its cached content, in place', () {
      final toc = DocxTableOfContents(cachedContent: [
        DocxParagraph(children: const [
          DocxText('Chapter One'),
          DocxTab(),
          DocxPageRef('_Toc1', cachedText: '3'),
        ]),
        DocxParagraph(children: const [
          DocxText('Chapter Two'),
          DocxTab(),
          DocxPageRef('_Toc2', cachedText: '7'),
        ]),
      ]);
      final input = <DocxNode>[
        DocxParagraph(children: const [DocxText('Before')]),
        toc,
        DocxParagraph(children: const [DocxText('After')]),
      ];

      final out = expandTocBlocks(input);
      expect(out.length, 4); // Before + 2 TOC entries + After
      expect(out.whereType<DocxTableOfContents>(), isEmpty);
      final texts = out
          .whereType<DocxParagraph>()
          .map((p) =>
              p.children.whereType<DocxText>().map((t) => t.content).join())
          .toList();
      expect(texts, ['Before', 'Chapter One', 'Chapter Two', 'After']);
    });

    test('a document without a TOC returns the same list instance', () {
      final input = <DocxNode>[
        DocxParagraph(children: const [DocxText('Body')]),
      ];
      expect(identical(expandTocBlocks(input), input), isTrue);
    });
  });
}
