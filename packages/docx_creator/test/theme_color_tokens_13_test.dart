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
}
