import 'package:xml/xml.dart';

import '../../../../docx_creator.dart';

/// Represents parsed style properties from styles.xml.
///
/// Combines both paragraph (pPr) and run (rPr) properties into a single
/// object for easier merging and application.
class DocxStyle {
  /// Sentinel id for a sparse "overlay" style — one whose set fields should be
  /// merged onto a base without replacing the base's identity. [merge] keeps the
  /// base id when the overlay carries this id (or [emptyId]). Centralised here so
  /// callers that build overlays (e.g. the style engine) don't hard-code it.
  static const overlayId = 'temp';

  /// Sentinel id used by [DocxStyle.empty]; treated like [overlayId] by [merge].
  static const emptyId = 'empty';

  final String id;
  final String? type;
  final String? basedOn;

  // Paragraph Properties
  final String? pStyleId;
  final DocxAlign? align;
  final String? shadingFill;
  final String? themeFill;
  final String? themeFillTint;
  final String? themeFillShade;
  final int? numId;
  final int? ilvl;
  final int? spacingAfter;
  final int? spacingBefore;
  final int? lineSpacing;
  final String? lineRule; // 'auto', 'exact', 'atLeast'
  final int? indentLeft;
  final int? indentRight;
  final int? indentFirstLine;
  final DocxBorderSide? borderTop;
  final DocxBorderSide? borderBottomSide;
  final DocxBorderSide? borderLeft;
  final DocxBorderSide? borderRight;
  final DocxBorderSide? borderBetween;
  final DocxBorder? borderBottom;

  /// Table-level borders from a table style's `w:tblPr/w:tblBorders` (styles.xml,
  /// e.g. the built-in "Table Grid"). Held as a [DocxTableStyle] so the viewer
  /// can inherit a table's borders from its style when the table has no inline
  /// `w:tblBorders` (Plan §F).
  final DocxTableStyle? tableBorders;

  // Run Properties
  final DocxFontWeight? fontWeight;
  final DocxFontStyle? fontStyle;
  final List<DocxTextDecoration> decorations;

  /// Underline pattern parsed from `w:u w:val` (e.g. double, wave).
  final DocxUnderlineStyle? underlineStyle;

  /// Underline color parsed from `w:u w:color`/`w:themeColor`.
  final DocxColor? underlineColor;
  final DocxColor? color;
  final double? fontSize;
  final DocxFont? fonts;
  String? get fontFamily => fonts?.family;
  final DocxHighlight? highlight;
  final bool? isSuperscript;
  final bool? isSubscript;
  final bool? isAllCaps;
  final bool? isSmallCaps;
  final bool? isDoubleStrike;
  final bool? isOutline;
  final bool? isShadow;
  final bool? isEmboss;
  final bool? isImprint;
  final DocxBorderSide? textBorder; // w:bdr element - border around text
  final double?
      characterSpacing; // w:spacing w:val - character spacing in twips

  // Table Cell Properties (for Table Styles)
  final DocxVerticalAlign? verticalAlign;
  final Map<String, DocxStyle> tableConditionals;

  const DocxStyle({
    required this.id,
    this.type,
    this.basedOn,
    this.pStyleId,
    this.align,
    this.shadingFill,
    this.themeFill,
    this.themeFillTint,
    this.themeFillShade,
    this.numId,
    this.ilvl,
    this.spacingAfter,
    this.spacingBefore,
    this.lineSpacing,
    this.lineRule,
    this.indentLeft,
    this.indentRight,
    this.indentFirstLine,
    this.borderTop,
    this.borderBottomSide,
    this.borderLeft,
    this.borderRight,
    this.borderBetween,
    this.borderBottom,
    this.tableBorders,
    this.fontWeight,
    this.fontStyle,
    this.decorations = const [],
    this.underlineStyle,
    this.underlineColor,
    this.color,
    this.fontSize,
    this.fonts,
    this.highlight,
    this.isSuperscript,
    this.isSubscript,
    this.isAllCaps,
    this.isSmallCaps,
    this.isDoubleStrike,
    this.isOutline,
    this.isShadow,
    this.isEmboss,
    this.isImprint,
    this.textBorder,
    this.characterSpacing,
    this.verticalAlign,
    this.tableConditionals = const {},
  });

