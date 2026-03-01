import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('Hotfix Tests (Issues #72, #73, #74)', () {
    test('Issue #72: DocxParagraph textAlignment generates correct XML', () {
      final paragraph = DocxParagraph(
        textAlignment: DocxTextAlignment.center,
        children: [DocxText('Aligned Text')],
      );

      final builder = XmlBuilder();
      paragraph.buildXml(builder);
      final xml = builder.buildDocument().toXmlString(pretty: true);

      expect(xml, contains('<w:textAlignment w:val="center"/>'));
    });

    test('Issue #73: Exporter uses w:type="default" for headerReference',
        () async {
      final doc = docx().section(
        header: DocxHeader(
          children: [DocxParagraph.text('Header Text')],
        ),
      );
      final builtDoc = doc.build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(builtDoc);

      // Verify the generated Document.xml from the ZIP
      final archive = _getArchive(bytes);
      final documentFile = archive.findFile('word/document.xml');
      expect(documentFile, isNotNull);

      final xmlString = String.fromCharCodes(documentFile!.content);
      expect(xmlString,
          contains('<w:headerReference w:type="default" r:id="rId5"/>'));
    });

    test('Issue #74: DocxTableRow generates w:hRule="exact" when height is set',
        () {
      final row = DocxTableRow(
        height: 500,
        cells: [
          DocxTableCell(children: [DocxParagraph.text('Cell 1')])
        ],
      );

      final builder = XmlBuilder();
      row.buildXml(builder);
      final xml = builder.buildDocument().toXmlString(pretty: true);

      expect(xml, contains('<w:trHeight w:val="500" w:hRule="exact"/>'));
    });
  });
}

Archive _getArchive(List<int> bytes) {
  return ZipDecoder().decodeBytes(bytes);
}
