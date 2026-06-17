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

  group('VML (w:pict) image — Part H', () {
    const ns =
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:v="urn:schemas-microsoft-com:vml" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';

    // Parses a `w:pict` whose `v:shape` carries [shapeStyle]; when [wrapperStyle]
    // is given the shape is nested inside another styled element (to exercise
    // ancestor walking / non-merging).
    DocxInlineImage parsePict(String shapeStyle, {String? wrapperStyle}) {
      final bytes = _gif1x1(); // 1×1 → intrinsic aspect ratio 1:1
      final archive = Archive()
        ..addFile(ArchiveFile('word/media/wm.png', bytes.length, bytes));
      final ctx = ReaderContext(archive);
      ctx.relationships['rId5'] = const DocxRelationship(
          id: 'rId5', type: 'image', target: 'media/wm.png');

      final shape = '<v:shape id="wm" type="#_x0000_t75" style="$shapeStyle">'
          '<v:imagedata r:id="rId5"/></v:shape>';
      final inner = wrapperStyle == null
          ? shape
          : '<v:group style="$wrapperStyle">$shape</v:group>';
      final run = XmlDocument.parse('<w:r $ns><w:pict>$inner</w:pict></w:r>');
      final parsed = InlineParser(ctx).parseRun(run.rootElement);
      return parsed as DocxInlineImage;
    }

    test('reads size from the v:shape style instead of defaulting to 100×100',
        () {
      final img =
          parsePict('position:absolute;width:450pt;height:300pt;z-index:-1');
      expect(img.width, closeTo(450, 0.01));
      expect(img.height, closeTo(300, 0.01));
    });

    test('converts non-pt units (in/px) to points', () {
      final inches = parsePict('width:6in;height:3in');
      expect(inches.width, closeTo(432, 0.01)); // 6in × 72
      expect(inches.height, closeTo(216, 0.01)); // 3in × 72

      final px = parsePict('width:96px;height:48px');
      expect(px.width, closeTo(72, 0.01)); // 96px × 72/96
      expect(px.height, closeTo(36, 0.01)); // 48px × 72/96
    });

    test('derives the missing dimension from the image aspect ratio', () {
      // width only → height from the 1:1 intrinsic ratio (≈ width), never 100.
      final img = parsePict('width:200pt');
      expect(img.width, closeTo(200, 0.01));
      expect(img.height, closeTo(200, 0.5));
    });

    test('does not merge width and height from different ancestors', () {
      // width on the v:shape, height on an unrelated wrapper: the height must be
      // derived from the shape's own (intrinsic) ratio, not stolen from the
      // wrapper (which would give 300).
      final img = parsePict('width:200pt', wrapperStyle: 'height:300pt');
      expect(img.width, closeTo(200, 0.01));
      expect(img.height, closeTo(200, 0.5));
      expect(img.height, isNot(closeTo(300, 0.5)));
    });

    test('unrecognised units fall back to the 100×100 default', () {
      final img = parsePict('width:50%;height:auto');
      expect(img.width, closeTo(100, 0.01));
      expect(img.height, closeTo(100, 0.01));
    });
  });

  group('Shape gradient fill (a:gradFill) — Part H', () {
    const ns =
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:wsp="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"';

    DocxShape parseShape(String spPrInner) {
      final run = XmlDocument.parse('<w:r $ns><w:drawing><wp:inline>'
          '<wp:extent cx="1270000" cy="635000"/>'
          '<a:graphic><a:graphicData><wsp:wsp>'
          '<wsp:spPr>$spPrInner</wsp:spPr>'
          '</wsp:wsp></a:graphicData></a:graphic>'
          '</wp:inline></w:drawing></w:r>');
      return InlineParser(ReaderContext(Archive())).parseRun(run.rootElement)
          as DocxShape;
    }

    test('parses a linear gradient (stops + angle), gradient wins over solid',
        () {
      final s = parseShape('<a:prstGeom prst="rect"/>'
          '<a:gradFill><a:gsLst>'
          '<a:gs pos="0"><a:srgbClr val="FF0000"/></a:gs>'
          '<a:gs pos="100000"><a:srgbClr val="0000FF"/></a:gs>'
          '</a:gsLst><a:lin ang="5400000" scaled="1"/></a:gradFill>');
      final g = s.gradientFill!;
      expect(g.type, DocxGradientType.linear);
      expect(g.angle, closeTo(90, 0.01)); // 5400000 / 60000
      expect(g.stops.length, 2);
      expect(g.stops.first.position, closeTo(0, 0.001));
      expect(g.stops.first.color.hex, 'FF0000');
      expect(g.stops.last.position, closeTo(1, 0.001));
      expect(s.fillColor, isNull);
    });

    test('parses a radial gradient', () {
      final s = parseShape('<a:prstGeom prst="ellipse"/>'
          '<a:gradFill><a:gsLst>'
          '<a:gs pos="0"><a:srgbClr val="FFFFFF"/></a:gs>'
          '<a:gs pos="100000"><a:srgbClr val="000000"/></a:gs>'
          '</a:gsLst><a:path path="circle"/></a:gradFill>');
      expect(s.gradientFill!.type, DocxGradientType.radial);
    });

    test('a solid fill still parses (no regression)', () {
      final s = parseShape('<a:prstGeom prst="rect"/>'
          '<a:solidFill><a:srgbClr val="4472C4"/></a:solidFill>');
      expect(s.gradientFill, isNull);
      expect(s.fillColor!.hex, '4472C4');
    });

    test('round-trips a gradient through buildXml', () {
      final shape = DocxShape(
        width: 100,
        height: 60,
        gradientFill: DocxGradientFill(angle: 45, stops: [
          DocxGradientStop(position: 0, color: DocxColor('FF0000')),
          DocxGradientStop(position: 1, color: DocxColor('00FF00')),
        ]),
      );
      final b = XmlBuilder();
      shape.buildXml(b);
      final xml = b.buildDocument().toXmlString();
      expect(xml, contains('a:gradFill'));

      final reparsed = InlineParser(ReaderContext(Archive()))
          .parseRun(XmlDocument.parse(xml).rootElement) as DocxShape;
      final g = reparsed.gradientFill!;
      expect(g.type, DocxGradientType.linear);
      expect(g.angle, closeTo(45, 0.01));
      expect(g.stops.length, 2);
      expect(g.stops.first.color.hex, 'FF0000');
      expect(g.stops.last.position, closeTo(1, 0.001));
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
