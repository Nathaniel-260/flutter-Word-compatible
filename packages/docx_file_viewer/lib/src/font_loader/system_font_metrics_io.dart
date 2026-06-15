import 'dart:io';

import 'package:flutter/foundation.dart';

import 'font_metrics.dart';
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
      final metrics = readFontMetricsPartial(file);
      if (metrics != null) {
        FontMetricsRegistry.registerRatio(family, metrics.lineHeightRatio);
        break;
      }
      // unreadable / unparseable file — try the next candidate
    }
  }
}

/// Reads a font's line metrics from disk **without loading the whole file**:
/// only the sfnt header, the table directory, and the `head` + `OS/2` tables are
/// read (a few hundred bytes), instead of pulling a 10–20 MB CJK font fully into
/// memory just to parse two tables (QA F9). Returns null on any IO/format error
/// (best-effort + silent, matching the previous behaviour).
@visibleForTesting
FontMetrics? readFontMetricsPartial(File file) {
  RandomAccessFile? raf;
  try {
    raf = file.openSync();
    final length = raf.lengthSync();
    final r = raf; // promote for the local closure

    Uint8List readAt(int offset, int count) {
      if (offset < 0 || count <= 0 || offset + count > length) {
        throw const FormatException('font table out of range');
      }
      r.setPositionSync(offset);
      final bytes = r.readSync(count);
      if (bytes.length != count) {
        throw const FormatException('short font read');
      }
      return bytes;
    }

    // sfnt / TTC header: a TrueType Collection points at face 0's offset table.
    var base = 0;
    final header = ByteData.sublistView(readAt(0, 12));
    if (header.getUint32(0) == 0x74746366) {
      // 'ttcf'
      base = ByteData.sublistView(readAt(12, 4)).getUint32(0); // face 0 offset
    }

    // Offset table → number of tables → the 16-byte-per-entry table directory.
    final numTables = ByteData.sublistView(readAt(base + 4, 2)).getUint16(0);
    if (numTables == 0) return null;
    final dir = ByteData.sublistView(readAt(base + 12, numTables * 16));

    int? headOff;
    int? os2Off;
    for (var i = 0; i < numTables; i++) {
      final rec = i * 16;
      final tag = dir.getUint32(rec);
      final off = dir.getUint32(rec + 8);
      if (tag == 0x68656164) headOff = off; // 'head'
      if (tag == 0x4f532f32) os2Off = off; // 'OS/2'
    }
    if (headOff == null || os2Off == null) return null;

    // Read only the two tables we parse (20 + 78 bytes), not the whole font.
    return FontMetrics.fromTables(readAt(headOff, 20), readAt(os2Off, 78));
  } catch (_) {
    return null; // missing / unreadable / malformed — caller falls back
  } finally {
    try {
      raf?.closeSync();
    } catch (_) {
      // ignore close failures
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
