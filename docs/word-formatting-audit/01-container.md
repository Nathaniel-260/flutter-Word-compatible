# משימה 01 — מבנה המכל: חלקים, יחסים, namespaces

> **מקור:** סעיף §1 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-19

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

> **צנרת התצוגה.** מנוע התצוגה (`docx_file_viewer`) טוען את הקובץ דרך
> `DocxReader.loadFromBytes` (`docx_view.dart:378`, באיזולייט רקע לקבצים גדולים),
> ש‑מחזיר `DocxBuiltDocument` (AST). כל פריטי "המכל" שבמשימה זו מטופלים ב‑**reader**
> שבחבילת `docx_creator` — ה‑viewer צורך את ה‑AST המוכן. לכן הציטוטים מצביעים על ה‑reader.
> רוב פריטי המכל הם **תשתית פיענוח** (לא עיצוב נראה‑לעין), ולכן בעמודת "נאמן 1:1" מסומן
> `n/a (תשתית)` כשהשאלה הפיקסלית אינה רלוונטית, ומולא ממצא אמיתי היכן שכן.

### ב.1 — סריקה פר‑פריט

| # | פריט (חלק/namespace) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | זיהוי ZIP/OPC ופתיחת חלקים דרך `.rels` | חלקי | n/a (תשתית) | Word פותח ארכיב OPC ומאתר את החלק הראשי **דרך** `_rels/.rels` (relationship type `officeDocument`), לא לפי נתיב קבוע. כאן פתיחת ה‑ZIP מלאה אך איתור החלקים בנתיב קשיח. | `docx_reader.dart:87` (`ZipDecoder().decodeBytes`); `reader_context.dart:46-57` (`readContent`/`readBytes` ע"י `archive.findFile`) |
| 2 | `[Content_Types].xml` | כן (חלקי בשימוש) | n/a (תשתית) | ב‑Word זהו המקור לזיהוי MIME של כל חלק. כאן נטען למפה (`Default`+`Override`) ונשמר לשימור, אך הגישה לחלקים בפועל מתבצעת בנתיב קשיח — המפה אינה מנתבת פירוש. | `relationship_manager.dart:20-43`; נשמר ב‑`docx_reader.dart:222` |
| 3 | `_rels/.rels` → `officeDocument` | חלקי | n/a (תשתית) | היחס שמצביע ל‑`document.xml`. כאן נקרא **רק לשימור** (`rootRelsXml`), ולא משמש לאיתור הגוף — `word/document.xml` מקודד קשיח. | קריאה לשימור `docx_reader.dart:223`; נתיב קשיח `docx_reader.dart:181` |
| 4 | `word/document.xml` (גוף) | כן | n/a (תשתית) | גוף המסמך. נטען בנתיב קשיח; אם חסר — נזרקת שגיאה. הגוף מפוענח ל‑AST. | `docx_reader.dart:181-189`; `block_parser.dart:30-35` |
| 5 | `word/_rels/document.xml.rels` | כן | n/a (תשתית) | מפת `rId → target` (תמונות, headers/footers, styles, numbering, hyperlinks). כולל `TargetMode=External`. | `relationship_manager.dart:46-67`; `resolveTarget` `:121-136` |
| 6 | `word/styles.xml` | כן | ראו משימה 07 | נקרא **לפני** הגוף (docDefaults + basedOn). | `docx_reader.dart:100-102`; `reader_context.dart:90-136` |
| 7 | `word/numbering.xml` | כן | ראו משימה 08 | נקרא + `numbering.xml.rels` לתבליטי‑תמונה (`v:imagedata`). | `docx_reader.dart:130-178`; `numbering_parser.dart:93-100` |
| 8 | `word/settings.xml` | חלקי | n/a (תשתית) | ב‑Word מכתיב defaultTabStop, even/odd headers, hyphenation, compat ועוד. כאן נקראים **רק** `evenAndOddHeaders`, `defaultTabStop`, `footnotePr`/`endnotePr`; השאר נשמר כ‑raw בלבד ואינו מוחל. | `docx_reader.dart:39-58, 213-221` (ראו משימה 14) |
| 9 | `word/theme/theme1.xml` | כן | ראו משימה 13 | הנתיב מאותר דרך relationship type `theme` (תומך גם `theme2.xml`), עם fallback קשיח ל‑`theme1.xml`. | `docx_reader.dart:109-127` |
| 10 | `word/fontTable.xml` | חלקי | n/a (תשתית) | ב‑Word נושא panose/charset/altName ל‑fallback פונטים. כאן נקרא **רק** לחילוץ פונטים מוטמעים (`embedRegular/Bold/Italic/BoldItalic`); מטא‑דאטת fallback אינה מנוצלת. | `docx_reader.dart:207-210`; `_readFonts:318-391` |
| 11 | `word/headerN.xml` (פר‑מקטע) | כן | ראו משימה 05 | 3 וריאנטים: `default`/`first`/`even` דרך `w:headerReference`, נשמרים בנפרד לבחירת ה‑viewer. | `section_parser.dart:93-114` |
| 12 | `word/footerN.xml` (פר‑מקטע) | כן | ראו משימה 05 | `w:footerReference`, 3 וריאנטים כמו ה‑header. | `section_parser.dart:117-135` |
| 13 | `word/footnotes.xml` | כן | ראו משימה 10 | נקרא ומפוענח לבלוקים (`DocxFootnote`); מזהי separator/continuation ברירת‑מחדל מסוננים בשלב הרינדור. | `docx_reader.dart:229-235, 276-295` |
| 14 | `word/endnotes.xml` | כן | ראו משימה 10 | נקרא ומפוענח לבלוקים (`DocxEndnote`). | `docx_reader.dart:237-240, 297-316` |
| 15 | `word/comments.xml` (+Extended/Ids/Extensible) | **לא** | לא | הערות סוקר. **אינן נקראות כלל** ב‑reader (השם מופיע רק בצד הייצוא). לא מוצגות. | אין; השוו `content_types_generator.dart:45` (ייצוא בלבד) |
| 16 | `word/media/imageN.*` | כן (חלקי לפי פורמט) | חלקי | בתי התמונה נקראים מהארכיב דרך `r:embed`/`r:id`→relationship→`word/media/…`. png/jpeg/gif/bmp נתמכים ע"י מפענח Flutter; **emf/wmf אינם** ולא יוצגו (משימה 09). | `inline_parser.dart:506-539` |
| 17 | `word/embeddings/*` (OLE) | **לא** | לא | אובייקטים מוטמעים (OLE/חוברת Excel/`w:object`) אינם נקראים; נופלים ל‑`DocxRawInline` (ללא רינדור) או אובדים. | אין (fallback `inline_parser.dart:806`) |
| 18 | `word/glossary/document.xml` | **לא** | n/a | Quick Parts / Building Blocks — אינם נקראים (גם Word לרוב אינו מרנדר אותם בגוף). | אין |
| 19 | `word/fonts/*` (מוטמעים/obfuscated) | כן | ראו משימה 13 | פונטים מוטמעים מעורפלים — נקראים ומפוענחים (`fromObfuscated` עם `fontKey`). | `docx_reader.dart:336-385` |
| 20 | `customXml/*`, `docProps/*` | **לא** (ולא נדרש לרינדור) | n/a | data‑binding/מטא‑דאטה. אינם נקראים בקריאה; `docProps` נוצר רק בייצוא. | אין |
| 21 | namespaces: `w`,`r`,`wp`,`a`,`pic`,`wps`,`wpg`,`wpc`,`mc`,`v`,`o`/`w10`,`m`,`w14`/`w15`/`w16*`,`wp14` | חלקי | n/a (תשתית) | רוב הקוד מתאים לפי **local name** (עמיד לקידומת) — `w`,`r`,`mc`,`m`,`v` עובדים. **חריג:** זיהוי צורות לפי קידומת ליטרלית `wsp:wsp` (לא תואם את `wps:wsp` של Word) → לבדיקה במשימה 09. `wpg`/`wpc` (קבוצות/קנבס) ו‑`w14/w15/w16` (אפקטים) אינם מטופלים. | התאמה לפי local: `block_parser.dart:26-27,55,114`; `inline_parser.dart:46,170,181-184`. צורות: `inline_parser.dart:800` |
| 22 | `mc:AlternateContent` (Choice/Fallback — לא לרנדר את שניהם) | חלקי | חלקי | בוחר `Choice` ואחרת `Fallback` — נכון שלא לרנדר את שניהם. **אך** ללא בדיקת תכונת `Requires` (לא מאמת שהקידומת נתמכת בפועל), ומטופל **רק ברמת inline** — `block_parser` אינו מזהה `AlternateContent` ברמת בלוק. | `inline_parser.dart:181-191` (אין טיפול ב‑`block_parser`) |
| 23 | שלד `document.xml`: בלוקים `w:p`/`w:tbl`/`w:sdt` + bookmarks שזורים | כן | n/a (תשתית) | `w:p`, `w:tbl`, `w:sdt` (כולל TOC), וכן `ins`/`moveTo`/`smartTag` נפרסים; `del`/`moveFrom` (מחוק) מושמטים. bookmarks: `bookmarkStart` נשמר (מדלג `_GoBack`), `bookmarkEnd` מתעלם. | `block_parser.dart:55,114,131-167`; bookmarks `inline_parser.dart:46-54` |
| 24 | מיקום `sectPr` (ביניים ב‑pPr / אחרון בסוף body) | כן | n/a (תשתית) | מקטע ביניים: `sectPr` בתוך `pPr` → `DocxSectionBreakBlock`. מקטע אחרון: `sectPr` ישיר בסוף ה‑body → `SectionParser`. | ביניים `block_parser.dart:107-113`; אחרון `docx_reader.dart:203-204`, `section_parser.dart` |

