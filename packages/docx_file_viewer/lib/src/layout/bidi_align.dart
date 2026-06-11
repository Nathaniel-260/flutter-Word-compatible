import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/painting.dart' show TextAlign;

/// Word paragraph justification (`w:jc`), keeping the physical/logical
/// distinction that the AST's [DocxAlign] collapses.
///
/// OOXML's `w:jc` carries six values that matter for layout: the *physical*
/// [left]/[right], the *logical* [start]/[end] (which flip with paragraph
/// direction), [center], and [both] (justify). The reader maps
/// `start`/`left` → [DocxAlign.left] and `end`/`right` → [DocxAlign.right],
/// so the original token is not recoverable from the AST alone — see
/// [justificationFromDocxAlign].
enum WordJustification { left, right, start, end, center, both }

/// Resolves a `w:jc` value to a *physical* [TextAlign] for the given paragraph
/// direction, implementing the mandatory BiDi alignment table (Plan §C.4).
///
/// | `w:jc`   | LTR paragraph | RTL paragraph (`w:bidi`) |
/// |----------|---------------|--------------------------|
/// | `left`   | left          | left  (physical)         |
/// | `right`  | right         | right (physical)         |
/// | `start`  | left          | right                    |
/// | `end`    | right         | left                     |
/// | `center` | center        | center                   |
/// | `both`   | justify       | justify                  |
///
/// Alignment never affects line breaking or height, so this is a render-only
/// concern and is independent of the measurer.
TextAlign resolveJustification(
  WordJustification jc, {
  required bool isRtl,
}) {
  switch (jc) {
    case WordJustification.left:
      return TextAlign.left;
    case WordJustification.right:
      return TextAlign.right;
    case WordJustification.start:
      return isRtl ? TextAlign.right : TextAlign.left;
    case WordJustification.end:
      return isRtl ? TextAlign.left : TextAlign.right;
    case WordJustification.center:
      return TextAlign.center;
    case WordJustification.both:
      return TextAlign.justify;
  }
}

/// Bridges the collapsed [DocxAlign] back to a [WordJustification].
///
/// Because the reader discards the physical/logical distinction
/// (`start`/`left` → [DocxAlign.left]; `end`/`right` → [DocxAlign.right]),
/// we apply the interpretation that loses the least fidelity on real
/// documents and matches the creator's own round-trip (which writes
/// [DocxAlign.left] back as `w:jc="start"`):
///
/// - [DocxAlign.left] → **start**: a bidi paragraph with no explicit `w:jc`
///   (the reader's default) and the common Hebrew "align to leading edge"
///   both align to the start edge — right in RTL. Explicit physical
///   `w:jc="left"` inside an RTL paragraph is the only case this mis-handles
///   (rare); documented as a conscious deviation (Plan §8.2).
/// - [DocxAlign.right] → **right** (physical): the "align right" button is the
///   dominant intent and stays on the right edge in both directions.
WordJustification justificationFromDocxAlign(DocxAlign align) {
  switch (align) {
    case DocxAlign.left:
      return WordJustification.start;
    case DocxAlign.center:
      return WordJustification.center;
    case DocxAlign.right:
      return WordJustification.right;
    case DocxAlign.justify:
      return WordJustification.both;
  }
}

/// Convenience: resolves the physical [TextAlign] for a paragraph whose
/// resolved direction is [isRtl] (from `w:bidi` when present, otherwise the
/// content detector). Combines [justificationFromDocxAlign] and
/// [resolveJustification].
TextAlign resolveParagraphTextAlign(DocxAlign align, {required bool isRtl}) =>
    resolveJustification(justificationFromDocxAlign(align), isRtl: isRtl);
