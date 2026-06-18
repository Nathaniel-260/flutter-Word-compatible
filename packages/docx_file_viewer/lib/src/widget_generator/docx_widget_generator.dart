import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';
import '../layout/column_layout.dart';
import '../layout/float_layout.dart';
import '../layout/numbering_resolver.dart';
import '../layout/span_factory.dart';
import '../layout/text_measurer.dart';
import '../pagination/block_slice.dart';
import '../pagination/field_substitution.dart';
import '../pagination/page_context.dart';
import '../pagination/page_model.dart';
import '../pagination/paginator.dart';
import '../search/docx_search_controller.dart';
import '../theme/docx_view_theme.dart';
import '../utils/block_index_counter.dart';
import '../utils/docx_units.dart';
import '../widgets/page_chrome.dart';
import 'image_builder.dart';
import 'list_builder.dart';
import 'paragraph_builder.dart';
import 'shape_builder.dart';
import 'table_builder.dart';

/// Generates Flutter widgets from [DocxNode] elements.
///
/// This is the core "brain" that maps OpenXML elements to Flutter widgets.
class DocxWidgetGenerator {
  final DocxViewConfig config;
  final DocxViewTheme theme;
  final DocxTheme? docxTheme;
  final DocxSearchController? searchController;

  final void Function(int id)? onFootnoteTap;
  final void Function(int id)? onEndnoteTap;

  /// Paragraph builder for text rendering.
  late ParagraphBuilder _paragraphBuilder;

  /// Table builder for table rendering.
  late TableBuilder _tableBuilder;

  /// List builder for list rendering.
  late ListBuilder _listBuilder;

  /// Image builder for image rendering.
  late ImageBuilder _imageBuilder;

  /// Shape builder for shape rendering.
  late ShapeBuilder _shapeBuilder;

  /// Store the last used counter to access widget keys after generation.
  BlockIndexCounter? _lastCounter;

  /// The last paged-mode pagination result. Shared with [extractTextForSearch]
  /// so search indices line up with the rendered slice order even across
  /// paragraph/table splits (Plan §D).
  PaginationResult? _lastPagination;

  /// Block keys for navigation.
  Map<int, GlobalKey> get keys => _lastCounter?.keyRegistry ?? {};

  /// The last pagination result (null until [generateWidgets] runs in paged
  /// mode). Exposes the bookmark→page / footnote→page maps to the host.
  PaginationResult? get lastPagination => _lastPagination;

  DocxWidgetGenerator({
    required this.config,
    DocxViewTheme? theme,
    this.docxTheme,
    this.searchController,
    this.onFootnoteTap,
    this.onEndnoteTap,
  }) : theme = theme ?? DocxViewTheme.light() {
    _paragraphBuilder = ParagraphBuilder(
      theme: this.theme,
      config: config,
      searchController: searchController,
      onFootnoteTap: onFootnoteTap,
      docxTheme: docxTheme,
      onEndnoteTap: onEndnoteTap,
    );
    _imageBuilder = ImageBuilder(config: config);
    // TableBuilder, ListBuilder, ShapeBuilder need docxTheme, set in generateWidgets
  }

  /// Generate a list of widgets from a parsed document (synchronous; one widget
  /// per page in paged mode).
  List<Widget> generateWidgets(DocxBuiltDocument doc) {
    _initBuilders(doc);
    if (config.pageMode == DocxPageMode.paged) {
      return _generatePagedWidgets(doc);
    }
    return _generateContinuousWidgets(doc);
  }

  /// Time-sliced variant of [generateWidgets] (Plan §4.4): paged-mode pagination
  /// yields the UI thread periodically so loading a large document does not
  /// freeze the frame. Continuous mode is unchanged (already cheap).
  Future<List<Widget>> generateWidgetsAsync(DocxBuiltDocument doc) async {
    _initBuilders(doc);
    if (config.pageMode == DocxPageMode.paged) {
      return _generatePagedWidgetsAsync(doc);
    }
    return _generateContinuousWidgets(doc);
  }

  /// Re-renders the page widgets from the *last* pagination without re-measuring
  /// — used when only search highlights change, since search does not affect
  /// layout (Plan §2.4.6 / §M.1). Falls back to a full [generateWidgets] when
  /// there is no cached pagination (continuous mode or before the first load).
  List<Widget> rerenderWidgets(DocxBuiltDocument doc) {
    final pagination = _lastPagination;
    if (config.pageMode == DocxPageMode.paged && pagination != null) {
      _initBuilders(doc);
      return _renderPages(doc, pagination);
    }
    return generateWidgets(doc);
  }

  /// The document the builders were last initialized for, so repeated calls
  /// with the same document (e.g. lazy per-page [buildPageWidget]) skip the
  /// rebuild. The builders depend only on `config`/`theme`/`doc.theme`.
  ///
  /// Invariant: this assumes one generator per document load (as [DocxView]
  /// creates) — `config`/`theme` are fixed at construction and `doc.theme` is
  /// keyed by document identity here. A generator reused across a *theme change
  /// with the same `doc`* would not refresh its builders.
  DocxBuiltDocument? _buildersFor;

