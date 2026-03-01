import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('Alignment Justification Tests', () {
    test('DocxAlign.justify maps to "both" in DocxParagraph XML', () {
      final paragraph = DocxParagraph(
        align: DocxAlign.justify,
        children: [DocxText('Justified text')],
      );

      final builder = XmlBuilder();
      paragraph.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('<w:jc w:val="both"/>'));
    });

    test('DocxAlign.justify maps to "both" in DocxTable XML', () {
      final table = DocxTable(
        rows: [
          DocxTableRow(cells: [DocxTableCell.text('Table Cell')])
        ],
        alignment: DocxAlign.justify,
      );

      final builder = XmlBuilder();
      table.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('<w:jc w:val="both"/>'));
    });

    test('DocxAlign.justify maps to "both" in DocxImage XML', () {
      final image = DocxImage(
        bytes: Uint8List(0),
        extension: 'png',
        align: DocxAlign.justify,
      );

      final builder = XmlBuilder();
      image.setRelationshipId('rId1', 1);
      image.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('<w:jc w:val="both"/>'));
    });
  });

  group('Image Border Tests', () {
    test('DocxImage side border builds correct <a:ln> XML', () {
      final border = const DocxBorderSide(
        color: DocxColor.red,
        size: 8, // 1pt
        style: DocxBorder.single,
      );

      final image = DocxImage(
        bytes: Uint8List(0),
        extension: 'png',
        border: border,
      );

      final builder = XmlBuilder();
      image.setRelationshipId('rId1', 1);
      image.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('<a:ln w="12700">'));
      expect(xml, contains('<a:srgbClr val="FF0000"/>'));
      expect(xml, contains('<a:prstDash val="solid"/>'));
    });

    test('DocxInlineImage with border builds correct <a:ln> XML', () {
      final border = const DocxBorderSide(
        color: DocxColor.blue,
        size: 4, // 0.5pt
        style: DocxBorder.dashed,
      );

      final image = DocxInlineImage(
        bytes: Uint8List(0),
        extension: 'png',
        border: border,
      );

      final builder = XmlBuilder();
      image.setRelationshipId('rId1', 1);
      image.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('<a:ln w="6350">'));
      expect(xml, contains('<a:srgbClr val="0000FF"/>'));
      expect(xml, contains('<a:prstDash val="dash"/>'));
    });

    test('DocxImage without border does not have <a:ln>', () {
      final image = DocxImage(
        bytes: Uint8List(0),
        extension: 'png',
      );

      final builder = XmlBuilder();
      image.setRelationshipId('rId1', 1);
      image.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, isNot(contains('<a:ln')));
    });
  });
}
