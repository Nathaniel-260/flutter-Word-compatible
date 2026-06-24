import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

/// 14-settings.md item 14 (R1 verification): a document `w:background` page
/// colour is exposed on the section **only** when `w:displayBackgroundShape`
/// is set in settings.xml — Word's print-layout gating. Without the flag the
/// colour is kept in the file but not painted (the viewer leaves it white).
/// This exercises the gate end-to-end (settings + document.xml → section),
/// not just the flag parsing.
void main() {
  const wns =
      'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

  Uint8List buildDocx({required bool flag}) {
    final archive = Archive();
    void addText(String name, String content) =>
        archive.addFile(ArchiveFile.string(name, content));
    addText(
        '[Content_Types].xml',
        '<?xml version="1.0"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>');
    addText(
        '_rels/.rels',
        '<?xml version="1.0"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>');
    // `w:background` is a child of `w:document`, before `w:body` (as Word writes
    // it). Text mixes Hebrew + English per the BiDi requirement.
    addText(
        'word/document.xml',
        '<?xml version="1.0"?>'
        '<w:document $wns>'
        '<w:background w:color="FF0000"/>'
        '<w:body><w:p><w:r><w:t>שלום background</w:t></w:r></w:p></w:body>'
        '</w:document>');
    addText('word/settings.xml',
        '<w:settings $wns>${flag ? '<w:displayBackgroundShape/>' : ''}</w:settings>');
    return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
  }

  test('page background is shown when displayBackgroundShape is set', () async {
    final doc = await DocxReader.loadFromBytes(buildDocx(flag: true));
    expect(doc.section?.backgroundColor?.hex, 'FF0000');
  });

  test('page background is hidden when the flag is absent', () async {
    final doc = await DocxReader.loadFromBytes(buildDocx(flag: false));
    expect(doc.section?.backgroundColor, isNull);
  });
}
