import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/docx_relationship.dart';
import '../models/docx_style.dart';
import '../models/docx_theme.dart';
import '../models/style_engine.dart';

/// Shared context for all reader components.
///
/// This object provides access to:
/// - The docx archive
/// - Parsed relationships and content types
/// - Resolved styles
/// - Numbering definitions
class ReaderContext {
  final Archive archive;

  /// Document relationships (rId -> relationship)
  final Map<String, DocxRelationship> relationships = {};

  /// Content types (partName -> contentType)
  final Map<String, String> contentTypes = {};

  /// Parsed styles (styleId -> DocxStyle)
  final Map<String, DocxStyle> styles = {};

  /// The styleId of the document's default *paragraph* style — the `w:style`
  /// carrying `w:default="1"` with `w:type="paragraph"` (ISO/IEC 29500
  /// §17.7.4.17). Used for a paragraph with no explicit `w:pStyle`. Defaults to
  /// the conventional `'Normal'`, but a file whose default is named otherwise
  /// (e.g. LibreOffice's `'Standard'`) sets it here so such paragraphs still
  /// inherit their real default style (07-styles.md item 5).
  String defaultParagraphStyleId = 'Normal';

  /// Raw numbering XML for list type detection
  String? numberingXml;

  /// Parsed numbering definitions (numId -> DocxNumberingDef)
  Map<int, DocxNumberingDef> parsedNumberings = {};

  /// Picture bullets (numPicBulletId -> relationship ID for image)
  final Map<int, String> pictureBullets = {};

  /// Relationships from numbering.xml.rels
  final Map<String, DocxRelationship> numberingRelationships = {};

  /// Archive path of the main document part. Per OPC, this is located through
  /// the package root relationships (`_rels/.rels`, type `officeDocument`) —
  /// not assumed — but defaults to the conventional `word/document.xml` until
  /// [setDocumentPart] is called (i.e. when `_rels/.rels` is absent).
  String documentPartPath = 'word/document.xml';

  /// Directory of [documentPartPath] including the trailing slash (`word/`), or
  /// `''` when the part sits at the package root. Every sibling part and every
  /// relationship target resolves relative to this — see [resolveRelative].
  String documentBaseDir = 'word/';

  /// The `_rels/*.rels` companion path for the main document part.
  String get documentRelsPath => relsPathFor(documentPartPath);

  ReaderContext(this.archive);

  /// Records the discovered main document part and derives [documentBaseDir].
  void setDocumentPart(String path) {
    documentPartPath = path;
    final slash = path.lastIndexOf('/');
    documentBaseDir = slash < 0 ? '' : path.substring(0, slash + 1);
  }

  /// Resolves a relationship [target] to an archive path, against
  /// [documentBaseDir]. A `/`-prefixed target is package-absolute; `..`/`.`
  /// segments are collapsed. With the default `word/` base this is identical to
  /// the legacy `word/<target>` join, so standard packages are unaffected.
  ///
  /// INVARIANT: this resolves against the *document* base dir, which is correct
  /// only because every part the reader follows (headers, footers, numbering,
  /// fontTable, media, embedded-object previews) is a sibling of the main
  /// document part and lives in [documentBaseDir]. A relationship belonging to a
  /// part in a *different* directory with its own relative `.rels` (e.g. a chart
  /// referencing `../media/...`) would need its owning-part base dir threaded
  /// in. No such part is read today; revisit this if one is added.
  String resolveRelative(String target) =>
      _resolveAgainst(documentBaseDir, target);

  /// Resolves a relationship [target] against the package root (base `''`),
  /// used for the root `_rels/.rels` (e.g. the `officeDocument` target).
  String resolveFromPackageRoot(String target) => _resolveAgainst('', target);

  /// The `_rels/<file>.rels` path companion to a given part archive path.
  String relsPathFor(String partPath) {
    final slash = partPath.lastIndexOf('/');
    final dir = slash < 0 ? '' : partPath.substring(0, slash + 1);
    final file = slash < 0 ? partPath : partPath.substring(slash + 1);
    return '${dir}_rels/$file.rels';
  }

