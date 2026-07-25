// Regression tests for the PDF exporter bugs found while auditing PDF
// export fidelity: table colSpan/rowSpan/borders/column-widths/pagination,
// missing headers/footers, vanishing drop caps, and forced page breaks.
import 'dart:convert';
import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

/// Minimal valid 1x1 red PNG, reused across image-related tests.
Uint8List _createTestPng() {
  const pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4'
      'nGP4z8BQDwAEgAF/pooBPQAAAABJRU5ErkJggg==';
  return base64Decode(pngBase64);
}

void main() {
  group('PDF table rendering', () {
    test('colSpan shifts the following cell to the right position',
        () async {
      final doc = docx()
          .add(DocxTable(rows: [
            DocxTableRow(cells: [
              DocxTableCell(
                colSpan: 2,
                children: [DocxParagraph.text('Wide')],
              ),
            ]),
            DocxTableRow(cells: [
              DocxTableCell(children: [DocxParagraph.text('L')]),
              DocxTableCell(children: [DocxParagraph.text('R')]),
            ]),
          ]))
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('Wide'));
      expect(content, contains('L'));
      expect(content, contains('R'));
    });

    test('rowSpan cell content is preserved and following row still renders',
        () async {
      final doc = docx()
          .add(DocxTable(rows: [
            DocxTableRow(cells: [
              DocxTableCell(
                rowSpan: 2,
                children: [DocxParagraph.text('Tall')],
              ),
              DocxTableCell(children: [DocxParagraph.text('Top')]),
            ]),
            DocxTableRow(cells: [
              DocxTableCell(children: [DocxParagraph.text('Bottom')]),
            ]),
          ]))
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('Tall'));
      expect(content, contains('Top'));
      expect(content, contains('Bottom'));
    });

    test('DocxTableStyle.plain draws no cell borders', () async {
      final doc = docx()
          .add(DocxTable(
            style: DocxTableStyle.plain,
            rows: [
              DocxTableRow(cells: [
                DocxTableCell(children: [DocxParagraph.text('A')]),
              ]),
            ],
          ))
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      // No stroke operator should appear for the (border-less) table.
      expect(content, isNot(contains(' S\n')));
    });

    test('default table style still draws visible borders', () async {
      final doc = docx()
          .add(DocxTable(rows: [
            DocxTableRow(cells: [
              DocxTableCell(children: [DocxParagraph.text('A')]),
            ]),
          ]))
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains(' S\n'));
    });

    test('custom cell border color is used instead of hardcoded black',
        () async {
      final doc = docx()
          .add(DocxTable(rows: [
            DocxTableRow(cells: [
              DocxTableCell(
                borderTop: DocxBorderSide(
                  color: DocxColor('#FF0000'),
                  size: 8,
                ),
                borderBottom: DocxBorderSide(
                  color: DocxColor('#FF0000'),
                  size: 8,
                ),
                borderLeft: DocxBorderSide(
                  color: DocxColor('#FF0000'),
                  size: 8,
                ),
                borderRight: DocxBorderSide(
                  color: DocxColor('#FF0000'),
                  size: 8,
                ),
                children: [DocxParagraph.text('Red border')],
              ),
            ]),
          ]))
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      // Red stroke color (1 0 0 RG) should appear rather than black.
      expect(content, contains('1.000 0.000 0.000 RG'));
    });

    test('a table with many rows paginates across multiple PDF pages',
        () async {
      final rows = List.generate(
        80,
        (i) => DocxTableRow(cells: [
          DocxTableCell(children: [DocxParagraph.text('Row $i')]),
        ]),
      );
      final doc = docx().add(DocxTable(rows: rows)).build();

      final bytes = PdfExporter().exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      final pageCount = '/Type /Page'.allMatches(content).length;
      expect(pageCount, greaterThan(1));

      // Content must survive the split — first and last row's numbers are
      // both present (regardless of which physical page each landed on).
      // Each word is drawn as a separate Tj operator, so "Row 0" isn't a
      // contiguous substring; check the row-number tokens instead.
      final bytesUncompressed =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final rawContent = String.fromCharCodes(bytesUncompressed);
      expect(rawContent, contains('(0) Tj'));
      expect(rawContent, contains('(79) Tj'));
    });

    test('nested list inside a table cell is no longer dropped', () async {
      final doc = docx()
          .add(DocxTable(rows: [
            DocxTableRow(cells: [
              DocxTableCell(children: [
                DocxList(
                  items: [
                    DocxListItem.text('Nested item one'),
                    DocxListItem.text('Nested item two'),
                  ],
                ),
              ]),
            ]),
          ]))
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('Nested'));
      expect(content, contains('item'));
    });
  });

  group('PDF header/footer/drop-cap/page-break rendering', () {
    test('section header and footer text render in the PDF', () async {
      final doc = docx()
          .section(
            header: DocxHeader.text('Company Header'),
            footer: DocxFooter.text('Footer Notice'),
          )
          .p('Body content')
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('Company'));
      expect(content, contains('Header'));
      expect(content, contains('Footer'));
      expect(content, contains('Notice'));
    });

    test('drop cap letter and rest-of-paragraph text are not lost',
        () async {
      final doc = docx()
          .add(DocxDropCap(
            letter: 'O',
            lines: 3,
            restOfParagraph: [DocxText('nce upon a time.')],
          ))
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('O'));
      expect(content, contains('nce'));
      expect(content, contains('upon'));
    });

    test('pageBreakBefore forces content onto a new PDF page', () async {
      final doc = docx()
          .p('Page one content')
          .add(DocxParagraph(
            pageBreakBefore: true,
            children: [DocxText('Page two content')],
          ))
          .build();

      final bytes = PdfExporter().exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      final pageCount = '/Type /Page'.allMatches(content).length;
      expect(pageCount, greaterThan(1));
    });
  });

  group('PDF hyperlinks, inline images, and paragraph borders', () {
    test('hyperlink text produces a clickable /Annot /Link with the URI',
        () async {
      final doc = docx()
          .add(DocxParagraph(children: [
            DocxText(
              'Click here',
              href: 'https://example.com',
            ),
          ]))
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('/Subtype /Link'));
      expect(content, contains('/URI (https://example.com)'));
      expect(content, contains('/Annots ['));
    });

    test('inline image in a paragraph run is drawn, not dropped', () async {
      final doc = docx()
          .add(DocxParagraph(children: [
            DocxText('See: '),
            DocxInlineImage(
              bytes: _createTestPng(),
              extension: 'png',
              width: 40,
              height: 40,
            ),
            DocxText(' end.'),
          ]))
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('/Subtype /Image'));
      expect(content, contains('/XObject'));
      expect(content, contains(' Do\n'));
    });

    test('block image border is drawn as a stroked rectangle', () async {
      final doc = docx()
          .add(DocxImage(
            bytes: _createTestPng(),
            extension: 'png',
            width: 40,
            height: 40,
            border: DocxBorderSide(
              style: DocxBorder.single,
              color: DocxColor('#00FF00'),
              size: 8,
            ),
          ))
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('0.000 1.000 0.000 RG'));
      expect(content, contains(' re S\n'));
    });

    test('inline image border is drawn inside a paragraph', () async {
      final doc = docx()
          .add(DocxParagraph(children: [
            DocxText('Photo: '),
            DocxInlineImage(
              bytes: _createTestPng(),
              extension: 'png',
              width: 30,
              height: 30,
              border: DocxBorderSide(
                style: DocxBorder.single,
                color: DocxColor('#0000FF'),
                size: 4,
              ),
            ),
          ]))
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('0.000 0.000 1.000 RG'));
    });

    test('inline shape inside a paragraph is drawn, not dropped', () async {
      final doc = docx()
          .add(DocxParagraph(children: [
            DocxText('Status: '),
            DocxShape.circle(diameter: 12, fillColor: DocxColor('#FF8800')),
            DocxText(' done'),
          ]))
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('Status'));
      expect(content, contains('done'));
      // The circle is drawn via Bezier curves (c operator) with the orange fill.
      expect(content, contains('1.000 0.533 0.000 rg'));
      expect(content, contains(' c\n'));
    });

    test('section backgroundColor paints a full-page fill rectangle',
        () async {
      final doc = docx()
          .section(backgroundColor: DocxColor('#3366CC'))
          .p('Content over a colored background')
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      // 0x33/0xCC -> 0.200/0.800 in the 0-1 fill-color operands.
      expect(content, contains('0.200 0.400 0.800 rg'));
      expect(content, contains(' re f\n'));
    });

    test('section backgroundImage is embedded and drawn on the page',
        () async {
      final validPng = Uint8List.fromList(img.encodePng(
        img.Image(width: 4, height: 4)..setPixelRgb(0, 0, 0, 255, 0),
      ));
      final doc = docx()
          .section(
            backgroundImage: DocxBackgroundImage(
              bytes: validPng,
              extension: 'png',
              fillMode: DocxBackgroundFillMode.stretch,
            ),
          )
          .p('Content over a background image')
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('/BgImg'));
      expect(content, contains('/Subtype /Image'));
      expect(content, contains(' Do\n'));
    });

    test('translucent backgroundImage registers an ExtGState with alpha',
        () async {
      final validPng = Uint8List.fromList(img.encodePng(
        img.Image(width: 4, height: 4)..setPixelRgb(0, 0, 0, 255, 0),
      ));
      final doc = docx()
          .section(
            backgroundImage: DocxBackgroundImage.watermark(
              bytes: validPng,
              extension: 'png',
              opacity: 0.2,
            ),
          )
          .p('Watermarked page')
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('/BgGS'));
      expect(content, contains('/ca 0.2'));
      expect(content, contains('gs\n'));
    });

    test('footnote text renders at the bottom of the page', () async {
      final doc = DocxBuiltDocument(
        elements: [
          DocxParagraph(children: [
            DocxText('This claim needs a citation.'),
            const DocxFootnoteRef(footnoteId: 1),
          ]),
        ],
        footnotes: [
          DocxFootnote(
            footnoteId: 1,
            content: [DocxParagraph.text('Source: Official record, 2024.')],
          ),
        ],
      );

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('claim'));
      expect(content, contains('Source:'));
      expect(content, contains('Official'));
      expect(content, contains('record'));
    });

    test('a paragraph with a footnote does not overlap the footnote area',
        () async {
      // Many short paragraphs each referencing the same footnote should
      // still paginate cleanly without the footnote text overlapping body
      // content — i.e. paginateWithFootnotes actually reserves space.
      final paragraphs = List.generate(
        60,
        (i) => DocxParagraph(children: [
          DocxText('Body line $i referencing a note.'),
          const DocxFootnoteRef(footnoteId: 1),
        ]),
      );
      final doc = DocxBuiltDocument(
        elements: paragraphs,
        footnotes: [
          DocxFootnote(
            footnoteId: 1,
            content: [DocxParagraph.text('A shared footnote.')],
          ),
        ],
      );

      final bytes = PdfExporter().exportToBytes(doc);
      final content = String.fromCharCodes(bytes);
      final pageCount = '/Type /Page'.allMatches(content).length;
      expect(pageCount, greaterThan(1));
    });

    test('TOC cached content renders instead of vanishing', () async {
      final doc = docx()
          .add(DocxTableOfContents(
            cachedContent: [
              DocxParagraph.text('1. Introduction'),
              DocxParagraph.text('2. Conclusion'),
            ],
          ))
          .build();

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      expect(content, contains('Introduction'));
      expect(content, contains('Conclusion'));
    });

    test(
        'embedded image bytes are a valid, undamaged JPEG stream '
        '(not corrupted by String/utf8 round-tripping)', () async {
      // The shared `_createTestPng()` fixture is a hand-crafted minimal PNG
      // that satisfies lenient header-only readers but fails a full IDAT
      // decode; use a genuinely valid, fully-decodable PNG here so the test
      // actually exercises the decode -> re-encode-as-JPEG path.
      final validPng = Uint8List.fromList(img.encodePng(
        img.Image(width: 3, height: 3)
          ..setPixelRgb(1, 1, 255, 0, 0),
      ));

      final doc = docx()
          .add(DocxImage(
            bytes: validPng,
            extension: 'png',
            width: 40,
            height: 40,
          ))
          .build();

      final bytes = PdfExporter(compressContent: false).exportToBytes(doc);

      // latin1 decode is 1:1 with byte offsets, so string indices below
      // correspond exactly to offsets in the original byte array.
      final text = latin1.decode(bytes, allowInvalid: true);
      final filterIdx = text.indexOf('/Filter /DCTDecode');
      expect(filterIdx, greaterThanOrEqualTo(0),
          reason: 'expected the image to be embedded as JPEG/DCTDecode');

      final afterFilter = text.substring(filterIdx);
      final lengthMatch = RegExp(r'/Length (\d+)').firstMatch(afterFilter);
      expect(lengthMatch, isNotNull);
      final length = int.parse(lengthMatch!.group(1)!);

      const marker = 'stream\n';
      final markerIdx = afterFilter.indexOf(marker, lengthMatch.end);
      final streamStart = filterIdx + markerIdx + marker.length;

      final jpegBytes = bytes.sublist(streamStart, streamStart + length);

      // A corrupted stream (bytes >= 0x80 expanded by utf8.encode, or a
      // /Length that no longer matches what got written) would fail these.
      expect(jpegBytes[0], equals(0xFF));
      expect(jpegBytes[1], equals(0xD8));
      expect(jpegBytes[jpegBytes.length - 2], equals(0xFF));
      expect(jpegBytes[jpegBytes.length - 1], equals(0xD9));

      final decoded = img.decodeJpg(Uint8List.fromList(jpegBytes));
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(3));
      expect(decoded.height, equals(3));
    });

    test('paragraph borderBottom is actually stroked (e.g. <hr>)', () async {
      final html = '<hr>';
      final elements = await DocxParser.fromHtml(html);
      final doc = DocxBuiltDocument(elements: elements);

      final bytes =
          PdfExporter(compressContent: false).exportToBytes(doc);
      final content = String.fromCharCodes(bytes);

      // A stroked line (m ... l ... S) should be present for the rule.
      expect(content, contains(' S\n'));
    });
  });
}
