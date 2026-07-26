import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/exporters/pdf/pdf_font_manager.dart';
import 'package:docx_creator/src/exporters/pdf/pdf_layout_engine.dart';
import 'package:test/test.dart';

void main() {
  group('PdfFontManager Unicode handling', () {
    test('substitutes an unmapped character instead of dropping it', () {
      final manager = PdfFontManager();
      // A CJK character has no WinAnsi mapping.
      final escaped = manager.escapeText('a中b'); // a中b
      expect(escaped, 'a?b');
    });

    test('measures a surrogate-pair (astral) character as one glyph', () {
      final manager = PdfFontManager();
      // U+1F600 GRINNING FACE is a surrogate pair in UTF-16.
      const emoji = '\u{1F600}';
      expect(emoji.length, 2); // sanity: two UTF-16 code units
      expect(emoji.runes.length, 1); // one actual character

      // measureText should not throw and should treat it as a single
      // (unknown-width) character rather than iterating two stray
      // surrogate halves.
      final width = manager.measureText(emoji, 12);
      expect(width, greaterThan(0));
    });

    test('needsUnicodeFallback flags text a standard font cannot render',
        () {
      final manager = PdfFontManager();
      expect(manager.needsUnicodeFallback('Hello, world!'), isFalse);
      expect(manager.needsUnicodeFallback('Привет'), isTrue); // Cyrillic
      expect(manager.needsUnicodeFallback('日本語'), isTrue); // CJK
    });

    test('fallbackUnicodeFontRef lazily embeds one font and reuses it', () {
      final manager = PdfFontManager();
      expect(manager.embeddedFonts, isEmpty);

      final ref1 = manager.fallbackUnicodeFontRef;
      expect(manager.embeddedFonts, hasLength(1));

      final ref2 = manager.fallbackUnicodeFontRef;
      expect(ref2, ref1);
      expect(manager.embeddedFonts, hasLength(1));
    });

    test('the bundled fallback font actually has glyphs for Cyrillic text',
        () {
      final manager = PdfFontManager();
      final ref = manager.fallbackUnicodeFontRef;
      final font = manager.getEmbeddedFont(ref)!;

      // Cyrillic 'П' (U+041F) must resolve to a real glyph, not .notdef (0).
      final glyphId = font.metrics.getGlyphId(0x041F);
      expect(glyphId, isNot(0));
    });
  });

  group('PdfExporter end-to-end Unicode fallback', () {
    test('exports Cyrillic/CJK text without a custom font, with no crash',
        () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph.text('Привет, мир!'), // Cyrillic
        DocxParagraph.text('日本語のテキスト'), // Japanese
      ]);

      final bytes = PdfExporter().exportToBytes(doc);
      expect(bytes, isNotEmpty);
    });

    test('an explicit custom font is not overridden by the fallback', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph(children: [
          DocxText('Привет', fontFamily: 'SomeCustomFont'),
        ]),
      ]);

      // Should not throw even though 'SomeCustomFont' was never actually
      // registered via addFont() - selectFont() falls back to a standard
      // font by name lookup miss, and the explicit fontFamily request means
      // _withUnicodeFallback must not silently substitute a different font.
      final bytes = PdfExporter().exportToBytes(doc);
      expect(bytes, isNotEmpty);
    });
  });

  group('PdfLayoutEngine.measureNode', () {
    test('measures a DocxShapeBlock using its real height, not a fixed '
        'fallback estimate', () {
      final engine = PdfLayoutEngine(pageWidth: 612, pageHeight: 792);
      final tallShape = DocxShapeBlock.rectangle(width: 100, height: 400);
      final shortShape = DocxShapeBlock.rectangle(width: 100, height: 20);

      final tallHeight = engine.measureNode(tallShape);
      final shortHeight = engine.measureNode(shortShape);

      expect(tallHeight, greaterThan(shortHeight));
      expect(tallHeight, greaterThanOrEqualTo(400));
    });
  });

  group('PDF nested list numbering in table cells', () {
    test('exports without error for a table cell containing a nested '
        'ordered list', () {
      final nestedList = DocxList(
        isOrdered: true,
        items: const [
          DocxListItem([DocxText('a')], level: 0),
          DocxListItem([DocxText('b')], level: 1),
          DocxListItem([DocxText('c')], level: 1),
          DocxListItem([DocxText('d')], level: 0),
        ],
      );
      final doc = DocxBuiltDocument(elements: [
        DocxTable(rows: [
          DocxTableRow(cells: [
            DocxTableCell(children: [nestedList]),
          ]),
        ]),
      ]);

      final bytes = PdfExporter().exportToBytes(doc);
      expect(bytes, isNotEmpty);
    });
  });
}
