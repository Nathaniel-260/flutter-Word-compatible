import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

/// Task 01 (container) fidelity: OPC part discovery, prefix-agnostic shape
/// parsing, Markup-Compatibility selection, comment markers, and OLE previews.
///
/// Every case mixes Hebrew + English in its text, per the BiDi requirement.
void main() {
  // The namespace set Word declares on `w:document` (a subset that covers every
  // element these tests exercise), so `Requires` prefixes and the `wps` shape
  // namespace resolve to real URIs.
  const ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" '
      'xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape" '
      'xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup" '
      'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" '
      'xmlns:v="urn:schemas-microsoft-com:vml" '
      'xmlns:o="urn:schemas-microsoft-com:office:office"';

  String document(String bodyInner) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document $ns><w:body>$bodyInner</w:body></w:document>';

  String rootRels(String docTarget) =>
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="$docTarget"/>'
      '</Relationships>';

  /// A minimal 1x1 PNG (valid header) so the image decoder accepts it.
  final pngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE
  ]);

  Uint8List buildDocx({
    required String documentXml,
    String documentPartPath = 'word/document.xml',
    String? rootRelsXml,
    Map<String, String> textParts = const {},
    Map<String, List<int>> binaryParts = const {},
  }) {
    final archive = Archive();
    void addText(String name, String content) =>
        archive.addFile(ArchiveFile.string(name, content));
    addText('[Content_Types].xml',
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="png" ContentType="image/png"/>'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/$documentPartPath" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>');
    addText('_rels/.rels', rootRelsXml ?? rootRels(documentPartPath));
    addText(documentPartPath, documentXml);
    textParts.forEach(addText);
    binaryParts.forEach(
        (name, bytes) => archive.addFile(ArchiveFile.bytes(name, bytes)));
    return ZipEncoder().encodeBytes(archive);
  }

  /// Flattens all visible text in [nodes] (recursing into shapes/lists), so an
  /// assertion can check what survived parsing regardless of structure.
  String collectText(List<DocxNode> nodes) {
    final buf = StringBuffer();
    late final void Function(List<DocxNode>) blocks;
    void inlines(List<DocxInline> items) {
      for (final i in items) {
        if (i is DocxText) buf.write(i.content);
        if (i is DocxShape && i.textBlocks != null) blocks(i.textBlocks!);
      }
    }

    blocks = (ns) {
      for (final n in ns) {
        if (n is DocxParagraph) inlines(n.children);
        if (n is DocxList) {
          for (final item in n.items) {
            inlines(item.children);
          }
        }
      }
    };

    blocks(nodes);
    return buf.toString();
  }

  group('OPC part discovery (items 1–4)', () {
    test('opens a package whose body is at a non-standard path', () async {
      // Body lives at `contents/main.xml`, not `word/document.xml`. Discovery
      // via `_rels/.rels` is the only way to find it. (Before: the reader
      // hard-coded `word/document.xml` and threw.)
      final bytes = buildDocx(
        documentPartPath: 'contents/main.xml',
        documentXml: document(
            '<w:p><w:r><w:t>שלום World — non-standard part</w:t></w:r></w:p>'),
      );
      final doc = await DocxReader.loadFromBytes(bytes);
      expect(collectText(doc.elements), contains('שלום World'));
    });

    test('resolves the document relationships relative to the discovered base',
        () async {
      // The hyperlink target lives in `contents/_rels/main.xml.rels`; resolving
      // it proves `documentRelsPath` follows the base dir, not a fixed `word/`.
      final bytes = buildDocx(
        documentPartPath: 'contents/main.xml',
        documentXml: document(
            '<w:p><w:hyperlink r:id="rId50"><w:r><w:t>קישור link</w:t></w:r></w:hyperlink></w:p>'),
        textParts: {
          'contents/_rels/main.xml.rels':
              '<?xml version="1.0" encoding="UTF-8"?>'
              '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
              '<Relationship Id="rId50" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.com" TargetMode="External"/>'
              '</Relationships>',
        },
      );
      final doc = await DocxReader.loadFromBytes(bytes);
      final para = doc.elements.whereType<DocxParagraph>().first;
      final link = para.children.whereType<DocxText>().first;
      expect(link.content, contains('קישור link'));
      expect(link.href, 'https://example.com');
    });

    test('standard word/document.xml package still opens (no regression)',
        () async {
      final bytes = buildDocx(
          documentXml:
              document('<w:p><w:r><w:t>רגיל standard</w:t></w:r></w:p>'));
      final doc = await DocxReader.loadFromBytes(bytes);
      expect(collectText(doc.elements), contains('רגיל standard'));
    });
  });

  group('shape namespace prefix (item 21)', () {
    test("parses a shape written with Word's wps: prefix", () async {
      final bytes = buildDocx(
          documentXml: document('<w:p><w:r><w:drawing><wp:inline>'
              '<wp:extent cx="762000" cy="508000"/>'
              '<a:graphic><a:graphicData uri="http://schemas.microsoft.com/office/word/2010/wordprocessingShape">'
              '<wps:wsp>'
              '<wps:spPr><a:prstGeom prst="rect"/><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></wps:spPr>'
              '<wps:txbx><w:txbxContent><w:p><w:r><w:t>שלום World box</w:t></w:r></w:p></w:txbxContent></wps:txbx>'
              '</wps:wsp>'
              '</a:graphicData></a:graphic>'
              '</wp:inline></w:drawing></w:r></w:p>'));
      final doc = await DocxReader.loadFromBytes(bytes);
      final para = doc.elements.whereType<DocxParagraph>().first;
      final shape = para.children.whereType<DocxShape>().single;
      expect(shape.fillColor?.hex, 'FF0000');
      expect(collectText(doc.elements), contains('שלום World box'));
      // The old literal `wsp:wsp` match would have produced a raw inline.
      expect(para.children.whereType<DocxRawInline>(), isEmpty);
    });
  });

  group('mc:AlternateContent selection (item 22)', () {
    // Builds an in-run drawing whose text box carries [label], so the two
    // branches of an AlternateContent are distinguishable by their text.
    String shapeDrawing(String label) =>
        '<w:drawing><wp:inline><wp:extent cx="762000" cy="508000"/>'
        '<a:graphic><a:graphicData><wps:wsp>'
        '<wps:spPr><a:prstGeom prst="rect"/></wps:spPr>'
        '<wps:txbx><w:txbxContent><w:p><w:r><w:t>$label</w:t></w:r></w:p></w:txbxContent></wps:txbx>'
        '</wps:wsp></a:graphicData></a:graphic></wp:inline></w:drawing>';

    test('in-run: an unsupported Choice yields to the Fallback', () async {
      // The Choice requires `wpg` (groups — unsupported), so the Fallback's
      // drawing must win. Before: a recursive search grabbed the first drawing
      // in document order (the unsupported Choice's), ignoring `Requires`.
      final bytes = buildDocx(
          documentXml: document('<w:p><w:r><mc:AlternateContent>'
              '<mc:Choice Requires="wpg">${shapeDrawing('בחירה unsupported')}</mc:Choice>'
              '<mc:Fallback>${shapeDrawing('גיבוי fallback')}</mc:Fallback>'
              '</mc:AlternateContent></w:r></w:p>'));
      final doc = await DocxReader.loadFromBytes(bytes);
      final text = collectText(doc.elements);
      expect(text, contains('גיבוי fallback'));
      expect(text, isNot(contains('בחירה unsupported')));
    });

    test('in-run: an understood wps Choice wins over the Fallback', () async {
      final bytes = buildDocx(
          documentXml: document('<w:p><w:r><mc:AlternateContent>'
              '<mc:Choice Requires="wps">${shapeDrawing('מודרני modern')}</mc:Choice>'
              '<mc:Fallback><w:pict><v:shape><v:textbox><w:txbxContent>'
              '<w:p><w:r><w:t>legacy ישן</w:t></w:r></w:p>'
              '</w:txbxContent></v:textbox></v:shape></w:pict></mc:Fallback>'
              '</mc:AlternateContent></w:r></w:p>'));
      final doc = await DocxReader.loadFromBytes(bytes);
      final para = doc.elements.whereType<DocxParagraph>().single;
      expect(para.children.whereType<DocxShape>(), isNotEmpty);
      expect(collectText(doc.elements), contains('מודרני modern'));
    });

    test('block-level AlternateContent is parsed, not dropped', () async {
      // Previously the block parser had no AlternateContent branch at all, so
      // the wrapped paragraph vanished entirely.
      final bytes = buildDocx(
          documentXml: document('<mc:AlternateContent>'
              '<mc:Choice Requires="wps"><w:p><w:r><w:t>בלוק block choice</w:t></w:r></w:p></mc:Choice>'
              '<mc:Fallback><w:p><w:r><w:t>בלוק fallback</w:t></w:r></w:p></mc:Fallback>'
              '</mc:AlternateContent>'));
      final doc = await DocxReader.loadFromBytes(bytes);
      final text = collectText(doc.elements);
      expect(text, contains('בלוק block choice'));
      expect(text, isNot(contains('בלוק fallback')));
    });
  });

  group('comment markers (item 15)', () {
    test('comment reference markers do not leak as raw inlines', () async {
      final bytes = buildDocx(
          documentXml: document('<w:p>'
              '<w:r><w:t>שלום </w:t></w:r>'
              '<w:commentRangeStart w:id="0"/>'
              '<w:r><w:t>World</w:t></w:r>'
              '<w:commentRangeEnd w:id="0"/>'
              '<w:r><w:rPr><w:rStyle w:val="CommentReference"/></w:rPr><w:commentReference w:id="0"/></w:r>'
              '</w:p>'));
      final doc = await DocxReader.loadFromBytes(bytes);
      final para = doc.elements.whereType<DocxParagraph>().single;
      expect(para.children.whereType<DocxRawInline>(), isEmpty);
      expect(para.children.whereType<DocxText>().map((t) => t.content).join(),
          'שלום World');
    });
  });

  group('OLE object preview (item 17)', () {
    test('extracts the raster preview of an embedded w:object', () async {
      final bytes = buildDocx(
          documentXml: document('<w:p><w:r>'
              '<w:object>'
              '<v:shape style="width:60pt;height:40pt"><v:imagedata r:id="rIdImg"/></v:shape>'
              '</w:object>'
              '</w:r><w:r><w:t>אובייקט object</w:t></w:r></w:p>'),
          textParts: {
            'word/_rels/document.xml.rels':
                '<?xml version="1.0" encoding="UTF-8"?>'
                '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                '<Relationship Id="rIdImg" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/preview.png"/>'
                '</Relationships>',
          },
          binaryParts: {'word/media/preview.png': pngBytes});
      final doc = await DocxReader.loadFromBytes(bytes);
      final para = doc.elements.whereType<DocxParagraph>().single;
      final img = para.children.whereType<DocxInlineImage>().single;
      expect(img.extension, 'png');
      expect(img.bytes, pngBytes);
      // The text run alongside the object is preserved.
      expect(collectText(doc.elements), contains('אובייקט object'));
    });

    test('resolves a package-absolute preview target (/word/media/…)',
        () async {
      final bytes = buildDocx(
          documentXml: document('<w:p><w:r>'
              '<w:object><v:shape style="width:60pt;height:40pt"><v:imagedata r:id="rIdAbs"/></v:shape></w:object>'
              '</w:r></w:p>'),
          textParts: {
            'word/_rels/document.xml.rels':
                '<?xml version="1.0" encoding="UTF-8"?>'
                '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                '<Relationship Id="rIdAbs" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="/word/media/abs.png"/>'
                '</Relationships>',
          },
          binaryParts: {'word/media/abs.png': pngBytes});
      final doc = await DocxReader.loadFromBytes(bytes);
      final para = doc.elements.whereType<DocxParagraph>().single;
      expect(para.children.whereType<DocxInlineImage>().single.bytes, pngBytes);
    });

    test('an object without a preview blip is preserved, not crashed',
        () async {
      final bytes = buildDocx(
          documentXml: document('<w:p><w:r>'
              '<w:object><o:OLEObject Type="Embed" ProgID="Excel.Sheet.12" r:id="rIdOle"/></w:object>'
              '</w:r><w:r><w:t>אחרי after</w:t></w:r></w:p>'));
      final doc = await DocxReader.loadFromBytes(bytes);
      final para = doc.elements.whereType<DocxParagraph>().single;
      // No image (no preview), but the object is kept as raw XML and the
      // following text run survives — no exception.
      expect(para.children.whereType<DocxInlineImage>(), isEmpty);
      expect(para.children.whereType<DocxRawInline>(), isNotEmpty);
      expect(collectText(doc.elements), contains('אחרי after'));
    });
  });

  group('review hardening', () {
    test('resolvePartByType follows a renamed sibling part (styles2.xml)',
        () async {
      // The styles part is renamed `styles2.xml` and reachable only via the
      // `styles` relationship — exercising the non-fallback branch. A bold
      // paragraph style proves the renamed part was actually loaded and applied.
      final bytes = buildDocx(
          documentXml: document(
              '<w:p><w:pPr><w:pStyle w:val="MyBold"/></w:pPr><w:r><w:t>מודגש bold</w:t></w:r></w:p>'),
          textParts: {
            'word/_rels/document.xml.rels':
                '<?xml version="1.0" encoding="UTF-8"?>'
                '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles2.xml"/>'
                '</Relationships>',
            'word/styles2.xml':
                '<?xml version="1.0" encoding="UTF-8"?>'
                '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
                '<w:style w:type="paragraph" w:styleId="MyBold"><w:rPr><w:b/></w:rPr></w:style>'
                '</w:styles>',
          });
      final doc = await DocxReader.loadFromBytes(bytes);
      final run = doc.elements
          .whereType<DocxParagraph>()
          .single
          .children
          .whereType<DocxText>()
          .first;
      expect(run.content, contains('מודגש bold'));
      expect(run.fontWeight, DocxFontWeight.bold);
    });

    test('a comment-marker run that also holds a drawing keeps the drawing',
        () async {
      // The run carries both a commentReference and a shape inside an
      // AlternateContent — it must NOT be discarded as a marker-only run.
      final bytes = buildDocx(
          documentXml: document('<w:p><w:r>'
              '<w:commentReference w:id="0"/>'
              '<mc:AlternateContent><mc:Choice Requires="wps">'
              '<w:drawing><wp:inline><wp:extent cx="762000" cy="508000"/>'
              '<a:graphic><a:graphicData><wps:wsp>'
              '<wps:spPr><a:prstGeom prst="rect"/></wps:spPr>'
              '<wps:txbx><w:txbxContent><w:p><w:r><w:t>הערה ציור note shape</w:t></w:r></w:p></w:txbxContent></wps:txbx>'
              '</wps:wsp></a:graphicData></a:graphic></wp:inline></w:drawing>'
              '</mc:Choice></mc:AlternateContent>'
              '</w:r></w:p>'));
      final doc = await DocxReader.loadFromBytes(bytes);
      final para = doc.elements.whereType<DocxParagraph>().single;
      expect(para.children.whereType<DocxShape>(), isNotEmpty);
      expect(collectText(doc.elements), contains('הערה ציור note shape'));
    });
  });
}
