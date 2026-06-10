import 'package:xml/xml.dart';

import '../../../../docx_creator.dart';

/// Parses document section properties (page size, margins, headers, footers).
class SectionParser {
  final ReaderContext context;
  final BlockParser blockParser;

  SectionParser(this.context) : blockParser = BlockParser(context);

  /// Parse section properties from document body.
  DocxSectionDef parse(XmlElement body, {DocxColor? backgroundColor}) {
    final sectPr = body.getElement('w:sectPr');

    DocxPageSize pageSize = DocxPageSize.letter;
    DocxPageOrientation orientation = DocxPageOrientation.portrait;
    int? customWidth;
    int? customHeight;
    int marginTop = kDefaultMarginTop;
    int marginBottom = kDefaultMarginBottom;
    int marginLeft = kDefaultMarginLeft;
    int marginRight = kDefaultMarginRight;
    int marginHeader = kDefaultHeaderDistance;
    int marginFooter = kDefaultFooterDistance;
    int gutter = 0;
    DocxHeader? header;
    DocxFooter? footer;
    DocxHeader? firstHeader;
    DocxFooter? firstFooter;
    DocxHeader? evenHeader;
    DocxFooter? evenFooter;
    DocxPageNumberFormat pageNumberFormat = DocxPageNumberFormat.decimal;
    int? pageNumberStart;
    int? chapterStyleLevel;
    DocxChapterSeparator chapterSeparator = DocxChapterSeparator.hyphen;
    bool titlePage = false;
    DocxBackgroundImage? backgroundImage;

    if (sectPr != null) {
      // Page Size
      final pgSz = sectPr.getElement('w:pgSz');
      if (pgSz != null) {
        final w = int.tryParse(pgSz.getAttribute('w:w') ?? '12240') ?? 12240;
        final h = int.tryParse(pgSz.getAttribute('w:h') ?? '15840') ?? 15840;
        final orient = pgSz.getAttribute('w:orient');

        if (orient == 'landscape') {
          orientation = DocxPageOrientation.landscape;
        }

        if ((w == 12240 && h == 15840) || (w == 15840 && h == 12240)) {
          pageSize = DocxPageSize.letter;
        } else if ((w == 11906 && h == 16838) || (w == 16838 && h == 11906)) {
          pageSize = DocxPageSize.a4;
        } else {
          pageSize = DocxPageSize.custom;
          customWidth = w;
          customHeight = h;
        }
      }

      // Margins
      final pgMar = sectPr.getElement('w:pgMar');
      if (pgMar != null) {
        marginTop =
            int.tryParse(pgMar.getAttribute('w:top') ?? '') ?? marginTop;
        marginBottom =
            int.tryParse(pgMar.getAttribute('w:bottom') ?? '') ?? marginBottom;
        marginLeft =
            int.tryParse(pgMar.getAttribute('w:left') ?? '') ?? marginLeft;
        marginRight =
            int.tryParse(pgMar.getAttribute('w:right') ?? '') ?? marginRight;
        // מרחקי header/footer מהקצה + מרווח כריכה — חיוניים למיקום הכותרות
        // באזור השוליים (ולא בתוך הגוף) ולמרווח הכריכה.
        marginHeader =
            int.tryParse(pgMar.getAttribute('w:header') ?? '') ?? marginHeader;
        marginFooter =
            int.tryParse(pgMar.getAttribute('w:footer') ?? '') ?? marginFooter;
        gutter = int.tryParse(pgMar.getAttribute('w:gutter') ?? '') ?? gutter;
      }

      // Headers — keep each variant (default/first/even) so the viewer can pick
      // the right one per page.
      for (var headerRef in sectPr.findAllElements('w:headerReference')) {
        final rId = headerRef.getAttribute('r:id');
        final type = headerRef.getAttribute('w:type') ?? 'default';
        if (rId == null) continue;
        if (_isBackgroundHeader(rId)) {
          backgroundImage = _readBackgroundImage(rId);
          continue;
        }
        final rel = context.getRelationship(rId);
        if (rel == null) continue;
        final parsed = _readHeader(rel);
        switch (type) {
          case 'first':
            firstHeader = parsed;
            break;
          case 'even':
            evenHeader = parsed;
            break;
          default:
            header = parsed;
        }
      }

      // Footers
      for (var footerRef in sectPr.findAllElements('w:footerReference')) {
        final rId = footerRef.getAttribute('r:id');
        final type = footerRef.getAttribute('w:type') ?? 'default';
        if (rId == null) continue;
        final rel = context.getRelationship(rId);
        if (rel == null) continue;
        final parsed = _readFooter(rel);
        switch (type) {
          case 'first':
            firstFooter = parsed;
            break;
          case 'even':
            evenFooter = parsed;
            break;
          default:
            footer = parsed;
        }
      }

      // Different-first-page flag (honors an explicit w:val="false").
      titlePage = readOnOff(sectPr.getElement('w:titlePg'));

      // Page numbering type/format/start/chapter.
      final pgNumType = sectPr.getElement('w:pgNumType');
      if (pgNumType != null) {
        pageNumberFormat =
            mapPageNumberFormat(pgNumType.getAttribute('w:fmt')) ??
                pageNumberFormat;
        pageNumberStart = int.tryParse(pgNumType.getAttribute('w:start') ?? '');
        chapterStyleLevel =
            int.tryParse(pgNumType.getAttribute('w:chapStyle') ?? '');
        chapterSeparator =
            mapChapterSeparator(pgNumType.getAttribute('w:chapSep')) ??
                chapterSeparator;
      }
    }

    return DocxSectionDef(
      pageSize: pageSize,
      orientation: orientation,
      customWidth: customWidth,
      customHeight: customHeight,
      marginTop: marginTop,
      marginBottom: marginBottom,
      marginLeft: marginLeft,
      marginRight: marginRight,
      marginHeader: marginHeader,
      marginFooter: marginFooter,
      gutter: gutter,
      header: header,
      footer: footer,
      firstHeader: firstHeader,
      firstFooter: firstFooter,
      evenHeader: evenHeader,
      evenFooter: evenFooter,
      pageNumberFormat: pageNumberFormat,
      pageNumberStart: pageNumberStart,
      chapterStyleLevel: chapterStyleLevel,
      chapterSeparator: chapterSeparator,
      titlePage: titlePage,
      backgroundColor: backgroundColor,
      backgroundImage: backgroundImage,
    );
  }

