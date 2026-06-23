import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 04-paragraph-ppr.md item 4: `w:pageBreakBefore` is realised by the paginator
/// in paged mode (which clears the flag before building). In continuous mode
/// Word draws no horizontal rule for a page break, so the paragraph must render
/// without any Divider artifact.
void main() {
  testWidgets('continuous: pageBreakBefore draws no Divider', (tester) async {
    final t = DocxViewTheme.light();
    const config = DocxViewConfig(enableSelection: false);
    final builder =
        ParagraphBuilder(theme: t, config: config, docxTheme: DocxTheme.empty());

    const p = DocxParagraph(
      pageBreakBefore: true,
      children: [DocxText('after a break')],
    );

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(width: 400, child: builder.build(p)))));

    expect(find.byType(Divider), findsNothing);
    // The paragraph content still renders (as a RichText span tree).
    expect(find.byType(RichText), findsWidgets);
  });
}
