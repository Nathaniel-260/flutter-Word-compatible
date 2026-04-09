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

    test('Issue 80: Images in footer generate .rels file', () async {
      final doc = DocxBuiltDocument(
        elements: [DocxParagraph.text('Body')],
        section: DocxSectionDef(
          footer: DocxFooter(
            children: [
              DocxImage(
                bytes: Uint8List.fromList([1, 2, 3]),
                extension: 'png',
                width: 100,
                height: 100,
              ),
            ],
          ),
        ),
      );

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);

      final archive = ZipDecoder().decodeBytes(bytes);

      final footerFile = archive.findFile('word/footer1.xml');
      final footerRelsFile = archive.findFile('word/_rels/footer1.xml.rels');

      expect(footerFile, isNotNull, reason: 'footer1.xml should exist');
      expect(footerRelsFile, isNotNull,
          reason: 'footer1.xml.rels should exist for images');

      final relsXml = String.fromCharCodes(footerRelsFile!.content);
      expect(
          relsXml,
          contains(
              'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"'));
      expect(relsXml, contains('Target="media/image1.png"'));
    });
  });
}
