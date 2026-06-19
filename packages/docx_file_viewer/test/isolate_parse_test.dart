import 'dart:io';

import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_test/flutter_test.dart';

/// Plan §M.3: [DocxView] parses on a background isolate via `compute`, so the
/// returned [DocxBuiltDocument] must be sendable across the isolate boundary.
/// This locks that invariant: a single non-sendable field would throw here long
/// before it reached production.

/// Top-level so `compute` can send it to the worker isolate (a captured closure
/// would not be sendable). Echoes the AST back, exercising the send *and*
/// receive of every field a real parse produces.
DocxBuiltDocument _echo(DocxBuiltDocument doc) => doc;

void main() {
  const docPath = r'C:\OTZ\flutter-packages\.tmp_docx\formatting-demo.docx';

  test('a representative AST round-trips through compute (always runs)',
      () async {
    // Covers the node kinds a parse yields — paragraphs, a table, a list, a
    // footnote, header/footer — so a non-sendable field on any of them surfaces
    // here even in a clean checkout without the local fixture below.
    final doc = DocxBuiltDocument(
      elements: <DocxNode>[
        DocxParagraph(children: const [DocxText('Hello'), DocxText(' שלום')]),
        DocxTable(rows: [
          DocxTableRow(cells: [
            DocxTableCell(
                children: [DocxParagraph(children: const [DocxText('cell')])]),
          ]),
        ]),
        DocxList(items: [
          DocxListItem(const [DocxText('item')]),
        ]),
      ],
      section: DocxSectionDef(
        header: DocxHeader(
            children: [DocxParagraph(children: const [DocxText('hdr')])]),
        footer: DocxFooter(
            children: [DocxParagraph(children: const [DocxText('ftr')])]),
      ),
      footnotes: [
        DocxFootnote(
            footnoteId: 1,
            content: [DocxParagraph(children: const [DocxText('note')])]),
      ],
    );

    final back = await compute(_echo, doc);
    expect(back.elements.length, doc.elements.length);
    expect(back.footnotes?.length, 1);
    expect(back.section?.header, isNotNull);
    expect((back.elements.first as DocxParagraph).children.length, 2);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('DocxReader.loadFromBytes round-trips through compute (sendable AST)',
      () async {
    final file = File(docPath);
    if (!file.existsSync()) {
      // Local-only fixture (shared with word_parity_test); skip in a clean
      // checkout rather than fail.
      return;
    }
    final bytes = file.readAsBytesSync();

    // The exact call DocxView makes: parse off the UI isolate.
    final viaIsolate = await compute(DocxReader.loadFromBytes, bytes);
    // Same parse on this isolate, as a reference.
    final direct = await DocxReader.loadFromBytes(bytes);

    expect(viaIsolate.elements, isNotEmpty,
        reason: 'the isolate-parsed AST must carry the document body');
    expect(viaIsolate.elements.length, direct.elements.length,
        reason: 'isolate parse must equal a same-isolate parse');
    expect(viaIsolate.fonts.length, direct.fonts.length);
    expect(viaIsolate.footnotes?.length, direct.footnotes?.length);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
