import 'package:xml/xml.dart';

/// Reads an OOXML `CT_OnOff` toggle (e.g. `w:titlePg`, `w:evenAndOddHeaders`,
/// `w:b`).
///
/// Per the spec a present element is *on* unless its `w:val` is one of
/// `0`/`false`/`off`. Word omits the element to turn a toggle off, but other
/// producers (LibreOffice, python-docx, docx4j) write `w:val="false"`
/// explicitly — so presence alone is not enough. A `null` element returns
/// [orElse].
bool readOnOff(XmlElement? element, {bool orElse = false}) {
  if (element == null) return orElse;
  final v = element.getAttribute('w:val')?.toLowerCase();
  return v != '0' && v != 'false' && v != 'off';
}

/// The flat background colour a `w:shd` element resolves to, as the four
/// attributes the viewer already renders (a hex/`null` [fill] plus an optional
/// theme reference). Returned by [resolveShdFill].
typedef ShdFill = ({
  String? fill,
  String? themeFill,
  String? themeFillTint,
  String? themeFillShade,
});

/// Coverage (0..1) of a non-`clear`/`solid` `w:shd` pattern, or `null` when the
/// token carries no implied coverage. `pctN` maps to N%; the stripe/grid
/// patterns are approximated at half coverage (the viewer paints one flat
/// colour, so the exact hatch geometry is out of scope — Plan §8.2).
double? _shdCoverage(String val) {
  if (val.startsWith('pct')) {
    final n = int.tryParse(val.substring(3));
    if (n != null) return (n / 100.0).clamp(0.0, 1.0);
  }
  const patterned = {
    'horzstripe', 'vertstripe', 'diagstripe', 'reversediagstripe',
    'horzcross', 'diagcross', 'thinhorzstripe', 'thinvertstripe',
    'thindiagstripe', 'thinreversediagstripe', 'thinhorzcross', 'thindiagcross',
  };
  return patterned.contains(val) ? 0.5 : null;
}

/// Normalises [v] to an uppercase 6-digit hex string, or `null` if it is not a
/// plain hex colour (e.g. `auto`, a theme name, or absent).
String? _plainHex(String? v) {
  if (v == null) return null;
  final h = v.toUpperCase().replaceAll('#', '');
  return RegExp(r'^[0-9A-F]{6}$').hasMatch(h) ? h : null;
}

/// Blends two 6-digit hex colours: [a] at `1-t`, [b] at `t`. The mix is plain
/// linear RGB (not gamma-corrected) — a minor, deliberate deviation that matches
/// Word's own flat approximation of a hatch pattern closely enough.
String _blendHex(String a, String b, double t) {
  int ch(String s, int i) => int.parse(s.substring(i, i + 2), radix: 16);
  int mix(int x, int y) => (x * (1 - t) + y * t).round().clamp(0, 255);
  String hx(int n) => n.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '${hx(mix(ch(a, 0), ch(b, 0)))}'
      '${hx(mix(ch(a, 2), ch(b, 2)))}'
      '${hx(mix(ch(a, 4), ch(b, 4)))}';
}

