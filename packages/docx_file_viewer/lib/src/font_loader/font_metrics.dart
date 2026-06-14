import 'dart:typed_data';

/// Per-font line metrics parsed straight from the font program (`head` + `OS/2`
/// tables), so the viewer lays single-spaced text out at the **font's own** line
/// height — exactly what Word does — instead of a fixed multiplier that can only
/// ever be right for one font.
///
/// Word lays single-spaced text out using the font's **typographic** metrics —
/// `sTypoAscender − sTypoDescender + sTypoLineGap` — for the line-to-line
/// distance, regardless of the `OS/2.fsSelection` USE_TYPO_METRICS bit (an
/// empirically-confirmed Word behaviour: e.g. Arial leaves the bit clear yet
/// Word still spaces lines by the typo metrics). Dividing by `unitsPerEm` yields
/// the [lineHeightRatio] to feed Flutter's [TextStyle.height]. For Arial this is
/// ≈1.088 (vs the Windows-metrics 1.117 and Flutter's default ~1.15); the
/// Windows metrics are used only as a fallback when the typo fields are absent.
/// Using the real per-font value is what makes page breaks line up with Word
/// across different fonts (David ≈1.00, Times ≈1.06, Calibri ≈1.22).
class FontMetrics {
  const FontMetrics({
    required this.lineHeightRatio,
    required this.unitsPerEm,
    required this.typoAscender,
    required this.typoDescender,
    required this.typoLineGap,
    required this.winAscent,
    required this.winDescent,
    required this.useTypoMetrics,
  });

  /// Line-to-line distance ÷ em — the multiplier for [TextStyle.height] that
  /// reproduces the font's single line spacing.
  final double lineHeightRatio;

  final int unitsPerEm;
  final int typoAscender;
  final int typoDescender;
  final int typoLineGap;
  final int winAscent;
  final int winDescent;
  final bool useTypoMetrics;

  /// USE_TYPO_METRICS is `fsSelection` bit 7.
  static const int _useTypoMetricsBit = 1 << 7;

  /// Parses [bytes] (a TTF/OTF — or the first face of a TTC) and returns its
  /// line metrics, or null when the data is not a font we can read. Defensive
  /// against malformed/truncated input (the viewer opens untrusted files).
  static FontMetrics? tryParse(Uint8List bytes) {
    try {
      final bd = ByteData.sublistView(bytes);
      if (bd.lengthInBytes < 12) return null;

      // TrueType Collection: jump to the first font's offset table.
      var base = 0;
      final tag0 = bd.getUint32(0);
      const ttcf = 0x74746366; // 'ttcf'
      if (tag0 == ttcf) {
        if (bd.lengthInBytes < 16) return null;
        base = bd.getUint32(12); // offset of face 0
      }

      if (base + 6 > bd.lengthInBytes) return null;
      final numTables = bd.getUint16(base + 4);

      int? headOff;
      int? os2Off;
      var rec = base + 12;
      for (var i = 0; i < numTables; i++) {
        if (rec + 16 > bd.lengthInBytes) return null;
        final tag = bd.getUint32(rec);
        final off = bd.getUint32(rec + 8);
        if (tag == 0x68656164) headOff = off; // 'head'
        if (tag == 0x4f532f32) os2Off = off; // 'OS/2'
        rec += 16;
      }

      if (headOff == null || headOff + 20 > bd.lengthInBytes) return null;
      final unitsPerEm = bd.getUint16(headOff + 18);
      if (unitsPerEm == 0) return null;

      // No OS/2 table (rare for Word-targeted fonts) → cannot derive Word's
      // line height; let the caller fall back.
      if (os2Off == null || os2Off + 78 > bd.lengthInBytes) return null;
      final fsSelection = bd.getUint16(os2Off + 62);
      final typoAsc = bd.getInt16(os2Off + 68);
      final typoDesc = bd.getInt16(os2Off + 70);
      final typoGap = bd.getInt16(os2Off + 72);
      final winAsc = bd.getUint16(os2Off + 74);
      final winDesc = bd.getUint16(os2Off + 76);

      final useTypo = (fsSelection & _useTypoMetricsBit) != 0;
      // Word spaces lines by the typographic metrics even when the bit is clear;
      // fall back to the Windows metrics only if the typo fields are unusable.
      final typoUnits = typoAsc - typoDesc + typoGap;
      final winUnits = winAsc + winDesc;
      final heightUnits = typoUnits > 0 ? typoUnits : winUnits;
      if (heightUnits <= 0) return null;

      return FontMetrics(
        lineHeightRatio: heightUnits / unitsPerEm,
        unitsPerEm: unitsPerEm,
        typoAscender: typoAsc,
        typoDescender: typoDesc,
        typoLineGap: typoGap,
        winAscent: winAsc,
        winDescent: winDesc,
        useTypoMetrics: useTypo,
      );
    } catch (_) {
      return null; // malformed font — caller falls back
    }
  }

  /// The typographic line-height ratio regardless of the USE_TYPO_METRICS bit
  /// (`sTypoAscender − sTypoDescender + sTypoLineGap` ÷ em). Exposed for
  /// diagnostics/calibration against a reference renderer.
  double get typoRatio =>
      (typoAscender - typoDescender + typoLineGap) / unitsPerEm;

  /// The Windows line-height ratio (`usWinAscent + usWinDescent` ÷ em).
  double get winRatio => (winAscent + winDescent) / unitsPerEm;
}
