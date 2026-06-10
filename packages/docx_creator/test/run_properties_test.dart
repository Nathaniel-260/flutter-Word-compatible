import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

/// Parse a single `<w:r>` snippet into a [DocxText].
DocxText parseRun(String inner) {
  final parser = InlineParser(ReaderContext(Archive()));
  final doc = XmlDocument.parse('<w:r $_ns>$inner</w:r>');
  final node = parser.parseRun(doc.rootElement);
  return node as DocxText;
}

String buildXml(DocxInline node) {
  final builder = XmlBuilder();
  node.buildXml(builder);
  return builder.buildDocument().toXmlString();
}

void main() {
  group('A.2 run properties — parsing', () {
    test('w:rtl / w:bCs / w:iCs toggles', () {
      final p = parseRun(
          '<w:rPr><w:rtl/><w:bCs/><w:iCs w:val="0"/></w:rPr><w:t>x</w:t>');
      expect(p.rtl, isTrue);
      expect(p.boldCs, isTrue);
      expect(p.italicCs, isFalse);
      // absent → null
      final plain = parseRun('<w:rPr/><w:t>y</w:t>');
      expect(plain.rtl, isNull);
      expect(plain.boldCs, isNull);
    });

    test('w:szCs → fontSizeCs in points', () {
      final p = parseRun('<w:rPr><w:szCs w:val="28"/></w:rPr><w:t>x</w:t>');
      expect(p.fontSizeCs, 14.0);
    });

    test('w:kern / w:position / w:w / w:fitText', () {
      final p = parseRun('''<w:rPr>
        <w:kern w:val="20"/>
        <w:position w:val="-6"/>
        <w:w w:val="150"/>
        <w:fitText w:val="1440"/>
      </w:rPr><w:t>x</w:t>''');
      expect(p.kernMinHalfPoints, 20);
      expect(p.raiseLowerHalfPoints, -6);
      expect(p.charScalePercent, 150);
      expect(p.fitTextTwips, 1440);
    });

    test('w:vanish → hidden; w:em → emphasisMark', () {
      final p =
          parseRun('<w:rPr><w:vanish/><w:em w:val="dot"/></w:rPr><w:t>x</w:t>');
      expect(p.hidden, isTrue);
      expect(p.emphasisMark, DocxEmphasisMark.dot);
      expect(parseRun('<w:rPr/><w:t>y</w:t>').hidden, isFalse);
    });
  });

  group('A.2 run properties — round-trip (buildXml)', () {
    test('all new rPr props survive parse → build → parse', () {
      const xml = '''<w:rPr>
        <w:bCs/>
        <w:iCs/>
        <w:vanish/>
        <w:w w:val="200"/>
        <w:kern w:val="18"/>
        <w:position w:val="4"/>
        <w:sz w:val="24"/>
        <w:szCs w:val="32"/>
        <w:fitText w:val="720"/>
        <w:rtl/>
        <w:em w:val="circle"/>
      </w:rPr><w:t>שלום</w:t>''';
      final parsed = parseRun(xml);
      final out = buildXml(parsed);

      expect(out, contains('<w:bCs'));
      expect(out, contains('<w:iCs'));
      expect(out, contains('<w:vanish'));
      expect(out, contains('w:val="200"')); // w:w
      expect(out, contains('<w:kern'));
      expect(out, contains('<w:position'));
      expect(out, contains('<w:szCs w:val="32"'));
      expect(out, contains('<w:fitText'));
      expect(out, contains('<w:rtl'));
      expect(out, contains('w:val="circle"'));

      final reparser = InlineParser(ReaderContext(Archive()));
      final reparsed =
          reparser.parseRun(XmlDocument.parse(out).rootElement) as DocxText;
      expect(reparsed.rtl, isTrue);
      expect(reparsed.boldCs, isTrue);
      expect(reparsed.italicCs, isTrue);
      expect(reparsed.hidden, isTrue);
      expect(reparsed.charScalePercent, 200);
      expect(reparsed.kernMinHalfPoints, 18);
      expect(reparsed.raiseLowerHalfPoints, 4);
      expect(reparsed.fontSize, 12.0);
      expect(reparsed.fontSizeCs, 16.0);
      expect(reparsed.fitTextTwips, 720);
      expect(reparsed.emphasisMark, DocxEmphasisMark.circle);
    });

    test('szCs mirrors sz when fontSizeCs is unset', () {
      final out = buildXml(const DocxText('x', fontSize: 11));
      expect(out, contains('<w:sz w:val="22"'));
      expect(out, contains('<w:szCs w:val="22"'));
    });

    test('plain run emits no advanced rPr elements', () {
      final out = buildXml(const DocxText('x'));
      expect(out, isNot(contains('w:rtl')));
      expect(out, isNot(contains('w:vanish')));
      expect(out, isNot(contains('w:szCs')));
    });
  });
}
