import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:docx_file_viewer/src/widgets/tabbed_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 3000tw = 200px (center stop); 6000tw = 400px (right stop).
  DocxParagraph headerLine({required bool rtl}) => DocxParagraph(
        isRtl: rtl,
        tabStops: const [
          DocxTabStop(
            posTwips: 3000,
            alignment: DocxTabAlignment.center,
            leader: DocxTabLeader.dot,
          ),
          DocxTabStop(posTwips: 6000, alignment: DocxTabAlignment.right),
        ],
        children: [
          DocxText('left'),
          const DocxTab(),
          DocxText('center'),
          const DocxTab(),
          DocxText('right'),
        ],
      );

  ParagraphBuilder makeBuilder() => ParagraphBuilder(
        theme: DocxViewTheme.light(),
        config: const DocxViewConfig(enableSelection: false),
        docxTheme: DocxTheme.empty(),
      );

  Future<Rect> pumpLine(WidgetTester tester, DocxParagraph p) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: const Key('box'),
            width: 500,
            child: makeBuilder().build(p),
          ),
        ),
      ),
    ));
    return tester.getRect(find.byKey(const Key('box')));
  }

  testWidgets('LTR header: left flush, center on 200, right ends at 400',
      (tester) async {
    final box = await pumpLine(tester, headerLine(rtl: false));

    // The tabbed renderer is used (not the plain RichText path).
    expect(find.byType(TabbedLineRenderer), findsOneWidget);

    final seg0 = tester.getRect(find.byType(RichText).at(0));
    final seg1 = tester.getRect(find.byType(RichText).at(1));
    final seg2 = tester.getRect(find.byType(RichText).at(2));

    expect(seg0.left - box.left, closeTo(0, 2)); // left flush
    expect(((seg1.left + seg1.right) / 2) - box.left,
        closeTo(200, 2)); // centered on the center stop
    expect(seg2.right - box.left, closeTo(400, 2)); // right edge at right stop
  });

  testWidgets('tab + line break stays on the wrapping path (not clipped)',
      (tester) async {
    // The single-line tabbed renderer would drop everything after a break;
    // such paragraphs must use the normal RichText path instead.
    final p = DocxParagraph(
      tabStops: const [
        DocxTabStop(posTwips: 3000, alignment: DocxTabAlignment.center),
      ],
      children: [
        DocxText('before'),
        const DocxTab(),
        DocxText('after'),
        const DocxLineBreak(),
        DocxText('second line'),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 500, child: makeBuilder().build(p)),
      ),
    ));

    expect(find.byType(TabbedLineRenderer), findsNothing);
    final plain =
        tester.widget<RichText>(find.byType(RichText).first).text.toPlainText();
    expect(plain, contains('second line'));
  });

  testWidgets('RTL header: leading segment hugs the right edge',
      (tester) async {
    final box = await pumpLine(tester, headerLine(rtl: true));

    expect(find.byType(TabbedLineRenderer), findsOneWidget);

    final seg0 = tester.getRect(find.byType(RichText).at(0));
    final seg2 = tester.getRect(find.byType(RichText).at(2));

    // Leading edge is the right side in RTL.
    expect(box.right - seg0.right, closeTo(0, 2));
    // The right-tab (leading-edge 400) mirrors to box.right - 400 on the left.
    expect(seg2.left - box.left, closeTo(100, 2));
  });
}
