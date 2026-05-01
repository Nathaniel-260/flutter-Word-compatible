import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:xml/xml.dart';

import '../docx_export_state.dart';

class DocxHeaderFooterGenerator {
  static ArchiveFile createHeader(DocxExportState state) {
    final builder = XmlBuilder();
    builder.processing(
        'xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    builder.element(
      'w:hdr',
      nest: () {
        builder.attribute('xmlns:w',
            'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
        builder.attribute('xmlns:r',
            'http://schemas.openxmlformats.org/officeDocument/2006/relationships');
        builder.attribute('xmlns:wp',
            'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing');
        builder.attribute(
            'xmlns:a', 'http://schemas.openxmlformats.org/drawingml/2006/main');
        builder.attribute('xmlns:pic',
            'http://schemas.openxmlformats.org/drawingml/2006/picture');
        builder.attribute('xmlns:mc',
            'http://schemas.openxmlformats.org/markup-compatibility/2006');
        builder.attribute('xmlns:w14',
            'http://schemas.microsoft.com/office/word/2010/wordml');
        builder.attribute('xmlns:wp14',
            'http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing');
        builder.attribute('mc:Ignorable', 'w14 wp14');
        (state.doc.section!.header as DocxNode).buildXml(builder);
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/header1.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  static ArchiveFile createFooter(DocxExportState state) {
    final builder = XmlBuilder();
    builder.processing(
        'xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    builder.element(
      'w:ftr',
      nest: () {
        builder.attribute('xmlns:w',
            'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
        builder.attribute('xmlns:r',
            'http://schemas.openxmlformats.org/officeDocument/2006/relationships');
        builder.attribute('xmlns:wp',
            'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing');
        builder.attribute(
            'xmlns:a', 'http://schemas.openxmlformats.org/drawingml/2006/main');
        builder.attribute('xmlns:pic',
            'http://schemas.openxmlformats.org/drawingml/2006/picture');
        builder.attribute('xmlns:mc',
            'http://schemas.openxmlformats.org/markup-compatibility/2006');
        builder.attribute('xmlns:w14',
            'http://schemas.microsoft.com/office/word/2010/wordml');
        builder.attribute('xmlns:wp14',
            'http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing');
        builder.attribute('mc:Ignorable', 'w14 wp14');
        (state.doc.section!.footer as DocxNode).buildXml(builder);
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/footer1.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  static ArchiveFile createHeaderRels(DocxExportState state) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('Relationships', nest: () {
      builder.attribute('xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships');
      final uniqueHeaderImages = <String, DocxInlineImage>{};
      for (final img in state.groupedImages['header'] ?? []) {
        if (img.relationshipId != null) {
          uniqueHeaderImages[img.relationshipId!] = img;
        }
      }
      for (final img in uniqueHeaderImages.values) {
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
    });
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/_rels/header1.xml.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  static ArchiveFile createFooterRels(DocxExportState state) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('Relationships', nest: () {
      builder.attribute('xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships');
      final uniqueFooterImages = <String, DocxInlineImage>{};
      for (final img in state.groupedImages['footer'] ?? []) {
        if (img.relationshipId != null) {
          uniqueFooterImages[img.relationshipId!] = img;
        }
      }
      for (final img in uniqueFooterImages.values) {
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
    });
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/_rels/footer1.xml.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  static ArchiveFile createBackgroundHeader(DocxExportState state) {
    if (state.doc.headerBgXml != null) {
      return ArchiveFile(
        'word/header_bg.xml',
        utf8.encode(state.doc.headerBgXml!).length,
        utf8.encode(state.doc.headerBgXml!),
      );
    }
    final builder = XmlBuilder();
    builder.processing(
        'xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    builder.element(
      'w:hdr',
      nest: () {
        builder.attribute('xmlns:w',
            'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
        builder.attribute('xmlns:wp',
            'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing');
        builder.attribute('xmlns:r',
            'http://schemas.openxmlformats.org/officeDocument/2006/relationships');
        builder.attribute(
            'xmlns:a', 'http://schemas.openxmlformats.org/drawingml/2006/main');
        builder.attribute('xmlns:pic',
            'http://schemas.openxmlformats.org/drawingml/2006/picture');
        builder.attribute('xmlns:mc',
            'http://schemas.openxmlformats.org/markup-compatibility/2006');
        builder.attribute('xmlns:w14',
            'http://schemas.microsoft.com/office/word/2010/wordml');
        builder.attribute('xmlns:wp14',
            'http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing');
        builder.attribute('mc:Ignorable', 'w14 wp14');

        _buildBackgroundImageParagraph(builder, state);
      },
    );

    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/header_bg.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  static ArchiveFile createBackgroundHeaderRels(DocxExportState state) {
    if (state.doc.headerBgRelsXml != null) {
      return ArchiveFile(
        'word/_rels/header_bg.xml.rels',
        utf8.encode(state.doc.headerBgRelsXml!).length,
        utf8.encode(state.doc.headerBgRelsXml!),
      );
    }
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute('xmlns',
            'http://schemas.openxmlformats.org/package/2006/relationships');
        builder.element('Relationship', nest: () {
          builder.attribute('Id', 'rIdBg');
          builder.attribute('Type',
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image');
          final ext = state.backgroundImage!.normalizedExtension;
          builder.attribute('Target', 'media/background.$ext');
        });
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/_rels/header_bg.xml.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  static void _buildBackgroundImageParagraph(
      XmlBuilder builder, DocxExportState state) {
    if (state.backgroundImage == null) return;

    int pageWidthEmu = 7772400; // 8.5 inches default
    int pageHeightEmu = 10058400; // 11 inches default

    final section = state.doc.section;
    if (section != null) {
      final isLandscape = section.orientation == DocxPageOrientation.landscape;
      final cw = isLandscape ? section.effectiveHeight : section.effectiveWidth;
      final ch = isLandscape ? section.effectiveWidth : section.effectiveHeight;
      // Convert twips to EMUs (1 twip = 635 EMUs)
      pageWidthEmu = cw * 635;
      pageHeightEmu = ch * 635;
    }

    builder.element(
      'w:p',
      nest: () {
        builder.element(
          'w:r',
          nest: () {
            builder.element(
              'w:drawing',
              nest: () {
                builder.element(
                  'wp:anchor',
                  nest: () {
                    builder.attribute('behindDoc', '1');
                    builder.attribute('distT', '0');
                    builder.attribute('distB', '0');
                    builder.attribute('distL', '0');
                    builder.attribute('distR', '0');
                    builder.attribute('simplePos', '0');
                    builder.attribute('relativeHeight', '251658240');
                    builder.attribute('locked', '1');
                    builder.attribute('layoutInCell', '0');
                    builder.attribute('allowOverlap', '1');

                    builder.element('wp:simplePos', nest: () {
                      builder.attribute('x', '0');
                      builder.attribute('y', '0');
                    });

                    builder.element('wp:positionH', nest: () {
                      builder.attribute('relativeFrom', 'page');
                      builder.element('wp:posOffset', nest: () {
                        builder.text('0');
                      });
                    });

                    builder.element('wp:positionV', nest: () {
                      builder.attribute('relativeFrom', 'page');
                      builder.element('wp:posOffset', nest: () {
                        builder.text('0');
                      });
                    });

                    builder.element('wp:extent', nest: () {
                      builder.attribute('cx', pageWidthEmu.toString());
                      builder.attribute('cy', pageHeightEmu.toString());
                    });

                    builder.element('wp:effectExtent', nest: () {
                      builder.attribute('l', '0');
                      builder.attribute('t', '0');
                      builder.attribute('r', '0');
                      builder.attribute('b', '0');
                    });

                    builder.element('wp:wrapNone');

                    builder.element('wp:docPr', nest: () {
                      builder.attribute('id', '1');
                      builder.attribute('name', 'Background Image');
                      builder.attribute('descr', 'Page background image');
                    });

                    builder.element('wp:cNvGraphicFramePr', nest: () {
                      builder.element('a:graphicFrameLocks', nest: () {
                        builder.attribute('xmlns:a',
                            'http://schemas.openxmlformats.org/drawingml/2006/main');
                        builder.attribute('noChangeAspect', '1');
                      });
                    });

                    builder.element('a:graphic', nest: () {
                      builder.attribute('xmlns:a',
                          'http://schemas.openxmlformats.org/drawingml/2006/main');
                      builder.element('a:graphicData', nest: () {
                        builder.attribute('uri',
                            'http://schemas.openxmlformats.org/drawingml/2006/picture');
                        builder.element('pic:pic', nest: () {
                          builder.attribute('xmlns:pic',
                              'http://schemas.openxmlformats.org/drawingml/2006/picture');

                          builder.element('pic:nvPicPr', nest: () {
                            builder.element('pic:cNvPr', nest: () {
                              builder.attribute('id', '0');
                              builder.attribute('name',
                                  'background.${state.backgroundImage!.normalizedExtension}');
                            });
                            builder.element('pic:cNvPicPr');
                          });

                          builder.element('pic:blipFill', nest: () {
                            builder.element('a:blip', nest: () {
                              builder.attribute('r:embed',
                                  state.backgroundImage!.relationshipId!);
                              if (state.backgroundImage!.opacity < 1.0) {
                                builder.element('a:alphaModFix', nest: () {
                                  final amt =
                                      (state.backgroundImage!.opacity * 100000)
                                          .toInt();
                                  builder.attribute('amt', amt.toString());
                                });
                              }
                            });
                            builder.element('a:stretch', nest: () {
                              builder.element('a:fillRect');
                            });
                          });

                          builder.element('pic:spPr', nest: () {
                            builder.element('a:xfrm', nest: () {
                              builder.element('a:off', nest: () {
                                builder.attribute('x', '0');
                                builder.attribute('y', '0');
                              });
                              builder.element('a:ext', nest: () {
                                builder.attribute(
                                    'cx', pageWidthEmu.toString());
                                builder.attribute(
                                    'cy', pageHeightEmu.toString());
                              });
                            });
                            builder.element('a:prstGeom', nest: () {
                              builder.attribute('prst', 'rect');
                              builder.element('a:avLst');
                            });
                          });
                        });
                      });
                    });
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  static ArchiveFile createFootnotes(DocxExportState state) {
    final builder = XmlBuilder();
    builder.processing(
        'xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    builder.element(
      'w:footnotes',
      nest: () {
        builder.attribute('xmlns:w',
            'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
        for (final note in state.doc.footnotes!) {
          note.buildXml(builder);
        }
      },
    );

    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/footnotes.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  static ArchiveFile createEndnotes(DocxExportState state) {
    final builder = XmlBuilder();
    builder.processing(
        'xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    builder.element(
      'w:endnotes',
      nest: () {
        builder.attribute('xmlns:w',
            'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
        for (final note in state.doc.endnotes!) {
          note.buildXml(builder);
        }
      },
    );

    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/endnotes.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }
}
