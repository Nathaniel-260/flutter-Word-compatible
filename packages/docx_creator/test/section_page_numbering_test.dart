import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/reader/docx_reader/parsers/section_parser.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('readOnOff (CT_OnOff semantics)', () {
    XmlElement el(String s) => XmlDocument.parse(
            '<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$s</w:p>')
        .rootElement
        .firstElementChild!;

    test('present without w:val is on', () {
      expect(readOnOff(el('<w:titlePg/>')), isTrue);
    });

    test('w:val="false"/"0"/"off" is off (explicit disable)', () {
      expect(readOnOff(el('<w:titlePg w:val="false"/>')), isFalse);
      expect(readOnOff(el('<w:titlePg w:val="0"/>')), isFalse);
      expect(readOnOff(el('<w:titlePg w:val="off"/>')), isFalse);
    });

    test('w:val="true"/"1" is on', () {
      expect(readOnOff(el('<w:titlePg w:val="true"/>')), isTrue);
      expect(readOnOff(el('<w:titlePg w:val="1"/>')), isTrue);
    });

    test('null element returns orElse', () {
      expect(readOnOff(null), isFalse);
      expect(readOnOff(null, orElse: true), isTrue);
    });
  });

  group('pgNumType attribute mapping', () {
    test('w:fmt maps to DocxPageNumberFormat', () {
      expect(SectionParser.mapPageNumberFormat('decimal'),
          DocxPageNumberFormat.decimal);
      expect(SectionParser.mapPageNumberFormat('lowerRoman'),
          DocxPageNumberFormat.lowerRoman);
      expect(SectionParser.mapPageNumberFormat('upperRoman'),
          DocxPageNumberFormat.upperRoman);
      expect(SectionParser.mapPageNumberFormat('lowerLetter'),
          DocxPageNumberFormat.lowerLetter);
      expect(SectionParser.mapPageNumberFormat('upperLetter'),
          DocxPageNumberFormat.upperLetter);
      // Hebrew numbering (§E.2): hebrew1 = gematria, hebrew2 = alphabet.
      expect(SectionParser.mapPageNumberFormat('hebrew1'),
          DocxPageNumberFormat.hebrew1);
      expect(SectionParser.mapPageNumberFormat('hebrew2'),
          DocxPageNumberFormat.hebrew2);
      // Unknown / missing → null (caller keeps its default).
      expect(SectionParser.mapPageNumberFormat('cardinalText'), isNull);
      expect(SectionParser.mapPageNumberFormat(null), isNull);
    });

    test('w:chapSep maps to DocxChapterSeparator', () {
      expect(SectionParser.mapChapterSeparator('hyphen'),
          DocxChapterSeparator.hyphen);
      expect(SectionParser.mapChapterSeparator('period'),
          DocxChapterSeparator.period);
      expect(SectionParser.mapChapterSeparator('emDash'),
          DocxChapterSeparator.emDash);
      expect(SectionParser.mapChapterSeparator(null), isNull);
    });
  });

  group('Header/footer variant selection', () {
    const primary = DocxHeader(children: []);
    const firstH = DocxHeader(children: []);
    const evenH = DocxHeader(children: []);

    test('title page returns the first-page variant on the first page', () {
      const section = DocxSectionDef(
        header: primary,
        firstHeader: firstH,
        titlePage: true,
      );
      expect(identical(section.headerFor(isFirstPage: true), firstH), isTrue);
      // Non-first pages still use the primary header.
      expect(identical(section.headerFor(isFirstPage: false), primary), isTrue);
    });

    test('without titlePg the first page uses the primary header', () {
      const section = DocxSectionDef(header: primary, firstHeader: firstH);
      expect(identical(section.headerFor(isFirstPage: true), primary), isTrue);
    });

    test('even page uses the even variant when present', () {
      const section = DocxSectionDef(header: primary, evenHeader: evenH);
      expect(identical(section.headerFor(isEvenPage: true), evenH), isTrue);
      expect(identical(section.headerFor(isEvenPage: false), primary), isTrue);
    });

    test('falls back to primary when no variant matches', () {
      const section = DocxSectionDef(header: primary);
      expect(identical(section.headerFor(isFirstPage: true), primary), isTrue);
      expect(identical(section.headerFor(isEvenPage: true), primary), isTrue);
    });
  });
}
