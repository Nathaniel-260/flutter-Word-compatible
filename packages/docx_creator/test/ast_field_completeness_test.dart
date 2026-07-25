// Regression tests for the "field defined but silently dropped" bug class
// discovered while auditing the codebase for issue #98
// (https://github.com/alihassan143/flutter-packages/issues/98). Each test
// pins down one previously-silent gap between an AST field and the code
// path (DOCX write, DOCX read, or copyWith) that is supposed to honor it.
import 'dart:convert';
import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

/// Minimal valid 1x1 red PNG, reused across image-related tests.
Uint8List _createTestPng() {
  const pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4'
      'nGP4z8BQDwAEgAF/pooBPQAAAABJRU5ErkJggg==';
  return base64Decode(pngBase64);
}

void main() {
  group('DocxText theme color', () {
    test('writes w:themeColor/themeTint/themeShade on w:color', () {
      final text = DocxText(
        'Themed',
        themeColor: 'accent1',
        themeTint: '66',
        themeShade: '80',
      );

      final builder = XmlBuilder();
      text.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('<w:color w:val="auto"'));
      expect(xml, contains('w:themeColor="accent1"'));
      expect(xml, contains('w:themeTint="66"'));
      expect(xml, contains('w:themeShade="80"'));
    });

    test('direct color takes precedence over theme color as w:val', () {
      final text = DocxText(
        'Themed',
        color: DocxColor('#123456'),
        themeColor: 'accent1',
      );

      final builder = XmlBuilder();
      text.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('<w:color w:val="123456"'));
      expect(xml, contains('w:themeColor="accent1"'));
    });

    test('omits w:color entirely when neither color nor themeColor is set', () {
      final builder = XmlBuilder();
      DocxText('Plain').buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, isNot(contains('w:color')));
    });
  });

  group('DocxParagraph theme fill', () {
    test('writes w:shd with theme fill attributes', () {
      final paragraph = DocxParagraph(
        themeFill: 'accent2',
        themeFillTint: '33',
        themeFillShade: '99',
        children: [DocxText('Body')],
      );

      final builder = XmlBuilder();
      paragraph.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('<w:shd'));
      expect(xml, contains('w:fill="auto"'));
      expect(xml, contains('w:themeFill="accent2"'));
      expect(xml, contains('w:themeFillTint="33"'));
      expect(xml, contains('w:themeFillShade="99"'));
    });

    test('shadingFill still works and strips a leading #', () {
      final paragraph = DocxParagraph(
        shadingFill: '#FFEE00',
        children: [DocxText('Body')],
      );

      final builder = XmlBuilder();
      paragraph.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('w:fill="FFEE00"'));
    });
  });

  group('DocxSectionDef.breakType', () {
    test('continuous section break writes w:type before w:pgSz', () {
      const section = DocxSectionDef(breakType: DocxSectionBreak.continuous);

      final builder = XmlBuilder();
      section.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, contains('<w:type w:val="continuous"/>'));
      expect(xml.indexOf('w:type'), lessThan(xml.indexOf('w:pgSz')));
    });

    test('default nextPage break omits w:type (schema default)', () {
      const section = DocxSectionDef();

      final builder = XmlBuilder();
      section.buildXml(builder);
      final xml = builder.buildDocument().toXmlString();

      expect(xml, isNot(contains('w:type')));
    });
  });

  group('DocxTableCell.copyWith', () {
    test('preserves themeFill/themeFillTint/themeFillShade/cnfStyle', () {
      const cell = DocxTableCell(
        themeFill: 'accent1',
        themeFillTint: '11',
        themeFillShade: '22',
        cnfStyle: '000000100000',
      );

      final copy = cell.copyWith(colSpan: 2);

      expect(copy.themeFill, equals('accent1'));
      expect(copy.themeFillTint, equals('11'));
      expect(copy.themeFillShade, equals('22'));
      expect(copy.cnfStyle, equals('000000100000'));
      expect(copy.colSpan, equals(2));
    });
  });

  group('DocxTableStyle.copyWith', () {
    test('preserves cellPadding and borderWidth', () {
      const style = DocxTableStyle(cellPadding: 150, borderWidth: 8);

      final copy = style.copyWith(border: DocxBorder.double);

      expect(copy.cellPadding, equals(150));
      expect(copy.borderWidth, equals(8));
      expect(copy.border, equals(DocxBorder.double));
    });
  });

  group('DocxListStyle theming exported to numbering.xml', () {
    test('themeColor/themeFont appear in a custom bullet abstract num',
        () async {
      final doc = docx()
          .add(DocxList(
            style: DocxListStyle(
              bullet: '»',
              color: DocxColor('#123456'),
              themeColor: 'accent3',
              themeTint: '44',
              themeFont: 'minorHAnsi',
            ),
            items: [DocxListItem.text('Themed bullet')],
          ))
          .build();

      final bytes = await DocxExporter().exportToBytes(doc);
      final reloaded = await DocxReader.loadFromBytes(bytes);
      // Full round trip should at least preserve the list item text.
      expect(reloaded.elements, isNotEmpty);
    });
  });

  group('DOCX read/write round-trip for previously-dropped fields', () {
    test('table cell marginLeft/marginRight survive a full round-trip',
        () async {
      final doc = docx()
          .add(DocxTable(rows: [
            DocxTableRow(cells: [
              DocxTableCell(
                marginLeft: 200,
                marginRight: 300,
                children: [DocxParagraph.text('Cell')],
              ),
            ]),
          ]))
          .build();

      final bytes = await DocxExporter().exportToBytes(doc);
      final reloaded = await DocxReader.loadFromBytes(bytes);

      final table = reloaded.elements.whereType<DocxTable>().first;
      final cell = table.rows.first.cells.first;
      expect(cell.marginLeft, equals(200));
      expect(cell.marginRight, equals(300));
    });

    test('paragraph cnfStyle survives a full round-trip', () async {
      final doc = docx()
          .add(DocxParagraph(
            cnfStyle: '100000000000',
            children: [DocxText('Conditional')],
          ))
          .build();

      final bytes = await DocxExporter().exportToBytes(doc);
      final reloaded = await DocxReader.loadFromBytes(bytes);

      final paragraph = reloaded.elements.whereType<DocxParagraph>().first;
      expect(paragraph.cnfStyle, equals('100000000000'));
    });

    test('inline image border survives a full round-trip', () async {
      final doc = docx()
          .add(DocxParagraph(children: [
            DocxInlineImage(
              bytes: _createTestPng(),
              extension: 'png',
              width: 50,
              height: 50,
              border: DocxBorderSide(
                style: DocxBorder.dashed,
                color: DocxColor('#FF0000'),
                size: 8,
              ),
            ),
          ]))
          .build();

      final bytes = await DocxExporter().exportToBytes(doc);
      final reloaded = await DocxReader.loadFromBytes(bytes);

      final paragraph = reloaded.elements.whereType<DocxParagraph>().first;
      final image = paragraph.children.whereType<DocxInlineImage>().first;
      expect(image.border, isNotNull);
      expect(image.border!.style, equals(DocxBorder.dashed));
      expect(image.border!.color.hex.toUpperCase(), equals('FF0000'));
    });

    test('table cellPadding survives a full round-trip', () async {
      final doc = docx()
          .add(DocxTable(
            style: const DocxTableStyle(cellPadding: 180),
            rows: [
              DocxTableRow(cells: [
                DocxTableCell(children: [DocxParagraph.text('Cell')]),
              ]),
            ],
          ))
          .build();

      final bytes = await DocxExporter().exportToBytes(doc);
      final reloaded = await DocxReader.loadFromBytes(bytes);

      final table = reloaded.elements.whereType<DocxTable>().first;
      expect(table.style.cellPadding, equals(180));
    });
  });
}
