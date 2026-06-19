import 'dart:typed_data';

import 'package:docx_file_viewer/src/docx_view.dart';
import 'package:docx_file_viewer/src/docx_view_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §M.4/§4.2: a mounted [DocxView] caps the global decoded-image cache to
/// the configured budget (lowering only), and restores the previous ceiling on
/// dispose so it does not permanently shrink the host app's cache.
void main() {
  testWidgets('caps and restores the global image-cache ceiling',
      (tester) async {
    final cache = PaintingBinding.instance.imageCache;
    final original = cache.maximumSizeBytes;
    addTearDown(() => cache.maximumSizeBytes = original);

    // Start above the test budget so the "lower only" rule triggers.
    cache.maximumSizeBytes = 100 * 1024 * 1024;
    const budget = 12 * 1024 * 1024;

    // Invalid bytes → the background parse fails, but initState applies the
    // budget synchronously first, which is what this test checks.
    final bytes = Uint8List.fromList(const [1, 2, 3]);
    await tester.pumpWidget(MaterialApp(
      home: DocxView.bytes(bytes,
          config: const DocxViewConfig(imageCacheMaxBytes: budget)),
    ));
    expect(cache.maximumSizeBytes, budget,
        reason: 'mounting the viewer lowers the ceiling to the budget');

    // Dispose the viewer → the previous ceiling is restored.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(cache.maximumSizeBytes, 100 * 1024 * 1024,
        reason: 'disposing the viewer restores the host ceiling');
  });

  testWidgets('never raises a host ceiling that is already below the budget',
      (tester) async {
    final cache = PaintingBinding.instance.imageCache;
    final original = cache.maximumSizeBytes;
    addTearDown(() => cache.maximumSizeBytes = original);

    // Host already keeps a tighter cache than our default budget.
    cache.maximumSizeBytes = 4 * 1024 * 1024;

    final bytes = Uint8List.fromList(const [1, 2, 3]);
    await tester.pumpWidget(MaterialApp(
      home: DocxView.bytes(bytes,
          config: const DocxViewConfig(imageCacheMaxBytes: 50 * 1024 * 1024)),
    ));
    expect(cache.maximumSizeBytes, 4 * 1024 * 1024,
        reason: 'a larger budget must not raise the host ceiling');

    // Clean up so the shared client count returns to zero for the next test.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  });

  testWidgets('two viewers: only the last to dispose restores the host ceiling',
      (tester) async {
    final cache = PaintingBinding.instance.imageCache;
    final original = cache.maximumSizeBytes;
    addTearDown(() => cache.maximumSizeBytes = original);

    cache.maximumSizeBytes = 100 * 1024 * 1024;
    const budget = 20 * 1024 * 1024;
    final bytes = Uint8List.fromList(const [1, 2, 3]);

    // Expanded gives each viewer a bounded height that fits its loading/error UI
    // (invalid bytes → error widget) without overflowing the test surface.
    Widget viewer(String key) => Expanded(
          child: DocxView.bytes(bytes,
              key: ValueKey(key),
              config: const DocxViewConfig(imageCacheMaxBytes: budget)),
        );

    // Both mounted → ceiling lowered to the budget.
    await tester.pumpWidget(MaterialApp(
      home: Column(children: [viewer('a'), viewer('b')]),
    ));
    expect(cache.maximumSizeBytes, budget);

    // Drop the second viewer but keep the first (its key preserves its State, so
    // only B disposes). The ceiling must stay capped while A is still live — the
    // race the per-instance restore got wrong.
    await tester.pumpWidget(MaterialApp(
      home: Column(children: [viewer('a')]),
    ));
    expect(cache.maximumSizeBytes, budget,
        reason: 'still capped while one viewer remains');

    // Drop the last viewer → the host ceiling is restored.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(cache.maximumSizeBytes, 100 * 1024 * 1024,
        reason: 'last viewer out restores the host ceiling');
  });
}
