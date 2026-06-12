import 'package:docx_creator/docx_creator.dart';

import 'block_slice.dart';

/// A single laid-out page: a thin list of [BlockSlice]s plus the metadata the
/// renderer needs to draw its chrome (Plan §D.1 / §4.2).
///
/// [PageModel] holds no widgets and no duplicated text — only references and
/// numbers — so the cost of an N-page document is O(blocks), not O(rendered
/// widgets).
class PageModel {
  const PageModel({
    required this.pageNumber,
    required this.absoluteIndex,
    required this.sectionIndex,
    required this.section,
    required this.slices,
    required this.usedHeight,
    this.isFirstPageOfSection = false,
    this.isEvenPage = false,
    this.isBlank = false,
  });

  /// 1-based display number for this page, after the section's
  /// `w:pgNumType w:start` offset/restart (what `PAGE` renders).
  final int pageNumber;

  /// 0-based absolute position of the page in the document.
  final int absoluteIndex;

  /// 0-based index of the section this page belongs to.
  final int sectionIndex;

  /// The section definition governing this page's geometry and chrome.
  final DocxSectionDef section;

  /// The block slices placed on this page, in document order.
  final List<BlockSlice> slices;

  /// Sum of slice heights actually used (≤ body height).
  final double usedHeight;

  /// True for the first page of its section (selects the title-page chrome).
  final bool isFirstPageOfSection;

  /// True when this page's number is even (selects the even-page chrome when
  /// `w:evenAndOddHeaders` is on).
  final bool isEvenPage;

  /// True for a forced-empty page inserted to satisfy an `evenPage`/`oddPage`
  /// section break (Plan §D.2.4). It still consumes a page number.
  final bool isBlank;
}

/// Output of [Paginator.paginate]: the page list plus the lookup maps that
/// downstream rendering needs (Plan §D.2.8).
class PaginationResult {
  const PaginationResult({
    required this.pages,
    required this.bookmarkPages,
    required this.footnotePages,
    required this.endnotePages,
    this.truncated = false,
  });

  /// All pages, in order (including blank even/odd filler pages).
  final List<PageModel> pages;

  /// True when pagination stopped at the page cap (`Paginator.maxPages`) before
  /// consuming the whole document — a pathological/hostile input. The host can
  /// surface a "document truncated" notice.
  final bool truncated;

  /// `bookmark name → display page number` for resolving `PAGEREF`.
  final Map<String, int> bookmarkPages;

  /// `footnoteId → absolute page index` of the page that references it
  /// (consumed by Part J to place the note at the page foot). Footnote and
  /// endnote ids are independent sequences, so they live in separate maps.
  final Map<int, int> footnotePages;

  /// `endnoteId → absolute page index` of the page that references it.
  final Map<int, int> endnotePages;

  /// Total page count (`NUMPAGES`).
  int get pageCount => pages.length;

  static const PaginationResult empty = PaginationResult(
    pages: [],
    bookmarkPages: {},
    footnotePages: {},
    endnotePages: {},
  );
}
