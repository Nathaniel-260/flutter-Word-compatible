import 'dart:io';

import 'font_metrics_registry.dart';

/// Loads line metrics for the named [families] from the operating system's font
/// files and records them in [FontMetricsRegistry], so documents that use system
/// fonts (e.g. Arial, David, Times New Roman — not embedded in the `.docx`) lay
/// single-spaced text out at Word's per-font line height. Desktop only and
/// entirely best-effort: every miss is silent, and already-known families are
/// skipped. The web build uses a no-op stub instead (no filesystem).
Future<void> registerSystemFonts(Iterable<String> families) async {
  late final List<Directory> dirs;
  try {
    dirs = _fontDirs().where((d) => d.existsSync()).toList();
  } catch (_) {
    return;
  }
  if (dirs.isEmpty) return;

  for (final family in families) {
    if (FontMetricsRegistry.has(family)) continue;
    for (final name in _candidateFileNames(family)) {
      final file = _firstExisting(dirs, name);
      if (file == null) continue;
      try {
        FontMetricsRegistry.register(family, file.readAsBytesSync());
      } catch (_) {
        // unreadable file — try the next candidate
        continue;
      }
      if (FontMetricsRegistry.has(family)) break;
    }
  }
}

List<Directory> _fontDirs() {
  final env = Platform.environment;
  if (Platform.isWindows) {
    final win = env['WINDIR'] ?? r'C:\Windows';
    final local = env['LOCALAPPDATA'];
    return [
      Directory('$win\\Fonts'),
      if (local != null) Directory('$local\\Microsoft\\Windows\\Fonts'),
    ];
  }
  if (Platform.isMacOS) {
    final home = env['HOME'];
    return [
      Directory('/System/Library/Fonts'),
      Directory('/System/Library/Fonts/Supplemental'),
      Directory('/Library/Fonts'),
      if (home != null) Directory('$home/Library/Fonts'),
    ];
  }
  // Linux / others
  final home = env['HOME'];
  return [
    Directory('/usr/share/fonts'),
    Directory('/usr/local/share/fonts'),
    if (home != null) Directory('$home/.fonts'),
    if (home != null) Directory('$home/.local/share/fonts'),
  ];
}

/// Maps a font family to the likely regular-weight filename(s). Only the regular
/// face is needed — line metrics are shared across weights/styles.
List<String> _candidateFileNames(String family) {
  final lower = family.trim().toLowerCase();
  // Known Windows filenames that don't follow the "lowercase, no spaces" rule.
  const known = <String, String>{
    'times new roman': 'times',
    'courier new': 'cour',
    'comic sans ms': 'comic',
    'trebuchet ms': 'trebuc',
    'lucida console': 'lucon',
    'palatino linotype': 'pala',
  };
  final stems = <String>{
    if (known.containsKey(lower)) known[lower]!,
    lower.replaceAll(' ', ''),
    lower.replaceAll(' ', '-'),
    lower,
  };
  final out = <String>[];
  for (final s in stems) {
    out.add('$s.ttf');
    out.add('$s.otf');
    out.add('$s.ttc');
  }
  return out;
}

File? _firstExisting(List<Directory> dirs, String fileName) {
  for (final dir in dirs) {
    final f = File('${dir.path}${Platform.pathSeparator}$fileName');
    try {
      if (f.existsSync()) return f;
    } catch (_) {
      // permission / IO error — keep scanning
    }
  }
  return null;
}
