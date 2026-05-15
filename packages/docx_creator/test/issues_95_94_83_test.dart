// Tests for GitHub issues #95, #94, and #83.

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<Map<String, String>> _exportAndRead(DocxBuiltDocument doc) async {
  final bytes = await DocxExporter().exportToBytes(doc);
  final archive = ZipDecoder().decodeBytes(bytes);
  return {
    for (final f in archive.files)
      f.name: utf8.decode(f.content as List<int>),
  };
}

// ---------------------------------------------------------------------------
// Issue #95 — DocxText.link href must generate a clickable w:hyperlink
// ---------------------------------------------------------------------------

void main() {
  group('Issue #95 — Hyperlinks', () {
    test('w:hyperlink element is generated in document.xml', () async {
      final doc = docx()
          .add(DocxParagraph(children: [
            DocxText.link('Visit Dart', href: 'https://dart.dev'),
          ]))
          .build();

      final files = await _exportAndRead(doc);
      final documentXml = files['word/document.xml']!;

      expect(documentXml, contains('w:hyperlink'),
          reason: 'w:hyperlink element must be present');
      expect(documentXml, contains('r:id="rIdHyperlink1"'),
          reason: 'hyperlink must reference a relationship ID');
    });

    test('hyperlink relationship is registered in document.xml.rels', () async {
      final doc = docx()
          .add(DocxParagraph(children: [
            DocxText.link('Dart', href: 'https://dart.dev'),
          ]))
          .build();

      final files = await _exportAndRead(doc);
      final rels = files['word/_rels/document.xml.rels']!;

      expect(rels, contains('relationships/hyperlink'),
          reason: 'hyperlink relationship type must be present');
      expect(rels, contains('https://dart.dev'),
          reason: 'the URL must be present as the Target');
      expect(rels, contains('TargetMode="External"'),
          reason: 'external hyperlinks need TargetMode=External');
    });

    test('same URL reuses a single relationship ID', () async {
      final doc = docx()
          .add(DocxParagraph(children: [
            DocxText.link('A', href: 'https://example.com'),
            DocxText.link('B', href: 'https://example.com'),
          ]))
          .build();

      final files = await _exportAndRead(doc);
      final rels = files['word/_rels/document.xml.rels']!;

      // Count occurrences of the URL — should appear exactly once in rels
      expect(
        'https://example.com'.allMatches(rels).length,
        equals(1),
        reason: 'identical URLs must share one relationship entry',
      );
    });

    test('two different URLs each get their own relationship', () async {
      final doc = docx()
          .add(DocxParagraph(children: [
            DocxText.link('A', href: 'https://dart.dev'),
            DocxText.link('B', href: 'https://pub.dev'),
          ]))
          .build();

      final files = await _exportAndRead(doc);
      final rels = files['word/_rels/document.xml.rels']!;

      expect(rels, contains('https://dart.dev'));
      expect(rels, contains('https://pub.dev'));
      expect(rels, contains('rIdHyperlink1'));
      expect(rels, contains('rIdHyperlink2'));
    });

    test('plain DocxText without href generates no w:hyperlink', () async {
      final doc = docx()
          .add(DocxParagraph(children: [DocxText('plain text')]))
          .build();

      final files = await _exportAndRead(doc);
      final documentXml = files['word/document.xml']!;

      expect(documentXml, isNot(contains('w:hyperlink')));
    });

    test('DocxText constructors remain const', () {
      // These must compile without error — they are compile-time constants
      const t1 = DocxText('hello');
      const t2 = DocxText.bold('bold');
      const t3 = DocxText.link('link', href: 'https://example.com');
      expect(t1.content, equals('hello'));
      expect(t2.isBold, isTrue);
      expect(t3.isLink, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Issue #94 — DocxListStyle bullet/format must appear in numbering.xml
  // -------------------------------------------------------------------------

  group('Issue #94 — DocxListStyle is respected', () {
    test('default bullet list uses abstractNumId=0', () async {
      final doc = docx().bullet(['Item 1', 'Item 2']).build();
      final files = await _exportAndRead(doc);
      final numbering = files['word/numbering.xml']!;

      expect(numbering, contains('<w:abstractNumId w:val="0"/>'));
    });

    test('custom bullet char creates a new abstractNum with the correct lvlText',
        () async {
      final doc = docx()
          .add(DocxList.bullet(
            ['Item 1', 'Item 2'],
            style: const DocxListStyle(bullet: '→'),
          ))
          .build();

      final files = await _exportAndRead(doc);
      final numbering = files['word/numbering.xml']!;

      expect(
        numbering,
        contains('<w:lvlText w:val="→"/>'),
        reason: 'custom bullet character must appear in numbering.xml',
      );
      // Must NOT fall back to the default abstractNumId=0
      expect(
        numbering,
        isNot(contains('<w:abstractNumId w:val="0"/>')),
        reason: 'custom style should use its own abstractNum, not the default',
      );
    });

    test('DocxListStyle.dash uses dash bullet character', () async {
      final doc = docx()
          .add(DocxList.bullet(['A', 'B'], style: DocxListStyle.dash))
          .build();

      final files = await _exportAndRead(doc);
      final numbering = files['word/numbering.xml']!;

      expect(numbering, contains('<w:lvlText w:val="-"/>'));
    });

    test('custom numbered list with lowerAlpha format', () async {
      final doc = docx()
          .add(DocxList.numbered(
            ['Step 1', 'Step 2'],
            style: DocxListStyle.lowerAlpha,
          ))
          .build();

      final files = await _exportAndRead(doc);
      final numbering = files['word/numbering.xml']!;

      expect(
        numbering,
        contains('<w:numFmt w:val="lowerLetter"/>'),
        reason: 'lowerAlpha format should map to OOXML lowerLetter',
      );
    });

    test('custom numbered list with upperRoman format', () async {
      final doc = docx()
          .add(DocxList.numbered(
            ['I', 'II'],
            style: DocxListStyle.upperRoman,
          ))
          .build();

      final files = await _exportAndRead(doc);
      final numbering = files['word/numbering.xml']!;

      expect(numbering, contains('<w:numFmt w:val="upperRoman"/>'));
    });

    test('buildXmlWithStyle applies style indentation to paragraph w:ind',
        () async {
      final doc = docx()
          .add(DocxList.bullet(
            ['Item'],
            style: const DocxListStyle(indentPerLevel: 900, hangingIndent: 400),
          ))
          .build();

      final files = await _exportAndRead(doc);
      final documentXml = files['word/document.xml']!;

      expect(
        documentXml,
        contains('w:left="900"'),
        reason: 'paragraph w:ind must reflect style.indentPerLevel',
      );
      expect(
        documentXml,
        contains('w:hanging="400"'),
        reason: 'paragraph w:ind must reflect style.hangingIndent',
      );
    });

    test('item-level overrideStyle indentation is applied', () async {
      final doc = docx()
          .add(DocxList(
            isOrdered: false,
            items: [
              DocxListItem(
                [DocxText('item')],
                overrideStyle:
                    const DocxListStyle(indentPerLevel: 1080, hangingIndent: 540),
              ),
            ],
          ))
          .build();

      final files = await _exportAndRead(doc);
      final documentXml = files['word/document.xml']!;

      expect(documentXml, contains('w:left="1080"'));
      expect(documentXml, contains('w:hanging="540"'));
    });

    test('default bullet style does not create extra abstractNum entries',
        () async {
      final doc =
          docx().bullet(['A', 'B']).numbered(['1', '2']).build();

      final files = await _exportAndRead(doc);
      final numbering = files['word/numbering.xml']!;

      // Only abstractNumId 0 and 1 should exist (the two defaults)
      expect(numbering, contains('w:abstractNumId="0"'));
      expect(numbering, contains('w:abstractNumId="1"'));
      expect(numbering, isNot(contains('w:abstractNumId="2"')));
    });
  });

}
