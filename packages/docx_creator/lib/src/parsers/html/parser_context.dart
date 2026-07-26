import 'package:html/dom.dart' as dom;

/// Collapses runs of HTML whitespace (space, tab, newline, carriage
/// return, form feed) into a single space, matching how a browser
/// collapses whitespace in normal (non-`<pre>`) text content.
///
/// This intentionally does not trim the result — a single leading or
/// trailing space is often significant (e.g. the space between
/// `<b>bold</b> text`), so trimming is left to call sites that know
/// whether they're at a boundary where it's safe to drop.
String collapseHtmlWhitespace(String text) {
  return text.replaceAll(RegExp(r'[ \t\r\n\f]+'), ' ');
}

/// Shared context for all HTML parser modules.
///
/// Holds the CSS class map and provides access to parsed styles.
class HtmlParserContext {
  /// CSS class map (className -> styleBody)
  final Map<String, String> cssMap;

  /// The parsed HTML document
  final dom.Document document;

  HtmlParserContext({
    required this.document,
    Map<String, String>? cssMap,
  }) : cssMap = cssMap ?? {};

  /// Create context from an HTML document, automatically parsing CSS classes.
  factory HtmlParserContext.fromDocument(dom.Document document) {
    final cssMap = _parseCssClasses(document);
    return HtmlParserContext(document: document, cssMap: cssMap);
  }

  /// Parse CSS classes from <style> tags in the document.
  ///
  /// Handles grouped selectors (`.foo, .bar { ... }`) by mapping every
  /// class named in the group to the shared declaration body, not just
  /// the first one.
  static Map<String, String> _parseCssClasses(dom.Document document) {
    final cssMap = <String, String>{};
    final styles = document.querySelectorAll('style');
    for (var style in styles) {
      final text = style.text;
      // Match "<selector-list> { <body> }" rules, then split the selector
      // list on commas so every class in a group gets the same body.
      final rules = RegExp(r'([^{}]+)\{([^}]+)\}').allMatches(text);
      for (var rule in rules) {
        final selectorList = rule.group(1);
        final styleBody = rule.group(2)?.trim();
        if (selectorList == null || styleBody == null) continue;

        for (var selector in selectorList.split(',')) {
          final classMatch =
              RegExp(r'^\.([a-zA-Z0-9_-]+)$').firstMatch(selector.trim());
          final className = classMatch?.group(1);
          if (className != null) {
            cssMap[className] = styleBody;
          }
        }
      }
    }
    return cssMap;
  }

  /// Merge inline styles with CSS class styles.
  /// Inline styles take precedence over class styles.
  String mergeStyles(String? inlineStyle, Iterable<String> classes) {
    var combined = inlineStyle ?? '';
    if (classes.isNotEmpty) {
      for (var cls in classes) {
        if (cssMap.containsKey(cls)) {
          combined = '$combined;${cssMap[cls]}';
        }
      }
    }
    return combined;
  }
}
