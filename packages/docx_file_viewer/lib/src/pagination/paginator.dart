import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/widgets.dart';

import '../docx_view_config.dart';
import '../layout/float_layout.dart';
import '../layout/list_layout.dart';
import '../layout/table_layout.dart';
import '../layout/table_min_widths.dart';
import '../layout/text_measurer.dart';
import '../utils/docx_units.dart';
import '../utils/text_direction_detector.dart';
import 'block_slice.dart';
import 'page_model.dart';

/// Splits a document into measured pages (Plan §D — the pagination engine).
///
/// This replaces the old heuristic (`~8px per character`) with real
/// [TextMeasurer]-based layout: each block is measured at the section's content
/// width and packed into pages of the section's real body height. Paragraphs and
/// tables that straddle a page boundary are sliced by reference (never cloned,
/// §2.4 rule 1) into [BlockSlice]s.
///
/// The engine is **pure and synchronous** so it can be unit-tested without a
/// widget tree; the UI wraps it for time-sliced background pagination (§4.4).
/// `TextPainter` work runs on the UI thread, as it must (§2.4 rule 3).
class Paginator {
  Paginator({
    required this.measurer,
    required this.config,
    this.maxPages = 50000,
  });

  final TextMeasurer measurer;
  final DocxViewConfig config;

  /// Anti-runaway backstop: an upper bound on the number of pages a single
  /// document may produce. A pathological/hostile `.docx` (tiny page height,
  /// enormous body) could otherwise paginate without end — unbounded memory and
  /// CPU for a viewer that opens untrusted files. On reaching the cap the fill
  /// loop and split recursion stop and the result is flagged
  /// [PaginationResult.truncated]. The default is far above any real document.
  final int maxPages;

  // --- Output accumulators (reset per paginate call) -----------------------
  final List<PageModel> _pages = [];
  final Map<String, int> _bookmarkPages = {};
  final Map<int, int> _footnotePages = {};
  final Map<int, int> _endnotePages = {};

  // Per-table content-width floors (longest-word px per grid column), memoised by
  // table identity so a table measured and then split is not recomputed. The
  // renderer derives the same vector independently (deterministic) → measure ≡
  // render for autofit table widths (QA F3).
  final Map<DocxTable, List<double>> _minColWidths = {};

  // Streaming sink: invoked as each page is closed so the UI can display pages
  // as they are born (Plan §D.2.9 / §4.4). Null for the synchronous path.
  void Function(PageModel page)? _onPage;

  // Cooperative-cancel predicate (async path): polled after each time-slice; a
  // false return abandons a superseded pagination instead of running it to the
  // end on the UI thread (e.g. the host switched documents).
  bool Function()? _shouldContinue;
  bool _cancelled = false;

  // Set once [maxPages] is reached; flags the result and stops further work.
  bool _truncated = false;

  // True once the fill loop / split recursion must unwind (cancel or cap).
  bool get _stop => _cancelled || _truncated;

  // --- Numbering / position state ------------------------------------------
  int _displayNumber = 1;
  int _absoluteIndex = 0;

  // --- Section iteration state ---------------------------------------------
  int _pendingSectionIndex = 0;
  bool _pendingFirstOfSection = true;
  DocxSectionDef _activeSection = const DocxSectionDef();

  // --- Open-page state (computed when a page is opened) ---------------------
  bool _hasOpenPage = false;
  bool _openIsBlank = false;
  List<BlockSlice> _slices = [];
  List<PlacedFloat> _floats = [];
  double _used = 0;
  PageGeometry _geo = PageGeometry.zero;
  DocxSectionDef _pageSection = const DocxSectionDef();
  int _pageSectionIndex = 0;
  bool _pageIsFirstOfSection = false;
  int _openDisplayNumber = 1;
  int _openAbsoluteIndex = 0;

  // Stable wrapper paragraphs for list items, so the measurement cache (keyed by
  // object identity) hits across calls instead of allocating a fresh paragraph
  // each time (§4.3).
  final Expando<DocxParagraph> _listItemParagraph = Expando<DocxParagraph>();

  double get _remaining => _geo.bodyHeight - _used;

  /// Lays [doc] out into pages and the bookmark/footnote position maps,
  /// synchronously (used by tests and small documents).
  PaginationResult paginate(DocxBuiltDocument doc) {
    _reset();
    final sections = _splitSections(doc);
    for (var si = 0; si < sections.length; si++) {
      _beginSection(sections[si], si);
      _fillBlocks(sections[si].blocks);
    }
    _closePage();
    return _finalize(doc);
  }

