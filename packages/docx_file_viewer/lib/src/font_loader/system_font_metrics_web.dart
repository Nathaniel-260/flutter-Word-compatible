/// Web stub for [registerSystemFonts]: the browser has no accessible system font
/// files, so there is nothing to load. Documents that need per-font line metrics
/// on the web should embed their fonts (those are registered from their bytes).
Future<void> registerSystemFonts(Iterable<String> families) async {}
