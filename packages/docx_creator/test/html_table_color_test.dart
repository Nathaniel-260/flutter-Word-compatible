import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('HTML table row/cell color parsing', () {
    test('applies a named background-color and text color from <tr style>',
        () async {
      final html = '''
<table border="1">
  <tr style="background-color: #4472C4; color: white;">
    <th>Name</th>
    <th>Status</th>
  </tr>
  <tr>
    <td>Task 1</td>
    <td style="background-color: lightgreen;">Complete</td>
  </tr>
</table>
''';
      final nodes = await DocxParser.fromHtml(html);
      final table = nodes.single as DocxTable;

      final headerRow = table.rows[0];
      for (final cell in headerRow.cells) {
        expect(cell.shadingFill, '4472C4');
        final para = cell.children.single as DocxParagraph;
        final text = para.children.single as DocxText;
        expect(text.color?.hex, 'FFFFFF');
      }

      final bodyRow = table.rows[1];
      expect(bodyRow.cells[0].shadingFill, isNull);
      // Named color, not just literal hex.
      expect(bodyRow.cells[1].shadingFill, '90EE90');
    });

    test('a cell background overrides its row background', () async {
      final html = '''
<table>
  <tr style="background-color: red;">
    <td style="background-color: blue;">Cell</td>
    <td>Other</td>
  </tr>
</table>
''';
      final nodes = await DocxParser.fromHtml(html);
      final table = nodes.single as DocxTable;

      expect(table.rows[0].cells[0].shadingFill, '0000FF');
      expect(table.rows[0].cells[1].shadingFill, 'FF0000');
    });

    test('rows inside <thead> are marked as header rows', () async {
      final html = '''
<table>
  <thead><tr><th>Col</th></tr></thead>
  <tbody><tr><td>Val</td></tr></tbody>
</table>
''';
      final nodes = await DocxParser.fromHtml(html);
      final table = nodes.single as DocxTable;

      expect(table.rows[0].isHeader, isTrue);
      expect(table.rows[1].isHeader, isFalse);
    });
  });
}
