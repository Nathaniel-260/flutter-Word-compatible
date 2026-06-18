import 'package:flutter/material.dart';

import 'theme/docx_view_theme.dart';

/// Defines the layout rendering mode.
enum DocxPageMode {
  /// Renders content in a single continuous scroll view (standard web/mobile style).
  continuous,

  /// Renders content in distinct page blocks (print layout style).
  paged,
}

/// Configuration for [DocxView] widget.
class DocxViewConfig {
  /// Enable search functionality with highlighting.
  final bool enableSearch;

  /// Enable pinch-to-zoom functionality.
  final bool enableZoom;

  /// Enable text selection for copy/paste.
  final bool enableSelection;

  /// Minimum zoom scale.
  final double minScale;

  /// Maximum zoom scale.
  final double maxScale;

  /// Font fallbacks when embedded fonts are unavailable.
  final List<String> customFontFallbacks;

  /// Overrides the built-in Word→available-family substitution table (Plan §L.2).
  /// Keys are Word font names (matched case-insensitively, e.g. `'Calibri'`),
  /// values the family the host app actually registered (e.g. a metric clone or
  /// a Hebrew font). An entry here wins over the document's own font and the
  /// built-in table, so the host can force a specific font for any Word name.
  final Map<String, String> fontSubstitutions;

  /// Theme for styling the document view.
  final DocxViewTheme? theme;

  /// Padding around the document content.
  final EdgeInsets padding;

  /// Background color for the viewer.
  final Color? backgroundColor;

  /// Show page breaks as visual separators.
  final bool showPageBreaks;

  /// Show debug info for unsupported elements (development mode).
  final bool showDebugInfo;

  /// Highlight color for search matches.
  final Color searchHighlightColor;

  /// Current search match highlight color.
  final Color currentSearchHighlightColor;

  /// Optional fixed page width to simulate print layout (e.g. 793 for A4).
  /// If null, content fills the available width (web/mobile responsive style).
  final double? pageWidth;

  /// The layout mode of the document (continuous or paged).
  final DocxPageMode pageMode;

  /// Optional fixed page height for paged mode (e.g. 1123 for A4 at 794 width).
  /// If null, defaults to page width * 1.414 (A4 ratio).
  final double? pageHeight;

  /// Called when an external hyperlink in the document is tapped, with its url
  /// (Plan §K.2). When null the viewer launches the url via `url_launcher`.
  /// Internal links (anchors to a bookmark) are handled by the viewer itself
  /// (it scrolls to the bookmark's page) and never reach this callback.
  final void Function(String url)? onOpenLink;

  /// Paged mode only: scale each page down to fit the viewport width when the
  /// window is narrower than the page, so the whole page is visible instead of
  /// being clipped. Crucially this is **purely visual zoom** — the document is
  /// still paginated and line-broken at the real page width, so line/page breaks
  /// stay identical to Word regardless of window size (a page that fits is shown
  /// at 100%, never enlarged). Set false to keep the page at its native pixel
  /// size (the caller then scrolls/zooms it themselves).
  final bool fitPageToWidth;

  const DocxViewConfig({
    this.enableSearch = true,
    this.enableZoom = true,
    this.enableSelection = true,
    this.minScale = 0.5,
    this.maxScale = 4.0,
    this.customFontFallbacks = const ['Roboto', 'Arial', 'Helvetica'],
    this.fontSubstitutions = const {},
    this.theme,
    this.padding = const EdgeInsets.all(16.0),
    this.backgroundColor,
    this.showPageBreaks = true,
    this.showDebugInfo = false,
    this.searchHighlightColor = const Color(0xFFFFEB3B),
    this.currentSearchHighlightColor = const Color(0xFFFF9800),
    this.pageWidth,
    this.pageHeight,
    this.pageMode = DocxPageMode.paged,
    this.fitPageToWidth = true,
    this.onOpenLink,
  });

  DocxViewConfig copyWith({
    bool? enableSearch,
    bool? enableZoom,
    bool? enableSelection,
    double? minScale,
    double? maxScale,
    List<String>? customFontFallbacks,
    Map<String, String>? fontSubstitutions,
    DocxViewTheme? theme,
    EdgeInsets? padding,
    Color? backgroundColor,
    bool? showPageBreaks,
    bool? showDebugInfo,
    Color? searchHighlightColor,
    Color? currentSearchHighlightColor,
    double? pageWidth,
    double? pageHeight,
    DocxPageMode? pageMode,
    bool? fitPageToWidth,
    void Function(String url)? onOpenLink,
  }) {
    return DocxViewConfig(
      enableSearch: enableSearch ?? this.enableSearch,
      enableZoom: enableZoom ?? this.enableZoom,
      enableSelection: enableSelection ?? this.enableSelection,
      minScale: minScale ?? this.minScale,
      maxScale: maxScale ?? this.maxScale,
      customFontFallbacks: customFontFallbacks ?? this.customFontFallbacks,
      fontSubstitutions: fontSubstitutions ?? this.fontSubstitutions,
      theme: theme ?? this.theme,
      padding: padding ?? this.padding,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      showPageBreaks: showPageBreaks ?? this.showPageBreaks,
      showDebugInfo: showDebugInfo ?? this.showDebugInfo,
      searchHighlightColor: searchHighlightColor ?? this.searchHighlightColor,
      currentSearchHighlightColor:
          currentSearchHighlightColor ?? this.currentSearchHighlightColor,
      pageWidth: pageWidth ?? this.pageWidth,
      pageHeight: pageHeight ?? this.pageHeight,
      pageMode: pageMode ?? this.pageMode,
      fitPageToWidth: fitPageToWidth ?? this.fitPageToWidth,
      onOpenLink: onOpenLink ?? this.onOpenLink,
    );
  }
}
