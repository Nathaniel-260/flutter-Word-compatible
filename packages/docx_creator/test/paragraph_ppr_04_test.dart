import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

/// Parse a body fragment (sequence of block children) into [DocxNode]s through
/// the block-grouping path (`parseBlocks`), so list coalescing is exercised.
List<DocxNode> parseBody(String inner) {
  final parser = BlockParser(ReaderContext(Archive()));
  final doc = XmlDocument.parse('<w:body $_ns>$inner</w:body>');
  return parser.parseBlocks(doc.rootElement.children);
}

/// Parse a single `<w:p>` snippet into a [DocxParagraph].
DocxParagraph parsePara(String inner) {
  final parser = BlockParser(ReaderContext(Archive()));
  final doc = XmlDocument.parse('<w:p $_ns>$inner</w:p>');
  return parser.parseParagraph(doc.rootElement);
}

void main() {
  // 04-paragraph-ppr.md item 19 — `w:numId="0"` explicitly cancels an inherited
  // list (ISO/IEC 29500 §17.9.18). Word renders the paragraph plain; it must NOT
  // be grouped into a list with a bogus default bullet.
  group('numId=0 cancels numbering (item 19)', () {
    test('numId=0 paragraph is a plain paragraph, not a list', () {
      final nodes = parseBody('''
        <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="0"/></w:numPr></w:pPr>
          <w:r><w:t>cancelled</w:t></w:r></w:p>''');
      expect(nodes, hasLength(1));
      expect(nodes.single, isA<DocxParagraph>());
      expect(nodes.whereType<DocxList>(), isEmpty);
    });

    test('a real numId still produces a list', () {
      final nodes = parseBody('''
        <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="3"/></w:numPr></w:pPr>
          <w:r><w:t>item</w:t></w:r></w:p>''');
      expect(nodes.whereType<DocxList>(), hasLength(1));
    });

    test('numId=0 between real list items breaks the list', () {
      final nodes = parseBody('''
        <w:p><w:pPr><w:numPr><w:numId w:val="3"/></w:numPr></w:pPr><w:r><w:t>a</w:t></w:r></w:p>
        <w:p><w:pPr><w:numPr><w:numId w:val="0"/></w:numPr></w:pPr><w:r><w:t>plain</w:t></w:r></w:p>
        <w:p><w:pPr><w:numPr><w:numId w:val="3"/></w:numPr></w:pPr><w:r><w:t>b</w:t></w:r></w:p>''');
      expect(nodes.whereType<DocxList>(), hasLength(2));
      expect(nodes.whereType<DocxParagraph>(), hasLength(1));
    });
  });

  // 04-paragraph-ppr.md item 47 — when both `w:hanging` and `w:firstLine` are
  // present, Word's hanging indent wins (ISO/IEC 29500 §17.3.1.12). Stored as a
  // signed value: hanging → negative, firstLine → positive.
  group('hanging wins over firstLine (item 47)', () {
    test('both present → hanging (negative) wins', () {
      final p = parsePara(
          '<w:pPr><w:ind w:firstLine="240" w:hanging="360"/></w:pPr>');
      expect(p.indentFirstLine, -360);
    });

    test('firstLine alone → positive', () {
      final p = parsePara('<w:pPr><w:ind w:firstLine="240"/></w:pPr>');
      expect(p.indentFirstLine, 240);
    });

    test('hanging alone → negative', () {
      final p = parsePara('<w:pPr><w:ind w:hanging="360"/></w:pPr>');
      expect(p.indentFirstLine, -360);
    });
  });

  // 04-paragraph-ppr.md — paragraph on/off flags now inherit through the style
  // engine (`direct ?? style ?? default`), not direct-pPr only. Critical for
  // Hebrew: a body style that sets `w:bidi` makes its paragraphs RTL.
  group('paragraph flags inherit from style', () {
    XmlElement pprOf(String inner) =>
        XmlDocument.parse('<w:pPr $_ns>$inner</w:pPr>').rootElement;

    DocxParagraph parseWithStyles(
        String paraXml, Map<String, DocxStyle> styles) {
      final ctx = ReaderContext(Archive());
      ctx.styles.addAll(styles);
      return BlockParser(ctx)
          .parseParagraph(XmlDocument.parse(paraXml).rootElement);
    }

    test('w:bidi from style → isRtl (Hebrew body style)', () {
      final styles = {
        'HebrewBody': DocxStyle.fromXml('HebrewBody',
            type: 'paragraph', pPr: pprOf('<w:bidi/><w:keepNext/>')),
      };
      final p = parseWithStyles(
          '<w:p $_ns><w:pPr><w:pStyle w:val="HebrewBody"/></w:pPr>'
          '<w:r><w:t>שלום</w:t></w:r></w:p>',
          styles);
      expect(p.isRtl, isTrue);
      expect(p.keepWithNext, isTrue);
    });

    test('direct pPr overrides the inherited flag (bidi off)', () {
      final styles = {
        'HebrewBody': DocxStyle.fromXml('HebrewBody',
            type: 'paragraph', pPr: pprOf('<w:bidi/>')),
      };
      final p = parseWithStyles(
          '<w:p $_ns><w:pPr><w:pStyle w:val="HebrewBody"/>'
          '<w:bidi w:val="0"/></w:pPr><w:r><w:t>x</w:t></w:r></w:p>',
          styles);
      expect(p.isRtl, isFalse);
    });

    test('outlineLvl and textAlignment inherit from style', () {
      final styles = {
        'Heading9': DocxStyle.fromXml('Heading9',
            type: 'paragraph',
            pPr: pprOf(
                '<w:outlineLvl w:val="3"/><w:textAlignment w:val="center"/>')),
      };
      final p = parseWithStyles(
          '<w:p $_ns><w:pPr><w:pStyle w:val="Heading9"/></w:pPr></w:p>',
          styles);
      expect(p.outlineLevel, 3);
      expect(p.textAlignment, DocxTextAlignment.center);
    });

    test('no style + no direct flag → defaults (widowControl on)', () {
      final p = parsePara('<w:pPr/>');
      expect(p.widowControl, isTrue);
      expect(p.keepWithNext, isFalse);
      expect(p.isRtl, isFalse);
    });
  });
}
