import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../docx_export_state.dart';

class DocxRelationshipsGenerator {
  static ArchiveFile createRootRels(DocxExportState state) {
    if (state.doc.rootRelsXml != null) {
      return ArchiveFile(
        '_rels/.rels',
        utf8.encode(state.doc.rootRelsXml!).length,
        utf8.encode(state.doc.rootRelsXml!),
      );
    }
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships',
        );
        builder.element(
          'Relationship',
          nest: () {
            builder.attribute('Id', 'rId1');
            builder.attribute(
              'Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument',
            );
            builder.attribute('Target', 'word/document.xml');
          },
        );
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      '_rels/.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  static ArchiveFile createDocumentRels(DocxExportState state) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships',
        );
        builder.element('Relationship', nest: () {
          builder.attribute('Id', 'rId1');
          builder.attribute('Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles');
          builder.attribute('Target', 'styles.xml');
        });
        builder.element('Relationship', nest: () {
          builder.attribute('Id', 'rId2');
          builder.attribute('Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings');
          builder.attribute('Target', 'settings.xml');
        });
        builder.element('Relationship', nest: () {
          builder.attribute('Id', 'rId3');
          builder.attribute('Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable');
          builder.attribute('Target', 'fontTable.xml');
        });
        builder.element('Relationship', nest: () {
          builder.attribute('Id', 'rId4');
          builder.attribute('Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering');
          builder.attribute('Target', 'numbering.xml');
        });
        builder.element('Relationship', nest: () {
          builder.attribute('Id', 'rIdTheme');
          builder.attribute('Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme');
          builder.attribute('Target', 'theme/theme1.xml');
        });

        if (state.doc.section?.header != null) {
          builder.element('Relationship', nest: () {
            builder.attribute('Id', 'rId5');
            builder.attribute('Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/header');
            builder.attribute('Target', 'header1.xml');
          });
        }

        if (state.doc.section?.footer != null) {
          builder.element('Relationship', nest: () {
            builder.attribute('Id', 'rId6');
            builder.attribute('Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer');
            builder.attribute('Target', 'footer1.xml');
          });
        }

        if (state.backgroundImage != null) {
          builder.element('Relationship', nest: () {
            builder.attribute('Id', 'rIdBg');
            builder.attribute('Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image');
            final ext = state.backgroundImage!.normalizedExtension;
            builder.attribute('Target', 'media/background.$ext');
          });
          builder.element('Relationship', nest: () {
            builder.attribute('Id', 'rIdBgHdr');
            builder.attribute('Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/header');
            builder.attribute('Target', 'header_bg.xml');
          });
        }

        if ((state.doc.footnotes != null && state.doc.footnotes!.isNotEmpty) ||
            state.doc.footnotesXml != null) {
          builder.element('Relationship', nest: () {
            builder.attribute('Id', 'rIdFootnotes');
            builder.attribute('Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes');
            builder.attribute('Target', 'footnotes.xml');
          });
        }

        if ((state.doc.endnotes != null && state.doc.endnotes!.isNotEmpty) ||
            state.doc.endnotesXml != null) {
          builder.element('Relationship', nest: () {
            builder.attribute('Id', 'rIdEndnotes');
            builder.attribute('Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes');
            builder.attribute('Target', 'endnotes.xml');
          });
        }

        final uniqueBodyImages = <String, dynamic>{};
        for (final img in state.groupedImages['body'] ?? []) {
          if (img.relationshipId != null) {
            uniqueBodyImages[img.relationshipId!] = img;
          }
        }

        for (final img in uniqueBodyImages.values) {
          final relId = img.relationshipId;
          final mediaPath = state.imageMediaPaths[img];
          if (relId != null && mediaPath != null) {
            builder.element('Relationship', nest: () {
              builder.attribute('Id', relId);
              builder.attribute('Type',
                  'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image');
              builder.attribute('Target', mediaPath.replaceFirst('word/', ''));
            });
          }
        }
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/_rels/document.xml.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  static ArchiveFile createFontTableRels(DocxExportState state) {
    if (state.doc.fontTableRelsXml != null) {
      return ArchiveFile(
        'word/_rels/fontTable.xml.rels',
        utf8.encode(state.doc.fontTableRelsXml!).length,
        utf8.encode(state.doc.fontTableRelsXml!),
      );
    }
    final builder = XmlBuilder();
    builder.processing(
        'xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships',
        );

        int i = 0;
        for (final font in state.fontManager.fonts) {
          builder.element(
            'Relationship',
            nest: () {
              builder.attribute('Id', 'rIdFont$i');
              builder.attribute(
                'Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/font',
              );
              builder.attribute('Target', 'fonts/${font.obfuscationKey}.odttf');
            },
          );
          i++;
        }
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/_rels/fontTable.xml.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }
}
