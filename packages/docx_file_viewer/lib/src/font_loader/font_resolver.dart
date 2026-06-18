import 'embedded_font_loader.dart';
import 'font_metrics_registry.dart';

/// The script a character (or run segment) belongs to for font selection
/// (Plan §L.1). Word carries a *separate* font for Latin (`w:rFonts w:ascii`)
/// and complex-script — Hebrew/Arabic — text (`w:rFonts w:cs`), plus separate
/// size (`w:sz`/`w:szCs`) and bold/italic (`w:b`/`w:bCs`, `w:i`/`w:iCs`). A run
/// mixing both scripts must be split so each character is laid out with the
/// right font/size/weight, which is exactly what Word does. We only distinguish
/// the two scripts that matter for this package's bidi target; East-Asian text
/// is folded into [latin] (it uses the `ascii`/`hAnsi` slot here).
enum DocxScript { latin, complex }

/// One maximal run of same-script characters within a string, as a half-open
/// `[start, end)` range into the source string's UTF-16 code units (which is the
/// unit `String.substring` and Flutter's text painter use).
class ScriptRun {
  const ScriptRun(this.start, this.end, this.script);

  final int start;
  final int end;
  final DocxScript script;

  int get length => end - start;
}

const int _neutral = -1;
const int _latin = 0;
const int _complex = 1;

/// Classifies a single UTF-16 code unit into [_complex] (RTL scripts), [_latin]
/// (Latin/Greek/Cyrillic letters + ASCII digits — Word's `ascii`/`hAnsi`
/// classes), or [_neutral] (spaces, punctuation, symbols — resolved by context).
int _classOf(int c) {
  // Complex (RTL) scripts → the `w:cs` font.
  if ((c >= 0x0590 && c <= 0x05FF) || // Hebrew
      (c >= 0xFB1D && c <= 0xFB4F) || // Hebrew presentation forms
      (c >= 0x0600 && c <= 0x06FF) || // Arabic
      (c >= 0x0700 && c <= 0x074F) || // Syriac
      (c >= 0x0750 && c <= 0x077F) || // Arabic Supplement
      (c >= 0x0780 && c <= 0x07BF) || // Thaana
      (c >= 0x07C0 && c <= 0x07FF) || // NKo
      (c >= 0x08A0 && c <= 0x08FF) || // Arabic Extended-A
      (c >= 0xFB50 && c <= 0xFDFF) || // Arabic Presentation Forms-A
      (c >= 0xFE70 && c <= 0xFEFF)) {
    // Arabic Presentation Forms-B
    return _complex;
  }
  // Strong "Latin" (rendered with the ascii/hAnsi font in Word's model): Latin
  // letters, ASCII digits (Word keeps 0-9 in the ascii font), Greek, Cyrillic.
  if ((c >= 0x0041 && c <= 0x005A) || // A-Z
      (c >= 0x0061 && c <= 0x007A) || // a-z
      (c >= 0x0030 && c <= 0x0039) || // 0-9
      (c >= 0x00C0 && c <= 0x024F) || // Latin-1 letters + Latin Extended-A/B
      (c >= 0x0370 && c <= 0x03FF) || // Greek
      (c >= 0x0400 && c <= 0x04FF)) {
    // Cyrillic
    return _latin;
  }
  return _neutral;
}

/// Splits [text] into maximal same-script runs (Plan §L.1). Neutral characters
/// (spaces, punctuation) inherit the script of the *preceding* strong character
/// — so a comma after a Hebrew word stays Hebrew — falling back to the following
/// strong character, then to Latin. When [hintComplex] is set (`w:rFonts
/// w:hint="cs"`) every neutral resolves to complex, matching Word's hint
/// semantics. The returned runs tile [text] exactly (`Σ length == text.length`),
/// so the caller can rebuild the original string by concatenating the slices.
List<ScriptRun> classifyScript(String text, {bool hintComplex = false}) {
  final n = text.length;
  if (n == 0) return const [];

  // Fast path for the overwhelmingly common single-script run: one cheap scan to
  // see whether both scripts actually appear. A run is one segment unless a
  // strong Latin *and* a strong complex char coexist (or, when hinted complex,
  // a strong Latin char forces a split off the complex neutrals). This avoids
  // the array allocation and multi-pass neutral resolution below.
  var hasLatin = false;
  var hasComplex = false;
  for (var i = 0; i < n; i++) {
    final c = _classOf(text.codeUnitAt(i));
    if (c == _latin) {
      hasLatin = true;
    } else if (c == _complex) {
      hasComplex = true;
    }
  }
  final single = hintComplex ? !hasLatin : !(hasLatin && hasComplex);
  if (single) {
    final script =
        (hintComplex || hasComplex) ? DocxScript.complex : DocxScript.latin;
    return [ScriptRun(0, n, script)];
  }

  final cls = List<int>.filled(n, _neutral);
  for (var i = 0; i < n; i++) {
    cls[i] = _classOf(text.codeUnitAt(i));
  }

  // Resolve interior neutrals from the preceding strong class (or to complex
  // when the run is hinted complex).
  var prev = _neutral;
  for (var i = 0; i < n; i++) {
    if (cls[i] == _neutral) {
      if (hintComplex) {
        cls[i] = _complex;
      } else if (prev != _neutral) {
        cls[i] = prev;
      }
    } else {
      prev = cls[i];
    }
  }
  // Leading neutrals (no preceding strong) take the following strong class, else
  // default to Latin. (Skipped when hinted: those are already complex.)
  if (!hintComplex) {
    var next = _neutral;
    for (var i = n - 1; i >= 0; i--) {
      if (cls[i] == _neutral) {
        cls[i] = next != _neutral ? next : _latin;
      } else {
        next = cls[i];
      }
    }
  }

  final runs = <ScriptRun>[];
  var start = 0;
  for (var i = 1; i <= n; i++) {
    if (i == n || cls[i] != cls[start]) {
      runs.add(ScriptRun(
        start,
        i,
        cls[start] == _complex ? DocxScript.complex : DocxScript.latin,
      ));
      start = i;
    }
  }
  return runs;
}

