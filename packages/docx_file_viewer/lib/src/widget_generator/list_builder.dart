import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/utils/text_direction_detector.dart';
import 'package:flutter/material.dart';

import 'paragraph_builder.dart';

/// Builds Flutter widgets from [DocxList] elements.
///
/// Supports [DocxListStyle] and all [DocxNumberFormat] types from docx_creator.
class ListBuilder {
  final DocxViewTheme theme;
  final DocxViewConfig config;
  final ParagraphBuilder paragraphBuilder;
  final DocxTheme? docxTheme;

  ListBuilder({
    required this.theme,
    required this.config,
    required this.paragraphBuilder,
    this.docxTheme,
  });

  /// Whether [item] should be rendered with an ordered marker. A per-item
  /// [DocxListItem.overrideStyle] (set for mixed nesting) takes precedence over
  /// the list's own [DocxList.isOrdered].
  bool _itemIsOrdered(DocxListItem item, DocxList list) =>
      item.overrideStyle != null
          ? item.overrideStyle!.numberFormat != DocxNumberFormat.bullet
          : list.isOrdered;

  /// Whether [item] is a checklist/task-list item — its first *significant*
  /// inline is a checkbox — in which case the checkbox glyph replaces the list
  /// marker. Leading empty/whitespace text (common from HTML parsing) is
  /// skipped so a stray `DocxText(' ')` before the checkbox doesn't reintroduce
  /// a double marker; the scan stops at the first real content inline.
  bool _itemIsCheckbox(DocxListItem item) {
    for (final child in item.children) {
      if (child is DocxCheckbox) return true;
      if (child is DocxText && child.content.trim().isEmpty) continue;
      return false;
    }
    return false;
  }

