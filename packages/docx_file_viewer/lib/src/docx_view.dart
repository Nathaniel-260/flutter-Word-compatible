import 'dart:io';
import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import 'docx_view_config.dart';
import 'font_loader/embedded_font_loader.dart';
import 'font_loader/system_font_metrics_io.dart'
    if (dart.library.js_interop) 'font_loader/system_font_metrics_web.dart';
import 'pagination/page_model.dart';
import 'search/docx_search_controller.dart';
import 'utils/page_fit.dart';
import 'theme/docx_view_theme.dart';
import 'widget_generator/docx_widget_generator.dart';

/// A Flutter widget for viewing DOCX files.
///
/// Renders Word documents using native Flutter widgets for best performance.
///
/// ## Example
/// ```dart
/// DocxView(
///   file: myDocxFile,
///   config: DocxViewConfig(
///     enableSearch: true,
///     enableZoom: true,
///   ),
/// )
/// ```
class DocxView extends StatefulWidget {
  /// The DOCX file to display. Provide one of: [file], [bytes], or [path].
  final File? file;

  /// Raw DOCX bytes to display.
  final Uint8List? bytes;

  /// Path to a DOCX file.
  final String? path;

  /// Configuration for the viewer.
  final DocxViewConfig config;

  /// Optional search controller for external control.
  final DocxSearchController? searchController;

  /// Callback when document loading completes.
  final VoidCallback? onLoaded;

  /// Callback when document loading fails.
  final void Function(Object error)? onError;

  const DocxView({
    super.key,
    this.file,
    this.bytes,
    this.path,
    this.config = const DocxViewConfig(),
    this.searchController,
    this.onLoaded,
    this.onError,
  }) : assert(
          file != null || bytes != null || path != null,
          'Must provide either file, bytes, or path',
        );

  /// Create from file.
  factory DocxView.file(
    File file, {
    Key? key,
    DocxViewConfig config = const DocxViewConfig(),
    DocxSearchController? searchController,
  }) {
    return DocxView(
      key: key,
      file: file,
      config: config,
      searchController: searchController,
    );
  }

  /// Create from bytes.
  factory DocxView.bytes(
    Uint8List bytes, {
    Key? key,
    DocxViewConfig config = const DocxViewConfig(),
    DocxSearchController? searchController,
  }) {
    return DocxView(
      key: key,
      bytes: bytes,
      config: config,
      searchController: searchController,
    );
  }

  /// Create from path.
  factory DocxView.path(
    String path, {
    Key? key,
    DocxViewConfig config = const DocxViewConfig(),
    DocxSearchController? searchController,
  }) {
    return DocxView(
      key: key,
      path: path,
      config: config,
      searchController: searchController,
    );
  }

  @override
  State<DocxView> createState() => _DocxViewState();
}

class _DocxViewState extends State<DocxView> {
  /// Eager widget list. Used by continuous mode, and by paged mode only once a
  /// search builds the keyed list for highlight/navigation. Null in paged mode
  /// during the streaming load.
  List<Widget>? _widgets;
  DocxBuiltDocument? _doc; // Store for re-rendering on search

  /// Pages produced so far in paged mode (grows as pagination streams them in,
  /// Plan §D.2.9). Page widgets are built lazily from these.
  List<PageModel> _pages = [];

  /// The completed pagination (null until paginating finishes); supplies the
  /// final `NUMPAGES`/`SECTIONPAGES`/`PAGEREF` values once known.
  PaginationResult? _pagination;

  /// True while paged pagination is still streaming pages in (drives the
  /// placeholder tail).
  bool _paginating = false;

  bool _isLoading = true;
  Object? _error;

  /// Incremented on every [_loadDocument] so a stale streaming pagination (from
  /// a superseded load) cannot mutate the current page list or call setState.
  int _loadGeneration = 0;

  late DocxSearchController _searchController;
  late DocxWidgetGenerator _generator;

  @override
  void initState() {
    super.initState();
    _searchController = widget.searchController ?? DocxSearchController();
    _searchController.addListener(_onSearchChanged);
    _loadDocument();
  }

