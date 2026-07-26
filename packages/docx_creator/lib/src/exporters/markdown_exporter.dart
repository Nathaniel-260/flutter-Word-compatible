import 'dart:convert';
import 'dart:typed_data';

import '../../docx_creator.dart';
import '../utils/file_saver.dart';

/// Converts a [DocxBuiltDocument] into a Markdown string.
///
/// The output targets GitHub-Flavored Markdown (GFM) plus a small number of
/// widely-supported HTML passthrough tags (`<sup>`, `<sub>`, `<u>`) for the
/// handful of text effects Markdown has no native syntax for. Markdown is a
/// much smaller format than DOCX, so this is a lossy, best-effort export:
///
/// * Floating images, drawing shapes, raw/unmodeled OOXML, section breaks,
///   and table-of-contents fields have no Markdown equivalent and are
///   dropped from the output.
/// * Table cell merges (`colSpan`/`rowSpan`) collapse to a plain cell,
///   because Markdown tables have no merge syntax.
/// * A table's first row is always rendered as the header row, because a
///   Markdown table is not valid without one — this applies even if
///   [DocxTable.hasHeader] is false.
/// * Highlighted text uses the `==text==` convention. It renders as plain
///   text (delimiters included) on parsers that don't support it, which is
///   an acceptable degradation for a formatting hint.
///
/// See the README's "Markdown Export" section for the full support matrix.
///
/// ## Basic usage
/// ```dart
/// final markdown = MarkdownExporter().export(doc);
/// await MarkdownExporter().exportToFile(doc, 'output.md');
/// ```
class MarkdownExporter {
  /// Exports [doc] to Markdown and writes it to [filePath].
  Future<void> exportToFile(DocxBuiltDocument doc, String filePath) async {
    try {
      final markdown = export(doc);
      final bytes = utf8.encode(markdown);
      await FileSaver.save(filePath, Uint8List.fromList(bytes));
    } catch (e) {
      throw DocxExportException(
        'Failed to write file: $e',
        targetFormat: 'Markdown',
        context: filePath,
      );
    }
  }

  /// Exports [doc] to a Markdown string.
  String export(DocxBuiltDocument doc) {
    final blocks = <String>[];
    for (final element in doc.elements) {
      final block = _convertNode(element);
      if (block.isNotEmpty) blocks.add(block);
    }

    final footnoteDefinitions = _convertFootnoteDefinitions(doc);
    if (footnoteDefinitions.isNotEmpty) blocks.add(footnoteDefinitions);

    return '${blocks.join('\n\n')}\n';
  }

  // ============================================================
  // BLOCK-LEVEL NODES
  // ============================================================

  String _convertNode(DocxNode node) {
    if (node is DocxParagraph) return _convertParagraph(node);
    if (node is DocxTable) return _convertTable(node);
    if (node is DocxList) return _convertList(node);
    if (node is DocxImage) return _convertBlockImage(node);
    if (node is DocxDropCap) return _convertDropCap(node);
    // Shapes, raw XML, TOC fields, and section breaks have no meaningful
    // Markdown representation and are intentionally omitted.
    return '';
  }

  String _convertParagraph(DocxParagraph para) {
    if (_isHorizontalRule(para)) return '---';
    if (para.children.isEmpty) return '';

    final headingLevel = _headingLevel(para.styleId);
    if (headingLevel != null) {
      final content = para.children.map(_convertInline).join();
      return '${'#' * headingLevel} $content';
    }

    if (_isCodeBlock(para)) {
      final code = (para.children.single as DocxText).content;
      return '```\n$code\n```';
    }

    final content = para.children.map(_convertInline).join();
    if (para.styleId == DocxStyleIds.quote) {
      return content.split('\n').map((line) => '> $line').join('\n');
    }

    return content;
  }

