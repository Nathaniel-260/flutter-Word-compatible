import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../docx_view_config.dart';
import '../layout/span_factory.dart';
import '../layout/text_measurer.dart';
import '../pagination/field_substitution.dart';
import '../pagination/page_context.dart';
import '../pagination/page_model.dart';
import '../pagination/paginator.dart';
import '../search/docx_search_controller.dart';
import '../theme/docx_view_theme.dart';
import '../utils/block_index_counter.dart';
import '../utils/docx_units.dart';
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
    _paragraphBuilder = ParagraphBuilder(
      theme: theme,
      config: config,
      searchController: searchController,
      onFootnoteTap: onFootnoteTap,
      onEndnoteTap: onEndnoteTap,
      docxTheme: doc.theme,
    );
    _listBuilder = ListBuilder(
      theme: theme,
      config: config,
      paragraphBuilder: _paragraphBuilder,
      docxTheme: doc.theme,
    );
    _imageBuilder = ImageBuilder(config: config);
    _shapeBuilder = ShapeBuilder(
      config: config,
      docxTheme: doc.theme,
    );
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
    final sliceBlocks = [for (final s in page.slices) s.block];
    final content = _generateBlockWidgets(sliceBlocks, counter: counter);
    final backgroundImages = _collectBehindTextImages(sliceBlocks);

    final pageContext = PageContext(
      pageNumber: page.pageNumber,
      totalPages: totalPages,
      sectionPages: sectionPages,
      sectionFormat: page.section.pageNumberFormat,
      bookmarkPages: bookmarkPages,
    );

    return _buildPageContainer(
      content,
      doc,
      sectionOverride: page.section,
      headerWidgets: firstPageHeaderWidgets,
      isFirstPage: page.isFirstPageOfSection,
      isEvenPage: doc.evenAndOddHeaders && page.isEvenPage,
      pageContext: pageContext,
      backgroundImages: backgroundImages,
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
      {List<Widget>? headerWidgets,
      bool isFirstPage = false,
      PageContext? pageContext,
      bool isEvenPage = false,
      DocxSectionDef? sectionOverride,
      List<DocxInlineImage> backgroundImages = const []}) {
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

    // כותרת תחתונה — באזור השוליים התחתונים (במרחק w:footer מהקצה).
    final List<Widget> footerCol = [];
    if (activeFooter != null) {
      footerCol.add(const Divider());
      footerCol.addAll(_generateBlockWidgets(resolve(activeFooter.children)));
    }

    // מידות העמוד מהמסמך (w:pgSz / w:pgMar), לא A4 קבוע.
    final pageWidth = config.pageWidth ??
        (section != null
            ? DocxUnits.twipsToPixels(section.effectiveWidth)
            : 794.0);
    final pageHeight = config.pageHeight ??
        (section != null
            ? DocxUnits.twipsToPixels(section.effectiveHeight)
            : pageWidth * 1.414);
    // gutter (מרווח כריכה) מתווסף לשוליים השמאליים (ברירת המחדל של Word).
    final gutter = DocxUnits.twipsToPixels(section?.gutter ?? 0);
    final padLeft =
        DocxUnits.twipsToPixels(section?.marginLeft ?? 1440) + gutter;
    final padRight = DocxUnits.twipsToPixels(section?.marginRight ?? 1440);
    final padTop = DocxUnits.twipsToPixels(section?.marginTop ?? 1440);
    final padBottom = DocxUnits.twipsToPixels(section?.marginBottom ?? 1440);
    // מרחקי הכותרות מקצה העמוד — מציבים אותן *באזור השוליים*, לא בגוף.
    final headerDist = DocxUnits.twipsToPixels(section?.marginHeader ?? 720);
    final footerDist = DocxUnits.twipsToPixels(section?.marginFooter ?? 720);

    return Container(
      width: pageWidth,
      constraints: BoxConstraints(minHeight: pageHeight),
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.backgroundColor ?? Colors.white,
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
      // Stack של 3 אזורים נאמן ל-Word: גוף בין השוליים, header באזור העליון,
      // footer באזור התחתון — כל אחד במרחק הנכון מקצה העמוד. ה-ConstrainedBox
      // על הגוף מבטיח שה-Stack בגובה העמוד (כך ה-Positioned bottom של ה-footer
      // יושב בתחתית העמוד גם כשהתוכן קצר), אך גמיש כלפי מעלה (לא חותך תוכן ארוך).
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: pageHeight),
            child: Padding(
              padding:
                  EdgeInsets.fromLTRB(padLeft, padTop, padRight, padBottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: content,
              ),
            ),
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
        ],
      ),
    );
  }

  /// Generate widgets for a list of blocks.
  List<Widget> _generateBlockWidgets(List<DocxNode> elements,
      {BlockIndexCounter? counter}) {
    final widgets = <Widget>[];
    int i = 0;

    // Track floats that have been "consumed" by a previous paragraph's grouping
    final consumedFloats = <DocxInline>{};

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

      // Handle Paragraphs with special float grouping logic
      if (element is DocxParagraph) {
        final (localLefts, localRights) = getFloatsFromParagraph(element);

        // Filter out floats we already handled in a previous group
        final activeLefts =
            localLefts.where((f) => !consumedFloats.contains(f)).toList();
        final activeRights =
            localRights.where((f) => !consumedFloats.contains(f)).toList();

        final extraRights = <DocxInline>[];

        // If we have unconsumed left floats, we are a potential anchor for a group
        // Look ahead for right floats in subsequent paragraphs
        if (activeLefts.isNotEmpty) {
          int j = i + 1;
          // Look ahead a few paragraphs
          while (j < elements.length && j < i + 5) {
            final next = elements[j];
            if (next is DocxParagraph) {
              final (nextLefts, nextRights) = getFloatsFromParagraph(next);

              // If next has valid lefts, it starts its own group - stop scanning
              if (nextLefts.any((f) => !consumedFloats.contains(f))) {
                break;
              }

              // Inspect next rights
              final nextActiveRights =
                  nextRights.where((f) => !consumedFloats.contains(f)).toList();

              if (nextActiveRights.isNotEmpty) {
                // Determine if we should group these rights with current lefts
                extraRights.addAll(nextActiveRights);
                consumedFloats.addAll(nextActiveRights);
              }
            } else {
              // Non-paragraph breaks the group visual flow
              break;
            }
            j++;
          }
        }

        final finalRights = [...activeRights, ...extraRights];

        // If we have active floats (either our own or adopted ones), render a Float Row
        if (activeLefts.isNotEmpty || finalRights.isNotEmpty) {
          // Mark our own floats as consumed
          consumedFloats.addAll(activeLefts);
          consumedFloats.addAll(activeRights);

          // Build the content WITHOUT the floats we are displaying here
          // We must exclude both activeLefts and activeRights from the content rendering
          final floatsToExclude = {...activeLefts, ...activeRights};

          final contentWidget = _paragraphBuilder
              .buildExcludingFloats(element, floatsToExclude, counter: counter);

          // Helper to build a column of floats
          List<Widget> buildFloatColumn(List<DocxInline> floats) {
            return floats.map((img) {
              Widget child;
              if (img is DocxInlineImage) {
                child = Image.memory(img.bytes,
                    width: img.width, height: img.height, fit: BoxFit.contain);
              } else if (img is DocxShape) {
                child = _shapeBuilder.buildInlineShape(img);
              } else {
                child = const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: child,
              );
            }).toList();
          }

          final rowWidget = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeLefts.isNotEmpty) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: buildFloatColumn(activeLefts),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: contentWidget),
              if (finalRights.isNotEmpty) ...[
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: buildFloatColumn(finalRights),
                ),
              ]
            ],
          );

          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: rowWidget,
          ));

          i++;
          continue;
        } else {
          // No active floats to render in the custom layout -- check for hidden consumed floats
          if (localLefts.any((f) => consumedFloats.contains(f)) ||
              localRights.any((f) => consumedFloats.contains(f))) {
            final floatsToExclude = {...localLefts, ...localRights}
                .where((f) => consumedFloats.contains(f))
                .toSet();

            widgets.add(_paragraphBuilder.buildExcludingFloats(
                element, floatsToExclude,
                counter: counter));

            i++;
            continue;
          }
        }
      }

      // Standard element processing
      final widget = generateWidget(element, counter: counter);
      if (widget != null) {
        widgets.add(widget);
      }
      i++;
    }

    return widgets;
  }

  /// Extract floating images from ANY paragraph, including those with text.
  /// Returns (leftFloats, rightFloats).
  (List<DocxInline>, List<DocxInline>) getFloatsFromParagraph(
      DocxParagraph paragraph) {
    final leftFloats = <DocxInline>[];
    final rightFloats = <DocxInline>[];

    for (final child in paragraph.children) {
      // תמונה/צורה "מאחורי הטקסט" (behindDoc) אינה float בצד — היא רקע של
      // העמוד (מסגרת/עיטור עמוד-שער). מדולגת כאן כדי שלא תרונדר כבלוק שדוחף
      // את הטקסט; היא נאספת בנפרד ומצוירת כרקע (ראו _collectBehindTextImages).
      //
      // הערה מכוונת: רקע-עמוד מוצג רק ב-DocxPageMode.paged, שם יש "מיכל עמוד"
      // (Stack) לשים מאחוריו את התמונה. במצב continuous (גלילה רציפה) הפלט הוא
      // רשימה שטוחה ללא גבולות עמוד, ולכן רקעי-עמוד *אינם* מוצגים — זהו מצב
      // reflow לקריאה, לא נאמנות-עמוד. אי-הצגה זו היא בחירת עיצוב, לא אובדן באג.
      if (child is DocxInlineImage &&
          child.textWrap == DocxTextWrap.behindText) {
        continue;
      }
      // צורה (DocxShape) "מאחורי הטקסט" מדולגת אף היא, אך כרגע **אינה** נאספת
      // לרקע (רק תמונות נאספות ב-_collectBehindTextImages) — צורות-רקע נעלמות.
      // edge case נדיר במסמכי קודש (רקע הוא כמעט תמיד תמונה); ליטוש עתידי.
      if (child is DocxShape && child.behindDocument) {
        continue;
      }
      if (child is DocxInlineImage &&
          child.positionMode == DocxDrawingPosition.floating) {
        if (child.hAlign == DrawingHAlign.right) {
          rightFloats.add(child);
        } else if (child.hAlign != DrawingHAlign.center) {
          leftFloats.add(child);
        }
      } else if (child is DocxShape &&
          child.position == DocxDrawingPosition.floating) {
        if (child.horizontalAlign == DrawingHAlign.right) {
          rightFloats.add(child);
        } else if (child.horizontalAlign != DrawingHAlign.center) {
          leftFloats.add(child);
        }
      }
    }

    return (leftFloats, rightFloats);
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
