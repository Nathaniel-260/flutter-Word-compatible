import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('NumberFormatter', () {
    test('decimal', () {
      expect(NumberFormatter.decimal(1), '1');
      expect(NumberFormatter.decimal(42), '42');
    });

    test('roman (upper/lower) and out-of-range fallback', () {
      expect(NumberFormatter.upperRoman(1), 'I');
      expect(NumberFormatter.upperRoman(4), 'IV');
      expect(NumberFormatter.upperRoman(2024), 'MMXXIV');
      expect(NumberFormatter.lowerRoman(9), 'ix');
      // Outside 1..3999 falls back to decimal.
      expect(NumberFormatter.upperRoman(0), '0');
      expect(NumberFormatter.upperRoman(4000), '4000');
    });

    test('alpha is bijective base-26 past z', () {
      expect(NumberFormatter.lowerAlpha(1), 'a');
      expect(NumberFormatter.lowerAlpha(26), 'z');
      expect(NumberFormatter.lowerAlpha(27), 'aa');
      expect(NumberFormatter.lowerAlpha(28), 'ab');
      expect(NumberFormatter.lowerAlpha(52), 'az');
      expect(NumberFormatter.lowerAlpha(53), 'ba');
      expect(NumberFormatter.upperAlpha(27), 'AA');
    });

    test('hebrew gematria with טו/טז special cases', () {
      expect(NumberFormatter.hebrew(1), 'א');
      expect(NumberFormatter.hebrew(10), 'י');
      expect(NumberFormatter.hebrew(11), 'יא');
      expect(NumberFormatter.hebrew(15), 'טו'); // not יה
      expect(NumberFormatter.hebrew(16), 'טז'); // not יו
      expect(NumberFormatter.hebrew(121), 'קכא');
      // Outside 1..999 falls back to decimal.
      expect(NumberFormatter.hebrew(1000), '1000');
    });

    test('hebrewAlpha is bijective base-22 over the alphabet (hebrew2)', () {
      expect(NumberFormatter.hebrewAlpha(1), 'א');
      expect(NumberFormatter.hebrewAlpha(22), 'ת');
      expect(NumberFormatter.hebrewAlpha(23), 'אא');
      expect(NumberFormatter.hebrewAlpha(44), 'את');
      expect(NumberFormatter.hebrewAlpha(45), 'בא');
      expect(NumberFormatter.hebrewAlpha(0), '0'); // non-positive → decimal
    });

    test('formatPage routes the Hebrew page-number formats (§E.2)', () {
      // hebrew1 = gematria value; hebrew2 = alphabet ordinal.
      expect(
          NumberFormatter.formatPage(15, DocxPageNumberFormat.hebrew1), 'טו');
      expect(NumberFormatter.formatPage(3, DocxPageNumberFormat.hebrew2), 'ג');
      expect(NumberFormatter.formatPage(7, DocxPageNumberFormat.decimal), '7');
    });
  });
}