  /// [DocxDocumentBuilder.hr] emits an empty paragraph whose only property
  /// is a bottom border — that shape is how a horizontal rule survives the
  /// round trip through the AST, since there is no dedicated `DocxHr` node.
  bool _isHorizontalRule(DocxParagraph para) =>
      para.children.isEmpty && para.borderBottomSide != null;

  /// [DocxParagraph.code] produces a paragraph shaded `F5F5F5` with exactly
  /// one [DocxText.code] child (Courier New, no other formatting) — that
  /// shape is how a fenced code block is distinguished here from an
  /// ordinary paragraph whose only content happens to be an inline code
  /// span (e.g. HTML `<p><code>x</code></p>`, which stays inline).
  bool _isCodeBlock(DocxParagraph para) {
    if (para.shadingFill != 'F5F5F5') return false;
    if (para.children.length != 1) return false;
    final child = para.children.single;
    return child is DocxText &&
        child.fontFamily == 'Courier New' &&
        !child.isBold &&
        !child.isItalic &&
        !child.isLink &&
        child.decorations.isEmpty;
  }

  int? _headingLevel(String? styleId) {
    if (styleId == null || !styleId.startsWith('Heading')) return null;
    final level = int.tryParse(styleId.substring('Heading'.length));
    if (level == null || level < 1 || level > 6) return null;
    return level;
  }

  String _convertDropCap(DocxDropCap dropCap) {
    final rest = dropCap.restOfParagraph.map(_convertInline).join();
    return '${_escapeMarkdown(dropCap.letter)}$rest';
  }

  String _convertBlockImage(DocxImage image) => _convertInlineImage(
        image.asInline,
      );

  String _convertTable(DocxTable table) {
    if (table.rows.isEmpty) return '';

    final columnCount = table.rows
        .map((row) => row.cells.length)
        .reduce((a, b) => a > b ? a : b);
    if (columnCount == 0) return '';

    final rows = table.rows.map(_convertTableRow).toList();
    final separator = '| ${List.filled(columnCount, '---').join(' | ')} |';
    // A Markdown table requires a header row syntactically, so the first
    // row always becomes the header regardless of DocxTable.hasHeader.
    rows.insert(1, separator);
    return rows.join('\n');
  }

  String _convertTableRow(DocxTableRow row) {
    final cells = row.cells.map(_convertTableCell).toList();
    return '| ${cells.join(' | ')} |';
  }

  String _convertTableCell(DocxTableCell cell) {
    final parts =
        cell.children.map<String>(_convertNode).where((s) => s.isNotEmpty);
    // '|' would terminate the cell early and a literal newline would break
    // the row, so cell content is flattened onto one line with <br> joins.
    return parts
        .join('<br>')
        .replaceAll('\n', ' ')
        .replaceAll('|', '\\|')
        .trim();
  }

  String _convertList(DocxList list) {
    if (list.items.isEmpty) return '';

    final buffer = StringBuffer();
    final orderedCounters = <int, int>{};

    for (final item in list.items) {
      // Re-entering a level after a deeper nested list resets its counter,
      // matching how ordered lists restart in Word.
      orderedCounters.removeWhere((level, _) => level > item.level);

      var children = item.children;
      var marker = '-';
      var checkboxPrefix = '';

      if (children.isNotEmpty && children.first is DocxCheckbox) {
        final checkbox = children.first as DocxCheckbox;
        checkboxPrefix = checkbox.isChecked ? '[x] ' : '[ ] ';
        children = children.skip(1).toList();
      } else if (list.isOrdered) {
        final start = list.startIndex;
        final next = (orderedCounters[item.level] ?? (start - 1)) + 1;
        orderedCounters[item.level] = next;
        marker = '$next.';
      }

      final indent = '  ' * item.level;
      final content = children.map(_convertInline).join();
      buffer.writeln('$indent$marker $checkboxPrefix$content');
    }

    return buffer.toString().trimRight();
  }

  // ============================================================
  // INLINE NODES
  // ============================================================

