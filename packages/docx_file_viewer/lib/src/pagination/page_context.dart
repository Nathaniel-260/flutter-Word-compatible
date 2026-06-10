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

  const PageContext({
    required this.pageNumber,
    required this.totalPages,
    int? sectionPages,
    this.sectionFormat = DocxPageNumberFormat.decimal,
    this.bookmarkPages = const {},
  }) : sectionPages = sectionPages ?? totalPages;
}