  /// Time-sliced pagination (Plan §4.4): the same layout, but the UI thread is
  /// released for a frame whenever a slice exceeds [sliceBudgetMs] (`TextPainter`
  /// must run on the UI thread, so we cooperate instead of blocking it). Keeps
  /// the viewer responsive while a large document paginates.
  /// [onPage] (when given) is called with each [PageModel] the moment its page
  /// is closed, in document order — so the host can render pages as they are
  /// laid out (streaming display) instead of waiting for the whole document.
  /// The complete [PaginationResult] (with the bookmark/footnote maps, which are
  /// only final at the end) is still returned.
  ///
  /// [shouldContinue], when given, is polled after each time-slice; returning
  /// false abandons the pagination (a superseded load) so it stops consuming the
  /// UI thread instead of running to completion.
  Future<PaginationResult> paginateAsync(
    DocxBuiltDocument doc, {
    int sliceBudgetMs = 8,
    void Function(PageModel page)? onPage,
    bool Function()? shouldContinue,
  }) async {
    _reset();
    _onPage = onPage;
    _shouldContinue = shouldContinue;
    final sw = Stopwatch()..start();
    final sections = _splitSections(doc);
    for (var si = 0; si < sections.length; si++) {
      _beginSection(sections[si], si);
      await _fillBlocksAsync(sections[si].blocks, sw, sliceBudgetMs);
      if (_stop) break;
    }
    _closePage();
    return _finalize(doc);
  }

  PaginationResult _finalize(DocxBuiltDocument doc) {
    if (_pages.isEmpty && !_cancelled) {
      // An empty (or not-yet-cancelled) document still shows one blank page. A
      // cancelled run returns whatever it had — the host discards it anyway.
      _pendingFirstOfSection = true;
      _openPage(doc.section ?? const DocxSectionDef(), 0);
      _closePage();
    }
    return PaginationResult(
      pages: List.unmodifiable(_pages),
      bookmarkPages: Map.unmodifiable(_bookmarkPages),
      footnotePages: Map.unmodifiable(_footnotePages),
      endnotePages: Map.unmodifiable(_endnotePages),
      truncated: _truncated,
    );
  }

  void _reset() {
    _pages.clear();
    _bookmarkPages.clear();
    _footnotePages.clear();
    _endnotePages.clear();
    _displayNumber = 1;
    _absoluteIndex = 0;
    _hasOpenPage = false;
    _slices = [];
    _floats = [];
    _used = 0;
    _pendingFirstOfSection = true;
    _onPage = null;
    _shouldContinue = null;
    _cancelled = false;
    _truncated = false;
  }

  // ===========================================================================
  // Sections
  // ===========================================================================

  /// Splits the document body into section runs at every [DocxSectionBreakBlock].
  /// A break block carries the [DocxSectionDef] of the run that *ends* at it; the
  /// trailing run uses the document's body-level [DocxBuiltDocument.section]
  /// (Plan §D / research §6.7).
  List<_SectionRun> _splitSections(DocxBuiltDocument doc) {
    final runs = <_SectionRun>[];
    var current = <DocxNode>[];
    for (final node in doc.elements) {
      if (node is DocxSectionBreakBlock) {
        runs.add(_SectionRun(current, node.section));
        current = [];
      } else {
        current.add(node);
      }
    }
    runs.add(_SectionRun(current, doc.section ?? const DocxSectionDef()));
    return runs;
  }

  /// Applies a section's start behaviour before filling its blocks.
  void _beginSection(_SectionRun run, int sectionIndex) {
    final def = run.def;
    if (sectionIndex > 0) {
      final type = def.breakType;
      if (type == DocxSectionBreak.continuous) {
        // Continuous: keep filling the current page; the new section's geometry
        // takes effect only when the next page is opened (best-effort — column
        // changes are Part I). We deliberately do NOT set _pendingFirstOfSection
        // here: the section starts mid-page on the *already-open* page (which
        // keeps the previous section's chrome/index), so no page is the section's
        // "first page" in the title-page sense. (§8.2 #14)
        _pendingSectionIndex = sectionIndex;
        // Fall through with the page still open.
      } else {
        _closePage();
        _pendingSectionIndex = sectionIndex;
        _applyParityBreak(type, def);
        _pendingFirstOfSection = true;
      }
    } else {
      _pendingSectionIndex = 0;
    }

    // Page-number restart (`w:pgNumType w:start`).
    if (def.pageNumberStart != null) {
      _displayNumber = def.pageNumberStart!;
    }

    _activeSection = def;
  }

