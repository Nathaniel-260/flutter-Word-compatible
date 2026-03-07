# Docx Creator - Master Developer & Master Reference Guide

This document is the definitive technical reference for the `docx_creator` package. It provides granular, code-level explanations of every major subsystem, intended to enable developers to modify or extend any part of the codebase with confidence.

---

## 🐣 Quick Start: Junior Developer Onboarding

If you are new to the codebase, follow this flow to understand how data moves:
1.  **Entry Point**: Look at `DocxDocumentBuilder` in `lib/src/builder/`. This is the user-facing API.
2.  **AST Transformation**: Every "add" method in the builder creates an object from `lib/src/ast/` (e.g., `DocxParagraph`).
3.  **The Output**: The `DocxExporter` in `lib/src/exporters/` takes these AST objects and converts them to XML.
4.  **Verification**: Check `test/new_features_test.dart` to see how we verify the XML output.

---

## 🏗 High-Level Architecture (The AST)

We represent a Word document as an **Abstract Syntax Tree (AST)**. This allows us to perform operations on the document (like finding all images or resolving styles) without worrying about the final file format (DOCX, PDF, or HTML).

### Core Node Types (`lib/src/ast/`)
*   **DocxNode**: Base class with a unique `id` and a `visitor` pattern implementation.
*   **DocxBlock**: Elements that start a new line (Paragraphs, Tables, Lists).
*   **DocxInline**: Elements that flow within a paragraph (Text runs, Images, Links).
*   **DocxSection**: Defines the physical page properties (Margins, Size, Orientation).

---

## 🚀 Deep Dive: The DocxExporter Engine
*Location: `lib/src/exporters/docx_exporter.dart`*

The `DocxExporter` is the "Compiler" of this project. It turns Dart objects into a valid `.docx` (OOXML) file.

### Granular Walkthrough: `exportToBytes()`

*   **Initialization (Lines 54-75)**:
    *   **Validation**: If a validator is attached, it runs structural checks.
    *   **Registry Reset**: We clear internal maps (`_images`, `_numIdMap`, etc.) to prevent data contamination if the exporter instance is reused.
*   **Resource Collection (Lines 78-97)**:
    *   **Fonts**: Registered in `FontManager` for obfuscation.
    *   **Images**: `_collectImages(doc)` recursively walks the tree to find every image. Each image is assigned a "Relationship ID" (`rId`) beginning at `11` (to avoid overlap with standard file relationships).
*   **Numbering Resolution (Lines 100-136)**:
    *   **The Problem**: Word separates *List Formatting* from *List Instances*.
    *   **The Logic**: We map each list to an `abstractNumId`. If multiple lists share a style, they share an `abstractNumId` but get different `numId`s if they should have independent counters.
*   **Archive Creation (Lines 138-230)**:
    *   We use the `archive` package to build a virtual ZIP structure.
    *   **XML Generation**: We add files like `[Content_Types].xml`, `styles.xml`, and `document.xml`.
    *   **Binary Injection**: Raw bytes for images and fonts are added to the ZIP internal directory (`word/media/` and `word/fonts/`).
    *   **Encoding**: The final `encoder.encode(archive)` call produces the `Uint8List` that users save as a `.docx` file.

---

## 🛠 Deep Dive: Block Elements (The Paragraph)
*Location: `lib/src/ast/docx_block.dart`*

The `DocxParagraph` is the most important AST node.

### Granular Walkthrough: `buildXml(XmlBuilder builder)`

*   **Master Tag (Line 351)**: `<w:p>` is the Word Processing element for a paragraph.
*   **Properties (`w:pPr`) (Line 357)**:
    *   This MUST be the first child of `<w:p>`.
    *   **Style (`w:pStyle`)**: Links to a named style in `styles.xml`.
    *   **Numbering (`w:numPr`)**: Defines if this paragraph is a bullet or numbered item.
    *   **Justification (`w:jc`)**: Sets alignment (start, center, end, both).
*   **Borders & Padding (Line 383)**:
    *   **The "Padding" Hack**: OOXML does not have a "padding" property. We use the `w:space` attribute inside the border tags (`w:top`, `w:bottom`, etc.).
    *   **Invisible Spacing**: To create spacing without a visible border line, we use `w:val="nil"` with a size of `0`.
*   **Children Emission (Line 506)**:
    *   The paragraph iterates through its `children` (Inlines).
    *   Each child (like `DocxText`) writes its own XML, typically a `<w:r>` (Run) element.

---

## 🧬 Deep Dive: The DocxReader (Reverse Engineering)
*Location: `lib/src/reader/docx_reader/docx_reader.dart`*

Reconstructing a document from XML is harder than creating it because Word uses many indirections.

### Granular Walkthrough: `_DocxReaderOrchestrator.read()`

*   **Step 1: Relations (Line 58)**: Map `rId`s to file paths. This is critical for images.
*   **Step 2: Style Hoisting (Line 61)**: Parse `styles.xml` first. This builds the property inheritance chain so we know the default font/size for the whole document.
*   **Step 3: Numbering Prep (Line 92)**: Parse `numbering.xml`. This tells us if a paragraph with `numId="5"` is a "Square Bullet" or "Roman Numeral".
*   **Step 4: Body Parsing (Line 152)**:
    *   We enter `BlockParser.parseBody`.
    *   It looks at tags: `<w:p>` -> new `DocxParagraph`, `<w:tbl>` -> new `DocxTable`.
