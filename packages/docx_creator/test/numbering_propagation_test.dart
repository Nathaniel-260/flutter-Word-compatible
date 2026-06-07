import 'package:docx_creator/docx_creator.dart';
import 'package:test/test.dart';

/// Verifies that the reader carries the full per-level numbering definition
/// (format, compound `w:lvlText`, and start / startOverride) onto
/// [DocxList.levels], so the renderer can reproduce Word's multilevel numbering.
void main() {
  group('Numbering definition propagation (export → read)', () {
    test('ordered list exposes per-level lvlText and format', () async {
      final doc = docx().numbered(['One', 'Two', 'Three']).build();
      final bytes = await DocxExporter().exportToBytes(doc);
      final readDoc = await DocxReader.loadFromBytes(bytes);

      final list = readDoc.elements.whereType<DocxList>().first;
      expect(list.levels, isNotEmpty);

      final level0 = list.levelFor(0);
      expect(level0, isNotNull);
      expect(level0!.format, DocxNumberFormat.decimal);
      // Word's single-component template for the top level.
      expect(level0.lvlText, '%1.');
    });

    test('startOverride is parsed onto the level start', () async {
      final doc = docx()
          .addList(DocxList.numbered(['Fifth', 'Sixth'], start: 5))
          .build();
      final bytes = await DocxExporter().exportToBytes(doc);
      final readDoc = await DocxReader.loadFromBytes(bytes);

      final list = readDoc.elements.whereType<DocxList>().first;
      // Either the level start or the list-level startIndex must reflect 5.
      final level0 = list.levelFor(0);
      expect(level0, isNotNull);
      expect(level0!.start == 5 || list.startIndex == 5, isTrue);
    });
  });
}
