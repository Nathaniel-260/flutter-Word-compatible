import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

String _settings(String inner) =>
    '<w:settings $_ns>$inner</w:settings>';

void main() {
  group('A.6 settings.xml', () {
    test('defaults when settings.xml is missing', () {
      final s = DocxReader.parseSettings(null);
      expect(s.defaultTabStop, 720);
      expect(s.evenAndOddHeaders, isFalse);
      expect(s.footnoteProperties, isNull);
      expect(s.endnoteProperties, isNull);
    });

    test('w:defaultTabStop overrides the default', () {
      final s = DocxReader.parseSettings(
          _settings('<w:defaultTabStop w:val="480"/>'));
      expect(s.defaultTabStop, 480);
    });

    test('w:evenAndOddHeaders toggle', () {
      expect(
          DocxReader.parseSettings(_settings('<w:evenAndOddHeaders/>'))
              .evenAndOddHeaders,
          isTrue);
      expect(
          DocxReader.parseSettings(
                  _settings('<w:evenAndOddHeaders w:val="false"/>'))
              .evenAndOddHeaders,
          isFalse);
    });

    test('global footnotePr / endnotePr', () {
      final s = DocxReader.parseSettings(_settings('''
        <w:footnotePr><w:pos w:val="pageBottom"/><w:numFmt w:val="decimal"/><w:numRestart w:val="eachPage"/></w:footnotePr>
        <w:endnotePr><w:pos w:val="docEnd"/><w:numFmt w:val="lowerRoman"/></w:endnotePr>'''));
      expect(s.footnoteProperties!.position, DocxNotePosition.pageBottom);
      expect(s.footnoteProperties!.format, DocxPageNumberFormat.decimal);
      expect(s.footnoteProperties!.numRestart, DocxNoteNumberRestart.eachPage);
      expect(s.endnoteProperties!.position, DocxNotePosition.docEnd);
      expect(s.endnoteProperties!.format, DocxPageNumberFormat.lowerRoman);
    });

    test('malformed XML falls back to defaults without throwing', () {
      final s = DocxReader.parseSettings('<not valid');
      expect(s.defaultTabStop, 720);
    });

    // 14-settings.md item 14: displayBackgroundShape gates page-background paint.
    test('w:displayBackgroundShape toggle (default off)', () {
      expect(DocxReader.parseSettings(null).displayBackgroundShape, isFalse);
      expect(
          DocxReader.parseSettings(_settings('<w:displayBackgroundShape/>'))
              .displayBackgroundShape,
          isTrue);
      expect(
          DocxReader.parseSettings(
                  _settings('<w:displayBackgroundShape w:val="false"/>'))
              .displayBackgroundShape,
          isFalse);
    });
  });
}
