/// Maps symbol-font glyph slots (`w:sym`) to equivalent Unicode characters so a
/// `DocxSymbol` renders meaningfully even when the original symbol font
/// (Wingdings / Symbol / …) is not installed (Plan §K.5).
///
/// Word stores symbol glyphs in the F000–F0FF private-use area; the caller passes
/// the slot with that offset already removed (`DocxSymbol.glyphIndex`), i.e. the
/// font's own code point (typically 0x20–0xFF). When a glyph has no mapping the
/// caller falls back to the raw character in a fallback font — so unmapped
/// glyphs are never lost, they just keep the font's own code point.
///
/// The tables are intentionally limited to the *common, verifiable* glyphs
/// (check/cross marks, smileys, arrows, and the full Adobe **Symbol** Greek +
/// math set used in scientific text across languages) rather than a guessed
/// exhaustive mapping.
abstract final class SymbolFontMap {
  /// The Unicode equivalent of [glyph] in [font], or null when there is no known
  /// mapping (the caller then renders the raw glyph). [font] is matched
  /// case-insensitively by family stem, so "Wingdings", "WINGDINGS" and a
  /// localized variant all resolve.
  static String? map(String? font, int glyph) {
    if (font == null) return null;
    final f = font.toLowerCase();
    if (f.contains('wingdings') || f.contains('webdings')) {
      return _wingdings[glyph];
    }
    if (f.contains('symbol')) {
      return _symbol[glyph];
    }
    return null;
  }

  /// Common Wingdings/Webdings glyphs (the checkbox family, smileys). Keyed by
  /// the font's own code point.
  static const Map<int, String> _wingdings = {
    0x4A: '☺', // ☺ smiling face
    0x4B: '\u{1F610}', // 😐 neutral face
    0x4C: '☹', // ☹ frowning face
    0x6C: '●', // ● black circle
    0x6D: '❍', // ❍ shadowed circle
    0x6E: '■', // ■ black square
    0x71: '❑', // ❑ shadowed square
    0x75: '◆', // ◆ black diamond
    0xA8: '♦', // ♦ diamond suit
    0xD8: '➢', // ➢ arrowhead
    0xE0: '←', // ← left arrow
    0xE1: '→', // → right arrow
    0xE2: '↑', // ↑ up arrow
    0xE3: '↓', // ↓ down arrow
    0xFB: '✗', // ✗ ballot X
    0xFC: '✓', // ✓ check mark
    0xFD: '☒', // ☒ ballot box with X
    0xFE: '☑', // ☑ ballot box with check
  };

  /// Adobe **Symbol** encoding: the full Greek alphabet plus the common math
  /// operators/relations, keyed by the font's own code point. Reliable across
  /// languages (scientific/mathematical text).
  static const Map<int, String> _symbol = {
    // Uppercase Greek.
    0x41: 'Α', 0x42: 'Β', 0x47: 'Γ', 0x44: 'Δ',
    0x45: 'Ε', 0x5A: 'Ζ', 0x48: 'Η', 0x51: 'Θ',
    0x49: 'Ι', 0x4B: 'Κ', 0x4C: 'Λ', 0x4D: 'Μ',
    0x4E: 'Ν', 0x58: 'Ξ', 0x4F: 'Ο', 0x50: 'Π',
    0x52: 'Ρ', 0x53: 'Σ', 0x54: 'Τ', 0x55: 'Υ',
    0x46: 'Φ', 0x43: 'Χ', 0x59: 'Ψ', 0x57: 'Ω',
    // Lowercase Greek.
    0x61: 'α', 0x62: 'β', 0x67: 'γ', 0x64: 'δ',
    0x65: 'ε', 0x7A: 'ζ', 0x68: 'η', 0x71: 'θ',
    0x69: 'ι', 0x6B: 'κ', 0x6C: 'λ', 0x6D: 'μ',
    0x6E: 'ν', 0x78: 'ξ', 0x6F: 'ο', 0x70: 'π',
    0x72: 'ρ', 0x56: 'ς', 0x73: 'σ', 0x74: 'τ',
    0x75: 'υ', 0x66: 'φ', 0x63: 'χ', 0x79: 'ψ',
    0x77: 'ω',
    // Common math operators and relations.
    0xA3: '≤', // ≤
    0xB3: '≥', // ≥
    0xB9: '≠', // ≠
    0xBB: '↔', // ↔
    0xAC: '←', // ←
    0xAD: '↑', // ↑
    0xAE: '→', // →
    0xAF: '↓', // ↓
    0xB1: '±', // ±
    0xB4: '×', // ×
    0xB8: '÷', // ÷
    0xB7: '•', // •
    0xA5: '∞', // ∞
    0xD6: '√', // √
    0xB6: '∂', // ∂
    0xF2: '∫', // ∫
  };
}
