import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/core/font_manager.dart';
import 'package:docx_creator/src/exporters/docx/docx_export_state.dart';
import 'package:docx_creator/src/exporters/docx/generators/header_footer_generator.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('DocxFooter Global Fix', () {
    test('standard DocxFooter with image generates compliant DrawingML', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final footer = DocxFooter(
        children: [
          DocxImage(
            bytes: bytes,
            extension: 'png',
            width: 50,
            height: 50,
            align: DocxAlign.left,
          ),
        ],
      );

      final doc = DocxBuiltDocument(
        elements: [],
        section: DocxSectionDef(footer: footer),
      );

      final state = DocxExportState(doc, FontManager(), DocxIdGenerator());

      // Initialize image collection
      state.groupedImages['footer'] = [];
      final img = footer.children.first as DocxImage;
      final inline = img.asInline;
      inline.setRelationshipId('rId99', 1);
      state.groupedImages['footer']!.add(inline);

      final archiveFile = DocxHeaderFooterGenerator.createFooter(state);
      final xmlString = String.fromCharCodes(archiveFile.content);
      final document = XmlDocument.parse(xmlString);
      final ftr = document.rootElement;

      // Verify Root Namespaces
      expect(
          ftr.getAttribute('xmlns:mc'),
          equals(
              'http://schemas.openxmlformats.org/markup-compatibility/2006'));
      expect(ftr.getAttribute('xmlns:w14'),
          equals('http://schemas.microsoft.com/office/word/2010/wordml'));
      expect(
          ftr.getAttribute('xmlns:wp14'),
          equals(
              'http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing'));
      expect(ftr.getAttribute('mc:Ignorable'), equals('w14 wp14'));

      // Verify wp:inline attributes
      final drawing = ftr.findAllElements('w:drawing').first;
      final inlineElement = drawing.findElements('wp:inline').first;

      expect(inlineElement.getAttribute('distT'), equals('0'));
      expect(inlineElement.getAttribute('distB'), equals('0'));
      expect(inlineElement.getAttribute('distL'), equals('114300'));
      expect(inlineElement.getAttribute('distR'), equals('114300'));

      // Verify wp:effectExtent
      final effectExtent = inlineElement.findElements('wp:effectExtent').first;
      expect(effectExtent.getAttribute('l'), equals('0'));
      expect(effectExtent.getAttribute('t'), equals('0'));
      expect(effectExtent.getAttribute('r'), equals('0'));
      expect(effectExtent.getAttribute('b'), equals('0'));
    });
  });
}