  @override
  void dispose() {
    if (widget.searchController == null) {
      _searchController.dispose();
    } else {
      _searchController.removeListener(_onSearchChanged);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(DocxView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file != widget.file ||
        oldWidget.bytes != widget.bytes ||
        oldWidget.path != widget.path) {
      _loadDocument();
    }
  }

  Future<void> _loadDocument() async {
    final int myGen = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _error = null;
      _widgets = null;
      _pages = <PageModel>[];
      _pagination = null;
      _paginating = false;
    });

    try {
      Uint8List bytes;
      if (widget.bytes != null) {
        bytes = widget.bytes!;
      } else if (widget.file != null) {
        bytes = await widget.file!.readAsBytes();
      } else if (widget.path != null) {
        bytes = await File(widget.path!).readAsBytes();
      } else {
        throw ArgumentError('No document source provided');
      }

      // Load document using docx_creator
      final doc = await DocxReader.loadFromBytes(bytes);

      for (final font in doc.fonts) {
        await EmbeddedFontLoader.loadFont(
          font.familyName,
          font.bytes,
          obfuscationKey: font.obfuscationKey,
        );
      }

      // Record real line metrics for the *system* fonts this document uses
      // (Arial/David/… are not embedded), so single-spaced text lays out at
      // Word's per-font line height. Best-effort + desktop-only (web no-ops);
      // embedded fonts were already registered above from their bytes.
      final families = collectDocumentFontFamilies(doc,
          extra: widget.config.customFontFallbacks);
      await registerSystemFonts(families);

      // Pre-process notes for quick lookup
      final footnoteMap = {for (var f in doc.footnotes ?? []) f.footnoteId: f};
      final endnoteMap = {for (var e in doc.endnotes ?? []) e.endnoteId: e};

      // Initialize widget generator
      _generator = DocxWidgetGenerator(
        config: widget.config,
        theme: widget.config.theme,
        docxTheme: doc.theme,
        searchController: widget.config.enableSearch ? _searchController : null,
        onFootnoteTap: (id) =>
            _showNoteContent('Footnote', footnoteMap[id]?.content),
        onEndnoteTap: (id) =>
            _showNoteContent('Endnote', endnoteMap[id]?.content),
      );

      if (widget.config.pageMode == DocxPageMode.paged) {
        // Streaming paged load (Plan §D.2.9 / §4.4): display pages as the
        // paginator lays them out, with a placeholder tail for pages not yet
        // measured, so the first page shows well before the full document is
        // paginated and the scrollbar stays stable.
        _doc = doc;
        _pages = <PageModel>[];
        setState(() {
          _isLoading = false;
          _paginating = true;
        });

        // Display each page on the UI thread as it is laid out. Several pages
        // can arrive before a frame draws; setState coalesces the rebuilds, so
        // the lazy ListView.builder repaints once per frame.
        final pagination = await _generator.paginateStreaming(
          doc,
          onPage: (page) {
            if (!mounted || myGen != _loadGeneration) return;
            _pages.add(page);
            setState(() {});
          },
          // Abandon this pagination if a newer load supersedes it, instead of
          // running it to completion on the UI thread (wasted work exactly when
          // the user wants responsiveness).
          shouldContinue: () => mounted && myGen == _loadGeneration,
        );
        if (!mounted || myGen != _loadGeneration) return;

        // Pagination finished: build the slice-aligned search index and settle
        // the page fields to their final NUMPAGES/SECTIONPAGES/PAGEREF values.
        // setDocument clears any query the user typed mid-stream, so capture and
        // replay it now that the index and navigation keys exist.
        final pendingQuery = _searchController.query;
        _searchController.setDocument(_generator.extractTextForSearch(doc));
        setState(() {
          _pagination = pagination;
          _pages = pagination.pages;
          _paginating = false;
        });
        if (pendingQuery.isNotEmpty) _searchController.search(pendingQuery);
        widget.onLoaded?.call();
      } else {
        // Continuous mode: build everything up front (already cheap).
        final widgets = await _generator.generateWidgetsAsync(doc);
        if (!mounted || myGen != _loadGeneration) return;
        _searchController.setDocument(_generator.extractTextForSearch(doc));
        setState(() {
          _doc = doc;
          _widgets = widgets;
          _isLoading = false;
        });
        widget.onLoaded?.call();
      }
    } catch (e) {
      if (!mounted || myGen != _loadGeneration) return;
      setState(() {
        _error = e;
        _isLoading = false;
        _paginating = false;
      });
      widget.onError?.call(e);
    }
  }

  /// A full page-height loading affordance at the *tail* of the paged list
  /// while later pages are still being laid out (Plan §4.4). It marks one page
  /// of pending content; the content region grows as real pages stream in ahead
  /// of it. (A per-remaining-page estimate to fully fix the scroll extent is a
  /// follow-up — it needs a reliable page-count estimate before pagination ends,
  /// and the placeholder's fixed height (vs a page's flexible `minHeight`) would
  /// otherwise accumulate drift.)
  Widget _buildPagePlaceholder() {
    final theme = widget.config.theme ?? DocxViewTheme.light();
    final section = _doc?.section;
    return Container(
      width: _generator.pageDisplayWidth(section),
      height: _generator.pageDisplayHeight(section),
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: (theme.backgroundColor ?? Colors.white).withValues(alpha: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  /// Tail notice shown when pagination stopped at the page cap (a pathological
  /// or hostile document); see [PaginationResult.truncated].
  Widget _buildTruncationNotice() {
    final shown = _pages.length;
    return Container(
      width: _generator.pageDisplayWidth(_doc?.section),
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'This document is very large; showing the first $shown pages.',
              style: TextStyle(color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoteContent(String title, List<DocxBlock>? content) {
    if (content == null || content.isEmpty || !mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        // Generate widgets for the note content
        // We use a temporary generator just for this content
        final noteWidgets = _generator.generateWidgets(DocxBuiltDocument(
          elements: content,
          // Empty dummy section/etc
          section: const DocxSectionDef(),
        ));

        // Filter out dividers/headers/etc that handle method might add?
        // generateWidgets handles 'doc' which includes section logic.
        // If we pass content as 'elements', it will be in the body. That's fine.

        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: noteWidgets,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _onSearchChanged() {
    // Search waits until pagination has finished and the index is built — there
    // are no matches to show (or keys to navigate) mid-stream.
    if (_doc == null || _paginating) return;

    // Re-render to reflect search highlights *without re-paginating* — search
    // does not change layout, so reuse the cached pagination (Plan §2.4.6). In
    // paged mode this swaps the lazy streamed display for the keyed eager list
    // so block keys exist for navigation.
    final widgets = _generator.rerenderWidgets(_doc!);

    if (!mounted) return;
    setState(() {
      _widgets = widgets;
    });

    // Handle navigation
    final matchIndex = _searchController.currentMatchIndex;
    if (matchIndex != -1 && matchIndex < _searchController.matches.length) {
      final match = _searchController.matches[matchIndex];
      final blockIndex = match.blockIndex;

      final key = _generator.keys[blockIndex];
      if (key != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (key.currentContext != null) {
            final context = key.currentContext!;
            if (!context.mounted) return;

            double alignment = 0.5;

            try {
              // For large blocks, calculate dynamic alignment
              final renderObject = context.findRenderObject();
              if (renderObject is RenderBox) {
                final scrollable = Scrollable.of(context);
                if (scrollable.position.hasViewportDimension) {
                  final viewportHeight = scrollable.position.viewportDimension;
                  if (renderObject.size.height > viewportHeight) {
                    final text = _searchController.getBlockText(blockIndex);
                    if (text.isNotEmpty) {
                      final relativePos = match.startOffset / text.length;
                      alignment = relativePos.clamp(0.0, 1.0);
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('DocxView: Error calculating alignment: $e');
            }

            debugPrint(
                'DocxView: Scrolling to match $matchIndex at block $blockIndex using alignment $alignment');

            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: alignment,
            );
          } else {
            debugPrint(
                'DocxView: Key found for block $blockIndex but context is null');
          }
        });
      } else {
        debugPrint('DocxView: No key found for block $blockIndex');
        // Debug dump keys
        debugPrint(
            'DocxView: Available keys: ${_generator.keys.keys.join(', ')}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.config.theme ?? DocxViewTheme.light();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load document',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Use theme's background color, fallback to config, then to white
    final backgroundColor =
        widget.config.backgroundColor ?? theme.backgroundColor ?? Colors.white;

    final bool isPaged = widget.config.pageMode == DocxPageMode.paged;
    // virtualization: כשאין zoom (InteractiveViewer דורש גודל סופי) ואין רוחב-עמוד
    // legacy, מרנדרים ב-ListView.builder — רק הבלוקים הנראים מקבלים RenderObject,
    // כך ש-RAM נשאר נמוך וגלילה חלקה גם במסמך של מאות עמודים.
    // ראו WORD_FIDELITY_VIEWER_PLAN.md §4.1.
    final bool canVirtualize =
        !widget.config.enableZoom && widget.config.pageWidth == null;

    final Widget list;
    if (isPaged && _widgets == null) {
      // Paged streaming display: build each page lazily from its measured model,
      // with a loading affordance at the tail while pages are still being laid
      // out (Plan §D.3/§4.4). The keyed eager list (_widgets) only takes over
      // once a search needs navigation keys.
      final pageCount = _pages.length;
      // One trailing item: a placeholder while paginating, or a truncation
      // notice if the page cap was hit (a pathological/hostile document).
      final bool truncated = !_paginating && (_pagination?.truncated ?? false);
      final bool hasTail = _paginating || truncated;
      final itemCount = pageCount + (hasTail ? 1 : 0);
      if (itemCount == 0) {
        return const Center(child: CircularProgressIndicator());
      }
      Widget buildItem(int i) {
        if (i >= pageCount) {
          return _paginating
              ? Center(child: _buildPagePlaceholder())
              : _buildTruncationNotice();
        }
        return _pageSlot(
          _generator.buildPageWidget(_doc!, _pages, i,
              finalResult: _pagination),
        );
      }

      list = canVirtualize
          ? ListView.builder(
              padding: widget.config.padding,
              itemCount: itemCount,
              itemBuilder: (context, i) => buildItem(i),
            )
          : SingleChildScrollView(
              padding: widget.config.padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [for (var i = 0; i < itemCount; i++) buildItem(i)],
              ),
            );
    } else {
      // Continuous mode, or the keyed eager list built for search navigation.
      final widgets = _widgets;
      if (widgets == null || widgets.isEmpty) {
        return const Center(child: Text('Empty document'));
      }
      list = canVirtualize
          ? ListView.builder(
              padding: widget.config.padding,
              itemCount: widgets.length,
              itemBuilder: (context, i) =>
                  isPaged ? _pageSlot(widgets[i]) : widgets[i],
            )
          : SingleChildScrollView(
              padding: widget.config.padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widgets.map((child) {
                  if (isPaged) return _pageSlot(child);
                  return child;
                }).toList(),
              ),
            );
    }

    Widget content;
    if (widget.config.pageMode == DocxPageMode.paged) {
      // Paged View: Canvas style
      content = Container(
        color: widget.config.backgroundColor ?? Colors.grey.shade200,
        child: list,
      );
    } else if (widget.config.pageWidth != null) {
      // Page Layout Mode (Legacy constrained continuous)
      content = Container(
        color: widget.config.backgroundColor ?? const Color(0xFFF0F0F0),
        alignment: Alignment.topCenter,
        child: Container(
          width: widget.config.pageWidth,
          margin: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: theme.backgroundColor ?? Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: list,
        ),
      );
    } else {
      // Standard Responsive Mode
      content = Container(
        color: backgroundColor,
        child: list,
      );
    }

    // Wrap with InteractiveViewer for zoom functionality
    if (widget.config.enableZoom) {
      content = InteractiveViewer(
        minScale: widget.config.minScale,
        maxScale: widget.config.maxScale,
        child: content,
      );
    }

    return content;
  }

  /// Wraps a fixed-size paged page so it scales **down** to fit the viewport
  /// width when narrower than the page ([DocxViewConfig.fitPageToWidth]). This
  /// is visual zoom only: the page widget is already laid out at the real page
  /// width, so line and page breaks are unchanged — only the whole page shrinks
  /// to stay fully visible. A page that fits is shown at 100%, centered.
  Widget _pageSlot(Widget page) {
    if (!widget.config.fitPageToWidth) return Center(child: page);
    // The page widget's natural footprint includes its outer margin band, so
    // measure and scale against the full slot (pageW/H already include the
    // margin). Otherwise BoxFit.fill stretched the larger child non-uniformly
    // and a "fitting" page rendered slightly under 100% (QA F4).
    final slotW = _generator.pageSlotWidth(_doc?.section);
    final slotH = _generator.pageSlotHeight(_doc?.section);
    return LayoutBuilder(
      builder: (context, constraints) => buildPageFitSlot(
        slotWidth: slotW,
        slotHeight: slotH,
        maxWidth: constraints.maxWidth,
        child: page,
      ),
    );
  }
}

/// Widget extension for adding a search bar.
class DocxViewWithSearch extends StatefulWidget {
  final File? file;
  final Uint8List? bytes;
  final String? path;
  final DocxViewConfig config;

  const DocxViewWithSearch({
    super.key,
    this.file,
    this.bytes,
    this.path,
    this.config = const DocxViewConfig(),
  });

  @override
  State<DocxViewWithSearch> createState() => _DocxViewWithSearchState();
}

class _DocxViewWithSearchState extends State<DocxViewWithSearch> {
  final DocxSearchController _searchController = DocxSearchController();
  final TextEditingController _textController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        if (_showSearch)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      _searchController.search(value);
                    },
                    onChanged: (value) {
                      // Optional: live search
                      // _searchController.search(value);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: _searchController.previousMatch,
                  tooltip: 'Previous match',
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: _searchController.nextMatch,
                  tooltip: 'Next match',
                ),
                ListenableBuilder(
                  listenable: _searchController,
                  builder: (context, _) {
                    if (_searchController.matchCount > 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${_searchController.currentMatchIndex + 1}/${_searchController.matchCount}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _showSearch = false;
                      _searchController.clear();
                      _textController.clear();
                    });
                  },
                ),
              ],
            ),
          ),
        // Document view
        Expanded(
          child: Stack(
            children: [
              DocxView(
                file: widget.file,
                bytes: widget.bytes,
                path: widget.path,
                config: widget.config,
                searchController: _searchController,
              ),
              // Search FAB
              if (!_showSearch)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: () {
                      setState(() {
                        _showSearch = true;
                      });
                    },
                    child: const Icon(Icons.search),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Collects every system font family the document references — across its body,
/// header, footer, footnotes and endnotes — so their real line metrics can be
/// registered (QA F10). Optionally seeded with [extra] (e.g. the configured
/// fallbacks). Best-effort: node kinds without text are skipped.
@visibleForTesting
Set<String> collectDocumentFontFamilies(
  DocxBuiltDocument doc, {
  Iterable<String> extra = const [],
}) {
  final families = <String>{...extra};
  _collectFontFamilies(doc.elements, families);
  _collectFontFamilies(doc.section?.header?.children ?? const [], families);
  _collectFontFamilies(doc.section?.footer?.children ?? const [], families);
  // Notes carry their own runs/fonts; a family used only inside a footnote or
  // endnote must still get system line-metrics instead of the default height.
  for (final f in doc.footnotes ?? const []) {
    _collectFontFamilies(f.content, families);
  }
  for (final e in doc.endnotes ?? const []) {
    _collectFontFamilies(e.content, families);
  }
  return families;
}

/// Collects every font family the document's runs reference (`w:rFonts`
/// ascii/hAnsi/cs/eastAsia + the legacy `fontFamily`) into [out], walking
/// paragraphs, table cells and list items. Used to register those families'
/// real line metrics. Best-effort: node kinds without text are skipped.
void _collectFontFamilies(Iterable<DocxNode> nodes, Set<String> out) {
  for (final node in nodes) {
    if (node is DocxParagraph) {
      _collectFromInlines(node.children, out);
    } else if (node is DocxTable) {
      for (final row in node.rows) {
        for (final cell in row.cells) {
          _collectFontFamilies(cell.children, out);
        }
      }
    } else if (node is DocxList) {
      for (final item in node.items) {
        _collectFromInlines(item.children, out);
      }
    }
  }
}

void _collectFromInlines(Iterable<DocxInline> inlines, Set<String> out) {
  void add(String? f) {
    if (f != null && f.trim().isNotEmpty) out.add(f);
  }

  for (final inline in inlines) {
    if (inline is DocxText) {
      add(inline.fontFamily);
      add(inline.fonts?.ascii);
      add(inline.fonts?.hAnsi);
      add(inline.fonts?.cs);
      add(inline.fonts?.eastAsia);
    }
  }
}
