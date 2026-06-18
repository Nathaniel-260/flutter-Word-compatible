import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/widgets.dart';
import 'package:xml/xml.dart';

import '../docx_view_config.dart';
import '../layout/column_layout.dart';
import '../layout/float_layout.dart';
import '../layout/float_text_layout.dart';
import '../layout/list_layout.dart';
import '../layout/table_layout.dart';
import '../layout/table_min_widths.dart';
import '../layout/text_measurer.dart';
import '../utils/docx_units.dart';
import '../utils/text_direction_detector.dart';
import 'block_slice.dart';
import 'page_context.dart';
import 'page_model.dart';
import 'toc_expander.dart';

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
  final Map<String, int> _bookmarkPageIndex = {};
  final Map<int, int> _footnotePages = {};
  final Map<int, int> _endnotePages = {};
  final Map<int, String> _footnoteLabels = {};
  final Map<int, String> _endnoteLabels = {};

  // --- Footnote state (Plan §J) --------------------------------------------
  // Notes indexed by id for content lookup (separators with id ≤ 0 are kept but
  // never referenced, so they never reach a page). Built once per paginate call.
  Map<int, DocxFootnote> _footnotesById = const {};
  Map<int, DocxEndnote> _endnotesById = const {};
  // Measured note-content heights at the active content width, memoised by id so
  // a note checked for fit and then committed is not re-measured.
  final Map<int, double> _footnoteHeightCache = {};
  // Running display number for the next footnote reference, per the effective
  // restart mode (reset at section/page boundaries by [_resetFootnoteNumbering]).
  int _footnoteNumber = 1;
  // Running display number for the next endnote reference. Endnotes are numbered
  // continuously across the document (Word's default) and collected at the end.
  int _endnoteNumber = 1;
  // Effective footnote properties for the active section (its own `w:footnotePr`
  // overrides the document-level default).
  DocxNoteProperties? _activeFootnoteProps;
  DocxNoteProperties? _docFootnoteProps;
  DocxNoteProperties? _docEndnoteProps;

  // Per-table content-width floors (longest-word px per grid column), memoised by
  // table identity so a table measured and then split is not recomputed. The
  // renderer derives the same vector independently (deterministic) → measure ≡
  // render for autofit table widths (QA F3).
  final Map<DocxTable, List<double>> _minColWidths = {};

  // --- STYLEREF state (Plan §K.3) ------------------------------------------
  // Normalized style keys actually referenced by a STYLEREF field anywhere in the
  // document/headers/footers; only these are tracked while filling pages.
  Set<String> _styleRefTargets = const {};
  // styleId → normalized style-name key (from styles.xml), so a paragraph whose
  // styleId differs from its display name still matches `STYLEREF "<name>"`.
  Map<String, String> _styleIdToNameKey = const {};
  // Running text of the last paragraph seen for each tracked style key, carried
  // across pages (the running-head value when a page has no such paragraph).
  final Map<String, String> _runningStyleText = {};
  // First/last matching paragraph text on the open page (cleared per page).
  final Map<String, String> _pageStyleFirst = {};
  final Map<String, String> _pageStyleLast = {};
  // Snapshot of [_runningStyleText] at page open, so a page with no matching
  // paragraph still resolves to the carried-over value.
  Map<String, String> _styleTextAtPageStart = const {};
  // True once any field inline (PAGE/NUMPAGES/SECTIONPAGES/PAGEREF/STYLEREF) is
  // seen in the body, so the renderer can skip the per-page field-substitution
  // scan entirely for a field-less document (exposed as
  // [PaginationResult.hasBodyField]).
  bool _hasBodyField = false;

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
  // Footnotes whose references have committed to the open page, in order, plus
  // the height band they reserve at the bottom of the body (Plan §J.2).
  List<PlacedFootnote> _pageFootnotes = [];
  final Set<int> _pageFootnoteIds = {};
  double _footnotesBand = 0;
  double _used = 0;
  PageGeometry _geo = PageGeometry.zero;
  DocxSectionDef _pageSection = const DocxSectionDef();
  int _pageSectionIndex = 0;
  bool _pageIsFirstOfSection = false;
  int _openDisplayNumber = 1;
  int _openAbsoluteIndex = 0;

  // --- Multi-column state (Plan §I) -----------------------------------------
  // _colCount=1 means single-column (no columns layout). _colIndex is the
  // 0-based index of the column currently being filled. _colWidths holds the
  // resolved pixel width of each column; empty for single-column pages.
  int _colCount = 1;
  int _colIndex = 0;
  List<double> _colWidths = const [];

  // Stable wrapper paragraphs for list items, so the measurement cache (keyed by
  // object identity) hits across calls instead of allocating a fresh paragraph
  // each time (§4.3).
  final Expando<DocxParagraph> _listItemParagraph = Expando<DocxParagraph>();

  // Body height still free for content: the full body height minus what is
  // already used and the footnote band reserved at the bottom (Plan §J.2).
  double get _remaining => _geo.bodyHeight - _used - _footnotesBand;

  /// Active content width: the current column's width in multi-column sections,
  /// or the full page content width in single-column sections (Plan §I.1).
  double get _activeContentWidth =>
      _colCount > 1 && _colIndex < _colWidths.length
          ? _colWidths[_colIndex]
          : _geo.contentWidth;

  /// Advances to the next column, or to the next page when the last column is
  /// full (Plan §I.1). In a single-column section this is equivalent to a page
  /// break (so column breaks degrade gracefully in single-column docs).
  void _advanceColumn() {
    if (_colCount <= 1) {
      _newPage();
      return;
    }
    _colIndex++;
    if (_colIndex >= _colCount) {
      // Last column overflowed — open the next page (resets _colIndex via
      // _openPage which calls _applyColumnLayout).
      _newPage();
    } else {
      // Same page, next column: reset the used-height cursor for this column.
      _used = 0;
    }
  }

  /// (Re)computes the column layout for [section] on the open page. Called
  /// from [_openPage] and from [_beginSection] for continuous-break transitions
  /// so that a mid-page section change (e.g. single→multi-column) is respected.
  void _applyColumnLayout(DocxSectionDef section) {
    final cols = section.columns;
    if (cols != null && cols.count > 1) {
      _colWidths = resolveColumnWidths(cols, _geo.contentWidth);
      // Track the resolved width count, not the raw `w:num`, so the two never
      // disagree (resolveColumnWidths clamps to 64) — otherwise a pathological
      // count would advance past the last resolved width and measure full-width.
      _colCount = _colWidths.length;
    } else {
      _colCount = 1;
      _colWidths = const [];
    }
    _colIndex = 0;
  }

  // Vertical space the footnote separator occupies (the ⅓-width rule plus a
  // little breathing room above the first note), and the gap between notes.
  static const double _footnoteSeparatorBand = 11.0;
  static const double _footnoteGapPx = 2.0;

  /// Lays [doc] out into pages and the bookmark/footnote position maps,
  /// synchronously (used by tests and small documents).
  PaginationResult paginate(DocxBuiltDocument doc) {
    _reset();
    _prepareNotes(doc);
    _prepareStyleRefs(doc);
    final sections = _splitSections(doc);
    for (var si = 0; si < sections.length; si++) {
      _beginSection(sections[si], si);
      _fillBlocks(sections[si].blocks);
    }
    // Endnotes flow at the document end, after the body (Plan §J.5).
    _fillBlocks(_buildEndnoteBlocks());
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
    _prepareNotes(doc);
    _prepareStyleRefs(doc);
    _onPage = onPage;
    _shouldContinue = shouldContinue;
    final sw = Stopwatch()..start();
    final sections = _splitSections(doc);
    for (var si = 0; si < sections.length; si++) {
      _beginSection(sections[si], si);
      await _fillBlocksAsync(sections[si].blocks, sw, sliceBudgetMs);
      if (_stop) break;
    }
    // Endnotes flow at the document end, after the body (Plan §J.5).
    if (!_stop) {
      await _fillBlocksAsync(_buildEndnoteBlocks(), sw, sliceBudgetMs);
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
      bookmarkPageIndex: Map.unmodifiable(_bookmarkPageIndex),
      footnotePages: Map.unmodifiable(_footnotePages),
      endnotePages: Map.unmodifiable(_endnotePages),
      footnoteLabels: Map.unmodifiable(_footnoteLabels),
      endnoteLabels: Map.unmodifiable(_endnoteLabels),
      truncated: _truncated,
      hasBodyField: _hasBodyField,
    );
  }

  void _reset() {
    _pages.clear();
    _bookmarkPages.clear();
    _bookmarkPageIndex.clear();
    _footnotePages.clear();
    _endnotePages.clear();
    _footnoteLabels.clear();
    _endnoteLabels.clear();
    _footnoteHeightCache.clear();
    _fnCacheWidth = double.nan;
    _footnoteNumber = 1;
    _endnoteNumber = 1;
    _displayNumber = 1;
    _absoluteIndex = 0;
    _hasOpenPage = false;
    _slices = [];
    _floats = [];
    _pageFootnotes = [];
    _pageFootnoteIds.clear();
    _footnotesBand = 0;
    _used = 0;
    _colCount = 1;
    _colIndex = 0;
    _colWidths = const [];
    _pendingFirstOfSection = true;
    _onPage = null;
    _shouldContinue = null;
    _cancelled = false;
    _truncated = false;
    _runningStyleText.clear();
    _pageStyleFirst.clear();
    _pageStyleLast.clear();
    _styleTextAtPageStart = const {};
    _hasBodyField = false;
  }

  // ===========================================================================
  // STYLEREF (Plan §K.3)
  // ===========================================================================

  /// Scans the document (body + every header/footer variant of every section)
  /// for `STYLEREF` fields and records the set of style names they reference, and
  /// builds a `styleId → normalized name` map from `styles.xml` so a paragraph's
  /// styleId matches a STYLEREF that names the style's display name. Called once
  /// per paginate, after [_reset]; cheap and skipped entirely when no STYLEREF is
  /// present (the common case).
  void _prepareStyleRefs(DocxBuiltDocument doc) {
    final targets = <String>{};
    void scanInlines(List<DocxInline> inlines) {
      for (final i in inlines) {
        if (i is DocxStyleRef) {
          targets.add(PageContext.normalizeStyleKey(i.styleName));
        }
      }
    }

    void scanBlocks(List<DocxNode> nodes) {
      for (final n in nodes) {
        if (n is DocxParagraph) {
          scanInlines(n.children);
        } else if (n is DocxTable) {
          for (final row in n.rows) {
            for (final cell in row.cells) {
              scanBlocks(cell.children);
            }
          }
        } else if (n is DocxSectionBreakBlock) {
          _scanSectionChrome(n.section, scanBlocks);
        }
      }
    }

    scanBlocks(doc.elements);
    if (doc.section != null) _scanSectionChrome(doc.section!, scanBlocks);
    _styleRefTargets = targets;
    _styleIdToNameKey =
        targets.isEmpty ? const {} : _parseStyleNames(doc.stylesXml);
  }

  void _scanSectionChrome(
      DocxSectionDef section, void Function(List<DocxNode>) scanBlocks) {
    for (final h in [
      section.header,
      section.firstHeader,
      section.evenHeader,
    ]) {
      if (h != null) scanBlocks(h.children);
    }
    for (final f in [
      section.footer,
      section.firstFooter,
      section.evenFooter,
    ]) {
      if (f != null) scanBlocks(f.children);
    }
  }

  /// Parses `styles.xml` into `styleId → normalized style-name key`. Best-effort;
  /// an unparseable or absent stylesheet yields an empty map (STYLEREF then
  /// matches on the normalized styleId alone).
  Map<String, String> _parseStyleNames(String? stylesXml) {
    if (stylesXml == null || stylesXml.isEmpty) return const {};
    try {
      final xml = XmlDocument.parse(stylesXml);
      final map = <String, String>{};
      for (final s in xml.findAllElements('w:style')) {
        final id = s.getAttribute('w:styleId');
        final name = s.getElement('w:name')?.getAttribute('w:val');
        if (id != null && name != null) {
          map[id] = PageContext.normalizeStyleKey(name);
        }
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  /// The set of tracked STYLEREF keys a paragraph with [styleId] satisfies: the
  /// normalized styleId itself and its style's normalized display name (so both
  /// `STYLEREF "Heading 1"` against styleId `Heading1` and a custom-named style
  /// resolve). Empty when no STYLEREF targets that style.
  Iterable<String> _styleRefKeysFor(String? styleId) {
    if (styleId == null || _styleRefTargets.isEmpty) return const [];
    final keys = <String>[];
    final idKey = PageContext.normalizeStyleKey(styleId);
    if (_styleRefTargets.contains(idKey)) keys.add(idKey);
    final nameKey = _styleIdToNameKey[styleId];
    if (nameKey != null &&
        nameKey != idKey &&
        _styleRefTargets.contains(nameKey)) {
      keys.add(nameKey);
    }
    return keys;
  }

  /// Records a placed [block]'s text against the STYLEREF tracking maps (Plan
  /// §K.3): updates the running value and the open page's first/last for every
  /// tracked style key the paragraph's style satisfies.
  void _recordStyleRef(DocxParagraph block) {
    if (_styleRefTargets.isEmpty) return;
    final keys = _styleRefKeysFor(block.styleId);
    if (keys.isEmpty) return;
    final text = _paragraphText(block);
    if (text.isEmpty) return;
    for (final key in keys) {
      _runningStyleText[key] = text;
      _pageStyleFirst.putIfAbsent(key, () => text);
      _pageStyleLast[key] = text;
    }
  }

  /// The visible text of a paragraph (non-hidden [DocxText] runs concatenated and
  /// trimmed) — the value Word shows for a STYLEREF to that paragraph's style.
  static String _paragraphText(DocxParagraph p) {
    final buf = StringBuffer();
    for (final i in p.children) {
      if (i is DocxText && !i.hidden) buf.write(i.content);
    }
    return buf.toString().trim();
  }

  // ===========================================================================
  // Footnotes (Plan §J)
  // ===========================================================================

  /// Indexes the document's notes by id and captures the document-level note
  /// properties (a section's own `w:footnotePr` overrides these). Called once
  /// per paginate, after [_reset].
  void _prepareNotes(DocxBuiltDocument doc) {
    _footnotesById = {
      for (final f in doc.footnotes ?? const <DocxFootnote>[]) f.footnoteId: f,
    };
    _endnotesById = {
      for (final e in doc.endnotes ?? const <DocxEndnote>[]) e.endnoteId: e,
    };
    _docFootnoteProps = doc.footnoteProperties;
    _activeFootnoteProps = doc.footnoteProperties;
    _docEndnoteProps = doc.endnoteProperties;
  }

  /// The effective endnote number format (default: `decimal`).
  DocxPageNumberFormat get _endnoteFormat =>
      _docEndnoteProps?.format ?? DocxPageNumberFormat.decimal;

  /// Builds the flowed blocks for the document's endnotes (Plan §J.5), in body
  /// reference order, each note's number prepended to its first paragraph as a
  /// superscript. Returns an empty list when no endnote was referenced. Endnotes
  /// are placed at the document end (`w:pos="docEnd"`, the default); the rarer
  /// `sectEnd` position is a documented deviation (§8.2).
  List<DocxNode> _buildEndnoteBlocks() {
    if (_endnoteLabels.isEmpty) return const [];
    final blocks = <DocxNode>[];
    // `_endnoteLabels` preserves reference order (insertion-ordered map).
    for (final entry in _endnoteLabels.entries) {
      final note = _endnotesById[entry.key];
      if (note == null || note.content.isEmpty) continue;
      final prefix = DocxText('${entry.value} ', isSuperscript: true);
      final first = note.content.first;
      if (first is DocxParagraph) {
        blocks.add(first.copyWith(children: [prefix, ...first.children]));
        blocks.addAll(note.content.skip(1));
      } else {
        blocks.add(DocxParagraph(children: [prefix]));
        blocks.addAll(note.content);
      }
    }
    return blocks;
  }

  /// The effective footnote restart mode (default: `continuous`).
  DocxNoteNumberRestart get _footnoteRestart =>
      _activeFootnoteProps?.numRestart ?? DocxNoteNumberRestart.continuous;

  /// The effective footnote number format (default: `decimal`).
  DocxPageNumberFormat get _footnoteFormat =>
      _activeFootnoteProps?.format ?? DocxPageNumberFormat.decimal;

  /// Resets the running footnote number at a section boundary when the section
  /// restarts numbering `eachSect` (Plan §J.4). `eachPage` is reset in
  /// [_openPage]; `continuous` never resets.
  void _resetFootnoteNumberingForSection() {
    if (_footnoteRestart == DocxNoteNumberRestart.eachSect) _footnoteNumber = 1;
  }

  /// The measured height of footnote [id]'s content at the active content width,
  /// memoised. The cache is invalidated when the content width changes (a
  /// multi-section document can switch page geometry). A note with no content
  /// (or an unknown id) measures as zero.
  double _footnoteContentHeight(int id) {
    if (_fnCacheWidth != _geo.contentWidth) {
      _footnoteHeightCache.clear();
      _fnCacheWidth = _geo.contentWidth;
    }
    return _footnoteHeightCache.putIfAbsent(id, () {
      final note = _footnotesById[id];
      if (note == null || note.content.isEmpty) return 0;
      return _measureBlocks(note.content, _geo.contentWidth);
    });
  }

  double _fnCacheWidth = double.nan;

  /// Footnote ids newly referenced by [block] that are not already committed to
  /// the open page, in document order (so the band growth and the committed set
  /// agree). Recurses into table cells, matching [_recordAnchors].
  List<int> _newFootnoteIds(DocxNode block) {
    final ids = <int>[];
    void scan(DocxNode b) {
      if (b is DocxParagraph) {
        for (final inline in b.children) {
          if (inline is DocxFootnoteRef &&
              !_pageFootnoteIds.contains(inline.footnoteId) &&
              !ids.contains(inline.footnoteId) &&
              _footnotesById.containsKey(inline.footnoteId)) {
            ids.add(inline.footnoteId);
          }
        }
      } else if (b is DocxTable) {
        for (final row in b.rows) {
          for (final cell in row.cells) {
            for (final cb in cell.children) {
              scan(cb);
            }
          }
        }
      }
    }

    scan(block);
    return ids;
  }

  /// Height the footnote band would grow by if [newIds] were placed on the open
  /// page (separator on the first note + each note's content + an inter-note
  /// gap). Used to test fit before committing a block (Plan §J.2).
  double _footnoteGrowth(List<int> newIds) {
    if (newIds.isEmpty) return 0;
    var growth = 0.0;
    if (_pageFootnoteIds.isEmpty) growth += _footnoteSeparatorBand;
    for (final id in newIds) {
      growth += _footnoteContentHeight(id) + _footnoteGapPx;
    }
    return growth;
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
    // Expand any Table of Contents to its cached paragraphs so it flows and
    // renders through the normal paragraph path (Plan §K.1).
    for (final node in expandTocBlocks(doc.elements)) {
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
        // Continuous: keep filling the current page, but update the column
        // layout so a single→multi-column (or multi→single) transition mid-page
        // is respected (Plan §I.3 best-effort; §8.2 #14). We do NOT reset
        // _pendingFirstOfSection: the section starts mid-page on the already-open
        // page (which keeps the previous section's chrome/index).
        _pendingSectionIndex = sectionIndex;
        if (_hasOpenPage) {
          _applyColumnLayout(def);
          // _used intentionally preserved: the new column fills from where the
          // old content left off (column 0, existing cursor position).
        }
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

    // Footnote numbering: the section's own `w:footnotePr` overrides the
    // document default; restart the counter when this section restarts
    // `eachSect` (Plan §J.4).
    _activeFootnoteProps = def.footnoteProperties ?? _docFootnoteProps;
    _resetFootnoteNumberingForSection();

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
    _pageFootnotes = [];
    _pageFootnoteIds.clear();
    _footnotesBand = 0;
    // `eachPage` footnote numbering restarts at the top of every page (Plan
    // §J.4); the height cache is content-only (width-independent here) so it
    // survives across pages.
    if (_footnoteRestart == DocxNoteNumberRestart.eachPage) {
      _footnoteNumber = 1;
    }
    _used = 0;
    // STYLEREF (Plan §K.3): snapshot the carried-over running values and reset the
    // per-page first/last so a page with no matching paragraph still resolves to
    // the value carried from before it.
    if (_styleRefTargets.isNotEmpty) {
      _styleTextAtPageStart = Map.of(_runningStyleText);
      _pageStyleFirst.clear();
      _pageStyleLast.clear();
    }
    // Initialise column layout for this page (Plan §I.1).
    _applyColumnLayout(section);
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
    // STYLEREF (Plan §K.3): the page's running-head values are the first/last
    // matching paragraph on the page, falling back to the value carried in from
    // before the page when none appeared on it.
    Map<String, String> styleLast = const {};
    Map<String, String> styleFirst = const {};
    if (_styleRefTargets.isNotEmpty) {
      styleLast = {};
      styleFirst = {};
      for (final key in _styleRefTargets) {
        final last = _pageStyleLast[key] ?? _styleTextAtPageStart[key];
        final first = _pageStyleFirst[key] ?? _styleTextAtPageStart[key];
        if (last != null) styleLast[key] = last;
        if (first != null) styleFirst[key] = first;
      }
    }
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
      footnotes: List.unmodifiable(_pageFootnotes),
      footnotesHeight: _pageFootnotes.isEmpty ? 0 : _footnotesBand,
      styleRefLast: Map.unmodifiable(styleLast),
      styleRefFirst: Map.unmodifiable(styleFirst),
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
          0, (h, b) => h + _measureBlock(b, _activeContentWidth));
      // Move the whole group to a fresh page only when it does not fit here but
      // would fit on an empty page; otherwise place individually (which allows
      // each block to split normally — keepNext is best-effort, §D.2.3).
      if (_used > 0 &&
          groupHeight > _remaining &&
          groupHeight <= _geo.bodyHeight) {
        // Multi-column: move to the next column (or next page when on the last);
        // single-column: equivalent to a page break. Using _newPage() here would
        // skip the remaining columns of a multi-column page.
        _advanceColumn();
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

    if (block is DocxParagraph) {
      // Inline column break (`w:br w:type="column"`, Plan §I.2): advance to the
      // next column (or next page when already on the last column). Mirrors the
      // page-break handling below.
      final ci = block.children
          .indexWhere((c) => c is DocxLineBreak && c.isColumnBreak);
      if (ci >= 0) {
        final pre = block.children.sublist(0, ci);
        final post = block.children.sublist(ci + 1);
        if (pre.isNotEmpty) {
          _placeBlock(block.copyWith(
            children: pre,
            spacingAfter: 0,
            pageBreakBefore: false,
          ));
        }
        if (_used > 0 || _colIndex > 0) _advanceColumn();
        if (post.isNotEmpty) {
          _placeBlock(block.copyWith(
            children: post,
            spacingBefore: 0,
            pageBreakBefore: false,
          ));
        }
        return;
      }

      // Inline page break (`w:br w:type="page"`): split the paragraph at the
      // first break so the remainder starts a new page (Plan §D.2.5). The break
      // inline itself is dropped; an empty pre-break part does not waste a page.
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
    // column or page: the first block hugs the margin instead of being pushed
    // down by its before-spacing. Mirror that here. Storing the suppressed copy
    // as the slice keeps measurement ≡ rendering.
    //
    // Also clear pageBreakBefore at the column/page top: the new column already
    // realises the break, so the renderer must not additionally draw a leading
    // break Divider (paragraph_builder) — that 32px is never accounted for by
    // the measurer and would push the body past the packed area (QA F1).
    if (_used == 0 &&
        block is DocxParagraph &&
        ((block.spacingBefore ?? 0) != 0 || block.pageBreakBefore)) {
      block = block.copyWith(spacingBefore: 0, pageBreakBefore: false);
    }

    final height = _measureBlock(block, _activeContentWidth);

    // Footnotes referenced by this block grow the reserved bottom band, so they
    // count against the remaining space too (Plan §J.2): a line whose note no
    // longer fits pushes the line (and its note) to the next page.
    final newFnIds = _newFootnoteIds(block);
    final fnGrowth = _footnoteGrowth(newFnIds);

    if (height + fnGrowth <= _remaining) {
      _addWhole(block, height);
      return;
    }

    // Does not fit in the remaining space. Reserve the block's whole footnote
    // band before splitting so the head (which carries a subset of these notes)
    // cannot overflow; the tail's notes are reserved again on the next column/
    // page — conservative, but it never overflows (§8.2).
    final split =
        _trySplit(block, _remaining - fnGrowth, atPageStart: _used == 0);
    if (split != null) {
      if (split.head != null) {
        final top = _used;
        // Tag the head with the column it lands in (Plan §I).
        _slices.add(split.head!.copyWith(columnIndex: _colIndex));
        _used += split.head!.height;
        _recordAnchors(split.head!.block);
        _recordFloats(split.head!.block, top);
      }
      _advanceColumn();
      _placeBlock(split.tail);
      return;
    }

    // Not splittable. On a fresh column/page, clamp (place anyway, overflow
    // tolerated).
    if (_used == 0) {
      _addWhole(block, height);
      return;
    }

    // Otherwise move the whole block to the next column/page and retry.
    _advanceColumn();
    _placeBlock(block);
  }

  void _addWhole(DocxNode block, double height) {
    final top = _used;
    _slices.add(BlockSlice(block, height, columnIndex: _colIndex));
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
      _recordStyleRef(block);
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
      if (!_hasBodyField &&
          (inline is DocxPageNumber ||
              inline is DocxPageCount ||
              inline is DocxPageRef ||
              inline is DocxStyleRef)) {
        // A field somewhere in the body: the renderer must run field
        // substitution per page (apply still no-ops the pages that carry none).
        _hasBodyField = true;
      }
      if (inline is DocxBookmark) {
        _bookmarkPages.putIfAbsent(inline.name, () => _openDisplayNumber);
        _bookmarkPageIndex.putIfAbsent(inline.name, () => _openAbsoluteIndex);
      } else if (inline is DocxFootnoteRef) {
        // Footnote and endnote ids are independent sequences — keep them in
        // separate maps so id 1 of each does not collide (Part J consumer).
        _footnotePages.putIfAbsent(inline.footnoteId, () => _openAbsoluteIndex);
        _commitFootnote(inline.footnoteId);
      } else if (inline is DocxEndnoteRef) {
        _endnotePages.putIfAbsent(inline.endnoteId, () => _openAbsoluteIndex);
        // Number endnotes continuously in reference order; the note bodies are
        // flowed at the document end (Plan §J.5).
        _endnoteLabels.putIfAbsent(
          inline.endnoteId,
          () => NumberFormatter.formatPage(_endnoteNumber++, _endnoteFormat),
        );
      }
    }
  }

  /// Commits footnote [id] to the open page (Plan §J): assigns its display label
  /// from the running number, grows the reserved band (separator on the first
  /// note + the note's content + a gap), and records it for rendering. Idempotent
  /// per page; called from [_scanInlines] as a block is added to the page, so the
  /// number follows document order and the band matches the fit check in
  /// [_placeBlock].
  void _commitFootnote(int id) {
    if (_pageFootnoteIds.contains(id)) return;
    final note = _footnotesById[id];
    // Dangling ref / separator note → nothing to place.
    if (note == null) return;
    final label =
        NumberFormatter.formatPage(_footnoteNumber++, _footnoteFormat);
    _footnoteLabels[id] = label;
    final height = _footnoteContentHeight(id);
    if (_pageFootnoteIds.isEmpty) _footnotesBand += _footnoteSeparatorBand;
    _footnotesBand += height + _footnoteGapPx;
    _pageFootnoteIds.add(id);
    _pageFootnotes.add(PlacedFootnote(
      id: id,
      label: label,
      content: note.content,
      height: height,
    ));
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
    final w = _activeContentWidth;
    final m = measurer.measureParagraph(p, w, direction: dir);
    if (m.lineCount <= 1) return null; // a single line cannot be split

    final contentAvail = remaining - m.spacingBefore;
    if (contentAvail <= 0) return null; // not even the before-spacing fits

    final layout = measurer.layoutForSplit(p, w, dir);
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
            availableWidth: _activeContentWidth,
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
      return _measureParagraph(block, width);
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

  /// Measures a paragraph, accounting for **side-float wrapping** (Plan §H.2,
  /// §8.2 #29): when the paragraph anchors a `square`/`tight` float, its text
  /// height is recomputed with [layoutFloatWrap] — the same core the renderer
  /// (`FloatWrapText`) lays out with — so the page-packing height matches the
  /// painted height. The paragraph spacing (and the no-float fast path) come from
  /// the ordinary measurement.
  double _measureParagraph(DocxParagraph p, double width) {
    final direction = _directionOf(p);
    final base = measurer.measureParagraph(p, width, direction: direction);
    // Use the same RTL signal the renderer does (`direction`, which honours
    // both `w:bidi` and content detection), not just `p.isRtl` — otherwise an
    // RTL-by-content paragraph (common in Hebrew sacred texts, no `w:bidi`)
    // would place `inside`/`outside` floats differently here than in the
    // renderer, breaking measure ≡ render.
    final pageIsRtl = direction == TextDirection.rtl;
    final sideRects = localSideFloatRects(p.children,
        contentWidth: width, pageIsRtl: pageIsRtl);
    // Centered/offset floats render as a stacked block (not a side band), so the
    // renderer adds their height to the paragraph column — mirror that here.
    final centerFloatsHeight =
        localCenterFloatsHeight(p.children, pageIsRtl: pageIsRtl);
    if (sideRects.isEmpty && centerFloatsHeight == 0) return base.totalHeight;

    var textHeight = base.textHeight;
    if (sideRects.isNotEmpty) {
      final lineHeight = measurer.spanFactory.resolveLineHeightScale(p);
      final span = measurer.spanFactory
          .buildMeasurementSpans(p.children,
              lineHeight: lineHeight, skipHidden: true)
          .root;
      final wrap = layoutFloatWrap(
        text: span,
        floats: sideRects,
        contentWidth: width,
        direction: direction,
        strut: measurer.spanFactory.resolveStrut(p),
      );
      textHeight = wrap?.height ?? base.textHeight;
    }
    return base.spacingBefore +
        textHeight +
        centerFloatsHeight +
        base.spacingAfter;
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