  /// Creates an empty style with no properties set.
  factory DocxStyle.empty() => const DocxStyle(id: emptyId);

  /// Parse a style element from styles.xml.
  factory DocxStyle.fromXml(
    String id, {
    String? type,
    String? basedOn,
    XmlElement? pPr,
    XmlElement? rPr,
    XmlElement? tcPr,
    XmlElement? tblPr,
    Map<String, DocxStyle>? tableConditionals,
  }) {
    final pProps = _parseParagraphProperties(pPr);
    final rProps = _parseRunProperties(rPr, tcPr);

    return DocxStyle(
      id: id,
      type: type,
      basedOn: basedOn,
      // P props
      pStyleId: pProps.pStyleId,
      align: pProps.align,
      shadingFill: pProps.shadingFill ?? rProps.shadingFill,
      themeFill: pProps.themeFill ?? rProps.themeFill,
      themeFillTint: pProps.themeFillTint ?? rProps.themeFillTint,
      themeFillShade: pProps.themeFillShade ?? rProps.themeFillShade,
      numId: pProps.numId,
      ilvl: pProps.ilvl,
      spacingAfter: pProps.spacingAfter,
      spacingBefore: pProps.spacingBefore,
      lineSpacing: pProps.lineSpacing,
      lineRule: pProps.lineRule,
      indentLeft: pProps.indentLeft,
      indentRight: pProps.indentRight,
      indentFirstLine: pProps.indentFirstLine,
      borderTop: pProps.borderTop ?? rProps.borderTop,
      borderBottomSide: pProps.borderBottomSide ?? rProps.borderBottomSide,
      borderLeft: pProps.borderLeft ?? rProps.borderLeft,
      borderRight: pProps.borderRight ?? rProps.borderRight,
      borderBetween: pProps.borderBetween,
      borderBottom: pProps.borderBottom,
      tableBorders: _parseTableBorders(tblPr),
      // R Props (merged)
      fontWeight: rProps.fontWeight,
      fontStyle: rProps.fontStyle,
      decorations: rProps.decorations,
      underlineStyle: rProps.underlineStyle,
      underlineColor: rProps.underlineColor,
      color: rProps.color,
      fontSize: rProps.fontSize,
      fonts: rProps.fonts,
      highlight: rProps.highlight,
      isSuperscript: rProps.isSuperscript,
      isSubscript: rProps.isSubscript,
      isAllCaps: rProps.isAllCaps,
      isSmallCaps: rProps.isSmallCaps,
      isDoubleStrike: rProps.isDoubleStrike,
      isOutline: rProps.isOutline,
      isShadow: rProps.isShadow,
      isEmboss: rProps.isEmboss,
      isImprint: rProps.isImprint,
      textBorder: rProps.textBorder,
      // Table Props
      verticalAlign: rProps.verticalAlign,
      tableConditionals: tableConditionals ?? const {},
    );
  }

