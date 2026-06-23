import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

/// Parse a `<w:p>` snippet into a [DocxParagraph] with a bare reader context.
DocxParagraph parsePara(String inner) {
  final parser = BlockParser(ReaderContext(Archive()));
  final doc = XmlDocument.parse('<w:p $_ns>$inner</w:p>');
  return parser.parseParagraph(doc.rootElement);
}

/// Parse a full `<w:p>...</w:p>` document string into a [DocxParagraph].
DocxParagraph parseParaDoc(String xml) {
  final parser = BlockParser(ReaderContext(Archive()));
  return parser.parseParagraph(XmlDocument.parse(xml).rootElement);
}

/// Serialize a block back to an XML string.
String buildXml(DocxBlock block) {
  final builder = XmlBuilder();
  block.buildXml(builder);
  return builder.buildDocument().toXmlString();
}

void main() {
  group('A.1 paragraph properties — parsing', () {
    test('w:bidi → isRtl', () {
      expect(parsePara('<w:pPr><w:bidi/></w:pPr>').isRtl, isTrue);
      expect(parsePara('<w:pPr><w:bidi w:val="0"/></w:pPr>').isRtl, isFalse);
      expect(parsePara('<w:pPr/>').isRtl, isFalse);
    });

    test('keepNext / keepLines toggles', () {
      final p = parsePara('<w:pPr><w:keepNext/><w:keepLines/></w:pPr>');
      expect(p.keepWithNext, isTrue);
      expect(p.keepLines, isTrue);
      expect(parsePara('<w:pPr/>').keepWithNext, isFalse);
    });

    test('widowControl defaults to true, off when val=0', () {
      expect(parsePara('<w:pPr/>').widowControl, isTrue);
      expect(parsePara('<w:pPr><w:widowControl w:val="0"/></w:pPr>').widowControl,
          isFalse);
      expect(parsePara('<w:pPr><w:widowControl/></w:pPr>').widowControl, isTrue);
    });

    test('suppressAutoHyphens / contextualSpacing / pageBreakBefore', () {
      final p = parsePara(
          '<w:pPr><w:suppressAutoHyphens/><w:contextualSpacing/><w:pageBreakBefore/></w:pPr>');
      expect(p.suppressHyphens, isTrue);
      expect(p.contextualSpacing, isTrue);
      expect(p.pageBreakBefore, isTrue);
    });

    test('w:tabs → tabStops with alignment + leader', () {
      final p = parsePara('''<w:pPr><w:tabs>
        <w:tab w:val="center" w:pos="2160" w:leader="dot"/>
        <w:tab w:val="right" w:pos="4320"/>
        <w:tab w:val="num" w:pos="100"/>
        <w:tab w:val="clear" w:pos="720"/>
      </w:tabs></w:pPr>''');
      expect(p.tabStops, hasLength(4));
      expect(p.tabStops[0].posTwips, 2160);
      expect(p.tabStops[0].alignment, DocxTabAlignment.center);
      expect(p.tabStops[0].leader, DocxTabLeader.dot);
      expect(p.tabStops[1].alignment, DocxTabAlignment.right);
      expect(p.tabStops[1].leader, DocxTabLeader.none);
      // legacy "num" maps to decimal
      expect(p.tabStops[2].alignment, DocxTabAlignment.decimal);
      expect(p.tabStops[3].alignment, DocxTabAlignment.clear);
    });

    test('w:outlineLvl and w:textAlignment', () {
      final p = parsePara(
          '<w:pPr><w:textAlignment w:val="center"/><w:outlineLvl w:val="2"/></w:pPr>');
      expect(p.outlineLevel, 2);
      expect(p.textAlignment, DocxTextAlignment.center);
    });
  });

  group('A.1 paragraph properties — round-trip (buildXml)', () {
    test('all new pPr flags survive parse → build → parse', () {
      const xml = '''<w:pPr>
        <w:keepNext/>
        <w:keepLines/>
        <w:pageBreakBefore/>
        <w:widowControl w:val="0"/>
        <w:tabs><w:tab w:val="right" w:pos="4320" w:leader="dot"/></w:tabs>
        <w:suppressAutoHyphens/>
        <w:bidi/>
        <w:contextualSpacing/>
      </w:pPr>''';
      final parsed = parsePara(xml);
      final out = buildXml(parsed);

      expect(out, contains('<w:keepNext'));
      expect(out, contains('<w:keepLines'));
      expect(out, contains('<w:pageBreakBefore'));
      expect(out, contains('<w:widowControl w:val="0"'));
      expect(out, contains('<w:bidi'));
      expect(out, contains('<w:suppressAutoHyphens'));
      expect(out, contains('<w:contextualSpacing'));
      expect(out, contains('<w:tab'));
      expect(out, contains('w:leader="dot"'));

      // Re-parse the produced XML — values must be stable.
      final reparsed = parseParaDoc(out);
      expect(reparsed.isRtl, isTrue);
      expect(reparsed.keepWithNext, isTrue);
      expect(reparsed.keepLines, isTrue);
      expect(reparsed.pageBreakBefore, isTrue);
      expect(reparsed.widowControl, isFalse);
      expect(reparsed.suppressHyphens, isTrue);
      expect(reparsed.contextualSpacing, isTrue);
      expect(reparsed.tabStops.single.alignment, DocxTabAlignment.right);
      expect(reparsed.tabStops.single.leader, DocxTabLeader.dot);
    });

    test('default paragraph omits the optional flags', () {
      final out = buildXml(const DocxParagraph(children: [DocxText('x')]));
      expect(out, isNot(contains('w:keepNext')));
      expect(out, isNot(contains('w:bidi')));
      expect(out, isNot(contains('w:widowControl')));
      expect(out, isNot(contains('w:contextualSpacing')));
    });
  });

  // 03-run-rpr.md item 1: the paragraph-mark run size (w:pPr/w:rPr/w:sz) is read
  // directly and drives an empty paragraph's height in the viewer.
  group('A.1 paragraph-mark run size (w:pPr/w:rPr/w:sz)', () {
    test('mark sz → markRunFontSize (half-points → points)', () {
      final p = parsePara('<w:pPr><w:rPr><w:sz w:val="48"/></w:rPr></w:pPr>');
      expect(p.markRunFontSize, 24.0);
    });

    test('no mark rPr/sz → null (common case unchanged)', () {
      expect(parsePara('<w:pPr/>').markRunFontSize, isNull);
      expect(parsePara('<w:pPr><w:rPr><w:b/></w:rPr></w:pPr>').markRunFontSize,
          isNull);
    });

    test('round-trips through buildXml (pPr/rPr/sz+szCs) and re-parses', () {
      final out =
          buildXml(const DocxParagraph(children: [], markRunFontSize: 24));
      expect(out, contains('<w:rPr>'));
      expect(out, contains('<w:sz w:val="48"/>'));
      expect(out, contains('<w:szCs w:val="48"/>'));
      expect(parseParaDoc(out).markRunFontSize, 24.0);
    });
  });
}
