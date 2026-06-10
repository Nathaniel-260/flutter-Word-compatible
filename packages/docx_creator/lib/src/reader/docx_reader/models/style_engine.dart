import '../../../../docx_creator.dart';

/// Resolves the *effective* style of a run/paragraph following Word's exact
/// inheritance chain (ISO/IEC 29500 §17.7), once, with caching.
///
/// This is the engine described in Part B of the Word-fidelity plan. Unlike the
/// older [StyleResolver] (which folds everything with simple last-wins logic and
/// does not apply `docDefaults`), this engine implements:
///
/// 1. **docDefaults** (`pPrDefault`/`rPrDefault`) as the lowest layer.
/// 2. The full **application order** (B.1): docDefaults → named-style chain
///    (`basedOn` flattened root→leaf) → character-style chain → direct props.
/// 3. **Toggle properties** (B.2, ISO 17.7.3): `b, i, caps, smallCaps, dstrike,
///    outline, shadow, emboss, imprint` combine by **XOR parity** across the
///    *named style* layers (turning a toggle on while already on turns it off),
///    while an explicit *off* (`w:val="0"`) hard-resets to off. `docDefaults` is
///    a fallback base (not an XOR participant) and a *direct* value overrides
///    outright.
/// 4. `basedOn` chains flattened **once per styleId** and cached, with a depth
///    cap and cycle guard so a malformed `basedOn` loop can never hang.
///
/// The engine produces a fully-merged [DocxStyle] (the same shape the reader
/// already bakes into AST nodes), so it slots into the existing parse-time
/// resolution without changing the public AST/API. See the delivery log entry
/// for 2026-06-10 (Part B) for the architectural rationale.
///
/// **INTERNAL / not yet wired.** This class is *not* exported from the package
/// and does not yet drive the parse pipeline — the reader still resolves styles
/// via `ReaderContext.resolveStyle` + last-wins merge. Do not treat it as public
/// API until it is wired in and the open semantic question below is settled.
///
/// **Open question — XOR across a `basedOn` chain (unverified).** This engine
/// applies the toggle XOR (B.2) across *every* named-style layer, including each
/// link of a `basedOn` chain (so `A(b)→B(b)→C(b)` resolves to bold by parity).
/// That follows the literal ISO 17.7.3 reading, but Word's actual behaviour for
/// a deep same-direction `basedOn` chain is **not yet verified**; Word may treat
/// `basedOn` as ordinary nearest-wins inheritance and reserve XOR for the
/// interaction *between* levels (paragraph-style vs character-style vs direct).
/// Before this engine is wired into production, lock the behaviour with a golden
/// generated from a real Word document. The plan makes Word the ground truth
/// (§7.2); the spec is only the backup.
class DocxStyleResolver {
  /// styleId -> parsed style definition (each carries *only its own* props).
  final Map<String, DocxStyle> styles;

  /// Document default paragraph properties (`w:pPrDefault`).
  final DocxStyle? docDefaultsParagraph;

  /// Document default run properties (`w:rPrDefault`).
  final DocxStyle? docDefaultsRun;

  /// Maximum `basedOn` chain depth before giving up (loop/runaway guard).
  final int maxDepth;

  /// Cache of flattened `basedOn` chains (root→leaf order), per styleId.
  final Map<String, List<DocxStyle>> _chainCache = {};

  /// Cache of fully-merged *style-only* run styles, keyed by
  /// `"<pStyleId>|<rStyleId>"`. Direct run props are applied on top per call
  /// (cheap) so the expensive chain+XOR work happens once per style combo.
  final Map<String, DocxStyle> _runStyleCache = {};

  /// Cache of fully-merged *style-only* paragraph styles, keyed by pStyleId.
  final Map<String, DocxStyle> _paragraphStyleCache = {};

  DocxStyleResolver({
    required this.styles,
    this.docDefaultsParagraph,
    this.docDefaultsRun,
    this.maxDepth = 12,
  });

  /// Builds a resolver from a parsed [DocxTheme] (styles + docDefaults).
  factory DocxStyleResolver.fromTheme(DocxTheme theme, {int maxDepth = 12}) {
    return DocxStyleResolver(
      styles: theme.styles,
      docDefaultsParagraph: theme.defaultParagraphStyle,
      docDefaultsRun: theme.defaultRunStyle,
      maxDepth: maxDepth,
    );
  }

