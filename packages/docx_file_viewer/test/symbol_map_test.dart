import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/layout/symbol_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// Part K.5 — `w:sym` glyphs mapped to equivalent Unicode so they render
/// without the original symbol font.
void main() {
  group('SymbolFontMap', () {
    test('Wingdings checkbox/smiley glyphs map to Unicode equivalents', () {
      // The slot is the font code point (F000 offset already removed).
      expect(SymbolFontMap.map('Wingdings', 0xFC), '✓');
      expect(SymbolFontMap.map('Wingdings', 0xFB), '✗');
      expect(SymbolFontMap.map('Wingdings', 0xFE), '☑');
      expect(SymbolFontMap.map('Wingdings', 0x4A), '☺');
    });

    test('font name matches case-insensitively', () {
      expect(SymbolFontMap.map('WINGDINGS', 0xFC), '✓');
    });

    test('Symbol font maps Greek letters', () {
      expect(SymbolFontMap.map('Symbol', 0x61), 'α'); // a → alpha
      expect(SymbolFontMap.map('Symbol', 0x70), 'π'); // p → pi
      expect(SymbolFontMap.map('Symbol', 0x57), 'Ω'); // W → Omega
    });

    test('Symbol font maps common math operators', () {
      expect(SymbolFontMap.map('Symbol', 0xA3), '≤');
      expect(SymbolFontMap.map('Symbol', 0xB1), '±');
      expect(SymbolFontMap.map('Symbol', 0xAE), '→');
    });

    test('unmapped glyph / unknown font returns null (caller keeps raw glyph)',
        () {
      expect(SymbolFontMap.map('Wingdings', 0x01), isNull);
      expect(SymbolFontMap.map('SomeUnknownFont', 0x41), isNull);
      expect(SymbolFontMap.map(null, 0x41), isNull);
    });

    test('DocxSymbol.glyphIndex strips the F000 private-use offset', () {
      const sym = DocxSymbol(charCode: 0xF04A, font: 'Wingdings');
      expect(sym.glyphIndex, 0x4A);
      expect(SymbolFontMap.map(sym.font, sym.glyphIndex), '☺');
    });
  });
}
