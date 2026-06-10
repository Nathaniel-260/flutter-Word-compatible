import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

const _ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
    'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"';

List<DocxInline> parseInlines(String inner) {
  final parser = InlineParser(ReaderContext(Archive()));
  final doc = XmlDocument.parse('<w:p $_ns>$inner</w:p>');
  return parser.parseChildren(doc.rootElement.children);
}

String buildXml(DocxInline node) {
  final builder = XmlBuilder();
  node.buildXml(builder);
  return builder.buildDocument().toXmlString();
}

void main() {
  group('A.3 simple inline runs', () {
    test('w:cr → line break', () {
      final i = parseInlines('<w:r><w:cr/></w:r>');
      expect(i.single, isA<DocxLineBreak>());
      expect((i.single as DocxLineBreak).isPageBreak, isFalse);
    });

    test('noBreakHyphen / softHyphen → unicode text', () {
      final nb = parseInlines('<w:r><w:noBreakHyphen/></w:r>');
      expect((nb.single as DocxText).content, '‑');
      final soft = parseInlines('<w:r><w:softHyphen/></w:r>');
      expect((soft.single as DocxText).content, '­');
    });
  });

  group('A.3 w:sym', () {
    test('parses font + char and strips PUA offset', () {
      final i = parseInlines('<w:r><w:sym w:font="Wingdings" w:char="F0E0"/></w:r>');
      final sym = i.single as DocxSymbol;
      expect(sym.font, 'Wingdings');
      expect(sym.charCode, 0xF0E0);
      expect(sym.glyphIndex, 0xE0);
    });

    test('round-trips through buildXml', () {
      final out =
          buildXml(const DocxSymbol(charCode: 0xF0E0, font: 'Wingdings'));
      expect(out, contains('<w:sym'));
      expect(out, contains('w:font="Wingdings"'));
      expect(out, contains('w:char="F0E0"'));
    });
  });

  group('A.3 w:ptab', () {
    test('parses alignment / relativeTo / leader', () {
      final i = parseInlines(
          '<w:r><w:ptab w:alignment="center" w:relativeTo="indent" w:leader="dot"/></w:r>');
      final pt = i.single as DocxPositionalTab;
      expect(pt.alignment, DocxTabAlignment.center);
      expect(pt.relativeTo, DocxPtabRelativeTo.indent);
      expect(pt.leader, DocxTabLeader.dot);
    });

    test('round-trips through buildXml', () {
      final out = buildXml(const DocxPositionalTab(
        alignment: DocxTabAlignment.right,
        relativeTo: DocxPtabRelativeTo.margin,
        leader: DocxTabLeader.hyphen,
      ));
      expect(out, contains('<w:ptab'));
      expect(out, contains('w:alignment="right"'));
      expect(out, contains('w:relativeTo="margin"'));
      expect(out, contains('w:leader="hyphen"'));
    });
  });

  group('A.3 track changes', () {
    test('w:ins content is shown, w:del content is dropped', () {
      final i = parseInlines(
          '<w:ins><w:r><w:t>kept</w:t></w:r></w:ins>'
          '<w:del><w:r><w:delText>gone</w:delText></w:r></w:del>'
          '<w:r><w:t> tail</w:t></w:r>');
      final text = i.whereType<DocxText>().map((t) => t.content).join();
      expect(text, contains('kept'));
      expect(text, isNot(contains('gone')));
      expect(text, contains(' tail'));
    });

    test('w:moveTo shown, w:moveFrom dropped', () {
      final i = parseInlines(
          '<w:moveTo><w:r><w:t>moved</w:t></w:r></w:moveTo>'
          '<w:moveFrom><w:r><w:t>old</w:t></w:r></w:moveFrom>');
      final text = i.whereType<DocxText>().map((t) => t.content).join();
      expect(text, 'moved');
    });
  });

  group('A.3 mc:AlternateContent', () {
    test('prefers mc:Choice content', () {
      final i = parseInlines('''<mc:AlternateContent>
        <mc:Choice Requires="wps"><w:r><w:t>modern</w:t></w:r></mc:Choice>
        <mc:Fallback><w:r><w:t>legacy</w:t></w:r></mc:Fallback>
      </mc:AlternateContent>''');
      final text = i.whereType<DocxText>().map((t) => t.content).join();
      expect(text, 'modern');
    });

    test('falls back to mc:Fallback when no Choice', () {
      final i = parseInlines('''<mc:AlternateContent>
        <mc:Fallback><w:r><w:t>legacy</w:t></w:r></mc:Fallback>
      </mc:AlternateContent>''');
      final text = i.whereType<DocxText>().map((t) => t.content).join();
      expect(text, 'legacy');
    });
  });
}
