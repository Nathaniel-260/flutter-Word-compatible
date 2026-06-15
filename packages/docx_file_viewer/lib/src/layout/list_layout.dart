import 'package:docx_creator/docx_creator.dart';

/// Vertical spacing (px) above and below a list item, mirroring Word.
///
/// A list item read from a DOCX carries its [DocxListItem.sourceParagraph],
/// whose resolved `spacingBefore`/`spacingAfter` (null → 0, exactly like ordinary
/// paragraphs) is the authoritative gap. `w:contextualSpacing` collapses the
/// space *between* sibling items (keeping only the gap above the first and below
/// the last), which is what Word's built-in "List Paragraph" style does.
///
/// Factory / HTML / Markdown lists have no source paragraph; they keep a small
/// default gap so they don't render flush.
///
/// Single source of truth shared by the renderer ([ListBuilder]) and the
/// measurer ([Paginator]) so pagination matches what is painted (measure ≡
/// render, Plan §2.4 / §G.2).
({double before, double after}) listItemSpacingPx(
  DocxListItem item, {
  required bool isFirst,
  required bool isLast,
}) {
  const twipsToPx = 1 / 15.0;
  final src = item.sourceParagraph;
  if (src == null) return (before: 2.0, after: 2.0);

  var before = (src.spacingBefore ?? 0) * twipsToPx;
  var after = (src.spacingAfter ?? 0) * twipsToPx;
  if (src.contextualSpacing) {
    if (!isFirst) before = 0;
    if (!isLast) after = 0;
  }
  return (
    before: before.clamp(0.0, double.infinity),
    after: after.clamp(0.0, double.infinity),
  );
}

/// Whether [list] was read from a DOCX (its items carry source paragraphs), in
/// which case the renderer must not add its own margin around the list — the
/// per-item [listItemSpacingPx] already reproduces Word's spacing.
bool listHasSourceParagraphs(DocxList list) =>
    list.items.any((it) => it.sourceParagraph != null);
