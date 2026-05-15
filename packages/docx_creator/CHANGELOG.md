## 1.2.6

### Fixed
- **Hyperlinks now generate clickable links** (#95): `DocxText.link` and the `href` parameter on `DocxText` were previously ignored during export. The generated XML now wraps the run in a `w:hyperlink` element with a proper relationship ID, and the corresponding `TargetMode=External` entry is added to `word/_rels/document.xml.rels`. All `const` constructors are preserved.
- **DocxListStyle is now fully respected** (#94): `DocxListItem.buildXmlWithStyle` previously ignored the `style` parameter entirely. Custom bullet characters, number formats (lowerAlpha, upperRoman, etc.), indentation, and font/color properties are now applied. Non-default styles receive their own `abstractNum` definition in `numbering.xml`, and each list item's `w:ind` reflects the effective `indentPerLevel` and `hangingIndent` from the style or per-item `overrideStyle`.

### Added
- **14 unit tests** covering hyperlink XML generation, relationship deduplication, and list style application (`test/issues_95_94_83_test.dart`).

---

## 1.2.5

### Fixed
- **Standardized Footer/Header Image Rendering**: Fixed a critical issue where images in footers and headers were invisible in Microsoft Word due to missing DrawingML attributes and namespace discrepancies.
  - Added mandatory `distT`, `distB`, `distL`, and `distR` attributes to `wp:inline`.
  - Added `wp:effectExtent` element for proper boundary calculation.
  - Synchronized `xmlns:mc`, `xmlns:w14`, and `xmlns:wp14` namespaces across all header and footer generators.
- **Table-based Footer Layout**: Added `DocxFooter.imageAndText` factory for easier creation of professional footer layouts with images and text.

### Added
- **Global Image Rendering Tests**: Added `test/footer_global_fix_test.dart` to verify OOXML compliance of image generation without workarounds.

---

## 1.2.4

### Fixed
- **Images Not Showing in MS Word**: Fixed critical issue where images in body, headers, and footers would render in LibreOffice but not in Microsoft Word (#90).
  - Added required `wp:cNvGraphicFramePr` element (with `a:graphicFrameLocks noChangeAspect="1"`) to both inline (`wp:inline`) and floating (`wp:anchor`) image drawings, as mandated by the OOXML specification.
  - Added missing `xmlns:a` (DrawingML) and `xmlns:pic` (Picture) namespace declarations to header and footer XML files, which are separate documents from `document.xml` and require their own namespace bindings.

### Added
- **MS Word Compatibility Tests**: Added 8 comprehensive tests (`image_ms_word_compat_test.dart`) that generate DOCX files, extract the ZIP, and verify XML structure for MS Word compatibility — including `wp:cNvGraphicFramePr` presence, namespace declarations, `.rels` files, media inclusion, and content type registration.

---

## 1.2.3

### Fixed
- **Invalid Path Decoding**: Added try-catch around `Uri.decodeFull` in `FileLoaderImpl` to prevent crashes when encountering invalid percent-encoded sequences (like a literal `%`) in file paths, especially on Windows (#89).
- **Zip Encoding Validation**: Added null/empty check for ZIP encoding results in `DocxExporter` to ensure document integrity (#85).

### Added
- **Custom Section Margins**: Added support for `marginTop`, `marginBottom`, `marginLeft`, and `marginRight` parameters in `DocxDocumentBuilder.section()`, allowing precise page layout control (#88).
- **AI Context**: Added `llm.txt` to the package root to provide better context for AI agents working with this codebase.

### Improved
- **Path Handling**: Enhanced `FileLoaderImpl` to correctly handle encoded file paths for local images (#77).

---

## 1.2.2

### Fixed
- **HTML image sizing**: `HtmlImageParser` now honors CSS-declared sizes (`<img style="width: 600px; height: 400px">`), converts pixel-valued `width`/`height` attributes to DOCX points via the 72/96 DPI ratio, and falls back to the intrinsic pixel size of the decoded image when no HTML-level sizing is present (#86).
- **Oversized images clipping the page**: `ImageResolver` now caps the final width at ~451 pt (the printable content width of an A4/Letter page with 1" side margins) preserving aspect ratio, so large source images stay inside the text frame.

---

## 1.2.1

### Added
- **Modular DOCX Generator Architecture**: Refactored the monolithic `DocxExporter` into specialized generator classes (`DocumentGenerator`, `StylesGenerator`, `RelationshipsGenerator`, etc.) for improved maintainability and extensibility.

### Fixed
- **Table Widths**: Corrected `w:tcW` (table cell width) generation when `gridColumns` are specified, ensuring accurate table layouts in Microsoft Word (#82).
- **Footer Images**: Fixed issue where images in footers were not rendering in Word due to missing relationship (`.rels`) files (#80).
- **Table Width Calculation**: Improved logic for calculating automatic column widths for better visual fidelity.

---

## 1.2.0

### Added
- **Multiple Text Decorations**: Added support for combining multiple text decorations (e.g., Bold + Underline + Strikethrough) on a single `DocxText` node.
- **Improved Decoration API**: Updated `DocxText` to use a `decorations` list, while maintaining backward compatibility with `isUnderline` and `isStrike` getters.

### Fixed
- **Heading Parsing**: Resolved an issue in `HtmlBlockParser` where nested elements (like `<b>` or `<i>`) inside heading tags (`h1`-`h6`) were being lost during HTML parsing.
- **Reader Compatibility**: Updated `DocxReader` and `PdfReader` to support multiple decorations.

---

## 1.1.9

### Fixed
- **Image Borders**: Corrected XML element order (`a:prstGeom` before `a:ln`) in `DocxInlineImage` to ensure borders are properly rendered in Microsoft Word.
- **Paragraph Alignment**: Fixed issue where left-aligned paragraphs in table cells incorrectly inherited table styles by always emitting explicit justification tags (`w:jc`).
- **Paragraph Padding**: Fixed unwanted horizontal lines appearing when using `paddingTop` or `paddingBottom` by defaulting to invisible `nil` borders (#70).

### Improved
- **Alignment Mapping**: Updated `DocxAlign` to use modern `start` and `end` values for better compatibility and RTL support.

---

## 1.1.8

### Fixed
- **Vertical Text Alignment**: Added support for vertical text alignment via `DocxTextAlignment` enum and `textAlignment` property in `DocxParagraph` and related factory methods (#72).
- **Header Visibility**: Fixed issue where custom headers were only visible on the first page by defaulting `headerReference` to `w:type="default"` (#73).
- **Table Row Height Enforcement**: Ensured strict matching of custom table row heights by adding `w:hRule="exact"` to the generated `w:trHeight` tag (#74).

---

## 1.1.7

### Fixed
- **Paragraph Justification**: Fixed critical issue where `DocxAlign.justify` caused document corruption by incorrectly mapping to `w:val="justify"`. Now correctly maps to `w:val="both"`.

### Added
- **Image Borders**: Added support for image outlines (Simple Frame) via the `border` parameter in `DocxImage` and `DocxInlineImage`.
- **Regression Tests**: Added `test/justification_and_border_test.dart` to verify alignment mapping and image border generation.

---

## 1.1.6

### Fixed
- **Web Compatibility**: Removed all direct `dart:io` dependencies to enable full Flutter Web support.
  - Replaced `dart:io` `File` usages with platform-agnostic `FileSaver` and `FileLoader` abstractions.
  - Replaced `dart:io` `zlib` compression with `package:archive` for PDF generation and parsing on web.
  - Updated `ImageResolver` to handle file loading via `FileLoader`.

---

## 1.1.4

### Fixed
- **Critical Word Compatibility**: Fixed issue where documents were not opening in Microsoft Word due to incorrect XML tag ordering.
  - Reordered `w:rPr` (run properties) children to strictly follow the OOXML schema (e.g., `rFonts` -> `color` -> `sz`).
  - Reordered `w:tblPr` (table properties) and `w:tcPr` (cell properties) to match schema requirements.
- **Newline Handling**: Fixed issue where newlines in `DocxText` were ignored. Now converts `\n` to `<w:br/>`.
- **Web Support**: Fixed `exportToFile` failure on web platforms.
  - Replaced direct `dart:io` imports with a platform-agnostic `FileSaver` utility.
  - Added proper web implementation using `dart:js_interop` and `package:web`.

---

## 1.1.3

### Fixed
- **DOCX Padding & Backgrounds**: Fixed critical issue where paragraph padding and background colors were ignored by Word.
  - Implemented strict OOXML schema compliance for `w:pPr` element order (`pStyle` -> `numPr` -> `pBdr` -> `shd` -> ...).
  - Fixed internal `w:pBdr` child order (`top` -> `left` -> `bottom` -> `right`) which previously caused border blocks to be invalidated.
  - Corrected `w:space` unit conversion (twips to points) for padding.
- **PDF Background Alignment**: Fixed issue where text rendered outside its background rectangle.
  - Corrected text baseline calculation to standard font metrics (approx. 1em offset) ensuring text sits strictly inside the background box.
- **PDF Rendering Loop**: Fixed bug where multi-line paragraphs were not updating the Y-coordinate correctly during rendering.

### Improved
- **AST Refactoring**: Cleaned up `DocxParagraph` by removing deprecated fields (`borderBottom`) and unifying styling logic.

---

## 1.1.2

### Added
- **PDF Reader Improvements**: Major enhancements for broader PDF compatibility:
  - **XRef Stream Support**: Complete parsing of PDF 1.5+ cross-reference streams with `/W` array, `/Index` array, and proper decompression.
  - **Object Stream Support**: Parse compressed objects stored within object streams (PDF 1.5+).
  - **Fallback Object Scanning**: Automatic object recovery when xref table/stream is corrupted or malformed.
  - **LZW Decoding**: Full implementation of LZWDecode filter for older PDFs.
  - **PNG Image Encoding**: Raw RGB pixel data (from FlateDecode images) is now properly encoded as PNG format for direct use in Flutter.
  - **Improved Font Parsing**: Balanced bracket matching for nested dictionary structures.

- **PDF Exporter Improvements**:
  - **Helvetica-Bold Width Table**: Added complete character width table for Helvetica-Bold with accurate per-character measurements.
  - **Fixed Binary Stream Handling**: Corrected compression corruption issue where binary compressed data was incorrectly converted through String encoding.

### Fixed
- **Bold Text Spacing**: Fixed issue where bold text characters appeared too close together due to inaccurate width calculations using only a 1.05x multiplier instead of proper Helvetica-Bold metrics.
- **Blank PDF Generation**: Fixed blank PDFs caused by binary FlateDecode stream data being corrupted during intermediate String conversions.
- **Image Extraction**: Fixed image extraction returning raw RGB bytes instead of usable image format. Images are now properly encoded as PNG.

### Improved
- **PdfDocument Documentation**: Enhanced documentation explaining the purpose of both `elements` and `images` lists.
- **Error Handling**: Better error recovery during PDF parsing with informative warnings.

---

## 1.1.1

### Fixed
- **Code Cleanup**: Removed unused optional parameters (`isStrikethrough`, `isUnderline`) in PDF reader classes to fix analyzer warnings.
- **Internal Optimization**: Improved code quality in `pdf_classes.dart` by removing unused fields.

---

## 1.1.0

### Added
- **PDF Export**: New `PdfExporter` class for exporting documents directly to PDF format.
  - Pure Dart implementation with no native dependencies
  - Supports text formatting (bold, italic, underline, strikethrough)
  - Per-character font metrics for accurate text measurement (Helvetica)
  - Bold font width scaling (1.05x) for proper heading layout
  - Superscript and subscript support with proper positioning
  - Custom font sizes with per-line height calculation
  - Background colors for paragraphs and inline text
  - Table rendering with cell backgrounds and borders
  - List rendering (bullet and numbered)
  - Image embedding (PNG format)
  - Multi-page support with configurable page sizes (Letter, A4)
  - Text alignment (left, center, right, justify)

### Example
```dart
import 'package:docx_creator/docx_creator.dart';

final doc = docx().h1('Title').p('Content').build();
await PdfExporter().exportToFile(doc, 'output.pdf');
```

---

## 1.0.9

### Fixed
- **Table Border Fidelity**: Fixed critical issues with conditional table borders (first row, last row, first column, last column, banding) not being correctly applied or inherited.
  - Resolved conflicts between cell-level borders, table-level borders, and named style borders.
  - Ensures correct visual rendering of complex table styles like "Grid Table 4 - Accent 1".
- **Table Color Resolution**: Fixed logic where 'auto' colors in tables were not correctly resolving to black/transparent based on context.
- **Fallback Logic**: Improved fallback logic for table borders when specific side borders are undefined.

### Improved
- **High-Fidelity Round-Trip**: Enhanced the preservation of table style properties during read/write cycles.

---

## 1.0.8

### Fixed
- **Advanced Style Inheritance**: Implemented proper `docDefaults` resolution for paragraph and run properties.
- **Table Text Styling**: Fixed text styling in tables to respect paragraph-level run properties (`w:rPr`).

### Added
- **Theme Color Support**: Added support for `themeColor`, `themeTint`, and `themeShade` in text and styling.
- **Character Spacing**: Added support for parsing `w:spacing` in run properties.

---

## 1.0.7

### Fixed
- **Table Row Heights**: Fixed missing `w:trHeight` parsing and export. Calendar tables and other tables with explicit row heights now preserve their dimensions.
- **Table Overlap**: Added parsing and export for `w:tblOverlap` attribute on floating tables.
- **Embedded Font Variants**: Fixed font reading to parse all font embed types (`w:embedRegular`, `w:embedBold`, `w:embedItalic`, `w:embedBoldItalic`) instead of only Regular. This fixes missing font files during round-trip.
- **Table Border Export**: Tables with a `styleId` (e.g., "Calendar3", "LightList-Accent3") no longer emit explicit `<w:tblBorders>` that was incorrectly overriding the named style definition.
- **Text Style Inheritance**: Fixed inline parser to only emit **direct** run properties (color, font size, fonts), not inherited ones from styles. This allows table cell text to properly inherit styling from table styles via `cnfStyle` conditional formatting.

---

## 1.0.6

### Fixed
- **Table Style Fidelity**: Fixed critical issue where table cell borders defined in Named Table Styles (via `w:tblStylePr`) were ignored.
  - Updated `DocxStyle` parser to correctly extract `w:tcBorders` from table style conditionals.
  - Fixed logic to properly prioritize table style borders when paragraph borders are absent.

## 1.0.5

### Fixed
- **Font Fidelity**: Fixed critical issue where embedded fonts were lost during the read-export cycle due to mismatched relationship IDs and filenames.
  - Preserved exact filenames and relationship IDs from the original document.
  - Updated `fontTable.xml.rels` handling to ensure valid links to embedded font files.
- **Line Spacing Fidelity**: Fixed issue where specific line spacing rules (e.g., 'Exactly' vs 'At Least') were ignored.
  - Added support for parsing and exporting `w:lineRule` attribute in paragraphs and styles.
  - Ensures visual vertical spacing matches the original document precisely.
- **Style Inheritance**: Fixed issue where paragraph styles (like 'Heading 1') were lost on export.
  - Added parsing for `w:pStyle` property in `DocxStyle` and `DocxParagraph`.
- **Inline Font Merging**: Fixed logic where direct font formatting (e.g., hints) completely overwrote character style fonts.
  - Implemented proper merging of direct font properties with underlying character style fonts.
- **Theme Support**: Added parsing for theme-related font attributes (`w:asciiTheme`, `w:eastAsiaTheme`, etc.) to preserve theme-based font selection.

## 1.0.4

### Added
- **Table Style Resolver**: Added full support for Named Table Styles (`w:tblStylePr`) and Conditional Formatting (`w:tblLook`).
  - Supports 'First Row', 'Last Row', 'First Column', 'Last Column', and 'Banded Rows/Columns' formatting.
  - Automatically resolves and "bakes" effective styles (shading, borders, fonts) into table cells for visual fidelity.
- **Floating Images**: Added parser support for floating images with precise positioning.
  - Supports `wp:anchor` parsing.
  - Handles `relativeFrom` (margin, page, column) and alignment attributes.
- **Drop Caps**: Added support for Drop Caps (`w:dropCap`) in paragraphs.
- **Footnotes & Endnotes**: Added comprehensive support for parsing and exporting Footnotes and Endnotes.
- **Text Borders**: Added support for parsing text borders (`w:bdr`).

### Fixed
- **Table Styles**: Fixed issue where table styles were not correctly applied to cells during parsing.
- **Attribute Export**: Fixed invalid hex color format (removed `#` prefix) in `w:fill` attribute generation to ensure compatibility with Microsoft Word.
- **Cell Copying**: Fixed `DocxTableCell.copyWith` bug that caused style properties to be lost when modifying table cells.

---

## 1.0.3

### Improved
- **Modular DocxReader Architecture**: Refactored 1797-line monolithic `docx_reader.dart` into 11 focused modules:
  - `reader_context.dart` - Shared state manager
  - `parsers/style_parser.dart` - Style resolution
  - `parsers/block_parser.dart` - Paragraph/list parsing
  - `parsers/inline_parser.dart` - Text/image/shape parsing
  - `parsers/table_parser.dart` - Table/rowspan handling
  - `parsers/section_parser.dart` - Headers/footers/sections
  - `handlers/relationship_manager.dart` - OOXML relationships
  - `handlers/font_reader.dart` - Embedded font extraction
- **Modular HTML Parser Architecture**: Refactored 1259-line `html_parser.dart` into 8 modules:
  - `html/parser_context.dart` - CSS class map & shared state
  - `html/style_context.dart` - Style inheritance context
  - `html/color_utils.dart` - 141 CSS named colors
  - `html/block_parser.dart` - Block elements
  - `html/inline_parser.dart` - Inline elements
  - `html/table_parser.dart` - Tables with nested support
  - `html/list_parser.dart` - Ordered/unordered lists
  - `html/image_parser.dart` - Image elements

### Fixed
- **UTF-8 Encoding**: Fixed XML content parsing to use proper UTF-8 decoding in DocxReader
- **Shape Parsing**: Restored full shape dimension/color/preset parsing in refactored reader
- **Nested Table Support**: HTML parser now correctly handles tables inside table cells
- **Background Inheritance**: Fixed `resetBackground()` to properly clear nullable `shadingFill` values

---

## 1.0.2

### Added
- **DrawingML Shapes**: Full support for 70+ preset shapes (rectangles, ellipses, stars, arrows, flowchart symbols, etc.)
  - Block-level shapes (`DocxShapeBlock`) and inline shapes (`DocxShape`)
  - Fill colors, outline colors, and outline widths
  - Text content inside shapes
  - Rotation support
  - Floating and inline positioning
- **Shape Reader Support**: Shapes are now preserved when reading existing DOCX files
- **141 CSS Named Colors**: Full W3C CSS3 Extended Color Keywords support in HTML parser
  - All grey/gray spelling variations supported
  - Includes colors like `dodgerblue`, `mediumvioletred`, `papayawhip`, etc.
- **Comprehensive Examples**: Added four complete example files:
  - `manual_builder_example.dart` - All builder API features
  - `html_parser_example.dart` - All HTML/CSS features
  - `markdown_parser_example.dart` - All Markdown features
  - `reader_editor_example.dart` - Full read-edit-write workflow

### Improved
- **Documentation**: Complete rewrite of README.md and new DOCUMENTATION.md with:
  - Full API reference tables
  - All supported HTML tags and CSS properties
  - Step-by-step DOCX Reader/Editor guide
  - OpenXML internals explanation
  - Troubleshooting section
- **Color Handling**: Improved color class with automatic hex normalization (strips `#` and `0x` prefixes)
- **List Rendering**: Enhanced 9-level nested list support with proper abstract numbering

### Fixed
- **Background Color Inheritance**: Fixed CSS `background-color` incorrectly inheriting to inline children
- **Code Block Visibility**: Fixed text visibility in code blocks when used with background colors

---

## 1.0.1

### Fixed
- **List Rendering**: Fixed numbered and bullet lists not displaying markers in Word when multiple lists appear in the same document.
- **Color Parsing**: Fixed `HtmlParser` color parsing for font colors and background highlights. Now supports:
  - Hex codes (3-digit and 6-digit)
  - RGB/RGBA formats
  - Extended CSS named colors (including `grey`, `lime`, `maroon`, etc.)
- **Highlight Mapping**: Fixed incorrect default highlight color (no longer defaults to yellow for unknown colors).

### Improved
- **OOXML Compliance**: Updated `numbering.xml` generation to match python-docx patterns for better Word compatibility (`w:nsid`, `w:tmpl`, `w:tabs`).

---

## 1.0.0

- Initial version.
