import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

/// 07-styles.md item 5: a paragraph with no `w:pStyle` inherits the style marked
/// `w:default="1"` (paragraph type), not a hardcoded 'Normal'. Critical for files
/// whose default style is named otherwise (e.g. LibreOffice's 'Standard').
void main() {
  DocxParagraph parseWithStyles(String stylesXml, String paraXml) {
    final ctx = ReaderContext(Archive());
    StyleParser(ctx).parse(stylesXml);
    return BlockParser(ctx)
        .parseParagraph(XmlDocument.parse(paraXml).rootElement);
  }

  test('default style id is read from w:default="1"', () {
    final ctx = ReaderContext(Archive());
    StyleParser(ctx).parse('''<w:styles $_ns>
      <w:style w:type="paragraph" w:default="1" w:styleId="Standard">
        <w:name w:val="Standard"/></w:style>
    </w:styles>''');
    expect(ctx.defaultParagraphStyleId, 'Standard');
  });

  test('a no-pStyle paragraph inherits the default style\'s formatting', () {
    final styles = '''<w:styles $_ns>
      <w:style w:type="paragraph" w:default="1" w:styleId="Standard">
        <w:pPr><w:jc w:val="center"/><w:bidi/></w:pPr>
      </w:style>
    </w:styles>''';
    final p = parseWithStyles(styles, '<w:p $_ns><w:r><w:t>x</w:t></w:r></w:p>');
    expect(p.align, DocxAlign.center);
    expect(p.isRtl, isTrue); // inherits bidi from the default style
  });

  test('without any w:default the fallback stays Normal', () {
    final ctx = ReaderContext(Archive());
    StyleParser(ctx).parse('''<w:styles $_ns>
      <w:style w:type="paragraph" w:styleId="Body"><w:name w:val="Body"/></w:style>
    </w:styles>''');
    expect(ctx.defaultParagraphStyleId, 'Normal');
  });
}