  /// Inserts a blank page if needed so an `evenPage`/`oddPage` section starts on
  /// a page of the right parity (Plan §D.2.4). Parity is judged by the display
  /// number the next page would receive.
  void _applyParityBreak(DocxSectionBreak type, DocxSectionDef def) {
    final wantEven = type == DocxSectionBreak.evenPage;
    final wantOdd = type == DocxSectionBreak.oddPage;
    if (!wantEven && !wantOdd) return;
    final nextNumber = def.pageNumberStart ?? _displayNumber;
    final nextIsEven = nextNumber.isEven;
    if ((wantEven && !nextIsEven) || (wantOdd && nextIsEven)) {
      // Emit a forced-blank page to flip the parity.
      _pendingFirstOfSection = false;
      _openPage(def, _pendingSectionIndex, blank: true);
      _closePage();
    }
  }

  // ===========================================================================
  // Page lifecycle
  // ===========================================================================

  void _openPage(DocxSectionDef section, int sectionIndex,
      {bool blank = false}) {
    final isEven = _displayNumber.isEven;
    final isFirst = blank ? false : _pendingFirstOfSection;
    _geo = _computeGeometry(section, isFirstOfSection: isFirst, isEven: isEven);
    _slices = [];
    _floats = [];
    _used = 0;
    _pageSection = section;
    _pageSectionIndex = sectionIndex;
    _pageIsFirstOfSection = isFirst;
    _openDisplayNumber = _displayNumber;
    _openAbsoluteIndex = _absoluteIndex;
    _hasOpenPage = true;
    _openIsBlank = blank;
    if (!blank) _pendingFirstOfSection = false;
  }

  /// Ensures a page is open before placing content. Opens one with the active
  /// section's geometry when needed. No-op once stopped (cap/cancel), so the
  /// unwinding placement code never resurrects a page past the cap.
  void _ensurePage() {
    if (_stop) return;
    if (!_hasOpenPage) {
      _openPage(_activeSection, _pendingSectionIndex);
    }
  }

  void _closePage() {
    if (!_hasOpenPage) return;
    final page = PageModel(
      pageNumber: _openDisplayNumber,
      absoluteIndex: _openAbsoluteIndex,
      sectionIndex: _pageSectionIndex,
      section: _pageSection,
      slices: List.unmodifiable(_slices),
      usedHeight: _used,
      geometry: _geo,
      isFirstPageOfSection: _pageIsFirstOfSection,
      isEvenPage: _openDisplayNumber.isEven,
      isBlank: _openIsBlank,
      floats: List.unmodifiable(_floats),
    );
    _pages.add(page);
    _displayNumber++;
    _absoluteIndex++;
    _hasOpenPage = false;
    if (_pages.length >= maxPages) _truncated = true; // anti-runaway backstop
    // Emit the finished page so a streaming host can display it immediately.
    _onPage?.call(page);
  }

  /// Closes the current page and immediately opens a fresh one in the same
  /// section, for content that overflowed. Once the page cap is hit (flagged by
  /// [_closePage]) it does not open another page, so pagination stops at exactly
  /// [maxPages].
  void _newPage() {
    final section = _hasOpenPage ? _pageSection : _activeSection;
    final sectionIndex =
        _hasOpenPage ? _pageSectionIndex : _pendingSectionIndex;
    _closePage();
    if (_truncated) return;
    _openPage(section, sectionIndex);
  }

  // ===========================================================================
  // Block placement
  // ===========================================================================

  void _fillBlocks(List<DocxNode> blocks) {
    var i = 0;
    while (i < blocks.length && !_stop) {
      i = _placeNextGroup(blocks, i);
    }
  }

