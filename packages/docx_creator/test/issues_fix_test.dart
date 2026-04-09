import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('Issue Fixes Verification', () {
    test('Issue 82: Table contains w:tcW when gridColumns is set', () {
      final table = DocxTable(
        gridColumns: [1000, 3000],
        rows: [
          DocxTableRow(cells: [
            DocxTableCell.text('Cell 1'), // width is null
            DocxTableCell.text('Cell 2'), // width is null
          ]),
        ],
      );

      final builder = XmlBuilder();
      table.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('w:tcW'), reason: 'w:tcW should be present');
      expect(xml, contains('w:w="1000"'),
          reason: 'First cell should have width 1000');
      expect(xml, contains('w:w="3000"'),
          reason: 'Second cell should have width 3000');
    });

    test('Issue 72: DocxParagraph factories support textAlignment', () {
      final p =
          DocxParagraph.text('Hello', textAlignment: DocxTextAlignment.center);

      final builder = XmlBuilder();
      p.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('<w:textAlignment w:val="center"/>'));
    });

    test('Issue 72: DocxTableCell.text support textAlignment', () {
      final cell =
          DocxTableCell.text('Hello', textAlignment: DocxTextAlignment.bottom);

      final builder = XmlBuilder();
      cell.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('<w:textAlignment w:val="bottom"/>'));
    });

    test(
        'Issue 80: Images in header, footer, docxlist, and duplicates generate correct .rels files',
        () async {
      final imgBytes = Uint8List.fromList([1, 2, 3]);
      final sharedImage = DocxImage(
        bytes: imgBytes,
        extension: 'png',
        width: 100,
        height: 100,
      );

      final doc = DocxBuiltDocument(
        elements: [
          // Body with a list containing the image
          DocxList(items: [
            DocxListItem([sharedImage.asInline])
          ]),
          // Duplicate image in body
          DocxParagraph(children: [sharedImage.asInline]),
        ],
        section: DocxSectionDef(
          header: DocxHeader(
            children: [sharedImage],
          ),
          footer: DocxFooter(
            children: [
              sharedImage,
              sharedImage, // Duplicate in footer
            ],
          ),
        ),
      );

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);

      final archive = ZipDecoder().decodeBytes(bytes);

      // Check header
      final headerFile = archive.findFile('word/header1.xml');
      final headerRelsFile = archive.findFile('word/_rels/header1.xml.rels');
      expect(headerFile, isNotNull, reason: 'header1.xml should exist');
      expect(headerRelsFile, isNotNull,
          reason: 'header1.xml.rels should exist for images');

      // Check footer
      final footerFile = archive.findFile('word/footer1.xml');
      final footerRelsFile = archive.findFile('word/_rels/footer1.xml.rels');
      expect(footerFile, isNotNull, reason: 'footer1.xml should exist');
      expect(footerRelsFile, isNotNull,
          reason: 'footer1.xml.rels should exist for images');

      // Check document
      final documentRelsFile = archive.findFile('word/_rels/document.xml.rels');
      expect(documentRelsFile, isNotNull,
          reason: 'document.xml.rels should exist');

      final footerRelsXml = String.fromCharCodes(footerRelsFile!.content);
      expect(
          footerRelsXml,
          contains(
              'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"'));
      expect(footerRelsXml, contains('Target="media/image1.png"'));

      // Ensure deduplication by counting relationships in footerRelsXml
      final relMatches = '<Relationship '.allMatches(footerRelsXml).length;
      expect(relMatches, equals(1),
          reason: 'Should have exactly 1 image relationship');
    });
  });
}
