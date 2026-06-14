import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/pagination/paginator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Word suppresses a paragraph's "space before" when it falls at the top of a
/// page — the first block hugs the top margin. Without this the viewer pushed the
/// first line of every page down by its before-spacing (a visible top gap vs
/// Word). The paginator stores the suppressed copy as the slice, so measurement
/// and rendering stay in agreement.
void main() {
  late Paginator paginator;
  late TextMeasurer measurer;

  setUp(() {
    const config = DocxViewConfig(
      pageWidth: 600,
      pageHeight: 400,
      enableSelection: false,
    );
    final sf = SpanFactory(
      theme: DocxViewTheme.light(),
      config: config,
      docxTheme: DocxTheme.empty(),
    );
    measurer = TextMeasurer(spanFactory: sf);
    paginator = Paginator(measurer: measurer, config: config);
  });

  tearDown(() => measurer.dispose());

  test('first block on a page loses its space-before; later blocks keep it',
      () {
    final res = paginator.paginate(DocxBuiltDocument(elements: [
      DocxParagraph(spacingBefore: 240, children: [DocxText('A')]),
      DocxParagraph(spacingBefore: 240, children: [DocxText('B')]),
    ]));

    final slices = res.pages.first.slices;
    expect((slices[0].block as DocxParagraph).spacingBefore, 0,
        reason: 'first block on the page is flush to the top margin');
    expect((slices[1].block as DocxParagraph).spacingBefore, 240,
        reason: 'a mid-page block keeps its before-spacing');
  });

  test('a paragraph forced to a new page is suppressed at its top', () {
    // pageBreakBefore guarantees the second paragraph opens page 2, so it is the
    // first block there and its before-spacing must be dropped.
    final res = paginator.paginate(DocxBuiltDocument(elements: [
      DocxParagraph(children: [DocxText('first')]),
      DocxParagraph(
        pageBreakBefore: true,
        spacingBefore: 240,
        children: [DocxText('TOP_OF_P2')],
      ),
    ]));

    expect(res.pages.length, 2);
    final p2first = res.pages[1].slices.first.block as DocxParagraph;
    expect(p2first.spacingBefore, 0,
        reason: 'a block forced to the top of a new page is suppressed too');
  });
}
