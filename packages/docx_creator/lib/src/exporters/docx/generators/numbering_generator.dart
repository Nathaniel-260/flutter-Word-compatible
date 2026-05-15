import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:docx_creator/docx_creator.dart';
import 'package:xml/xml.dart';

import '../docx_export_state.dart';

class DocxNumberingGenerator {
  static ArchiveFile createNumbering(DocxExportState state) {
    if (state.doc.numberingXml != null) {
      return ArchiveFile(
        'word/numbering.xml',
        utf8.encode(state.doc.numberingXml!).length,
        utf8.encode(state.doc.numberingXml!),
      );
    }
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln(
      '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:v="urn:schemas-microsoft-com:vml" '
      'xmlns:o="urn:schemas-microsoft-com:office:office" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:w10="urn:schemas-microsoft-com:office:word" '
      'xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml">',
    );

    // Bullet characters for each level
    const bulletChars = ['•', '○', '▪', '•', '○', '▪', '•', '○', '▪'];

    // Image Bullets definitions
    const vmlShapetype =
        '<v:shapetype id="_x0000_t75" coordsize="21600,21600" o:spt="75" o:preferrelative="t" path="m@4@5l@4@11@9@11@9@5xe" filled="f" stroked="f">'
        '<v:stroke joinstyle="miter"/>'
        '<v:formulas>'
        '<v:f eqn="if lineDrawn pixelLineWidth 0"/>'
        '<v:f eqn="sum @0 1 0"/>'
        '<v:f eqn="sum 0 0 @1"/>'
        '<v:f eqn="prod @2 1 2"/>'
        '<v:f eqn="prod @3 21600 pixelWidth"/>'
        '<v:f eqn="prod @3 21600 pixelHeight"/>'
        '<v:f eqn="sum @0 0 1"/>'
        '<v:f eqn="prod @6 1 2"/>'
        '<v:f eqn="prod @7 21600 pixelWidth"/>'
        '<v:f eqn="sum @8 21600 0"/>'
        '<v:f eqn="prod @7 21600 pixelHeight"/>'
        '<v:f eqn="sum @10 21600 0"/>'
        '</v:formulas>'
        '<v:path o:extrusionok="f" gradientshapeok="t" o:connecttype="rect"/>'
        '<o:lock v:ext="edit" aspectratio="t"/>'
        '</v:shapetype>';

    for (int i = 0; i < state.imageBullets.length; i++) {
      buffer.writeln('  <w:numPicBullet w:numPicBulletId="$i">');
      buffer.writeln('    <w:pict>');
      if (i == 0) buffer.writeln(vmlShapetype);
      buffer.writeln(
          '      <v:shape id="_x0000_i102$i" type="#_x0000_t75" style="width:9pt;height:9pt" o:bullet="t">');
      buffer.writeln('      <v:imagedata r:id="rIdImgBullet$i" o:title=""/>');
      buffer.writeln('    </v:shape></w:pict>');
      buffer.writeln('  </w:numPicBullet>');
    }

    // Abstract numbering for bullets (abstractNumId=0) - 9 levels
    buffer.writeln('  <w:abstractNum w:abstractNumId="0">');
    buffer.writeln('    <w:nsid w:val="FFFFFF89"/>');
    buffer.writeln('    <w:multiLevelType w:val="hybridMultilevel"/>');
    buffer.writeln('    <w:tmpl w:val="29761A62"/>');

    for (int lvl = 0; lvl < 9; lvl++) {
      final indent = (lvl + 1) * 720;
      final bullet = bulletChars[lvl];
      buffer.writeln('''
    <w:lvl w:ilvl="$lvl">
      <w:start w:val="1"/>
      <w:numFmt w:val="bullet"/>
      <w:lvlText w:val="$bullet"/>
      <w:lvlJc w:val="left"/>
      <w:pPr>
        <w:tabs><w:tab w:val="num" w:pos="$indent"/></w:tabs>
        <w:ind w:left="$indent" w:hanging="360"/>
      </w:pPr>
      <w:rPr>
        <w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/>
      </w:rPr>
    </w:lvl>''');
    }
    buffer.writeln('  </w:abstractNum>');

    // Number formats for each level of ordered lists
    const numFormats = [
      'decimal', // 1, 2, 3
      'lowerLetter', // a, b, c
      'lowerRoman', // i, ii, iii
      'decimal', // 1, 2, 3
      'lowerLetter', // a, b, c
      'lowerRoman', // i, ii, iii
      'decimal', // 1, 2, 3
      'lowerLetter', // a, b, c
      'lowerRoman', // i, ii, iii
    ];
    const lvlTextFormats = [
      '%1.',
      '%2.',
      '%3.',
      '%4.',
      '%5.',
      '%6.',
      '%7.',
      '%8.',
      '%9.'
    ];

    // Abstract numbering for decimals (abstractNumId=1) - 9 levels
    buffer.writeln('  <w:abstractNum w:abstractNumId="1">');
    buffer.writeln('    <w:nsid w:val="FFFFFF88"/>');
    buffer.writeln('    <w:multiLevelType w:val="hybridMultilevel"/>');
    buffer.writeln('    <w:tmpl w:val="D0A62B40"/>');

    for (int lvl = 0; lvl < 9; lvl++) {
      final indent = (lvl + 1) * 720;
      final numFmt = numFormats[lvl];
      final lvlText = lvlTextFormats[lvl];
      buffer.writeln('''
    <w:lvl w:ilvl="$lvl">
      <w:start w:val="1"/>
      <w:numFmt w:val="$numFmt"/>
      <w:lvlText w:val="$lvlText"/>
      <w:lvlJc w:val="left"/>
      <w:pPr>
        <w:tabs><w:tab w:val="num" w:pos="$indent"/></w:tabs>
        <w:ind w:left="$indent" w:hanging="360"/>
      </w:pPr>
    </w:lvl>''');
    }
    buffer.writeln('  </w:abstractNum>');

    // Abstract Custom List Styles (non-default bullet chars or number formats)
    state.customAbstractStyles.forEach((absId, style) {
      final isOrdered = state.customAbstractIsOrdered[absId] ?? false;
      buffer.writeln(_buildCustomAbstractNum(absId, style, isOrdered));
    });

    // Abstract Custom Image Bullets
    state.abstractNumImageBulletMap.forEach((absId, bulletIndex) {
      buffer.writeln('  <w:abstractNum w:abstractNumId="$absId">');
      buffer.writeln(
          '    <w:nsid w:val="${(100000 + absId).toRadixString(16)}"/>');
      buffer.writeln('    <w:multiLevelType w:val="hybridMultilevel"/>');

      for (int lvl = 0; lvl < 9; lvl++) {
        final indent = 720 + (lvl * 360);
        buffer.writeln('''
      <w:lvl w:ilvl="$lvl">
        <w:start w:val="1"/>
        <w:numFmt w:val="bullet"/>
        <w:lvlText w:val=""/>
        <w:lvlPicBulletId w:val="$bulletIndex"/>
        <w:lvlJc w:val="left"/>
        <w:pPr>
          <w:tabs><w:tab w:val="num" w:pos="$indent"/></w:tabs>
          <w:ind w:left="$indent" w:hanging="360"/>
        </w:pPr>
        <w:rPr>
          <w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/>
          <w:color w:val="auto"/>
        </w:rPr>
      </w:lvl>''');
      }
      buffer.writeln('  </w:abstractNum>');
    });

    // Generate num instances
    state.listAbstractNumMap.forEach((numId, absId) {
      buffer.write(
        '  <w:num w:numId="$numId"><w:abstractNumId w:val="$absId"/>',
      );
      if (state.listStartOverrides.containsKey(numId)) {
        final start = state.listStartOverrides[numId];
        buffer.write(
          '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="$start"/></w:lvlOverride>',
        );
      }
      buffer.writeln('</w:num>');
    });

    buffer.writeln('</w:numbering>');
    final xml = buffer.toString();
    return ArchiveFile(
      'word/numbering.xml',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }

  static String _numFmtXml(DocxNumberFormat fmt) {
    switch (fmt) {
      case DocxNumberFormat.decimal:
        return 'decimal';
      case DocxNumberFormat.lowerAlpha:
        return 'lowerLetter';
      case DocxNumberFormat.upperAlpha:
        return 'upperLetter';
      case DocxNumberFormat.lowerRoman:
        return 'lowerRoman';
      case DocxNumberFormat.upperRoman:
        return 'upperRoman';
      case DocxNumberFormat.bullet:
        return 'bullet';
    }
  }

  static String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String _buildCustomAbstractNum(
      int absId, DocxListStyle style, bool isOrdered) {
    final buf = StringBuffer();
    buf.writeln('  <w:abstractNum w:abstractNumId="$absId">');
    buf.writeln(
        '    <w:nsid w:val="${(0xFFFF00 + absId).toRadixString(16).padLeft(8, '0').toUpperCase()}"/>');
    buf.writeln('    <w:multiLevelType w:val="hybridMultilevel"/>');

    for (int lvl = 0; lvl < 9; lvl++) {
      final indent = style.indentPerLevel * (lvl + 1);
      final hanging = style.hangingIndent;

      buf.writeln('    <w:lvl w:ilvl="$lvl">');
      buf.writeln('      <w:start w:val="1"/>');

      if (isOrdered) {
        final fmt = _numFmtXml(style.numberFormat);
        final lvlText = '%${lvl + 1}.';
        buf.writeln('      <w:numFmt w:val="$fmt"/>');
        buf.writeln('      <w:lvlText w:val="$lvlText"/>');
      } else {
        buf.writeln('      <w:numFmt w:val="bullet"/>');
        buf.writeln('      <w:lvlText w:val="${_escapeXml(style.bullet)}"/>');
      }

      buf.writeln('      <w:lvlJc w:val="left"/>');
      buf.writeln('      <w:pPr>');
      buf.writeln(
          '        <w:tabs><w:tab w:val="num" w:pos="$indent"/></w:tabs>');
      buf.writeln('        <w:ind w:left="$indent" w:hanging="$hanging"/>');
      buf.writeln('      </w:pPr>');

      // rPr: font family (default to Symbol for bullet chars, Arial otherwise)
      final fontName = style.fontFamily ??
          (isOrdered ? null : _bulletFont(style.bullet));
      buf.writeln('      <w:rPr>');
      if (fontName != null) {
        buf.writeln(
            '        <w:rFonts w:ascii="${_escapeXml(fontName)}" w:hAnsi="${_escapeXml(fontName)}" w:hint="default"/>');
      }
      if (style.fontWeight == DocxFontWeight.bold) {
        buf.writeln('        <w:b/>');
      }
      if (style.color != DocxColor.black) {
        buf.writeln('        <w:color w:val="${style.color.hex}"/>');
      }
      if (style.fontSize != null) {
        final halfPt = (style.fontSize! * 2).toInt();
        buf.writeln('        <w:sz w:val="$halfPt"/>');
        buf.writeln('        <w:szCs w:val="$halfPt"/>');
      }
      buf.writeln('      </w:rPr>');
      buf.writeln('    </w:lvl>');
    }

    buf.writeln('  </w:abstractNum>');
    return buf.toString();
  }

  /// Returns an appropriate font for a given bullet character so Word renders
  /// it correctly. Falls back to the default body font for unknown chars.
  static String? _bulletFont(String bullet) {
    const symbolBullets = {'•', '◦', '▪'};
    const wingdingsBullets = {'➢', '➤', '✓', '✗', '★'};
    if (symbolBullets.contains(bullet)) return 'Symbol';
    if (wingdingsBullets.contains(bullet)) return 'Wingdings';
    return null;
  }

  static ArchiveFile createNumberingRels(DocxExportState state) {
    if (state.doc.numberingRelsXml != null) {
      return ArchiveFile(
        'word/_rels/numbering.xml.rels',
        utf8.encode(state.doc.numberingRelsXml!).length,
        utf8.encode(state.doc.numberingRelsXml!),
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

        for (int i = 0; i < state.imageBullets.length; i++) {
          builder.element(
            'Relationship',
            nest: () {
              builder.attribute('Id', 'rIdImgBullet$i');
              builder.attribute(
                'Type',
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
              );
              builder.attribute('Target', 'media/imageBullet$i.png');
            },
          );
        }
      },
    );
    final xml = builder.buildDocument().toXmlString();
    return ArchiveFile(
      'word/_rels/numbering.xml.rels',
      utf8.encode(xml).length,
      utf8.encode(xml),
    );
  }
}
