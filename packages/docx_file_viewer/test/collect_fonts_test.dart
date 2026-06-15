import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/docx_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// QA F10: font families that live *only* in footnotes/endnotes must still be
/// collected, so their real system line-metrics get registered (otherwise such
/// a family falls back to the default line height).
void main() {
  DocxParagraph runWithFont(String family) =>
      DocxParagraph(children: [DocxText('x', fontFamily: family)]);

  test('collects families that appear only in footnotes and endnotes', () {
    final doc = DocxBuiltDocument(
      elements: [runWithFont('BodyFont')],
      footnotes: [
        DocxFootnote(footnoteId: 1, content: [runWithFont('FootnoteOnlyFont')]),
      ],
      endnotes: [
        DocxEndnote(endnoteId: 1, content: [runWithFont('EndnoteOnlyFont')]),
      ],
    );

    final families = collectDocumentFontFamilies(doc);

    expect(families, contains('BodyFont'));
    expect(families, contains('FootnoteOnlyFont'),
        reason: 'a family used only in a footnote must be collected (F10)');
    expect(families, contains('EndnoteOnlyFont'),
        reason: 'a family used only in an endnote must be collected (F10)');
  });

  test('seeds the set with the configured fallbacks (extra)', () {
    final doc = DocxBuiltDocument(elements: [runWithFont('BodyFont')]);
    final families =
        collectDocumentFontFamilies(doc, extra: const ['FallbackFont']);
    expect(families, containsAll(['BodyFont', 'FallbackFont']));
  });
}
