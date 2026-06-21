# משימה 01 — מבנה המכל: חלקים, יחסים, namespaces

> **מקור:** סעיף §1 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **מימוש פערים:** ✅ הושלם — כל פער הוכרע (ממומש 1:1 / סטייה מודעת / מטופל במשימה ייעודית) &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-21

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
| 1 | זיהוי ZIP/OPC ופתיחת חלקים דרך `.rels` | **כן** ✅ | כן (OPC) | Word מאתר את החלק הראשי **דרך** `_rels/.rels` (relationship type `officeDocument`), לא בנתיב קבוע. **תוקן:** `discoverDocumentPart` מאתר את הגוף דרך היחס; `documentBaseDir` נגזר ממנו וכל החלקים/יעדי היחסים נפתרים יחסית אליו (`resolveRelative`/`resolvePartByType`). חבילה לא‑סטנדרטית (גוף בנתיב/שם אחר) נפתחת כעת. ברירת המחדל `word/` נשמרת → אפס רגרסיה. | `relationship_manager.dart:discoverDocumentPart`; `reader_context.dart` (`documentBaseDir`/`resolveRelative`/`resolvePartByType`); `docx_reader.dart` (שלב 0) |
| 2 | `[Content_Types].xml` | כן | כן (תשתית) | ב‑Word מקור זיהוי MIME של כל חלק. נטען (`Default`+`Override`) ונשמר; ה‑MIME משמש לתמונות. **ניתוב הפירוש** של חלקי‑מסמך מתבצע כעת לפי **סוג היחס** ב‑`document.xml.rels` (`resolvePartByType`) — שקול סמנטית לניתוב Word ועמיד בשמות חלקים שונים (למשל `styles2.xml`). | `relationship_manager.dart:20-43`; ניתוב `reader_context.dart:resolvePartByType` |
| 3 | `_rels/.rels` → `officeDocument` | **כן** ✅ | כן (OPC) | היחס שמצביע לגוף. **תוקן:** `discoverDocumentPart` קורא אותו ומאתר דרכו את הגוף (לא עוד נתיב קשיח), עם אימות קיום הקובץ ונפילה בטוחה ל‑`word/document.xml`. עדיין נשמר גם כ‑`rootRelsXml`. | `relationship_manager.dart:discoverDocumentPart`; `docx_reader.dart` (שלב 5) |
| 4 | `word/document.xml` (גוף) | כן | כן (תשתית) | גוף המסמך. נטען כעת מ‑`context.documentPartPath` שהתגלה ב‑`.rels` (במקום נתיב קשיח); אם חסר — שגיאה. מפוענח ל‑AST. | `docx_reader.dart` (שלב 5, `documentPartPath`); `block_parser.dart:30-35` |
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
| 15 | `word/comments.xml` (+Extended/Ids/Extensible) | חלקי (סמנים מסוננים) | סטייה מודעת (בלונים) | הערות סוקר. **תוקן:** סמני ההערה בגוף (`commentReference`/`annotationRef`, וכן `commentRangeStart/End`) מסוננים נקי במקום לדלוף כ‑`DocxRawInline` (זה גם מתואם להתנהגות Word — אין סימן נראה בטקסט). **רינדור בלוני‑שוליים = סטייה מודעת** (חומרה נמוכה): markup סוקר אינו חלק מהעמוד המודפס, ו‑Word מסתירו כברירת מחדל; עלות פריסת בלון בשוליים גבוהה. | סינון: `inline_parser.dart` (`_isCommentMarkerRun`) |
| 16 | `word/media/imageN.*` | כן (חלקי לפי פורמט) | חלקי | בתי התמונה נקראים דרך `r:embed`/`r:id`→relationship→מדיה (כעת יחסית ל‑`documentBaseDir`). png/jpeg/gif/bmp נתמכים ע"י מפענח Flutter; **emf/wmf אינם** → **סטייה מודעת** (§8.2 #2, placeholder ללא fallback ראסטרי). המרה/רסטור = משימה 09. | `inline_parser.dart` (`_parseDrawing`, `resolveRelative`) |
| 17 | `word/embeddings/*` (OLE) | חלקי (preview) | סטייה מודעת (בינארי) | אובייקטים מוטמעים. **תוקן:** `w:object` מנותב כעת דרך `_parseDrawing`, כך שתמונת ה‑**preview** שלו (`v:imagedata`/`a:blip`) מרונדרת כתמונה רגילה (רסטר → נראה; emf/wmf → placeholder, §8.2 #2). הבינארי המוטמע עצמו (OLE/Excel) אינו מורץ — **סטייה מודעת** (אין מנוע OLE/EMF native). ללא preview → נשמר כ‑`DocxRawInline`. | ניתוב `inline_parser.dart:parseRun` (`w:object`→`_parseDrawing`) |
| 18 | `word/glossary/document.xml` | **לא** | סטייה מודעת (מכוון) | Quick Parts / Building Blocks — תבניות, לא תוכן גוף. **Word עצמו אינו מרנדר אותם בגוף המסמך** → אי‑קריאה היא 1:1 עם תצוגת Word. חומרה: ללא. | אין (מכוון) |
| 19 | `word/fonts/*` (מוטמעים/obfuscated) | כן | ראו משימה 13 | פונטים מוטמעים מעורפלים — נקראים ומפוענחים (`fromObfuscated` עם `fontKey`). | `docx_reader.dart:336-385` |
| 20 | `customXml/*`, `docProps/*` | **לא** (ולא נדרש לרינדור) | סטייה מודעת (מכוון) | data‑binding/מטא‑דאטה — אינם משפיעים על פיקסל בעמוד. אי‑קריאה היא הבחירה הנכונה לנאמנות חזותית. חומרה: ללא. | אין (מכוון) |
| 21 | namespaces: `w`,`r`,`wp`,`a`,`pic`,`wps`,`wpg`,`wpc`,`mc`,`v`,`o`/`w10`,`m`,`w14`/`w15`/`w16*`,`wp14` | **כן** ✅ (חלקי ל‑wpg/wpc) | כן (תשתית) | רוב הקוד מתאים לפי **local name**. **תוקן:** זיהוי צורות עבר ל‑local‑name (`findAllElements('wsp', namespace:'*')` + `spPr`/`txbx` כילדים ישירים), כך ש‑`wps:wsp` של Word **נפתר כעת** (קודם רק `wsp:` של docx_creator). זו הייתה תקלת‑נאמנות אמיתית: צורות/תיבות‑טקסט מ‑Word לא פוענחו כלל. `wpg`/`wpc` (קבוצות/קנבס) ו‑`w14/w15/w16` (אפקטים) — **סטייה מודעת** (נדיר; חוץ מהיקף רינדור הצורות, משימה 09/H). | `inline_parser.dart` (`_parseDrawing`/`_parseShape`, `namespace:'*'`) |
| 22 | `mc:AlternateContent` (Choice/Fallback — לא לרנדר את שניהם) | **כן** ✅ | כן | **תוקן ל‑1:1:** `selectAlternateContent` (ISO/IEC 29500‑3 §10) בוחר את ה‑`Choice` הראשון שכל ה‑`Requires` שלו מובנים (URI מתוך scope, נפילה לקידומת), אחרת `Fallback`. מטופל ב‑**שלוש רמות**: בלוק (`block_parser`), inline ישיר, ו‑**בתוך `w:r`** (הצורה הנפוצה של Word — `parseRun` בונה ריצה סינתטית מהענף הנבחר, כך שחיפוש‑צאצאים לא חוטף את הענף הלא‑נכון). `wps` מובן כעת → ה‑Choice המודרני (DrawingML) גובר על ה‑Fallback (VML). | `xml_extension.dart:selectAlternateContent`; `inline_parser.dart` (`parseRun`/`parseChildren`); `block_parser.dart` |
| 23 | שלד `document.xml`: בלוקים `w:p`/`w:tbl`/`w:sdt` + bookmarks שזורים | כן | n/a (תשתית) | `w:p`, `w:tbl`, `w:sdt` (כולל TOC), וכן `ins`/`moveTo`/`smartTag` נפרסים; `del`/`moveFrom` (מחוק) מושמטים. bookmarks: `bookmarkStart` נשמר (מדלג `_GoBack`), `bookmarkEnd` מתעלם. | `block_parser.dart:55,114,131-167`; bookmarks `inline_parser.dart:46-54` |
| 24 | מיקום `sectPr` (ביניים ב‑pPr / אחרון בסוף body) | כן | n/a (תשתית) | מקטע ביניים: `sectPr` בתוך `pPr` → `DocxSectionBreakBlock`. מקטע אחרון: `sectPr` ישיר בסוף ה‑body → `SectionParser`. | ביניים `block_parser.dart:107-113`; אחרון `docx_reader.dart:203-204`, `section_parser.dart` |

### ב.2 — יומן הכרעות (כל פער הוכרע)

> **ראיה אמפירית.** נפתח DOCX אמיתי (`.tmp_docx/formatting-demo.docx`) ונקרא ה‑XML: `_rels/.rels`
> מצביע לגוף דרך `officeDocument`→`word/document.xml`; `document.xml.rels` נושא את סוגי היחסים
> styles/numbering/footnotes/endnotes/settings/comments/header/footer/fontTable; namespace הצורות של
> Word הוא `wps="…/wordprocessingShape"`. ההכרעות מתבססות על זה + ISO/IEC 29500.
>
> **מדידה≡רינדור.** כל התיקונים הם ברמת ה‑reader/AST ומפיקים צמתים קיימים (`DocxShape`,
> `DocxInlineImage`, `DocxText`) שה‑Paginator/TextMeasurer כבר מודדים — לא שונתה גאומטריית רינדור,
> ולכן אין סטיית עימוד חדשה. **תוספתי בלבד:** ברירת מחדל `word/`, אין שבירת API, round‑trip נשמר.

**ממומש 1:1:**

- **איתור חלקים דרך OPC (פריטים 1–4).** ✅ `discoverDocumentPart` מאתר את הגוף דרך יחס `officeDocument` ב‑`_rels/.rels`; `documentBaseDir` נגזר ממנו, וכל החלקים נפתרים לפי **סוג היחס** (`resolvePartByType`) עם נפילה ל‑`<baseDir>/<שם>`, וכל יעדי היחסים/תמונות/פונטים/כותרות דרך `resolveRelative` (תומך `..`/`/`). חבילה לא‑סטנדרטית נפתחת כעת; חבילת `word/` סטנדרטית — זהה לחלוטין (אפס רגרסיה). _בדיקה: "non-standard part" + "relationships relative to base"._
- **קידומת צורות `wps`/`wsp` (פריט 21).** ✅ ההתאמה עברה ל‑local‑name (`namespace:'*'` + ילדים ישירים ל‑`spPr`/`txbx`). צורות ותיבות‑טקסט מ‑**Word אמיתי** (`wps:wsp`) מפוענחות כעת — קודם נפלו ל‑`DocxRawInline`. _בדיקה: "shape with Word's wps: prefix"._
- **`mc:AlternateContent` (פריט 22).** ✅ `selectAlternateContent` (ISO §10): בוחר Choice שכל ה‑`Requires` שלו מובנים, אחרת Fallback; ב‑3 רמות (בלוק / inline / בתוך `w:r` עם ריצה סינתטית). `wps` מובן → ה‑Choice המודרני גובר על VML. _בדיקות: in‑run unsupported→fallback, understood wps→choice, block‑level._
- **סמני הערות בגוף (פריט 15).** ✅ `commentReference`/`annotationRef` (+`commentRangeStart/End`) מסוננים נקי — לא דולפים כ‑`DocxRawInline`. תואם 1:1 ל‑Word (אין סימן נראה בטקסט). _בדיקה: "comment markers don't leak"._
- **preview ל‑OLE (פריט 17).** ✅ `w:object` מנותב ל‑`_parseDrawing` → תמונת ה‑preview (`v:imagedata`/`a:blip`) מרונדרת. _בדיקה: "raster preview of embedded w:object"._

**סטיות מודעות (מתועדות, חומרה נמוכה):**

- **בלוני הערות סוקר (פריט 15).** רינדור הבלון בשוליים אינו ממומש — markup סוקר אינו חלק מהעמוד המודפס ו‑Word מסתירו כברירת מחדל; עלות פריסת בלון גבוהה. הנתונים אינם דולפים ואינם פוגעים בגוף.
- **בינארי OLE מוטמע (פריט 17).** ה‑binary (Excel/OLE) אינו מורץ — אין מנוע OLE native; ה‑preview כן מוצג.
- **emf/wmf במדיה (פריט 16).** placeholder ללא fallback ראסטרי — אין מפענח native ב‑Flutter (§8.2 #2). המרה/רסטור = משימה 09.
- **`wpg`/`wpc`, `w14`/`w15`/`w16` (פריט 21).** קבוצות/קנבס/אפקטים נדירים — מחוץ להיקף פיענוח הצורות (משימה 09/H).
- **glossary, customXml, docProps (פריטים 18, 20).** מכוון: תבניות/מטא‑דאטה שאינן חלק מהעמוד המודפס; אי‑קריאה = 1:1 עם Word.

**מטופל במשימה ייעודית (חובת המכל — קריאת החלק — מולאה):**

- **`settings.xml` (פריט 8).** כל ההגדרות נשמרות; **החלתן** (defaultTabStop/hyphenation/compat…) — משימה 14.
- **`fontTable.xml` fallback (פריט 10).** הפונטים המוטמעים נקראים; ניצול panose/charset/altName לבחירת תחליף — משימות 03/13.
