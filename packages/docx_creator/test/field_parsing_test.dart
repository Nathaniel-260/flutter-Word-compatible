import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:docx_creator/src/reader/docx_reader/parsers/field_instruction.dart';
import 'package:docx_creator/src/reader/docx_reader/parsers/inline_parser.dart';
import 'package:docx_creator/src/reader/docx_reader/reader_context/reader_context.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

const _ns =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

/// Parses the inline children of a `<w:p>` snippet with a bare reader context.
List<DocxInline> parseParagraph(String inner) {
  final parser = InlineParser(ReaderContext(Archive()));
  final doc = XmlDocument.parse('<w:p $_ns>$inner</w:p>');
  return parser.parseChildren(doc.rootElement.children);
}

void main() {
  group('FieldInstruction (pure parser)', () {
    test('PAGE → DocxPageNumber, decimal by default', () {
      final node = FieldInstruction.parse(' PAGE ');
      expect(node, isA<DocxPageNumber>());
      expect((node as DocxPageNumber).format, isNull);
    });

    test('PAGE \\* ROMAN vs \\* roman distinguishes case', () {
      expect(
          (FieldInstruction.parse(r' PAGE \* ROMAN ') as DocxPageNumber).format,
          DocxPageNumberFormat.upperRoman);
      expect(
          (FieldInstruction.parse(r' PAGE \* roman ') as DocxPageNumber).format,
          DocxPageNumberFormat.lowerRoman);
    });

    test('NUMPAGES and SECTIONPAGES', () {
      expect(FieldInstruction.parse(' NUMPAGES '), isA<DocxPageCount>());
      expect(
          (FieldInstruction.parse(' NUMPAGES ') as DocxPageCount).sectionScope,
          isFalse);
      final sec = FieldInstruction.parse(' SECTIONPAGES ') as DocxPageCount;
      expect(sec.sectionScope, isTrue);
    });

    test('PAGEREF captures bookmark and \\h switch', () {
      final ref =
          FieldInstruction.parse(r' PAGEREF _Toc123 \h ') as DocxPageRef;
      expect(ref.bookmark, '_Toc123');
      expect(ref.hyperlink, isTrue);
    });

    test('quoted bookmark name with spaces stays intact', () {
      final ref =
          FieldInstruction.parse(' PAGEREF "My Bookmark" ') as DocxPageRef;
      expect(ref.bookmark, 'My Bookmark');
    });

    test('cachedText is carried onto the node', () {
      final node = FieldInstruction.parse(' PAGE ', cachedText: '7');
      expect((node as DocxPageNumber).cachedText, '7');
    });

    test('unknown field codes return null (caller wraps as unknown)', () {
      expect(FieldInstruction.parse(r' TOC \o "1-3" '), isNull);
      expect(FieldInstruction.parse(' DATE '), isNull);
      expect(FieldInstruction.parse('   '), isNull);
    });

    test('MERGEFORMAT switch is ignored (format inherits)', () {
      final node = FieldInstruction.parse(r' PAGE \* MERGEFORMAT ');
      expect((node as DocxPageNumber).format, isNull);
    });

    test('STYLEREF → DocxStyleRef with the style name', () {
      final node = FieldInstruction.parse(' STYLEREF "Heading 1" ');
      expect(node, isA<DocxStyleRef>());
      final ref = node as DocxStyleRef;
      expect(ref.styleName, 'Heading 1');
      expect(ref.searchFromTop, isFalse);
    });

    test('STYLEREF \\l sets searchFromTop', () {
      final ref =
          FieldInstruction.parse(r' STYLEREF "Heading 1" \l ') as DocxStyleRef;
      expect(ref.searchFromTop, isTrue);
    });

    test('parseHyperlink distinguishes external url and internal anchor', () {
      final ext = FieldInstruction.parseHyperlink(' HYPERLINK "http://x.com" ');
      expect(ext?.url, 'http://x.com');
      expect(ext?.anchor, isNull);

      final intern =
          FieldInstruction.parseHyperlink(r' HYPERLINK \l "anchor" ');
      expect(intern?.anchor, 'anchor');
      expect(intern?.url, isNull);

      expect(FieldInstruction.parseHyperlink(' PAGE '), isNull);
    });
  });

  group('Hyperlinks, fields, and OMML (Plan §K)', () {
    test('a HYPERLINK field turns its result text into a link', () {
      const xml = '''
        <w:r><w:fldChar w:fldCharType="begin"/></w:r>
        <w:r><w:instrText xml:space="preserve"> HYPERLINK "http://example.com" </w:instrText></w:r>
        <w:r><w:fldChar w:fldCharType="separate"/></w:r>
        <w:r><w:t>Click here</w:t></w:r>
        <w:r><w:fldChar w:fldCharType="end"/></w:r>''';
      final inlines = parseParagraph(xml);
      final link = inlines.whereType<DocxText>().single;
      expect(link.content, 'Click here');
      expect(link.href, 'http://example.com');
      expect(link.isLink, isTrue);
    });

    test('a HYPERLINK \\l field becomes an internal #anchor link', () {
      const xml = '''
        <w:r><w:fldChar w:fldCharType="begin"/></w:r>
        <w:r><w:instrText xml:space="preserve"> HYPERLINK \\l "ch1" </w:instrText></w:r>
        <w:r><w:fldChar w:fldCharType="separate"/></w:r>
        <w:r><w:t>Chapter 1</w:t></w:r>
        <w:r><w:fldChar w:fldCharType="end"/></w:r>''';
      final link = parseParagraph(xml).whereType<DocxText>().single;
      expect(link.href, '#ch1');
    });

    test('a w:hyperlink with w:anchor becomes an internal #anchor link', () {
      const xml = '''
        <w:hyperlink w:anchor="sec2"><w:r><w:t>Go to section 2</w:t></w:r></w:hyperlink>''';
      final link = parseParagraph(xml).whereType<DocxText>().single;
      expect(link.content, 'Go to section 2');
      expect(link.href, '#sec2');
    });

    test('inline OMML keeps its linear m:t text as a placeholder', () {
      const xml = '''
        <m:oMath xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math">
          <m:r><m:t>x</m:t></m:r><m:r><m:t>+</m:t></m:r><m:r><m:t>y</m:t></m:r>
        </m:oMath>''';
      final inlines = parseParagraph(xml);
      expect(inlines.whereType<DocxText>().map((t) => t.content).join(), 'x+y');
    });

    test('STYLEREF field reads back as DocxStyleRef', () {
      const xml = '''
        <w:r><w:fldChar w:fldCharType="begin"/></w:r>
        <w:r><w:instrText xml:space="preserve"> STYLEREF "Heading 1" </w:instrText></w:r>
        <w:r><w:fldChar w:fldCharType="separate"/></w:r>
        <w:r><w:t>Genesis</w:t></w:r>
        <w:r><w:fldChar w:fldCharType="end"/></w:r>''';
      final ref = parseParagraph(xml).whereType<DocxStyleRef>().single;
      expect(ref.styleName, 'Heading 1');
      expect(ref.cachedText, 'Genesis');
    });
  });

  group('Field run structures', () {
    test('field packed into a single run parses fully (regression)', () {
      // Word sometimes emits begin/instrText/separate/end inside ONE <w:r>.
      // Previously everything after this run was silently dropped.
      const xml = '''
        <w:r><w:t xml:space="preserve">עמוד </w:t></w:r>
        <w:r>
          <w:fldChar w:fldCharType="begin"/>
          <w:instrText xml:space="preserve">PAGE</w:instrText>
          <w:fldChar w:fldCharType="separate"/>
          <w:fldChar w:fldCharType="end"/>
        </w:r>
        <w:r><w:t xml:space="preserve"> מתוך </w:t></w:r>
        <w:r>
          <w:fldChar w:fldCharType="begin"/>
          <w:instrText xml:space="preserve">NUMPAGES</w:instrText>
          <w:fldChar w:fldCharType="separate"/>
          <w:fldChar w:fldCharType="end"/>
        </w:r>''';
      final inlines = parseParagraph(xml);

      expect(inlines.whereType<DocxPageNumber>(), isNotEmpty);
      expect(inlines.whereType<DocxPageCount>(), isNotEmpty);
      expect(inlines.whereType<DocxText>().map((t) => t.content).join(),
          'עמוד  מתוך ');
    });

    test('field split across runs still parses (with cached result)', () {
      const xml = '''
        <w:r><w:fldChar w:fldCharType="begin"/></w:r>
        <w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>
        <w:r><w:fldChar w:fldCharType="separate"/></w:r>
        <w:r><w:t>7</w:t></w:r>
        <w:r><w:fldChar w:fldCharType="end"/></w:r>''';
      final inlines = parseParagraph(xml);

      final page = inlines.whereType<DocxPageNumber>().single;
      expect(page.cachedText, '7');
      // The cached "7" must not also appear as a stray text run.
      expect(inlines.whereType<DocxText>(), isEmpty);
    });

    test('packed field with an inline cached result keeps it', () {
      const xml = '''
        <w:r>
          <w:fldChar w:fldCharType="begin"/>
          <w:instrText xml:space="preserve"> PAGE </w:instrText>
          <w:fldChar w:fldCharType="separate"/>
          <w:t>3</w:t>
          <w:fldChar w:fldCharType="end"/>
        </w:r>''';
      final inlines = parseParagraph(xml);
      expect(inlines.whereType<DocxPageNumber>().single.cachedText, '3');
    });
  });

  group('Reader integration (export → read)', () {
    test('a PAGE field in a footer reads back as DocxPageNumber, not text',
        () async {
      final footer = DocxFooter(children: [
        DocxParagraph(children: const [
          DocxText('Page '),
          DocxPageNumber(),
          DocxText(' of '),
          DocxPageCount(),
        ]),
      ]);
      final doc = docx().p('Body').build();
      // Attach the footer via a section that the exporter will serialize.
      final withFooter = DocxBuiltDocument(
        elements: doc.elements,
        section: DocxSectionDef(footer: footer),
      );

      final bytes = await DocxExporter().exportToBytes(withFooter);
      final read = await DocxReader.loadFromBytes(bytes);

      final footerInlines = read.section!.footer!.children
          .whereType<DocxParagraph>()
          .expand((p) => p.children)
          .toList();

      expect(footerInlines.whereType<DocxPageNumber>(), isNotEmpty);
      expect(footerInlines.whereType<DocxPageCount>(), isNotEmpty);
    });
  });
}