  /// Async variant of [_fillBlocks] that yields the UI thread between groups once
  /// the current slice exceeds [budgetMs] (Plan §4.4). After each yield it polls
  /// [_shouldContinue] and abandons a superseded pagination.
  Future<void> _fillBlocksAsync(
      List<DocxNode> blocks, Stopwatch sw, int budgetMs) async {
    var i = 0;
    while (i < blocks.length && !_stop) {
      i = _placeNextGroup(blocks, i);
      if (sw.elapsedMilliseconds >= budgetMs) {
        await Future<void>.delayed(Duration.zero);
        sw.reset();
        if (_shouldContinue != null && !_shouldContinue!()) _cancelled = true;
      }
    }
  }

  /// Builds the keepNext group starting at [i] (consecutive blocks where each
  /// but the last has `w:keepNext`, Plan §D.2.3), places it, and returns the
  /// index past the group.
  int _placeNextGroup(List<DocxNode> blocks, int i) {
    final group = <DocxNode>[blocks[i]];
    while (i + 1 < blocks.length && _keepsWithNext(blocks[i])) {
      i++;
      group.add(blocks[i]);
    }
    i++;
    _placeGroup(group);
    return i;
  }

  bool _keepsWithNext(DocxNode block) =>
      block is DocxParagraph && block.keepWithNext;

  void _placeGroup(List<DocxNode> group) {
    if (_stop) return;
    if (group.length > 1) {
      _ensurePage();
      final groupHeight = group.fold<double>(
          0, (h, b) => h + _measureBlock(b, _geo.contentWidth));
      // Move the whole group to a fresh page only when it does not fit here but
      // would fit on an empty page; otherwise place individually (which allows
      // each block to split normally — keepNext is best-effort, §D.2.3).
      if (_used > 0 &&
          groupHeight > _remaining &&
          groupHeight <= _geo.bodyHeight) {
        _newPage();
      }
    }
    for (final block in group) {
      _placeBlock(block);
    }
  }

  void _placeBlock(DocxNode block) {
    if (_stop) return; // unwind the split recursion once stopped (cap/cancel)
    _ensurePage();

    // Hard page break before this paragraph (`w:pageBreakBefore`).
    if (block is DocxParagraph && block.pageBreakBefore && _used > 0) {
      _newPage();
      if (_stop) return;
    }

    // Inline page break (`w:br w:type="page"`): split the paragraph at the first
    // break so the remainder starts a new page (Plan §D.2.5). The break inline
    // itself is dropped; an empty pre-break part does not waste a page.
    if (block is DocxParagraph) {
      final bi =
          block.children.indexWhere((c) => c is DocxLineBreak && c.isPageBreak);
      if (bi >= 0) {
        final pre = block.children.sublist(0, bi);
        final post = block.children.sublist(bi + 1);
        if (pre.isNotEmpty) {
          _placeBlock(block.copyWith(
            children: pre,
            spacingAfter: 0,
            pageBreakBefore: false,
          ));
        }
        if (_used > 0) _closePage(); // only break when content sits above it
        if (post.isNotEmpty) {
          _placeBlock(block.copyWith(
            children: post,
            spacingBefore: 0,
            pageBreakBefore: false,
          ));
        }
        return;
      }
    }

    // Word suppresses a paragraph's "space before" when it lands at the top of a
    // page: the first block hugs the top margin instead of being pushed down by
    // its before-spacing. Mirror that here (after any page break above, so a
    // pageBreakBefore/heading paragraph also sits at the new page top). Storing
    // the suppressed copy as the slice keeps measurement ≡ rendering.
    //
    // Also clear pageBreakBefore at the page top: the new page already realises
    // the break, so the renderer must not additionally draw a leading break
    // Divider (paragraph_builder) — that 32px is never accounted for by the
    // measurer and would push the body past the packed area (QA F1).
    if (_used == 0 &&
        block is DocxParagraph &&
        ((block.spacingBefore ?? 0) != 0 || block.pageBreakBefore)) {
      block = block.copyWith(spacingBefore: 0, pageBreakBefore: false);
    }

    final height = _measureBlock(block, _geo.contentWidth);

    if (height <= _remaining) {
      _addWhole(block, height);
      return;
    }

    // Does not fit in the remaining space. Try to split it.
    final split = _trySplit(block, _remaining, atPageStart: _used == 0);
    if (split != null) {
      if (split.head != null) {
        final top = _used;
        _slices.add(split.head!);
        _used += split.head!.height;
        _recordAnchors(split.head!.block);
        _recordFloats(split.head!.block, top);
      }
      _newPage();
      _placeBlock(split.tail);
      return;
    }

    // Not splittable. On a fresh page, clamp (place anyway, overflow tolerated).
    if (_used == 0) {
      _addWhole(block, height);
      return;
    }

    // Otherwise move the whole block to a fresh page and retry.
    _newPage();
    _placeBlock(block);
  }

