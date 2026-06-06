/// Utility class for converting DOCX units to Flutter logical pixels.
///
/// DOCX uses several internal unit systems:
/// - **Twips**: Twentieth of a point (1/1440 inch)
/// - **Half-points**: Used for font sizes (sz attribute)
/// - **EMU**: English Metric Units for images (914400 EMU = 1 inch)
class DocxUnits {
  DocxUnits._();

  /// Converts twips to logical pixels at **96 DPI** (consistent with EMU).
  ///
  /// Twips are 1/20th of a point. At 96 DPI: 1 twip = 1.333/20 px = 1/15 px.
  /// (הגרסה הקודמת השתמשה ב-twips/20 = 72 DPI, מה שהקטין את גודל העמוד והשוליים
  /// ביחס לתמונות שכבר חושבו ב-96 DPI — אי-עקביות שגרמה לחיתוך תוכן.)
  static double twipsToPixels(int twips) => twips / 15.0;

  /// Converts twips to pixels (nullable version, 96 DPI).
  static double? twipsToPixelsOrNull(int? twips) =>
      twips != null ? twips / 15.0 : null;

  /// Converts half-points to logical pixels at **96 DPI**.
  ///
  /// Font sizes in DOCX are specified in half-points (sz attribute).
  /// For example, sz="24" = 12pt = 16px at 96 DPI (12 * 96/72).
  static double halfPointsToPixels(int halfPoints) =>
      halfPoints / 2.0 * 96.0 / 72.0;

  /// Converts half-points to pixels (nullable version, 96 DPI).
  static double? halfPointsToPixelsOrNull(int? halfPoints) =>
      halfPoints != null ? halfPoints / 2.0 * 96.0 / 72.0 : null;

  /// Converts EMU (English Metric Units) to logical pixels.
  ///
  /// EMU is used for image dimensions in DrawingML.
  /// 914400 EMU = 1 inch, and at 96 DPI: 1 inch = 96 pixels.
  /// So: 1 pixel = 914400 / 96 = 9525 EMU
  static double emuToPixels(int emu) => emu / 9525.0;

  /// Converts EMU to pixels (nullable version).
  static double? emuToPixelsOrNull(int? emu) =>
      emu != null ? emu / 9525.0 : null;

  /// Converts points to logical pixels.
  ///
  /// At 96 DPI: 1 point = 96/72 pixels ≈ 1.333 pixels.
  static double pointsToPixels(double points) => points * 1.333;

  /// Converts eighths of a point to pixels (used for border widths).
  ///
  /// Border widths use sz attribute in eighths of a point.
  /// For example, sz="4" means 0.5pt border.
  static double eighthsPointToPixels(int eighths) => (eighths / 8.0) * 1.333;

  /// Converts percentage width (used in tables) to fraction.
  ///
  /// DOCX table widths with type="pct" use 50ths of a percent.
  /// For example, w="5000" means 100% (5000/50 = 100).
  static double pctToFraction(int pct) => pct / 5000.0;
}
