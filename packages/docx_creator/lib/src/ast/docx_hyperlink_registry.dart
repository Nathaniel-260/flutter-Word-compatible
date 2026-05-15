/// Package-internal registry that maps hyperlink URLs to OOXML relationship
/// IDs during a DOCX export pass. The exporter populates it before calling
/// buildXml and clears it afterward, so DocxText can look up its rId without
/// needing mutable state on the node itself.
class DocxHyperlinkRegistry {
  static Map<String, String>? _relIds;

  static void begin(Map<String, String> relIds) =>
      _relIds = Map.unmodifiable(relIds);

  static void end() => _relIds = null;

  static String? lookup(String href) => _relIds?[href];
}