  void _addWhole(DocxNode block, double height) {
    final top = _used;
    _slices.add(BlockSlice(block, height));
    _used += height;
    _recordAnchors(block);
    _recordFloats(block, top);
  }

  /// Resolves any floating drawings anchored in [block] (a top-level paragraph)
  /// to body-coordinate rectangles for the open page (Plan §H.2). [anchorTop] is
  /// the y at which the block was placed, used for paragraph/line-relative
  /// vertical placement. A `topAndBottom` float additionally reserves vertical
  /// space — the bottom of its exclusion box becomes the new content cursor — so
  /// following blocks clear it (text above/below, none beside). Side and layered
  /// floats are recorded for rendering without changing the flow here (side
  /// wrapping is the next step; layered floats never affect flow).
  void _recordFloats(DocxNode block, double anchorTop) {
    if (block is! DocxParagraph) return;
    for (final inline in block.children) {
      final placement = floatPlacementOf(inline);
      if (placement == null) continue;
      final rect = resolveFloatRect(
        placement,
        geo: _geo,
        anchorTopPx: anchorTop,
        pageIsRtl: block.isRtl,
      );
      _floats.add(PlacedFloat(drawing: inline, rect: rect));
      if (placement.flow == FloatFlow.fullWidth) {
        final clearedTo =
            rect.exBottom.clamp(_used, _geo.bodyHeight).toDouble();
        if (clearedTo > _used) _used = clearedTo;
      }
    }
  }

  /// Records bookmark/footnote anchors found in [block] against the open page.
  void _recordAnchors(DocxNode block) {
    if (block is DocxParagraph) {
      _scanInlines(block.children);
    } else if (block is DocxTable) {
      for (final row in block.rows) {
        for (final cell in row.cells) {
          for (final b in cell.children) {
            _recordAnchors(b);
          }
        }
      }
    }
  }

  void _scanInlines(List<DocxInline> inlines) {
    for (final inline in inlines) {
      if (inline is DocxBookmark) {
        _bookmarkPages.putIfAbsent(inline.name, () => _openDisplayNumber);
      } else if (inline is DocxFootnoteRef) {
        // Footnote and endnote ids are independent sequences — keep them in
        // separate maps so id 1 of each does not collide (Part J consumer).
        _footnotePages.putIfAbsent(inline.footnoteId, () => _openAbsoluteIndex);
      } else if (inline is DocxEndnoteRef) {
        _endnotePages.putIfAbsent(inline.endnoteId, () => _openAbsoluteIndex);
      }
    }
  }

  // ===========================================================================
  // Splitting (M4/M5 fill these in; M3 returns null = "move whole block")
  // ===========================================================================

  /// Attempts to split [block] so its head fits in [remaining] pixels. Returns
  /// null when the block cannot (or should not) be split here, in which case the
  /// caller moves the whole block to the next page.
  _Split? _trySplit(DocxNode block, double remaining,
      {required bool atPageStart}) {
    if (block is DocxParagraph) {
      return _splitParagraph(block, remaining, atPageStart: atPageStart);
    }
    if (block is DocxTable) {
      return _splitTable(block, remaining, atPageStart: atPageStart);
    }
    return null;
  }

