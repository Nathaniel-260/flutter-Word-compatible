import 'package:docx_creator/docx_creator.dart';

/// Plan §G — global list numbering.
///
/// The problem this solves (§G.1): list markers used to be computed *per
/// [DocxList]* inside the renderer, so a list that is interrupted by an ordinary
/// paragraph and then continues — or the same `numId` reused in two places, or a
/// list inside a table cell — restarted its counters instead of continuing like
/// Word. [NumberingResolver] makes a **single document-order pass** over every
/// block (recursing into table cells), keeps one counter per `(numId, ilvl)`
/// across [DocxList] boundaries, and produces the final marker string for each
/// numbered item — keyed by item *identity*, never mutating the AST (§2.4.1).
///
/// Each "story" (body, every header/footer variant, every footnote/endnote) is
/// numbered independently with fresh counters, matching Word: a numbered list in
/// a footer does not continue the body's numbering.
///
/// Only lists that carry a `numId` **and** resolved [DocxList.levels] (i.e. lists
/// read from a real DOCX) are handled here; factory-built lists fall back to the
/// renderer's own per-list logic, so existing behaviour is preserved.
class NumberingResolver {
  /// counters[numId][ilvl] = the last value emitted at that level. A level
  /// absent from the inner map has not been seen since its last restart, so the
  /// next item there seeds from the level's `start`.
  final Map<int, Map<int, int>> _counters = {};

  /// The composed marker for each numbered item, by identity.
  final Map<DocxListItem, String> labels = {};

  /// Resolves numbering for the whole [doc]. Returns [labels] for convenience.
  Map<DocxListItem, String> resolveDocument(DocxBuiltDocument doc) {
    // Body + its tables share one numbering story (counters continue across
    // interrupting paragraphs and into cells, like Word).
    _walk(doc.elements);

    // Headers, footers, footnotes and endnotes are independent stories.
    final section = doc.section;
    if (section != null) {
      for (final h in [
        section.header,
        section.firstHeader,
        section.evenHeader,
      ]) {
        if (h != null) _story(h.children);
      }
      for (final f in [
        section.footer,
        section.firstFooter,
        section.evenFooter,
      ]) {
        if (f != null) _story(f.children);
      }
    }
    for (final note in doc.footnotes ?? const <DocxFootnote>[]) {
      _story(note.content);
    }
    for (final note in doc.endnotes ?? const <DocxEndnote>[]) {
      _story(note.content);
    }
    return labels;
  }

  /// Runs [blocks] as a fresh numbering story (independent counters).
  void _story(Iterable<DocxNode> blocks) {
    _counters.clear();
    _walk(blocks);
  }

  /// Walks [blocks] in document order, resolving lists and recursing into table
  /// cells so a list inside a table participates in the same story.
  void _walk(Iterable<DocxNode> blocks) {
    for (final block in blocks) {
      if (block is DocxList) {
        _resolveList(block);
      } else if (block is DocxTable) {
        for (final row in block.rows) {
          for (final cell in row.cells) {
            _walk(cell.children);
          }
        }
      }
    }
  }

  void _resolveList(DocxList list) {
    final numId = list.numId;
    // Only globally tracked lists (real DOCX) are handled; the renderer's
    // per-list fallback covers factory lists and missing definitions.
    if (numId == null || list.levels.isEmpty) return;
    final counters = _counters.putIfAbsent(numId, () => <int, int>{});

    for (final item in list.items) {
      final level = item.level.clamp(0, DocxList.maxLevels - 1);
      final def = list.levelFor(level);

      if (def != null && !_isBulletLevel(def)) {
        // Seed from the level's start on first appearance (or after a restart),
        // otherwise advance. Global counters make continuation fall out for
        // free across interrupting blocks and same-`numId` lists.
        final value =
            counters.containsKey(level) ? counters[level]! + 1 : def.start;
        counters[level] = value;
        labels[item] = composeListLabel(list, def, level, counters);
      }

      // A shallower item restarts deeper levels (Word's default), unless a
      // deeper level's `w:lvlRestart` says otherwise.
      _restartDeeperLevels(list, level, counters);
    }
  }

  /// Removes the counters of levels deeper than [level] so they reseed, honoring
  /// each deeper level's `w:lvlRestart`:
  ///  - null (default): restart whenever any lower-numbered level advances;
  ///  - `0`: never restart;
  ///  - `r` (1-based): restart only when a level with ilvl `< r-1` advances.
  void _restartDeeperLevels(DocxList list, int level, Map<int, int> counters) {
    for (var d = level + 1; d < DocxList.maxLevels; d++) {
      if (!counters.containsKey(d)) continue;
      final r = list.levelFor(d)?.lvlRestart;
      final threshold = r == null ? d : (r - 1);
      if (level < threshold) counters.remove(d);
    }
  }

  static bool _isBulletLevel(DocxListLevel def) =>
      def.numFmtRaw == 'bullet' || def.format == DocxNumberFormat.bullet;
}

