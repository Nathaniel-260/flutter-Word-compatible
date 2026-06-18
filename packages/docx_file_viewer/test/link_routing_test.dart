import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Part K.2 — a tapped link routes to the right handler: an internal `#anchor`
/// to [onInternalLink], an external url to [onExternalLink].
void main() {
  // Recursively collects (text, recognizer) for every leaf TextSpan.
  List<(String, GestureRecognizer?)> spansOf(InlineSpan span) {
    final out = <(String, GestureRecognizer?)>[];
    void walk(InlineSpan s) {
      if (s is TextSpan) {
        if (s.text != null) out.add((s.text!, s.recognizer));
        for (final c in s.children ?? const <InlineSpan>[]) {
          walk(c);
        }
      }
    }

    walk(span);
    return out;
  }

  testWidgets(
      'internal #anchor → onInternalLink, external url → onExternalLink',
      (tester) async {
    String? internal;
    String? external;

    final builder = ParagraphBuilder(
      theme: DocxViewTheme.light(),
      config: const DocxViewConfig(enableSelection: false),
      onInternalLink: (b) => internal = b,
      onExternalLink: (u) => external = u,
    );

    final paragraph = DocxParagraph(children: const [
      DocxText('External', href: 'https://example.com'),
      DocxText('Internal', href: '#chapter2'),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: builder.build(paragraph)),
    ));

    final richText = tester.widget<RichText>(find.byType(RichText).first);
    final spans = spansOf(richText.text);

    // Fire each link's tap recognizer.
    for (final (text, rec) in spans) {
      if (rec is TapGestureRecognizer) {
        if (text == 'External') rec.onTap!();
        if (text == 'Internal') rec.onTap!();
      }
    }

    expect(external, 'https://example.com');
    expect(internal, 'chapter2');
  });

  testWidgets('DocxViewController reports bookmarks and resolves page index',
      (tester) async {
    // No view attached → empty/null, and jumping is a no-op (returns false).
    final controller = DocxViewController();
    expect(controller.bookmarks, isEmpty);
    expect(controller.pageIndexForBookmark('x'), isNull);
    expect(controller.hasBookmark('x'), isFalse);
    expect(await controller.jumpToBookmark('x'), isFalse);

    // After a view binds its hooks, the controller reads through them.
    controller.attach(
      bookmarks: () => const {'ch1': 0, 'ch2': 3},
      jumpBookmark: (name, _, __) async => name == 'ch2',
      jumpPage: (i, _, __) async => i >= 0,
    );
    expect(controller.bookmarks, {'ch1': 0, 'ch2': 3});
    expect(controller.pageIndexForBookmark('ch2'), 3);
    expect(controller.hasBookmark('ch1'), isTrue);
    expect(await controller.jumpToBookmark('ch2'), isTrue);
    expect(await controller.jumpToPage(2), isTrue);
  });
}
