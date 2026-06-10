import 'enums.dart';

/// Pure number-to-string conversions shared by every numbered surface:
/// list markers, page numbers (`PAGE`/`NUMPAGES`/`PAGEREF`), and chapter
/// prefixes. Single source of truth so the same value renders identically
/// wherever it appears.
///
/// Intentionally dependency-free (no Flutter, no AST types) so it can live in
/// `core` and be reused by both the document model and the viewer. Callers map
/// their own format enum onto these static methods.
abstract final class NumberFormatter {
  /// Formats a page number [n] in a [DocxPageNumberFormat] — the single mapping
  /// point shared by page fields (`PAGE`/`NUMPAGES`/`PAGEREF`) and `pgNumType`.
  static String formatPage(int n, DocxPageNumberFormat format) {
    switch (format) {
      case DocxPageNumberFormat.decimal:
        return decimal(n);
      case DocxPageNumberFormat.upperRoman:
        return upperRoman(n);
      case DocxPageNumberFormat.lowerRoman:
        return lowerRoman(n);
      case DocxPageNumberFormat.upperLetter:
        return upperAlpha(n);
      case DocxPageNumberFormat.lowerLetter:
        return lowerAlpha(n);
    }
  }

  /// Plain decimal: 1, 2, 3 …
  static String decimal(int n) => '$n';

  /// Uppercase Roman: I, II, III … Values outside 1..3999 fall back to decimal
  /// (additive Roman has no representation for them).
  static String upperRoman(int n) {
    if (n <= 0 || n > 3999) return '$n';
    const numerals = <(int, String)>[
      (1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'),
      (100, 'C'), (90, 'XC'), (50, 'L'), (40, 'XL'),
      (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I'),
    ];
    final buffer = StringBuffer();
    var remaining = n;
    for (final (value, numeral) in numerals) {
      while (remaining >= value) {
        buffer.write(numeral);
        remaining -= value;
      }
    }
    return buffer.toString();
  }

  /// Lowercase Roman: i, ii, iii …
  static String lowerRoman(int n) => upperRoman(n).toLowerCase();

  /// Uppercase bijective base-26: A, B … Z, AA, AB … (no zero digit).
  static String upperAlpha(int n) => _alpha(n, 0x41); // 'A'

  /// Lowercase bijective base-26: a, b … z, aa, ab …
  static String lowerAlpha(int n) => _alpha(n, 0x61); // 'a'

  static String _alpha(int n, int base) {
    if (n <= 0) return '';
    final codes = <int>[];
    var remaining = n;
    while (remaining > 0) {
      final rem = (remaining - 1) % 26;
      codes.add(base + rem);
      remaining = (remaining - 1) ~/ 26;
    }
    return String.fromCharCodes(codes.reversed);
  }

  /// Hebrew gematria: א, ב … י, יא … ק, קא … (Word's "hebrew1").
  ///
  /// Uses the conventional טו/טז spellings for 15/16 to avoid forming part of
  /// the divine name. Covers 1..999; values outside that fall back to decimal
  /// (additive gematria has no clean separator-free form for thousands).
  static String hebrew(int n) {
    if (n <= 0 || n >= 1000) return '$n';
    const units = <(int, String)>[
      (400, 'ת'), (300, 'ש'), (200, 'ר'), (100, 'ק'),
      (90, 'צ'), (80, 'פ'), (70, 'ע'), (60, 'ס'), (50, 'נ'),
      (40, 'מ'), (30, 'ל'), (20, 'כ'), (10, 'י'),
      (9, 'ט'), (8, 'ח'), (7, 'ז'), (6, 'ו'), (5, 'ה'),
      (4, 'ד'), (3, 'ג'), (2, 'ב'), (1, 'א'),
    ];
    final buffer = StringBuffer();
    var remaining = n;
    for (final (value, letter) in units) {
      while (remaining >= value) {
        buffer.write(letter);
        remaining -= value;
      }
    }
    return buffer
        .toString()
        .replaceAll('יה', 'טו') // 15 → טו (not יה)
        .replaceAll('יו', 'טז'); // 16 → טז (not יו)
  }
}
