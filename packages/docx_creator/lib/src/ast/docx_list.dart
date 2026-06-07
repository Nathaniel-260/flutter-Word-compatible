import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../core/enums.dart';
import 'docx_inline.dart';
import 'docx_node.dart';

/// List styling configuration.
///
/// ```dart
/// DocxList.bullet(items, style: DocxListStyle.circle)
/// DocxList.numbered(items, style: DocxListStyle.roman)
/// ```
class DocxListStyle {
  /// Bullet character (for unordered lists).
  final String bullet;

  /// Number format (for ordered lists).
  final DocxNumberFormat numberFormat;

  /// Indentation per level in twips.
  final int indentPerLevel;

  /// Hanging indent in twips.
  final int hangingIndent;

  /// Text style for list items.
  final DocxFontWeight fontWeight;
  final DocxColor color;
  final double? fontSize;

  /// Theme color reference.
  final String? themeColor;
  final String? themeTint;
  final String? themeShade;
  final String? themeFont;
  final String? fontFamily;

  /// Custom image bullet bytes (png/jpg).
  ///
  /// If provided, this overrides [bullet] and [numberFormat].
  final Uint8List? imageBulletBytes;

  const DocxListStyle({
    this.bullet = '•',
    this.numberFormat = DocxNumberFormat.decimal,
    this.indentPerLevel = 720,
    this.hangingIndent = 360,
    this.fontWeight = DocxFontWeight.normal,
    this.color = DocxColor.black,
    this.fontSize,
    this.themeColor,
    this.themeTint,
    this.themeShade,
    this.themeFont,
    this.fontFamily,
    this.imageBulletBytes,
  });

  /// Solid disc bullet (default)
  static const disc = DocxListStyle(bullet: '•');

  /// Circle bullet
  static const circle = DocxListStyle(bullet: '◦');

  /// Square bullet
  static const square = DocxListStyle(bullet: '▪');

  /// Dash bullet
  static const dash = DocxListStyle(bullet: '-');

  /// Arrow bullet
  static const arrow = DocxListStyle(bullet: '→');

  /// Checkmark bullet
  static const check = DocxListStyle(bullet: '✓');

  /// Decimal numbers (1, 2, 3)
  static const decimal = DocxListStyle(numberFormat: DocxNumberFormat.decimal);

  /// Lowercase letters (a, b, c)
  static const lowerAlpha = DocxListStyle(
    numberFormat: DocxNumberFormat.lowerAlpha,
  );

  /// Uppercase letters (A, B, C)
  static const upperAlpha = DocxListStyle(
    numberFormat: DocxNumberFormat.upperAlpha,
  );

  /// Lowercase roman (i, ii, iii)
  static const lowerRoman = DocxListStyle(
    numberFormat: DocxNumberFormat.lowerRoman,
  );

  /// Uppercase roman (I, II, III)
  static const upperRoman = DocxListStyle(
    numberFormat: DocxNumberFormat.upperRoman,
  );

  /// Hebrew letter numbering / gematria (א, ב, ג … יא, יב …)
  static const hebrew = DocxListStyle(
    numberFormat: DocxNumberFormat.hebrew,
  );
}

/// Number format for ordered lists.
enum DocxNumberFormat {
  decimal, // 1, 2, 3
  lowerAlpha, // a, b, c
  upperAlpha, // A, B, C
  lowerRoman, // i, ii, iii
  upperRoman, // I, II, III
  hebrew, // א, ב, ג (gematria; OOXML "hebrew1")
  bullet, // Unordered
}

/// A list element (bulleted or numbered).
///
/// ## Bulleted List
/// ```dart
/// DocxList.bullet(['First', 'Second', 'Third'])
/// DocxList.bullet(items, style: DocxListStyle.circle)
/// ```
///
/// ## Numbered List
/// ```dart
/// DocxList.numbered(['Step 1', 'Step 2'])
/// DocxList.numbered(items, style: DocxListStyle.roman)
/// ```
///
/// ## Custom Items
/// ```dart
/// DocxList(
///   items: [
///     DocxListItem([DocxText.bold('Bold item')]),
///     DocxListItem([DocxText('Normal item')]),
///   ],
/// )
/// ```
class DocxList extends DocxBlock {
  final List<DocxListItem> items;
  final bool isOrdered;
  final DocxListStyle style;
  final int startIndex;

  int? numId;

  DocxList({
    required this.items,
    this.isOrdered = false,
    this.style = const DocxListStyle(),
    this.startIndex = 1,
    this.numId,
    super.id,
  });

  /// Maximum number of nesting levels a list supports (levels 0..8), matching
  /// Word's multilevel lists. Single source of truth for every per-level loop
  /// and clamp in the exporter and viewer.
  static const maxLevels = 9;

  /// Default bullet glyphs by nesting depth, cycled every 3 levels. Single
  /// source of truth shared by the DOCX exporter and the Flutter viewer so
  /// nested bullets look identical in both.
  static const defaultBulletChars = ['•', '◦', '▪'];

  /// The default bullet glyph for [level].
  static String bulletForLevel(int level) =>
      defaultBulletChars[level % defaultBulletChars.length];