  /// Splits a paragraph at a line boundary so the lines that fit stay on the
  /// page (Plan §D.2.2 / §6.4). Honours `keepLines` (no split) and
  /// `widowControl` (≥2 lines on each side). The head/tail are lightweight
  /// sliced paragraphs sharing every non-boundary inline by reference.
  _Split? _splitParagraph(DocxParagraph p, double remaining,
      {required bool atPageStart}) {
    if (p.keepLines) return null; // never split this paragraph

    final dir = _directionOf(p);
    final m = measurer.measureParagraph(p, _geo.contentWidth, direction: dir);
    if (m.lineCount <= 1) return null; // a single line cannot be split

    final contentAvail = remaining - m.spacingBefore;
    if (contentAvail <= 0) return null; // not even the before-spacing fits

    final layout = measurer.layoutForSplit(p, _geo.contentWidth, dir);
    final total = layout.lineCount;
    if (total <= 1) return null;

    // Largest line count whose bottom edge fits in the available content height.
    var fit = 0;
    for (var k = 1; k <= total; k++) {
      if (layout.lineTop[k] <= contentAvail + 0.5) {
        fit = k;
      } else {
        break;
      }
    }
    if (fit >= total) return null; // everything fits → caller moves it whole

    // Widow/orphan control: at least two lines on each side of the break.
    if (p.widowControl) {
      if (fit < 2) return null; // orphan: <2 lines on the head → move whole
      if (total - fit == 1) fit -= 1; // widow: a lone last line → push it down
      if (fit < 2) return null; // the decrement created an orphan → move whole
    }
    if (fit < 1) return null; // nothing fits

    final splitChar = layout.lineStartChar[fit];
    final endChar = layout.lineStartChar[total];
    final headChildren = measurer.spanFactory
        .sliceInlines(p.children, layout.segments, 0, splitChar);
    // The tail runs to the paragraph end, so an anchor at the final offset
    // belongs to it (includeEndAnchors) — keeps split bookmarks resolvable.
    final tailChildren = measurer.spanFactory.sliceInlines(
        p.children, layout.segments, splitChar, endChar,
        includeEndAnchors: true);
    if (headChildren.isEmpty || tailChildren.isEmpty) return null;

    final headHeight = m.spacingBefore + layout.lineTop[fit];
    // Head keeps the before-spacing; its after-spacing is suppressed (it
    // continues). Tail drops the before-spacing and first-line indent (Word
    // gives a continuation no first-line indent) and any page-break-before.
    final headPara = p.copyWith(children: headChildren, spacingAfter: 0);
    final tailPara = p.copyWith(
      children: tailChildren,
      spacingBefore: 0,
      indentFirstLine: 0,
      pageBreakBefore: false,
    );

    return _Split(
      head: BlockSlice(headPara, headHeight),
      tail: tailPara,
    );
  }

  /// Splits a table between rows so the rows that fit stay on the page (Plan
  /// §D.2.7 / §6.5). Leading `w:tblHeader` rows repeat at the top of every
  /// continuation. A single body row taller than a page is clamped (overflow
  /// tolerated) rather than dropped; per-cell splitting is a future extension.
  ///
  /// `w:cantSplit` is honoured implicitly: splitting only happens *between*
  /// rows, never through a row's content.
  _Split? _splitTable(DocxTable table, double remaining,
      {required bool atPageStart}) {
    final rows = table.rows;
    if (rows.isEmpty) return null;

    // Leading header rows (repeat on each continuation).
    var headerCount = 0;
    while (headerCount < rows.length && rows[headerCount].isHeader) {
      headerCount++;
    }
    final headerRows = rows.sublist(0, headerCount);
    final bodyRows = rows.sublist(headerCount);
    if (bodyRows.length <= 1) return null; // nothing to split between

    final cols = resolveTableColumnWidths(table,
            availableWidth: _geo.contentWidth,
            minColumnWidths: _minWidthsOf(table))
        .columns;
    final headerHeight = _measureRows(headerRows, table, cols);

    var used = headerHeight;
    var fitBody = 0;
    for (final row in bodyRows) {
      final rh = _measureRow(row, table, cols);
      if (used + rh <= remaining + 0.5) {
        used += rh;
        fitBody++;
      } else {
        break;
      }
    }

    if (fitBody == 0) {
      // Header + first body row already overflow. On a fresh page, clamp the one
      // oversized row and continue; otherwise move the whole table down.
      if (atPageStart && bodyRows.length > 1) {
        fitBody = 1;
        used = headerHeight + _measureRow(bodyRows.first, table, cols);
      } else {
        return null;
      }
    }
    if (fitBody >= bodyRows.length) return null; // all fit → move whole

    final headRows = [...headerRows, ...bodyRows.sublist(0, fitBody)];
    final tailRows = [...headerRows, ...bodyRows.sublist(fitBody)];
    final headTable = table.copyWith(rows: headRows);
    final tailTable = table.copyWith(rows: tailRows);

    return _Split(
      head: BlockSlice(headTable, used),
      tail: tailTable,
    );
  }

  // ===========================================================================
  // Measurement
  // ===========================================================================