  /// Resolves a single-instance sibling part by its relationship [type] (the
  /// segment after the last `/`), reading the document relationships Word
  /// itself follows. Falls back to `<baseDir><fallbackName>` when no such
  /// relationship resolves to an existing part. This is the OPC-correct routing
  /// (it tolerates renamed parts like `styles2.xml`) while preserving the
  /// conventional path for the overwhelmingly common case.
  String resolvePartByType(String type, String fallbackName) {
    for (final rel in relationships.values) {
      if (rel.targetMode == 'External') continue;
      if (rel.type == type || rel.type.endsWith('/$type')) {
        final p = resolveRelative(rel.target);
        if (archive.findFile(p) != null) return p;
      }
    }
    return '$documentBaseDir$fallbackName';
  }

  static String _resolveAgainst(String baseDir, String target) {
    final raw = target.startsWith('/') ? target.substring(1) : '$baseDir$target';
    final out = <String>[];
    for (final segment in raw.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (out.isNotEmpty) out.removeLast();
        continue;
      }
      out.add(segment);
    }
    return out.join('/');
  }

  /// Read file content from the archive as a string.
  String? readContent(String path) {
    final file = archive.findFile(path);
    if (file == null) return null;
    return utf8.decode(file.content as List<int>);
  }

  /// Read file content from the archive as bytes.
  Uint8List? readBytes(String path) {
    final file = archive.findFile(path);
    if (file == null) return null;
    return Uint8List.fromList(file.content as List<int>);
  }

  /// Parse XML content from a path.
  XmlDocument? readXml(String path) {
    final content = readContent(path);
    if (content == null) return null;
    try {
      return XmlDocument.parse(content);
    } catch (_) {
      return null;
    }
  }

  /// Get a relationship by rId.
  DocxRelationship? getRelationship(String rId) => relationships[rId];

  /// Default paragraph style from docDefaults
  DocxStyle? defaultParagraphStyle;

  /// Default run style from docDefaults
  DocxStyle? defaultRunStyle;

  DocxStyleResolver? _styleResolver;

  /// The shared style-resolution engine (Part B). Built lazily from the parsed
  /// styles + docDefaults, so the expensive `basedOn` flattening and toggle
  /// resolution happen once per style combo across the whole document.
  ///
  /// INVARIANT: styles.xml/docDefaults must be fully parsed before the first
  /// access (they are — styles are read before the document body). The engine
  /// snapshots [styles]/[defaultParagraphStyle]/[defaultRunStyle] on first use
  /// and is never reset, so a [ReaderContext] is single-document: do not reuse
  /// one across documents. See [DocxStyleResolver].
  DocxStyleResolver get styleResolver => _styleResolver ??= DocxStyleResolver(
        styles: styles,
        docDefaultsParagraph: defaultParagraphStyle,
        docDefaultsRun: defaultRunStyle,
      );

  /// Resolve a style by ID, handling inheritance and defaults.
  DocxStyle resolveStyle(String? styleId) => _resolveStyle(styleId, <String>{});

  /// Internal resolver carrying a [visited] set so a malformed `basedOn` cycle
  /// (e.g. A→B→A) terminates instead of recursing forever.
  DocxStyle _resolveStyle(String? styleId, Set<String> visited) {
    if (styleId == null || !styles.containsKey(styleId)) {
      // Fallback to Normal if available, otherwise defaults
      if (styleId != 'Normal' && styles.containsKey('Normal')) {
        return styles['Normal']!;
      }
      return defaultParagraphStyle ?? DocxStyle.empty();
    }

    final style = styles[styleId]!;
    if (style.basedOn != null &&
        style.basedOn != styleId &&
        !visited.contains(style.basedOn)) {
      visited.add(styleId);
      final parent = _resolveStyle(style.basedOn, visited);
      return parent.merge(style);
    } else {
      // Root style - merge with defaults
      // Styles are either paragraph or character styles.
      // If it's a paragraph style, it should inherit from defaultParagraphStyle.
      // If content rely on this style, it needs the defaults.
      // Ideally, we distinguish style type, but DocxStyle often lacks type info in some contexts.
      // Usually named styles in styles.xml have type.

      // If this is a paragraph style (or unknown), merge on top of docDefaults
      if (style.type == 'paragraph' || style.type == null) {
        if (defaultParagraphStyle != null) {
          return defaultParagraphStyle!.merge(style);
        }
      }
      // Note: Character styles (type == 'character') merge with defaultParagraphFont...
      // strictly speaking, character styles are additive to the paragraph style they are applied to.
      // But if they have no basedOn, they start from "Default Paragraph Font" which is essentially empty or docDefaults.
    }
    return style;
  }
}