/// Composes the marker string for a numbered item at [level], given the live
/// [counters] (ilvl → current value). Shared by [NumberingResolver] (global
/// counters) and the renderer's per-list fallback so both produce identical
/// strings.
///
/// When the level supplies a compound `w:lvlText` (e.g. `%1.%2.%3.`) it is
/// expanded against every referenced ancestor counter — reproducing Word's
/// multilevel / legal numbering. Otherwise a single component is rendered with a
/// trailing period (matching Word's common `%n.` default for simple lists).
String composeListLabel(
  DocxList list,
  DocxListLevel? def,
  int level,
  Map<int, int> counters,
) {
  final template = def?.lvlText;
  if (template != null && template.contains('%')) {
    return expandLvlText(
      template,
      isLgl: def?.isLgl ?? false,
      valueForLevel: (l) => counters[l] ?? (list.levelFor(l)?.start ?? 1),
      defForLevel: list.levelFor,
    );
  }
  final value = counters[level] ?? (def?.start ?? 1);
  if (def != null) {
    if (def.numFmtRaw == 'none') return '';
    final component = formatNumberComponent(
      value,
      rawFmt: def.numFmtRaw,
      fmt: def.format,
      level: level,
    );
    return '$component.';
  }
  // No resolved definition: fall back to the default decimal cascade by depth.
  return orderedMarkerWithCascade(value, level, list.style.numberFormat);
}

/// Expands a `w:lvlText` template, replacing each `%n` with the count of level
/// `n-1`. [valueForLevel] supplies that count and [defForLevel] its definition
/// (for the per-component format). When [isLgl] is true every component renders
/// in decimal (Word's legal numbering).
String expandLvlText(
  String template, {
  required int Function(int level) valueForLevel,
  required DocxListLevel? Function(int level) defForLevel,
  bool isLgl = false,
}) {
  return template.replaceAllMapped(RegExp(r'%(\d)'), (m) {
    final refLevel = int.parse(m.group(1)!) - 1;
    final value = valueForLevel(refLevel);
    if (isLgl) return value.toString();
    final def = defForLevel(refLevel);
    return formatNumberComponent(
      value,
      rawFmt: def?.numFmtRaw,
      fmt: def?.format ?? DocxNumberFormat.decimal,
      level: refLevel,
    );
  });
}

/// Formats a single numbering component (no trailing separator).
///
/// Prefers the raw OOXML format string [rawFmt] when present, so distinctions
/// the coarse [DocxNumberFormat] enum collapses are honored: `hebrew1` gematria
/// vs. `hebrew2` Hebrew-alphabet ordinals, `decimalZero` zero-padding, `ordinal`
/// (1st/2nd), and `none` (empty). English-word formats (`cardinalText`,
/// `ordinalText`) fall back to decimal (§8.2 — out of scope). Falls through to
/// the coarse [fmt] when [rawFmt] is null or unknown (factory-built lists).
String formatNumberComponent(
  int n, {
  String? rawFmt,
  required DocxNumberFormat fmt,
  int level = 0,
}) {
  if (rawFmt != null) {
    switch (rawFmt) {
      case 'decimal':
        return NumberFormatter.decimal(n);
      case 'decimalZero':
        return NumberFormatter.decimalZero(n);
      case 'upperRoman':
        return NumberFormatter.upperRoman(n);
      case 'lowerRoman':
        return NumberFormatter.lowerRoman(n);
      case 'upperLetter':
      case 'upperAlpha':
        return NumberFormatter.upperAlpha(n);
      case 'lowerLetter':
      case 'lowerAlpha':
        return NumberFormatter.lowerAlpha(n);
      case 'hebrew1':
        return NumberFormatter.hebrew(n);
      case 'hebrew2':
        return NumberFormatter.hebrewAlpha(n);
      case 'ordinal':
        return NumberFormatter.ordinal(n);
      case 'cardinalText':
      case 'ordinalText':
        return NumberFormatter.decimal(n); // §8.2: English words unsupported
      case 'none':
        return '';
      // 'bullet' and any unrecognised format fall through to the coarse enum.
    }
  }
  switch (fmt) {
    case DocxNumberFormat.decimal:
      return NumberFormatter.decimal(n);
    case DocxNumberFormat.lowerAlpha:
      return NumberFormatter.lowerAlpha(n);
    case DocxNumberFormat.upperAlpha:
      return NumberFormatter.upperAlpha(n);
    case DocxNumberFormat.lowerRoman:
      return NumberFormatter.lowerRoman(n);
    case DocxNumberFormat.upperRoman:
      return NumberFormatter.upperRoman(n);
    case DocxNumberFormat.hebrew:
      return NumberFormatter.hebrew(n);
    case DocxNumberFormat.bullet:
      return DocxList.bulletForLevel(level);
  }
}

/// Single-component ordered marker for a factory-built list with no resolved
/// definition: the default decimal list cascades by depth (1. → a. → i.) to
/// match Word's standard multilevel list; an explicit format is kept at every
/// level. Used only by the per-list fallback (the resolver always has a [def]).
String orderedMarkerWithCascade(int n, int level, DocxNumberFormat format) {
  final effective = format == DocxNumberFormat.decimal
      ? DocxList.cascadeFormatForLevel(level)
      : format;
  if (effective == DocxNumberFormat.bullet) {
    return DocxList.bulletForLevel(level);
  }
  return '${formatNumberComponent(n, fmt: effective, level: level)}.';
}
