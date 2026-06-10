import '../../../../docx_creator.dart';

/// Parses a Word field instruction (the text accumulated from `w:instrText` /
/// `w:fldSimple@w:instr`) into the matching page-related inline node.
///
/// Returns null for field codes the viewer does not model (TOC, REF, DATE, …);
/// the caller wraps those in [DocxUnknownField] so their cached result is kept.
///
/// Pure and dependency-light so it is unit-testable without a reader context.
abstract final class FieldInstruction {
  static DocxInline? parse(String instruction, {String? cachedText}) {
    final tokens = tokenize(instruction);
    if (tokens.isEmpty) return null;

    final name = tokens.first.toUpperCase();
    final format = _format(tokens);

    switch (name) {
      case 'PAGE':
        return DocxPageNumber(format: format, cachedText: cachedText);
      case 'NUMPAGES':
        return DocxPageCount(format: format, cachedText: cachedText);
      case 'SECTIONPAGES':
        return DocxPageCount(
            sectionScope: true, format: format, cachedText: cachedText);
      case 'PAGEREF':
        // PAGEREF <bookmark> [\h] [\* FORMAT]
        if (tokens.length < 2 || tokens[1].startsWith(r'\')) return null;
        return DocxPageRef(
          tokens[1],
          hyperlink: tokens.contains(r'\h'),
          format: format,
          cachedText: cachedText,
        );
      default:
        return null;
    }
  }

  /// The page-number format from a `\* SWITCH` pair, or null to inherit.
  /// Word distinguishes case: `\* ROMAN` (upper) vs `\* roman` (lower).
  static DocxPageNumberFormat? _format(List<String> tokens) {
    final i = tokens.indexOf(r'\*');
    if (i == -1 || i + 1 >= tokens.length) return null;
    final sw = tokens[i + 1];
    switch (sw.toLowerCase()) {
      case 'roman':
        return sw == 'ROMAN'
            ? DocxPageNumberFormat.upperRoman
            : DocxPageNumberFormat.lowerRoman;
      case 'alphabetic':
        return sw == 'ALPHABETIC'
            ? DocxPageNumberFormat.upperLetter
            : DocxPageNumberFormat.lowerLetter;
      case 'arabic':
        return DocxPageNumberFormat.decimal;
      default:
        return null; // MERGEFORMAT / CHARFORMAT / etc. → inherit section format
    }
  }

  /// Splits an instruction into tokens on whitespace, keeping double-quoted
  /// runs (e.g. bookmark names with spaces) intact.
  static List<String> tokenize(String s) {
    final tokens = <String>[];
    final buf = StringBuffer();
    var inQuote = false;
    for (final rune in s.runes) {
      final c = String.fromCharCode(rune);
      if (c == '"') {
        inQuote = !inQuote;
      } else if (!inQuote && (c == ' ' || c == '\t')) {
        if (buf.isNotEmpty) {
          tokens.add(buf.toString());
          buf.clear();
        }
      } else {
        buf.write(c);
      }
    }
    if (buf.isNotEmpty) tokens.add(buf.toString());
    return tokens;
  }
}
