import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/widget_generator/docx_widget_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Part J — the paged renderer draws footnotes at the foot of the page with the
/// number the paginator computed (format + restart), and resolves the body
/// reference mark to that same number.
void main() {
  const config = DocxViewConfig(pageWidth: 600, pageHeight: 400);

  Future<List<Widget>> pump(WidgetTester tester, DocxBuiltDocument doc) async {
    final widgets = DocxWidgetGenerator(config: config).generateWidgets(doc);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: Column(children: widgets)),
      ),
    ));
    return widgets;
  }

  testWidgets('footnote content renders at the page foot', (tester) async {
    final doc = DocxBuiltDocument(
      elements: [
        DocxParagraph(children: [
          const DocxText('Body text'),
          const DocxFootnoteRef(footnoteId: 1),
        ]),
      ],
      footnotes: [
        DocxFootnote(
          footnoteId: 1,
          content: [
            DocxParagraph(children: [const DocxText('Note body here')])
          ],
        ),
      ],
    );

    await pump(tester, doc);

    expect(find.textContaining('Note body here', findRichText: true),
        findsOneWidget);
  });

  testWidgets('hebrew1 footnote renders gematria mark in body and at the foot',
      (tester) async {
    final doc = DocxBuiltDocument(
      elements: [
        DocxParagraph(children: [
          const DocxText('גוף'),
          const DocxFootnoteRef(footnoteId: 1),
        ]),
      ],
      footnotes: [
        DocxFootnote(
          footnoteId: 1,
          content: [
            DocxParagraph(children: [const DocxText('תוכן ההערה')])
          ],
        ),
      ],
      footnoteProperties:
          const DocxNoteProperties(format: DocxPageNumberFormat.hebrew1),
    );

    await pump(tester, doc);

    // 'א' appears twice: the superscript body mark and the note's leading mark.
    expect(find.textContaining('א', findRichText: true), findsWidgets);
    expect(
        find.textContaining('תוכן ההערה', findRichText: true), findsOneWidget);
  });

  testWidgets('endnotes render as flowed content at the document end',
      (tester) async {
    final doc = DocxBuiltDocument(
      elements: [
        DocxParagraph(children: [
          const DocxText('Body one'),
          const DocxEndnoteRef(endnoteId: 1),
        ]),
        DocxParagraph(children: [
          const DocxText('Body two'),
          const DocxEndnoteRef(endnoteId: 2),
        ]),
      ],
      endnotes: [
        DocxEndnote(
          endnoteId: 1,
          content: [
            DocxParagraph(children: [const DocxText('First endnote')])
          ],
        ),
        DocxEndnote(
          endnoteId: 2,
          content: [
            DocxParagraph(children: [const DocxText('Second endnote')])
          ],
        ),
      ],
    );

    await pump(tester, doc);

    expect(find.textContaining('First endnote', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('Second endnote', findRichText: true),
        findsOneWidget);
  });
}