*   **Step 5: Font Harvesting (Line 169)**: We extract embedded `.odttf` files. We must also capture the `fontKey` from the XML to de-obfuscate them correctly if needed.

---

## 🌐 Deep Dive: Platform Isolation (WASM/Web Support)
*Location: `lib/src/utils/file_saver.dart`, `file_loader.dart`*

To maintain compatibility across Native (IO) and Web (JS/WASM), the codebase uses **Conditional Exports**.

### How it works:
1.  **Unified Interface**: `file_saver.dart` acts as the entry point.
2.  **Conditional Logic**:
    ```dart
    export 'file_saver_io.dart' if (dart.library.js_interop) 'file_saver_web.dart';
    ```
3.  **WASM Compatibility**: We use `dart.library.js_interop` (WASM-friendly) instead of the legacy `dart.library.html`. This ensures that even when compiling to WebAssembly, the package knows which implementation to tree-shake.

---

## 🗓 Deep Dive: The Table Engine
*Location: `lib/src/reader/docx_reader/parsers/table_parser.dart`*

Tables are complex because they involve two-dimensional "merging" logic.

### Row Span Resolution (`_resolveRowSpans`)

*   **Logic (Line 527)**: Word doesn't store a "row span" number. Instead, it uses `vMerge` states: `restart` (start) and `continue` (middle/end).
*   **The Algorithm**: We maintain an `activeMerges` map that tracks the "source" cell for each column. When we hit a `continue`, we don't create a new cell; we find the `restart` cell in that column and increment its `finalRowSpan`. This collapses multiple XML tags into a single clean `DocxTableCell` object.

### Conditional Styling (`_resolveCellStyle`)

*   **Logic (Line 592)**: This method calculates the "Effective Style" of a cell by layering multiple properties:
    1.  **Table Style**: The global default.
    2.  **Banding**: Alternating row/column colors (Vertical/Horizontal Banding).
    3.  **Corners**: Special styles for specific cells like the "North-West" or "South-East" corners.
    4.  **Direct Formatting**: Manual overrides applied specifically to that cell.

---

## 🎨 Deep Dive: Style Inheritance
*Location: `lib/src/reader/docx_reader/parsers/style_parser.dart`*

### The Inheritance Cascade

1.  **Document Defaults (`_parseDocDefaults`)**: The absolute base (found in `styles.xml`).
2.  **Theme Baseline**: Colors and fonts from `theme1.xml`.
3.  **Named Styles (`_parseNamedStyles`)**: Styles like `Normal` or `Heading1` that can be `basedOn` other styles, creating a linked-list inheritance chain.
4.  **Local Overrides**: Properties defined directly on a Paragraph or Text run.

---

## 📄 Deep Dive: Fixed-to-Flow Processing (The PDF Reader)
*Location: `lib/src/reader/pdf_reader/pdf_reader.dart`*

PDFs have no concept of "paragraphs" or "rows"—only "draw text at (10, 50)".

### The Reconstructive Logic

1.  **Digitization (`_parsePage`)**: Every character is extracted with its bounding box (X, Y, Width, Height).
2.  **Grouping Algorithm (`_processPageFeatures`)**:
    *   **Sorting**: We sort all items by Y coordinate (descending) and then X.
    *   **Paragraph Detection**: If the Y-gap between two lines of text is small (e.g., `< 1.5 * font_size`), they are merged into one `DocxParagraph`.
    *   **Table Detection**: We pass all lines and text to `PdfTableDetector`. It looks for perpendicular lines that form rectangles around text.
3.  **Decoration Recovery (`_applyDecorations`)**:
    *   If a graphic line is found sitting exactly under a text run, we toggle `isUnderline = true` on the resulting `DocxText` node.

---

## ⚙️ Contributor Checklist: Adding a Feature

If you are adding a new Word property (e.g., "Glow Effect"):

1.  **Define the Data**: Add a field to the relevant AST node (e.g., `DocxText`).
2.  **Update Exporter**: In the `buildXml` method of that node, write the XML tags. **Warning**: Order matters! Check the OOXML schema to see where your new tag fits.
3.  **Update Reader**: Go to the corresponding Parser (e.g., `InlineParser`) and add logic to read that tag back from XML.
4.  **Test**: Add a case to `test/new_features_test.dart` that builds a document with your feature and checks the XML.

---

## 💡 Best Practices

*   **Avoid String Concatenation**: Always use `XmlBuilder`. It handles escaping and namespaces safely.
*   **Coordinate Systems**: Word uses "Twips" (1/1440th of an inch) for most distances. PDF uses "Points" (1/72nd of an inch). We have utility functions to convert between these.
*   **Modular Parsers**: Never let the `DocxReader` file grow too large. If you add a new subsystem, create a new sub-parser in `lib/src/reader/docx_reader/parsers/`.

---

> [!IMPORTANT]
> **XML Schema Integrity**: Word is extremely sensitive to the order of elements within `<w:pPr>` and `<w:rPr>`. If your generated document fails to open, 99% of the time it is because a tag is in the wrong position. Use the "Open XML SDK Productivity Tool" to find the exact error.
