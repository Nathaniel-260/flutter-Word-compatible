import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_pdf_engine/native_pdf_engine.dart';
import 'package:path/path.dart' as path;

/// Validates that [bytes] starts with the PDF magic header '%PDF'.
void expectValidPdf(Uint8List bytes) {
  expect(bytes, isNotNull);
  expect(bytes.length, greaterThan(4), reason: 'PDF too small to be valid');
  expect(
    String.fromCharCodes(bytes.take(5)),
    startsWith('%PDF'),
    reason: 'Not a valid PDF file (missing %PDF header)',
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // ─────────────────────────────────────────────────────────────────
  // Group 1: HTML to File
  // ─────────────────────────────────────────────────────────────────
  group('NativePdf.convert (HTML → File)', () {
    testWidgets('generates valid PDF file from simple HTML', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_test_');
      final outputPath = path.join(tempDir.path, 'simple.pdf');

      try {
        await NativePdf.convert(
          '<h1>Hello</h1><p>Simple HTML test.</p>',
          outputPath,
        );

        final file = File(outputPath);
        expect(file.existsSync(), isTrue, reason: 'PDF file was not created');
        expect(file.lengthSync(), greaterThan(0));

        final bytes = file.readAsBytesSync();
        expectValidPdf(Uint8List.fromList(bytes));
      } finally {
        _cleanupDir(tempDir);
      }
    });

    testWidgets('generates PDF with complex HTML and CSS', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_test_');
      final outputPath = path.join(tempDir.path, 'complex.pdf');

      const html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; }
    h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
    th { background-color: #3498db; color: white; }
    tr:nth-child(even) { background-color: #f2f2f2; }
    .highlight { background-color: #ffffcc; font-weight: bold; }
  </style>
</head>
<body>
  <h1>Complex HTML Test</h1>
  <p>This tests CSS styling, tables, and layout.</p>
  <table>
    <tr><th>Name</th><th>Value</th><th>Status</th></tr>
    <tr><td>Test 1</td><td>100</td><td class="highlight">Pass</td></tr>
    <tr><td>Test 2</td><td>200</td><td>Pass</td></tr>
    <tr><td>Test 3</td><td>300</td><td class="highlight">Pass</td></tr>
  </table>
  <ul>
    <li>Item one</li>
    <li>Item two</li>
    <li>Item three</li>
  </ul>
</body>
</html>
''';

      try {
        await NativePdf.convert(html, outputPath);

        final file = File(outputPath);
        expect(file.existsSync(), isTrue);
        // Complex HTML should produce a larger PDF
        expect(file.lengthSync(), greaterThan(100));

        final bytes = file.readAsBytesSync();
        expectValidPdf(Uint8List.fromList(bytes));
      } finally {
        _cleanupDir(tempDir);
      }
    });

    testWidgets('generates PDF with special characters and Unicode', (
      tester,
    ) async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_test_');
      final outputPath = path.join(tempDir.path, 'unicode.pdf');

      const html = '''
<html>
<head><meta charset="utf-8"></head>
<body>
  <h1>Unicode Test: émojis 🎉 & spëcial châráctérs</h1>
  <p>Arabic: مرحبا</p>
  <p>Chinese: 你好世界</p>
  <p>Japanese: こんにちは</p>
  <p>Symbols: © ® ™ € £ ¥ § ¶</p>
  <p>Math: ∑ ∏ ∫ √ ∞ ≈ ≠ ≤ ≥</p>
  <p>Ampersand: &amp; Less: &lt; Greater: &gt; Quote: &quot;</p>
</body>
</html>
''';

      try {
        await NativePdf.convert(html, outputPath);

        final file = File(outputPath);
        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), greaterThan(0));
        expectValidPdf(Uint8List.fromList(file.readAsBytesSync()));
      } finally {
        _cleanupDir(tempDir);
      }
    });

    testWidgets('handles nested directory output path', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_test_');
      final nestedDir = Directory(path.join(tempDir.path, 'sub', 'dir'));
      nestedDir.createSync(recursive: true);
      final outputPath = path.join(nestedDir.path, 'nested.pdf');

      try {
        await NativePdf.convert('<h1>Nested Dir Test</h1>', outputPath);

        final file = File(outputPath);
        expect(file.existsSync(), isTrue);
        expectValidPdf(Uint8List.fromList(file.readAsBytesSync()));
      } finally {
        _cleanupDir(tempDir);
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 2: HTML to Data (in-memory)
  // ─────────────────────────────────────────────────────────────────
  group('NativePdf.convertToData (HTML → Uint8List)', () {
    testWidgets('returns valid PDF bytes from simple HTML', (tester) async {
      final bytes = await NativePdf.convertToData(
        '<h1>Hello Data</h1><p>In-memory PDF.</p>',
      );

      expectValidPdf(bytes);
    });

    testWidgets('returns valid PDF bytes from complex HTML', (tester) async {
      final bytes = await NativePdf.convertToData('''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-size: 14px; line-height: 1.6; }
    .container { max-width: 800px; margin: 0 auto; }
    .grid { display: flex; flex-wrap: wrap; gap: 10px; }
    .card { border: 1px solid #ccc; padding: 15px; flex: 1 1 200px; border-radius: 8px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Data Conversion Test</h1>
    <div class="grid">
      <div class="card"><h3>Card 1</h3><p>Content A</p></div>
      <div class="card"><h3>Card 2</h3><p>Content B</p></div>
      <div class="card"><h3>Card 3</h3><p>Content C</p></div>
    </div>
  </div>
</body>
</html>
''');

      expectValidPdf(bytes);
      // Complex content should produce meaningful PDF
      expect(bytes.length, greaterThan(500));
    });

    testWidgets('returns non-empty data for minimal HTML', (tester) async {
      final bytes = await NativePdf.convertToData('<p>x</p>');
      expectValidPdf(bytes);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 3: URL to File
  // ─────────────────────────────────────────────────────────────────
  group('NativePdf.convertUrl (URL → File)', () {
    testWidgets('generates PDF from data: URI to file', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_test_');
      final outputPath = path.join(tempDir.path, 'url_output.pdf');

      final dataUri = Uri.dataFromString(
        '<h1>URL to File Test</h1><p>From data URI.</p>',
        mimeType: 'text/html',
      ).toString();

      try {
        await NativePdf.convertUrl(dataUri, outputPath);

        final file = File(outputPath);
        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), greaterThan(0));
        expectValidPdf(Uint8List.fromList(file.readAsBytesSync()));
      } finally {
        _cleanupDir(tempDir);
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 4: URL to Data (in-memory)
  // ─────────────────────────────────────────────────────────────────
  group('NativePdf.convertUrlToData (URL → Uint8List)', () {
    testWidgets('returns valid PDF bytes from data: URI', (tester) async {
      final dataUri = Uri.dataFromString(
        '<h1>URL to Data Test</h1><p>In-memory from URL.</p>',
        mimeType: 'text/html',
      ).toString();

      final bytes = await NativePdf.convertUrlToData(dataUri);
      expectValidPdf(bytes);
    });

    testWidgets('handles data: URI with styled content', (tester) async {
      final dataUri = Uri.dataFromString(
        '''<html><head><style>body{background:navy;color:white;}</style></head>
        <body><h1>Styled URL Test</h1></body></html>''',
        mimeType: 'text/html',
      ).toString();

      final bytes = await NativePdf.convertUrlToData(dataUri);
      expectValidPdf(bytes);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 5: Error Handling & Edge Cases
  // ─────────────────────────────────────────────────────────────────
  group('Error handling', () {
    testWidgets('rejects concurrent PDF generation', (tester) async {
      // Start first conversion (don't await)
      final future1 = NativePdf.convertToData('<h1>First</h1>');

      // Immediately try a second — should throw StateError
      expect(
        () => NativePdf.convertToData('<h1>Second</h1>'),
        throwsA(isA<StateError>()),
      );

      // Wait for the first to finish so state is clean for subsequent tests
      await future1;
    });

    testWidgets('can generate PDF after previous completes', (tester) async {
      // First call
      final bytes1 = await NativePdf.convertToData('<h1>Call 1</h1>');
      expectValidPdf(bytes1);

      // Second call — should succeed because first is done
      final bytes2 = await NativePdf.convertToData('<h1>Call 2</h1>');
      expectValidPdf(bytes2);
    });

    testWidgets('handles empty HTML gracefully', (tester) async {
      // Empty HTML should still produce a valid (blank) PDF
      final bytes = await NativePdf.convertToData('');
      // Should at least return valid PDF structure (may be blank page)
      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(0));
    });

    testWidgets('sequential calls produce independent results', (tester) async {
      final bytes1 = await NativePdf.convertToData('<h1>Short</h1>');
      final bytes2 = await NativePdf.convertToData('''
<html><body>
  <h1>Much Longer Content</h1>
  <p>${List.generate(50, (i) => 'Paragraph $i with some content. ').join()}</p>
  <table>
    ${List.generate(20, (i) => '<tr><td>Row $i Col 1</td><td>Row $i Col 2</td><td>Row $i Col 3</td></tr>').join()}
  </table>
</body></html>
''');

      expectValidPdf(bytes1);
      expectValidPdf(bytes2);
      // Longer content should produce larger PDF
      expect(bytes2.length, greaterThan(bytes1.length));
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 6: Memory Safety – Cleanup Verification
  // ─────────────────────────────────────────────────────────────────
  group('Memory safety & cleanup', () {
    testWidgets('multiple sequential conversions do not leak', (tester) async {
      // Run 5 sequential conversions to verify cleanup works properly
      for (var i = 0; i < 5; i++) {
        final bytes = await NativePdf.convertToData(
          '<h1>Iteration $i</h1><p>Testing cleanup after each call.</p>',
        );
        expectValidPdf(bytes);
      }
    });

    testWidgets('file conversion followed by data conversion works', (
      tester,
    ) async {
      // Test switching between file and data output modes
      final tempDir = Directory.systemTemp.createTempSync('pdf_test_');
      final outputPath = path.join(tempDir.path, 'mixed.pdf');

      try {
        // File mode
        await NativePdf.convert('<h1>File Mode</h1>', outputPath);
        expect(File(outputPath).existsSync(), isTrue);

        // Data mode (should work after file mode cleaned up)
        final bytes = await NativePdf.convertToData('<h1>Data Mode</h1>');
        expectValidPdf(bytes);

        // File mode again
        final outputPath2 = path.join(tempDir.path, 'mixed2.pdf');
        await NativePdf.convert('<h1>File Mode Again</h1>', outputPath2);
        expect(File(outputPath2).existsSync(), isTrue);
      } finally {
        _cleanupDir(tempDir);
      }
    });

    testWidgets('URL conversion followed by HTML conversion works', (
      tester,
    ) async {
      // URL mode
      final dataUri = Uri.dataFromString(
        '<h1>URL First</h1>',
        mimeType: 'text/html',
      ).toString();
      final urlBytes = await NativePdf.convertUrlToData(dataUri);
      expectValidPdf(urlBytes);

      // HTML mode (should work after URL mode cleaned up)
      final htmlBytes = await NativePdf.convertToData('<h1>HTML Second</h1>');
      expectValidPdf(htmlBytes);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Group 7: Large Content Handling
  // ─────────────────────────────────────────────────────────────────
  group('Large content', () {
    testWidgets('handles large HTML document', (tester) async {
      // Generate a large HTML document with many paragraphs
      final paragraphs = List.generate(
        100,
        (i) =>
            '<p>Paragraph $i: ${List.filled(10, 'Lorem ipsum dolor sit amet.').join(' ')}</p>',
      ).join('\n');

      final html =
          '''
<!DOCTYPE html>
<html>
<head><style>body { font-size: 12px; margin: 20px; }</style></head>
<body>
  <h1>Large Document Test</h1>
  $paragraphs
</body>
</html>
''';

      final bytes = await NativePdf.convertToData(html);
      expectValidPdf(bytes);
      // Large content should produce a reasonably sized PDF
      expect(bytes.length, greaterThan(1000));
    });
  });
}

/// Safely clean up a temporary directory.
void _cleanupDir(Directory dir) {
  if (dir.existsSync()) {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  }
}
