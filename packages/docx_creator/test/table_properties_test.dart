import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

DocxTable parseTable(String inner) {
  final ctx = ReaderContext(Archive());
  final parser = TableParser(ctx, InlineParser(ctx));
  final doc = XmlDocument.parse('<w:tbl $_ns>$inner</w:tbl>');
  return parser.parse(doc.rootElement);
}

String buildXml(DocxBlock block) {
  final builder = XmlBuilder();
  block.buildXml(builder);
  return builder.buildDocument().toXmlString();
}

const _cell = '<w:tc><w:tcPr><w:tcW w:w="5000" w:type="dxa"/></w:tcPr>'
    '<w:p><w:r><w:t>x</w:t></w:r></w:p></w:tc>';

void main() {
  group('A.4 table-level properties', () {
    test('bidiVisual / tblLayout / tblInd / tblCellMar / tblCellSpacing', () {
      final t = parseTable('''
        <w:tblPr>
          <w:bidiVisual/>
          <w:tblLayout w:type="fixed"/>
          <w:tblInd w:w="240" w:type="dxa"/>
          <w:tblCellSpacing w:w="15" w:type="dxa"/>
          <w:tblCellMar>
            <w:top w:w="0" w:type="nil"/>
            <w:left w:w="108" w:type="dxa"/>
            <w:right w:w="108" w:type="dxa"/>
          </w:tblCellMar>
        </w:tblPr>
        <w:tblGrid><w:gridCol w:w="5000"/></w:tblGrid>
        <w:tr>$_cell</w:tr>''');

      expect(t.bidiVisual, isTrue);
      expect(t.layout, DocxTableLayout.fixed);
      expect(t.indentTwips, 240);
      expect(t.cellSpacingTwips, 15);
      expect(t.defaultCellMargins, isNotNull);
      expect(t.defaultCellMargins!.top, 0); // nil → 0
      expect(t.defaultCellMargins!.left, 108);
      expect(t.defaultCellMargins!.bottom, isNull); // unspecified

      final out = buildXml(t);
      expect(out, contains('<w:bidiVisual'));
      expect(out, contains('<w:tblLayout w:type="fixed"'));
      expect(out, contains('<w:tblInd'));
      expect(out, contains('<w:tblCellSpacing'));
      expect(out, contains('<w:tblCellMar'));
    });
  });

  group('A.4 row-level properties', () {
    test('cantSplit / gridBefore / gridAfter / wBefore / wAfter', () {
      final t = parseTable('''
        <w:tblGrid><w:gridCol w:w="5000"/></w:tblGrid>
        <w:tr>
          <w:trPr>
            <w:cantSplit/>
            <w:gridBefore w:val="1"/>
            <w:gridAfter w:val="2"/>
            <w:wBefore w:w="300" w:type="dxa"/>
            <w:wAfter w:w="400" w:type="dxa"/>
          </w:trPr>
          $_cell
        </w:tr>''');

      final row = t.rows.single;
      expect(row.cantSplit, isTrue);
      expect(row.gridBefore, 1);
      expect(row.gridAfter, 2);
      expect(row.wBefore, 300);
      expect(row.wAfter, 400);

      final out = buildXml(t);
      expect(out, contains('<w:cantSplit'));
      expect(out, contains('<w:gridBefore'));
      expect(out, contains('<w:gridAfter'));
      expect(out, contains('<w:wBefore'));
      expect(out, contains('<w:wAfter'));
    });
  });

  group('A.4 cell-level properties', () {
    test('tcMar / textDirection / noWrap / tcFitText / hideMark', () {
      final t = parseTable('''
        <w:tblGrid><w:gridCol w:w="5000"/></w:tblGrid>
        <w:tr><w:tc>
          <w:tcPr>
            <w:tcW w:w="5000" w:type="dxa"/>
            <w:tcMar>
              <w:top w:w="20" w:type="dxa"/>
              <w:bottom w:w="20" w:type="dxa"/>
            </w:tcMar>
            <w:textDirection w:val="tbRl"/>
            <w:noWrap/>
            <w:tcFitText/>
            <w:hideMark/>
          </w:tcPr>
          <w:p><w:r><w:t>x</w:t></w:r></w:p>
        </w:tc></w:tr>''');

      final cell = t.rows.single.cells.single;
      expect(cell.margins, isNotNull);
      expect(cell.margins!.top, 20);
      expect(cell.margins!.bottom, 20);
      expect(cell.textDirection, DocxCellTextDirection.tbRl);
      expect(cell.noWrap, isTrue);
      expect(cell.tcFitText, isTrue);
      expect(cell.hideMark, isTrue);

      final out = buildXml(t);
      expect(out, contains('<w:tcMar'));
      expect(out, contains('<w:textDirection w:val="tbRl"'));
      expect(out, contains('<w:noWrap'));
      expect(out, contains('<w:tcFitText'));
      expect(out, contains('<w:hideMark'));
    });
  });

  test('A.4 defaults: a plain table omits the new optional elements', () {
    final out = buildXml(const DocxTable(rows: [
      DocxTableRow(cells: [
        DocxTableCell(children: [DocxParagraph(children: [DocxText('x')])]),
      ]),
    ]));
    expect(out, isNot(contains('w:bidiVisual')));
    expect(out, isNot(contains('w:tblLayout')));
    expect(out, isNot(contains('w:cantSplit')));
    expect(out, isNot(contains('w:textDirection')));
    expect(out, isNot(contains('w:noWrap')));
  });
}
