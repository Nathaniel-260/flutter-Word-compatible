import 'dart:io';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/pagination/paginator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Page-break parity with Word.
///
/// The unit test locks the OOXML-correct default: a paragraph with no resolved
/// spacing contributes **0** before/after, not a guessed 80tw. Injecting 80tw on
/// every unstyled body paragraph inflated the page count (~10px each) and pushed
/// content onto later pages than Word.
///
/// The integration test reproduces the real regression end-to-end: with the
/// document's own fonts (Arial/David) loaded, `formatting-demo.docx` must
/// paginate to exactly 7 pages — the page count Word produces
/// (`.tmp_docx/word_ref/ref1-7.png`). It skips when the fixture or system fonts
/// are unavailable (e.g. non-Windows CI), so it guards parity where it can
/// without failing elsewhere.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TextMeasurer makeMeasurer() {
    const config = DocxViewConfig(enableSelection: false);
    final sf = SpanFactory(
      theme: DocxViewTheme.light(),
      config: config,
      docxTheme: DocxTheme.empty(),
    );
    return TextMeasurer(spanFactory: sf);
  }

  test('a paragraph with no resolved spacing measures 0 before/after', () {
    final measurer = makeMeasurer();
    final m = measurer.measureParagraph(
      DocxParagraph(children: [DocxText('plain body line')]),
      400,
    );
    expect(m.spacingBefore, 0, reason: 'OOXML default before-spacing is 0');
    expect(m.spacingAfter, 0, reason: 'OOXML default after-spacing is 0');
    measurer.dispose();
  });

  test('explicit paragraph spacing is still honoured', () {
    final measurer = makeMeasurer();
    final m = measurer.measureParagraph(
      DocxParagraph(
        spacingBefore: 240, // 12pt
        spacingAfter: 120, // 6pt
        children: [DocxText('spaced line')],
      ),
      400,
    );
    expect(m.spacingBefore, closeTo(240 / 15.0, 0.01));
    expect(m.spacingAfter, closeTo(120 / 15.0, 0.01));
    measurer.dispose();
  });

  testWidgets('formatting-demo.docx paginates to 7 pages (Word parity)',
      (tester) async {
    const docPath = r'C:\OTZ\flutter-packages\.tmp_docx\formatting-demo.docx';
    final fonts = {
      'Arial': ['arial.ttf', 'arialbd.ttf', 'ariali.ttf', 'arialbi.ttf'],
      'David': ['david.ttf', 'davidbd.ttf'],
    };
    final haveFonts = File('C:\\Windows\\Fonts\\arial.ttf').existsSync();
    if (!File(docPath).existsSync() || !haveFonts) {
      return; // fixture/fonts unavailable — skip parity check on this host
    }

    for (final entry in fonts.entries) {
      final loader = FontLoader(entry.key);
      for (final f in entry.value) {
        final p = 'C:\\Windows\\Fonts\\$f';
        if (!File(p).existsSync()) continue;
        loader.addFont(Future.value(ByteData.view(
            Uint8List.fromList(File(p).readAsBytesSync()).buffer)));
      }
      await loader.load();
    }

    final doc = await DocxReader.loadFromBytes(File(docPath).readAsBytesSync());
    const config = DocxViewConfig(
      enableSelection: false,
      customFontFallbacks: ['Arial', 'David'],
    );
    final sf = SpanFactory(
      theme: const DocxViewTheme(
        backgroundColor: Colors.white,
        defaultTextStyle: TextStyle(
            fontFamily: 'Arial', fontSize: 14.67, color: Colors.black),
      ),
      config: config,
      docxTheme: doc.theme,
    );
    final measurer = TextMeasurer(spanFactory: sf);
    final res = Paginator(measurer: measurer, config: config).paginate(doc);
    measurer.dispose();

    expect(res.pages.length, 7,
        reason: 'Word renders this document as 7 pages (word_ref/ref1-7.png)');
  });
}
