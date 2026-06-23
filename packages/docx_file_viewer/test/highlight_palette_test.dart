import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 03-run-rpr.md item 28: `w:highlight` is the fixed 16-colour
/// `ST_HighlightColor` palette (ISO/IEC 29500). Word paints these exact RGB
/// values; the viewer must use them verbatim, not Material approximations.
void main() {
  late SpanFactory sf;

  setUp(() {
    sf = SpanFactory(
      theme: DocxViewTheme.light(),
      config: const DocxViewConfig(enableSelection: false),
      docxTheme: DocxTheme.empty(),
    );
  });

  test('every highlight value maps to its exact Word RGB', () {
    const expected = <DocxHighlight, Color>{
      DocxHighlight.black: Color(0xFF000000),
      DocxHighlight.blue: Color(0xFF0000FF),
      DocxHighlight.cyan: Color(0xFF00FFFF),
      DocxHighlight.green: Color(0xFF00FF00),
      DocxHighlight.magenta: Color(0xFFFF00FF),
      DocxHighlight.red: Color(0xFFFF0000),
      DocxHighlight.yellow: Color(0xFFFFFF00),
      DocxHighlight.white: Color(0xFFFFFFFF),
      DocxHighlight.darkBlue: Color(0xFF000080),
      DocxHighlight.darkCyan: Color(0xFF008080),
      DocxHighlight.darkGreen: Color(0xFF008000),
      DocxHighlight.darkMagenta: Color(0xFF800080),
      DocxHighlight.darkRed: Color(0xFF800000),
      DocxHighlight.darkYellow: Color(0xFF808000),
      DocxHighlight.darkGray: Color(0xFF808080),
      DocxHighlight.lightGray: Color(0xFFC0C0C0),
    };
    expected.forEach((h, color) {
      expect(sf.highlightToColor(h), color, reason: '$h');
    });
    expect(sf.highlightToColor(DocxHighlight.none), isNull);
  });

  test('yellow is FFFF00 (not Material FFEB3B), applied as run background; HE+EN',
      () {
    const run = DocxText('שלום world', highlight: DocxHighlight.yellow);
    final style = sf.resolveRunStyle(run);
    expect(style.backgroundColor, const Color(0xFFFFFF00));
    // Guard against a regression back to the Material approximation.
    expect(style.backgroundColor, isNot(Colors.yellow)); // Material = FFEB3B
  });
}
