import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('Alignment Fix Verification', () {
    test('DocxParagraph with DocxAlign.left emits <w:jc w:val="start"/>', () {
      final paragraph = DocxParagraph(
        align: DocxAlign.left,
        children: [DocxText('Left aligned text')],
      );

      final builder = XmlBuilder();
      paragraph.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      // Should contain w:jc with val="start"
      expect(xml, contains('<w:jc w:val="start"/>'));
    });

    test('DocxParagraph with DocxAlign.right emits <w:jc w:val="end"/>', () {
      final paragraph = DocxParagraph(
        align: DocxAlign.right,
        children: [DocxText('Right aligned text')],
      );

      final builder = XmlBuilder();
      paragraph.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      // Should contain w:jc with val="end"
      expect(xml, contains('<w:jc w:val="end"/>'));
    });
  });

  group('Image Border Order Verification', () {
    test('DocxInlineImage with border has a:prstGeom BEFORE a:ln', () {
      final border = const DocxBorderSide(
        color: DocxColor.red,
        size: 8,
        style: DocxBorder.single,
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

      // Verify a:prstGeom exists
      expect(xml, contains('<a:prstGeom prst="rect">'));
      // Verify a:ln exists
      expect(xml, contains('<a:ln w="12700">'));

      // Check order: prstGeom index should be less than ln index
      final prstIndex = xml.indexOf('<a:prstGeom');
      final lnIndex = xml.indexOf('<a:ln');

      expect(prstIndex, isNot(-1));
      expect(lnIndex, isNot(-1));
      expect(prstIndex, lessThan(lnIndex),
          reason: 'a:prstGeom must precede a:ln in pic:spPr');
    });
  });
}
