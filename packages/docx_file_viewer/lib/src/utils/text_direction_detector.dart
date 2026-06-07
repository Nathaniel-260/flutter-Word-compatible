import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/widgets.dart';

/// Detects the writing direction of inline content.
///
/// docx_creator does not expose `w:bidi`/`w:rtl`, so direction is derived from
/// the text itself using a "first strong" scan: the first strongly-typed
/// character wins — Hebrew/Arabic → RTL, Latin → LTR. Shared by the paragraph
/// and list builders so both mirror identically for RTL documents.
class TextDirectionDetector {
  const TextDirectionDetector._();

  /// Returns the direction implied by [children], or [TextDirection.ltr] when
  /// no strongly-typed character is found.
  static TextDirection fromInlines(List<DocxInline> children) {
    for (final child in children) {
      if (child is DocxText) {
        for (final rune in child.content.runes) {
          // Hebrew, Arabic and related RTL Unicode blocks.
          if ((rune >= 0x0590 && rune <= 0x08FF) ||
              (rune >= 0xFB1D && rune <= 0xFDFF) ||
              (rune >= 0xFE70 && rune <= 0xFEFF)) {
            return TextDirection.rtl;
          }
          // Latin letters → strong LTR.
          if ((rune >= 0x0041 && rune <= 0x005A) ||
              (rune >= 0x0061 && rune <= 0x007A)) {
            return TextDirection.ltr;
          }
        }
      }
    }
    return TextDirection.ltr;
  }
}