  /// The `basedOn` chain for [styleId], flattened to a list of each style's own
  /// properties in **root→leaf** order. Cycle- and depth-safe; cached.
  List<DocxStyle> chainLayers(String? styleId) {
    if (styleId == null) return const [];
    final cached = _chainCache[styleId];
    if (cached != null) return cached;

    // We walk leaf→root and stop at [maxDepth]. NOTE: hitting the cap drops the
    // *root* (oldest) layers — which usually carry the base font/size — rather
    // than the leaf. At the default depth of 12 this is effectively unreachable
    // in real documents; a deeper chain almost certainly indicates a malformed
    // file. Truncation is silent by design (no logger dependency here).
    final leafToRoot = <DocxStyle>[];
    final visited = <String>{};
    String? current = styleId;
    var depth = 0;
    while (current != null && depth < maxDepth && !visited.contains(current)) {
      visited.add(current);
      final style = styles[current];
      if (style == null) break;
      leafToRoot.add(style);
      final parent = style.basedOn;
      current = (parent != null && parent != current) ? parent : null;
      depth++;
    }

    final layers = leafToRoot.reversed.toList(growable: false);
    _chainCache[styleId] = layers;
    return layers;
  }

  /// Resolves the effective **run** style for a run carrying [direct] rPr,
  /// inside a paragraph using [paragraphStyleId], optionally with character
  /// style [runStyleId]. Returns a merged [DocxStyle].
  DocxStyle resolveRun({
    String? paragraphStyleId,
    String? runStyleId,
    DocxStyle? direct,
  }) {
    final key = '${paragraphStyleId ?? ''}|${runStyleId ?? ''}';
    final styleMerged = _runStyleCache.putIfAbsent(key, () {
      final named = <DocxStyle>[
        ...chainLayers(paragraphStyleId),
        ...chainLayers(runStyleId),
      ];
      return _mergeStyleLayers(docDefaultsRun, named);
    });
    if (direct == null) return styleMerged;
    // Direct rPr overrides outright (including toggles, which are non-null when
    // explicitly set on the run).
    return styleMerged.merge(direct);
  }

  /// Resolves the effective **paragraph** style for a paragraph using
  /// [paragraphStyleId] and carrying [direct] pPr props.
  DocxStyle resolveParagraph({
    String? paragraphStyleId,
    DocxStyle? direct,
  }) {
    final styleMerged = _paragraphStyleCache.putIfAbsent(
      paragraphStyleId ?? '',
      () => _mergeStyleLayers(
          docDefaultsParagraph, chainLayers(paragraphStyleId)),
    );
    if (direct == null) return styleMerged;
    return styleMerged.merge(direct);
  }

  /// Clears all caches (call when styles/theme change — e.g. styleEpoch bump).
  void clearCache() {
    _chainCache.clear();
    _runStyleCache.clear();
    _paragraphStyleCache.clear();
  }

  // ---------------------------------------------------------------------------
  // Internal merge with toggle XOR.
  // ---------------------------------------------------------------------------

  /// Merges [docDefaults] (normal base) with the ordered [namedLayers] (named
  /// style chains). Non-toggle props are last-wins; the nine toggle props are
  /// XOR-combined across [namedLayers] only, falling back to [docDefaults] when
  /// no named layer sets them.
  DocxStyle _mergeStyleLayers(DocxStyle? docDefaults, List<DocxStyle> namedLayers) {
    var acc = docDefaults ?? DocxStyle.empty();
    for (final layer in namedLayers) {
      acc = acc.merge(layer);
    }
    // Override the toggles with the XOR result computed over named layers only.
    // Where a toggle is untouched by every named layer the override field is
    // null, so `merge` keeps `acc`'s value (i.e. the docDefaults fallback).
    return acc.merge(_toggleOverride(namedLayers));
  }

  /// A sparse [DocxStyle] carrying only the toggle properties, set to their
  /// XOR-resolved values across [layers] (null where no layer touched them).
  DocxStyle _toggleOverride(List<DocxStyle> layers) {
    return DocxStyle(
      id: DocxStyle.overlayId,
      fontWeight: _xorWeight(layers),
      fontStyle: _xorStyle(layers),
      isAllCaps: _resolveToggle(layers, (s) => s.isAllCaps),
      isSmallCaps: _resolveToggle(layers, (s) => s.isSmallCaps),
      isDoubleStrike: _resolveToggle(layers, (s) => s.isDoubleStrike),
      isOutline: _resolveToggle(layers, (s) => s.isOutline),
      isShadow: _resolveToggle(layers, (s) => s.isShadow),
      isEmboss: _resolveToggle(layers, (s) => s.isEmboss),
      isImprint: _resolveToggle(layers, (s) => s.isImprint),
    );
  }

