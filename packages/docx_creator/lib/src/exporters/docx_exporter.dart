import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../docx_creator.dart';
import '../core/font_manager.dart';
import '../utils/file_saver.dart';
import 'docx/docx_collection_manager.dart';
import 'docx/docx_export_state.dart';
import 'docx/generators/document_generator.dart';
import 'docx/generators/header_footer_generator.dart';
import 'docx/generators/numbering_generator.dart';
import 'docx/generators/relationships_generator.dart';
import 'docx/generators/styles_generator.dart';

/// Exports [DocxBuiltDocument] to .docx format.
class DocxExporter {
  /// The font manager used to handle embedded fonts during export.
  final FontManager fontManager = FontManager();

  /// ID generator for unique element IDs (available for advanced usage).
  final DocxIdGenerator idGenerator = DocxIdGenerator();

  /// Optional validator for pre-export validation.
  /// If set, the document will be validated before export.
  final DocxValidator? validator;

  /// Creates a DocxExporter.
  ///
  /// Optionally provide a [validator] for pre-export validation.
  DocxExporter({this.validator});

  /// Exports the document to a file.
  Future<void> exportToFile(DocxBuiltDocument doc, String filePath) async {
    try {
      final bytes = await exportToBytes(doc);
      await FileSaver.save(filePath, bytes);
    } catch (e) {
      throw DocxExportException(
        'Failed to write file: $e',
        targetFormat: 'DOCX',
        context: filePath,
      );
    }
  }

  /// Exports the document to bytes.
  Future<Uint8List> exportToBytes(DocxBuiltDocument doc) async {
    // Run validation if validator is provided
    if (validator != null) {
      final isValid = validator!.validate(doc);
      if (!isValid) {
        throw DocxExportException(
          'Document validation failed: ${validator!.errors.join(", ")}',
          targetFormat: 'DOCX',
        );
      }
    }

    final state = DocxExportState(doc, fontManager, idGenerator);
    DocxCollectionManager.collect(state);

    final archive = Archive();

    archive.addFile(_createContentTypes(state));
    archive.addFile(DocxRelationshipsGenerator.createRootRels(state));
    archive.addFile(DocxDocumentGenerator.generate(state));
    archive.addFile(DocxRelationshipsGenerator.createDocumentRels(state));
    archive.addFile(DocxStylesGenerator.createSettings(state));
    archive.addFile(DocxStylesGenerator.createStyles(state));
    archive.addFile(DocxStylesGenerator.createFontTable(state));
    archive.addFile(DocxRelationshipsGenerator.createFontTableRels(state));
    archive.addFile(DocxStylesGenerator.createTheme(state));

    archive.addFile(DocxNumberingGenerator.createNumbering(state));

    if (state.imageBullets.isNotEmpty || state.doc.numberingRelsXml != null) {
      archive.addFile(DocxNumberingGenerator.createNumberingRels(state));

      for (int i = 0; i < state.imageBullets.length; i++) {
        final filename = 'word/media/imageBullet$i.png';
        archive.addFile(ArchiveFile(
            filename, state.imageBullets[i].length, state.imageBullets[i]));
      }

      if (state.doc.numberingImages.isNotEmpty) {
        state.doc.numberingImages.forEach((target, bytes) {
          final filename =
              target.startsWith('/') ? target.substring(1) : 'word/$target';
          archive.addFile(ArchiveFile(filename, bytes.length, bytes));
        });
      }
    }

    // Process fonts
    for (final font in state.fontManager.fonts) {
      final filename = font.preservedFilename != null
          ? 'word/${font.preservedFilename}'
          : 'word/fonts/${font.obfuscationKey}.odttf';
      archive.addFile(ArchiveFile(
          filename, font.obfuscatedBytes.length, font.obfuscatedBytes));
    }

    // Headers and Footers
    if (state.doc.section?.header != null) {
      archive.addFile(DocxHeaderFooterGenerator.createHeader(state));
      if (state.groupedImages['header']!.isNotEmpty) {
        archive.addFile(DocxHeaderFooterGenerator.createHeaderRels(state));
      }
    }

    if (state.doc.section?.footer != null) {
      archive.addFile(DocxHeaderFooterGenerator.createFooter(state));
      if (state.groupedImages['footer']!.isNotEmpty) {
        archive.addFile(DocxHeaderFooterGenerator.createFooterRels(state));
      }
    }

    // Background header (for background image)
    if (state.backgroundImage != null) {
      archive.addFile(DocxHeaderFooterGenerator.createBackgroundHeader(state));
      archive
          .addFile(DocxHeaderFooterGenerator.createBackgroundHeaderRels(state));
    }

    // Footnotes and Endnotes
    if (state.doc.footnotes != null && state.doc.footnotes!.isNotEmpty) {
      archive.addFile(DocxHeaderFooterGenerator.createFootnotes(state));
    } else if (state.doc.footnotesXml != null) {
      archive.addFile(ArchiveFile(
          'word/footnotes.xml',
          utf8.encode(state.doc.footnotesXml!).length,
          utf8.encode(state.doc.footnotesXml!)));
    }

    if (state.doc.endnotes != null && state.doc.endnotes!.isNotEmpty) {
      archive.addFile(DocxHeaderFooterGenerator.createEndnotes(state));
    } else if (state.doc.endnotesXml != null) {
      archive.addFile(ArchiveFile(
          'word/endnotes.xml',
          utf8.encode(state.doc.endnotesXml!).length,
          utf8.encode(state.doc.endnotesXml!)));
    }

    // Images
    for (final entry in state.images.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }

    final encoder = ZipEncoder();
    final bytes = encoder.encode(archive);
    // ignore: unnecessary_null_comparison
    if (bytes == null || bytes.isEmpty) {
      throw DocxExportException('Failed to encode ZIP', targetFormat: 'DOCX');
    }

    return Uint8List.fromList(bytes);
  }