  // Fallback heights/margins for block kinds without real measurement yet.
  // These are best-effort estimates refined by later parts (F=tables, G=lists,
  // H=images/shapes); tune here.
  static const double _defaultImageHeightPx = 200.0;
  static const double _imageMarginPx =
      16.0; // vertical space around a block image
  static const double _dropCapHeightPx = 80.0;
  static const double _shapeHeightPx = 120.0;
  static const double _unknownBlockHeightPx = 24.0; // one conservative line
  static const double _listLevelIndentPx = 24.0; // per nesting level (~0.25")
  static const double _minContentWidthPx = 8.0;

  /// Measures the full vertical footprint of [block] at [width] pixels.
  double _measureBlock(DocxNode block, double width) {
    if (block is DocxParagraph) {
      return measurer
          .measureParagraph(block, width, direction: _directionOf(block))
          .totalHeight;
    }
    if (block is DocxTable) {
      return _measureTable(block, width);
    }
    if (block is DocxList) {
      return _measureList(block, width);
    }
    if (block is DocxImage) {
      final h =
          block.height > 0 ? block.height.toDouble() : _defaultImageHeightPx;
      return h + _imageMarginPx;
    }
    if (block is DocxDropCap) {
      // Drop cap is a paragraph with an oversized initial; estimate generously
      // (refined when Part E/H formalise drop-cap layout).
      return _dropCapHeightPx;
    }
    if (block is DocxShapeBlock) {
      return _shapeHeightPx;
    }
    return _unknownBlockHeightPx;
  }

  /// Mirrors the renderer's direction choice (paragraph_builder
  /// `_detectDirection`): `w:bidi` is authoritative; otherwise detect from the
  /// inline content. Keeping these in sync makes the measured split offsets
  /// match the painted layout for RTL/mixed paragraphs.
  TextDirection _directionOf(DocxParagraph p) => p.isRtl
      ? TextDirection.rtl
      : TextDirectionDetector.fromInlines(p.children);

  /// Measures a table's height with the real per-column widths resolved by Part
  /// F's [resolveTableColumnWidths] (Plan §F.1), so the page-packing height
  /// matches the painted table (no longer an equal-column approximation).
  double _measureTable(DocxTable table, double width) {
    if (table.rows.isEmpty) return 0;
    final cols = resolveTableColumnWidths(table,
            availableWidth: width, minColumnWidths: _minWidthsOf(table))
        .columns;
    return _measureRows(table.rows, table, cols);
  }

  /// The content-width floor vector for [table] (longest-word px per grid
  /// column), memoised by identity. Computed from the same span construction the
  /// measurer uses, so the renderer derives the same vector (QA F3).
  List<double> _minWidthsOf(DocxTable table) => _minColWidths.putIfAbsent(
      table, () => computeMinColumnWidths(table, measurer.spanFactory));

  double _measureRows(
      List<DocxTableRow> rows, DocxTable table, List<double> cols) {
    var total = 0.0;
    for (final row in rows) {
      total += _measureRow(row, table, cols);
    }
    return total;
  }

  double _measureRow(DocxTableRow row, DocxTable table, List<double> cols) {
    var rowHeight = 0.0;
    // Walk the row's cells across the grid, honouring `w:gridBefore` and each
    // cell's `w:gridSpan`, so every cell is measured at its true content width.
    var gridIndex = row.gridBefore;
    for (final cell in row.cells) {
      final span = cell.colSpan > 0 ? cell.colSpan : 1;
      final margins = resolveCellMargins(table, cell);
      final cellWidth = cellContentWidthPx(cols, gridIndex, span, margins)
          .clamp(_minContentWidthPx, double.infinity);
      var cellHeight = margins.top + margins.bottom;
      for (final block in cell.children) {
        cellHeight += _measureBlock(block, cellWidth);
      }
      if (cellHeight > rowHeight) rowHeight = cellHeight;
      gridIndex += span;
    }
    // `w:trHeight` rule — mirror the renderer (_buildRow) exactly so that
    // measurement ≡ rendering: only a height with an explicit rule constrains
    // the row. `exact` fixes the height (content clipped); `atLeast` is a floor;
    // `auto` (and any row with no height) sizes to its content. The renderer
    // imposes no minimum on an auto row, so neither does the measurer — the old
    // 18px floor over-estimated near-empty auto rows (QA F8).
    if (row.height != null) {
      final hPx = row.height! * kTwipsToPx;
      if (row.heightRule == DocxTableRowHeightRule.exact) return hPx;
      if (row.heightRule == DocxTableRowHeightRule.atLeast) {
        return rowHeight < hPx ? hPx : rowHeight;
      }
    }
    return rowHeight;
  }

