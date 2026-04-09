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

  DocxExportState(this.doc, this.fontManager, this.idGenerator);
}