/// Maps a Word font name to a font family Flutter can actually render, and
/// supplies a per-script fallback chain so a stray glyph degrades gracefully
/// instead of dropping to a tofu box (Plan §L.2/§L.3).
///
/// The package deliberately bundles **no** fonts (size); the host app is
/// expected to register the fonts it cares about (its Hebrew fonts, or the
/// metric-compatible clones below). Resolution order:
///   1. an explicit [substitutions] entry the host configured (intent wins);
///   2. the requested family is actually available — an embedded font from the
///      `.docx` ([EmbeddedFontLoader]) or a system font whose metrics we read
///      ([FontMetricsRegistry]) — keep it for maximal fidelity;
///   3. a built-in metric-compatible substitute (Calibri→Carlito, Arial→Arimo,
///      Times New Roman→Tinos, David→David Libre, Narkisim→Frank Ruhl Libre …),
///      which only helps if the host bundled that clone;
///   4. otherwise keep the requested name and rely on [fallbacksFor].
///
/// Pure and cheap to construct (the availability check reads process-wide static
/// registries), so the [SpanFactory] builds one per document from the config.
class FontResolver {
  FontResolver({
    Map<String, String> substitutions = const {},
    List<String> extraFallbacks = const [],
    bool Function(String family)? isAvailable,
  })  : _userSubs = {
          for (final e in substitutions.entries)
            e.key.trim().toLowerCase(): e.value,
        },
        _latinFallbacks = List.unmodifiable(extraFallbacks),
        _complexFallbacks = List.unmodifiable([
          ..._builtinComplexFallbacks,
          ...extraFallbacks,
        ]),
        _isAvailable = isAvailable ?? _defaultIsAvailable;

  final Map<String, String> _userSubs;
  final List<String> _latinFallbacks;
  final List<String> _complexFallbacks;
  final bool Function(String family) _isAvailable;

  /// Resolves a requested Word font name to the best available family, or null
  /// when [requested] is null/blank (the caller then uses its own default).
  String? resolve(String? requested) {
    if (requested == null) return null;
    final name = requested.trim();
    if (name.isEmpty) return null;
    final key = name.toLowerCase();

    final userSub = _userSubs[key];
    if (userSub != null) return userSub;

    if (_isAvailable(name)) return name;

    final builtin = _builtinSubstitutions[key];
    if (builtin != null) return builtin;

    return name;
  }

  /// The fallback chain for [script]. Latin runs use only the host's configured
  /// fallbacks (so single-script Latin layout is byte-identical to pre-Part-L);
  /// complex runs prepend Hebrew/Arabic families so a Hebrew glyph missing in the
  /// primary font never falls to a Latin fallback (which would tofu it).
  List<String> fallbacksFor(DocxScript script) =>
      script == DocxScript.complex ? _complexFallbacks : _latinFallbacks;

  static bool _defaultIsAvailable(String family) =>
      EmbeddedFontLoader.isFontLoaded(family) ||
      FontMetricsRegistry.has(family);

  /// Metric-compatible (same glyph advances → same line breaks) open clones of
  /// the common Microsoft/Hebrew fonts. Keys are lower-cased. These names only
  /// resolve glyphs if the host registered the clone; otherwise the fallback
  /// chain still catches misses.
  static const Map<String, String> _builtinSubstitutions = {
    'calibri': 'Carlito',
    'calibri light': 'Carlito',
    'cambria': 'Caladea',
    'cambria math': 'Caladea',
    'times new roman': 'Tinos',
    'times': 'Tinos',
    'arial': 'Arimo',
    'arial narrow': 'Arimo',
    'helvetica': 'Arimo',
    'courier new': 'Cousine',
    'georgia': 'Gelasio',
    'david': 'David Libre',
    'david clm': 'David Libre',
    'narkisim': 'Frank Ruhl Libre',
    'frank ruehl': 'Frank Ruhl Libre',
    'frankruehl': 'Frank Ruhl Libre',
    'frankruehl clm': 'Frank Ruhl Libre',
  };

  /// Hebrew/Arabic families tried (in order) before the host's Latin fallbacks
  /// for a complex-script run. None are bundled; they resolve only when present
  /// on the system or registered by the host app.
  static const List<String> _builtinComplexFallbacks = [
    'David Libre',
    'Frank Ruhl Libre',
    'Noto Sans Hebrew',
    'Noto Serif Hebrew',
    'Noto Naskh Arabic',
    'Arial',
  ];
}