  String _convertInline(DocxInline inline) {
    if (inline is DocxText) return _convertText(inline);
    if (inline is DocxLineBreak) return '  \n';
    if (inline is DocxTab) return '\t';
    if (inline is DocxInlineImage) return _convertInlineImage(inline);
    if (inline is DocxCheckbox) return inline.isChecked ? '☑' : '☐';
    if (inline is DocxFootnoteRef) return '[^${inline.footnoteId}]';
    if (inline is DocxEndnoteRef) return '[^e${inline.endnoteId}]';
    // Page number/count fields, inline shapes, and raw inline XML have no
    // static Markdown equivalent and are intentionally omitted.
    return '';
  }

  String _convertText(DocxText text) {
    if (_isInlineCode(text)) return _inlineCodeSpan(text.content);

    var content = _escapeMarkdown(text.content).replaceAll('\n', '  \n');

    if (text.isSuperscript) content = '<sup>$content</sup>';
    if (text.isSubscript) content = '<sub>$content</sub>';
    if (text.isUnderline) content = '<u>$content</u>';
    if (text.isStrike || text.isDoubleStrike) content = '~~$content~~';

    // Emphasis markers around whitespace-only content are not valid
    // Markdown emphasis, so leave those runs unwrapped.
    if (content.trim().isNotEmpty) {
      if (text.isBold && text.isItalic) {
        content = '***$content***';
      } else if (text.isBold) {
        content = '**$content**';
      } else if (text.isItalic) {
        content = '*$content*';
      }
    }

    if (text.highlight != DocxHighlight.none) content = '==$content==';
    if (text.href != null) content = '[$content](${text.href})';
    return content;
  }

  bool _isInlineCode(DocxText text) =>
      text.fontFamily == 'Courier New' &&
      !text.isBold &&
      !text.isItalic &&
      !text.isLink &&
      text.decorations.isEmpty;

  /// Wraps [content] in a CommonMark code span, choosing a backtick fence
  /// one character longer than the longest run of backticks already inside
  /// the content (per the CommonMark code-span spec) so embedded backticks
  /// can never prematurely close the span.
  String _inlineCodeSpan(String content) {
    final runLengths =
        RegExp('`+').allMatches(content).map((m) => m.group(0)!.length);
    final fenceLength =
        runLengths.isEmpty ? 1 : runLengths.reduce((a, b) => a > b ? a : b) + 1;
    final fence = '`' * fenceLength;
    final needsPadding = content.startsWith('`') || content.endsWith('`');
    return needsPadding ? '$fence $content $fence' : '$fence$content$fence';
  }

  String _convertInlineImage(DocxInlineImage image) {
    final dataUri =
        Uri.dataFromBytes(image.bytes, mimeType: 'image/${image.extension}')
            .toString();
    final alt = (image.altText ?? '').replaceAll('[', '(').replaceAll(']', ')');
    return '![$alt]($dataUri)';
  }

  String _convertFootnoteDefinitions(DocxBuiltDocument doc) {
    final definitions = <String>[];

    for (final footnote in doc.footnotes ?? const <DocxFootnote>[]) {
      final content = footnote.content
          .map<String>(_convertNode)
          .where((s) => s.isNotEmpty)
          .join(' ');
      definitions.add('[^${footnote.footnoteId}]: $content');
    }
    for (final endnote in doc.endnotes ?? const <DocxEndnote>[]) {
      final content = endnote.content
          .map<String>(_convertNode)
          .where((s) => s.isNotEmpty)
          .join(' ');
      definitions.add('[^e${endnote.endnoteId}]: $content');
    }

    return definitions.join('\n');
  }

  /// Escapes characters that would otherwise be interpreted as Markdown
  /// syntax if they appeared literally in plain text content.
  String _escapeMarkdown(String text) {
    return text.replaceAllMapped(
      RegExp(r'[\\`*_\[\]<>]'),
      (m) => '\\${m[0]}',
    );
  }
}
