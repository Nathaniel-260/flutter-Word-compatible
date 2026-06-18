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
      case 'STYLEREF':
        // STYLEREF "<style>" [\l] [\n \w \r \t \p \* …] — only the style name and
        // the \l (search-from-top) switch affect the displayed running head text.
        final style = _firstArg(tokens);
        if (style == null) return null;
        return DocxStyleRef(
          style,
          searchFromTop: tokens.contains(r'\l'),
          cachedText: cachedText,
        );
      default:
        return null;
    }
  }

  /// The first non-switch argument after the field name (e.g. the style name in
  /// `STYLEREF`, the target in `HYPERLINK`), or null when there is none.
  static String? _firstArg(List<String> tokens) {
    for (var i = 1; i < tokens.length; i++) {
      if (!tokens[i].startsWith(r'\')) return tokens[i];
    }
    return null;
  }

  /// Parses a `HYPERLINK` instruction into its `(url, anchor)` (Plan §K.2/§K.3).
  /// `HYPERLINK "http://…"` → external url; `HYPERLINK \l "name"` → an internal
  /// anchor (a bookmark). Returns null when [instruction] is not a HYPERLINK.
  static ({String? url, String? anchor})? parseHyperlink(String instruction) {
    final tokens = tokenize(instruction);
    if (tokens.isEmpty || tokens.first.toUpperCase() != 'HYPERLINK') {
      return null;
    }
    final li = tokens.indexOf(r'\l');
    final anchor = (li != -1 && li + 1 < tokens.length) ? tokens[li + 1] : null;
    final url = _firstArg(tokens);
    return (url: anchor == null ? url : null, anchor: anchor);
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
