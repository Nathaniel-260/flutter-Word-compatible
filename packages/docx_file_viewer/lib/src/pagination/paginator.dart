import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/widgets.dart';

import '../docx_view_config.dart';
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
  });

  final TextMeasurer measurer;
  final DocxViewConfig config;

  // --- Output accumulators (reset per paginate call) -----------------------
  final List<PageModel> _pages = [];
  final Map<String, int> _bookmarkPages = {};
  final Map<int, int> _footnotePages = {};
  final Map<int, int> _endnotePages = {};

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
  double _used = 0;
  _Geometry _geo = const _Geometry.empty();
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

  /// Lays [doc] out into pages and the bookmark/footnote position maps.
  PaginationResult paginate(DocxBuiltDocument doc) {
    _reset();

    final sections = _splitSections(doc);
    for (var si = 0; si < sections.length; si++) {
      final run = sections[si];
      _beginSection(run, si);
      _fillBlocks(run.blocks);
    }
    _closePage();

    if (_pages.isEmpty) {
      // An empty document still shows one (blank) page.
      _pendingFirstOfSection = true;
      _openPage(doc.section ?? const DocxSectionDef(), 0);
      _closePage();
    }

    return PaginationResult(
      pages: List.unmodifiable(_pages),
      bookmarkPages: Map.unmodifiable(_bookmarkPages),
      footnotePages: Map.unmodifiable(_footnotePages),
      endnotePages: Map.unmodifiable(_endnotePages),
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
    _used = 0;
    _pendingFirstOfSection = true;
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
  /// section's geometry when needed.
  void _ensurePage() {
    if (!_hasOpenPage) {
      _openPage(_activeSection, _pendingSectionIndex);
    }
  }

  void _closePage() {
    if (!_hasOpenPage) return;
    _pages.add(PageModel(
      pageNumber: _openDisplayNumber,
      absoluteIndex: _openAbsoluteIndex,
      sectionIndex: _pageSectionIndex,
      section: _pageSection,
      slices: List.unmodifiable(_slices),
      usedHeight: _used,
      isFirstPageOfSection: _pageIsFirstOfSection,
      isEvenPage: _openDisplayNumber.isEven,
      isBlank: _openIsBlank,
    ));
    _displayNumber++;
    _absoluteIndex++;
    _hasOpenPage = false;
  }

  /// Closes the current page and immediately opens a fresh one in the same
  /// section, for content that overflowed.
  void _newPage() {
    final section = _hasOpenPage ? _pageSection : _activeSection;
    final sectionIndex =
        _hasOpenPage ? _pageSectionIndex : _pendingSectionIndex;
    _closePage();
    _openPage(section, sectionIndex);
  }

  // ===========================================================================
  // Block placement
  // ===========================================================================

  void _fillBlocks(List<DocxNode> blocks) {
    var i = 0;
    while (i < blocks.length) {
      // Build a keepNext group: consecutive blocks where each but the last has
      // `w:keepNext` (Plan §D.2.3).
      final group = <DocxNode>[blocks[i]];
      while (i + 1 < blocks.length && _keepsWithNext(blocks[i])) {
        i++;
        group.add(blocks[i]);
      }
      i++;
      _placeGroup(group);
    }
  }

  bool _keepsWithNext(DocxNode block) =>
      block is DocxParagraph && block.keepWithNext;

  void _placeGroup(List<DocxNode> group) {
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
    _ensurePage();

    // Hard page break before this paragraph (`w:pageBreakBefore`).
    if (block is DocxParagraph && block.pageBreakBefore && _used > 0) {
      _newPage();
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

    final height = _measureBlock(block, _geo.contentWidth);

    if (height <= _remaining) {
      _addWhole(block, height);
      return;
    }

    // Does not fit in the remaining space. Try to split it.
    final split = _trySplit(block, _remaining, atPageStart: _used == 0);
    if (split != null) {
      if (split.head != null) {
        _slices.add(split.head!);
        _used += split.head!.height;
        _recordAnchors(split.head!.block);
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
    _slices.add(BlockSlice(block, height));
    _used += height;
    _recordAnchors(block);
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

    final cellWidth = _tableCellContentWidth(table, _geo.contentWidth);
    final headerHeight = _measureRows(headerRows, cellWidth);

    var used = headerHeight;
    var fitBody = 0;
    for (final row in bodyRows) {
      final rh = _measureRow(row, cellWidth);
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
        used = headerHeight + _measureRow(bodyRows.first, cellWidth);
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
  static const double _minRowHeightPx = 18.0;
  static const double _listLevelIndentPx = 24.0; // per nesting level (~0.25")
  static const double _cellSideMarginPx =
      108 / 15.0; // Word default 108tw → 7.2px
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

  /// Estimates a table's height by measuring each row at an equal column-width
  /// split. Real column-width resolution (autofit) is Part F; this is a
  /// best-effort measurement good enough for page packing (Plan §6.5).
  double _measureTable(DocxTable table, double width) {
    if (table.rows.isEmpty) return 0;
    return _measureRows(table.rows, _tableCellContentWidth(table, width));
  }

  /// The per-cell content width for a table at [width], using an equal column
  /// split minus Word's default 108tw cell margins (refined by Part F).
  double _tableCellContentWidth(DocxTable table, double width) {
    var colCount = 1;
    for (final row in table.rows) {
      if (row.cells.length > colCount) colCount = row.cells.length;
    }
    final colWidth = width / colCount;
    return (colWidth - _cellSideMarginPx * 2).clamp(_minContentWidthPx, width);
  }

  double _measureRows(List<DocxTableRow> rows, double cellContentWidth) {
    var total = 0.0;
    for (final row in rows) {
      total += _measureRow(row, cellContentWidth);
    }
    return total;
  }

  double _measureRow(DocxTableRow row, double cellContentWidth) {
    var rowHeight = 0.0;
    for (final cell in row.cells) {
      var cellHeight = 0.0;
      for (final block in cell.children) {
        cellHeight += _measureBlock(block, cellContentWidth);
      }
      if (cellHeight > rowHeight) rowHeight = cellHeight;
    }
    // Minimum visible row height so empty rows still occupy space.
    return rowHeight < _minRowHeightPx ? _minRowHeightPx : rowHeight;
  }

  double _measureList(DocxList list, double width) {
    var total = 0.0;
    for (final item in list.items) {
      // Indent the item content for its level + bullet gutter.
      final indent = (item.level + 1) * _listLevelIndentPx;
      final itemWidth = (width - indent).clamp(_minContentWidthPx, width);
      // Measure the item's inline content as a paragraph. The wrapper is cached
      // per item so the measurement LRU (keyed by identity) hits on re-measure.
      final wrap =
          _listItemParagraph[item] ??= DocxParagraph(children: item.children);
      total += measurer.measureParagraph(wrap, itemWidth).totalHeight;
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

  _Geometry _computeGeometry(
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
    // header pushes the body down. For the common case (a short header sitting
    // in the top margin) headerDist + headerHeight ≈ padTop, so the body region
    // equals the renderer's content padding.
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
    final bodyHeight =
        (pageHeight - bodyTop - bodyBottom).clamp(40.0, pageHeight);

    return _Geometry(
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      contentWidth: contentWidth,
      bodyHeight: bodyHeight,
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

/// Resolved page geometry for one page variant.
class _Geometry {
  const _Geometry({
    required this.pageWidth,
    required this.pageHeight,
    required this.contentWidth,
    required this.bodyHeight,
  });

  const _Geometry.empty()
      : pageWidth = 0,
        pageHeight = 0,
        contentWidth = 0,
        bodyHeight = 0;

  final double pageWidth;
  final double pageHeight;
  final double contentWidth;
  final double bodyHeight;
}
