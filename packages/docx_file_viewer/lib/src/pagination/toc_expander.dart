import 'package:docx_creator/docx_creator.dart';

/// Flattens [DocxTableOfContents] blocks into their cached content so the TOC
/// flows and renders as ordinary paragraphs (Plan §K.1).
///
/// Word stores a TOC as an SDT wrapping cached paragraphs — `hyperlink` runs to
/// each heading, a leader-dot tab, and a `PAGEREF` page number. The viewer does
/// not regenerate the TOC; it shows what Word saved, with the page numbers
/// updated live by [FieldSubstitution] against our own pagination. Returning the
/// cached paragraphs lets the normal paragraph path handle the leader tab
/// (TabbedLineRenderer) and the bookmarks (hyperlink anchors).
///
/// Returns the same list instance when there is nothing to expand (the common
/// case), so non-TOC documents pay nothing.
List<DocxNode> expandTocBlocks(List<DocxNode> nodes) {
  var hasToc = false;
  for (final n in nodes) {
    if (n is DocxTableOfContents) {
      hasToc = true;
      break;
    }
  }
  if (!hasToc) return nodes;

  final out = <DocxNode>[];
  for (final n in nodes) {
    if (n is DocxTableOfContents) {
      out.addAll(n.cachedContent);
    } else {
      out.add(n);
    }
  }
  return out;
}
