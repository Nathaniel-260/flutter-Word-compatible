import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

/// Part H.1/H.3 — drawing transform (rotation / mirror / crop) parse + round-trip.
void main() {
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