  /// The numbering format for a default decimal multilevel list at [level]:
  /// decimal → lowerAlpha → lowerRoman, repeating every 3 levels. Single source
  /// of truth shared by the viewer renderer and the DOCX numbering generator.
  static DocxNumberFormat cascadeFormatForLevel(int level) {
    switch (level % 3) {
      case 0:
        return DocxNumberFormat.decimal;
      case 1:
        return DocxNumberFormat.lowerAlpha;
      default:
        return DocxNumberFormat.lowerRoman;
    }
  }

  /// Tags flattened nested-list [items] with an [DocxListItem.overrideStyle]
  /// carrying their own ordering, so a numbered list nested in a bulleted one
  /// (or vice-versa) keeps its markers after flattening. Items that already
  /// carry an override are left untouched; when the nested kind matches the
  /// parent ([differs] is false) nothing is tagged, keeping homogeneous lists
  /// unchanged. Shared by the HTML and Markdown list parsers.
  ///
  /// The override only records ordering (decimal vs bullet); a nested list's
  /// own custom bullet glyph or indentation is not preserved through this path.
  /// In practice the parsers do not emit such per-sublist styling, so this is a
  /// non-issue today, but a future custom-styled nested list would fall back to
  /// the default marker for the overridden levels.
  static List<DocxListItem> withOrderingOverride(
    List<DocxListItem> items,
    bool ordered, {
    required bool differs,
  }) {
    if (!differs) return items;
    final style = DocxListStyle(
      numberFormat:
          ordered ? DocxNumberFormat.decimal : DocxNumberFormat.bullet,
    );
    return [
      for (final it in items)
        it.overrideStyle != null ? it : it.copyWith(overrideStyle: style),
    ];
  }

  /// Creates a bulleted list.
  factory DocxList.bullet(
    List<String> texts, {
    DocxListStyle style = const DocxListStyle(),
  }) {
    return DocxList(
      isOrdered: false,
      style: style,
      items: texts.map((t) => DocxListItem.text(t)).toList(),
    );
  }

  /// Creates a numbered list.
  factory DocxList.numbered(
    List<String> texts, {
    DocxListStyle style = const DocxListStyle(),
    int start = 1,
  }) {
    return DocxList(
      isOrdered: true,
      style: style,
      startIndex: start,
      items: texts.map((t) => DocxListItem.text(t)).toList(),
    );
  }

  /// Creates from list items with rich content.
  factory DocxList.items(
    List<DocxListItem> items, {
    bool ordered = false,
    DocxListStyle style = const DocxListStyle(),
    int start = 1,
  }) {
    return DocxList(
        items: items, isOrdered: ordered, style: style, startIndex: start);
  }

  DocxList copyWith({
    List<DocxListItem>? items,
    bool? isOrdered,
    DocxListStyle? style,
    int? numId,
    int? startIndex,
  }) {
    final list = DocxList(
      items: items ?? this.items,
      isOrdered: isOrdered ?? this.isOrdered,
      style: style ?? this.style,
      startIndex: startIndex ?? this.startIndex,
      id: id,
    );
    list.numId = numId ?? this.numId;
    return list;
  }

  @override
  void accept(DocxVisitor visitor) {}

  @override
  void buildXml(XmlBuilder builder) {
    for (var item in items) {
      item.buildXmlWithStyle(builder, numId ?? 1, style, isOrdered);
    }
  }
}

/// A single item in a list.
class DocxListItem extends DocxNode {
  final List<DocxInline> children;
  final int level;
  final DocxListStyle? overrideStyle;

  const DocxListItem(
    this.children, {
    this.level = 0,
    this.overrideStyle,
    super.id,
  });

  factory DocxListItem.text(String text, {int level = 0}) {
    return DocxListItem([DocxText(text)], level: level);
  }

  factory DocxListItem.rich(
    List<DocxInline> content, {
    int level = 0,
    DocxListStyle? overrideStyle,
  }) {
    return DocxListItem(content, level: level, overrideStyle: overrideStyle);
  }

  DocxListItem copyWith({
    List<DocxInline>? children,
    int? level,
    DocxListStyle? overrideStyle,
  }) {
    return DocxListItem(
      children ?? this.children,
      level: level ?? this.level,
      overrideStyle: overrideStyle ?? this.overrideStyle,
      id: id,
    );
  }

  @override
  void accept(DocxVisitor visitor) {}

  @override
  void buildXml(XmlBuilder builder) {
    buildXmlWithStyle(builder, 1, const DocxListStyle(), false);
  }

  void buildXmlWithStyle(
    XmlBuilder builder,
    int numId,
    DocxListStyle style,
    bool isOrdered,
  ) {
    final effectiveStyle = overrideStyle ?? style;
    final leftIndent = effectiveStyle.indentPerLevel * (level + 1);

    builder.element(
      'w:p',
      nest: () {
        builder.element(
          'w:pPr',
          nest: () {
            builder.element(
              'w:numPr',
              nest: () {
                builder.element(
                  'w:ilvl',
                  nest: () {
                    builder.attribute('w:val', level.toString());
                  },
                );
                builder.element(
                  'w:numId',
                  nest: () {
                    builder.attribute('w:val', numId.toString());
                  },
                );
              },
            );
            // Apply indentation from the effective style
            builder.element(
              'w:ind',
              nest: () {
                builder.attribute('w:left', leftIndent.toString());
                builder.attribute(
                    'w:hanging', effectiveStyle.hangingIndent.toString());
              },
            );
          },
        );
        for (var child in children) {
          child.buildXml(builder);
        }
      },
    );
  }
}
