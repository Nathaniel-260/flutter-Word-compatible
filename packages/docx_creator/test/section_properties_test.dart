import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

DocxSectionDef parseSection(String sectInner) {
  final parser = SectionParser(ReaderContext(Archive()));
  final doc =
      XmlDocument.parse('<w:body $_ns><w:sectPr>$sectInner</w:sectPr></w:body>');
  return parser.parse(doc.rootElement);
}

String buildXml(DocxSectionDef s) {
  final builder = XmlBuilder();
  s.buildXml(builder);
  return builder.buildDocument().toXmlString();
}

void main() {
  group('A.5 section properties — parsing', () {
    test('w:cols (equal width) + separator', () {
      final s = parseSection('<w:cols w:num="2" w:space="708" w:sep="1"/>');
      expect(s.columns, isNotNull);
      expect(s.columns!.count, 2);
      expect(s.columns!.spaceTwips, 708);
      expect(s.columns!.equalWidth, isTrue);
      expect(s.columns!.separator, isTrue);
    });

    test('w:cols with explicit columns', () {
      final s = parseSection('''<w:cols w:num="2" w:equalWidth="0">
        <w:col w:w="4000" w:space="200"/>
        <w:col w:w="4000"/>
      </w:cols>''');
      expect(s.columns!.equalWidth, isFalse);
      expect(s.columns!.explicit, hasLength(2));
      expect(s.columns!.explicit![0].widthTwips, 4000);
      expect(s.columns!.explicit![0].spaceTwips, 200);
    });

    test('explicit columns without w:equalWidth infer equalWidth=false', () {
      // Absent attribute + explicit w:col ⇒ not equal-width, so the widths are
      // preserved (and re-emitted) on round-trip.
      final s = parseSection('''<w:cols w:num="2">
        <w:col w:w="4000" w:space="200"/>
        <w:col w:w="4000"/>
      </w:cols>''');
      expect(s.columns!.equalWidth, isFalse);
      expect(s.columns!.explicit, hasLength(2));
      final out = buildXml(s);
      expect(out, contains('<w:col'));
      expect(out, contains('w:w="4000"'));
    });

    test('w:vAlign / w:bidi / w:rtlGutter', () {
      final s = parseSection('<w:vAlign w:val="center"/><w:bidi/><w:rtlGutter/>');
      expect(s.vAlign, DocxSectionVAlign.center);
      expect(s.isRtlSection, isTrue);
      expect(s.rtlGutter, isTrue);
    });

    test('w:pgBorders', () {
      final s = parseSection('''<w:pgBorders w:offsetFrom="page" w:display="firstPage" w:zOrder="back">
        <w:top w:val="double" w:sz="24" w:space="24" w:color="FF0000"/>
        <w:bottom w:val="single" w:sz="12" w:space="24"/>
      </w:pgBorders>''');
      expect(s.pageBorders, isNotNull);
      expect(s.pageBorders!.offsetFrom, DocxPageBorderOffsetFrom.page);
      expect(s.pageBorders!.display, DocxPageBorderDisplay.firstPage);
      expect(s.pageBorders!.zOrderBack, isTrue);
      expect(s.pageBorders!.top!.style, DocxBorder.double);
      expect(s.pageBorders!.top!.size, 24);
      expect(s.pageBorders!.left, isNull);
    });

    test('w:lnNumType', () {
      final s = parseSection(
          '<w:lnNumType w:countBy="5" w:start="1" w:distance="360" w:restart="newPage"/>');
      expect(s.lineNumbering!.countBy, 5);
      expect(s.lineNumbering!.start, 1);
      expect(s.lineNumbering!.distance, 360);
      expect(s.lineNumbering!.restart, DocxLineNumberRestart.newPage);
    });

    test('w:footnotePr / w:endnotePr', () {
      final s = parseSection('''
        <w:footnotePr><w:pos w:val="pageBottom"/><w:numFmt w:val="lowerRoman"/><w:numRestart w:val="eachPage"/></w:footnotePr>
        <w:endnotePr><w:pos w:val="docEnd"/><w:numFmt w:val="decimal"/></w:endnotePr>''');
      expect(s.footnoteProperties!.position, DocxNotePosition.pageBottom);
      expect(s.footnoteProperties!.format, DocxPageNumberFormat.lowerRoman);
      expect(s.footnoteProperties!.numRestart, DocxNoteNumberRestart.eachPage);
      expect(s.endnoteProperties!.position, DocxNotePosition.docEnd);
      expect(s.endnoteProperties!.format, DocxPageNumberFormat.decimal);
    });
  });

  group('A.5 section properties — round-trip (buildXml)', () {
    test('new section elements survive parse → build → parse', () {
      const xml = '''
        <w:footnotePr><w:pos w:val="beneathText"/><w:numRestart w:val="eachSect"/></w:footnotePr>
        <w:pgSz w:w="11906" w:h="16838"/>
        <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720"/>
        <w:pgBorders w:offsetFrom="text" w:display="allPages">
          <w:top w:val="single" w:sz="4" w:space="24" w:color="000000"/>
        </w:pgBorders>
        <w:lnNumType w:countBy="1" w:restart="continuous"/>
        <w:cols w:num="3" w:space="425"/>
        <w:vAlign w:val="both"/>
        <w:bidi/>
        <w:rtlGutter/>''';
      final parsed = parseSection(xml);
      final out = buildXml(parsed);

      expect(out, contains('<w:footnotePr'));
      expect(out, contains('<w:pgBorders'));
      expect(out, contains('<w:lnNumType'));
      expect(out, contains('w:num="3"'));
      expect(out, contains('<w:vAlign w:val="both"'));
      expect(out, contains('<w:bidi'));
      expect(out, contains('<w:rtlGutter'));

      // Re-parse: take the produced w:sectPr's children back through the parser.
      final sectEl = XmlDocument.parse(out).rootElement;
      final inner = sectEl.children.map((c) => c.toXmlString()).join();
      final re = parseSection(inner);
      expect(re.columns!.count, 3);
      expect(re.vAlign, DocxSectionVAlign.both);
      expect(re.isRtlSection, isTrue);
      expect(re.rtlGutter, isTrue);
      expect(re.pageBorders!.top!.style, DocxBorder.single);
      expect(re.lineNumbering!.restart, DocxLineNumberRestart.continuous);
      expect(re.footnoteProperties!.position, DocxNotePosition.beneathText);
    });

    test('default section omits the new optional elements', () {
      final out = buildXml(const DocxSectionDef());
      expect(out, isNot(contains('w:cols')));
      expect(out, isNot(contains('w:pgBorders')));
      expect(out, isNot(contains('w:vAlign')));
      expect(out, isNot(contains('w:bidi')));
      expect(out, isNot(contains('w:lnNumType')));
    });
  });
}
