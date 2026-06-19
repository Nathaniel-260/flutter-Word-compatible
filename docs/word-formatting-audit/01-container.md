# משימה 01 — מבנה המכל: חלקים, יחסים, namespaces

> **מקור:** סעיף §1 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

קובץ `.docx` הוא ארכיון **ZIP** (OPC — Open Packaging Conventions). מנוע הרינדור פותח אותו ומאתר "חלקים" (parts) דרך קובצי יחסים (`.rels`).

### 1.1 החלקים העיקריים

| נתיב בתוך ה‑ZIP | תפקיד | חובה לרינדור? |
|---|---|---|
| `[Content_Types].xml` | מיפוי סיומת/חלק → MIME type | כן (לזיהוי) |
| `_rels/.rels` | יחס שורש → מצביע ל‑`document.xml` (relationship type `officeDocument`) | כן |
| `word/document.xml` | **גוף המסמך**: פסקאות, טבלאות, מקטעים | כן |
| `word/_rels/document.xml.rels` | יחסי הגוף → תמונות, headers/footers, styles, numbering, hyperlinks חיצוניים | כן |
| `word/styles.xml` | הגדרות סגנונות + `docDefaults` + `latentStyles` | כן |
| `word/numbering.xml` | הגדרות מספור ורשימות (`abstractNum`, `num`) | כן (לרשימות) |
| `word/settings.xml` | הגדרות מסמך גלובליות (defaultTabStop, compat, hyphenation...) | כן (משפיע) |
| `word/theme/theme1.xml` | ערכת צבעים + פונטים (major/minor) | כן (theme refs) |
| `word/fontTable.xml` | רשימת הפונטים בשימוש + מאפייני fallback (panose, charset) | מומלץ |
| `word/header1.xml` … | תוכן כותרות עליונות | כן (פר‑מקטע) |
| `word/footer1.xml` … | תוכן כותרות תחתונות | כן (פר‑מקטע) |
| `word/footnotes.xml` | הערות שוליים | כן (אם יש) |
| `word/endnotes.xml` | הערות סיום | כן (אם יש) |
| `word/comments.xml` (+`commentsExtended/Ids/Extensible`) | הערות סוקר | תלוי תצוגה |
| `word/media/imageN.*` | קבצי מדיה גולמיים (png/jpeg/emf/wmf/svg...) | כן |
| `word/embeddings/*` | אובייקטים מוטמעים (OLE, חוברות Excel) | תלוי |
| `word/glossary/document.xml` | Quick Parts / Building Blocks | לרוב לא |
| `word/fonts/*` | פונטים מוטמעים (לעיתים מעורפלים/obfuscated) | מומלץ |
| `customXml/*`, `docProps/*` | מטא‑דאטה ו‑data binding | לא לרינדור ישיר |

### 1.2 Namespaces מרכזיים (קידומות מוסכמות)

| קידומת | URI (מקוצר) | תוכן |
|---|---|---|
| `w` | `…/wordprocessingml/2006/main` | רוב עיצובי הטקסט/פסקה/טבלה/מקטע |
| `r` | `…/officeDocument/2006/relationships` | מזהי יחס (`r:id`, `r:embed`) |
| `wp` | `…/drawingml/2006/wordprocessingDrawing` | עיגון ציור במסמך (inline/anchor, wrap) |
| `a` | `…/drawingml/2006/main` | DrawingML core (גאומטריה, מילויים, אפקטים) |
| `pic` | `…/drawingml/2006/picture` | אריזת תמונה (`pic:pic`) |
| `wps` | `…/2010/wordprocessingShape` | צורות/תיבות טקסט (ext) |
| `wpg` | `…/2010/wordprocessingGroup` | קבוצות צורות |
| `wpc` | `…/2010/wordprocessingCanvas` | קנבס ציור |
| `mc` | `…/markup-compatibility/2006` | `AlternateContent` (Choice/Fallback) |
| `v` | `urn:schemas-microsoft-com:vml` | VML (גרפיקה ישנה, fallback, סימני מים) |
| `o`, `w10` | `urn:schemas-microsoft-com:office:*` | תוספי VML |
| `m` | `…/officeDocument/2006/math` | נוסחאות (OMML) |
| `w14`,`w15`,`w16*` | `…/wordml/2010/…` ואילך | הרחבות Word (effects, SDT checkbox, ...) |
| `wp14` | `…/2010/wordprocessingDrawing` | מיקום ציור מתקדם |

