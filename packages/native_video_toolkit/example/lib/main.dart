import 'dart:io';

import 'package:flutter/material.dart';
import 'package:native_video_toolkit/native_video_toolkit.dart';
import 'package:path_provider/path_provider.dart';

/// Smoke-test harness: exercises every operation against a battery of
/// AVFoundation-native (mov) and non-native (avi/wmv/flv/mkv) sample files
/// dropped at /tmp/nvt_format_tests/, printing pass/fail for each. A real
/// macOS app build (not a bare `dart run`) is required — the generated
/// Objective-C block glue only exists once SwiftPM/Xcode compiles it into
/// this app.
void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final List<String> _log = ['Starting...'];

  @override
  void initState() {
    super.initState();
    _runAll();
  }

  void _print(String line) {
    // ignore: avoid_print
    print(line);
    if (!mounted) return;
    setState(() => _log.add(line));
  }

  Future<void> _step(String name, Future<void> Function() body) async {
    try {
      await body();
      _print('$name: OK');
    } catch (e) {
      _print('$name: FAILED -> $e');
    }
  }

  Future<void> _runAll() async {
    if (Platform.isAndroid) {
      await _runAllAndroid();
      return;
    }
    const dir = '/tmp/nvt_format_tests';
    final formats = ['mov', 'avi', 'wmv', 'flv', 'mkv'];

    for (final format in formats) {
      final input = '$dir/sample.$format';
      if (!File(input).existsSync()) {
        _print('[$format] skipped (no test file at $input)');
        continue;
      }

      await _step('[$format] compressVideo', () async {
        final out = await NativeVideoToolkit.compressVideo(
          inputPath: input,
          outputPath: '$dir/out_compressed_$format.$format',
          quality: 0.6,
        );
        final size = File(out).lengthSync();
        if (size <= 0) throw Exception('output file is empty');
        if (!out.endsWith('.$format')) {
          throw Exception('expected output extension .$format, got $out');
        }
        _print('  -> $out (${size}B)');
      });

      await _step('[$format] muteVideo', () async {
        final out = await NativeVideoToolkit.muteVideo(
          inputPath: input,
          outputPath: '$dir/out_muted_$format.$format',
        );
        final size = File(out).lengthSync();
        if (size <= 0) throw Exception('output file is empty');
        if (!out.endsWith('.$format')) {
          throw Exception('expected output extension .$format, got $out');
        }
        _print('  -> $out (${size}B)');
      });

      await _step('[$format] reverseVideo', () async {
        final out = await NativeVideoToolkit.reverseVideo(
          inputPath: input,
          outputPath: '$dir/out_reversed_$format.$format',
        );
        final size = File(out).lengthSync();
        if (size <= 0) throw Exception('output file is empty');
        if (!out.endsWith('.$format')) {
          throw Exception('expected output extension .$format, got $out');
        }
        _print('  -> $out (${size}B)');
      });

      await _step('[$format] ensurePlayableCopy', () async {
        final playable = await NativeVideoToolkit.ensurePlayableCopy(input);
        final size = File(playable).lengthSync();
        if (size <= 0) throw Exception('playable copy is empty');
        _print('  -> $playable (${size}B)');
        await NativeVideoToolkit.disposePlayableCopy(playable, input);
      });
    }

    await _step('mergeVideos (mov + avi + mkv)', () async {
      final inputs = ['mov', 'avi', 'mkv']
          .map((f) => '$dir/sample.$f')
          .where((p) => File(p).existsSync())
          .toList();
      if (inputs.length < 2) {
        throw Exception('need at least 2 of mov/avi/mkv test files');
      }
      final out = await NativeVideoToolkit.mergeVideos(
        inputPaths: inputs,
        outputPath: '$dir/out_merged.mov',
      );
      final size = File(out).lengthSync();
      if (size <= 0) throw Exception('output file is empty');
      _print('  -> $out (${size}B)');
    });

    _print('DONE');
  }

  /// Android smoke test: exercises the jnigen/`android.media` backed
  /// implementation (`native_video_toolkit_android.dart`) against real mp4
  /// files pushed via `adb push` into this app's own external files dir
  /// (printed below) — `android.media.MediaExtractor`/`MediaMuxer`/
  /// `MediaCodec` have nothing to do with AVFoundation container
  /// compatibility, so this doesn't need the mov/avi/wmv/flv/mkv battery
  /// above, just real H.264/AAC mp4s.
  Future<void> _runAllAndroid() async {
    final extDir = await getExternalStorageDirectory();
    final dir = '${extDir!.path}/nvt_test';
    await Directory(dir).create(recursive: true);
    _print('Android test dir: $dir');

    final sampleA = '$dir/sample_a.mp4';
    final sampleB = '$dir/sample_b.mp4';
    final sampleDiffRes = '$dir/sample_diffres.mp4';

    if (!File(sampleA).existsSync()) {
      _print(
        'skipped (no test files at $dir — push sample_a.mp4/'
        'sample_b.mp4/sample_diffres.mp4 first)',
      );
      return;
    }

    await _step('muteVideo', () async {
      final out = await NativeVideoToolkit.muteVideo(
        inputPath: sampleA,
        outputPath: '$dir/out_muted.mp4',
      );
      final size = File(out).lengthSync();
      if (size <= 0) throw Exception('output file is empty');
      _print('  -> $out (${size}B)');
    });

    await _step('reverseVideo', () async {
      final out = await NativeVideoToolkit.reverseVideo(
        inputPath: sampleA,
        outputPath: '$dir/out_reversed.mp4',
      );
      final size = File(out).lengthSync();
      if (size <= 0) throw Exception('output file is empty');
      _print('  -> $out (${size}B)');
    });

    await _step('mergeVideos (fast path: same encoding)', () async {
      final out = await NativeVideoToolkit.mergeVideos(
        inputPaths: [sampleA, sampleB],
        outputPath: '$dir/out_merged_fast.mp4',
      );
      final size = File(out).lengthSync();
      if (size <= 0) throw Exception('output file is empty');
      _print('  -> $out (${size}B)');
    });

    if (File(sampleDiffRes).existsSync()) {
      await _step(
        'mergeVideos (mismatched resolution -> expected to throw)',
        () async {
          try {
            await NativeVideoToolkit.mergeVideos(
              inputPaths: [sampleA, sampleDiffRes],
              outputPath: '$dir/out_merged_should_fail.mp4',
            );
            throw Exception('expected an incompatible-clips exception');
          } on Exception catch (e) {
            if (e.toString().contains('expected an incompatible')) rethrow;
            _print('  -> correctly rejected: $e');
          }
        },
      );
    }

    await _step('ensurePlayableCopy', () async {
      final playable = await NativeVideoToolkit.ensurePlayableCopy(sampleA);
      final size = File(playable).lengthSync();
      if (size <= 0) throw Exception('playable copy is empty');
      _print('  -> $playable (${size}B)');
      await NativeVideoToolkit.disposePlayableCopy(playable, sampleA);
    });

    _print('DONE');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('native_video_toolkit smoke test')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [for (final line in _log) Text(line)],
        ),
      ),
    );
  }
}
