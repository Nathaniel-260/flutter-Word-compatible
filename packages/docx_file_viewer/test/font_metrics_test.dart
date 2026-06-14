import 'dart:io';
import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/font_loader/font_metrics.dart';
import 'package:docx_file_viewer/src/font_loader/font_metrics_registry.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Per-font line metrics: single-spaced text must lay out at the font's own line
/// height (what Word does), not one fixed multiplier.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(FontMetricsRegistry.clear);

  group('FontMetricsRegistry', () {
    test('lookup is case-insensitive; unknown/null → null', () {
      FontMetricsRegistry.registerRatio('Arial', 1.088);
      expect(FontMetricsRegistry.lineHeightFor('arial'), 1.088);
      expect(FontMetricsRegistry.lineHeightFor('ARIAL'), 1.088);
      expect(FontMetricsRegistry.has('Arial'), isTrue);
      expect(FontMetricsRegistry.lineHeightFor('Times New Roman'), isNull);
      expect(FontMetricsRegistry.lineHeightFor(null), isNull);
    });
  });

  test('SpanFactory uses the registered per-font ratio for single spacing', () {
    FontMetricsRegistry.registerRatio('BigFont', 1.5);
    final theme = DocxViewTheme.light(); // default single height 1.15
    final sf = SpanFactory(
      theme: theme,
      config: const DocxViewConfig(enableSelection: false),
      docxTheme: DocxTheme.empty(),
    );
    final measurer = TextMeasurer(spanFactory: sf);
    final fs = theme.defaultTextStyle.fontSize!; // 14

    double perLine(String? family) {
      final p = DocxParagraph(children: [DocxText('x', fontFamily: family)]);
      final m = measurer.measureParagraph(p, 400);
      return m.textHeight / m.lineCount;
    }

    expect(perLine('BigFont'), closeTo(fs * 1.5, 1.0),
        reason: 'a registered font lays out at its own line-height ratio');
    expect(perLine('Unregistered'), closeTo(fs * 1.15, 1.0),
        reason: 'an unknown font falls back to the theme single height');
    measurer.dispose();
  });

  test('FontMetrics.tryParse reads Arial typo metrics (~1.09) when present',
      () {
    const p = r'C:\Windows\Fonts\arial.ttf';
    if (!File(p).existsSync()) return; // skip on non-Windows hosts
    final m = FontMetrics.tryParse(File(p).readAsBytesSync());
    expect(m, isNotNull);
    // Word spaces Arial by its typo metrics ≈ 1.088 (vs the win-metrics 1.117).
    expect(m!.lineHeightRatio, closeTo(1.088, 0.02));
    expect(m.unitsPerEm, 2048);
  });

  test('tryParse returns null for non-font bytes', () {
    expect(FontMetrics.tryParse(Uint8List.fromList([0, 1, 2, 3, 4])), isNull);
  });
}
