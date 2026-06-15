import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

/// Plan §G — verifies the reader parses Word's multilevel numbering controls
/// (`w:isLgl`, `w:suff`, `w:lvlJc`, `w:lvlRestart`) onto [DocxNumberingLevel].
String _numberingXml(String levels) => '''
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="0">
    $levels
  </w:abstractNum>
  <w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
</w:numbering>''';

DocxNumberingLevel parseLevel(String levelXml) {
  final parser = NumberingParser(ReaderContext(Archive()));
  parser.parse(_numberingXml(levelXml));
  return parser.getLevel(1, 0)!;
}

void main() {
  group('G — numbering level extras', () {
    test('isLgl / suff / lvlJc / lvlRestart are parsed', () {
      final lvl = parseLevel('''
        <w:lvl w:ilvl="0">
          <w:start w:val="1"/>
          <w:numFmt w:val="decimal"/>
          <w:lvlText w:val="%1.%2"/>
          <w:isLgl/>
          <w:suff w:val="space"/>
          <w:lvlJc w:val="right"/>
          <w:lvlRestart w:val="0"/>
        </w:lvl>''');

      expect(lvl.isLgl, isTrue);
      expect(lvl.suff, 'space');
      expect(lvl.lvlJc, 'right');
      expect(lvl.lvlRestart, 0);
    });

    test('defaults when the controls are absent', () {
      final lvl = parseLevel('''
        <w:lvl w:ilvl="0">
          <w:numFmt w:val="decimal"/>
          <w:lvlText w:val="%1."/>
        </w:lvl>''');

      expect(lvl.isLgl, isFalse);
      expect(lvl.suff, isNull); // unspecified → treated as tab downstream
      expect(lvl.lvlJc, isNull);
      expect(lvl.lvlRestart, isNull);
    });

    test('raw Hebrew formats are preserved on numFmt', () {
      final lvl = parseLevel('''
        <w:lvl w:ilvl="0">
          <w:numFmt w:val="hebrew1"/>
          <w:lvlText w:val="%1."/>
        </w:lvl>''');
      expect(lvl.numFmt, 'hebrew1');
    });
  });
}
