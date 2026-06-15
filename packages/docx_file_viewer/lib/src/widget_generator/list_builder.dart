import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:docx_file_viewer/src/layout/numbering_resolver.dart';
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

  /// Pre-computed marker strings keyed by item identity, from the document-wide
  /// [NumberingResolver] pass (Plan §G). When an item is present here its marker
  /// is taken verbatim — counters continue correctly across interrupting blocks,
  /// table cells and same-`numId` lists. Null (or a missing item) means this is a
  /// factory-built list with no global numbering, so the per-list fallback runs.
  final Map<DocxListItem, String>? numberLabels;

  ListBuilder({
    required this.theme,
    required this.config,
    required this.paragraphBuilder,
    this.docxTheme,
    this.numberLabels,
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

    // When the global resolver (§G) supplied labels for this list's items, its
    // markers are authoritative (correct continuation across blocks/cells); the
    // local counter pass below only runs for factory lists it did not cover.
    final resolved = numberLabels;

    for (final item in list.items) {
      final level = item.level.clamp(0, DocxList.maxLevels - 1);
      final isCheckbox = _itemIsCheckbox(item);

      String? orderedMarker;
      if (resolved != null) {
        // The resolver decided which items are numbered: a present label (even
        // an empty one, for `w:numFmt="none"`) marks an ordered item; absent
        // means a bullet/unnumbered item.
        if (!isCheckbox) orderedMarker = resolved[item];
      } else {
        final ordered = _itemIsOrdered(item, list);
        if (ordered && !isCheckbox) {
          // Advance this level (seeding from its start on first appearance);
          // bullet/checkbox items must not consume a number.
          counters[level] = counters.containsKey(level)
              ? counters[level]! + 1
              : _startForLevel(list, level);
          orderedMarker = _composeMarker(list, item, level, counters);
        }

        // A shallower (or equal, for the next sibling) item resets deeper
        // levels so nested counters restart — matching Word.
        for (var i = level + 1; i < DocxList.maxLevels; i++) {
          counters.remove(i);
        }
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
      // Shared with the global resolver so both render identical strings.
      return expandLvlText(
        template,
        isLgl: levelDef?.isLgl ?? false,
        valueForLevel: (l) => counters[l] ?? _startForLevel(list, l),
        defForLevel: list.levelFor,
      );
    }
    final value = counters[level] ?? _startForLevel(list, level);
    if (levelDef != null) {
      // Resolved from the document: use its actual format, no synthetic cascade.
      if (levelDef.numFmtRaw == 'none') return '';
      return '${formatNumberComponent(value, rawFmt: levelDef.numFmtRaw, fmt: levelDef.format, level: level)}.';
    }
    // Factory-built list with no resolved definition: honor a per-item override
    // format, else the base style, applying the default decimal cascade by depth.
    final format = item.overrideStyle?.numberFormat ?? list.style.numberFormat;
    return orderedMarkerWithCascade(value, level, format);
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

    // Number justification (`w:lvlJc`) and suffix (`w:suff`) from the resolved
    // level definition (Plan §G.2). The default keeps the carefully-tuned RTL
    // behaviour: the glyph hugs the text side of its box (TextAlign.end) and a
    // small gap separates it from the body, approximating Word's tab suffix.
    final levelDef = list.levelFor(level);
    final markerAlign = switch (levelDef?.lvlJc) {
      'center' => TextAlign.center,
      'left' || 'start' => TextAlign.start,
      _ => TextAlign.end,
    };
    // `w:suff="nothing"` removes the gap between number and text; `space`/`tab`
    // (and the unset default) keep the standard separation.
    final markerGap = levelDef?.suff == 'nothing' ? 0.0 : 4.0;

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

    // Size the marker to the item's own body text rather than the theme
    // default. A document whose runs are larger than the default would
    // otherwise render a tiny marker that, top-aligned, looks like a raised
    // superscript next to the text.
    final bodyFontSize = firstSpanFontSize(spans);
    final markerStyle = TextStyle(
      color: markerColor,
      fontSize: style.fontSize != null
          ? style.fontSize! * 1.333
          : (bodyFontSize ?? theme.defaultTextStyle.fontSize),
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
      // Align the glyph per `w:lvlJc`; the default (end) hugs the content side
      // of its box so it sits next to the text in both LTR and RTL.
      markerWidget =
          Text(markerText, style: markerStyle, textAlign: markerAlign);
    }

    // Hebrew/Arabic content must lay out RTL: the marker sits on the right and
    // nested levels indent from the right. `w:bidi` from the document
    // ([DocxListItem.isRtl], חלק A) is authoritative; otherwise we fall back to
    // detecting direction from the item's own text. We wrap in Directionality so
    // the Row, the marker [Text] and the directional padding all mirror.
    final direction = item.isRtl
        ? TextDirection.rtl
        : TextDirectionDetector.fromInlines(item.children);

    return Directionality(
      textDirection: direction,
      child: Padding(
        key: key,
        // Directional: `start` is the right edge under RTL, so deeper levels
        // indent away from the correct margin.
        padding: EdgeInsetsDirectional.only(start: indent, top: 2, bottom: 2),
        child: Row(
          // Baseline-align text markers so the number/letter sits on the same
          // baseline as the first line of body text even when their font
          // metrics differ slightly. Image bullets have no text baseline, so
          // they keep top alignment.
          crossAxisAlignment: style.imageBulletBytes != null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Min-width keeps short markers aligned; long ones (e.g. Roman
            // "viii." or a large gematria value) grow the box instead of
            // clipping.
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 24),
              child: markerWidget,
            ),
            SizedBox(width: markerGap),
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

  /// The font size of the first text-bearing span, used to size the list
  /// marker to match the body text. Returns null when no span declares a size.
  ///
  /// Exposed for testing: the inheritance handling for nested spans is easier to
  /// verify against synthetic span trees than to coax out of the paragraph
  /// builder.
  @visibleForTesting
  static double? firstSpanFontSize(List<InlineSpan> spans) {
    for (final span in spans) {
      final size = _spanFontSize(span);
      if (size != null) return size;
    }
    return null;
  }

  /// Walks an [InlineSpan] tree for the first text-bearing span's effective font
  /// size. [inherited] carries an ancestor's size down so a wrapper span that
  /// declares the size while its children hold the text still resolves correctly.
  static double? _spanFontSize(InlineSpan span, [double? inherited]) {
    if (span is! TextSpan) return null;
    final effective = span.style?.fontSize ?? inherited;
    if (span.text?.isNotEmpty ?? false) return effective;
    for (final child in span.children ?? const <InlineSpan>[]) {
      final size = _spanFontSize(child, effective);
      if (size != null) return size;
    }
    return null;
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
