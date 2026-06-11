import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/layout/bidi_align.dart';
import 'package:flutter/painting.dart' show TextAlign;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Mandatory BiDi alignment table (Plan §C.4) — one assertion per row, in both
  // paragraph directions, so every cell of the table is locked.
  group('resolveJustification — §C.4 table', () {
    test('left → physical left in both directions', () {
      expect(resolveJustification(WordJustification.left, isRtl: false),
          TextAlign.left);
      expect(resolveJustification(WordJustification.left, isRtl: true),
          TextAlign.left);
    });

    test('right → physical right in both directions', () {
      expect(resolveJustification(WordJustification.right, isRtl: false),
          TextAlign.right);
      expect(resolveJustification(WordJustification.right, isRtl: true),
          TextAlign.right);
    });

    test('start → left in LTR, right in RTL', () {
      expect(resolveJustification(WordJustification.start, isRtl: false),
          TextAlign.left);
      expect(resolveJustification(WordJustification.start, isRtl: true),
          TextAlign.right);
    });

    test('end → right in LTR, left in RTL', () {
      expect(resolveJustification(WordJustification.end, isRtl: false),
          TextAlign.right);
      expect(resolveJustification(WordJustification.end, isRtl: true),
          TextAlign.left);
    });

    test('center → center in both directions', () {
      expect(resolveJustification(WordJustification.center, isRtl: false),
          TextAlign.center);
      expect(resolveJustification(WordJustification.center, isRtl: true),
          TextAlign.center);
    });

    test('both → justify in both directions', () {
      expect(resolveJustification(WordJustification.both, isRtl: false),
          TextAlign.justify);
      expect(resolveJustification(WordJustification.both, isRtl: true),
          TextAlign.justify);
    });
  });

  group('justificationFromDocxAlign — collapsed AST bridge', () {
    test('left → start (leading edge / no-jc default)', () {
      expect(
          justificationFromDocxAlign(DocxAlign.left), WordJustification.start);
    });

    test('right → physical right (align-right intent)', () {
      expect(
          justificationFromDocxAlign(DocxAlign.right), WordJustification.right);
    });

    test('center → center', () {
      expect(justificationFromDocxAlign(DocxAlign.center),
          WordJustification.center);
    });

    test('justify → both', () {
      expect(justificationFromDocxAlign(DocxAlign.justify),
          WordJustification.both);
    });
  });

  group('resolveParagraphTextAlign — end-to-end', () {
    test('AST left aligns to leading edge (right in RTL, left in LTR)', () {
      expect(resolveParagraphTextAlign(DocxAlign.left, isRtl: false),
          TextAlign.left);
      expect(resolveParagraphTextAlign(DocxAlign.left, isRtl: true),
          TextAlign.right);
    });

    test('AST right stays physical right in both directions', () {
      expect(resolveParagraphTextAlign(DocxAlign.right, isRtl: false),
          TextAlign.right);
      expect(resolveParagraphTextAlign(DocxAlign.right, isRtl: true),
          TextAlign.right);
    });

    test('center / justify are direction-independent', () {
      expect(resolveParagraphTextAlign(DocxAlign.center, isRtl: true),
          TextAlign.center);
      expect(resolveParagraphTextAlign(DocxAlign.justify, isRtl: true),
          TextAlign.justify);
    });
  });
}
