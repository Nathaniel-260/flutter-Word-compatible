import 'dart:typed_data';
import 'package:docx_creator/docx_creator.dart';
import '../../core/font_manager.dart';

/// Holds the configuration and generated state for a single DOCX export pass.
/// This prevents having to pass dozens of arguments or create a monolithic God object.
class DocxExportState {
  final DocxBuiltDocument doc;

  /// The font manager used to handle embedded fonts during export.
  final FontManager fontManager;

  /// ID generator for unique element IDs.
  final DocxIdGenerator idGenerator;

  // -------------------------------------------------------------
  // Image State
  // -------------------------------------------------------------

  /// Map of image paths to bytes for inclusion in the DOCX archive.
  final Map<String, Uint8List> images = {};

  /// Counter for naming image files.
  int imageCounter = 0;

  /// Counter for generating unique rIds.
  int uniqueIdCounter = 1;

  /// Tracks the media path for inline images.
  final Map<DocxInlineImage, String> imageMediaPaths = {};

  /// References the background image (if any).
  DocxBackgroundImage? backgroundImage;

  /// Images grouped by where they appear (body, header, footer).
  Map<String, List<DocxInlineImage>> groupedImages = {
    'body': [],
    'header': [],
    'footer': [],
  };

  // -------------------------------------------------------------
  // Numbering / Bullet State
  // -------------------------------------------------------------

  /// Counter for exported numIds.
  int numIdCounter = 1;

  final List<Uint8List> imageBullets = [];

  /// Mapping of numId -> abstractNumId.
  final Map<int, int> listAbstractNumMap = {};

  /// Mapping of abstractNumId -> imageBulletIndex.
  final Map<int, int> abstractNumImageBulletMap = {};

  /// Mapping of sourceNumId -> exportedNumId.
  final Map<int, int> preservedNumIds = {};

  /// Mapping of exportedNumId -> startIndex.
  final Map<int, int> listStartOverrides = {};

  // -------------------------------------------------------------
  // Hyperlink State
  // -------------------------------------------------------------

  /// Map of href URL -> relationship ID for all hyperlinks in the document.
  final Map<String, String> hyperlinkRelIds = {};

  // -------------------------------------------------------------
  // Custom List Style State
  // -------------------------------------------------------------

  /// Styles for custom abstract numbering definitions (abstractNumId -> style).
  final Map<int, DocxListStyle> customAbstractStyles = {};

  /// Whether the custom abstract num is for an ordered list.
  final Map<int, bool> customAbstractIsOrdered = {};

  /// Per-level styles for "mixed" lists (abstractNumId -> 9 level styles).
  ///
  /// Used when a single [DocxList] mixes ordered and unordered nesting (e.g. a
  /// numbered list inside a bulleted one). Each entry holds the fully resolved
  /// style for levels 0..8; a level whose `numberFormat` is
  /// [DocxNumberFormat.bullet] is rendered as a bullet, otherwise as that
  /// ordered format.
  final Map<int, List<DocxListStyle>> mixedAbstractLevelStyles = {};

  DocxExportState(this.doc, this.fontManager, this.idGenerator);
}