/// Collapses a three-part `w:shd` (ISO/IEC 29500 §17.3.5) to the single flat
/// colour Word effectively paints, as a [ShdFill].
///
/// `w:val` is the pattern (ST_Shd), `w:fill` the background, `w:color` the
/// pattern foreground. Word renders:
///   - `nil`/`none`        → no shading;
///   - `clear` (or absent) → the fill alone (+ its theme);
///   - `solid`             → the **pattern colour** (it fully covers the fill) —
///     previously dropped, so a `solid` cell showed no background at all;
///   - `pctN`/stripe/grid  → the colour mixed over the fill at the pattern's
///     coverage when both are plain hex; a theme-driven pattern keeps the fill
///     (the flat-colour model can't carry two theme refs — documented in §8.2).
///
/// Returning the existing four-attribute shape means callers (and the viewer's
/// `resolveColor`) need no new fields, and there is no geometry change — only
/// the resolved colour differs, so measure ≡ render is untouched.
ShdFill resolveShdFill(XmlElement shd) {
  final val = (shd.getAttribute('w:val') ?? 'clear').toLowerCase();

  String? fill = shd.getAttribute('w:fill');
  if (fill == 'auto') fill = null;
  final themeFill = shd.getAttribute('w:themeFill');
  final themeFillTint = shd.getAttribute('w:themeFillTint');
  final themeFillShade = shd.getAttribute('w:themeFillShade');

  if (val == 'nil' || val == 'none') {
    return (
      fill: null,
      themeFill: null,
      themeFillTint: null,
      themeFillShade: null
    );
  }

  final fillTuple = (
    fill: fill,
    themeFill: themeFill,
    themeFillTint: themeFillTint,
    themeFillShade: themeFillShade,
  );
  if (val == 'clear') return fillTuple;

  // Pattern foreground (`w:color` + its own theme reference).
  String? patternColor = shd.getAttribute('w:color');
  if (patternColor == 'auto') patternColor = null;
  final patternThemeColor = shd.getAttribute('w:themeColor');
  final patternThemeTint = shd.getAttribute('w:themeTint');
  final patternThemeShade = shd.getAttribute('w:themeShade');

  if (val == 'solid') {
    if (patternColor == null && patternThemeColor == null) return fillTuple;
    return (
      fill: patternColor,
      themeFill: patternThemeColor,
      themeFillTint: patternThemeTint,
      themeFillShade: patternThemeShade,
    );
  }

  // pctN / stripe / grid: blend when both endpoints are plain hex.
  final coverage = _shdCoverage(val);
  final plainColor = _plainHex(patternColor);
  // A missing fill blends against the page background (white).
  final plainFill = _plainHex(fill) ?? (themeFill == null ? 'FFFFFF' : null);
  if (coverage != null &&
      plainColor != null &&
      plainFill != null &&
      patternThemeColor == null) {
    return (
      fill: _blendHex(plainFill, plainColor, coverage),
      themeFill: null,
      themeFillTint: null,
      themeFillShade: null,
    );
  }
  return fillTuple;
}

/// Namespace URIs whose content the reader can render, used to decide whether
/// an `mc:Choice` is satisfiable. The key entry is the WordprocessingShape
/// namespace (`wps`): with prefix-agnostic shape parsing the reader now honours
/// the modern DrawingML `mc:Choice` over the VML `mc:Fallback`.
const Set<String> _understoodMcNamespaceUris = {
  'http://schemas.openxmlformats.org/wordprocessingml/2006/main', // w
  'http://schemas.openxmlformats.org/officeDocument/2006/relationships', // r
  'http://schemas.openxmlformats.org/drawingml/2006/main', // a
  'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing', // wp
  'http://schemas.openxmlformats.org/drawingml/2006/picture', // pic
  'http://schemas.microsoft.com/office/word/2010/wordprocessingShape', // wps
  'http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing', // wp14
  'http://schemas.openxmlformats.org/officeDocument/2006/math', // m
};

/// Well-known prefixes the reader understands, used as a fallback when a
/// `Requires` prefix cannot be resolved to a declared namespace URI (e.g. a
/// hand-written XML fragment in a test). Standard producers use these fixed
/// prefixes, so prefix matching is reliable in practice.
const Set<String> _understoodMcPrefixes = {
  'w', 'r', 'a', 'wp', 'pic', 'wps', 'wp14', 'm',
};

/// Resolves an `xmlns:`[prefix] declaration by walking [scope] and its
/// ancestors. Returns null when the prefix is not declared in scope.
String? _lookupNamespaceUri(XmlElement scope, String prefix) {
  XmlElement? e = scope;
  while (e != null) {
    final decl = e.getAttribute('xmlns:$prefix');
    if (decl != null) return decl;
    final parent = e.parent;
    e = parent is XmlElement ? parent : null;
  }
  return null;
}

/// Selects the content container of an `mc:AlternateContent` element per the
/// Markup Compatibility rules (ISO/IEC 29500-3 §10): the first `mc:Choice`
/// whose `Requires` namespaces are *all* understood by this reader, otherwise
/// `mc:Fallback`. As a last resort (no qualifying Choice and no Fallback) the
/// first Choice is returned so content is never silently lost.
///
/// Word almost always writes `<mc:Choice Requires="wps">` (modern DrawingML)
/// plus `<mc:Fallback>` (legacy VML). Previously the reader picked the Choice
/// blindly; now it verifies the requirement, and — crucially — actually
/// understands `wps`, so the higher-fidelity Choice wins. Choice/Fallback are
/// matched by local name so a non-`mc` prefix still resolves.
XmlElement? selectAlternateContent(XmlElement alternateContent) {
  final choices = alternateContent.childElements
      .where((e) => e.name.local == 'Choice')
      .toList();
  final fallback = alternateContent.childElements
      .where((e) => e.name.local == 'Fallback')
      .firstOrNull;

  for (final choice in choices) {
    final requires = choice.getAttribute('Requires');
    if (requires == null || requires.trim().isEmpty) return choice;
    final prefixes = requires.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final understood = prefixes.every((prefix) {
      final uri = _lookupNamespaceUri(choice, prefix);
      if (uri != null) return _understoodMcNamespaceUris.contains(uri);
      return _understoodMcPrefixes.contains(prefix);
    });
    if (understood) return choice;
  }

  return fallback ?? choices.firstOrNull;
}

