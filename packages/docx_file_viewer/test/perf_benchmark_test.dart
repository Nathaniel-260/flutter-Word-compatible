import 'dart:io';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/pagination/paginator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §N.4 / §M.7: a *soft* regression backstop for pagination cost. It is
/// **not** the §2.2 device budget (load ≤1.5s, paginate ≤6s, search ≤100ms,
/// 60fps) — those need `--profile` on a device with the ~200-page reference doc
/// (§M.7, still open). This guards against the regressions a build machine *can*
/// catch deterministically: re-measuring blocks (cache thrash / O(n²)).
///
/// The primary assertion is machine-independent — `TextMeasurer.layoutCount`
/// (real `TextPainter` layouts = cache misses) must stay ~linear in the block
/// count. The wall-clock check is a generous catastrophic backstop only, so CI
/// variance never flakes it.
void main() {
  test('paginating a large document measures each block ~once (no thrash)', () {
    const blockCount = 500;
    final body = <DocxNode>[
      for (var i = 0; i < blockCount; i++)
        // Short single-line text + a generous page height → no paragraph splits,
        // so a clean run lays out exactly one painter per block.
        DocxParagraph(children: [DocxText('Benchmark paragraph number $i')]),
    ];
    final doc = DocxBuiltDocument(
      elements: body,
      section: const DocxSectionDef(),
    );

    const config = DocxViewConfig(
      pageMode: DocxPageMode.paged,
      pageWidth: 600,
      pageHeight: 400,
      enableSelection: false,
    );
    final spanFactory = SpanFactory(
      theme: DocxViewTheme.light(),
      config: config,
      docxTheme: DocxTheme.empty(),
    );
    final measurer = TextMeasurer(spanFactory: spanFactory);

    final sw = Stopwatch()..start();
    final result = Paginator(measurer: measurer, config: config).paginate(doc);
    sw.stop();

    final layouts = measurer.layoutCount;
    final hits = measurer.cacheHits;
    measurer.dispose();

    expect(result.pageCount, greaterThan(10),
        reason: 'the synthetic doc must span many pages');

    // Deterministic, machine-independent guard: a clean paginate lays out each
    // block about once (measured ~1.13× for keepNext/page-boundary look-ahead).
    // The 1.5× bound trips early on a re-measurement regression (a missing or
    // ineffective cache, or an O(n²) pass) while keeping headroom for honest
    // look-ahead — layoutCount does not vary by machine, so it cannot flake.
    expect(layouts, lessThan((blockCount * 1.5).round()),
        reason: 'pagination must not re-measure blocks (layouts=$layouts, '
            'blocks=$blockCount)');

    // Generous catastrophic backstop only (not the §2.2 budget). A real
    // quadratic regression turns sub-second work into tens of seconds.
    expect(sw.elapsedMilliseconds, lessThan(20000),
        reason: 'pagination wall-clock backstop (${sw.elapsedMilliseconds}ms)');

    // Diagnostic line for the profiling log (§M.5) — surfaces the numbers even
    // when the test passes.
    // ignore: avoid_print
    print('[perf] paginate: ${result.pageCount} pages, '
        '$layouts layouts, $hits cache hits, ${sw.elapsedMilliseconds}ms');
  });

  test('parse timing on the reference fixture (diagnostic)', () async {
    // Local-only fixture (shared with word_parity_test); skip in a clean
    // checkout. Reports parse wall-clock for the §M.5 log — no hard budget here
    // (that is a device measurement, §M.7).
    const docPath = r'C:\OTZ\flutter-packages\.tmp_docx\formatting-demo.docx';
    final file = File(docPath);
    if (!file.existsSync()) return;
    final bytes = file.readAsBytesSync();

    final sw = Stopwatch()..start();
    final doc = await DocxReader.loadFromBytes(bytes);
    sw.stop();

    expect(doc.elements, isNotEmpty);
    // ignore: avoid_print
    print('[perf] parse: ${doc.elements.length} blocks, '
        '${sw.elapsedMilliseconds}ms for ${bytes.length} bytes');
  });
}
