import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/float_layout.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/pagination/paginator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §H.2 — float integration into measurement + pagination.
const double _pageW = 600;
const double _pageH = 400;
const double _contentW = _pageW - 96 - 96; // 408

void main() {
  late DocxViewConfig config;
  late TextMeasurer measurer;
  late Paginator paginator;

  setUp(() {
    config = const DocxViewConfig(pageWidth: _pageW, pageHeight: _pageH);
    final spanFactory = SpanFactory(
      theme: DocxViewTheme.light(),
      config: config,
      docxTheme: DocxTheme.empty(),
    );
    measurer = TextMeasurer(spanFactory: spanFactory);
    paginator = Paginator(measurer: measurer, config: config);
  });

  DocxInlineImage floatImg(DocxTextWrap wrap, {DrawingHAlign? hAlign}) =>
      DocxInlineImage(
        bytes: _gif(),
        extension: 'gif',
        width: 100,
        height: 100, // 100pt → ~133px
        positionMode: DocxDrawingPosition.floating,
        textWrap: wrap,
        hAlign: hAlign,
      );

  group('measurement excludes floating drawings from the text span', () {
    test('no floating image (any wrap) adds inline height to its paragraph',
        () {
      // Every floating drawing is placed out of the text flow — a side float by
      // the band-aware wrap (§8.2 #29), a full-width float as a reserved band, a
      // layer float as a back/front layer — so none inflate the measured text
      // span. Their footprint is added by the paginator (band / wrap height).
      final plain = DocxParagraph(children: [DocxText('hello world')]);
      final plainH = measurer.measureParagraph(plain, _contentW).totalHeight;
      for (final wrap in [
        DocxTextWrap.square,
        DocxTextWrap.topAndBottom,
        DocxTextWrap.behindText,
        DocxTextWrap.inFrontOfText,
      ]) {
        final withFloat = DocxParagraph(children: [
          DocxText('hello world'),
          floatImg(wrap, hAlign: DrawingHAlign.right),
        ]);
        expect(
          measurer.measureParagraph(withFloat, _contentW).totalHeight,
          plainH,
          reason: 'wrap=$wrap must not add inline height',
        );
      }
    });
  });

  group('paginator records floats', () {
    test('a side float is recorded with a side-flow rect, no reservation', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph(children: [
          DocxText('anchor'),
          floatImg(DocxTextWrap.square, hAlign: DrawingHAlign.right),
        ]),
        for (var i = 0; i < 20; i++)
          DocxParagraph(children: [DocxText('line $i')]),
      ]);
      final res = paginator.paginate(doc);
      final p1 = res.pages.first;
      expect(p1.floats.length, 1);
      expect(p1.floats.first.rect.flow, FloatFlow.side);
      // Right-aligned → hugs the right content edge.
      expect(p1.floats.first.rect.right, closeTo(_contentW, 0.5));
    });
  });

  group('topAndBottom reserves vertical space', () {
    DocxBuiltDocument docWith(DocxParagraph head) =>
        DocxBuiltDocument(elements: [
          head,
          for (var i = 0; i < 30; i++)
            DocxParagraph(children: [DocxText('line $i')]),
        ]);

    test('a topAndBottom float pushes following blocks down', () {
      final plain = paginator
          .paginate(docWith(DocxParagraph(children: [DocxText('anchor')])));
      // Fresh paginator state per call.
      final tb = paginator.paginate(docWith(DocxParagraph(children: [
        DocxText('anchor'),
        floatImg(DocxTextWrap.topAndBottom),
      ])));

      final plainFirst = plain.pages.first.slices.length;
      final tbFirst = tb.pages.first.slices.length;
      expect(tb.pages.first.floats.single.rect.flow, FloatFlow.fullWidth);
      // The ~133px float band leaves room for fewer body lines on page 1.
      expect(tbFirst, lessThan(plainFirst));
    });

    test('a tall side float reduces the first-page line count', () {
      // A side float is rendered in-flow (text beside it), so a ~133px float in a
      // short paragraph makes that paragraph ~133px tall — fewer body lines fit
      // on page 1, matching the rendered layout. Guards the measure≡render hole.
      final plain = paginator
          .paginate(docWith(DocxParagraph(children: [DocxText('anchor')])));
      final side = paginator.paginate(docWith(DocxParagraph(children: [
        DocxText('anchor'),
        floatImg(DocxTextWrap.square, hAlign: DrawingHAlign.left),
      ])));
      expect(side.pages.first.slices.length,
          lessThan(plain.pages.first.slices.length));
    });
  });
}

Uint8List _gif() => Uint8List.fromList([
      0x47, 0x49, 0x46, 0x38, 0x39, 0x61, //
      0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00,
      0xff, 0xff, 0xff, 0x00, 0x00, 0x00,
      0x21, 0xf9, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
      0x02, 0x02, 0x44, 0x01, 0x00, 0x3b,
    ]);
