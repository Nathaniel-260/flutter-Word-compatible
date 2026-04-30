import 'dart:convert';
// import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

/// Creates a minimal 1x1 PNG image for testing.
Uint8List _createTestPng() {
  // Minimal valid 1x1 red PNG
  const pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4'
      'nGP4z8BQDwAEgAF/pooBPQAAAABJRU5ErkJggg==';
  return base64Decode(pngBase64);
}

void main() {
  group('MS Word Image Compatibility (Issue #90)', () {
    late Uint8List testPng;

    setUp(() {
      testPng = _createTestPng();
    });

    // ======================================================================
    // Core structural tests: verify wp:cNvGraphicFramePr is present
    // ======================================================================

    test('Body inline image has wp:cNvGraphicFramePr element', () async {
      final doc = DocxDocumentBuilder()
          .p('Before image')
          .image(DocxImage(
            bytes: testPng,
            extension: 'png',
            width: 100,
            height: 100,
          ))
          .p('After image')
          .build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      final documentFile =
          archive.files.firstWhere((f) => f.name == 'word/document.xml');
      final documentXml = utf8.decode(documentFile.content);

      // Must contain the drawing structure
      expect(documentXml, contains('w:drawing'));
      expect(documentXml, contains('wp:inline'));

      // Parse and verify cNvGraphicFramePr exists as child of wp:inline
      final xmlDoc = XmlDocument.parse(documentXml);
      final inlines = xmlDoc.findAllElements('wp:inline');
      expect(inlines, isNotEmpty, reason: 'Should have wp:inline elements');

      for (final inline in inlines) {
        final cNvGfp = inline.findElements('wp:cNvGraphicFramePr');
        expect(cNvGfp, isNotEmpty,
            reason: 'wp:inline must contain wp:cNvGraphicFramePr for MS Word');

        // Verify graphicFrameLocks with noChangeAspect
        final locks = cNvGfp.first.findElements('a:graphicFrameLocks');
        expect(locks, isNotEmpty,
            reason: 'cNvGraphicFramePr must contain a:graphicFrameLocks');
        expect(locks.first.getAttribute('noChangeAspect'), equals('1'));
      }
    });

    test('Floating image has wp:cNvGraphicFramePr element', () async {
      final doc = DocxDocumentBuilder()
          .p('Before floating image')
          .add(DocxParagraph(children: [
            DocxInlineImage(
              bytes: testPng,
              extension: 'png',
              width: 100,
              height: 100,
              positionMode: DocxDrawingPosition.floating,
              textWrap: DocxTextWrap.square,
            ),
          ]))
          .build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      final documentFile =
          archive.files.firstWhere((f) => f.name == 'word/document.xml');
      final documentXml = utf8.decode(documentFile.content);

      final xmlDoc = XmlDocument.parse(documentXml);
      final anchors = xmlDoc.findAllElements('wp:anchor');
      expect(anchors, isNotEmpty, reason: 'Should have wp:anchor elements');

      for (final anchor in anchors) {
        final cNvGfp = anchor.findElements('wp:cNvGraphicFramePr');
        expect(cNvGfp, isNotEmpty,
            reason: 'wp:anchor must contain wp:cNvGraphicFramePr for MS Word');
      }
    });

    // ======================================================================
    // Header/Footer namespace and image rendering tests
    // ======================================================================

    test('Header XML has a: and pic: namespace declarations', () async {
      final doc = DocxDocumentBuilder()
          .section(
            header: DocxHeader(children: [
              DocxParagraph(children: [DocxText('Header Text')]),
            ]),
          )
          .p('Body content')
          .build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      final headerFile =
          archive.files.firstWhere((f) => f.name == 'word/header1.xml');
      final headerXml = utf8.decode(headerFile.content);

      final xmlDoc = XmlDocument.parse(headerXml);
      final hdr = xmlDoc.rootElement;

      expect(hdr.getAttribute('xmlns:a'), isNotNull,
          reason: 'Header must declare xmlns:a namespace');
      expect(hdr.getAttribute('xmlns:pic'), isNotNull,
          reason: 'Header must declare xmlns:pic namespace');
      expect(hdr.getAttribute('xmlns:a'),
          equals('http://schemas.openxmlformats.org/drawingml/2006/main'));
      expect(hdr.getAttribute('xmlns:pic'),
          equals('http://schemas.openxmlformats.org/drawingml/2006/picture'));
    });

    test('Footer XML has a: and pic: namespace declarations', () async {
      final doc = DocxDocumentBuilder()
          .section(
            footer: DocxFooter(children: [
              DocxParagraph(children: [DocxText('Footer Text')]),
            ]),
          )
          .p('Body content')
          .build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      final footerFile =
          archive.files.firstWhere((f) => f.name == 'word/footer1.xml');
      final footerXml = utf8.decode(footerFile.content);

      final xmlDoc = XmlDocument.parse(footerXml);
      final ftr = xmlDoc.rootElement;

      expect(ftr.getAttribute('xmlns:a'), isNotNull,
          reason: 'Footer must declare xmlns:a namespace');
      expect(ftr.getAttribute('xmlns:pic'), isNotNull,
          reason: 'Footer must declare xmlns:pic namespace');
    });

    test('Footer with image generates correct XML and relationships', () async {
      final doc = DocxDocumentBuilder()
          .section(
            footer: DocxFooter(children: [
              DocxImage(
                bytes: testPng,
                extension: 'png',
                width: 80,
                height: 40,
              ),
            ]),
          )
          .p('Body content')
          .build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. footer1.xml must exist
      final footerFile =
          archive.files.firstWhere((f) => f.name == 'word/footer1.xml');
      final footerXml = utf8.decode(footerFile.content);
      expect(footerXml, contains('w:drawing'),
          reason: 'Footer must contain w:drawing for image');
      expect(footerXml, contains('wp:inline'),
          reason: 'Footer image must use wp:inline');
      expect(footerXml, contains('wp:cNvGraphicFramePr'),
          reason: 'Footer image must have cNvGraphicFramePr for MS Word');
      expect(footerXml, contains('pic:pic'),
          reason: 'Footer must contain pic:pic element');
      expect(footerXml, contains('r:embed'),
          reason: 'Footer image must have r:embed relationship');

      // 2. footer1.xml.rels must exist with image relationship
      final footerRelsFile = archive.files
          .firstWhere((f) => f.name == 'word/_rels/footer1.xml.rels');
      final footerRelsXml = utf8.decode(footerRelsFile.content);
      expect(footerRelsXml, contains('Relationship'),
          reason: 'Footer rels must have Relationship entries');
      expect(footerRelsXml, contains('image'),
          reason: 'Footer rels must reference image type');
      expect(footerRelsXml, contains('media/'),
          reason: 'Footer rels must point to media path');

      // 3. Image file must exist in word/media/
      final imageFiles = archive.files
          .where((f) => f.name.startsWith('word/media/image'))
          .toList();
      expect(imageFiles, isNotEmpty,
          reason: 'Image file must exist in word/media/');
    });

    test('Header with image generates correct XML and relationships', () async {
      final doc = DocxDocumentBuilder()
          .section(
            header: DocxHeader(children: [
              DocxImage(
                bytes: testPng,
                extension: 'png',
                width: 80,
                height: 40,
              ),
            ]),
          )
          .p('Body content')
          .build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      // header1.xml must contain drawing with cNvGraphicFramePr
      final headerFile =
          archive.files.firstWhere((f) => f.name == 'word/header1.xml');
      final headerXml = utf8.decode(headerFile.content);
      expect(headerXml, contains('w:drawing'));
      expect(headerXml, contains('wp:cNvGraphicFramePr'));
      expect(headerXml, contains('pic:pic'));

      // header1.xml.rels must exist
      final headerRelsFile = archive.files
          .firstWhere((f) => f.name == 'word/_rels/header1.xml.rels');
      final headerRelsXml = utf8.decode(headerRelsFile.content);
      expect(headerRelsXml, contains('image'));
    });

    // ======================================================================
    // Combined test: body + header + footer images
    // ======================================================================

    test(
        'Full document with images in body, header, and footer '
        'produces MS Word-compatible DOCX', () async {
      final doc = DocxDocumentBuilder()
          .section(
            header: DocxHeader(children: [
              DocxImage(
                bytes: testPng,
                extension: 'png',
                width: 60,
                height: 30,
              ),
            ]),
            footer: DocxFooter(children: [
              DocxImage(
                bytes: testPng,
                extension: 'png',
                width: 60,
                height: 30,
              ),
            ]),
          )
          .p('Document with images everywhere')
          .image(DocxImage(
            bytes: testPng,
            extension: 'png',
            width: 200,
            height: 150,
          ))
          .p('End of body')
          .build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);
      final archive = ZipDecoder().decodeBytes(bytes);

      // --- document.xml verification ---
      final docFile =
          archive.files.firstWhere((f) => f.name == 'word/document.xml');
      final docXml = utf8.decode(docFile.content);
      final docXmlDoc = XmlDocument.parse(docXml);

      // Body image must have cNvGraphicFramePr
      final bodyInlines = docXmlDoc.findAllElements('wp:inline');
      expect(bodyInlines, isNotEmpty);
      for (final inline in bodyInlines) {
        expect(inline.findElements('wp:cNvGraphicFramePr'), isNotEmpty,
            reason: 'Body image missing cNvGraphicFramePr');
      }

      // --- header1.xml verification ---
      final headerFile =
          archive.files.firstWhere((f) => f.name == 'word/header1.xml');
      final headerXml = utf8.decode(headerFile.content);
      final headerXmlDoc = XmlDocument.parse(headerXml);

      // Header namespaces
      final hdr = headerXmlDoc.rootElement;
      expect(hdr.getAttribute('xmlns:a'), isNotNull,
          reason: 'Header missing xmlns:a');
      expect(hdr.getAttribute('xmlns:pic'), isNotNull,
          reason: 'Header missing xmlns:pic');

      // Header image structure
      final headerInlines = headerXmlDoc.findAllElements('wp:inline');
      expect(headerInlines, isNotEmpty);
      for (final inline in headerInlines) {
        expect(inline.findElements('wp:cNvGraphicFramePr'), isNotEmpty,
            reason: 'Header image missing cNvGraphicFramePr');
      }

      // --- footer1.xml verification ---
      final footerFile =
          archive.files.firstWhere((f) => f.name == 'word/footer1.xml');
      final footerXml = utf8.decode(footerFile.content);
      final footerXmlDoc = XmlDocument.parse(footerXml);

      // Footer namespaces
      final ftr = footerXmlDoc.rootElement;
      expect(ftr.getAttribute('xmlns:a'), isNotNull,
          reason: 'Footer missing xmlns:a');
      expect(ftr.getAttribute('xmlns:pic'), isNotNull,
          reason: 'Footer missing xmlns:pic');

      // Footer image structure
      final footerInlines = footerXmlDoc.findAllElements('wp:inline');
      expect(footerInlines, isNotEmpty);
      for (final inline in footerInlines) {
        expect(inline.findElements('wp:cNvGraphicFramePr'), isNotEmpty,
            reason: 'Footer image missing cNvGraphicFramePr');
      }

      // --- Relationships verification ---
      final docRels = archive.files
          .firstWhere((f) => f.name == 'word/_rels/document.xml.rels');
      final docRelsXml = utf8.decode(docRels.content);
      expect(docRelsXml, contains('image'),
          reason: 'document.xml.rels must have body image rel');

      final headerRels = archive.files
          .firstWhere((f) => f.name == 'word/_rels/header1.xml.rels');
      final headerRelsXml = utf8.decode(headerRels.content);
      expect(headerRelsXml, contains('image'),
          reason: 'header1.xml.rels must have image rel');

      final footerRels = archive.files
          .firstWhere((f) => f.name == 'word/_rels/footer1.xml.rels');
      final footerRelsXml = utf8.decode(footerRels.content);
      expect(footerRelsXml, contains('image'),
          reason: 'footer1.xml.rels must have image rel');

      // --- Media files ---
      final mediaFiles = archive.files
          .where((f) => f.name.startsWith('word/media/image'))
          .toList();
      // Should have images for body + header + footer
      expect(mediaFiles.length, greaterThanOrEqualTo(1),
          reason: 'Archive must contain image media files');

      // --- Content Types ---
      final contentTypes =
          archive.files.firstWhere((f) => f.name == '[Content_Types].xml');
      final ctXml = utf8.decode(contentTypes.content);
      expect(ctXml, contains('image/png'),
          reason: 'Content types must declare image/png');
      expect(ctXml, contains('header'),
          reason: 'Content types must declare header part');
      expect(ctXml, contains('footer'),
          reason: 'Content types must declare footer part');
    });

    // ======================================================================
    // DOCX file generation test — writes to disk for manual Word testing
    // ======================================================================

    test('Generates DOCX file for manual MS Word verification', () async {
      // final image = await DocxBackgroundImage.fromUrl(
      //     "https://images.unsplash.com/photo-1624555130581-1d9cca783bc0?q=80&w=1742&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D");

      final doc = DocxDocumentBuilder()
          .section(
            header: DocxHeader(children: [
              DocxParagraph(align: DocxAlign.left, children: [
                DocxInlineImage(
                  bytes: testPng,
                  extension: 'png',
                  width: 40,
                  height: 40,
                  altText: 'Header logo',
                ),
                DocxText(' Header with Image', fontWeight: DocxFontWeight.bold),
              ]),
            ]),
            footer: DocxFooter(children: [
              DocxParagraph(align: DocxAlign.center, children: [
                DocxInlineImage(
                  bytes: testPng,
                  extension: 'png',
                  width: 30,
                  height: 30,
                  altText: 'Footer icon',
                ),
              ]),
              DocxParagraph(align: DocxAlign.center, children: [
                DocxText('Page '),
                DocxPageNumber(),
                DocxText(' of '),
                DocxPageCount(),
              ]),
            ]),
          )
          .h1('MS Word Compatibility Test')
          .p('This document tests that images render correctly in MS Word.')
          .p('Below is an inline image in the body:')
          .image(DocxImage(
            bytes: testPng,
            extension: 'png',
            width: 100,
            height: 100,
          ))
          .p('The header and footer also contain images.')
          .p('If you can see images in the header, footer, and body — the fix works!')
          .build();

      final exporter = DocxExporter();
      final bytes = await exporter.exportToBytes(doc);

      // Basic validity — can decode as ZIP
      expect(bytes.length, greaterThan(0));
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.files.any((f) => f.name == 'word/document.xml'), true);
      expect(archive.files.any((f) => f.name == 'word/header1.xml'), true);
      expect(archive.files.any((f) => f.name == 'word/footer1.xml'), true);

      // Uncomment below to write to disk for manual Word testing:
      // // import 'dart:io';
      // await File('test_output_ms_word_compat.docx').writeAsBytes(bytes);
    });
  });
}