  /// Maps a `w:pgNumType w:fmt` value to [DocxPageNumberFormat], or null when
  /// absent/unrecognized (caller keeps the default). Exposed for testing.
  static DocxPageNumberFormat? mapPageNumberFormat(String? fmt) {
    switch (fmt) {
      case 'decimal':
        return DocxPageNumberFormat.decimal;
      case 'upperRoman':
        return DocxPageNumberFormat.upperRoman;
      case 'lowerRoman':
        return DocxPageNumberFormat.lowerRoman;
      case 'upperLetter':
        return DocxPageNumberFormat.upperLetter;
      case 'lowerLetter':
        return DocxPageNumberFormat.lowerLetter;
      default:
        return null;
    }
  }

  /// Maps a `w:pgNumType w:chapSep` value to [DocxChapterSeparator], or null
  /// when absent/unrecognized. Exposed for testing.
  static DocxChapterSeparator? mapChapterSeparator(String? sep) {
    switch (sep) {
      case 'hyphen':
        return DocxChapterSeparator.hyphen;
      case 'period':
        return DocxChapterSeparator.period;
      case 'colon':
        return DocxChapterSeparator.colon;
      case 'emDash':
        return DocxChapterSeparator.emDash;
      case 'enDash':
        return DocxChapterSeparator.enDash;
      default:
        return null;
    }
  }

  bool _isBackgroundHeader(String rId) {
    return rId == 'rIdBgHdr';
  }

  DocxBackgroundImage? _readBackgroundImage(String rId) {
    final rel = context.getRelationship(rId);
    if (rel == null) return null;

    String target = rel.target;
    if (!target.startsWith('/')) target = 'word/$target';

    final xmlContent = context.readContent(target);
    if (xmlContent == null) return null;

    try {
      final xml = XmlDocument.parse(xmlContent);
      final blip = xml.findAllElements('a:blip').firstOrNull;
      if (blip != null) {
        final embedId = blip.getAttribute('r:embed');
        if (embedId != null) {
          // Load header relationships
          final headerRelsPath = 'word/_rels/${target.split('/').last}.rels';
          final relsContent = context.readContent(headerRelsPath);
          if (relsContent != null) {
            final relsXml = XmlDocument.parse(relsContent);
            for (var r in relsXml.findAllElements('Relationship')) {
              if (r.getAttribute('Id') == embedId) {
                final imgTarget = r.getAttribute('Target');
                if (imgTarget != null) {
                  String imgPath = imgTarget;
                  if (!imgPath.startsWith('/')) imgPath = 'word/$imgPath';
                  final imageBytes = context.readBytes(imgPath);
                  if (imageBytes != null) {
                    // Determine extension from file path
                    String ext = 'png';
                    if (imgPath.contains('.')) {
                      ext = imgPath.split('.').last.toLowerCase();
                    }
                    return DocxBackgroundImage(
                        bytes: imageBytes, extension: ext);
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  DocxHeader? _readHeader(DocxRelationship rel) {
    String target = rel.target;
    if (!target.startsWith('/')) target = 'word/$target';

    final xmlContent = context.readContent(target);
    if (xmlContent == null) return null;

    try {
      final xml = XmlDocument.parse(xmlContent);
      final body = xml.findAllElements('w:hdr').firstOrNull;
      if (body != null) {
        final elements = blockParser.parseBlocks(body.children);
        return DocxHeader(children: elements.cast<DocxBlock>());
      }
    } catch (_) {}

    return null;
  }

  DocxFooter? _readFooter(DocxRelationship rel) {
    String target = rel.target;
    if (!target.startsWith('/')) target = 'word/$target';

    final xmlContent = context.readContent(target);
    if (xmlContent == null) return null;

    try {
      final xml = XmlDocument.parse(xmlContent);
      final body = xml.findAllElements('w:ftr').firstOrNull;
      if (body != null) {
        final elements = blockParser.parseBlocks(body.children);
        return DocxFooter(children: elements.cast<DocxBlock>());
      }
    } catch (_) {}

    return null;
  }
}
