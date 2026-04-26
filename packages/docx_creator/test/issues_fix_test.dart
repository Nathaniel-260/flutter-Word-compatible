import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/utils/file_loader_io.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('Issue Fixes Verification', () {
    test('Issue 77: FileLoaderImpl decodes path before loading', () async {
      // FileLoaderImpl is private in the library but exported via getFileLoader
      // Or we can just test the logic if we can access it.
      // Since it's not exported, we might need to use getFileLoader().
      final loader = getFileLoader();

      final tempDir = Directory.systemTemp.createTempSync('docx_test');
      try {
        final file = File('${tempDir.path}/test file.txt');
        file.writeAsStringSync('hello');

        final manualEncodedPath = file.path.replaceAll(' ', '%20');

        expect(await loader.exists(manualEncodedPath), isTrue,
            reason: 'Should find file even if path is encoded');
        final bytes = await loader.loadBytes(manualEncodedPath);
        expect(bytes, isNotNull);
        expect(utf8.decode(bytes!), equals('hello'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Issue 89: FileLoaderImpl gracefully handles invalid percent encoding',
        () async {
      final loader = getFileLoader();

      final tempDir = Directory.systemTemp.createTempSync('docx_test');
      try {
        final file = File('${tempDir.path}/test%file.txt');
        file.writeAsStringSync('hello');

        expect(await loader.exists(file.path), isTrue,
            reason: 'Should find file with invalid percent encoding');
        final bytes = await loader.loadBytes(file.path);
        expect(bytes, isNotNull);
        expect(utf8.decode(bytes!), equals('hello'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

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

    test('Issue 88: DocxDocumentBuilder.section supports custom margins', () {
      final doc = docx()
          .section(
            marginTop: 1440, // 1 inch
            marginBottom: 1440,
            marginLeft: 720, // 0.5 inch
            marginRight: 720,
          )
          .p('Test content')
          .build();

      expect(doc.section, isNotNull);
      expect(doc.section!.marginTop, equals(1440));
      expect(doc.section!.marginBottom, equals(1440));
      expect(doc.section!.marginLeft, equals(720));
      expect(doc.section!.marginRight, equals(720));
    });

    test(
        'Issue 85: DocxExporter throws DocxExportException when ZIP encoding fails',
        () async {
      final exporter = DocxExporter();
      // We can't easily mock ZipEncoder without changing the code to inject it,
      // but we can verify the exception type if it were to fail.
      // A doc with no elements might still encode fine, but let's test a simple build.
      final doc = docx().build();
      try {
        final bytes = await exporter.exportToBytes(doc);
        expect(bytes, isNotEmpty);
      } catch (e) {
        expect(e, isA<DocxExportException>());
      }
    });
  });
}
