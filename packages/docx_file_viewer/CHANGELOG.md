# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

QA Part F follow-up fixes.

### 🐛 Bug Fixes

- **No artificial divider at a forced page top (F1)** — in paged mode, a paragraph carrying `w:pageBreakBefore` that opens a new page no longer draws a leading `Divider`. The page itself represents the break (as in Word), and the measurer no longer disagrees with the renderer by the divider's 32px, so the last body line is not at risk of being clipped.
- **`DocxViewConfig.copyWith` carries page settings (F13)** — `copyWith` now preserves `pageHeight`, `pageMode` and `fitPageToWidth`; previously `pageHeight`/`pageMode` were silently reset to their defaults.

### 🔧 Improvements

- **Paragraph spacing defaults to 0 (F6)** — when no spacing is resolved, a paragraph now contributes 0 before/after (the OOXML spec default) instead of an implicit 80 twips. Improves page-break parity with Word; documents that relied on the implicit spacing will render more tightly.
- **Fit-to-width shows a fitting page at 100% (F4)** — `fitPageToWidth` now scales the whole page footprint (including its margin band) uniformly via `BoxFit.contain`, so a page that fits is shown at exactly 100% with no aspect-ratio distortion (previously ~96% and slightly stretched).
- **Autofit table content floor (F3)** — a long, unbreakable word now widens its autofit column (the CSS `table-layout:auto` floor) instead of overflowing the cell — applied identically in measurement and rendering.
- **Faster system-font metrics (F9)** — system fonts are read partially (only the `head` + `OS/2` tables) instead of loading the whole file, avoiding multi-megabyte reads for large CJK fonts on first load.
- **Wider font-metrics coverage (F10)** — font families used only inside footnotes/endnotes are now registered for per-font line metrics, instead of falling back to the default line height.
- **`auto` table-row measurement (F8)** — an `auto` row with no explicit height now measures to its content (no 18px floor), matching the renderer exactly.

### 🧪 Tests

- Added/extended: `top_spacing_test` (F1), `page_fit_test` (F4), `paginator_test` (F8), `collect_fonts_test` (F10), `font_metrics_test` (F9), `table_min_widths_test` (F3).

## [1.0.2] - 2026-05-16

### ✨ New Features

- **First-line indent** (`w:firstLine`) — positive `indentFirstLine` now prepends a zero-height `WidgetSpan` spacer so the first line is indented relative to the paragraph body
- **Hanging indent** (`w:hanging`) — negative `indentFirstLine` values reduce the container left padding to approximate hanging-indent layout
- **Line-rule variants** — `lineRule` values `'exact'` and `'atLeast'` are now handled separately from `'auto'`: `exact` clamps the scale to 0.5–10, `atLeast` floors it at 1.0

### 🐛 Bug Fixes

- **Multi-column vertical merge placeholder** — a cell spanning N columns across multiple rows previously produced N separate thin placeholders in continuation rows; it now correctly emits one wide placeholder whose width covers all spanned columns

### 🧪 Tests

- Added `test/parser_test.dart` — 5 unit tests covering the cascade rule, table grid matrix, crash immunity, first-line indent spacer, and line-rule variants
- Added `test/widget_test.dart` — 4 widget tests covering row height `ConstrainedBox`, multi-column vMerge placeholder child count, search highlight character ranges, and floating image `Row` layout

### 🔧 Improvements

- Extracted `_resolveLineHeightScale()` helper in `ParagraphBuilder` to centralise line-height logic
- `TableBuilder._buildRow()` now tracks a parallel `skipColSpans` array alongside `skipCounts` to correctly group multi-column vertical merges
- Added `.claude/` and `graphify-out/` to `.gitignore`

## [1.0.1] - 2026-01-07

### 🎉 Stable Release

This release marks the stable 1.0.0 version with a complete architecture overhaul and significant feature improvements.

### ✨ New Features

- **Paged View Mode** - Documents can now be rendered in distinct page blocks (print layout style) in addition to continuous scrolling
- **Content-Aware Pagination** - Smart page breaks based on content height estimation
- **Embedded Font Loading** - Full support for OOXML font embedding with deobfuscation
- **Theme Color Resolution** - Proper handling of theme colors with tint/shade modifiers
- **Drop Cap Support** - Rich drop cap rendering with proper text wrapping
- **Floating Image Layout** - Left/right floating images with text wrap
- **Headers & Footers** - First page, odd/even page header/footer support
- **Footnotes & Endnotes** - Interactive footnote/endnote references with tap-to-view dialog
- **Table Conditional Formatting** - Support for first row, last row, first column, last column, and banded styles
- **Checkbox Support** - Interactive checkbox rendering in documents
- **Shape Rendering** - Basic shape support (rectangles, text boxes)

### 🔧 Improvements

- **Search Navigation** - Auto-scroll to search matches with dynamic alignment
- **Style Resolution** - Full style inheritance from named styles, paragraph, and run properties
- **Color Resolution** - Theme color, tint, and shade calculation
- **Border Rendering** - Complete border support for paragraphs and tables
- **Performance** - Optimized widget generation for large documents

### 🏗️ Architecture

- Migrated to modular builder pattern (`ParagraphBuilder`, `TableBuilder`, `ListBuilder`, etc.)
- Introduced `DocxWidgetGenerator` as the central rendering engine
- Added `DocxViewTheme` for comprehensive theming support
- Added `DocxSearchController` for programmatic search control
- Added `BlockIndexCounter` for search indexing

---

## [0.0.8]

### Fixed

- Bullet alignment improved
- Heading styles corrected

---

## [0.0.7]

### Added

- Text alignment from styles now parsed
- Background color and borders now parsed for paragraph and text elements

---

## [0.0.6]

### Fixed

- Styles were too much larger than expected
- If color is defined, don't apply default color

---

## [0.0.5]

### Added

- Styles now parsed from file for paragraph and character
- Text alignment now parsed from file

---

## [0.0.4]

### Fixed

- Ordered and unordered lists now render correctly

---

## [0.0.3]

### Fixed

- Resolved an issue where the divider was not being added correctly in the widget

### Breaking Changes

- Removed a static function to facilitate easier addition of new features in the future

---

## [0.0.2]

### Fixed

- Tag-based text not rendered issue resolved

---

## [0.0.1]

### Added

- Initial release