import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/font_loader/font_metrics_registry.dart';
import 'package:docx_file_viewer/src/layout/span_factory.dart';
import 'package:docx_file_viewer/src/layout/text_measurer.dart';
import 'package:docx_file_viewer/src/widget_generator/paragraph_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §L.1: a run mixing Hebrew and Latin is split per script so each segment
/// gets the right font (`w:ascii` vs `w:cs`), size (`w:sz` vs `w:szCs`) and
/// bold/italic — what Word does, and a precondition for 1:1 line breaking.
void main() {
  late SpanFactory spanFactory;
  late TextMeasurer measurer;
  late ParagraphBuilder builder;

  setUp(() {
    final t = DocxViewTheme.light();
    const config = DocxViewConfig(enableSelection: false);
    final dt = DocxTheme.empty();
    spanFactory = SpanFactory(theme: t, config: config, docxTheme: dt);
    measurer = TextMeasurer(spanFactory: spanFactory);
    builder = ParagraphBuilder(theme: t, config: config, docxTheme: dt);
    // Make "Arial"/"David" resolve to themselves (as if installed) so the DoD's
    // exact font names can be asserted instead of their metric clones.
    FontMetricsRegistry.registerRatio('Arial', 1.15);
    FontMetricsRegistry.registerRatio('David', 1.0);
  });

  tearDown(FontMetricsRegistry.clear);

  group('resolveRunSegments', () {
    test('single-script run stays one segment', () {
      final segs = spanFactory.resolveRunSegments(const DocxText('Hello'));
      expect(segs, hasLength(1));
      expect(segs.single.text, 'Hello');
    });

    test('empty run yields no segments', () {
      expect(spanFactory.resolveRunSegments(const DocxText('')), isEmpty);
    });

    test('DoD: "שלום Hello עולם" with ascii=Arial cs=David, sz 12 / szCs 14',
        () {
      const run = DocxText(
        'שלום Hello עולם',
        fonts: DocxFont(ascii: 'Arial', cs: 'David'),
        fontSize: 12,
        fontSizeCs: 14,
      );
      final segs = spanFactory.resolveRunSegments(run);
      expect(segs, hasLength(3));

      // Hebrew → David at the complex size (14pt).
      expect(segs[0].text, 'שלום ');
      expect(segs[0].style.fontFamily, 'David');
      expect(segs[0].style.fontSize, closeTo(14 * 1.333, 0.01));

      // Latin → Arial at the ascii size (12pt).
      expect(segs[1].text, 'Hello ');
      expect(segs[1].style.fontFamily, 'Arial');
      expect(segs[1].style.fontSize, closeTo(12 * 1.333, 0.01));

      // Trailing Hebrew → David/14 again.
      expect(segs[2].text, 'עולם');
      expect(segs[2].style.fontFamily, 'David');
      expect(segs[2].style.fontSize, closeTo(14 * 1.333, 0.01));
    });

    test('per-script bold/italic (b/bCs, i/iCs) apply to the right segment',
        () {
      const run = DocxText(
        'A א',
        fonts: DocxFont(ascii: 'LatinFont', cs: 'HebrewFont'),
        fontWeight: DocxFontWeight.bold,
        boldCs: false,
        fontStyle: DocxFontStyle.italic,
        italicCs: false,
      );
      final segs = spanFactory.resolveRunSegments(run);
      expect(segs, hasLength(2));

      // Latin segment: bold + italic from w:b/w:i.
      expect(segs[0].text, 'A ');
      expect(segs[0].style.fontWeight, FontWeight.bold);
      expect(segs[0].style.fontStyle, FontStyle.italic);
      // Custom (unknown, unavailable) names are kept verbatim.
      expect(segs[0].style.fontFamily, 'LatinFont');

      // Complex segment: bCs=false / iCs=false override to normal.
      expect(segs[1].text, 'א');
      expect(segs[1].style.fontWeight, FontWeight.normal);
      expect(segs[1].style.fontStyle, FontStyle.normal);
      expect(segs[1].style.fontFamily, 'HebrewFont');
    });

    test('complex segment carries the Hebrew fallback chain', () {
      const run = DocxText('שלום', fonts: DocxFont(cs: 'HebrewFont'));
      final seg = spanFactory.resolveRunSegments(run).single;
      expect(seg.style.fontFamilyFallback, contains('David Libre'));
    });
  });

  // 03-run-rpr.md item 13: small caps must be real OpenType small caps (lowercase
  // → small capitals, real uppercase stays full), not the old uppercase-then-×0.85
  // approximation which wrongly shrank already-uppercase letters.
  group('w:smallCaps → OpenType small caps', () {
    test('lowercase preserved, smcp applied, size not shrunk (Hebrew+Latin)', () {
      const run = DocxText(
        'hello שלום',
        isSmallCaps: true,
        fonts: DocxFont(ascii: 'Arial', cs: 'David'),
        fontSize: 12,
      );
      final segs = spanFactory.resolveRunSegments(run);
      expect(segs, hasLength(2));
      // Latin: source case preserved (not uppercased), smcp on, full 12pt.
      expect(segs[0].text, 'hello ');
      expect(segs[0].style.fontFeatures,
          contains(const FontFeature.enable('smcp')));
      expect(segs[0].style.fontSize, closeTo(12 * 1.333, 0.01));
      // Hebrew is caseless; smcp is harmless and the text is intact.
      expect(segs[1].text, 'שלום');
    });

    test('allCaps still uppercases the glyphs and does not use smcp', () {
      const run = DocxText('hello', isAllCaps: true);
      final seg = spanFactory.resolveRunSegments(run).single;
      expect(seg.text, 'HELLO');
      expect(seg.style.fontFeatures ?? const <FontFeature>[],
          isNot(contains(const FontFeature.enable('smcp'))));
    });
  });

  // 03-run-rpr.md items 39, 40: an explicit w:rtl / w:cs flag forces an
  // otherwise-neutral run into the complex script (the cs font / szCs apply),
  // following the audit's recommendation. Strong Latin still stays Latin.
  group('explicit w:rtl / w:cs force a neutral run complex', () {
    const fonts = DocxFont(ascii: 'Arial', cs: 'David');

    test('w:rtl selects the cs font + szCs for a neutral run', () {
      const plain = DocxText('()', fonts: fonts, fontSize: 12, fontSizeCs: 14);
      const rtl =
          DocxText('()', fonts: fonts, fontSize: 12, fontSizeCs: 14, rtl: true);
      // Without the flag a neutral run is Latin → the ascii font.
      expect(
          spanFactory.resolveRunSegments(plain).single.style.fontFamily, 'Arial');
      // With w:rtl it is complex → the cs font at the complex size.
      final r = spanFactory.resolveRunSegments(rtl).single;
      expect(r.style.fontFamily, 'David');
      expect(r.style.fontSize, closeTo(14 * 1.333, 0.01));
    });

    test('w:cs flag forces the same complex selection', () {
      const run = DocxText('()', fonts: fonts, complexScript: true);
      expect(
          spanFactory.resolveRunSegments(run).single.style.fontFamily, 'David');
    });

    test('strong Latin in an rtl run stays Latin (e.g. "A1")', () {
      const run = DocxText('A1', fonts: fonts, rtl: true);
      expect(
          spanFactory.resolveRunSegments(run).single.style.fontFamily, 'Arial');
    });
  });

  // 03-run-rpr.md item 29: w:u val="words" underlines word characters only, not
  // the spaces between them. The run is re-split at whitespace; the gap pieces
  // drop the underline. Char count is preserved → pagination/search unaffected.
  group('w:u val="words" underlines words, not the spaces', () {
    bool hasUnderline(RunSegment s) =>
        s.style.decoration?.contains(TextDecoration.underline) ?? false;

    test('space piece drops the underline, word pieces keep it (Hebrew+Latin)',
        () {
      const run = DocxText(
        'אב cd',
        decorations: [DocxTextDecoration.underline],
        underlineStyle: DocxUnderlineStyle.words,
      );
      final segs = spanFactory.resolveRunSegments(run);
      expect(segs.map((s) => s.text).toList(), ['אב', ' ', 'cd']);
      expect(hasUnderline(segs[0]), isTrue); // אב
      expect(hasUnderline(segs[1]), isFalse); // the space
      expect(hasUnderline(segs[2]), isTrue); // cd
      // Painter text is byte-identical to the source (offsets preserved).
      expect(segs.map((s) => s.text).join(), 'אב cd');
      expect(segs.last.end, 'אב cd'.length);
    });

    test('strike stays continuous under the spaces', () {
      const run = DocxText(
        'one two',
        decorations: [
          DocxTextDecoration.underline,
          DocxTextDecoration.strikethrough,
        ],
        underlineStyle: DocxUnderlineStyle.words,
      );
      final segs = spanFactory.resolveRunSegments(run);
      final space = segs.firstWhere((s) => s.text == ' ');
      // The space keeps line-through but not the underline.
      expect(space.style.decoration!.contains(TextDecoration.lineThrough),
          isTrue);
      expect(space.style.decoration!.contains(TextDecoration.underline),
          isFalse);
      // Every word piece keeps both decorations.
      for (final s in segs.where((s) => s.text != ' ')) {
        expect(s.style.decoration!.contains(TextDecoration.underline), isTrue);
        expect(
            s.style.decoration!.contains(TextDecoration.lineThrough), isTrue);
      }
    });

    test('a plain (non-words) underline stays continuous — one segment', () {
      const run = DocxText(
        'one two',
        decorations: [DocxTextDecoration.underline],
        underlineStyle: DocxUnderlineStyle.single,
      );
      final segs = spanFactory.resolveRunSegments(run);
      expect(segs, hasLength(1));
      expect(hasUnderline(segs.single), isTrue);
    });
  });

  test('buildMeasurementSpans emits one painter segment but per-script spans',
      () {
    const run = DocxText(
      'שלום Hello עולם',
      fonts: DocxFont(ascii: 'Arial', cs: 'David'),
    );
    final built = spanFactory.buildMeasurementSpans(const [run]);

    // Three visual TextSpans (one per script), but a single split-point segment
    // covering the whole run (its character offsets are unchanged).
    final root = built.root as TextSpan;
    expect(root.children, hasLength(3));
    expect(built.segments, hasLength(1));
    expect(built.segments.single.length, 'שלום Hello עולם'.length);
    expect(built.segments.single.atomic, isFalse);
  });

  group('measure ≡ render with a script-split paragraph', () {
    Future<double> renderedHeight(
      WidgetTester tester,
      DocxParagraph p,
      double width,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: builder.build(p)),
          ),
        ),
      ));
      return tester.getSize(find.byType(RichText).first).height;
    }

    testWidgets('mixed Hebrew/Latin run with distinct per-script sizes',
        (tester) async {
      final p = DocxParagraph(
        isRtl: true,
        children: const [
          DocxText(
            'שלום world זהו mixed טקסט עברי ארוך with אנגלית together בשורה '
            'אחת long enough to wrap across several lines for parity.',
            fonts: DocxFont(ascii: 'Arial', cs: 'David'),
            fontSize: 11,
            fontSizeCs: 13,
          ),
        ],
      );
      final measured =
          measurer.measureParagraph(p, 220.0, direction: TextDirection.rtl);
      final rendered = await renderedHeight(tester, p, 220.0);
      expect(measured.textHeight, closeTo(rendered, 0.5),
          reason: 'measured ${measured.textHeight} vs rendered $rendered');
    });
  });
}