  /// Merge this style (as base) with override properties from another style.
  DocxStyle merge(DocxStyle other) {
    return DocxStyle(
      id: other.id == overlayId || other.id == emptyId ? id : other.id,
      type: type,
      basedOn: basedOn,
      // P props
      align: other.align ?? align,
      shadingFill: other.shadingFill ?? shadingFill,
      themeFill: other.themeFill ?? themeFill,
      themeFillTint: other.themeFillTint ?? themeFillTint,
      themeFillShade: other.themeFillShade ?? themeFillShade,
      numId: other.numId ?? numId,
      ilvl: other.ilvl ?? ilvl,
      spacingAfter: other.spacingAfter ?? spacingAfter,
      spacingBefore: other.spacingBefore ?? spacingBefore,
      lineSpacing: other.lineSpacing ?? lineSpacing,
      lineRule: other.lineRule ?? lineRule,
      indentLeft: other.indentLeft ?? indentLeft,
      indentRight: other.indentRight ?? indentRight,
      indentFirstLine: other.indentFirstLine ?? indentFirstLine,
      borderTop: other.borderTop ?? borderTop,
      borderBottomSide: other.borderBottomSide ?? borderBottomSide,
      borderLeft: other.borderLeft ?? borderLeft,
      borderRight: other.borderRight ?? borderRight,
      borderBetween: other.borderBetween ?? borderBetween,
      borderBottom: other.borderBottom ?? borderBottom,
      tableBorders: _mergeTableBorders(tableBorders, other.tableBorders),
      // R props
      fontWeight: other.fontWeight ?? fontWeight,
      fontStyle: other.fontStyle ?? fontStyle,
      decorations:
          other.decorations.isNotEmpty ? other.decorations : decorations,
      underlineStyle: other.underlineStyle ?? underlineStyle,
      underlineColor: other.underlineColor ?? underlineColor,
      color: other.color ?? color,
      fontSize: other.fontSize ?? fontSize,
      fonts: fonts?.merge(other.fonts) ?? other.fonts,
      highlight: other.highlight ?? highlight,
      isSuperscript: other.isSuperscript ?? isSuperscript,
      isSubscript: other.isSubscript ?? isSubscript,
      isAllCaps: other.isAllCaps ?? isAllCaps,
      isSmallCaps: other.isSmallCaps ?? isSmallCaps,
      isDoubleStrike: other.isDoubleStrike ?? isDoubleStrike,
      isOutline: other.isOutline ?? isOutline,
      isShadow: other.isShadow ?? isShadow,
      isEmboss: other.isEmboss ?? isEmboss,
      isImprint: other.isImprint ?? isImprint,
      textBorder: other.textBorder ?? textBorder,
      characterSpacing: other.characterSpacing ?? characterSpacing,
      verticalAlign: other.verticalAlign ?? verticalAlign,
      tableConditionals: other.tableConditionals.isNotEmpty
          ? other.tableConditionals
          : tableConditionals,
    );
  }

  /// Parses a table style's `w:tblPr/w:tblBorders` into a [DocxTableStyle]
  /// carrying the six table border sides, or null when absent.
  static DocxTableStyle? _parseTableBorders(XmlElement? tblPr) {
    final tb = tblPr?.getElement('w:tblBorders');
    if (tb == null) return null;
    return DocxTableStyle(
      borderTop: _parseBorderSide(tb.getElement('w:top')),
      borderBottom: _parseBorderSide(tb.getElement('w:bottom')),
      borderLeft: _parseBorderSide(tb.getElement('w:left')),
      borderRight: _parseBorderSide(tb.getElement('w:right')),
      borderInsideH: _parseBorderSide(tb.getElement('w:insideH')),
      borderInsideV: _parseBorderSide(tb.getElement('w:insideV')),
    );
  }

  /// Per-side merge of table borders along a `basedOn` chain ([other] overrides
  /// [base] side by side), so a style inherits the sides its parent defines.
  static DocxTableStyle? _mergeTableBorders(
      DocxTableStyle? base, DocxTableStyle? other) {
    if (base == null) return other;
    if (other == null) return base;
    return base.copyWith(
      borderTop: other.borderTop ?? base.borderTop,
      borderBottom: other.borderBottom ?? base.borderBottom,
      borderLeft: other.borderLeft ?? base.borderLeft,
      borderRight: other.borderRight ?? base.borderRight,
      borderInsideH: other.borderInsideH ?? base.borderInsideH,
      borderInsideV: other.borderInsideV ?? base.borderInsideV,
    );
  }

  // ============================================================
  // PARAGRAPH PROPERTIES PARSER
  // ============================================================

