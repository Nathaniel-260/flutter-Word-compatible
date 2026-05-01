import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

void main() {
  group('DocxFooter.imageAndText', () {
    test('initializes correctly with image and text in a table', () {
      final imgBytes = Uint8List.fromList([1, 2, 3]);
      final footer = DocxFooter.imageAndText(
        imageBytes: imgBytes,
        imageExtension: 'png',
        text: 'Footer Text',
        imageWidth: 50,
        imageHeight: 50,
        textAlign: DocxAlign.center,
      );

      expect(footer.children.length, equals(1));
      expect(footer.children[0], isA<DocxTable>());

      final table = footer.children[0] as DocxTable;
      expect(table.width, equals(5000));
      expect(table.widthType, equals(DocxWidthType.pct));

      // Check borders are invisible
      final style = table.style;
      expect(style, isNotNull);
      expect(style.borderTop!.size, equals(0));
      expect(style.borderTop!.color, equals(DocxColor.white));
      expect(style.borderBottom!.size, equals(0));
      expect(style.borderLeft!.size, equals(0));
      expect(style.borderRight!.size, equals(0));
      expect(style.borderInsideH!.size, equals(0));
      expect(style.borderInsideV!.size, equals(0));

      // Check cells
      expect(table.rows.length, equals(1));
      expect(table.rows[0].cells.length, equals(2));

      // Left cell with image
      final leftCell = table.rows[0].cells[0];
      expect(leftCell.verticalAlign, equals(DocxVerticalAlign.center));
      expect(leftCell.children[0], isA<DocxImage>());
      final image = leftCell.children[0] as DocxImage;
      expect(image.bytes, equals(imgBytes));
      expect(image.extension, equals('png'));
      expect(image.width, equals(50));
      expect(image.height, equals(50));
      expect(image.align, equals(DocxAlign.left));

      // Right cell with text
      final rightCell = table.rows[0].cells[1];
      expect(rightCell.verticalAlign, equals(DocxVerticalAlign.center));
      expect(rightCell.children[0], isA<DocxParagraph>());
      final p = rightCell.children[0] as DocxParagraph;
      expect(p.align, equals(DocxAlign.center));
      expect(p.children[0], isA<DocxText>());
      expect((p.children[0] as DocxText).content, equals('Footer Text'));
    });
  });
}