/// Stores unknown XML attributes and child elements for round-trip preservation.
///
/// This "Shadow Model" ensures that when reading a DOCX file, any XML
/// attributes or elements that aren't formally modeled are preserved and
/// written back exactly as they were found.
///
/// Example usage:
/// ```dart
/// // When parsing an anchor element, extract unknown attributes
/// final extensions = XmlExtensionMap.extractFromElement(
///   anchorElement,
///   knownAttributes: {'distT', 'distB', 'simplePos'},
/// );
///
/// // Later, when writing back
/// extensions.writeAttributesTo(builder);
/// ```
class XmlExtensionMap {
  /// Unknown attributes: qualified name -> value
  final Map<String, String> attributes;

  /// Unknown child elements as raw XML strings
  final List<String> childElements;

  const XmlExtensionMap({
    this.attributes = const {},
    this.childElements = const [],
  });

  /// Returns true if there's no extension data to preserve.
  bool get isEmpty => attributes.isEmpty && childElements.isEmpty;

  /// Returns true if there is extension data to preserve.
  bool get isNotEmpty => !isEmpty;

  /// Extract unknown attributes from an element, given a set of known attribute names.
  ///
  /// [element] - The XML element to extract from
  /// [knownAttributes] - Set of attribute names (qualified) that are formally modeled
  ///
  /// Returns an [XmlExtensionMap] containing only the unknown attributes.
  static XmlExtensionMap extractFromElement(
    XmlElement element, {
    required Set<String> knownAttributes,
  }) {
    final unknownAttrs = <String, String>{};

    for (var attr in element.attributes) {
      final qualifiedName = attr.name.qualified;
      if (!knownAttributes.contains(qualifiedName)) {
        unknownAttrs[qualifiedName] = attr.value;
      }
    }

    return XmlExtensionMap(attributes: unknownAttrs);
  }

  /// Extract unknown child elements from an element, given a set of known element names.
  ///
  /// [element] - The XML element to extract from
  /// [knownChildren] - Set of element names (local names) that are formally modeled
  ///
  /// Returns an [XmlExtensionMap] containing only the unknown child elements.
  static XmlExtensionMap extractFromChildren(
    XmlElement element, {
    required Set<String> knownChildren,
  }) {
    final unknownChildren = <String>[];

    for (var child in element.children) {
      if (child is XmlElement) {
        if (!knownChildren.contains(child.name.local)) {
          unknownChildren.add(child.toXmlString());
        }
      }
    }

    return XmlExtensionMap(childElements: unknownChildren);
  }

  /// Extract both unknown attributes and children.
  static XmlExtensionMap extractFull(
    XmlElement element, {
    required Set<String> knownAttributes,
    required Set<String> knownChildren,
  }) {
    final attrs = extractFromElement(element, knownAttributes: knownAttributes);
    final children = extractFromChildren(element, knownChildren: knownChildren);

    return XmlExtensionMap(
      attributes: attrs.attributes,
      childElements: children.childElements,
    );
  }

  /// Writes the unknown attributes to an [XmlBuilder].
  void writeAttributesTo(XmlBuilder builder) {
    for (var entry in attributes.entries) {
      builder.attribute(entry.key, entry.value);
    }
  }

  /// Writes the unknown child elements to an [XmlBuilder].
  ///
  /// Note: This inserts raw XML strings, which requires the builder
  /// to support raw content insertion.
  void writeChildrenTo(XmlBuilder builder) {
    for (var childXml in childElements) {
      try {
        final fragment = XmlDocumentFragment.parse(childXml);
        for (var node in fragment.children) {
          builder.xml(node.toXmlString());
        }
      } catch (_) {
        // If parsing fails, skip this element
      }
    }
  }

  /// Merges this extension map with another, preferring values from [other].
  XmlExtensionMap merge(XmlExtensionMap other) {
    return XmlExtensionMap(
      attributes: {...attributes, ...other.attributes},
      childElements: [...childElements, ...other.childElements],
    );
  }

  @override
  String toString() {
    return 'XmlExtensionMap(attributes: $attributes, childElements: ${childElements.length} items)';
  }
}
