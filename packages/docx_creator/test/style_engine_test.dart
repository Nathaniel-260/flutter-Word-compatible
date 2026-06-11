import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
// DocxStyleResolver/ThemeColorResolver are internal (not yet exported); import
// them directly until the engine is wired into the pipeline.
import 'package:docx_creator/src/reader/docx_reader/models/style_engine.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

const _ns =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

/// Parse an `<w:rPr>` snippet into an [XmlElement].
XmlElement rPr(String inner) =>
    XmlDocument.parse('<w:rPr $_ns>$inner</w:rPr>').rootElement;

/// Build a named style from an rPr snippet.
DocxStyle style(String id, String rprInner,
        {String? basedOn, String type = 'paragraph'}) =>
    DocxStyle.fromXml(id, type: type, basedOn: basedOn, rPr: rPr(rprInner));

void main() {
  group('B — DocxStyleResolver: basedOn chain (B.1)', () {
    test('3-level chain: each level contributes its own props', () {
      final styles = {
        'A': style('A', '<w:sz w:val="20"/><w:color w:val="FF0000"/>'),
        'B': style('B', '<w:b/>', basedOn: 'A'),
        'C': style('C', '<w:sz w:val="40"/>', basedOn: 'B'),
      };
      final resolver = DocxStyleResolver(styles: styles);
      final s = resolver.resolveRun(paragraphStyleId: 'C');

      expect(s.fontSize, 20.0, reason: 'sz=40 half-points → 20pt, from C');
      expect(s.color?.hex, 'FF0000', reason: 'colour inherited from root A');
      expect(s.fontWeight, DocxFontWeight.bold, reason: 'bold from B');
    });

    test('chainLayers is root→leaf and cached', () {
      final styles = {
        'A': style('A', '<w:b/>'),
        'B': style('B', '<w:i/>', basedOn: 'A'),
      };
      final resolver = DocxStyleResolver(styles: styles);
      final layers = resolver.chainLayers('B');
      expect(layers.map((l) => l.id), ['A', 'B']);
      // Second call returns the identical cached list instance.
      expect(identical(resolver.chainLayers('B'), layers), isTrue);
    });
  });

  group('B — basedOn inheritance vs cross-level toggle XOR (B.2)', () {
    test('basedOn chain uses normal nearest-wins inheritance, not XOR', () {
      final styles = {
        'P1': style('P1', '<w:b/>'),
        'P2': style('P2', '<w:b/>', basedOn: 'P1'),
        'P3': style('P3', '<w:b/>', basedOn: 'P2'),
      };
      final resolver = DocxStyleResolver(styles: styles);
      // Re-asserting bold down a basedOn chain stays bold (it does NOT cancel by
      // parity); this matches ReaderContext.resolveStyle and Word inheritance.
      expect(resolver.resolveRun(paragraphStyleId: 'P1').fontWeight,
          DocxFontWeight.bold);
      expect(resolver.resolveRun(paragraphStyleId: 'P2').fontWeight,
          DocxFontWeight.bold);
      expect(resolver.resolveRun(paragraphStyleId: 'P3').fontWeight,
          DocxFontWeight.bold);
    });

    test('child inherits a toggle the parent set and the child omits', () {
      final styles = {
        'Base': style('Base', '<w:b/>'),
        'Child': style('Child', '<w:i/>', basedOn: 'Base'),
      };
      final s = DocxStyleResolver(styles: styles)
          .resolveRun(paragraphStyleId: 'Child');
      expect(s.fontWeight, DocxFontWeight.bold, reason: 'inherited from Base');
      expect(s.fontStyle, DocxFontStyle.italic, reason: 'set on Child');
    });

    test('paragraph-style bold XOR character-style bold → off (canonical)', () {
      // The documented toggle case: an emphasis style over already-bold text
      // cancels to non-bold.
      final styles = {
        'Para': style('Para', '<w:b/>'),
        'Strong': style('Strong', '<w:b/>', type: 'character'),
      };
      final s = DocxStyleResolver(styles: styles)
          .resolveRun(paragraphStyleId: 'Para', runStyleId: 'Strong');
      expect(s.fontWeight, DocxFontWeight.normal,
          reason: 'bold (pStyle) ^ bold (rStyle) → off');
    });

    test('cross-level XOR is per-property (caps cancels, italic survives)', () {
      final styles = {
        'Para': style('Para', '<w:caps/><w:i/>'),
        'Char': style('Char', '<w:caps/>', type: 'character'),
      };
      final s = DocxStyleResolver(styles: styles)
          .resolveRun(paragraphStyleId: 'Para', runStyleId: 'Char');
      expect(s.isAllCaps, isFalse, reason: 'caps ^ caps → off');
      expect(s.fontStyle, DocxFontStyle.italic,
          reason: 'italic only on pStyle');
    });

    // TODO(golden): characterization test — it locks the *current* "direct
    // overrides" choice, which ISO 29500 §17.7.3's canonical example suggests
    // should actually be an XOR at the direct level (direct <w:b/> on bold text
    // → not bold). Confirm against a real-Word golden before wiring; if XOR is
    // correct this expectation flips to DocxFontWeight.normal.
    test('direct rPr currently overrides the cancelled cross-level toggle', () {
      final styles = {
        'Para': style('Para', '<w:b/>'),
        'Strong': style('Strong', '<w:b/>', type: 'character'), // cancels → off
      };
      final resolver = DocxStyleResolver(styles: styles);
      final direct = DocxStyle.fromXml('temp', rPr: rPr('<w:b/>'));
      final s = resolver.resolveRun(
          paragraphStyleId: 'Para', runStyleId: 'Strong', direct: direct);
      expect(s.fontWeight, DocxFontWeight.bold,
          reason: 'direct bold currently overrides the cancelled style toggle');
    });
  });

  group('B — explicit toggle-off (w:val="0")', () {
    test('child style <w:b w:val="0"/> forces bold OFF, not another toggle',
        () {
      final styles = {
        'Base': style('Base', '<w:b/>'),
        'Child': style('Child', '<w:b w:val="0"/>', basedOn: 'Base'),
      };
      final resolver = DocxStyleResolver(styles: styles);
      expect(resolver.resolveRun(paragraphStyleId: 'Child').fontWeight,
          DocxFontWeight.normal,
          reason: 'explicit off must win regardless of XOR parity');
    });

    test('direct rPr can disable an inherited toggle', () {
      final styles = {'P': style('P', '<w:caps/>')};
      final resolver = DocxStyleResolver(styles: styles);
      final direct = DocxStyle.fromXml('temp', rPr: rPr('<w:caps w:val="0"/>'));
      expect(
          resolver.resolveRun(paragraphStyleId: 'P', direct: direct).isAllCaps,
          isFalse);
    });
  });

  group('B — docDefaults (rPrDefault) as base layer', () {
    final docDefaultsRun = DocxStyle.fromXml('__d',
        rPr: rPr('<w:sz w:val="22"/><w:rFonts w:ascii="Calibri"/>'));

    test('run with no explicit size inherits docDefaults font/size', () {
      final styles = {'A': style('A', '<w:b/>')};
      final resolver =
          DocxStyleResolver(styles: styles, docDefaultsRun: docDefaultsRun);
      final s = resolver.resolveRun(paragraphStyleId: 'A');
      expect(s.fontSize, 11.0,
          reason: 'sz=22 half-points → 11pt from rPrDefault');
      expect(s.fontFamily, 'Calibri');
      expect(s.fontWeight, DocxFontWeight.bold);
    });

    test('bare run (no styles) still picks up docDefaults', () {
      final resolver =
          DocxStyleResolver(styles: const {}, docDefaultsRun: docDefaultsRun);
      expect(resolver.resolveRun().fontSize, 11.0);
    });

    test('a named style overrides the docDefaults size', () {
      final styles = {'A': style('A', '<w:sz w:val="48"/>')};
      final resolver =
          DocxStyleResolver(styles: styles, docDefaultsRun: docDefaultsRun);
      expect(resolver.resolveRun(paragraphStyleId: 'A').fontSize, 24.0);
    });

    test('docDefaults is a base, not an XOR participant (decision lock)', () {
      // docDefaults bold + a single named bold layer → bold. docDefaults does
      // NOT XOR with the named layer (which would cancel to off); it only acts
      // as the fallback when no named layer touches the toggle. See style_engine
      // _mergeStyleLayers.
      final boldDefaults = DocxStyle.fromXml('__d', rPr: rPr('<w:b/>'));
      final styles = {'A': style('A', '<w:b/>')};
      final resolver =
          DocxStyleResolver(styles: styles, docDefaultsRun: boldDefaults);
      expect(resolver.resolveRun(paragraphStyleId: 'A').fontWeight,
          DocxFontWeight.bold);
      // And when no named layer touches bold, docDefaults bold shows through.
      final resolver2 = DocxStyleResolver(
          styles: {'B': style('B', '<w:i/>')}, docDefaultsRun: boldDefaults);
      expect(resolver2.resolveRun(paragraphStyleId: 'B').fontWeight,
          DocxFontWeight.bold);
    });
  });

  group('B — character (run) style layering', () {
    test('rStyle adds bold on top of the paragraph style colour', () {
      final styles = {
        'Para': style('Para', '<w:color w:val="0000FF"/>'),
        'Strong': style('Strong', '<w:b/>', type: 'character'),
      };
      final resolver = DocxStyleResolver(styles: styles);
      final s =
          resolver.resolveRun(paragraphStyleId: 'Para', runStyleId: 'Strong');
      expect(s.color?.hex, '0000FF');
      expect(s.fontWeight, DocxFontWeight.bold);
    });
  });

  group('B — basedOn loop & depth guards (B.5)', () {
    test('A→B→A cycle terminates instead of hanging', () {
      final styles = {
        'A': style('A', '<w:b/>', basedOn: 'B'),
        'B': style('B', '<w:i/>', basedOn: 'A'),
      };
      final resolver = DocxStyleResolver(styles: styles);
      expect(() => resolver.resolveRun(paragraphStyleId: 'A'), returnsNormally);
      expect(resolver.chainLayers('A').length, lessThanOrEqualTo(2));
    });

    test('chain longer than maxDepth is truncated', () {
      final styles = <String, DocxStyle>{};
      for (var i = 0; i <= 20; i++) {
        styles['S$i'] =
            style('S$i', '<w:b/>', basedOn: i == 0 ? null : 'S${i - 1}');
      }
      final resolver = DocxStyleResolver(styles: styles, maxDepth: 5);
      expect(resolver.chainLayers('S20').length, 5);
    });
  });

  group('B — theme colour tint/shade (B.3)', () {
    test('tint mixes toward white: c*tint + 255*(1-tint)', () {
      // tint 0x99 = 0.6 → red stays FF, green/blue rise to 0x66.
      expect(
          ThemeColorResolver.applyTintShade('FF0000', tintHex: '99'), 'FF6666');
    });

    test('shade mixes toward black: c*shade', () {
      // shade 0x80 ≈ 0.502 → red halves to 0x80.
      expect(ThemeColorResolver.applyTintShade('FF0000', shadeHex: '80'),
          '800000');
    });

    test('tint and shade together apply in sequence (tint then shade)', () {
      // 0x80 ≈ 0.502. FF0000 --tint--> FF7F7F --shade--> 804040.
      expect(
          ThemeColorResolver.applyTintShade('FF0000',
              tintHex: '80', shadeHex: '80'),
          '804040');
    });

    test('resolve against theme colour scheme by name', () {
      const colors = DocxThemeColors(); // accent1 = 4F81BD
      expect(ThemeColorResolver.resolve(colors, 'accent1'), '4F81BD');
      expect(ThemeColorResolver.resolve(colors, 'text1'), '000000');
      expect(ThemeColorResolver.resolve(colors, 'no-such-name'), isNull);
    });

    test('auto colour: black on light/none, white on dark (B.3)', () {
      expect(ThemeColorResolver.resolveAutoColor(), '000000',
          reason: 'no background → black');
      expect(ThemeColorResolver.resolveAutoColor(backgroundHex: 'FFFFFF'),
          '000000');
      expect(ThemeColorResolver.resolveAutoColor(backgroundHex: 'FFFF00'),
          '000000',
          reason: 'yellow is light');
      expect(ThemeColorResolver.resolveAutoColor(backgroundHex: '000000'),
          'FFFFFF');
      expect(ThemeColorResolver.resolveAutoColor(backgroundHex: '#1F3864'),
          'FFFFFF',
          reason: 'dark blue → white text (handles leading #)');
    });
  });

  group('B — conditional table styles (cnfStyle/tblLook, B.4)', () {
    test('firstRow conditional shading applies only to the first row', () {
      final ctx = ReaderContext(Archive());
      StyleParser(ctx).parse('''
        <w:styles $_ns>
          <w:style w:type="table" w:styleId="Grid">
            <w:tblStylePr w:type="firstRow">
              <w:tcPr><w:shd w:val="clear" w:fill="FF0000"/></w:tcPr>
            </w:tblStylePr>
          </w:style>
        </w:styles>''');

      const cell = '<w:tc><w:tcPr><w:tcW w:w="5000" w:type="dxa"/></w:tcPr>'
          '<w:p><w:r><w:t>x</w:t></w:r></w:p></w:tc>';
      final parser = TableParser(ctx, InlineParser(ctx));
      final table = parser.parse(XmlDocument.parse('''
        <w:tbl $_ns>
          <w:tblPr>
            <w:tblStyle w:val="Grid"/>
            <w:tblLook w:firstRow="1" w:noHBand="1" w:noVBand="1"/>
          </w:tblPr>
          <w:tblGrid><w:gridCol w:w="5000"/></w:tblGrid>
          <w:tr>$cell</w:tr>
          <w:tr>$cell</w:tr>
        </w:tbl>''').rootElement);

      expect(table.rows.first.cells.first.shadingFill, '#FF0000',
          reason: 'first-row conditional shading from the table style');
      expect(table.rows[1].cells.first.shadingFill, isNull,
          reason: 'body rows get no firstRow conditional');
    });
  });
}