### ב.2 — פערים והוראות ל‑AI הבא

- **איתור חלקים בנתיב קשיח (פריטים 1–4).** `_rels/.rels` ו‑`[Content_Types].xml` נטענים אך **אינם מנתבים** את איתור החלקים — `word/document.xml` והשאר מקודדים קשיח. עובד לקבצי Word סטנדרטיים, אך docx לא‑סטנדרטי (חלק ראשי בנתיב אחר, או part name שונה) ייכשל. **המלצה:** לאתר את הגוף דרך relationship `officeDocument` שב‑`_rels/.rels` ולכבד את `[Content_Types].xml` בעת פירוש חלקים.
- **`comments.xml` לא נתמך (פריט 15).** אם נדרש להציג הערות סוקר/בלוני שינויים — להוסיף קריאת `word/comments.xml` (+`commentsExtended/Ids/Extensible`) ל‑reader וצומת AST מתאים.
- **`embeddings/*` OLE לא נתמך (פריט 17).** אובייקטים מוטמעים אובדים. לכל הפחות לתעד כ"סטייה מודעת"; אם נדרש — להציג את תמונת ה‑preview (`emf/wmf`) של ה‑OLE (תלוי בתמיכת emf/wmf — פריט 16).
- **emf/wmf במדיה (פריט 16).** Flutter אינו מפענח emf/wmf → תמונות בפורמטים אלו לא יוצגו (נפוץ בסימני מים/לוגו מ‑Word). לבחון רסטור/המרה. ראו משימה 09.
- **`fontTable.xml` — fallback לא מנוצל (פריט 10).** panose/charset/altName אינם משמשים לבחירת פונט חלופי → עלול לפגוע בנאמנות פונטים. ראו משימות 03/13.
- **`AlternateContent` (פריט 22).** (א) להוסיף בדיקת `Requires` לפני בחירת `Choice` (היום בוחר Choice עיוורת); (ב) להוסיף טיפול ברמת **בלוק** ב‑`block_parser`, לא רק inline.
- **קידומת צורות `wsp:wsp` (פריט 21).** ההתאמה תלוית‑קידומת ליטרלית; Word כותב `wps:wsp`. לאמת מול קובץ Word אמיתי ולהמיר להתאמה לפי local name. ראו משימה 09.
- **`settings.xml` חלקי (פריט 8).** רוב ההגדרות הגלובליות נשמרות אך אינן מוחלות. הפירוט המלא — משימה 14.
