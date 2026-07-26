import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';

/// Sample content shared across the showcase's demo screens.
class SampleData {
  SampleData._();

  static const String sampleHtml = '''
<h1 style="color: navy;">Quarterly Report</h1>
<p>This report covers <b>Q3 performance</b> across all <i>regions</i>, with a
focus on <span style="color: #E53935; font-weight: bold;">at-risk accounts</span>.</p>
<h2>Highlights</h2>
<ul>
  <li>Revenue grew <mark>12% quarter-over-quarter</mark></li>
  <li>Customer churn dropped to 2.1%
    <ul>
      <li>Enterprise churn: 0.8%</li>
      <li>SMB churn: 3.4%</li>
    </ul>
  </li>
  <li>3 new markets launched</li>
</ul>
<table border="1">
  <tr style="background-color: #4472C4; color: white;">
    <th>Region</th>
    <th>Revenue</th>
    <th>Status</th>
  </tr>
  <tr>
    <td>North America</td>
    <td>\$4.2M</td>
    <td style="background-color: lightgreen;">On Track</td>
  </tr>
  <tr>
    <td>EMEA</td>
    <td>\$2.1M</td>
    <td style="background-color: khaki;">Watch</td>
  </tr>
</table>
<blockquote>"Best quarter in company history." — CEO</blockquote>
<p>See <a href="https://example.com">full dashboard</a> for details.</p>
''';

  static const String sampleMarkdown = '''
# Release Notes — v2.4.0

## New Features

- **Dark mode** support across all screens
- Keyboard shortcuts for power users
  1. `Ctrl+K` — command palette
  2. `Ctrl+S` — save
- Export to *PDF*, **Word**, and ~~CSV~~ Markdown

## Bug Fixes

| Issue | Severity | Status |
|:------|:--------:|-------:|
| Login timeout | High | Fixed |
| Dark mode flicker | Low | Fixed |
| Export hangs on large docs | Medium | Fixed |

> Upgrade recommended for all users on v2.3.x or earlier.

See the [full changelog](https://example.com/changelog) for details.

```dart
final doc = docx().h1('Hello').build();
```
''';

  /// A rich document built purely through the fluent builder API, exercising
  /// headings, styled text, lists, tables, images, shapes, footnotes, and a
  /// drop cap in one place.
  static DocxBuiltDocument buildDemoDocument() {
    return DocxDocumentBuilder()
        .h1('The docx_creator Showcase')
        .p('This entire page was generated with the fluent builder API — '
            'no HTML or Markdown involved.')
        .add(DocxDropCap(
          letter: 'O',
          lines: 3,
          restOfParagraph: [
            DocxText('nce upon a time, a Dart package needed no native '
                'dependencies to create, read, and export Word documents. '
                'This paragraph demonstrates a true wrap-around drop cap.'),
          ],
        ))
        .h2('Text Formatting')
        .add(DocxParagraph(children: [
          DocxText.bold('Bold '),
          DocxText.italic('Italic '),
          DocxText.underline('Underlined '),
          DocxText.strike('Struck-through '),
          DocxText('Colored', color: DocxColor('#E53935')),
        ]))
        .add(DocxParagraph(children: [
          DocxText('Superscript: x'),
          DocxText.superscript('2'),
          DocxText('   Subscript: H'),
          DocxText.subscript('2'),
          DocxText('O'),
        ]))
        .h2('Lists')
        .bullet(['First bullet', 'Second bullet', 'Third bullet'])
        .numbered(['Step one', 'Step two', 'Step three'])
        .h2('A Table')
        .table([
          ['Feature', 'DOCX', 'PDF'],
          ['Tables', 'Yes', 'Yes'],
          ['Shapes', 'Yes', 'Yes'],
          ['Unicode fallback font', 'N/A', 'Yes'],
        ])
        .h2('A Shape')
        .add(DocxShapeBlock.rectangle(
          width: 180,
          height: 50,
          fillColor: DocxColor('#4472C4'),
          outlineColor: DocxColor.black,
          text: 'Built with DocxShapeBlock',
        ))
        .p('This statement has a footnote attached to it.')
        .addFootnote(DocxFootnote(
          footnoteId: 1,
          content: [DocxParagraph.text('This is the footnote content.')],
        ))
        .quote('A well-formatted document builds trust.')
        .build();
  }

  /// A small document specifically demonstrating the PDF exporter's
  /// automatic Unicode fallback font for non-Latin scripts.
  static DocxBuiltDocument buildUnicodeDemoDocument() {
    return DocxDocumentBuilder()
        .h1('Automatic Unicode Fallback Font')
        .p('No custom font was registered for this document. Non-Latin '
            'scripts below are still rendered correctly in PDF because '
            'docx_creator automatically embeds a bundled fallback font '
            '(DejaVu Sans) the first time it is needed.')
        .h2('Russian (Cyrillic)')
        .p('Привет, мир! Как дела?')
        .h2('Greek')
        .p('Γειά σου κόσμε! Πώς είσαι;')
        .h2('Vietnamese')
        .p('Xin chào thế giới! Bạn khỏe không?')
        .p('An explicit addFont() call always takes priority over this '
            'fallback. CJK and Arabic scripts still need an explicit font, '
            'since they require dedicated, much larger, shaping-aware fonts.')
        .build();
  }

  /// A 1x1 transparent PNG, used as placeholder image bytes for the demo
  /// image feature without shipping a binary asset.
  static Uint8List get placeholderImageBytes => Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);
}