  ArchiveFile _createContentTypes(DocxExportState state) {
    if (state.doc.contentTypesXml != null) {
      return ArchiveFile(
        '[Content_Types].xml',
        utf8.encode(state.doc.contentTypesXml!).length,
        utf8.encode(state.doc.contentTypesXml!),
      );
    }

    final generator = ContentTypesGenerator();

    generator.registerPart('/word/document.xml',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml');
    generator.registerPart('/word/styles.xml',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml');
    generator.registerPart('/word/settings.xml',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml');
    generator.registerPart('/word/fontTable.xml',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml');
    generator.registerPart('/word/numbering.xml',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml');
    generator.registerPart('/word/theme/theme1.xml',
        'application/vnd.openxmlformats-officedocument.theme+xml');

    if (state.doc.footnotesXml != null ||
        (state.doc.footnotes?.isNotEmpty ?? false)) {
      generator.registerPart('/word/footnotes.xml',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml');
    }
    if (state.doc.endnotesXml != null ||
        (state.doc.endnotes?.isNotEmpty ?? false)) {
      generator.registerPart('/word/endnotes.xml',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.endnotes+xml');
    }

    if (state.doc.section?.header != null) {
      generator.registerHeader('header1.xml');
    }
    if (state.doc.section?.footer != null) {
      generator.registerFooter('footer1.xml');
    }

    if (state.backgroundImage != null) {
      generator.registerHeader('header_bg.xml');
    }

    for (int i = 0; i < state.images.length; i++) {
      final key = state.images.keys.elementAt(i);
      final ext = key.split('.').last.toLowerCase();
      final contentType = 'image/${ext == "jpg" ? "jpeg" : ext}';
      generator.registerExtension(ext, contentType);
    }

    if (state.imageBullets.isNotEmpty) {
      generator.registerExtension('png', 'image/png');
    }

    if (state.doc.numberingImages.isNotEmpty) {
      for (var key in state.doc.numberingImages.keys) {
        final ext = key.split('.').last.toLowerCase();
        final contentType = 'image/${ext == "jpg" ? "jpeg" : ext}';
        generator.registerExtension(ext, contentType);
      }
    }

    final xml = generator.generate();
    return ArchiveFile(
      '[Content_Types].xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }
}
