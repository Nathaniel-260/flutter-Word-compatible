import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

const _ns =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

DocxText _parseRun(String inner) {
  final parser = InlineParser(ReaderContext(Archive()));
  final doc = XmlDocument.parse('<w:r $_ns>$inner</w:r>');
  return parser.parseRun(doc.rootElement) as DocxText;
}

DocxParagraph _parsePara(String inner) {
  final parser = BlockParser(ReaderContext(Archive()));
  final doc = XmlDocument.parse('<w:p $_ns>$inner</w:p>');
  return parser.parseParagraph(doc.rootElement);
}

DocxTable _parseTable(String inner) {
  final ctx = ReaderContext(Archive());
  final parser = TableParser(ctx, InlineParser(ctx));
  final doc = XmlDocument.parse('<w:tbl $_ns>$inner</w:tbl>');
  return parser.parse(doc.rootElement);
}

String _buildXml(DocxBlock block) {
  final builder = XmlBuilder();
  block.buildXml(builder);
  return builder.buildDocument().toXmlString();
}

XmlElement _shd(String attrs) =>
    XmlDocument.parse('<w:shd $_ns $attrs/>').rootElement;

void main() {
  // ===========================================================================
  // §2.3 — w:shd three-part shading (items 18, 20)
  // ===========================================================================
  group('§2.3 w:shd → effective flat fill (resolveShdFill)', () {
    test('clear keeps the fill (legacy behaviour)', () {
      final r = resolveShdFill(_shd('w:val="clear" w:fill="D9D9D9"'));
      expect(r.fill, 'D9D9D9');
      expect(r.themeFill, isNull);
    });

    test('absent w:val defaults to clear', () {
      expect(resolveShdFill(_shd('w:fill="CCCCCC"')).fill, 'CCCCCC');
    });

    test('nil / none → no shading', () {
      expect(resolveShdFill(_shd('w:val="nil" w:fill="D9D9D9"')).fill, isNull);
      expect(resolveShdFill(_shd('w:val="none" w:fill="D9D9D9"')).fill, isNull);
    });

    test('solid uses the pattern colour, not the fill', () {
      // The bug this fixes: a solid shd previously rendered with no background
      // because only w:fill was read and a solid carries its colour in w:color.
      final r =
          resolveShdFill(_shd('w:val="solid" w:color="FF0000" w:fill="00FF00"'));
      expect(r.fill, 'FF0000');
    });

    test('solid with a theme colour maps to the theme-fill slots', () {
      final r = resolveShdFill(_shd(
          'w:val="solid" w:themeColor="accent1" w:themeTint="99"'));
      expect(r.fill, isNull);
      expect(r.themeFill, 'accent1');
      expect(r.themeFillTint, '99');
    });

    test('pct50 blends colour over fill (plain hex)', () {
      // 50% of black over white → mid-grey 0x80.
      final r =
          resolveShdFill(_shd('w:val="pct50" w:color="000000" w:fill="FFFFFF"'));
      expect(r.fill, '808080');
    });

    test('pct25 blends at the pattern coverage', () {
      // 25% of black over white → 255*0.75 = 191.25 → 0xBF.
      final r =
          resolveShdFill(_shd('w:val="pct25" w:color="000000" w:fill="FFFFFF"'));
      expect(r.fill, 'BFBFBF');
    });

    test('pattern with no fill blends against white', () {
      final r = resolveShdFill(_shd('w:val="pct50" w:color="000000"'));
      expect(r.fill, '808080');
    });

    test('theme-driven pattern keeps the fill (documented deviation)', () {
      final r = resolveShdFill(
          _shd('w:val="pct50" w:themeColor="accent1" w:fill="EEEEEE"'));
      expect(r.fill, 'EEEEEE');
    });

    test('run-level solid shd reaches DocxText (Hebrew+English)', () {
      final run = _parseRun(
          '<w:rPr><w:shd w:val="solid" w:color="FFFF00"/></w:rPr>'
          '<w:t>שלום world</w:t>');
      expect(run.content, 'שלום world');
      expect(run.shadingFill, 'FFFF00');
    });

    test('paragraph-level solid shd reaches DocxParagraph', () {
      final p = _parsePara(
          '<w:pPr><w:shd w:val="solid" w:color="123456"/></w:pPr>'
          '<w:r><w:t>טקסט mixed</w:t></w:r>');
      expect(p.shadingFill, '123456');
    });

    test('cell-level solid shd reaches DocxTableCell', () {
      final t = _parseTable(
          '<w:tblGrid><w:gridCol w:w="5000"/></w:tblGrid>'
          '<w:tr><w:tc>'
          '<w:tcPr><w:shd w:val="solid" w:color="ABCDEF"/></w:tcPr>'
          '<w:p><w:r><w:t>תא cell</w:t></w:r></w:p>'
          '</w:tc></w:tr>');
      expect(t.rows.first.cells.first.shadingFill, 'ABCDEF');
    });
  });

  // ===========================================================================
  // §2.4 — CT_Border space + theme colour (items 23, 24) on a paragraph border
  // ===========================================================================
  group('§2.4 CT_Border space / theme colour / rawVal', () {
    test('w:space, theme colour and an unknown val are all read', () {
      final p = _parsePara('<w:pPr><w:pBdr>'
          '<w:top w:val="single" w:sz="8" w:space="4" '
          'w:themeColor="accent2" w:themeTint="66"/>'
          '<w:bottom w:val="wavyDouble" w:sz="6" w:space="2"/>'
          '</w:pBdr></w:pPr><w:r><w:t>גבול border</w:t></w:r>');

      final top = p.borderTop!;
      expect(top.space, 4);
      expect(top.themeColor, 'accent2');
      expect(top.themeTint, '66');

      final bottom = p.borderBottomSide!;
      expect(bottom.space, 2);
      // An unmodelled style token is preserved verbatim.
      expect(bottom.rawVal, 'wavyDouble');
    });

    test('border space + theme colour round-trip through buildXml', () {
      final p = _parsePara('<w:pPr><w:pBdr>'
          '<w:top w:val="single" w:sz="8" w:space="4" w:themeColor="accent2"/>'
          '</w:pBdr></w:pPr><w:r><w:t>x</w:t></w:r>');
      final xml = _buildXml(p);
      expect(xml, contains('w:space="4"'));
      expect(xml, contains('w:themeColor="accent2"'));
    });

    test('absent w:space defaults to 0 (no regression)', () {
      final p = _parsePara('<w:pPr><w:pBdr>'
          '<w:top w:val="single" w:sz="8"/>'
          '</w:pBdr></w:pPr><w:r><w:t>x</w:t></w:r>');
      expect(p.borderTop!.space, 0);
      expect(p.borderTop!.themeColor, isNull);
    });
  });

  // ===========================================================================
  // §2 — percentage-string table width (item 6)
  // ===========================================================================
  group('§2 table width as a percentage string (w:w="50%")', () {
    DocxTable widthTable(String tblW) => _parseTable(
          '<w:tblPr>$tblW</w:tblPr>'
          '<w:tblGrid><w:gridCol w:w="5000"/></w:tblGrid>'
          '<w:tr><w:tc><w:p><w:r><w:t>x</w:t></w:r></w:p></w:tc></w:tr>',
        );

    test('"50%" → pct width 2500 fiftieths (was dropped silently)', () {
      final t = widthTable('<w:tblW w:w="50%" w:type="pct"/>');
      expect(t.widthType, DocxWidthType.pct);
      expect(t.width, 2500);
    });

    test('"100%" → 5000 fiftieths', () {
      final t = widthTable('<w:tblW w:w="100%" w:type="pct"/>');
      expect(t.width, 5000);
    });

    test('numeric fiftieths form is unchanged', () {
      final t = widthTable('<w:tblW w:w="2500" w:type="pct"/>');
      expect(t.widthType, DocxWidthType.pct);
      expect(t.width, 2500);
    });

    test('numeric dxa form is unchanged', () {
      final t = widthTable('<w:tblW w:w="7200" w:type="dxa"/>');
      expect(t.widthType, DocxWidthType.dxa);
      expect(t.width, 7200);
    });
  });
}
