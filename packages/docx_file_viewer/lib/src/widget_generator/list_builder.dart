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

    // Current counter value per level. Seeded lazily from each level's start so
    // both custom start values ("list starting from 5") and Word's compound
    // (legal) numbering — %1.%2.%3 — can reference any ancestor's count.
    final counters = <int, int>{};

    for (final item in list.items) {
      final level = item.level.clamp(0, DocxList.maxLevels - 1);
      final ordered = _itemIsOrdered(item, list);
      final isCheckbox = _itemIsCheckbox(item);

      String? orderedMarker;
      if (ordered && !isCheckbox) {
        // Advance this level (seeding from its start on first appearance);
        // bullet/checkbox items must not consume a number.
        counters[level] =
            counters.containsKey(level) ? counters[level]! + 1 : _startForLevel(list, level);
        orderedMarker = _composeMarker(list, item, level, counters);
      }

      // A shallower (or equal, for the next sibling) item resets deeper levels
      // so nested counters restart — matching Word and the previous behaviour.
      for (var i = level + 1; i < DocxList.maxLevels; i++) {
        counters.remove(i);
      }

      itemWidgets.add(_buildListItem(
        item,
        list: list,
        orderedMarker: orderedMarker,
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

  /// The 1-based value the first item at [level] should display. Honors the
  /// resolved per-level start (`w:start` / `w:startOverride`) and, for the top
  /// level, list continuation via [DocxList.startIndex].
  int _startForLevel(DocxList list, int level) {
    final base = list.levelFor(level)?.start ?? 1;
    if (level == 0 && list.startIndex > base) return list.startIndex;
    return base;
  }

  /// Builds the marker for an ordered item at [level] given the live [counters].
  ///
  /// When the document supplies a compound template (`w:lvlText`, e.g.
  /// `%1.%2.%3.`) it is expanded against every referenced ancestor counter —
  /// reproducing Word's multilevel "legal" numbering. Otherwise it falls back to
  /// the single-component marker (resolved per-level format, or the default
  /// decimal cascade for factory-built lists).
  String _composeMarker(
      DocxList list, DocxListItem item, int level, Map<int, int> counters) {
    final levelDef = list.levelFor(level);
    final template = levelDef?.lvlText;
    if (template != null && template.contains('%')) {
      return _expandLvlText(list, template, counters);
    }
    final value = counters[level] ?? _startForLevel(list, level);
    if (levelDef != null) {
      // Resolved from the document: use its actual format, no synthetic cascade.
      return '${_formatComponent(value, level, levelDef.format)}.';
    }
    // Factory-built list with no resolved definition: honor a per-item override
    // format, else the base style, applying the default decimal cascade by depth.
    final format = item.overrideStyle?.numberFormat ?? list.style.numberFormat;
    return _getOrderedMarker(value, level, format);
  }

  /// Expands a `w:lvlText` template, replacing each `%n` with the count of
  /// level `n-1` formatted in that level's own format.
  String _expandLvlText(DocxList list, String template, Map<int, int> counters) {
    return template.replaceAllMapped(RegExp(r'%(\d)'), (m) {
      final refLevel = int.parse(m.group(1)!) - 1;
      final value = counters[refLevel] ?? _startForLevel(list, refLevel);
      final fmt = list.levelFor(refLevel)?.format ?? DocxNumberFormat.decimal;
      return _formatComponent(value, refLevel, fmt);
    });
  }

  /// Formats a single numbering component (no trailing separator).
  String _formatComponent(int n, int level, DocxNumberFormat format) {
    switch (format) {
      case DocxNumberFormat.decimal:
        return '$n';
      case DocxNumberFormat.lowerAlpha:
        return _toLowerAlpha(n);
      case DocxNumberFormat.upperAlpha:
        return _toUpperAlpha(n);
      case DocxNumberFormat.lowerRoman:
        return _toRoman(n).toLowerCase();
      case DocxNumberFormat.upperRoman:
        return _toRoman(n);
      case DocxNumberFormat.hebrew:
        return _toHebrewNumber(n);
      case DocxNumberFormat.bullet:
        return DocxList.bulletForLevel(level);
    }
  }

  Widget _buildListItem(
    DocxListItem item, {
    required DocxList list,
    required String? orderedMarker,
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
      } else if (orderedMarker != null) {
        markerText = orderedMarker;
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

  String _toLowerAlpha(int n) => _toAlpha(n, 97); // 'a'

  String _toUpperAlpha(int n) => _toAlpha(n, 65); // 'A'

  /// Bijective base-26 alphabetical numbering, matching Word: a..z, then aa, ab
  /// … az, ba … (there is no "zero" digit, so it is not plain base-26).
  String _toAlpha(int n, int base) {
    if (n <= 0) return '';
    final buffer = StringBuffer();
    var remaining = n;
    while (remaining > 0) {
      final rem = (remaining - 1) % 26;
      buffer.writeCharCode(base + rem);
      remaining = (remaining - 1) ~/ 26;
    }
    // Digits were produced least-significant first; reverse to read left→right.
    return String.fromCharCodes(buffer.toString().codeUnits.reversed);
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
