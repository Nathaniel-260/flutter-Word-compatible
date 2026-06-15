import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

/// Part H.1/H.3 — drawing transform (rotation / mirror / crop) parse + round-trip.
void main() {
  group('Text box content (w:txbxContent) — Part H', () {
    const ns =
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:wsp="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"';

    DocxShape parseTextBoxShape(String txbxInner) {
      // The reader matches the `wsp:` prefix (wsp:wsp / wsp:txbx), as written by
      // the exporter and real Word output.
      final run = XmlDocument.parse('<w:r $ns><w:drawing><wp:inline>'
          '<a:graphic><a:graphicData><wsp:wsp>'
          '<wsp:spPr><a:prstGeom prst="rect"/></wsp:spPr>'
          '<wsp:txbx><w:txbxContent>$txbxInner</w:txbxContent></wsp:txbx>'
          '</wsp:wsp></a:graphicData></a:graphic>'
          '</wp:inline></w:drawing></w:r>');
      final parsed =
          InlineParser(ReaderContext(Archive())).parseRun(run.rootElement);
      return parsed as DocxShape;
    }

    test('parses real block content into textBlocks (not just flat text)', () {
      final shape = parseTextBoxShape(
        '<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Boxed title</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Second line</w:t></w:r></w:p>',
      );

      expect(shape.textBlocks, isNotNull);
      expect(shape.textBlocks!.length, 2);
      final first = shape.textBlocks!.first as DocxParagraph;
      final firstRun = first.children.first as DocxText;
      expect(firstRun.content, 'Boxed title');
      expect(firstRun.fontWeight, DocxFontWeight.bold);
      // The flat fallback is still populated from the joined w:t runs.
      expect(shape.text, contains('Boxed title'));
    });

    test('buildXml emits the real blocks (not the flat centred fallback)', () {
      final shape = DocxShape(
        width: 120,
        height: 60,
        textBlocks: [
          DocxParagraph(children: [
            DocxText('Hello', fontWeight: DocxFontWeight.bold),
          ]),
        ],
      )..setShapeId(9);

      final builder = XmlBuilder();
      shape.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('<w:txbxContent>'));
      expect(xml, contains('Hello'));
      // The blocks carry their own bold run, so the flat single-paragraph
      // centred fallback is not used.
      expect(xml, contains('<w:b'));
    });

    test('flat text still uses the centred-paragraph fallback', () {
      final shape = DocxShape(width: 80, height: 40, text: 'Label')
        ..setShapeId(10);
      final builder = XmlBuilder();
      shape.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();
      expect(xml, contains('<w:txbxContent>'));
      expect(xml, contains('Label'));
      expect(xml, contains('w:val="center"'));
    });
  });

  group('Image transform — buildXml', () {
    test('writes rot / flipH / flipV / srcRect into the drawing XML', () {
      final img = DocxInlineImage(
        bytes: _gif1x1(),
        extension: 'gif',
        width: 100,
        height: 80,
        rotation: 45,
        flipH: true,
        flipV: true,
        cropLeft: 0.1,
        cropTop: 0.05,
        cropRight: 0.2,
        cropBottom: 0,
      )..setRelationshipId('rId7', 7);

      final builder = XmlBuilder();
      img.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      // 45° in 1/60000 units.
      expect(xml, contains('rot="2700000"'));
      expect(xml, contains('flipH="1"'));
      expect(xml, contains('flipV="1"'));
      // Crop fractions in 1/1000 of a percent; zero insets (bottom) are omitted.
      expect(xml, contains('<a:srcRect l="10000" t="5000" r="20000"/>'));
    });

    test('no transform → no rot/flip/srcRect emitted', () {
      final img = DocxInlineImage(
        bytes: _gif1x1(),
        extension: 'gif',
      )..setRelationshipId('rId1', 1);
      final builder = XmlBuilder();
      img.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, isNot(contains('rot=')));
      expect(xml, isNot(contains('flipH=')));
      expect(xml, isNot(contains('a:srcRect')));
    });
  });

  group('Image transform — export → read round-trip', () {
    test('rotation, mirror and crop survive a full round-trip', () async {
      final doc = DocxDocumentBuilder()
          .add(DocxParagraph(children: [
            DocxInlineImage(
              bytes: _gif1x1(),
              extension: 'gif',
              width: 120,
              height: 90,
              rotation: 30,
              flipH: true,
              cropLeft: 0.1,
              cropBottom: 0.25,
            ),
          ]))
          .build();

      final bytes = await DocxExporter().exportToBytes(doc);
      final read = await DocxReader.loadFromBytes(bytes);

      final image = _firstImage(read);
      expect(image, isNotNull, reason: 'image should round-trip');
      expect(image!.rotation, closeTo(30, 0.01));
      expect(image.flipH, isTrue);
      expect(image.flipV, isFalse);
      expect(image.cropLeft, closeTo(0.1, 0.001));
      expect(image.cropBottom, closeTo(0.25, 0.001));
      expect(image.cropTop, 0);
      expect(image.cropRight, 0);
    });
  });

  group('Shape transform + floating anchor — round-trip', () {
    test('flipH/flipV/rotation on a shape survive buildXml', () {
      final shape = DocxShape.rectangle(width: 60, height: 40)..setShapeId(3);
      final flipped = DocxShape(
        width: 60,
        height: 40,
        rotation: 90,
        flipH: true,
        flipV: true,
      )..setShapeId(4);

      final b1 = XmlBuilder();
      shape.buildXml(b1);
      expect(b1.buildDocument().toXmlString(), isNot(contains('flipH=')));

      final b2 = XmlBuilder();
      flipped.buildXml(b2);
      final xml = b2.buildDocument().toXmlString();
      expect(xml, contains('flipH="1"'));
      expect(xml, contains('flipV="1"'));
      expect(xml, contains('rot="5400000"'));
    });

    test('floating shape anchor (position + wrap + rotation) round-trips',
        () async {
      final doc = DocxDocumentBuilder()
          .add(DocxParagraph(children: [
            DocxShape(
              width: 80,
              height: 50,
              preset: DocxShapePreset.ellipse,
              position: DocxDrawingPosition.floating,
              fillColor: DocxColor.blue,
              horizontalFrom: DocxHorizontalPositionFrom.page,
              horizontalAlign: DrawingHAlign.right,
              verticalFrom: DocxVerticalPositionFrom.page,
              verticalAlign: DrawingVAlign.top,
              textWrap: DocxTextWrap.square,
              rotation: 45,
              flipH: true,
            ),
          ]))
          .build();

      final bytes = await DocxExporter().exportToBytes(doc);
      final read = await DocxReader.loadFromBytes(bytes);

      final shape = _firstShape(read);
      expect(shape, isNotNull, reason: 'shape should round-trip');
      expect(shape!.position, DocxDrawingPosition.floating);
      expect(shape.horizontalFrom, DocxHorizontalPositionFrom.page);
      expect(shape.horizontalAlign, DrawingHAlign.right);
      expect(shape.verticalFrom, DocxVerticalPositionFrom.page);
      expect(shape.verticalAlign, DrawingVAlign.top);
      expect(shape.textWrap, DocxTextWrap.square);
      expect(shape.rotation, closeTo(45, 0.01));
      expect(shape.flipH, isTrue);
    });
  });
}

DocxInlineImage? _firstImage(DocxBuiltDocument doc) {
  for (final el in doc.elements) {
    if (el is DocxParagraph) {
      for (final c in el.children) {
        if (c is DocxInlineImage) return c;
      }
    }
  }
  return null;
}

DocxShape? _firstShape(DocxBuiltDocument doc) {
  for (final el in doc.elements) {
    if (el is DocxParagraph) {
      for (final c in el.children) {
        if (c is DocxShape) return c;
      }
    }
  }
  return null;
}

/// Minimal valid 1×1 GIF (same fixture style as the other drawing tests).
Uint8List _gif1x1() => Uint8List.fromList([
      0x47, 0x49, 0x46, 0x38, 0x39, 0x61, //
      0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00,
      0xff, 0xff, 0xff, 0x00, 0x00, 0x00,
      0x21, 0xf9, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
      0x02, 0x02, 0x44, 0x01, 0x00, 0x3b,
    ]);
