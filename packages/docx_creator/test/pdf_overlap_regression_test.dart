import 'dart:convert';
import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/exporters/pdf/pdf_layout_engine.dart';
import 'package:docx_creator/src/utils/image_resolver.dart';
import 'package:test/test.dart';

/// A 1x1 transparent PNG, small enough to embed as a literal but a real,
/// decodable raster image (unlike raw text/SVG bytes).
const _base64Png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  group('PdfLayoutEngine paragraph height accounts for inline media', () {
    test('a paragraph with a tall inline image measures at least that tall',
        () {
      final engine = PdfLayoutEngine(pageWidth: 612, pageHeight: 792);
      final withImage = DocxParagraph(children: [
        DocxText('See: '),
        DocxInlineImage(
            bytes: Uint8List(0), extension: 'png', width: 40, height: 300),
        DocxText(' above.'),
      ]);
      final plain = DocxParagraph(children: [DocxText('See: above.')]);

      final imageHeight = engine.measureParagraph(withImage);
      final plainHeight = engine.measureParagraph(plain);

      // Previously measureParagraph only ever looked at DocxText/
      // DocxLineBreak/DocxTab, so a paragraph's inline image contributed
      // nothing at all to its measured height - pagination would reserve
      // only a single text line's worth of space no matter how tall the
      // image actually was.
      expect(imageHeight, greaterThanOrEqualTo(300));
      expect(imageHeight, greaterThan(plainHeight));
    });

    test('a paragraph with a tall inline shape measures at least that tall',
        () {
      final engine = PdfLayoutEngine(pageWidth: 612, pageHeight: 792);
      final withShape = DocxParagraph(children: [
        DocxText('Look: '),
        DocxShape.rectangle(width: 30, height: 250),
      ]);

      expect(engine.measureParagraph(withShape), greaterThanOrEqualTo(250));
    });
  });

  group('PdfExporter renders inline media without overlapping following '
      'content', () {
    test('a paragraph after one containing a tall inline image starts below '
        'the image, not inside it', () {
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph(children: [
          DocxText('Badge: '),
          DocxInlineImage(
              bytes: Uint8List(0), extension: 'png', width: 40, height: 150),
        ]),
        DocxParagraph.text('MARKERTEXT should be clear of the image above.'),
      ]);

      final bytes = PdfExporter(compressContent: false).exportToBytes(doc);
      final content = latin1.decode(bytes, allowInvalid: true);

      // The image is drawn via "<w> 0 0 <h> <x> <y> cm" immediately
      // followed by a "/ImN Do" - pull out its bottom-left y and height.
      final imageMatch =
          RegExp(r'([\d.]+) 0 0 ([\d.]+) ([\d.]+) ([\d.]+) cm\s*/Im1 Do')
              .firstMatch(content);
      expect(imageMatch, isNotNull,
          reason: 'expected to find the inline image draw operator');
      final imageH = double.parse(imageMatch!.group(2)!);
      final imageY = double.parse(imageMatch.group(4)!);
      final imageTop = imageY + imageH;

      // The marker paragraph's own text line: find its "Tm" (text matrix)
      // y right before its "Tj".
      final markerMatch = RegExp(
              r'1 0 0 1 [\d.]+ ([\d.]+) Tm[\s\S]{0,60}?\(MARKERTEXT\) Tj')
          .firstMatch(content);
      expect(markerMatch, isNotNull,
          reason: 'expected to find the marker paragraph\'s text operator');
      final markerY = double.parse(markerMatch!.group(1)!);

      // Previously the line-height reserved after a line containing an
      // inline image ignored the image's own height entirely (it only
      // looked at word.fontSize), so the cursor advanced by one ordinary
      // text line and the next paragraph was drawn starting well inside
      // the image instead of below it. The marker's baseline must be at
      // or below the image's bottom edge (PDF y increases upward, so
      // "below" is a smaller y) - never above the image's top.
      expect(markerY, lessThan(imageTop),
          reason: 'marker text must not be drawn inside/above the image');
    });
  });

  group('Table cells mixing a fallback-only character with plain text wrap '
      'consistently between measurement and rendering', () {
    test('measureRowHeight reserves enough height for the actual number of '
        'wrapped lines the renderer produces', () {
      // A run mixing an emoji (forces the whole run through the wider
      // Unicode fallback font at render time - see
      // PdfExporter._withUnicodeFallback, which decides per DocxText run,
      // not per word) with enough plain ASCII text that it's borderline
      // whether it fits on one line using the *plain* metrics measurement
      // used to (incorrectly) use. If measurement doesn't know some of
      // this text renders wider than plain metrics say, it under-reserves
      // and the wrapped second line spills into the row below.
      final cell = DocxTableCell(children: [
        DocxParagraph(children: [
          DocxText('✅ this line of plain text is long enough that '
              'wrapping is sensitive to font metrics'),
        ]),
      ]);
      final table = DocxTable(rows: [
        DocxTableRow(cells: [cell]),
      ]);

      final engine = PdfLayoutEngine(pageWidth: 400, pageHeight: 792);
      final colWidths = engine.tableColumnWidths(table);
      final measuredRowHeight =
          engine.measureRowHeight(table.rows.first, colWidths);

      // Render the same cell content standalone and count how many
      // separate text-matrix positions (i.e. wrapped lines) actually get
      // drawn for it, then check the measured row height is tall enough
      // to hold that many lines without any of them landing below the
      // measured box.
      final bytes = PdfExporter(compressContent: false)
          .exportToBytes(DocxBuiltDocument(elements: [table]));
      final content = latin1.decode(bytes, allowInvalid: true);
      final lineYs = RegExp(r'1 0 0 1 [\d.]+ ([\d.]+) Tm')
          .allMatches(content)
          .map((m) => double.parse(m.group(1)!))
          .toSet();
      final renderedLineCount = lineYs.length;

      final fontSize = engine.getFontSize(null);
      final lineHeight = fontSize * 1.4;
      final minHeightForRenderedLines = renderedLineCount * lineHeight;

      expect(measuredRowHeight, greaterThanOrEqualTo(minHeightForRenderedLines),
          reason: 'row must reserve enough height for every line the '
              'renderer actually draws, or later lines spill past the '
              'row border into whatever is drawn next');
    });
  });

  group('ImageResolver rejects non-decodable "image" bytes', () {
    test('a data URI whose payload is not a real raster image resolves to '
        'null instead of being passed through as garbage', () async {
      // SVG (or any non-raster payload) mislabeled with an image/* MIME
      // type is a common real-world case (e.g. shields.io badges). Bytes
      // that aren't decodable must not reach callers, who would otherwise
      // embed them at a guessed size with no relation to their real byte
      // count - producing solid garbage where a real image should be.
      final svgBytes = utf8.encode('<svg xmlns="http://www.w3.org/2000/svg">'
          '<rect width="1" height="1"/></svg>');
      final dataUri = 'data:image/png;base64,${base64Encode(svgBytes)}';

      final result = await ImageResolver.resolve(dataUri);
      expect(result, isNull);
    });

    test('a real decodable PNG still resolves normally', () async {
      final dataUri = 'data:image/png;base64,$_base64Png';
      final result = await ImageResolver.resolve(dataUri);
      expect(result, isNotNull);
    });
  });

  group('PDF font names are always syntactically valid PDF name objects', () {
    test('a fallback font name containing spaces/parentheses is hex-escaped, '
        'not written through raw', () {
      // Triggers PdfFontManager.fallbackUnicodeFontRef, whose display name
      // is 'DejaVu Sans (docx_creator fallback)' - contains both spaces and
      // parentheses, which are PDF name delimiters and must be escaped as
      // #XX or they split the /Font dictionary into a stray extra literal
      // string object, corrupting everything that follows it in that
      // dictionary.
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph.text('emoji ✅ next to plain text'),
      ]);

      final bytes = PdfExporter(compressContent: false).exportToBytes(doc);
      final content = latin1.decode(bytes, allowInvalid: true);

      expect(content, contains('/FontName /DejaVu#20Sans'));
      // A raw, unescaped '(' immediately after a font name would indicate
      // the old bug reappeared.
      expect(content, isNot(contains('/FontName /DejaVu Sans (')));
    });

    test('every font referenced by a "Tf" operator in a page\'s content '
        'stream is present in that page\'s own /Resources /Font dict', () {
      // Regression for fonts embedded lazily during rendering (e.g. the
      // Unicode fallback font, only embedded the first time a
      // fallback-needing character is actually encountered) never being
      // written to the PDF at all, because font objects were previously
      // written *before* rendering happened.
      final doc = DocxBuiltDocument(elements: [
        DocxParagraph.text('plain text first'),
        DocxParagraph.text('then an emoji ✅ forces the fallback font'),
      ]);

      final bytes = PdfExporter(compressContent: false).exportToBytes(doc);
      final content = latin1.decode(bytes, allowInvalid: true);

      final pageMatch =
          RegExp(r'/Type /Page\b[\s\S]*?/Contents (\d+) 0 R[\s\S]*?/Font <<([\s\S]*?)>>')
              .firstMatch(content);
      expect(pageMatch, isNotNull);
      final pageFontDict = pageMatch!.group(2)!;
      final pageFontRefs = RegExp(r'(/F\d+) \d+ 0 R')
          .allMatches(pageFontDict)
          .map((m) => m.group(1)!)
          .toSet();

      final contentObjId = pageMatch.group(1)!;
      final streamMatch =
          RegExp('\n$contentObjId 0 obj[\\s\\S]*?stream\\n([\\s\\S]*?)endstream')
              .firstMatch(content);
      expect(streamMatch, isNotNull);
      final pageContent = streamMatch!.group(1)!;
      final usedFontRefs = RegExp(r'(/F\d+) [\d.]+ Tf')
          .allMatches(pageContent)
          .map((m) => m.group(1)!)
          .toSet();

      expect(usedFontRefs, isNotEmpty);
      for (final ref in usedFontRefs) {
        expect(pageFontDict, contains(ref),
            reason: '$ref is used via Tf in the content stream but missing '
                'from this page\'s /Resources /Font dict ($pageFontRefs)');
      }
    });
  });
}