  static DocxStyle _parseParagraphProperties(XmlElement? pPr) {
    if (pPr == null) return const DocxStyle(id: 'temp');

    DocxAlign? align;
    String? shadingFill;
    String? themeFill;
    String? themeFillTint;
    String? themeFillShade;
    int? numId;
    int? ilvl;
    int? spacingAfter;
    int? spacingBefore;
    int? lineSpacing;
    String? lineRule;
    int? indentLeft;
    int? indentRight;
    int? indentFirstLine;
    DocxBorderSide? borderTop;
    DocxBorderSide? borderBottomSide;
    DocxBorderSide? borderLeft;
    DocxBorderSide? borderRight;
    DocxBorderSide? borderBetween;

    // Style ID
    String? styleId;
    final pStyle = pPr.getElement('w:pStyle');
    if (pStyle != null) {
      styleId = pStyle.getAttribute('w:val');
    }

    // Alignment
    final jcElem = pPr.getElement('w:jc');
    if (jcElem != null) {
      final val = jcElem.getAttribute('w:val');
      if (val == 'center') align = DocxAlign.center;
      if (val == 'right' || val == 'end') align = DocxAlign.right;
      if (val == 'both' || val == 'distribute') align = DocxAlign.justify;
      if (val == 'left' || val == 'start') align = DocxAlign.left;
    }

    // Spacing
    final spacingElem = pPr.getElement('w:spacing');
    if (spacingElem != null) {
      final after = spacingElem.getAttribute('w:after');
      if (after != null) spacingAfter = int.tryParse(after);

      final before = spacingElem.getAttribute('w:before');
      if (before != null) spacingBefore = int.tryParse(before);

      final line = spacingElem.getAttribute('w:line');
      if (line != null) lineSpacing = int.tryParse(line);

      final rule = spacingElem.getAttribute('w:lineRule');
      if (rule != null) lineRule = rule;
    }

    // Indentation
    final indElem = pPr.getElement('w:ind');
    if (indElem != null) {
      final left =
          indElem.getAttribute('w:left') ?? indElem.getAttribute('w:start');
      if (left != null) indentLeft = int.tryParse(left);

      final right =
          indElem.getAttribute('w:right') ?? indElem.getAttribute('w:end');
      if (right != null) indentRight = int.tryParse(right);

      final firstLine = indElem.getAttribute('w:firstLine');
      if (firstLine != null) {
        indentFirstLine = int.tryParse(firstLine);
      } else {
        final hanging = indElem.getAttribute('w:hanging');
        if (hanging != null) {
          final hVal = int.tryParse(hanging);
          if (hVal != null) indentFirstLine = -hVal;
        }
      }
    }

    // Shading — collapse the three-part `w:shd` (pattern/fill/colour) to the
    // flat colour Word paints (handles `solid`/pctN, not just `fill`).
    final shdElem = pPr.getElement('w:shd');
    if (shdElem != null) {
      final shd = resolveShdFill(shdElem);
      shadingFill = shd.fill;
      themeFill = shd.themeFill;
      themeFillTint = shd.themeFillTint;
      themeFillShade = shd.themeFillShade;
    }

    // Numbering/Lists
    final numPr = pPr.getElement('w:numPr');
    if (numPr != null) {
      final numIdElem = numPr.getElement('w:numId');
      final ilvlElem = numPr.getElement('w:ilvl');

      if (numIdElem != null) {
        numId = int.tryParse(numIdElem.getAttribute('w:val') ?? '');
      }
      if (ilvlElem != null) {
        ilvl = int.tryParse(ilvlElem.getAttribute('w:val') ?? '');
      }
    }

    // Borders
    final pBdr = pPr.getElement('w:pBdr');
    if (pBdr != null) {
      borderTop = _parseBorderSide(pBdr.getElement('w:top'));
      borderBottomSide = _parseBorderSide(pBdr.getElement('w:bottom'));
      borderLeft = _parseBorderSide(pBdr.getElement('w:left'));
      borderRight = _parseBorderSide(pBdr.getElement('w:right'));
      borderBetween = _parseBorderSide(pBdr.getElement('w:between'));
    }

    return DocxStyle(
      id: 'temp',
      pStyleId: styleId,
      align: align,
      shadingFill: shadingFill,
      themeFill: themeFill,
      themeFillTint: themeFillTint,
      themeFillShade: themeFillShade,
      numId: numId,
      ilvl: ilvl,
      spacingAfter: spacingAfter,
      spacingBefore: spacingBefore,
      lineSpacing: lineSpacing,
      lineRule: lineRule,
      indentLeft: indentLeft,
      indentRight: indentRight,
      indentFirstLine: indentFirstLine,
      borderTop: borderTop,
      borderBottomSide: borderBottomSide,
      borderLeft: borderLeft,
      borderRight: borderRight,
      borderBetween: borderBetween,
    );
  }

