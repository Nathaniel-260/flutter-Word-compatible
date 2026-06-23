import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 04-paragraph-ppr.md items 44/45: paragraph indents are *logical*. `indentLeft`
/// (`w:start`/`w:left`) is the leading edge, `indentRight` (`w:end`/`w:right`) the
/// trailing edge. In an RTL paragraph the leading indent must land on the right,
/// as Word draws it. The left+right sum is unchanged, so the measurer stays 1:1.
void main() {
  late ParagraphBuilder builder;

  setUp(() {
    final t = DocxViewTheme.light();
    const config = DocxViewConfig(enableSelection: false);
    builder = ParagraphBuilder(theme: t, config: config, docxTheme: DocxTheme.empty());
  });

  EdgeInsetsGeometry? paddingOf(WidgetTester tester) {
    final container = tester.widgetList<Container>(find.byType(Container)).first;
    return container.padding;
  }

  testWidgets('LTR: leading indent → left padding', (tester) async {
    const p = DocxParagraph(
      isRtl: false,
      indentLeft: 1500, // start
      indentRight: 300, // end
      children: [DocxText('hello')],
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(width: 400, child: builder.build(p)))));
    final pad = paddingOf(tester)!.resolve(TextDirection.ltr);
    expect(pad.left, closeTo(100, 0.01)); // 1500/15
    expect(pad.right, closeTo(20, 0.01)); // 300/15
  });

  testWidgets('RTL: leading indent → right padding (Word fidelity)',
      (tester) async {
    const p = DocxParagraph(
      isRtl: true,
      indentLeft: 1500, // start → right side in RTL
      indentRight: 300, // end → left side in RTL
      children: [DocxText('שלום')],
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(width: 400, child: builder.build(p)))));
    final pad = paddingOf(tester)!.resolve(TextDirection.ltr);
    expect(pad.right, closeTo(100, 0.01)); // start indent on the right
    expect(pad.left, closeTo(20, 0.01)); // end indent on the left
  });
}
