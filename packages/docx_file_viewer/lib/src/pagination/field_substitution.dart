import 'package:docx_creator/docx_creator.dart';

import 'page_context.dart';

/// Replaces automatic field inlines (`PAGE`/`NUMPAGES`/`SECTIONPAGES`/`PAGEREF`)
/// with concrete text for one page, leaving all other content untouched.
///
/// Pure and allocation-light: only paragraphs that actually contain a field are
/// copied; every other block and inline is reused by reference, so substituting
/// a footer that has no fields returns the original list unchanged.
abstract final class FieldSubstitution {
  /// Returns [blocks] with field inlines resolved against [ctx]. The same list
  /// instance is returned when nothing changed. Accepts any [DocxNode] list (so
  /// it can be applied to a page's slice blocks as well as a header/footer); only
  /// paragraphs carrying a field are copied.
  static List<DocxNode> apply(List<DocxNode> blocks, PageContext ctx) {
    List<DocxNode>? out;
    for (var i = 0; i < blocks.length; i++) {
      final nb = _block(blocks[i], ctx);
      if (!identical(nb, blocks[i])) {
        out ??= List<DocxNode>.of(blocks);
        out[i] = nb;
      }
    }
    return out ?? blocks;
  }

  static DocxNode _block(DocxNode block, PageContext ctx) {
    if (block is DocxParagraph && _hasField(block.children)) {
      return block.copyWith(children: _inlines(block.children, ctx));
    }
    return block;
  }

  static bool _hasField(List<DocxInline> inlines) => inlines.any((i) =>
      i is DocxPageNumber ||
      i is DocxPageCount ||
      i is DocxPageRef ||
      i is DocxStyleRef);

  static List<DocxInline> _inlines(List<DocxInline> inlines, PageContext ctx) {
    // Inherit the styling (size/font/color) of a neighbouring text run so the
    // substituted number matches the surrounding footer text.
    DocxText? ref;
    for (final i in inlines) {
      if (i is DocxText && i.content.trim().isNotEmpty) {
        ref = i;
        break;
      }
    }
    DocxText make(String s) =>
        ref != null ? ref.copyWith(content: s) : DocxText(s);

    return [
      for (final i in inlines)
        if (i is DocxPageNumber)
          make(format(ctx.pageNumber, i.format ?? ctx.sectionFormat))
        else if (i is DocxPageCount)
          make(format(i.sectionScope ? ctx.sectionPages : ctx.totalPages,
              i.format ?? ctx.sectionFormat))
        else if (i is DocxPageRef)
          make(_pageRef(i, ctx))
        else if (i is DocxStyleRef)
          make(_styleRef(i, ctx))
        else
          i,
    ];
  }

  static String _pageRef(DocxPageRef ref, PageContext ctx) {
    final page = ctx.bookmarkPages[ref.bookmark];
    if (page == null) return ref.cachedText ?? '';
    return format(page, ref.format ?? ctx.sectionFormat);
  }

  static String _styleRef(DocxStyleRef ref, PageContext ctx) {
    final key = PageContext.normalizeStyleKey(ref.styleName);
    final value =
        ref.searchFromTop ? ctx.styleRefFirst[key] : ctx.styleRefLast[key];
    // Fall back to Word's cached value when pagination found no matching
    // paragraph (e.g. a style only used after this page).
    return value ?? ref.cachedText ?? '';
  }

  /// Formats [n] in the given page-number [format].
  static String format(int n, DocxPageNumberFormat format) =>
      NumberFormatter.formatPage(n, format);
}