> **`mc:AlternateContent`** קריטי: Word כותב פעמים רבות גרסה מודרנית (`mc:Choice Requires="wps"`) וגם
> נפילה ל‑VML (`mc:Fallback`). מנוע הרינדור צריך לבחור את ה‑Choice שהוא תומך בו, ואחרת את ה‑Fallback —
> אסור לרנדר את שניהם.

### 1.3 שלד `document.xml`

```xml
<w:document xmlns:w="…" xmlns:r="…">
  <w:body>
    <w:p>…פסקה…</w:p>          <!-- בלוק -->
    <w:tbl>…טבלה…</w:tbl>       <!-- בלוק -->
    <w:p>
      <w:pPr><w:sectPr>…</w:sectPr></w:pPr>  <!-- מקטע שמסתיים כאן -->
    </w:p>
    <w:sectPr>…</w:sectPr>      <!-- מקטע אחרון (גוף ה-body) -->
  </w:body>
</w:document>
```

- **בלוקים** ברמת הגוף: `w:p` (פסקה), `w:tbl` (טבלה), `w:sdt` (פקד תוכן), ו‑bookmark/הערות שזורים.
- כל **מקטע** מסתיים ב‑`sectPr`: מקטע ביניים נמצא ב‑`pPr` של הפסקה האחרונה שלו; המקטע האחרון נמצא ישירות בסוף ה‑`body`.
- **פסקה** מכילה `pPr` (אופציונלי) + ריצות (`w:r`) ותכני inline אחרים.
- **ריצה** (`w:r`) מכילה `rPr` (אופציונלי) + תוכן (`w:t`, `w:br`, `w:tab`, `w:drawing`, `w:sym`, …).

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

### ב.1 — סריקה פר‑פריט

| # | פריט (חלק/namespace) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | זיהוי ZIP/OPC ופתיחת חלקים דרך `.rels` | | | | |
| 2 | `[Content_Types].xml` | | | | |
| 3 | `_rels/.rels` → `officeDocument` | | | | |
| 4 | `word/document.xml` (גוף) | | | | |
| 5 | `word/_rels/document.xml.rels` | | | | |
| 6 | `word/styles.xml` | | | | |
| 7 | `word/numbering.xml` | | | | |
| 8 | `word/settings.xml` | | | | |
| 9 | `word/theme/theme1.xml` | | | | |
| 10 | `word/fontTable.xml` | | | | |
| 11 | `word/headerN.xml` (פר‑מקטע) | | | | |
| 12 | `word/footerN.xml` (פר‑מקטע) | | | | |
| 13 | `word/footnotes.xml` | | | | |
| 14 | `word/endnotes.xml` | | | | |
| 15 | `word/comments.xml` (+Extended/Ids/Extensible) | | | | |
| 16 | `word/media/imageN.*` | | | | |
| 17 | `word/embeddings/*` (OLE) | | | | |
| 18 | `word/glossary/document.xml` | | | | |
| 19 | `word/fonts/*` (מוטמעים/obfuscated) | | | | |
| 20 | `customXml/*`, `docProps/*` | | | | |
| 21 | namespaces: `w`,`r`,`wp`,`a`,`pic`,`wps`,`wpg`,`wpc`,`mc`,`v`,`o`/`w10`,`m`,`w14`/`w15`/`w16*`,`wp14` | | | | |
| 22 | `mc:AlternateContent` (Choice/Fallback — לא לרנדר את שניהם) | | | | |
| 23 | שלד `document.xml`: בלוקים `w:p`/`w:tbl`/`w:sdt` + bookmarks שזורים | | | | |
| 24 | מיקום `sectPr` (ביניים ב‑pPr / אחרון בסוף body) | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