  double _measureList(DocxList list, double width) {
    var total = 0.0;
    for (var i = 0; i < list.items.length; i++) {
      final item = list.items[i];
      // Indent the item content for its level + bullet gutter.
      final indent = (item.level + 1) * _listLevelIndentPx;
      final itemWidth = (width - indent).clamp(_minContentWidthPx, width);
      // Measure the item's inline content as a paragraph. The wrapper is cached
      // per item so the measurement LRU (keyed by identity) hits on re-measure.
      final wrap =
          _listItemParagraph[item] ??= DocxParagraph(children: item.children);
      // Vertical spacing comes from the source paragraph (Word's
      // spacingBefore/After + contextualSpacing) via the shared helper, so the
      // page-packing height matches the painted list (measure ≡ render, §G.2).
      final spacing = listItemSpacingPx(
        item,
        isFirst: i == 0,
        isLast: i == list.items.length - 1,
      );
      total += spacing.before +
          measurer.measureParagraph(wrap, itemWidth).textHeight +
          spacing.after;
    }
    return total;
  }

  /// Measures the total height of a header/footer block list at [width].
  double _measureBlocks(List<DocxBlock> blocks, double width) {
    var total = 0.0;
    for (final block in blocks) {
      total += _measureBlock(block, width);
    }
    return total;
  }

  // ===========================================================================
  // Geometry
  // ===========================================================================

  PageGeometry _computeGeometry(
    DocxSectionDef section, {
    required bool isFirstOfSection,
    required bool isEven,
  }) {
    final pageWidth =
        config.pageWidth ?? DocxUnits.twipsToPixels(section.effectiveWidth);
    final pageHeight =
        config.pageHeight ?? DocxUnits.twipsToPixels(section.effectiveHeight);

    final gutter = DocxUnits.twipsToPixels(section.gutter);
    final padLeft = DocxUnits.twipsToPixels(section.marginLeft) + gutter;
    final padRight = DocxUnits.twipsToPixels(section.marginRight);
    final padTop = DocxUnits.twipsToPixels(section.marginTop);
    final padBottom = DocxUnits.twipsToPixels(section.marginBottom);
    final headerDist = DocxUnits.twipsToPixels(section.marginHeader);
    final footerDist = DocxUnits.twipsToPixels(section.marginFooter);

    final contentWidth =
        (pageWidth - padLeft - padRight).clamp(16.0, pageWidth);

    // Header/footer measured height for the page's variant (Plan §D.2.1): a tall
    // header/footer pushes the body inward so it never overlaps the chrome. For
    // the common case (short chrome inside the margin) `dist + chromeHeight ≤
    // margin`, so the body region equals the raw margins. The renderer reuses
    // this exact geometry (via PageModel.geometry), so packed area ≡ painted.
    final header =
        section.headerFor(isFirstPage: isFirstOfSection, isEvenPage: isEven);
    final footer =
        section.footerFor(isFirstPage: isFirstOfSection, isEvenPage: isEven);
    final headerHeight =
        header == null ? 0.0 : _measureBlocks(header.children, contentWidth);
    final footerHeight =
        footer == null ? 0.0 : _measureBlocks(footer.children, contentWidth);

    final bodyTop =
        padTop > headerDist + headerHeight ? padTop : headerDist + headerHeight;
    final bodyBottom = padBottom > footerDist + footerHeight
        ? padBottom
        : footerDist + footerHeight;

    return PageGeometry(
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      padLeft: padLeft,
      padRight: padRight,
      padTop: padTop,
      padBottom: padBottom,
      bodyTop: bodyTop,
      bodyBottom: bodyBottom,
      headerDist: headerDist,
      footerDist: footerDist,
    );
  }
}

/// A run of body blocks governed by one section definition.
class _SectionRun {
  _SectionRun(this.blocks, this.def);
  final List<DocxNode> blocks;
  final DocxSectionDef def;
}

/// The portion of a split block that fits ([head], may be null) and the
/// remainder ([tail]) to carry to the next page.
class _Split {
  const _Split({this.head, required this.tail});
  final BlockSlice? head;
  final DocxNode tail;
}