  // ============================================================
  // RUN PROPERTIES PARSER
  // ============================================================

  static DocxStyle _parseRunProperties(XmlElement? rPr, XmlElement? tcPr) {
    // rPr may be null while tcPr (cell properties, for table styles) is present,
    // so we must not return early on a null rPr.

    DocxFontWeight? fontWeight;
    DocxFontStyle? fontStyle;
    List<DocxTextDecoration> decorations = [];
    DocxUnderlineStyle? underlineStyle;
    DocxColor? underlineColor;
    DocxColor? color;
    String? shadingFill;
    double? fontSize;
    DocxFont? fonts;
    DocxHighlight? highlight;
    bool? isSuperscript;
    bool? isSubscript;
    bool? isAllCaps;
    bool? isSmallCaps;
    bool? isDoubleStrike;
    bool? isOutline;
    bool? isShadow;
    bool? isEmboss;
    bool? isImprint;
    DocxVerticalAlign? verticalAlign; // Added for tcPr parsing
    DocxBorderSide? borderTop;
    DocxBorderSide? borderBottomSide;
    DocxBorderSide? borderLeft;
    DocxBorderSide? borderRight;

    // Added shading theme props
    String? themeFill;
    String? themeFillTint;
    String? themeFillShade;
    double? characterSpacing;

    if (rPr != null) {
      // Toggles honour w:val: a bare element is on, but w:val="0"/"false"/"off"
      // is an explicit *off* (used by a child style/direct run to switch a
      // toggle back off). Reading val — not mere presence — is required for the
      // style engine's XOR and for direct formatting to disable an inherited
      // toggle. (ISO 29500 §17.3.2; see [readOnOff].)
      final bEl = rPr.getElement('w:b');
      if (bEl != null) {
        fontWeight =
            readOnOff(bEl) ? DocxFontWeight.bold : DocxFontWeight.normal;
      }
      final iEl = rPr.getElement('w:i');
      if (iEl != null) {
        fontStyle =
            readOnOff(iEl) ? DocxFontStyle.italic : DocxFontStyle.normal;
      }
      final uElem = rPr.getElement('w:u');
      if (uElem != null) {
        final val = uElem.getAttribute('w:val');
        final parsedStyle = DocxUnderlineStyleExtension.fromXml(val);
        // `w:val="none"` explicitly disables the underline.
        if (val != 'none' && parsedStyle != DocxUnderlineStyle.none) {
          decorations.add(DocxTextDecoration.underline);
          underlineStyle =
              parsedStyle; // null (unknown token) → treated as single
          final themeColor = uElem.getAttribute('w:themeColor');
          final colorVal = uElem.getAttribute('w:color');
          if ((colorVal != null && colorVal != 'auto') || themeColor != null) {
            underlineColor = DocxColor(
              (colorVal != null && colorVal != 'auto') ? colorVal : 'auto',
              themeColor: themeColor,
              themeTint: uElem.getAttribute('w:themeTint'),
              themeShade: uElem.getAttribute('w:themeShade'),
            );
          }
        }
      }
      final strikeEl = rPr.getElement('w:strike');
      if (strikeEl != null && readOnOff(strikeEl)) {
        decorations.add(DocxTextDecoration.strikethrough);
      }

      final colorElem = rPr.getElement('w:color');
      if (colorElem != null) {
        final val = colorElem.getAttribute('w:val');
        if (val != null) {
          color = DocxColor(
            val,
            themeColor: colorElem.getAttribute('w:themeColor'),
            themeTint: colorElem.getAttribute('w:themeTint'),
            themeShade: colorElem.getAttribute('w:themeShade'),
          );
        }
      }

      final shdElem = rPr.getElement('w:shd');
      if (shdElem != null) {
        final shd = resolveShdFill(shdElem);
        shadingFill = shd.fill;
        themeFill = shd.themeFill;
        themeFillTint = shd.themeFillTint;
        themeFillShade = shd.themeFillShade;
      }

      final spacingElem = rPr.getElement('w:spacing');
      if (spacingElem != null) {
        final val = spacingElem.getAttribute('w:val');
        if (val != null) {
          characterSpacing = int.tryParse(val)?.toDouble();
        }
      }

      final szElem = rPr.getElement('w:sz');
      if (szElem != null) {
        final val = szElem.getAttribute('w:val');
        if (val != null) {
          final halfPoints = int.tryParse(val);
          if (halfPoints != null) fontSize = halfPoints / 2.0;
        }
      }

      final rFonts = rPr.getElement('w:rFonts');
      if (rFonts != null) {
        fonts = DocxFont(
          ascii: rFonts.getAttribute('w:ascii'),
          hAnsi: rFonts.getAttribute('w:hAnsi'),
          cs: rFonts.getAttribute('w:cs'),
          eastAsia: rFonts.getAttribute('w:eastAsia'),
          hint: rFonts.getAttribute('w:hint'),
          asciiTheme: rFonts.getAttribute('w:asciiTheme'),
          hAnsiTheme: rFonts.getAttribute('w:hAnsiTheme'),
          csTheme: rFonts.getAttribute('w:csTheme'),
          eastAsiaTheme: rFonts.getAttribute('w:eastAsiaTheme'),
        );
      }

      final highlightElem = rPr.getElement('w:highlight');
      if (highlightElem != null) {
        final val = highlightElem.getAttribute('w:val');
        if (val != null) {
          for (var h in DocxHighlight.values) {
            if (h.name == val) {
              highlight = h;
              break;
            }
          }
        }
      }

      isAllCaps = _onOff(rPr, 'w:caps');
      isSmallCaps = _onOff(rPr, 'w:smallCaps');
      isDoubleStrike = _onOff(rPr, 'w:dstrike');
      isOutline = _onOff(rPr, 'w:outline');
      isShadow = _onOff(rPr, 'w:shadow');
      isEmboss = _onOff(rPr, 'w:emboss');
      isImprint = _onOff(rPr, 'w:imprint');

      final vertAlignElem = rPr.getElement('w:vertAlign');
      if (vertAlignElem != null) {
        final val = vertAlignElem.getAttribute('w:val');
        if (val == 'superscript') isSuperscript = true;
        if (val == 'subscript') isSubscript = true;
      }
    }

    // Parse text border (w:bdr)
    DocxBorderSide? textBorder;
    final bdr = rPr?.getElement('w:bdr');
    if (bdr != null) {
      textBorder = _parseBorderSide(bdr);
    }

    // Parse Cell Properties
    if (tcPr != null) {
      // Shading (cell shading overrides paragraph shading if present). Resolve
      // the three-part shd to its flat colour so `solid`/pctN styles take effect.
      // This (table-style) path keeps the historical `#` prefix on a plain hex
      // for backward compatibility with the conditional-shading contract.
      final tcShd = tcPr.getElement('w:shd');
      if (tcShd != null) {
        final resolved = resolveShdFill(tcShd);
        final f = resolved.fill;
        if (f != null) {
          shadingFill =
              RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(f) ? '#$f' : f;
        }
        if (resolved.themeFill != null) {
          themeFill = resolved.themeFill;
          themeFillTint = resolved.themeFillTint;
          themeFillShade = resolved.themeFillShade;
        }
      }

      final vAlignElem = tcPr.getElement('w:vAlign');
      if (vAlignElem != null) {
        final val = vAlignElem.getAttribute('w:val');
        if (val == 'top') verticalAlign = DocxVerticalAlign.top;
        if (val == 'center') verticalAlign = DocxVerticalAlign.center;
        if (val == 'bottom') verticalAlign = DocxVerticalAlign.bottom;
      }

      final tcBorders = tcPr.getElement('w:tcBorders');
      if (tcBorders != null) {
        borderTop = _parseBorderSide(tcBorders.getElement('w:top'));
        borderBottomSide = _parseBorderSide(tcBorders.getElement('w:bottom'));
        borderLeft = _parseBorderSide(tcBorders.getElement('w:left'));
        borderRight = _parseBorderSide(tcBorders.getElement('w:right'));
      }
    }

    return DocxStyle(
      id: 'temp',
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decorations: decorations,
      underlineStyle: underlineStyle,
      underlineColor: underlineColor,
      color: color,
      shadingFill: shadingFill,
      themeFill: themeFill,
      themeFillTint: themeFillTint,
      themeFillShade: themeFillShade,
      fontSize: fontSize,
      fonts: fonts,
      highlight: highlight,
      characterSpacing: characterSpacing,
      isSuperscript: isSuperscript,
      isSubscript: isSubscript,
      isAllCaps: isAllCaps,
      isSmallCaps: isSmallCaps,
      isDoubleStrike: isDoubleStrike,
      isOutline: isOutline,
      isShadow: isShadow,
      isEmboss: isEmboss,
      isImprint: isImprint,
      textBorder: textBorder,
      verticalAlign: verticalAlign,
      borderTop: borderTop,
      borderBottomSide: borderBottomSide,
      borderLeft: borderLeft,
      borderRight: borderRight,
    );
  }