  /// (Re)initializes the block builders that depend on the document's theme.
  void _initBuilders(DocxBuiltDocument doc) {
    if (identical(_buildersFor, doc)) return;
    _buildersFor = doc;
    _finalSectionCounts = null; // belongs to the previous document
    _lastPagination =
        null; // a stale map must not resolve this doc's note marks
    _paragraphBuilder = ParagraphBuilder(
      theme: theme,
      config: config,
      searchController: searchController,
      onFootnoteTap: onFootnoteTap,
      onEndnoteTap: onEndnoteTap,
      docxTheme: doc.theme,
    );
    // Plan §G: one document-order numbering pass so list markers continue
    // correctly across interrupting blocks, table cells and same-`numId` lists,
    // instead of restarting per [DocxList]. Computed once per document load.
    final numberLabels = NumberingResolver().resolveDocument(doc);
    _listBuilder = ListBuilder(
      theme: theme,
      config: config,
      paragraphBuilder: _paragraphBuilder,
      docxTheme: doc.theme,
      numberLabels: numberLabels,
    );
    _imageBuilder = ImageBuilder(config: config);
    _shapeBuilder = ShapeBuilder(
      config: config,
      docxTheme: doc.theme,
      // Re-enter block generation so a text box renders its real paragraphs
      // (Plan §H) instead of a single flat string.
      textBlockBuilder: (blocks) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: _generateBlockWidgets(blocks),
      ),
    );
    // Route the paragraph builder's in-flow shapes through the shared
    // ShapeBuilder too, so an inline/side text box renders its content (§H).
    _paragraphBuilder.shapeBuilder = _shapeBuilder;
    _tableBuilder = TableBuilder(
      theme: theme,
      config: config,
      paragraphBuilder: _paragraphBuilder,
      listBuilder: _listBuilder,
      imageBuilder: _imageBuilder,
      shapeBuilder: _shapeBuilder,
      docxTheme: doc.theme,
    );
  }

  /// Original continuous generation logic
  List<Widget> _generateContinuousWidgets(DocxBuiltDocument doc) {
    final widgets = <Widget>[];
    final counter = BlockIndexCounter();

    // 1. Header
    // We must pass the counter to align indices with extraction
    if (doc.section?.header != null) {
      widgets.addAll(_generateBlockWidgets(doc.section!.header!.children,
          counter: counter));
      widgets.add(const Divider(height: 32, thickness: 1, color: Colors.grey));
    }

    // 2. Body
    _lastCounter = counter;
    widgets.addAll(_generateBlockWidgets(doc.elements, counter: counter));

    // 3. Footnotes
    if (doc.footnotes != null && doc.footnotes!.isNotEmpty) {
      widgets.add(const Divider(height: 32, thickness: 1));
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text('Footnotes',
            style: theme.defaultTextStyle
                .copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
      ));

      for (var footnote in doc.footnotes!) {
        widgets.add(_buildNoteWidget(footnote.footnoteId, footnote.content));
      }
    }

    // 4. Endnotes
    if (doc.endnotes != null && doc.endnotes!.isNotEmpty) {
      widgets.add(const Divider(height: 32, thickness: 1));
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text('Endnotes',
            style: theme.defaultTextStyle
                .copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
      ));

      for (var endnote in doc.endnotes!) {
        widgets.add(_buildNoteWidget(endnote.endnoteId, endnote.content));
      }
    }

    // 5. Footer
    if (doc.section?.footer != null) {
      widgets.add(const Divider(height: 32, thickness: 1, color: Colors.grey));
      widgets.addAll(_generateBlockWidgets(doc.section!.footer!.children,
          counter: counter));
    }

    return widgets;
  }

  /// Generate one page widget per [PageModel] using the measurement-based
  /// [Paginator] (Plan §D). Replaces the old `~8px/char` heuristic: page breaks,
  /// paragraph/table splitting, multi-section numbering and the bookmark map all
  /// come from the engine, so `PAGE`/`NUMPAGES`/`PAGEREF` and the page breaks
  /// match what Word produces.
  List<Widget> _generatePagedWidgets(DocxBuiltDocument doc) {
    // Lay the document out. The measurer's recycled TextPainter is only needed
    // during pagination — release it before rendering (which uses its own).
    final spanFactory = SpanFactory(
      theme: theme,
      config: config,
      docxTheme: doc.theme,
    );
    final measurer = TextMeasurer(spanFactory: spanFactory);
    final PaginationResult pagination;
    try {
      pagination = Paginator(measurer: measurer, config: config).paginate(doc);
    } finally {
      measurer.dispose(); // release the recycled TextPainter even on error
    }
    return _renderPages(doc, pagination);
  }

  /// Time-sliced variant of [_generatePagedWidgets] (Plan §4.4): the heavy
  /// measurement phase yields the UI thread periodically so a large document
  /// loads without freezing the frame.
  Future<List<Widget>> _generatePagedWidgetsAsync(DocxBuiltDocument doc) async {
    final spanFactory = SpanFactory(
      theme: theme,
      config: config,
      docxTheme: doc.theme,
    );
    final measurer = TextMeasurer(spanFactory: spanFactory);
    final PaginationResult pagination;
    try {
      pagination = await Paginator(measurer: measurer, config: config)
          .paginateAsync(doc);
    } finally {
      measurer.dispose(); // release the recycled TextPainter even on error
    }
    return _renderPages(doc, pagination);
  }

  /// Paginates [doc] time-sliced (Plan §4.4), invoking [onPage] as each page is
  /// laid out so the host can render pages as they are born (streaming display,
  /// §D.2.9) instead of blocking until the whole document is paginated. Only the
  /// *measurement* runs here; page widgets are built lazily by the host through
  /// [buildPageWidget], so a 200-page document keeps its pagination slices light
  /// (no eager widget tree per page).
  ///
  /// The returned [PaginationResult] carries the final bookmark/footnote maps and
  /// page count, and is stored as [lastPagination] so [extractTextForSearch]
  /// lines up with the rendered slice order afterwards.
  Future<PaginationResult> paginateStreaming(
    DocxBuiltDocument doc, {
    required void Function(PageModel page) onPage,
    bool Function()? shouldContinue,
  }) async {
    _initBuilders(doc);
    // The recycled TextPainter is only needed during measurement; release it
    // once pagination ends (the per-page renderers use their own).
    final spanFactory = SpanFactory(
      theme: theme,
      config: config,
      docxTheme: doc.theme,
    );
    final measurer = TextMeasurer(spanFactory: spanFactory);
    final PaginationResult pagination;
    try {
      pagination = await Paginator(measurer: measurer, config: config)
          .paginateAsync(doc, onPage: onPage, shouldContinue: shouldContinue);
    } finally {
      measurer.dispose(); // release the recycled TextPainter even on error
    }
    _lastPagination = pagination;
    return pagination;
  }

  /// Builds the widget for a single already-measured [PageModel]. The streaming
  /// host calls this lazily from its `ListView.builder` (Plan §D.3) so only
  /// visible pages are ever built.
  ///
  /// No search keys are attached: during the initial streaming load there are no
  /// matches yet, and search navigation later uses the keyed eager list from
  /// [rerenderWidgets]/[_renderPages]. While pagination is still running pass
  /// [finalResult] = null — the header/footer `NUMPAGES`/`SECTIONPAGES`/`PAGEREF`
  /// fields then resolve against provisional running totals from [pages] and
  /// settle to their final values once [finalResult] is supplied.
  Widget buildPageWidget(
    DocxBuiltDocument doc,
    List<PageModel> pages,
    int index, {
    PaginationResult? finalResult,
  }) {
    _initBuilders(doc);
    final page = pages[index];
    final totalPages = finalResult?.pageCount ?? pages.length;
    final bookmarkPages = finalResult?.bookmarkPages ?? const <String, int>{};
    // SECTIONPAGES uses one definition of "pages per section" (shared with the
    // eager path). When done it is memoized; while streaming it is recomputed
    // from the pages seen so far (cheap, and the counts are provisional anyway).
    final counts = finalResult != null
        ? (_finalSectionCounts ??= _sectionPageCounts(finalResult.pages))
        : _sectionPageCounts(pages);
    final sectionPages = counts[page.sectionIndex] ?? totalPages;
    return _buildPageFromModel(
      doc,
      page,
      totalPages: totalPages,
      sectionPages: sectionPages,
      bookmarkPages: bookmarkPages,
    );
  }

  /// Memoized `sectionIndex → page count` for the *final* pagination (cleared
  /// when [_initBuilders] switches documents), so lazy per-page builds do not
  /// re-scan every page each frame.
  Map<int, int>? _finalSectionCounts;

  /// The page width a rendered page occupies (`w:pgSz`, or the config override),
  /// used to size streaming placeholders to match real pages.
  double pageDisplayWidth([DocxSectionDef? section]) =>
      config.pageWidth ??
      (section != null
          ? DocxUnits.twipsToPixels(section.effectiveWidth)
          : 794.0);

  /// The page height a rendered page occupies (`w:pgSz`, or the config
  /// override), used to size streaming placeholders so the scrollbar stays
  /// stable while later pages are still being laid out (Plan §4.4).
  double pageDisplayHeight([DocxSectionDef? section]) =>
      config.pageHeight ??
      (section != null
          ? DocxUnits.twipsToPixels(section.effectiveHeight)
          : pageDisplayWidth(section) * 1.414);

  /// The transparent margin band drawn around every paged page (the visual gap
  /// between pages plus room for the drop shadow). Applied symmetrically by
  /// [_buildPageContainer]; the fit-to-width wrapper must account for it so the
  /// whole page footprint scales uniformly and a fitting page shows at 100%.
  static const double pageOuterMargin = 16.0;

  /// Full width a page widget occupies including [pageOuterMargin] on both
  /// sides — the natural footprint the fit-to-width slot scales/contains.
  double pageSlotWidth([DocxSectionDef? section]) =>
      pageDisplayWidth(section) + pageOuterMargin * 2;

  /// Full height a page widget occupies including [pageOuterMargin] on top and
  /// bottom.
  double pageSlotHeight([DocxSectionDef? section]) =>
      pageDisplayHeight(section) + pageOuterMargin * 2;

  /// Builds one page widget per [PaginationResult.pages] entry, wiring each
  /// page's [PageContext] (live `PAGE`/`NUMPAGES`/`SECTIONPAGES`/`PAGEREF`,
  /// even/odd and title-page chrome, per-section geometry). Shared by the sync
  /// and async paths.
  List<Widget> _renderPages(
      DocxBuiltDocument doc, PaginationResult pagination) {
    _lastPagination = pagination;

    // One counter shared across all pages' body widgets so search keys stay in
    // document order; extractTextForSearch walks the same slice order.
    final counter = BlockIndexCounter();
    _lastCounter = counter;

    // The document's first-page header (title-page variant) is pre-built with
    // the shared counter so its search keys come first (matching the search
    // index). Other pages rebuild their header inside _buildPageContainer.
    List<Widget>? firstPageHeaderWidgets;
    final firstHeader = doc.section?.headerFor(isFirstPage: true);
    if (firstHeader != null) {
      firstPageHeaderWidgets =
          _generateBlockWidgets(firstHeader.children, counter: counter);
    }

    // SECTIONPAGES: pages per section index.
    final sectionPageCounts = _sectionPageCounts(pagination.pages);

    final widgets = <Widget>[];
    for (final page in pagination.pages) {
      widgets.add(_buildPageFromModel(
        doc,
        page,
        totalPages: pagination.pageCount,
        sectionPages:
            sectionPageCounts[page.sectionIndex] ?? pagination.pageCount,
        bookmarkPages: pagination.bookmarkPages,
        counter: counter,
        firstPageHeaderWidgets:
            page.absoluteIndex == 0 ? firstPageHeaderWidgets : null,
      ));
    }
    return widgets;
  }

  /// Maps `sectionIndex → page count` for `SECTIONPAGES`.
  Map<int, int> _sectionPageCounts(List<PageModel> pages) {
    final counts = <int, int>{};
    for (final page in pages) {
      counts.update(page.sectionIndex, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// Builds the page chrome + body for one [page]. The single source of page
  /// rendering, shared by the eager [_renderPages] list and the lazy streaming
  /// [buildPageWidget] (so there is no second rendering path, §2.4.6).
  Widget _buildPageFromModel(
    DocxBuiltDocument doc,
    PageModel page, {
    required int totalPages,
    required int sectionPages,
    required Map<String, int> bookmarkPages,
    BlockIndexCounter? counter,
    List<Widget>? firstPageHeaderWidgets,
  }) {
    // Footnote/endnote reference marks render the number the paginator computed
    // (format + restart, Plan §J.4), not the raw id. A footnote's reference and
    // its note are always on the same page, so the page's own notes resolve the
    // body marks; endnote marks resolve against the document-wide map. Set before
    // building the body so the marks pick the labels up.
    _paragraphBuilder.footnoteLabels = {
      for (final fn in page.footnotes) fn.id: fn.label
    };
    _paragraphBuilder.endnoteLabels =
        _lastPagination?.endnoteLabels ?? const {};

    final sliceBlocks = [for (final s in page.slices) s.block];
    // Floats rendered as a positioned layer (Plan §H.2 step 4): topAndBottom +
    // front (wrapNone/inFront). Side floats stay on the in-flow Row path and
    // behindText stays on the page-background path, so neither is layered here.
    final layerFloats = [
      for (final pf in page.floats)
        if (_isLayerFloat(pf.drawing)) pf
    ];
    final stripSet = <DocxInline>{for (final pf in layerFloats) pf.drawing};
    final backgroundImages = _collectBehindTextImages(sliceBlocks);

    // Multi-column layout (Plan §I): if the page's section defines >1 column,
    // group slices by column index and render them side-by-side.
    final colDef = page.section.columns;
    final isMultiCol =
        colDef != null && colDef.count > 1 && page.slices.isNotEmpty;

    final List<Widget> singleColContent;
    final Widget? multiColBody;
    if (isMultiCol) {
      singleColContent = const [];
      multiColBody = _buildMultiColumnBody(
        page.slices,
        stripSet,
        colDef,
        page.geometry,
        page.section.isRtlSection,
        // The column region is the body height minus the footnote band — the
        // same area the body `Positioned` occupies — so the `w:sep` rule spans
        // the full column height the way Word draws it.
        columnHeight: page.geometry.bodyHeight - page.footnotesHeight,
        counter: counter,
      );
    } else {
      final bodyBlocks = _stripFloats(sliceBlocks, stripSet);
      singleColContent = _generateBlockWidgets(bodyBlocks, counter: counter);
      multiColBody = null;
    }

    final pageContext = PageContext(
      pageNumber: page.pageNumber,
      totalPages: totalPages,
      sectionPages: sectionPages,
      sectionFormat: page.section.pageNumberFormat,
      bookmarkPages: bookmarkPages,
    );

    return _buildPageContainer(
      singleColContent,
      doc,
      geometry: page.geometry,
      sectionOverride: page.section,
      headerWidgets: firstPageHeaderWidgets,
      isFirstPage: page.isFirstPageOfSection,
      isEvenPage: doc.evenAndOddHeaders && page.isEvenPage,
      pageContext: pageContext,
      backgroundImages: backgroundImages,
      floats: layerFloats,
      footnotes: page.footnotes,
      footnotesHeight: page.footnotesHeight,
      bodyChild: multiColBody,
    );
  }

  /// Builds the footnote area drawn at the foot of the body region (Plan §J): a
  /// short separator line followed by each note, its computed number as a leading
  /// superscript. Returns null when the page has no footnotes. Laid out at the
  /// page content width — the same width the paginator measured the notes at, so
  /// the reserved band matches the painted height.
  Widget? _buildFootnoteArea(List<PlacedFootnote> footnotes, bool rtl) {
    if (footnotes.isEmpty) return null;
    final align = rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Word's default footnote separator: a short rule (~⅓ width) above the
        // notes, on the leading edge. A custom separator from footnotes.xml is a
        // future refinement (§8.2) — the reader drops the separator note's type.
        Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 5),
          child: Align(
            alignment: rtl ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              // Derive the rule colour from the body text colour so it stays
              // visible on a dark theme instead of a fixed grey.
              child: Container(
                height: 1,
                color: (theme.defaultTextStyle.color ?? Colors.grey.shade600)
                    .withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
        for (final fn in footnotes) _buildFootnoteEntry(fn, rtl: rtl),
      ],
    );
  }

  /// One footnote at the page foot: the note's content with its number prepended
  /// as a superscript to the first paragraph (so the text indents past the mark
  /// the way Word renders it). Non-paragraph first blocks get the number on a
  /// short leading line instead. [rtl] aligns the note column to the leading edge
  /// for Hebrew/RTL notes (otherwise the content would hug the left).
  Widget _buildFootnoteEntry(PlacedFootnote fn, {required bool rtl}) {
    final content = fn.content;
    final List<DocxNode> display;
    if (content.isNotEmpty && content.first is DocxParagraph) {
      final first = content.first as DocxParagraph;
      display = [
        first.copyWith(children: [
          DocxText('${fn.label} ', isSuperscript: true),
          ...first.children,
        ]),
        ...content.skip(1),
      ];
    } else {
      display = [
        DocxParagraph(
            children: [DocxText('${fn.label} ', isSuperscript: true)]),
        ...content,
      ];
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment:
            rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: _generateBlockWidgets(display),
      ),
    );
  }

  /// A float drawn as a positioned layer (not in flow, not page background):
  /// `topAndBottom` (space reserved by the paginator) and the front modes
  /// (`wrapNone`/`inFront`). Side floats (square/tight, left/right) remain on the
  /// in-flow Row path; `behindText` is the page background — neither is layered.
  bool _isLayerFloat(DocxInline d) {
    final wrap = _wrapOf(d);
    return wrap == DocxTextWrap.topAndBottom ||
        wrap == DocxTextWrap.none ||
        wrap == DocxTextWrap.inFrontOfText;
  }

  DocxTextWrap _wrapOf(DocxInline d) {
    if (d is DocxInlineImage) return d.textWrap;
    if (d is DocxShape) {
      return d.behindDocument ? DocxTextWrap.behindText : d.textWrap;
    }
    return DocxTextWrap.none;
  }

  /// Returns [blocks] with every inline in [strip] removed from its paragraph,
  /// sharing all surviving children by reference (§2.4). Used to keep layered
  /// floats out of the in-flow body so they are not also rendered there.
  List<DocxNode> _stripFloats(List<DocxNode> blocks, Set<DocxInline> strip) {
    if (strip.isEmpty) return blocks;
    final out = <DocxNode>[];
    for (final b in blocks) {
      if (b is DocxParagraph && b.children.any(strip.contains)) {
        out.add(b.copyWith(
          children: [
            for (final c in b.children)
              if (!strip.contains(c)) c
          ],
        ));
      } else {
        out.add(b);
      }
    }
    return out;
  }

  /// Builds the widget for a layered float, sized to its resolved rectangle
  /// ([FloatRect] is in display px; the drawing builders work in points, so the
  /// `FittedBox` scales the drawing to fill the rect — keeping geometry ≡ render).
  ///
  /// Limitation (§8.2): the rect is the drawing's *unrotated* extent. A float
  /// rotated by a non-180° angle has a different axis-aligned bounding box, so
  /// the in-builder `Transform.rotate` (paint-only) can overflow/under-fill the
  /// box — a minor distortion for the rare rotated float. Left as-is until a
  /// rotated-extent fixture is available to verify against Word.
  Widget _buildFloatDrawing(DocxInline drawing, FloatRect rect) {
    Widget inner;
    if (drawing is DocxInlineImage) {
      inner = _imageBuilder.buildInlineImage(drawing);
    } else if (drawing is DocxShape) {
      inner = _shapeBuilder.buildInlineShape(drawing);
    } else {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: rect.width,
      height: rect.height,
      child: FittedBox(fit: BoxFit.fill, child: inner),
    );
  }

  /// אוסף תמונות "מאחורי הטקסט" (behindDoc) מתוך רצף בלוקים — מרונדרות
  /// כשכבת רקע ברמת העמוד (Stack), לא כ-float בצד. כך הטקסט מופיע *בתוך*
  /// המסגרת/רקע במקום מתחתיה.
  List<DocxInlineImage> _collectBehindTextImages(List<DocxNode> elements) {
    final result = <DocxInlineImage>[];
    for (final el in elements) {
      if (el is DocxParagraph) {
        for (final child in el.children) {
          if (child is DocxInlineImage &&
              child.textWrap == DocxTextWrap.behindText) {
            result.add(child);
          }
        }
      }
    }
    return result;
  }

  Widget _buildNoteWidget(int id, List<DocxNode> content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$id. ',
              style: theme.defaultTextStyle
                  .copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _generateBlockWidgets(content),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContainer(List<Widget> content, DocxBuiltDocument doc,
      {required PageGeometry geometry,
      List<Widget>? headerWidgets,
      bool isFirstPage = false,
      PageContext? pageContext,
      bool isEvenPage = false,
      DocxSectionDef? sectionOverride,
      List<DocxInlineImage> backgroundImages = const [],
      List<PlacedFloat> floats = const [],
      List<PlacedFootnote> footnotes = const [],
      double footnotesHeight = 0,
      Widget? bodyChild}) {
    // The page's own section (multi-section docs); falls back to the document
    // default. Drives geometry and header/footer variant selection.
    final section = sectionOverride ?? doc.section;
    // Variant selection: a section's first page uses the title-page header/footer
    // when w:titlePg is set; the even-page variant applies when the document's
    // evenAndOddHeaders setting is on and this page number is even.
    final activeHeader =
        section?.headerFor(isFirstPage: isFirstPage, isEvenPage: isEvenPage);
    final activeFooter =
        section?.footerFor(isFirstPage: isFirstPage, isEvenPage: isEvenPage);

    // Resolve PAGE/NUMPAGES/PAGEREF fields to this page's concrete values.
    List<DocxBlock> resolve(List<DocxBlock> blocks) => pageContext == null
        ? blocks
        : FieldSubstitution.apply(blocks, pageContext);

    // כותרת עליונה — נאספת בנפרד כדי למקם אותה *באזור השוליים העליונים*
    // (במרחק w:header מהקצה), ולא בתוך הגוף שדוחף את הטקסט מטה.
    // הערה: בעמוד הראשון משתמשים ב-headerWidgets שנבנו מראש (ערך-מטמון); החלפת
    // שדה חיה בכותרת עליונה של עמוד 1 תיכנס עם רפקטור העימוד (M4).
    final List<Widget> headerCol = [];
    if (activeHeader != null) {
      headerCol.addAll(headerWidgets ??
          _generateBlockWidgets(resolve(activeHeader.children)));
    }

    // כותרת תחתונה — באזור השוליים התחתונים (במרחק w:footer מהקצה). אין מזריקים
    // Divider מלאכותי: וורד אינו מוסיף קו כזה, והפוטר עצמו נושא את הגבול שלו
    // (w:pBdr) כשהוגדר. ה-Divider הקודם ניפח את גובה הפוטר עד שדרס את השורה
    // האחרונה של הגוף ("הטקסט מסתתר מתחת לפוטר").
    final List<Widget> footerCol = [];
    if (activeFooter != null) {
      footerCol.addAll(_generateBlockWidgets(resolve(activeFooter.children)));
    }

    // מידות העמוד והשוליים — מתוך [PageGeometry] שחושב פעם אחת ב-Paginator
    // (מקור-אמת יחיד), כך שאזור-הצביעה זהה בדיוק לאזור-האריזה.
    final pageWidth = geometry.pageWidth;
    final pageHeight = geometry.pageHeight;
    final padLeft = geometry.padLeft; // כולל gutter
    final padRight = geometry.padRight;
    final padTop = geometry.padTop; // שוליים גולמיים — למיקום גבולות-עמוד
    final padBottom = geometry.padBottom;
    // אזור-הגוף שמור מפני הכותרות: max(שוליים, מרחק-כותרת + גובה-כותרת), כך
    // שכותרת/פוטר גבוהים דוחפים את הגוף פנימה במקום לדרוס אותו (כמו Word).
    final bodyTop = geometry.bodyTop;
    final bodyBottom = geometry.bodyBottom;
    // מרחקי הכותרות מקצה העמוד — מציבים אותן *באזור השוליים*, לא בגוף.
    final headerDist = geometry.headerDist;
    final footerDist = geometry.footerDist;

    // Page background (`w:background`/section): a section background colour fills
    // the paper, drawn under behindDoc images and the body (Plan §E.1.1 layer 1).
    final paperColor = theme.backgroundColor ?? Colors.white;
    final sectionBg = section?.backgroundColor == null
        ? null
        : resolveDocxColor(section!.backgroundColor!, paperColor);

    // Page borders (`w:pgBorders`, §E.1.4): gated by display (all/first/notFirst).
    final pageBorders = section?.pageBorders;
    final drawBorder = pageBorders != null &&
        pageBorders.hasAnySide &&
        switch (pageBorders.display) {
          DocxPageBorderDisplay.allPages => true,
          DocxPageBorderDisplay.firstPage => isFirstPage,
          DocxPageBorderDisplay.notFirstPage => !isFirstPage,
        };

    // Vertical alignment of the body within the fixed content region (`w:vAlign`,
    // §E.1.3). PageBody lays the body out at natural height, aligns it, clips
    // overflow, and warns in debug if it exceeds the region. `both` justifies
    // (space between blocks) only when the content fits.
    final vAlign = section?.vAlign ?? DocxSectionVAlign.top;
    final bool stretch = vAlign == DocxSectionVAlign.both;
    final Alignment bodyAlignment = switch (vAlign) {
      DocxSectionVAlign.center => Alignment.center,
      DocxSectionVAlign.bottom => Alignment.bottomCenter,
      DocxSectionVAlign.top || DocxSectionVAlign.both => Alignment.topCenter,
    };
    final Widget bodyRegion = PageBody(
      alignment: bodyAlignment,
      stretch: stretch,
      // Multi-column (Plan §I): [bodyChild] is a Row of columns built by
      // [_buildMultiColumnBody]; single-column falls back to the standard
      // Column of block widgets.
      child: bodyChild ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: stretch
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
            children: content,
          ),
    );

    // Footnote area (Plan §J): the paginator reserved [footnotesHeight] at the
    // bottom of the body region, so the body is inset by it and the notes are
    // painted in that band. RTL notes (Hebrew sacred texts) put the separator on
    // the right.
    final bool notesRtl = footnotes.isNotEmpty &&
        (section?.isRtlSection == true ||
            (footnotes.first.content.isNotEmpty &&
                footnotes.first.content.first is DocxParagraph &&
                (footnotes.first.content.first as DocxParagraph).isRtl));
    final Widget? footnoteArea = _buildFootnoteArea(footnotes, notesRtl);

    return Container(
      width: pageWidth,
      // Fixed page height (Plan §D.2.6/§E.2): content is measured to fit, and any
      // small overshoot is clipped rather than stretching the page.
      height: pageHeight,
      margin: const EdgeInsets.all(pageOuterMargin),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: sectionBg ?? paperColor,
        // תמונת "מאחורי הטקסט" (behindDoc, למשל מסגרת/עיטור עמוד-שער) מצוירת
        // כרקע של העמוד כולו, מתחת לטקסט — כך הטקסט מופיע *בתוכה*.
        image: backgroundImages.isNotEmpty
            ? DecorationImage(
                image: MemoryImage(backgroundImages.first.bytes),
                fit: BoxFit.fill,
                // תמונת רקע פגומה לא תפיל את כל העמוד — נבלעת בשקט.
                onError: (_, __) {},
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      // Stack נאמן ל-Word: גוף בין השוליים (עם יישור אנכי), header/footer באזורי
      // השוליים, ומסגרת עמוד מעל (front, ברירת המחדל של Word).
      child: Stack(
        children: [
          Positioned(
            left: padLeft,
            top: bodyTop,
            right: padRight,
            // The footnote band is reserved at the bottom of the body region,
            // so the body content stops above it (Plan §J.2).
            bottom: bodyBottom + footnotesHeight,
            child: bodyRegion,
          ),
          if (footnoteArea != null)
            Positioned(
              left: padLeft,
              right: padRight,
              bottom: bodyBottom,
              height: footnotesHeight,
              child: footnoteArea,
            ),
          // Floating drawings layer (Plan §H.2): topAndBottom + front floats,
          // positioned in page coordinates from their body-relative rect, painted
          // over the body in z-order (`relativeHeight`).
          for (final pf
              in (floats.toList()
                ..sort((a, b) => a.rect.zOrder.compareTo(b.rect.zOrder))))
            Positioned(
              left: padLeft + pf.rect.left,
              top: bodyTop + pf.rect.top,
              width: pf.rect.width,
              height: pf.rect.height,
              child: _buildFloatDrawing(pf.drawing, pf.rect),
            ),
          if (headerCol.isNotEmpty)
            Positioned(
              top: headerDist,
              left: padLeft,
              right: padRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: headerCol,
              ),
            ),
          if (footerCol.isNotEmpty)
            Positioned(
              bottom: footerDist,
              left: padLeft,
              right: padRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: footerCol,
              ),
            ),
          if (drawBorder)
            Positioned.fill(
              child: CustomPaint(
                painter: PageBorderPainter(
                  borders: pageBorders,
                  padLeft: padLeft,
                  padTop: padTop,
                  padRight: padRight,
                  padBottom: padBottom,
                  defaultColor: theme.defaultTextStyle.color ?? Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the body widget for a multi-column page (Plan §I.4–5).
  ///
  /// Groups [slices] by their [BlockSlice.columnIndex], generates block widgets
  /// per column, and arranges them in a [Row]. A vertical separator line is
  /// drawn between columns when `w:sep` is set. For RTL sections (`w:bidi`)
  /// the visual order is reversed so column 0 (first content) appears on the
  /// right.
  Widget _buildMultiColumnBody(
    List<BlockSlice> slices,
    Set<DocxInline> stripSet,
    DocxColumns colDef,
    PageGeometry geometry,
    bool isRtl, {
    required double columnHeight,
    BlockIndexCounter? counter,
  }) {
    final colWidths = resolveColumnWidths(colDef, geometry.contentWidth);
    final gaps = resolveColumnGaps(colDef, colWidths.length);
    final n = colWidths.length;

    // Group slice blocks by column index.
    final colBlocks = List.generate(n, (_) => <DocxNode>[]);
    for (final slice in slices) {
      final ci = slice.columnIndex.clamp(0, n - 1);
      colBlocks[ci].add(slice.block);
    }

    // Build one Column widget per document column.
    final colWidgets = <Widget>[
      for (var i = 0; i < n; i++)
        SizedBox(
          width: colWidths[i],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: _generateBlockWidgets(
                _stripFloats(colBlocks[i], stripSet),
                counter: counter),
          ),
        ),
    ];

    // Interleave spacer / separator widgets between columns. The gap after
    // column i comes from [gaps] (per-column `w:space` in explicit layouts).
    final sepHeight = columnHeight.clamp(0.0, double.infinity);
    final rowChildren = <Widget>[];
    for (var i = 0; i < colWidgets.length; i++) {
      rowChildren.add(colWidgets[i]);
      if (i < colWidgets.length - 1) {
        final gapPx = gaps[i];
        if (colDef.separator) {
          // A 1px rule centred in the gap, given an explicit height so it spans
          // the column region (a Container with no child/height collapses to 0
          // inside a Row — the line would be invisible).
          rowChildren.add(SizedBox(
            width: gapPx,
            child: Center(
              child: Container(
                width: 1,
                height: sepHeight,
                color: (theme.defaultTextStyle.color ?? Colors.grey)
                    .withValues(alpha: 0.35),
              ),
            ),
          ));
        } else {
          rowChildren.add(SizedBox(width: gapPx));
        }
      }
    }

    // RTL section: first column (index 0) is on the right.
    final orderedChildren = isRtl ? rowChildren.reversed.toList() : rowChildren;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: orderedChildren,
    );
  }

  /// Generate widgets for a list of blocks.
  List<Widget> _generateBlockWidgets(List<DocxNode> elements,
      {BlockIndexCounter? counter}) {
    final widgets = <Widget>[];
    int i = 0;

    while (i < elements.length) {
      final element = elements[i];

      // Check for floating table
      if (element is DocxTable && element.position != null) {
        // This is a floating table - group with following paragraphs
        final floatingTable = element;
        final followingParagraphs = <DocxNode>[];

        // Collect paragraphs that should wrap around this table
        int j = i + 1;
        while (j < elements.length && followingParagraphs.length < 5) {
          final next = elements[j];
          if (next is DocxParagraph || next is DocxDropCap) {
            followingParagraphs.add(next);
            j++;
          } else {
            break; // Stop at non-paragraph block
          }
        }

        if (followingParagraphs.isNotEmpty) {
          // Build the floating Row layout
          final tableWidget =
              _tableBuilder.build(floatingTable, counter: counter);
          final paragraphWidgets = followingParagraphs.map((p) {
            if (p is DocxParagraph) {
              return _paragraphBuilder.build(p, counter: counter);
            } else if (p is DocxDropCap) {
              return _paragraphBuilder.buildDropCap(p);
            }
            return const SizedBox.shrink();
          }).toList();

          // Determine float side from table position
          final isRightFloat =
              floatingTable.position?.hAnchor == DocxTableHAnchor.margin &&
                  floatingTable.alignment == DocxAlign.right;

          Widget rowWidget;
          if (isRightFloat) {
            // Table on the right
            rowWidget = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 2,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: paragraphWidgets)),
                const SizedBox(width: 12),
                Flexible(flex: 1, child: tableWidget),
              ],
            );
          } else {
            // Table on the left (default)
            rowWidget = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(flex: 1, child: tableWidget),
                const SizedBox(width: 12),
                Expanded(
                    flex: 2,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: paragraphWidgets)),
              ],
            );
          }

          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: rowWidget,
          ));
          i = j; // Skip to after grouped paragraphs
          continue;
        }
      }

      // Paragraphs (with or without floats) fall through to standard
      // processing → the paragraph builder. Side floats wrap the text in-flow
      // via [FloatWrapText] (§8.2 #29); layer / full-width floats are drawn by
      // the page float layer (paged) or the page background. The old block-level
      // float-grouping Row (getFloatsFromParagraph) was removed when real
      // band-aware wrapping landed.

      // Standard element processing
      final widget = generateWidget(element, counter: counter);
      if (widget != null) {
        widgets.add(widget);
      }
      i++;
    }

    return widgets;
  }

  /// Generate a single widget from a [DocxNode].
  Widget? generateWidget(DocxNode node, {BlockIndexCounter? counter}) {
    try {
      if (node is DocxParagraph) {
        return _paragraphBuilder.build(node, counter: counter);
      } else if (node is DocxTable) {
        return _tableBuilder.build(node, counter: counter);
      } else if (node is DocxList) {
        return _listBuilder.build(node, counter: counter);
      } else if (node is DocxImage) {
        return _imageBuilder.buildBlockImage(node);
      } else if (node is DocxShapeBlock) {
        return _shapeBuilder.buildBlockShape(node);
      } else if (node is DocxDropCap) {
        return _paragraphBuilder.buildDropCap(node);
      } else if (node is DocxSectionBreakBlock) {
        // Render section breaks as horizontal dividers
        return const Divider(height: 24, thickness: 1);
      } else if (node is DocxRawXml) {
        return config.showDebugInfo
            ? buildDebugPlaceholder('[Unsupported element]')
            : const SizedBox.shrink();
      }
    } catch (e, stack) {
      // Silent failure: return debug widget or empty space
      if (config.showDebugInfo) {
        return buildDebugPlaceholder('Error: $e\n$stack',
            color: Colors.red.shade100);
      }
      return const SizedBox.shrink();
    }
    return null;
  }

  Widget buildDebugPlaceholder(String message, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color ?? Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 10,
          fontFamily: 'Courier',
        ),
      ),
    );
  }

  /// Extract all text content for search indexing.
  List<String> extractTextForSearch(DocxBuiltDocument doc) {
    final texts = <String>[];
    final counter = BlockIndexCounter();

    // Header
    if (doc.section?.header != null) {
      _extractFromBlocks(doc.section!.header!.children, texts, counter);
    }

    // Body. In paged mode the rendered widgets come from the paginator's slices
    // (a split paragraph/table is two slices), so the search index must walk the
    // same slice order — otherwise the per-block keys would drift after a split.
    final pagination = _lastPagination;
    if (config.pageMode == DocxPageMode.paged && pagination != null) {
      final sliceBlocks = <DocxNode>[
        for (final page in pagination.pages)
          for (final slice in page.slices) slice.block,
      ];
      _extractFromBlocks(sliceBlocks, texts, counter);
    } else {
      _extractFromBlocks(doc.elements, texts, counter);
    }

    // Footer
    if (doc.section?.footer != null) {
      _extractFromBlocks(doc.section!.footer!.children, texts, counter);
    }

    return texts;
  }

  void _extractFromBlocks(
      List<DocxNode> nodes, List<String> texts, BlockIndexCounter counter) {
    for (final node in nodes) {
      if (node is DocxParagraph) {
        texts.add(_extractFromParagraph(node));
        counter.increment();
      } else if (node is DocxTable) {
        for (final row in node.rows) {
          for (final cell in row.cells) {
            _extractFromBlocks(cell.children, texts, counter);
          }
        }
      } else if (node is DocxList) {
        for (final item in node.items) {
          // List item behaves like a paragraph
          texts.add(_extractFromInlines(item.children));
          counter.increment();
        }
      } else if (node is DocxSectionBreakBlock) {
        // Ignored
      }
      // Other blocks
    }
  }

  String _extractFromParagraph(DocxParagraph paragraph) {
    return _extractFromInlines(paragraph.children);
  }

  String _extractFromInlines(List<DocxInline> inlines) {
    final buffer = StringBuffer();
    for (final inline in inlines) {
      if (inline is DocxText) {
        if (inline.hidden) continue; // w:vanish — not rendered, not searchable.
        buffer.write(inline.content);
      } else if (inline is DocxTab) {
        buffer.write('    ');
      } else if (inline is DocxLineBreak) {
        buffer.write('\n');
      } else if (inline is DocxCheckbox) {
        buffer.write(inline.isChecked ? '☒ ' : '☐ ');
      }
      // Ignore others
    }
    return buffer.toString();
  }
}
