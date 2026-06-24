import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

/// 13-theme.md items 3, 6: `w:themeColor` (ST_ThemeColor) tokens —
/// `dark1`/`light1`/`dark2`/`light2`/`hyperlink`/`followedHyperlink` — resolve to
/// the matching clrScheme slot, not just the `dk*`/`lt*`/`hlink` spelling.
void main() {
  const colors = DocxThemeColors(
    dk1: '111111',
    lt1: 'EEEEEE',
    dk2: '222222',
    lt2: 'DDDDDD',
    hlink: '0000FF',
    folHlink: '800080',
  );

  test('ST_ThemeColor tokens map to the same slot as clrScheme names', () {
    expect(colors.getColor('dark1'), colors.getColor('dk1'));
    expect(colors.getColor('light1'), colors.getColor('lt1'));
    expect(colors.getColor('dark2'), colors.getColor('dk2'));
    expect(colors.getColor('light2'), colors.getColor('lt2'));
    expect(colors.getColor('hyperlink'), '0000FF');
    expect(colors.getColor('followedHyperlink'), '800080');
  });

  test('unknown token still returns null', () {
    expect(colors.getColor('bogus'), isNull);
  });

  // 13-theme.md E2: a Hebrew-specific theme font (`<a:font script="Hebr">`)
  // overrides the generic `<a:cs>` for complex (Hebrew) text.
  group('Hebrew theme font (E2)', () {
    test('majorBidi/minorBidi prefer the Hebrew font over generic cs', () {
      const fonts = DocxThemeFonts(
        majorComplexScript: 'Arial',
        minorComplexScript: 'Arial',
        majorHebrew: 'David',
        minorHebrew: 'Frank Ruhl',
      );
      expect(fonts.getFont('majorBidi'), 'David');
      expect(fonts.getFont('minorBidi'), 'Frank Ruhl');
    });

    test('falls back to the generic cs font when no Hebrew entry', () {
      const fonts = DocxThemeFonts(
        majorComplexScript: 'Arial',
        minorComplexScript: 'Arial',
      );
      expect(fonts.getFont('majorBidi'), 'Arial');
      expect(fonts.getFont('minorBidi'), 'Arial');
    });

    test('ThemeParser reads <a:font script="Hebr"> for major and minor', () {
      const xml = '''<?xml version="1.0"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <a:themeElements>
    <a:fontScheme name="Office">
      <a:majorFont>
        <a:latin typeface="Calibri Light"/>
        <a:cs typeface=""/>
        <a:font script="Hebr" typeface="David"/>
      </a:majorFont>
      <a:minorFont>
        <a:latin typeface="Calibri"/>
        <a:cs typeface=""/>
        <a:font script="Hebr" typeface="Frank Ruhl"/>
        <a:font script="Arab" typeface="Arabic Typesetting"/>
      </a:minorFont>
    </a:fontScheme>
  </a:themeElements>
</a:theme>''';
      final (_, fonts) = ThemeParser.parse(xml);
      expect(fonts.majorHebrew, 'David');
      expect(fonts.minorHebrew, 'Frank Ruhl');
      // A Hebrew run referencing the body bidi theme font now resolves to the
      // Hebrew typeface instead of the empty <a:cs>.
      expect(fonts.getFont('minorBidi'), 'Frank Ruhl');
    });
  });
}
