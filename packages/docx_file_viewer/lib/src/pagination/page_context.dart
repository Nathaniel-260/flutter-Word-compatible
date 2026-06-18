import 'package:docx_creator/docx_creator.dart';

/// Per-page values needed to resolve automatic fields when rendering a page's
/// header and footer.
///
/// Built by the widget generator once page boundaries are known, then handed to
/// [FieldSubstitution] to turn `PAGE`/`NUMPAGES`/`SECTIONPAGES`/`PAGEREF` nodes
/// into concrete text.
class PageContext {
  /// 1-based display number of this page (already offset by the section's
  /// `w:pgNumType w:start`).
  final int pageNumber;

  /// Total pages in the document (`NUMPAGES`).
  final int totalPages;

  /// Pages in the current section (`SECTIONPAGES`); equals [totalPages] for a
  /// single-section document.
  final int sectionPages;

  /// Default number format for this section (`w:pgNumType w:fmt`), used when a
  /// field carries no explicit `\*` switch.
  final DocxPageNumberFormat sectionFormat;

  /// Resolved bookmark → page-number map for `PAGEREF`; empty until pagination
  /// records bookmark positions.
  final Map<String, int> bookmarkPages;

  /// `STYLEREF` values for this page, keyed by [normalizeStyleKey] of the style
  /// name: the text of the *last* paragraph of that style up to the end of this
  /// page (the default running-head value). Empty until pagination computes it.
  final Map<String, String> styleRefLast;

  /// Like [styleRefLast] but the *first* matching paragraph on the page — the
  /// value `STYLEREF \l` resolves to (Plan §K.3).
  final Map<String, String> styleRefFirst;

  const PageContext({
    required this.pageNumber,
    required this.totalPages,
    int? sectionPages,
    this.sectionFormat = DocxPageNumberFormat.decimal,
    this.bookmarkPages = const {},
    this.styleRefLast = const {},
    this.styleRefFirst = const {},
  }) : sectionPages = sectionPages ?? totalPages;

  /// Normalizes a style name/id for STYLEREF matching: lower-cased with all
  /// non-alphanumerics removed, so the field's `"Heading 1"` matches a
  /// paragraph's `Heading1` styleId regardless of spacing/case. Kept
  /// Unicode-aware (only ASCII separators stripped) so non-Latin style names
  /// match too.
  static String normalizeStyleKey(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
}
