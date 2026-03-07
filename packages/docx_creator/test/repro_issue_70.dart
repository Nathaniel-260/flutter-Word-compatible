import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  test('Issue 70: paddingTop causes visible horizontal line', () {
    final paragraph = DocxParagraph(
      paddingTop: 200, // ~10pt
      children: [DocxText('Paragraph with padding')],
    );

    final builder = XmlBuilder();
    paragraph.buildXml(builder);
    final xml = builder.buildDocument().toXmlString();

    // The fixed behavior should use <w:top w:val="nil" ... />
    expect(xml, contains('<w:top'),
        reason: 'Should still have a top element for padding');
    expect(xml, contains('w:val="nil"'),
        reason:
            'Padding without explicit border should use "nil" (invisible) border');
    expect(xml, isNot(contains('w:val="single"')),
        reason: 'Should not use visible "single" border for padding');
  });
}
