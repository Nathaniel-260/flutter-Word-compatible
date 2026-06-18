import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/pagination/field_substitution.dart';
import 'package:docx_file_viewer/src/pagination/page_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Pulls the concrete text out of a substituted paragraph.
  String textOf(DocxNode block) => (block as DocxParagraph)
      .children
      .whereType<DocxText>()
      .map((t) => t.content)
      .join();

  group('FieldSubstitution', () {
    test('resolves PAGE and NUMPAGES to the page context values', () {
      final footer = <DocxBlock>[
        DocxParagraph(children: const [
          DocxText('Page '),
          DocxPageNumber(),
          DocxText(' of '),
          DocxPageCount(),
        ]),
      ];
      const ctx = PageContext(pageNumber: 3, totalPages: 10);

      final out = FieldSubstitution.apply(footer, ctx);
      expect(textOf(out.first), 'Page 3 of 10');
    });

    test('SECTIONPAGES uses sectionPages, not totalPages', () {
      final footer = <DocxBlock>[
        DocxParagraph(children: const [DocxPageCount(sectionScope: true)]),
      ];
      const ctx = PageContext(pageNumber: 2, totalPages: 20, sectionPages: 5);
      expect(textOf(FieldSubstitution.apply(footer, ctx).first), '5');
    });

    test('section format applies when the field has no explicit switch', () {
      final footer = <DocxBlock>[
        DocxParagraph(children: const [DocxPageNumber()]),
      ];
      const ctx = PageContext(
        pageNumber: 4,
        totalPages: 9,
        sectionFormat: DocxPageNumberFormat.lowerRoman,
      );
      expect(textOf(FieldSubstitution.apply(footer, ctx).first), 'iv');
    });

    test("a field's own switch overrides the section format", () {
      final footer = <DocxBlock>[
        DocxParagraph(children: const [
          DocxPageNumber(format: DocxPageNumberFormat.upperRoman),
        ]),
      ];
      const ctx = PageContext(
        pageNumber: 7,
        totalPages: 9,
        sectionFormat: DocxPageNumberFormat.decimal,
      );
      expect(textOf(FieldSubstitution.apply(footer, ctx).first), 'VII');
    });

    test('substituted number inherits the neighbouring run style', () {
      final footer = <DocxBlock>[
        DocxParagraph(children: const [
          DocxText('Page ', fontSize: 20),
          DocxPageNumber(),
        ]),
      ];
      const ctx = PageContext(pageNumber: 1, totalPages: 1);
      final para = FieldSubstitution.apply(footer, ctx).first as DocxParagraph;
      final numberRun =
          para.children.whereType<DocxText>().last; // the substituted PAGE
      expect(numberRun.content, '1');
      expect(numberRun.fontSize, 20);
    });

    test('PAGEREF resolves from the bookmark map, else falls back to cache',
        () {
      final blocks = <DocxBlock>[
        DocxParagraph(children: const [
          DocxPageRef('ch1', cachedText: '?'),
          DocxText(' / '),
          DocxPageRef('missing', cachedText: '12'),
        ]),
      ];
      const ctx = PageContext(
        pageNumber: 1,
        totalPages: 30,
        bookmarkPages: {'ch1': 8},
      );
      expect(textOf(FieldSubstitution.apply(blocks, ctx).first), '8 / 12');
    });

    test('blocks without fields are returned unchanged (same instance)', () {
      final blocks = <DocxBlock>[
        DocxParagraph(children: const [DocxText('Just text')]),
      ];
      const ctx = PageContext(pageNumber: 1, totalPages: 1);
      expect(identical(FieldSubstitution.apply(blocks, ctx), blocks), isTrue);
    });

    group('STYLEREF (Plan §K.3)', () {
      test('default resolves to the last matching paragraph on the page', () {
        final header = <DocxBlock>[
          DocxParagraph(children: const [DocxStyleRef('Heading 1')]),
        ];
        const ctx = PageContext(
          pageNumber: 2,
          totalPages: 5,
          styleRefLast: {'heading1': 'Genesis'},
          styleRefFirst: {'heading1': 'Exodus'},
        );
        expect(textOf(FieldSubstitution.apply(header, ctx).first), 'Genesis');
      });

      test('\\l switch resolves to the first matching paragraph', () {
        final header = <DocxBlock>[
          DocxParagraph(
              children: const [DocxStyleRef('Heading 1', searchFromTop: true)]),
        ];
        const ctx = PageContext(
          pageNumber: 2,
          totalPages: 5,
          styleRefLast: {'heading1': 'Genesis'},
          styleRefFirst: {'heading1': 'Exodus'},
        );
        expect(textOf(FieldSubstitution.apply(header, ctx).first), 'Exodus');
      });

      test('normalized key matches "Heading 1" against styleId Heading1', () {
        // The field names the style with a space; the page key is the normalized
        // styleId. They must resolve to the same value.
        final header = <DocxBlock>[
          DocxParagraph(children: const [DocxStyleRef('Heading 1')]),
        ];
        final ctx = PageContext(
          pageNumber: 1,
          totalPages: 1,
          styleRefLast: {PageContext.normalizeStyleKey('Heading1'): 'בראשית'},
        );
        expect(textOf(FieldSubstitution.apply(header, ctx).first), 'בראשית');
      });

      test('falls back to cached text when no paragraph matched', () {
        final header = <DocxBlock>[
          DocxParagraph(children: const [
            DocxStyleRef('Heading 1', cachedText: 'cached')
          ]),
        ];
        const ctx = PageContext(pageNumber: 1, totalPages: 1);
        expect(textOf(FieldSubstitution.apply(header, ctx).first), 'cached');
      });
    });
  });
}
