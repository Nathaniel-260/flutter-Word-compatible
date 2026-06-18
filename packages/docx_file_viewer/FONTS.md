# Fonts in `docx_file_viewer`

This package **does not bundle any fonts** — bundling the Microsoft Office and
Hebrew font families a `.docx` typically references would add tens of megabytes
to every app. Instead the viewer resolves each Word font name to a family that
is *actually available* to Flutter, and you (the host app) decide which fonts to
provide.

## How a Word font name is resolved (Plan §L.2)

For every run, `FontResolver` maps the document's font name to a usable family in
this order:

1. **An explicit override** you configured in
   [`DocxViewConfig.fontSubstitutions`](lib/src/docx_view_config.dart) — wins
   over everything (intent is explicit). Keys are matched case-insensitively.
2. **The exact font, when available** — a font embedded in the `.docx`, or a
   system font the viewer could read. Kept as-is for maximal fidelity.
3. **A built-in metric-compatible clone** — open fonts with the *same glyph
   advances*, so line breaks match Word even when the original is absent:

   | Word font | Clone |
   |---|---|
   | Calibri / Calibri Light | Carlito |
   | Cambria | Caladea |
   | Times New Roman | Tinos |
   | Arial | Arimo |
   | Courier New | Cousine |
   | Georgia | Gelasio |
   | David | David Libre |
   | Narkisim / FrankRuehl | Frank Ruhl Libre |

   These names only render glyphs if **you bundle the clone**; otherwise the
   per-script fallback chain below catches the misses.
4. **Otherwise** the requested name is kept and the fallback chain is relied on.

## Mixed Hebrew + English (Plan §L.1)

A run containing both scripts is split: Hebrew/Arabic characters use the run's
complex-script font (`w:cs`, size `w:szCs`, bold `w:bCs`, italic `w:iCs`), Latin
characters use the Latin font (`w:ascii`, `w:sz`, `w:b`, `w:i`) — exactly what
Word does. Complex-script segments also carry a Hebrew/Arabic fallback chain
(David Libre → Frank Ruhl Libre → Noto Sans/Serif Hebrew → Noto Naskh Arabic)
*before* your Latin fallbacks, so a Hebrew glyph missing in the primary font
never drops to a Latin font (which would render a tofu box).

## Recommended setup for a host app

Register the fonts you care about with Flutter (via `pubspec.yaml` `fonts:` or a
`FontLoader`), using the family names Word uses **or** the clone names above, and
optionally map any remaining names:

```dart
DocxView(
  bytes: docxBytes,
  config: DocxViewConfig(
    // Make Hebrew glyphs resolve well even when the document's font is absent.
    customFontFallbacks: ['David Libre', 'Frank Ruhl Libre', 'Noto Sans Hebrew'],
    // Force a specific family for any Word font name (overrides the built-ins).
    fontSubstitutions: {
      'Calibri': 'MyBundledCalibriClone',
      'Narkisim': 'Frank Ruhl Libre',
    },
  ),
)
```

Embedded fonts are loaded **lazily** — only families the document actually
references are registered, so a `.docx` that embeds many faces but uses few does
not pay RAM for the unused ones.