  // ============================================================
  // BORDER PARSER HELPER
  // ============================================================

  /// Reads an OOXML on/off toggle child of [rPr] (`w:caps`, `w:dstrike`, …) as
  /// a tri-state: `null` when the element is absent, otherwise true/false
  /// honouring `w:val`. Keeping "absent" distinct from "explicit off" is what
  /// lets the style engine XOR toggles and lets a child style turn one back off.
  static bool? _onOff(XmlElement rPr, String name) {
    final el = rPr.getElement(name);
    return el == null ? null : readOnOff(el);
  }

  static DocxBorderSide? _parseBorderSide(XmlElement? el) {
    if (el == null) return null;
    final val = el.getAttribute('w:val');
    if (val == null || val == 'none' || val == 'nil') return null;

    int size = 4;
    final szAttr = el.getAttribute('w:sz');
    if (szAttr != null) {
      final s = int.tryParse(szAttr);
      if (s != null) size = s;
    }

    // `w:space` — the gap between the border and the text, in points
    // (CT_Border, ISO/IEC 29500 §17.18.3). Previously dropped, so a bordered
    // paragraph hugged its text instead of keeping Word's offset.
    int space = 0;
    final spaceAttr = el.getAttribute('w:space');
    if (spaceAttr != null) {
      final s = int.tryParse(spaceAttr);
      if (s != null) space = s;
    }

    var color = DocxColor.black;
    final colorAttr = el.getAttribute('w:color');
    if (colorAttr != null && colorAttr != 'auto') {
      color = DocxColor(colorAttr);
    }

    // Theme colour for the line (resolved by the viewer against the document
    // theme). Without these a border with `w:themeColor` lost its hue and fell
    // back to black; the cell/table parser already read them — this brings the
    // paragraph/run/style border parser to parity.
    final themeColor = el.getAttribute('w:themeColor');
    final themeTint = el.getAttribute('w:themeTint');
    final themeShade = el.getAttribute('w:themeShade');

    var style = DocxBorder.single;
    String? rawVal;
    bool found = false;
    for (var b in DocxBorder.values) {
      if (b.xmlValue == val) {
        style = b;
        found = true;
        break;
      }
    }
    // An art/decorative or otherwise unmodelled `w:val` is preserved verbatim
    // (rendered as `single` by the viewer; see Plan §8.2 #3/#17).
    if (!found) rawVal = val;

    return DocxBorderSide(
      style: style,
      size: size,
      space: space,
      color: color,
      themeColor: themeColor,
      themeTint: themeTint,
      themeShade: themeShade,
      rawVal: rawVal,
    );
  }
}
