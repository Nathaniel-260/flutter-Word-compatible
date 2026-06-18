import 'package:docx_creator/docx_creator.dart';

import '../layout/float_layout.dart';
import 'block_slice.dart';

/// The resolved pixel geometry of one page (Plan §D.2.1 / §E.1.3).
///
/// This is the **single source of truth** for a page's layout, computed once by
/// the [Paginator] and reused verbatim by the renderer — so the area the
/// paginator packs content into is exactly the area the renderer draws it in.
/// Splitting this computation across the two used to let the body run *under*
/// the footer: the paginator reserved `max(margin, dist + chromeHeight)` for the
/// header/footer, while the renderer only inset by the raw margin, so a footer
/// taller than its margin overpainted the body's last line.
///
/// Vertical model (mirrors Word): the header sits at [headerDist] from the top
/// edge and the footer at [footerDist] from the bottom edge, each inside the
/// margin band. The body region is inset by [bodyTop]/[bodyBottom], which are
/// the larger of the raw margin and the chrome's outer edge — so a tall
/// header/footer pushes the body inward instead of overlapping it. Page borders
/// (`offsetFrom="text"`) are positioned from the raw margins [padTop]/[padBottom].
class PageGeometry {
  const PageGeometry({
    required this.pageWidth,
    required this.pageHeight,
    required this.padLeft,
    required this.padRight,
    required this.padTop,
    required this.padBottom,
    required this.bodyTop,
    required this.bodyBottom,
    required this.headerDist,
    required this.footerDist,
  });

  /// Full page size in pixels (`w:pgSz`, or the config override).
  final double pageWidth;
  final double pageHeight;

  /// Horizontal body/header/footer insets (`w:left` + gutter, and `w:right`).
  final double padLeft;
  final double padRight;

  /// Raw vertical margins (`w:top`/`w:bottom`). Used to position page borders
  /// (`offsetFrom="text"`), not the body — the body uses [bodyTop]/[bodyBottom].
  final double padTop;
  final double padBottom;

  /// Body region vertical insets: `max(rawMargin, chromeDist + chromeHeight)`,
  /// so the body never overlaps the header/footer.
  final double bodyTop;
  final double bodyBottom;

  /// Distance of the header/footer from the top/bottom page edge (`w:header`/
  /// `w:footer`).
  final double headerDist;
  final double footerDist;

  /// Content width available to body blocks (clamped to a sane minimum).
  double get contentWidth =>
      (pageWidth - padLeft - padRight).clamp(16.0, pageWidth);

  /// Body height available for content packing (clamped to a sane minimum).
  double get bodyHeight =>
      (pageHeight - bodyTop - bodyBottom).clamp(40.0, pageHeight);

  static const PageGeometry zero = PageGeometry(
    pageWidth: 0,
    pageHeight: 0,
    padLeft: 0,
    padRight: 0,
    padTop: 0,
    padBottom: 0,
    bodyTop: 0,
    bodyBottom: 0,
    headerDist: 0,
    footerDist: 0,
  );
}

/// A footnote resolved onto the foot of a page (Plan §J): its computed display
/// [label] (already formatted per the section's footnote numbering), the note's
/// content blocks, and the measured [height] of that content at the page content
/// width. The renderer draws these below a separator inside the band the
/// paginator reserved at the bottom of the body region — so the page-packing
/// height (which subtracts the band) exactly matches the painted layout.
class PlacedFootnote {
  const PlacedFootnote({
    required this.id,
    required this.label,
    required this.content,
    required this.height,
  });

  /// The footnote id (links the body reference to its note).
  final int id;

  /// The display number/mark as Word would render it (e.g. `1`, `iv`, `ב`).
  final String label;

  /// The note's content blocks (paragraphs etc.), shared by reference.
  final List<DocxBlock> content;

  /// Measured height of [content] at the page content width, in pixels.
  final double height;
}

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
    this.geometry = PageGeometry.zero,
    this.isFirstPageOfSection = false,
    this.isEvenPage = false,
    this.isBlank = false,
    this.floats = const [],
    this.footnotes = const [],
    this.footnotesHeight = 0,
  });

  /// The resolved pixel geometry of this page (size, margins, body region,
  /// header/footer positions). Computed by the paginator and reused verbatim by
  /// the renderer so packed area ≡ painted area.
  final PageGeometry geometry;

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

  /// Floating drawings anchored to blocks on this page, resolved to body
  /// coordinates (Plan §H.2). The renderer paints them as `Positioned` layers
  /// over/under the body in z-order; they hold no widgets, only a reference to
  /// the AST drawing plus its rectangle.
  final List<PlacedFloat> floats;

  /// Footnotes whose references land on this page, in document order (Plan §J).
  /// Drawn at the foot of the body region below a separator, in the reserved
  /// [footnotesHeight] band.
  final List<PlacedFootnote> footnotes;

  /// Total height in pixels the paginator reserved at the bottom of the body
  /// region for [footnotes] (separator + note contents + inter-note gaps). Zero
  /// when the page has no footnotes. The renderer insets the body by this band
  /// and paints the notes within it, so packed area ≡ painted area.
  final double footnotesHeight;
}

/// Output of [Paginator.paginate]: the page list plus the lookup maps that
/// downstream rendering needs (Plan §D.2.8).
class PaginationResult {
  const PaginationResult({
    required this.pages,
    required this.bookmarkPages,
    required this.footnotePages,
    required this.endnotePages,
    this.footnoteLabels = const {},
    this.endnoteLabels = const {},
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

  /// `footnoteId → display label` (e.g. `1`, `iv`, `ב`) computed during
  /// pagination from the section's footnote numbering (format + restart, Plan
  /// §J.4). The body reference mark and the note at the page foot both render
  /// this, so a `hebrew1`/`eachPage` document shows the same mark Word does.
  final Map<int, String> footnoteLabels;

  /// `endnoteId → display label`, computed like [footnoteLabels].
  final Map<int, String> endnoteLabels;

  /// Total page count (`NUMPAGES`).
  int get pageCount => pages.length;

  static const PaginationResult empty = PaginationResult(
    pages: [],
    bookmarkPages: {},
    footnotePages: {},
    endnotePages: {},
    footnoteLabels: {},
    endnoteLabels: {},
  );
}
