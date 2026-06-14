import 'package:flutter/foundation.dart';

import 'font_metrics.dart';

/// Process-wide map of `font family → single-line-height ratio`, parsed from the
/// real font program (see [FontMetrics]). The [SpanFactory] consults it so
/// single-spaced text is laid out at each font's own line height — what Word
/// does — instead of one fixed multiplier (which can only be right for one
/// font). Pure and byte-based (no `dart:io`), so it is safe on every platform
/// including web; the host supplies font bytes (embedded fonts from the `.docx`,
/// and system fonts on desktop) via [register].
///
/// Static, mirroring [EmbeddedFontLoader]: a family's metrics are stable for the
/// process, and Flutter's font registration is global anyway. Family lookup is
/// case-insensitive.
class FontMetricsRegistry {
  FontMetricsRegistry._();

  static final Map<String, double> _ratios = {};

  /// Families we already tried and failed to parse — so a bad/duplicate font is
  /// not re-parsed on every lookup.
  static final Set<String> _failed = {};

  static String _key(String family) => family.trim().toLowerCase();

  /// Parses [bytes] and records the family's line-height ratio. No-op when the
  /// family is already known or the bytes are not a readable font. Safe to call
  /// repeatedly (e.g. once per document load).
  static void register(String family, Uint8List bytes) {
    final key = _key(family);
    if (key.isEmpty || _ratios.containsKey(key) || _failed.contains(key)) {
      return;
    }
    final m = FontMetrics.tryParse(bytes);
    if (m == null) {
      _failed.add(key);
      return;
    }
    _ratios[key] = m.lineHeightRatio;
  }

  /// Records a pre-computed ratio directly (used by tests / callers that already
  /// parsed the font).
  static void registerRatio(String family, double ratio) {
    final key = _key(family);
    if (key.isNotEmpty) _ratios[key] = ratio;
  }

  /// The single-line-height ratio for [family], or null when it was never
  /// registered (the caller then falls back to the theme/default height).
  static double? lineHeightFor(String? family) {
    if (family == null) return null;
    return _ratios[_key(family)];
  }

  /// True once [family]'s metrics are available.
  static bool has(String? family) =>
      family != null && _ratios.containsKey(_key(family));

  /// Clears all recorded metrics (test hook).
  @visibleForTesting
  static void clear() {
    _ratios.clear();
    _failed.clear();
  }
}