  /// Build a widget from a [DocxList].
  Widget build(DocxList list, {BlockIndexCounter? counter}) {
    final itemWidgets = <Widget>[];

    // Track numbering per level for nested lists
    final numberingByLevel = <int, int>{};

    for (final item in list.items) {
      final level = item.level;
      final ordered = _itemIsOrdered(item, list);
      final isCheckbox = _itemIsCheckbox(item);

      // Only consume a number when the item actually renders an ordered marker;
      // bullet and checkbox items must not advance the counter (otherwise a
      // checkbox between "1." and "3." would silently skip "2.").
      var number = 1;
      if (ordered && !isCheckbox) {
        numberingByLevel[level] = (numberingByLevel[level] ?? 0) + 1;
        number = numberingByLevel[level]!;
      }

      // Reset numbering for deeper levels when we go back up
      for (var i = level + 1; i < DocxList.maxLevels; i++) {
        numberingByLevel.remove(i);
      }

      itemWidgets.add(_buildListItem(
        item,
        list: list,
        number: number,
        ordered: ordered,
        isCheckbox: isCheckbox,
        counter: counter,
      ));
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: itemWidgets,
      ),
    );
  }

  Widget _buildListItem(
    DocxListItem item, {
    required DocxList list,
    required int number,
    required bool ordered,
    required bool isCheckbox,
    BlockIndexCounter? counter,
  }) {
    final level = item.level.clamp(0, DocxList.maxLevels - 1);
    // Use override style if available, otherwise fall back to list style
    final style = item.overrideStyle ?? list.style;

    // Calculate indent from list style or default
    final indentPerLevel =
        style.indentPerLevel / 15.0; // Convert twips to pixels
    // Calculate initial indent based on level
    double indent = 16.0 + (level * indentPerLevel.clamp(16.0, 48.0));

    // Build content from all inline children with search support
    List<InlineSpan> spans;
    Key? key;
    if (counter != null && paragraphBuilder.searchController != null) {
      final blockIndex = counter.value;
      final matches = paragraphBuilder.searchController!.matches
          .where((m) => m.blockIndex == blockIndex)
          .toList();

      if (matches.isNotEmpty) {
        key = counter.registerKey(blockIndex);
      }
      counter.increment();

      spans =
          paragraphBuilder.buildInlineSpans(item.children, matches: matches);
    } else {
      spans = paragraphBuilder.buildInlineSpans(item.children);
    }

    // ... (rest of method)

    // Apply style properties from DocxListStyle to the marker

    // Resolve theme color for marker
    final markerColor = _resolveColor(
          style.color.hex,
          style.themeColor,
          style.themeTint,
          style.themeShade,
        ) ??
        _parseHexColor(style.color.hex); // Fallback

    // Resolve theme font for marker
    final markerFont = docxTheme != null && style.themeFont != null
        ? docxTheme!.fonts.getFont(style.themeFont!)
        : null;

    final markerStyle = TextStyle(
      color: markerColor,
      fontSize: style.fontSize != null
          ? style.fontSize! * 1.333
          : theme.defaultTextStyle.fontSize,
      fontWeight: style.fontWeight == DocxFontWeight.bold
          ? FontWeight.bold
          : FontWeight.normal,
      fontFamily:
          markerFont ?? style.fontFamily ?? theme.defaultTextStyle.fontFamily,
      // Match the body line metrics so the marker shares the first text line's
      // box; otherwise a taller text line makes the top-aligned marker look
      // like a raised superscript.
      height: theme.defaultTextStyle.height,
    );

    // Build marker widget
    Widget markerWidget;
    if (style.imageBulletBytes != null) {
      markerWidget = Image.memory(
        style.imageBulletBytes!,
        width: 12,
        height: 12,
        fit: BoxFit.contain,
      );
    } else {
      // A checklist/task-list item carries its own checkbox glyph (☐/☒) in its
      // inline content, so suppress the list bullet to avoid a double marker
      // ("• ☐ task"). Ordering is decided by the caller (per-item, honoring an
      // overrideStyle for mixed nesting).
      String markerText;
      if (isCheckbox) {
        markerText = '';
      } else if (ordered && style.numberFormat != DocxNumberFormat.bullet) {
        markerText = _getOrderedMarker(number, level, style.numberFormat);
      } else {
        markerText = _getBulletMarker(level, style);
      }
      // Align the glyph to the content side of its box so it hugs the text in
      // both LTR and RTL.
      markerWidget =
          Text(markerText, style: markerStyle, textAlign: TextAlign.end);
    }

    // Hebrew/Arabic content must lay out RTL: the marker sits on the right and
    // nested levels indent from the right. We detect direction from the item's
    // own text (docx_creator does not expose w:bidi) and wrap in Directionality
    // so the Row, the marker [Text] and the directional padding all mirror.
    final direction = TextDirectionDetector.fromInlines(item.children);

    return Directionality(
      textDirection: direction,
      child: Padding(
        key: key,
        // Directional: `start` is the right edge under RTL, so deeper levels
        // indent away from the correct margin.
        padding: EdgeInsetsDirectional.only(start: indent, top: 2, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Min-width keeps short markers aligned; long ones (e.g. Roman
            // "viii." or a large gematria value) grow the box instead of
            // clipping.
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 24),
              child: markerWidget,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: config.enableSelection
                  ? SelectableText.rich(TextSpan(children: spans))
                  : RichText(
                      text: TextSpan(children: spans),
                      textDirection: direction,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get bullet marker based on level and style.
  String _getBulletMarker(int level, DocxListStyle style) {
    // If style has a custom bullet, use it
    if (style.bullet.isNotEmpty && style.bullet != '•') {
      return style.bullet;
    }
    // Otherwise use the shared level-based default bullets
    return DocxList.bulletForLevel(level);
  }

  /// Get ordered marker based on number format.
  ///
  /// For the default decimal list, the format cascades by depth
  /// (1. → a. → i. → 1. ...) to match Word's standard multilevel list and the
  /// DOCX numbering definition produced on export. An explicitly chosen format
  /// (e.g. upperRoman) is kept at every level, mirroring the exporter's
  /// behavior for custom list styles.
  String _getOrderedMarker(int number, int level, DocxNumberFormat format) {
    final effectiveFormat = format == DocxNumberFormat.decimal
        ? DocxList.cascadeFormatForLevel(level)
        : format;
    switch (effectiveFormat) {
      case DocxNumberFormat.decimal:
        return '$number.';
      case DocxNumberFormat.lowerAlpha:
        return '${_toLowerAlpha(number)}.';
      case DocxNumberFormat.upperAlpha:
        return '${_toUpperAlpha(number)}.';
      case DocxNumberFormat.lowerRoman:
        return '${_toRoman(number).toLowerCase()}.';
      case DocxNumberFormat.upperRoman:
        return '${_toRoman(number)}.';
      case DocxNumberFormat.hebrew:
        return '${_toHebrewNumber(number)}.';
      case DocxNumberFormat.bullet:
        return DocxList.bulletForLevel(level);
    }
  }

  /// Converts [n] to a Hebrew gematria numeral (א, ב … י, יא … ק, קא …).
  /// Uses the conventional טו/טז spellings for 15/16 to avoid forming part of
  /// the divine name. Matches Word's "hebrew1" numbering format.
  ///
  /// Gematria here covers 1..999. Hebrew thousands require a separator (׳) that
  /// this additive scheme does not produce, so values ≥ 1000 fall back to plain
  /// decimal rather than emitting an unconventional letter run. List indices
  /// realistically never reach that range.
  String _toHebrewNumber(int n) {
    if (n <= 0 || n >= 1000) return '$n';
    const units = <(int, String)>[
      (400, 'ת'), (300, 'ש'), (200, 'ר'), (100, 'ק'),
      (90, 'צ'), (80, 'פ'), (70, 'ע'), (60, 'ס'), (50, 'נ'),
      (40, 'מ'), (30, 'ל'), (20, 'כ'), (10, 'י'),
      (9, 'ט'), (8, 'ח'), (7, 'ז'), (6, 'ו'), (5, 'ה'),
      (4, 'ד'), (3, 'ג'), (2, 'ב'), (1, 'א'),
    ];
    final buffer = StringBuffer();
    var remaining = n;
    for (final (value, letter) in units) {
      while (remaining >= value) {
        buffer.write(letter);
        remaining -= value;
      }
    }
    return buffer
        .toString()
        .replaceAll('יה', 'טו') // 15 → טו (not יה)
        .replaceAll('יו', 'טז'); // 16 → טז (not יו)
  }

  String _toLowerAlpha(int n) {
    if (n <= 0) return '';
    final code = ((n - 1) % 26) + 97; // 'a' = 97
    return String.fromCharCode(code);
  }

  String _toUpperAlpha(int n) {
    if (n <= 0) return '';
    final code = ((n - 1) % 26) + 65; // 'A' = 65
    return String.fromCharCode(code);
  }

  String _toRoman(int n) {
    if (n <= 0 || n > 3999) return n.toString();
    const romanNumerals = [
      ['M', 1000],
      ['CM', 900],
      ['D', 500],
      ['CD', 400],
      ['C', 100],
      ['XC', 90],
      ['L', 50],
      ['XL', 40],
      ['X', 10],
      ['IX', 9],
      ['V', 5],
      ['IV', 4],
      ['I', 1],
    ];
    final buffer = StringBuffer();
    int remaining = n;
    for (final entry in romanNumerals) {
      final numeral = entry[0] as String;
      final value = entry[1] as int;
      while (remaining >= value) {
        buffer.write(numeral);
        remaining -= value;
      }
    }
    return buffer.toString();
  }

  Color? _resolveColor(
      String? hex, String? themeColor, String? themeTint, String? themeShade) {
    Color? baseColor;

    // 1. Try Theme Color
    if (themeColor != null && docxTheme != null) {
      final themeHex = docxTheme!.colors.getColor(themeColor);
      if (themeHex != null) {
        baseColor = _parseHexColor(themeHex);
      }
    }

    // 2. Fallback to direct Hex
    if (baseColor == null && hex != null && hex != 'auto') {
      baseColor = _parseHexColor(hex);
    }

    if (baseColor == null) return null;

    // 3. Apply Tint/Shade
    if (themeTint != null) {
      final tintVal = int.tryParse(themeTint, radix: 16);
      if (tintVal != null) {
        final factor = tintVal / 255.0;
        baseColor = Color.alphaBlend(
            Colors.white.withValues(alpha: 1 - factor), baseColor);
      }
    }

    if (themeShade != null) {
      final shadeVal = int.tryParse(themeShade, radix: 16);
      if (shadeVal != null) {
        // Shade means darker, mix with black
        final factor = shadeVal / 255.0;
        baseColor = Color.alphaBlend(
            Colors.black.withValues(alpha: 1 - factor), baseColor);
      }
    }

    return baseColor;
  }

  Color _parseHexColor(String hex) {
    String cleanHex = hex.replaceAll('#', '').replaceAll('0x', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    } else if (cleanHex.length == 8) {
      return Color(int.parse(cleanHex, radix: 16));
    }
    return Colors.black;
  }
}
