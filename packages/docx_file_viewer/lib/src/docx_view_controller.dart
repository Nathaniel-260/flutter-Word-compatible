import 'package:flutter/widgets.dart';

/// Imperative controller for a [DocxView]: programmatic navigation to bookmarks
/// (Plan §K.2). Create one, pass it to [DocxView.controller], and call
/// [jumpToBookmark] (e.g. from an app-level "go to chapter" action). Internal
/// document links (anchors to a bookmark) route here automatically.
///
/// A controller is bound to exactly one [DocxView] at a time; reusing it across
/// views rebinds it to the most recent one.
class DocxViewController extends ChangeNotifier {
  Map<String, int> Function()? _bookmarks;
  Future<bool> Function(String, Duration, Curve)? _jumpBookmark;
  Future<bool> Function(int, Duration, Curve)? _jumpPage;

  /// Binds the view's navigation hooks to this controller. Internal — called by
  /// [DocxView] when it mounts/updates.
  void attach({
    required Map<String, int> Function() bookmarks,
    required Future<bool> Function(String, Duration, Curve) jumpBookmark,
    required Future<bool> Function(int, Duration, Curve) jumpPage,
  }) {
    _bookmarks = bookmarks;
    _jumpBookmark = jumpBookmark;
    _jumpPage = jumpPage;
  }

  /// Releases the bound hooks if they are still this view's. Internal — called by
  /// [DocxView] on dispose. [bookmarks] identifies the binding to release so a
  /// late dispose of an old view cannot detach a newer one.
  void detach(Map<String, int> Function() bookmarks) {
    if (identical(_bookmarks, bookmarks)) {
      _bookmarks = null;
      _jumpBookmark = null;
      _jumpPage = null;
    }
  }

  /// `bookmark name → absolute page index` for the loaded document, or an empty
  /// map before pagination finishes. Useful for building a navigation UI.
  Map<String, int> get bookmarks => _bookmarks?.call() ?? const {};

  /// The 0-based page index a [bookmark] resolves to, or null when unknown
  /// (no such bookmark, or pagination has not finished yet).
  int? pageIndexForBookmark(String bookmark) => bookmarks[bookmark];

  /// Whether [bookmark] is currently resolvable.
  bool hasBookmark(String bookmark) => bookmarks.containsKey(bookmark);

  /// Scrolls the view so the page containing [bookmark] is at the top. Resolves
  /// to true when the bookmark was found and the scroll was issued, false when
  /// the bookmark is unknown (or the view is not yet ready).
  Future<bool> jumpToBookmark(
    String bookmark, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) async {
    final fn = _jumpBookmark;
    if (fn == null) return false;
    return fn(bookmark, duration, curve);
  }

  /// Scrolls to a specific 0-based [pageIndex] (paged mode). Resolves to true
  /// when the index is in range and the scroll was issued.
  Future<bool> jumpToPage(
    int pageIndex, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) async {
    final fn = _jumpPage;
    if (fn == null) return false;
    return fn(pageIndex, duration, curve);
  }
}
