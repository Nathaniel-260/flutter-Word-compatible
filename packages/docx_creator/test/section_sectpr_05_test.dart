import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';

List<DocxNode> parseBody(String inner) {
  final parser = BlockParser(ReaderContext(Archive()));
  final doc = XmlDocument.parse('<w:body $_ns>$inner</w:body>');
  return parser.parseBlocks(doc.rootElement.children);
}

String buildSectionXml(DocxSectionDef def) {
  final b = XmlBuilder();
  def.buildXml(b);
  return b.buildDocument().toXmlString();
}

void main() {
  // 05-section-sectpr.md — structural gap: an intermediate section (`w:sectPr`
  // inside a paragraph's `w:pPr`) now goes through the full SectionParser, not a
  // pgSz+margins-only path, so it keeps columns / vAlign / bidi / type.
  group('intermediate section keeps full properties', () {
    test('columns, vAlign, bidi and break type survive', () {
      final nodes = parseBody('''
        <w:p><w:pPr><w:sectPr>
          <w:type w:val="continuous"/>
          <w:pgSz w:w="11906" w:h="16838"/>
          <w:cols w:num="2" w:space="708"/>
          <w:vAlign w:val="center"/>
          <w:bidi/>
        </w:sectPr></w:pPr></w:p>''');
      final brk = nodes.whereType<DocxSectionBreakBlock>().single;
      final s = brk.section;
      expect(s.breakType, DocxSectionBreak.continuous);
      expect(s.columns?.count, 2);
      expect(s.vAlign, DocxSectionVAlign.center);
      expect(s.isRtlSection, isTrue);
    });
  });

  // Item 6 — w:type is read (was always nextPage before).
  group('w:type → breakType (item 6)', () {
    DocxSectionBreak typeOf(String? val) {
      final inner = val == null ? '' : '<w:type w:val="$val"/>';
      final nodes =
          parseBody('<w:p><w:pPr><w:sectPr>$inner<w:pgSz w:w="11906" w:h="16838"/></w:sectPr></w:pPr></w:p>');
      return nodes.whereType<DocxSectionBreakBlock>().single.section.breakType;
    }

    test('continuous / evenPage / oddPage / default', () {
      expect(typeOf('continuous'), DocxSectionBreak.continuous);
      expect(typeOf('evenPage'), DocxSectionBreak.evenPage);
      expect(typeOf('oddPage'), DocxSectionBreak.oddPage);
      expect(typeOf(null), DocxSectionBreak.nextPage); // default
    });
  });

  group('breakType round-trips through buildXml', () {
    test('continuous is written; nextPage default is omitted', () {
      expect(
          buildSectionXml(const DocxSectionDef(
              breakType: DocxSectionBreak.continuous)),
          contains('<w:type w:val="continuous"'));
      expect(buildSectionXml(const DocxSectionDef()),
          isNot(contains('<w:type')));
    });
  });
}