  /// Resolves a toggle property across [layers] (root→leaf). An *on* value
  /// flips the running value (XOR parity, per ISO 17.7.3 — turning bold on while
  /// it is already on turns it off); an explicit *off* (`w:val="0"`) is a hard
  /// reset to off rather than an XOR-as-false no-op, so a child style or direct
  /// run can switch an inherited toggle back off. Returns null when no layer in
  /// [layers] specifies the toggle (so [docDefaults] can show through).
  static bool? _resolveToggle(
      List<DocxStyle> layers, bool? Function(DocxStyle) get) {
    bool? effective;
    for (final layer in layers) {
      final value = get(layer);
      if (value == null) continue;
      effective = value ? !(effective ?? false) : false;
    }
    return effective;
  }

  /// Resolves `w:b` (a toggle) across [layers]; null if untouched.
  static DocxFontWeight? _xorWeight(List<DocxStyle> layers) {
    final on = _resolveToggle(layers,
        (s) => s.fontWeight == null ? null : s.fontWeight == DocxFontWeight.bold);
    if (on == null) return null;
    return on ? DocxFontWeight.bold : DocxFontWeight.normal;
  }

  /// Resolves `w:i` (a toggle) across [layers]; null if untouched.
  static DocxFontStyle? _xorStyle(List<DocxStyle> layers) {
    final on = _resolveToggle(layers,
        (s) => s.fontStyle == null ? null : s.fontStyle == DocxFontStyle.italic);
    if (on == null) return null;
    return on ? DocxFontStyle.italic : DocxFontStyle.normal;
  }
}

/// Resolves OOXML theme colors with `tint`/`shade` per ISO 29500 §17.3.2.6,
/// using Word's exact arithmetic (B.3):
///
/// * **tint** mixes toward white: `c' = c*tint + 255*(1 - tint)`.
/// * **shade** mixes toward black: `c' = c*shade`.
///
/// `tint`/`shade` arrive as hex bytes (`"00".."FF"`) where `FF` == 1.0.
///
/// Known fidelity limitations:
/// * tint and shade are mutually exclusive in well-formed OOXML; if both are
///   supplied here they are applied in sequence (tint then shade) rather than
///   rejected, so malformed input degrades quietly instead of throwing.
/// * Word defines tint/shade on luminance in an HSL space; the per-channel RGB
///   arithmetic below is the widely-used close approximation, not exact.
class ThemeColorResolver {
  /// Resolves [themeColorName] against [colors], applying [tintHex]/[shadeHex].
  /// Returns a 6-digit upper-case hex string, or null if the name is unknown.
  static String? resolve(
    DocxThemeColors colors,
    String themeColorName, {
    String? tintHex,
    String? shadeHex,
  }) {
    final base = colors.getColor(themeColorName);
    if (base == null) return null;
    return applyTintShade(base, tintHex: tintHex, shadeHex: shadeHex);
  }

  /// Applies [tintHex]/[shadeHex] to a 6-digit [hex] color (no `#`).
  static String applyTintShade(String hex, {String? tintHex, String? shadeHex}) {
    final normalized = hex.replaceFirst('#', '');
    if (normalized.length != 6) return hex;
    var r = int.parse(normalized.substring(0, 2), radix: 16);
    var g = int.parse(normalized.substring(2, 4), radix: 16);
    var b = int.parse(normalized.substring(4, 6), radix: 16);

    final tint = _byteFactor(tintHex);
    if (tint != null) {
      r = (r * tint + 255 * (1 - tint)).round();
      g = (g * tint + 255 * (1 - tint)).round();
      b = (b * tint + 255 * (1 - tint)).round();
    }
    final shade = _byteFactor(shadeHex);
    if (shade != null) {
      r = (r * shade).round();
      g = (g * shade).round();
      b = (b * shade).round();
    }

    String hh(int v) => v.clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '${hh(r)}${hh(g)}${hh(b)}'.toUpperCase();
  }

  /// Parses a hex byte ("FF") to a 0..1 factor, or null if absent/invalid.
  static double? _byteFactor(String? hexByte) {
    if (hexByte == null) return null;
    final value = int.tryParse(hexByte, radix: 16);
    if (value == null) return null;
    return value / 255.0;
  }
}
