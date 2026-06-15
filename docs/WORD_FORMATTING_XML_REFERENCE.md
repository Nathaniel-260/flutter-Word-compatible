# מסמך ייחוס מקיף: כל העיצובים והסגנונות של Word ב‑XML (OOXML / WordprocessingML)

> **מטרת המסמך.** זהו מסמך הייחוס המלא לבניית **מנוע רינדור** ל‑DOCX. הוא ממפה *כל* מאפיין עיצוב
> שקיים ב‑Word, את שם האלמנט/התכונה ב‑XML, את היחידות והערכים האפשריים, מה הוא עושה ויזואלית,
> ואת מקרי הקצה החשובים למימוש 1:1.
>
> **מקורות.** ECMA‑376 / ISO‑IEC 29500 (WordprocessingML, DrawingML), מראת הסכמה ב‑datypic.com,
> Microsoft Learn ([MS‑OI29500] ו‑Open XML SDK), ו‑officeopenxml.com. כשיש סתירה בין המפרט
> להתנהגות Word בפועל — **התנהגות Word היא הקובעת** והמפרט הוא הגיבוי.
>
> **כיצד לקרוא.** לכל קבוצת מאפיינים יש טבלה: `אלמנט/תכונה | יחידה/ערכים | מה עושה | הערות וקצה`.
> שמות אלמנטים תמיד עם הקידומת `w:` (namespace הראשי) אלא אם צוין אחרת (`wp:`, `a:`, `pic:`, `r:`, `mc:`, `m:`, `v:`, `w14:`/`w15:`).
> מסמך אחות מעשי: [WORD_FIDELITY_VIEWER_PLAN.md](WORD_FIDELITY_VIEWER_PLAN.md) (תוכנית הבנייה בפועל).

---

## תוכן עניינים

1. [מבנה המכל: חלקים, יחסים, namespaces](#1-מבנה-המכל)
2. [יחידות מידה וטיפוסי ערכים (twips, EMU, half-points, toggle, צבעים)](#2-יחידות-מידה-וטיפוסי-ערכים)
3. [עיצוב ריצה / תו — `w:rPr`](#3-עיצוב-ריצה--תו--wrpr)
4. [עיצוב פסקה — `w:pPr`](#4-עיצוב-פסקה--wppr)
5. [מקטעים, עמוד, טורים, גבולות, מספור — `w:sectPr`](#5-מקטעים-עמוד-טורים-גבולות-מספור--wsectpr)
6. [טבלאות — `w:tblPr` / `w:trPr` / `w:tcPr`](#6-טבלאות)
7. [סגנונות — `styles.xml`](#7-סגנונות--stylesxml)
8. [מספור ורשימות — `numbering.xml`](#8-מספור-ורשימות--numberingxml)
9. [ציור, תמונות, צורות, תיבות טקסט — DrawingML / VML](#9-ציור-תמונות-צורות-תיבות-טקסט)
10. [תוכן inline מיוחד: שבירות, טאבים, סמלים, שדות, קישורים, סימניות, הערות, נוסחאות](#10-תוכן-inline-מיוחד)
11. [פקדי תוכן — Structured Document Tags (SDT)](#11-פקדי-תוכן-sdt)
12. [מעקב שינויים (Revisions)](#12-מעקב-שינויים-revisions)
13. [ערכת עיצוב — `theme1.xml` (צבעים ופונטים)](#13-ערכת-עיצוב--theme1xml)
14. [הגדרות מסמך — `settings.xml`](#14-הגדרות-מסמך--settingsxml)
15. [רקע מסמך וסימני מים](#15-רקע-מסמך-וסימני-מים)
16. [סדר ההחלה והעדיפות (resolution) — קריטי למנוע](#16-סדר-ההחלה-והעדיפות)
17. [נספח: טבלאות enum מלאות](#17-נספח-טבלאות-enum-מלאות)

---

## 1. מבנה המכל

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

## 2. יחידות מידה וטיפוסי ערכים

מנוע רינדור **חייב** להמיר נכון; טעות יחידה = פספוס מידות. כל ההמרות הבסיסיות:

| יחידה | הגדרה | המרה | היכן בשימוש |
|---|---|---|---|
| **twip** (dxa) | 1/20 נקודה = 1/1440 אינץ' | `px = twip / 1440 * 96` (ב‑96dpi); `pt = twip / 20` | שוליים, מידות עמוד, הזחות, רוחב טבלה/תא, מיקום טאב, גובה שורה |
| **half-point** | 1/2 נקודה | `pt = val / 2` | גודל פונט (`sz`,`szCs`), `position`, `kern` |
| **eighth-point** | 1/8 נקודה | `pt = val / 8` | עובי גבול (`sz` ב‑borders) |
| **EMU** | English Metric Unit | `1 inch = 914400`; `1 pt = 12700`; `1 cm = 360000` | מידות DrawingML (extent, offset, גודל תמונה) |
| **fiftieth of %** | 1/50 אחוז | `% = val / 50` | רוחב type="pct" ישן (`5000`=100%) |
| **% string** | מחרוזת `"50%"` | ישיר | רוחב type="pct" חדש (Word כותב לעיתים `w="50%"`) |
| **240ths of line** | יחידת שורה | יחס שורה = `line/240` | `w:spacing line` כש‑`lineRule="auto"` (240=יחיד, 360=1.5, 480=כפול) |
| **line units (×100)** | 1/100 שורה | `lines = val/100` | `beforeLines`,`afterLines`,`gridBefore/After` |

### 2.1 `ST_OnOff` — מאפייני toggle (חשוב מאוד)

מאפיינים בוליאניים (`w:b`, `w:i`, `w:caps`, `w:keepNext`...) מצייתים לכללי `ST_OnOff`:

- `<w:b/>` (ללא תכונה) ⇒ **דלוק** (true).
- `<w:b w:val="true"/>` או `="1"` או `="on"` ⇒ דלוק.
- `<w:b w:val="false"/>` או `="0"` או `="off"` ⇒ **כבוי** (חשוב: זה לא "ברירת מחדל" אלא ביטול מפורש שגובר על ירושה).
- **היעדר האלמנט** = "לא צוין" = יורש מהרמה שמעליה (≠ כבוי).

> **כלל ה‑XOR לתכונות toggle** (ISO 17.7.3): עבור `b, bCs, i, iCs, caps, smallCaps, strike, dstrike, outline, shadow, emboss, imprint, vanish` — כאשר התכונה מוגדרת בכמה רמות (docDefaults / סגנון / ישיר), הערכים מצטברים ב‑**XOR** ולא בדריסה פשוטה. דוגמה: סגנון מגדיר `b=on`, וריצה מגדירה `b=on` → התוצאה **off** (true XOR true). זאת הסיבה ש"בולד על בולד" מבטל. ראו §16.3.

### 2.2 צבעים

| צורה | XML | משמעות |
|---|---|---|
| RGB מפורש | `w:val="FF0000"` | hex RRGGBB (ללא `#`) |
| אוטומטי | `w:val="auto"` | Word בוחר שחור/לבן לפי רקע (ניגודיות) |
| theme color | `w:themeColor="accent1"` | הפניה ל‑`clrScheme` ב‑theme1.xml |
| גוון theme | `w:themeTint="99"` / `w:themeShade="BF"` | ערך hex (00–FF) של בהרה/האפלה על צבע ה‑theme |

> **חישוב tint/shade:** `tint` = הבהרה לכיוון לבן, `shade` = החשכה לכיוון שחור. הערך הוא יחס (byte/255).
> נוסחה מקובלת ל‑shade: `channel_out = channel * (shade/255)`. ל‑tint: `channel_out = channel*(tint/255) + 255*(1 - tint/255)`.
> ערכי `ST_ThemeColor`: ראו [נספח §17.7](#177-st_themecolor-צבעי-theme).

### 2.3 מאפיין הצללה משולש: `w:shd`

`w:shd` חוזר בהרבה הקשרים (ריצה, פסקה, תא, טבלה). תמיד שלוש תכונות:

| תכונה | משמעות |
|---|---|
| `w:val` | **תבנית** ההצללה (ST_Shd: `clear`, `solid`, `pct25`, `horzStripe`…). `clear` = אין תבנית, רק `fill`. |
| `w:fill` | צבע **רקע** (hex/auto/themeFill) |
| `w:color` | צבע ה**תבנית** (הפיקסלים של ה‑pattern; רלוונטי רק כש‑val≠clear/solid) |

> מקרה נפוץ: `<w:shd w:val="clear" w:fill="D9D9D9"/>` = רקע אפור אחיד. `<w:shd w:val="solid" w:color="…"/>` = מילוי מלא בצבע ה‑color. ערכי ST_Shd מלאים: [נספח §17.5](#175-st_shd-תבניות-הצללה).

### 2.4 גבול גנרי: `CT_Border`

כל גבול (ב‑pBdr/tblBorders/tcBorders/bdr/pgBorders) חולק תכונות:

| תכונה | יחידה/ערכים | מה עושה |
|---|---|---|
| `w:val` | `ST_Border` (single, double, dotted, dashed, wave, threeDEmboss, + 160 art borders…) | סגנון הקו. `nil`/`none` = אין גבול. ראו [§17.1](#171-st_border-סגנונות-גבול-מלא). |
| `w:sz` | eighth-points (1/8 pt) | עובי הקו. טווח שכיח 2–96. |
| `w:space` | נקודות (pt) | מרווח בין הגבול לטקסט. ב‑pgBorders תלוי ב‑`offsetFrom`. |
| `w:color` | hex/auto/theme | צבע הקו |
| `w:themeColor`,`themeTint`,`themeShade` | כמו §2.2 | צבע theme לקו |
| `w:frame` | bool | אפקט תלת‑ממד "מסגרת" |
| `w:shadow` | bool | צל לקו |
| `w:id` | מזהה art border | רק לגבולות עמוד דקורטיביים (`w:val` שהוא art) |

---
## 3. עיצוב ריצה / תו — `w:rPr`

`rPr` מופיע ב‑3 הקשרים: (א) בתוך `w:r` (עיצוב ישיר של ריצה); (ב) בתוך `w:pPr` כ‑**mark run properties** — עיצוב של תו סוף‑הפסקה (פיד הפסקה); (ג) בתוך `w:style`/`docDefaults` (עיצוב סגנון). הסדר בין הילדים מחייב לפי הסכמה (להלן הסדר הרשמי של `CT_RPr`).

### 3.1 הפניית סגנון תו

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:rStyle` | `<w:rStyle w:val="Emphasis"/>` | מחיל **סגנון תו** (character style) על הריצה | נכנס בסדר העדיפות בין סגנון פסקה לעיצוב ישיר (§16) |

### 3.2 פונטים — `w:rFonts`

```xml
<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="David"
          w:eastAsia="SimSun" w:hint="cs"/>
```

| תכונה | מה עושה |
|---|---|
| `w:ascii` | פונט לתווי ASCII (U+0000–U+007F) |
| `w:hAnsi` | פונט ל‑"High ANSI" (לטינית מורחבת, מעל U+007F שאינו EA/CS) |
| `w:cs` | פונט ל‑**Complex Script** (עברית, ערבית) — **קריטי לעברית** |
| `w:eastAsia` | פונט למזרח‑אסיה (CJK) |
| `w:asciiTheme`,`hAnsiTheme`,`eastAsiaTheme`,`cstheme` | במקום שם פונט מפורש — הפניה ל‑theme (`minorHAnsi`,`majorBidi`...) |
| `w:hint` | `default`/`eastAsia`/`cs` — רמז לאיזו קטגוריה משתייכים תווים "מעורפלים" (למשל סימני פיסוק) |

> **בחירת הפונט פר‑תו (קריטי ל‑BiDi):** Word בוחר את התכונה (ascii/hAnsi/eastAsia/cs) לפי **טווח היוניקוד של כל תו**, לא לפי הריצה. כך באותה ריצה: "א" יקבל את `cs`, "A" יקבל את `ascii`. מנוע 1:1 חייב לפצל ריצה לפי כתב. ראו §16.5.

### 3.3 משקל, נטייה, וריאנטים — תכונות toggle

| אלמנט | מה עושה | תאום CS | קצה |
|---|---|---|---|
| `w:b` | מודגש | `w:bCs` (לכתב מורכב/עברית) | toggle (XOR) |
| `w:i` | נטוי | `w:iCs` | toggle |
| `w:caps` | הצגת כל התווים כאותיות גדולות (לטינית) | — | ויזואלי בלבד; הטקסט נשאר lowercase |
| `w:smallCaps` | קפיטליות קטנות | — | toggle; אותיות קטנות → גרסת caps מוקטנת |
| `w:strike` | קו חוצה יחיד | — | toggle |
| `w:dstrike` | קו חוצה כפול | — | toggle; גובר/נפרד מ‑strike |
| `w:outline` | מתאר תווים (קו חיצוני, פנים חלול) | — | toggle |
| `w:shadow` | צל לתו | — | toggle |
| `w:emboss` | תבליט (בולט) | — | toggle |
| `w:imprint` | חריטה (שקוע) | — | toggle |
| `w:vanish` | **טקסט מוסתר** — לא מוצג/מודפס | — | toggle; משפיע על עימוד (תופס/לא תופס מקום לפי הגדרת hidden text) |
| `w:specVanish` | סימן פסקה מוסתר תמיד (כותרות מקופלות) | — | רק על mark run |
| `w:webHidden` | מוסתר בתצוגת Web בלבד | — | בד"כ מתעלמים בתצוגת print |
| `w:noProof` | אל תבדוק איות/דקדוק | — | לא משפיע ויזואלית |
| `w:snapToGrid` | יישר תווים לרשת המסמך (docGrid) | — | משפיע על ריווח ב‑EA |

### 3.4 צבע, גודל, הדגשה

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:color` | `<w:color w:val="C00000" w:themeColor="accent2"/>` | צבע הטקסט | `auto`=שחור/לבן לפי רקע; theme גובר אם קיים |
| `w:sz` | `<w:sz w:val="24"/>` | גודל פונט ב‑**half-points** (24=12pt) | תאום: `szCs` |
| `w:szCs` | `<w:szCs w:val="24"/>` | גודל לכתב מורכב/עברית | **חיוני** — עברית יכולה לקבל גודל שונה מהלטינית באותה ריצה |
| `w:highlight` | `<w:highlight w:val="yellow"/>` | סימון מרקר (17 צבעים קבועים) | ערכים: [§17.4](#174-st_highlightcolor-צבעי-מרקר). `none`=ללא. שונה מ‑shd! |
| `w:u` | `<w:u w:val="single" w:color="FF0000"/>` | קו תחתון | val: [§17.2](#172-st_underline-קו-תחתון). `words`=רק מתחת מילים, לא רווחים. תומך `color`/theme. |
| `w:em` | `<w:em w:val="dot"/>` | סימן הדגשה (מעל/מתחת תווים, EA) | ערכים: none, dot, comma, circle, underDot |
| `w:effect` | `<w:effect w:val="sparkle"/>` | אפקט אנימציה ישן | ערכים: none, blinkBackground, lights, antsBlack, antsRed, shimmer, sparkle. לרוב מרנדרים כסטטי. |

### 3.5 מיקום, ריווח, מתיחה (typographic)

| אלמנט | XML | יחידה | מה עושה | קצה |
|---|---|---|---|---|
| `w:spacing` | `<w:spacing w:val="20"/>` | twips (יכול שלילי) | ריווח בין אותיות (tracking) | שונה מ‑`w:spacing` של פסקה! |
| `w:position` | `<w:position w:val="6"/>` | half-points (שלילי=הנמכה) | הרמה/הנמכה מקו הבסיס בלי שינוי גודל | ≠ vertAlign (שמשנה גודל) |
| `w:kern` | `<w:kern w:val="18"/>` | half-points | מפעיל kerning החל מגודל פונט זה ומעלה | 0=כבוי |
| `w:w` | `<w:w w:val="150"/>` | אחוזים (1–600, 100=רגיל) | מתיחה/כיווץ אופקי של רוחב התווים | מעוות את התו |
| `w:fitText` | `<w:fitText w:val="1440" w:id="1"/>` | twips | דחיסה/מתיחה כך שהטקסט ימלא רוחב נתון | `id` מקבץ ריצות לאותו fitText |

### 3.6 גבול והצללה ברמת ריצה

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:bdr` | `<w:bdr w:val="single" w:sz="4" w:color="auto"/>` | מסגרת סביב הטקסט (תכונות `CT_Border`, §2.4) | מקיף את הריצה; רצף ריצות עם אותו bdr ממוזג |
| `w:shd` | `<w:shd w:val="clear" w:fill="FFFF00"/>` | הצללת רקע לריצה (§2.3) | שונה מ‑highlight (מנגנון אחר, מודפס תמיד) |

### 3.7 כיוון וכתב מורכב (BiDi)

| אלמנט | מה עושה | קצה |
|---|---|---|
| `w:rtl` | מסמן את הריצה ככתב RTL — **קובע שמאפייני ה‑CS (`bCs`,`iCs`,`szCs`,`cs`) הם החלים** | toggle; משפיע על סדר התווים בתוך הריצה |
| `w:cs` | "השתמש בעיצוב Complex Script על הריצה" | דגל שמפנה את ההחלטה למאפייני ה‑CS |
| `w:lang` | `<w:lang w:val="en-US" w:bidi="he-IL" w:eastAsia="…"/>` | שפת התוכן (לטינית/CS/EA בנפרד) | משפיע על מקפים, איות, ובחירת fallback |

### 3.8 פריסת מזרח‑אסיה

| אלמנט | תכונות | מה עושה |
|---|---|---|
| `w:eastAsianLayout` | `id`, `combine`, `combineBrackets` (none/round/square/angle/curly), `vert`, `vertCompress` | "Two lines in one" / טקסט אנכי / דחיסה — תופעות EA |

### 3.9 נוסחה ושינויי גרסה

| אלמנט | מה עושה |
|---|---|
| `w:oMath` | מסמן שהריצה היא חלק מנוסחה (OMML) |
| `w:rPrChange` | מידע מעקב‑שינויים על מאפייני הריצה (revision) — ראו §12 |

### 3.10 הרחבות Word (namespace `w14`) — אפקטי טקסט

Word 2010+ מוסיף אפקטים גרפיים לטקסט תחת `w14`, בתוך `rPr` (לרוב עטופים ב‑`mc:AlternateContent`):

| אלמנט | מה עושה |
|---|---|
| `w14:glow` | זוהר מסביב לטקסט (rad + צבע) |
| `w14:shadow` | צל מתקדם (offset, blur, direction) |
| `w14:reflection` | השתקפות |
| `w14:textOutline` | מתאר טקסט מתקדם (עובי, צבע, gradient) |
| `w14:textFill` | מילוי טקסט (solid/gradient/דמוי תמונה) |
| `w14:scene3d`,`w14:props3d` | אפקטי תלת‑ממד |
| `w14:ligatures` | ליגטורות (none/standard/contextual/historical/discretional + צירופים) |
| `w14:numForm` | צורת ספרות (default/lining/oldStyle) |
| `w14:numSpacing` | ריווח ספרות (default/proportional/tabular) |
| `w14:stylisticSets` | ערכות סגנון של הפונט (OpenType ssXX) |
| `w14:cntxtAlts` | חלופות הקשריות (contextual alternates) |

> מנוע בסיסי יכול להתעלם מ‑`w14` ולרנדר את הטקסט הרגיל; מנוע 1:1 מלא יממש לפחות glow/outline/fill/shadow.

---
## 4. עיצוב פסקה — `w:pPr`

`pPr` הוא הילד הראשון של `w:p` (כשקיים). הסדר של ילדיו מחייב לפי הסכמה (`CT_PPr`). הרשימה המלאה, לפי סדר הסכמה:

### 4.1 הפניית סגנון ושמירה (keep)

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:pStyle` | `<w:pStyle w:val="Heading1"/>` | מחיל **סגנון פסקה** | בסיס לשרשרת `basedOn` |
| `w:keepNext` | `<w:keepNext/>` | החזק את הפסקה באותו עמוד עם הבאה אחריה | toggle; מונע יתמות כותרת |
| `w:keepLines` | `<w:keepLines/>` | אל תשבור את שורות הפסקה בין עמודים | toggle |
| `w:pageBreakBefore` | `<w:pageBreakBefore/>` | התחל את הפסקה בראש עמוד חדש | toggle; כופה מעבר עמוד לפני |
| `w:widowControl` | `<w:widowControl/>` | מנע שורה בודדת (אלמנה/יתום) בראש/סוף עמוד | **ברירת מחדל true** ב‑Word (בד"כ ב‑docDefaults) |
| `w:suppressLineNumbers` | | אל תמספר שורות בפסקה זו (כשמספור שורות פעיל) | toggle |
| `w:suppressAutoHyphens` | | בטל מיקוף אוטומטי בפסקה | toggle |

### 4.2 מסגרת טקסט — `w:framePr`

הופך פסקה ל"מסגרת צפה" (text frame) — בסיס drop‑cap וכותרות צד.

| תכונה | ערכים | מה עושה |
|---|---|---|
| `w:dropCap` | none/drop/margin | אות פתיח מוגדלת; `drop`=בתוך הטקסט, `margin`=בשוליים |
| `w:lines` | int | כמה שורות גובה תופסת ה‑drop cap |
| `w:w`,`w:h` | twips | רוחב/גובה המסגרת |
| `w:hRule` | auto/exact/atLeast | כלל הגובה |
| `w:hSpace`,`w:vSpace` | twips | מרווח אופקי/אנכי מהטקסט שמסביב |
| `w:wrap` | around/none/notBeside/through/tight | עטיפת הטקסט סביב המסגרת |
| `w:hAnchor`,`w:vAnchor` | text/margin/page | עוגן המיקום האופקי/האנכי |
| `w:x`,`w:y` | twips | מיקום מוחלט |
| `w:xAlign` | left/center/right/inside/outside | יישור אופקי יחסי |
| `w:yAlign` | inline/top/center/bottom/inside/outside | יישור אנכי יחסי |
| `w:anchorLock` | bool | נעל את העוגן |

### 4.3 מספור (רשימה)

| אלמנט | XML | מה עושה |
|---|---|---|
| `w:numPr` | `<w:numPr><w:ilvl w:val="0"/><w:numId w:val="3"/></w:numPr>` | משייך את הפסקה לרשימה: `numId`→הגדרה ב‑numbering.xml, `ilvl`→רמת היררכיה (0‑based) |
| | `<w:ins .../>` בתוך numPr | מעקב‑שינויים על המספור |

> `numId="0"` = **ביטול מספור** מפורש (שובר מספור שירש מסגנון).

### 4.4 גבולות והצללה של פסקה

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:pBdr` | `<w:pBdr><w:top …/><w:left …/><w:bottom …/><w:right …/><w:between …/><w:bar …/></w:pBdr>` | גבולות פסקה (תכונות `CT_Border`) | `between`=קו בין פסקאות עוקבות עם אותו גבול; `bar`=קו אנכי בצד |
| `w:shd` | `<w:shd w:val="clear" w:fill="E0E0E0"/>` | הצללת רקע לפסקה (§2.3) | מתפרס על כל רוחב אזור הטקסט |

> **מיזוג גבולות פסקה:** פסקאות עוקבות עם `pBdr` זהה ממוזגות לתיבה אחת (Word לא מצייר קו אופקי ביניהן אלא `between`). מקרה קצה למנוע.

### 4.5 טאבים — `w:tabs`

```xml
<w:tabs>
  <w:tab w:val="center" w:pos="4320"/>
  <w:tab w:val="right"  w:pos="8640" w:leader="dot"/>
  <w:tab w:val="clear"  w:pos="2880"/>
</w:tabs>
```

| תכונה | ערכים | מה עושה |
|---|---|---|
| `w:val` | left, center, right, decimal, bar, num, start, end, clear | סוג היישור בנקודת הטאב. `decimal`=יישור לפי נקודה עשרונית; `bar`=מצייר קו אנכי; `clear`=מוחק טאב שירש; `num`=טאב רשימה |
| `w:pos` | twips | מיקום מהשוליים |
| `w:leader` | none, dot, hyphen, underscore, heavy, middleDot | תו מילוי עד הטאב (למשל נקודות בתוכן עניינים) |

> טאבים שלא הוגדרו במפורש נופלים ל‑`w:defaultTabStop` מ‑settings.xml (ברירת מחדל 720 twips = חצי אינץ').

### 4.6 טיפוגרפיית מזרח‑אסיה (ברמת פסקה)

| אלמנט | מה עושה |
|---|---|
| `w:kinsoku` | החל כללי שבירת‑שורה של EA (אסור להתחיל/לסיים שורה בתווים מסוימים) |
| `w:wordWrap` | התר שבירה ברמת תו (לא רק רווח) |
| `w:overflowPunct` | אפשר לפיסוק לחרוג מעבר לשוליים |
| `w:topLinePunct` | דחוס פיסוק בתחילת שורה |
| `w:autoSpaceDE` | רווח אוטומטי בין לטינית ל‑EA |
| `w:autoSpaceDN` | רווח אוטומטי בין EA לספרות |
| `w:snapToGrid` | יישר את הפסקה ל‑docGrid |
| `w:adjustRightInd` | התאם אוטומטית הזחה ימנית לרשת |

### 4.7 כיוון, ריווח, הזחה, יישור

| אלמנט | XML | יחידה/ערכים | מה עושה | קצה |
|---|---|---|---|---|
| `w:bidi` | `<w:bidi/>` | toggle | **כיוון פסקה RTL** | **דגל הכיוון הקריטי**; קובע גם את מיפוי `jc` (§16.4) |
| `w:spacing` | `<w:spacing w:before="240" w:after="120" w:line="360" w:lineRule="auto"/>` | ראה למטה | ריווח לפני/אחרי + גובה שורה | |
| `w:ind` | `<w:ind w:start="720" w:hanging="360"/>` | twips | הזחות | |
| `w:contextualSpacing` | toggle | | בטל before/after בין פסקאות מאותו סגנון רצופות | קריטי לרשימות צפופות |
| `w:mirrorIndents` | toggle | | התייחס להזחה left/right כ‑inside/outside (הדפסת ספר) | |
| `w:suppressOverlap` | toggle | | מנע ממסגרות טקסט לחפוף | |
| `w:jc` | `<w:jc w:val="both"/>` | start,end,left,right,center,both,distribute,… | **יישור אופקי** | תלוי‑כיוון! ראו §16.4 + [§17.3](#173-st_jc-יישור) |
| `w:textDirection` | `<w:textDirection w:val="tbRl"/>` | lrTb, tbRl, btLr, lrTbV, tbRlV, tbLrV | כיוון זרימת הטקסט (אופקי/אנכי) | רלוונטי לתאים ול‑EA |
| `w:textAlignment` | `<w:textAlignment w:val="center"/>` | auto, baseline, top, center, bottom | יישור **אנכי** של תווים בשורה (כשגדלים שונים) | |
| `w:textboxTightWrap` | none/allLines/firstAndLastLine/… | | עטיפה צמודה לתוכן תיבת טקסט | |
| `w:outlineLvl` | `<w:outlineLvl w:val="0"/>` | 0–9 (9=body) | רמת תוכן עניינים/חלוקה לראשי פרקים | משפיע על TOC ועל ניווט |
| `w:divId` | int | | קישור ל‑HTML div | לא ויזואלי |
| `w:cnfStyle` | `<w:cnfStyle w:val="100000000000"/>` | bitmask | עיצוב מותנה (firstRow/lastRow/...) — בעיקר בתאים | ראו §6.5 |

#### פירוט `w:spacing` (פסקה)

| תכונה | יחידה | מה עושה |
|---|---|---|
| `w:before` | twips | רווח מעל הפסקה |
| `w:after` | twips | רווח מתחת לפסקה |
| `w:beforeLines`,`w:afterLines` | 1/100 שורה | רווח לפני/אחרי ביחידות שורה |
| `w:beforeAutospacing`,`w:afterAutospacing` | toggle | רווח אוטומטי (כמו ב‑HTML `<p>`); כשדלוק, מתעלם מ‑before/after המספריים |
| `w:line` | תלוי lineRule | גובה שורה |
| `w:lineRule` | auto/exact/atLeast | פירוש `line`: **auto**→`line` ב‑240ths (240=יחיד, 360=1.5, 480=כפול); **exact**→`line` ב‑twips (גובה קבוע, חותך תוכן גדול); **atLeast**→`line` ב‑twips כמינימום (גדל לפי הצורך) |

#### פירוט `w:ind` (הזחה)

| תכונה | מה עושה | קצה |
|---|---|---|
| `w:start` / `w:left` | הזחה מהצד המתחיל (start = תלוי‑כיוון, החדש; left = הישן) | Word החדש כותב start/end |
| `w:end` / `w:right` | הזחה מהצד המסיים | |
| `w:firstLine` | הזחה נוספת **לשורה הראשונה** | |
| `w:hanging` | הזחה **תלויה** — השורה הראשונה שמאלה משאר הפסקה | `hanging` גובר על `firstLine`; בסיס לרשימות |
| `w:startChars`/`w:endChars`/`w:firstLineChars`/`w:hangingChars` | אותו דבר ביחידות תו (EA) | |

### 4.8 `w:rPr` בתוך `w:pPr` (mark run properties)

עיצוב של **תו סוף‑הפסקה** (סימן הפיד). קובע את גובה השורה הריקה ועיצוב סימן הפסקה. קריטי: גודל פונט של mark run משפיע על גובה פסקה ריקה ועל מרווחים.

---
## 5. מקטעים, עמוד, טורים, גבולות, מספור — `w:sectPr`

מקטע מגדיר את גאומטריית העמוד וכל מה שתלוי‑עמוד. הסדר של ילדי `CT_SectPr` מחייב:

### 5.1 כותרות/תחתיות והערות

| אלמנט | XML | מה עושה |
|---|---|---|
| `w:headerReference` | `<w:headerReference w:type="default" r:id="rId7"/>` | מצביע לקובץ header. `w:type`: `default` (אי‑זוגי/כל), `even` (זוגי), `first` (עמוד ראשון) |
| `w:footerReference` | אותו דבר ל‑footer | |
| `w:footnotePr` | `pos`, `numFmt`, `numStart`, `numRestart`, `numStartCount` | מאפייני הערות שוליים פר‑מקטע |
| `w:endnotePr` | אותו דבר להערות סיום | |

> שלושת ה‑variants (default/even/first) מופעלים לפי `w:titlePg` (להלן) ו‑`w:evenAndOddHeaders` ב‑settings.xml. בלי `evenAndOddHeaders`, `even` מתעלם וה‑default משמש לכל העמודים.

### 5.2 סוג מקטע, גודל ושוליים

| אלמנט | XML | מה עושה |
|---|---|---|
| `w:type` | `<w:type w:val="nextPage"/>` | תחילת המקטע: `nextPage`, `continuous` (ללא מעבר), `evenPage`, `oddPage`, `nextColumn` |
| `w:pgSz` | `<w:pgSz w:w="11906" w:h="16838" w:orient="portrait" w:code="9"/>` | גודל עמוד ב‑twips (11906×16838 = A4). `orient`: portrait/landscape. `code`=קוד גודל נייר. |
| `w:pgMar` | `<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>` | שוליים ב‑twips. `header`/`footer`=מרחק הכותרת מקצה הנייר. `gutter`=שוליים נוספים לכריכה. top/bottom יכולים להיות שליליים. |
| `w:paperSrc` | `first`, `other` | מגש נייר במדפסת (לא ויזואלי) |

### 5.3 גבולות עמוד — `w:pgBorders`

```xml
<w:pgBorders w:offsetFrom="page" w:display="allPages" w:zOrder="front">
  <w:top    w:val="single" w:sz="24" w:space="24" w:color="auto"/>
  <w:left   .../><w:bottom .../><w:right .../>
</w:pgBorders>
```

| תכונה | ערכים | מה עושה |
|---|---|---|
| `w:offsetFrom` | page / text | האם `space` נמדד מקצה הנייר או מהטקסט |
| `w:display` | allPages / firstPage / notFirstPage | באילו עמודים להציג |
| `w:zOrder` | front / back | מעל או מתחת לתוכן |
| כל גבול (top/left/bottom/right) | `CT_Border` (§2.4) + `w:id` ל‑art borders | art borders (apples, hearts...) דורשים תמונות חוזרות. ראו [§17.1](#171-st_border-סגנונות-גבול-מלא) |

> ב‑`offsetFrom="text"` ה‑`space` ב‑pgBorders נמדד **בנקודות** מהטקסט; ב‑`page` הוא בנקודות מקצה הנייר.

### 5.4 מספור שורות — `w:lnNumType`

| תכונה | מה עושה |
|---|---|
| `w:countBy` | מספר כל N שורות (1=כל שורה) |
| `w:start` | מספר התחלה |
| `w:distance` | מרחק המספר מהטקסט (twips) |
| `w:restart` | newPage / newSection / continuous |

### 5.5 מספור עמודים — `w:pgNumType`

| תכונה | ערכים | מה עושה |
|---|---|---|
| `w:start` | int | מספר העמוד הראשון במקטע |
| `w:fmt` | ST_NumberFormat (decimal, lowerRoman, upperLetter, hebrew1…) | פורמט מספר העמוד |
| `w:chapStyle` | int | סגנון הכותרת המגדיר מספר פרק (לפורמט "1‑1") |
| `w:chapSep` | hyphen, period, colon, emDash, enDash | מפריד בין מספר פרק למספר עמוד |

> השדה `PAGE` בכותרת מקבל את הפורמט מ‑`pgNumType/@fmt` של המקטע הנוכחי. `start` מאפס את ספירת העמודים.

### 5.6 טורים — `w:cols`

```xml
<w:cols w:num="2" w:space="708" w:equalWidth="0" w:sep="1">
  <w:col w:w="2700" w:space="360"/>
  <w:col w:w="6000"/>
</w:cols>
```

| תכונה | מה עושה |
|---|---|
| `w:num` | מספר הטורים |
| `w:space` | מרווח אחיד בין טורים (twips) — כש‑equalWidth |
| `w:equalWidth` | bool — טורים שווים (אז מתעלמים מ‑`col`) או רוחב פר‑טור |
| `w:sep` | bool — קו מפריד בין טורים |
| `w:col` | `w` (רוחב הטור) + `space` (מרווח אחריו) — כשהרוחבים אינם שווים |

> במקטע **RTL** (`w:bidi`), סדר הטורים מימין לשמאל. מעבר טור = `<w:br w:type="column"/>`.

### 5.7 שאר מאפייני המקטע

| אלמנט | ערכים | מה עושה |
|---|---|---|
| `w:vAlign` | top / center / both / bottom | **יישור אנכי של התוכן בעמוד** (both=justify אנכי) |
| `w:titlePg` | toggle | הפעל header/footer שונה לעמוד הראשון של המקטע |
| `w:bidi` | toggle | מקטע RTL (משפיע על סדר טורים וברירת כיוון) |
| `w:rtlGutter` | toggle | ה‑gutter בצד ימין |
| `w:textDirection` | lrTb, tbRl… | כיוון זרימה למקטע כולו (EA/אנכי) |
| `w:formProt` | toggle | אפשר עריכה רק בשדות טופס |
| `w:noEndnote` | toggle | אל תציג הערות סיום במקטע |
| `w:docGrid` | `type` (default/lines/linesAndChars/snapToChars), `linePitch`, `charSpace` | רשת מסמך — מספר שורות/תווים קבוע לעמוד (EA) |
| `w:printerSettings` | r:id | הפניה לנתוני מדפסת (לא ויזואלי) |
| `w:sectPrChange` | | מעקב‑שינויים על המקטע (§12) |

> **`docGrid`** משפיע על גובה שורה ב‑EA: `linePitch` קובע גובה שורה קבוע ברשת. מנוע לא‑EA יכול לרוב להתעלם, אך שים לב שהוא יכול לשנות גובה שורה גם בלטינית כש‑`type="lines"`.

---
## 6. טבלאות

מבנה: `w:tbl` → `w:tblPr` (מאפייני טבלה) + `w:tblGrid` (הגדרת עמודות) + שורות `w:tr` (כל אחת `w:trPr` + תאים `w:tc`, וכל תא `w:tcPr` + בלוקים).

```xml
<w:tbl>
  <w:tblPr>…</w:tblPr>
  <w:tblGrid><w:gridCol w:w="4675"/><w:gridCol w:w="4675"/></w:tblGrid>
  <w:tr>
    <w:trPr>…</w:trPr>
    <w:tc><w:tcPr>…</w:tcPr><w:p>…</w:p></w:tc>
    <w:tc>…</w:tc>
  </w:tr>
</w:tbl>
```

### 6.1 `w:tblGrid` — שלד העמודות

| אלמנט | מה עושה | קצה |
|---|---|---|
| `w:gridCol` | `w:w` (twips) — רוחב עמודה לוגית | מספר ה‑gridCol = מספר העמודות הלוגיות. תא יכול לפרוס כמה (gridSpan). הרוחבים האלה הם "preferred" — autofit יכול לשנותם. |

### 6.2 `w:tblPr` — מאפייני טבלה

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:tblStyle` | `<w:tblStyle w:val="TableGrid"/>` | מחיל סגנון טבלה | בסיס לעיצוב מותנה (§6.5) |
| `w:tblpPr` | `leftFromText`,`rightFromText`,`topFromText`,`bottomFromText`,`horzAnchor`(text/margin/page),`vertAnchor`,`tblpX`/`tblpXSpec`(left/center/right/...),`tblpY`/`tblpYSpec` | **טבלה צפה** — מיקום מוחלט + עטיפת טקסט | |
| `w:tblOverlap` | never / overlap | האם טבלה צפה יכולה לחפוף לאחרת | |
| `w:bidiVisual` | toggle | **טבלת RTL** — היפוך ויזואלי של סדר העמודות | קריטי לעברית |
| `w:tblStyleRowBandSize` | int | כמה שורות בכל "פס" (banding) | לסגנון band1/band2 |
| `w:tblStyleColBandSize` | int | כמה עמודות בכל פס | |
| `w:tblW` | `<w:tblW w:w="5000" w:type="pct"/>` | רוחב מועדף של הטבלה | `type`: auto/dxa(twips)/pct/nil. pct ב‑1/50% (5000=100%) |
| `w:jc` | start/end/left/right/center | יישור הטבלה בעמוד | תלוי‑כיוון |
| `w:tblCellSpacing` | `w`+`type` | ריווח בין תאים (טבלה "מרווחת") | |
| `w:tblInd` | `w`+`type` | הזחת הטבלה מהשול המתחיל | |
| `w:tblBorders` | top/left/bottom/right/insideH/insideV (כ‑`CT_Border`) | גבולות ברירת מחדל לטבלה | `insideH`/`insideV`=הקווים הפנימיים |
| `w:shd` | §2.3 | הצללת רקע לכל הטבלה | |
| `w:tblLayout` | `<w:tblLayout w:type="fixed"/>` | `fixed`=רוחבים קבועים מ‑gridCol; `autofit`=התאמה לתוכן | קובע אלגוריתם הרוחב |
| `w:tblCellMar` | top/left/bottom/right (כל אחד `w`+`type`) | שולי תא ברירת מחדל | תא יכול לדרוס ב‑tcMar |
| `w:tblLook` | bitmask/תכונות | אילו חלקי הסגנון המותנה פעילים | §6.5 |
| `w:tblCaption`,`w:tblDescription` | מחרוזת | נגישות (alt text) — לא ויזואלי | |

### 6.3 `w:trPr` — מאפייני שורה

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:trHeight` | `<w:trHeight w:val="567" w:hRule="atLeast"/>` | גובה שורה | `hRule`: auto (לפי תוכן), exact (קבוע, חותך), atLeast (מינימום) |
| `w:cantSplit` | toggle | אל תשבור את השורה בין עמודים | |
| `w:tblHeader` | toggle | **שורת כותרת שחוזרת** בראש כל עמוד | קריטי לעימוד טבלאות ארוכות |
| `w:gridBefore`/`w:gridAfter` | int | תאי‑רשת ריקים לפני/אחרי השורה | יוצר שורה "מוזחת" |
| `w:wBefore`/`w:wAfter` | `w`+`type` | רוחב האזור הריק לפני/אחרי | |
| `w:jc` | יישור השורה (כשהיא צרה מהטבלה) | | |
| `w:tblCellSpacing` | ריווח תאים פר‑שורה | | |
| `w:hidden` | toggle | שורה מוסתרת | |
| `w:cnfStyle` | bitmask | עיצוב מותנה פר‑שורה (§6.5) | |
| `w:ins`/`w:del` | מעקב‑שינויים: שורה שנוספה/נמחקה | | §12 |

### 6.4 `w:tcPr` — מאפייני תא

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:tcW` | `<w:tcW w:w="4675" w:type="dxa"/>` | רוחב מועדף של התא | type כמו tblW |
| `w:gridSpan` | `<w:gridSpan w:val="2"/>` | התא פורס N עמודות לוגיות (מיזוג אופקי) | |
| `w:hMerge` | `restart`/`continue` | מיזוג אופקי בסגנון ישן | חלופה ל‑gridSpan |
| `w:vMerge` | `<w:vMerge w:val="restart"/>` / `<w:vMerge/>` | **מיזוג אנכי**: `restart`=תא ראשון; ללא val (=continue)=המשך המיזוג | התא ה‑continue מצויר ריק, התוכן בא מה‑restart |
| `w:tcBorders` | top/left/bottom/right/insideH/insideV/**tl2br**/**tr2bl** | גבולות התא + אלכסונים | tl2br/tr2bl=קווים אלכסוניים בתא |
| `w:shd` | §2.3 | הצללת התא | גובר על הצללת שורה/טבלה |
| `w:noWrap` | toggle | אל תשבור שורות בתא (התא יתרחב) | |
| `w:tcMar` | top/left/bottom/right | שולי התא (דורס tblCellMar) | |
| `w:textDirection` | lrTb/tbRl/btLr… | כיוון טקסט בתא (טקסט אנכי בכותרות) | |
| `w:tcFitText` | toggle | מתח טקסט למילוי רוחב התא | |
| `w:vAlign` | top / center / bottom | יישור אנכי של התוכן בתא | |
| `w:hideMark` | toggle | התעלם מסימן סוף‑התא בחישוב גובה השורה | |
| `w:cnfStyle` | bitmask | עיצוב מותנה פר‑תא | §6.5 |
| `w:cellIns`/`w:cellDel`/`w:cellMerge` | | מעקב‑שינויים על התא | §12 |

### 6.5 סגנונות טבלה מותנים — `tblStylePr` + `cnfStyle` + `tblLook`

סגנון טבלה (ב‑styles.xml, `type="table"`) יכול להגדיר עיצוב שונה ל**אזורים** שונים דרך `w:tblStylePr w:type="…"`:

| ערך `type` | האזור |
|---|---|
| `wholeTable` | כל הטבלה (בסיס) |
| `firstRow` / `lastRow` | שורת כותרת עליונה / תחתונה |
| `firstCol` / `lastCol` | עמודה ראשונה / אחרונה |
| `band1Horz` / `band2Horz` | פסים אופקיים מתחלפים (שורות) |
| `band1Vert` / `band2Vert` | פסים אנכיים מתחלפים (עמודות) |
| `nwCell` / `neCell` / `swCell` / `seCell` | ארבע פינות הטבלה |

**`w:tblLook`** קובע אילו מהאזורים האלה **פעילים** עבור טבלה ספציפית:

```xml
<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0"
           w:firstColumn="1" w:lastColumn="0"
           w:noHBand="0" w:noVBand="1"/>
```

| תכונה | מה מפעיל |
|---|---|
| `w:firstRow` | החל את firstRow |
| `w:lastRow` | החל את lastRow |
| `w:firstColumn` | החל את firstCol |
| `w:lastColumn` | החל את lastCol |
| `w:noHBand` | בטל פסים אופקיים (band1Horz/band2Horz) |
| `w:noVBand` | בטל פסים אנכיים |
| `w:val` | אותו מידע כ‑bitmask hex (גרסה ישנה) |

**`w:cnfStyle`** (על שורה/תא/פסקה) מציין במפורש לאיזה אזור התא שייך (12 ביטים: firstRow, lastRow, firstColumn, lastColumn, firstRowFirstColumn, ...). מנוע 1:1 משתמש בו כדי להחיל את ה‑tblStylePr הנכון.

### 6.6 פתרון קונפליקט גבולות (כלל Word — קריטי)

כששני תאים שכנים מגדירים גבול שונה לאותו קו, Word בוחר גבול **אחד** מנצח (לא מסכם). סדר הקדימה (מהגבוה לנמוך):

1. עובי גדול יותר (`sz`) מנצח.
2. בעובי שווה — לפי **קדימות סגנון הקו**: double > single > dashed > dotted > … (סדר ST_Border).
3. בשוויון מלא — צבע כהה יותר, ואז לפי מיקום (top/left מנצח).
4. גבול `nil` מאבד תמיד מול גבול קיים; אבל גבול `none` מפורש יכול לבטל גבול‑סגנון.

> בנוסף יש קדימות **מקור**: גבול שמוגדר על התא (`tcBorders`) גובר על `insideH/V` של הטבלה, שגובר על גבול מהסגנון. מנוע 1:1 חייב לחשב לכל קו את המנצח פעם אחת, אחרת מקבלים קווים כפולים/שגויים (בעיה נפוצה בטבלאות RTL).

### 6.7 autofit מול fixed

- `tblLayout="fixed"`: רוחבי העמודות = `gridCol` (מותאם ל‑`tcW`); תוכן נשבר/נחתך לרוחב.
- `tblLayout="autofit"` (ברירת מחדל אם חסר): Word מחשב רוחבים מהתוכן ומ‑`tblW`, עם איזון. אלגוריתם מורכב — מנוע 1:1 צריך מדידת תוכן אמיתית פר‑עמודה ואז חלוקה מידתית בכפוף ל‑`tblW`/רוחב הזמין.

---
## 7. סגנונות — `styles.xml`

הקובץ מכיל: `w:docDefaults` (ברירות מחדל לכל המסמך), `w:latentStyles` (הגדרות ל‑built‑in styles לא‑מוגדרים), ורשימת `w:style`.

### 7.1 `w:docDefaults`

```xml
<w:docDefaults>
  <w:rPrDefault><w:rPr>…</w:rPr></w:rPrDefault>
  <w:pPrDefault><w:pPr>…</w:pPr></w:pPrDefault>
</w:docDefaults>
```

- **שכבת הבסיס** של כל עיצוב. כל פסקה/ריצה יורשת מכאן לפני כל סגנון. מכאן בא לרוב הפונט הבסיסי, גודל 22 (11pt), `widowControl`, ריווח שורה ברירת מחדל.

### 7.2 `w:style` — הגדרת סגנון

**תכונות:**

| תכונה | ערכים | מה עושה |
|---|---|---|
| `w:type` | paragraph / character / table / numbering | סוג הסגנון |
| `w:styleId` | מזהה | המזהה שאליו מפנים (`pStyle`/`rStyle`/`tblStyle`) |
| `w:default` | bool | האם זה ברירת המחדל לסוג שלו (חל כשאין הפניה מפורשת) |
| `w:customStyle` | bool | סגנון משתמש (לא built‑in) |

**ילדים מרכזיים:**

| אלמנט | מה עושה | קצה |
|---|---|---|
| `w:name` | שם תצוגה | יכול להבדל מ‑styleId (מיפוי שמות מקומיים) |
| `w:aliases` | שמות חלופיים | |
| `w:basedOn` | **סגנון אב** — ממנו יורשים | שרשרת ירושה; בלי מעגלים |
| `w:next` | סגנון הפסקה הבאה (אחרי Enter) | לא ויזואלי לרינדור קיים |
| `w:link` | קישור בין סגנון פסקה לסגנון תו תואם | "linked style" |
| `w:autoRedefine` | עדכן את הסגנון אוטומטית מעיצוב ידני | נדיר |
| `w:hidden` / `w:semiHidden` | הסתר מה‑UI | לא משפיע רינדור |
| `w:unhideWhenUsed` | הצג אחרי שימוש | |
| `w:uiPriority` | סדר מיון ב‑UI | |
| `w:qFormat` | סגנון "מומלץ" (כותרות) | |
| `w:locked` | אי‑אפשר להחיל | |
| `w:rsid` | מזהה גרסה | |
| `w:pPr` | מאפייני פסקה של הסגנון | |
| `w:rPr` | מאפייני ריצה של הסגנון | |
| `w:tblPr`/`w:trPr`/`w:tcPr` | מאפייני טבלה/שורה/תא (לסגנון טבלה) | |
| `w:tblStylePr` | עיצוב מותנה (§6.5) | רק type=table |

### 7.3 שרשרת הירושה וה‑resolution

עבור פסקה רגילה, סדר ההצטברות (כל שכבה דורסת/מצטברת על הקודמת):

1. `docDefaults` (pPrDefault + rPrDefault)
2. שרשרת `basedOn` של סגנון הפסקה — **מהשורש כלפי מטה** (הסגנון הבסיסי ביותר ראשון)
3. סגנון הפסקה עצמו (`pStyle`)
4. (לריצה) שרשרת סגנון התו (`rStyle`)
5. עיצוב ישיר (`pPr`/`rPr` בתוך הפסקה/ריצה)

> פירוט מלא כולל טבלאות, מספור ו‑toggle: ראו §16.

### 7.4 `w:latentStyles`

```xml
<w:latentStyles w:defLockedState="0" w:defUIPriority="99"
                w:defSemiHidden="1" w:defUnhideWhenUsed="1" w:defQFormat="0"
                w:count="376">
  <w:lsdException w:name="Normal" w:semiHidden="0" w:uiPriority="0" w:qFormat="1"/>
  …
</w:latentStyles>
```

מגדיר התנהגות ל‑built‑in styles שלא הוגדרו מפורשות במסמך. בעיקר משפיע על ה‑UI; לרינדור — רלוונטי רק אם סגנון מופיע ב‑latent ולא בהגדרה מלאה.

---

## 8. מספור ורשימות — `numbering.xml`

שני רבדים: `w:abstractNum` (תבנית הרשימה) ו‑`w:num` (מופע שמצביע ל‑abstract, עם דריסות אפשריות). פסקה מצביעה ל‑`numId` של `w:num` דרך `numPr`.

```xml
<w:numbering>
  <w:abstractNum w:abstractNumId="0">
    <w:multiLevelType w:val="hybridMultilevel"/>
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/>
      <w:numFmt w:val="decimal"/>
      <w:lvlText w:val="%1."/>
      <w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>
      <w:rPr><w:rFonts w:hint="default"/></w:rPr>
    </w:lvl>
    <w:lvl w:ilvl="1">…</w:lvl>  <!-- עד ilvl=8 -->
  </w:abstractNum>
  <w:num w:numId="1">
    <w:abstractNumId w:val="0"/>
    <w:lvlOverride w:ilvl="0"><w:startOverride w:val="5"/></w:lvlOverride>
  </w:num>
</w:numbering>
```

### 8.1 `w:abstractNum` (תבנית)

| אלמנט/תכונה | מה עושה |
|---|---|
| `@w:abstractNumId` | מזהה התבנית |
| `w:nsid` | מזהה ייחוס יציב (לסנכרון רשימות) |
| `w:multiLevelType` | singleLevel / multilevel / hybridMultilevel | סוג ההיררכיה |
| `w:tmpl` | קוד תבנית | |
| `w:numStyleLink` | מפנה לסגנון מספור (numbering style) | |
| `w:styleLink` | מסמן שזו ההגדרה של סגנון מספור | |
| `w:lvl` | הגדרת רמה (×9, ilvl 0–8) | |

### 8.2 `w:lvl` (רמה)

| אלמנט/תכונה | ערכים | מה עושה |
|---|---|---|
| `@w:ilvl` | 0–8 | מספר הרמה |
| `@w:tplc` | קוד תבנית לרמה | |
| `@w:tentative` | bool | רמה "זמנית" (Word עשוי להחליפה) |
| `w:start` | int | ערך התחלה |
| `w:numFmt` | ST_NumberFormat | פורמט הספרה ([§17.6](#176-st_numberformat-פורמטי-מספור-מלא)). `bullet`=תבליט, `none`=ללא מספר |
| `w:lvlRestart` | int | אפס את הרמה כשרמה X מתקדמת (0=אף פעם) |
| `w:pStyle` | styleId | קושר רמה לסגנון פסקה |
| `w:isLgl` | toggle | הצג את כל הרמות כספרות ערביות (מספור "legal" 1.1.1) |
| `w:suff` | tab / space / nothing | מה בין המספר לטקסט (ברירת מחדל tab) |
| `w:lvlText` | מחרוזת עם `%1`–`%9` | **תבנית הטקסט** של התווית. `%1`=ערך רמה 0, `%2`=רמה 1... למשל `%1.%2.` |
| `w:lvlPicBulletId` | int | תבליט תמונה (מפנה ל‑numPicBullet) |
| `w:legacy` | legacy, legacySpace, legacyIndent | התנהגות מספור ישנה (Word 6) |
| `w:lvlJc` | left/center/right (start/end) | יישור התווית |
| `w:pPr` | מאפייני פסקה לרמה (בעיקר `ind` — ההזחה!) | |
| `w:rPr` | מאפייני ריצה ל**תווית** (גופן/גודל של המספר/תבליט) | |

> **`lvlText` ו‑bullet:** ברשימת תבליטים, `numFmt="bullet"` ו‑`lvlText` מכיל את תו התבליט (למשל `` עם פונט Symbol/Wingdings ב‑rPr). מנוע חייב למפות את התו לפונט הנכון.

### 8.3 `w:num` (מופע) ו‑`w:lvlOverride`

| אלמנט/תכונה | מה עושה |
|---|---|
| `@w:numId` | המזהה שאליו `numPr/numId` מפנה |
| `w:abstractNumId` | מצביע לתבנית |
| `w:lvlOverride` | דריסה פר‑רמה למופע הזה: `w:startOverride` (ערך התחלה חדש) או `w:lvl` מלא (החלפת הגדרת הרמה) |

> **`startOverride`** מאפשר ל‑3 פסקאות עם אותו abstractNum להתחיל ממספרים שונים (numId שונה, abstract זהה). קריטי ל"המשך מספור" מול "התחל מחדש".

### 8.4 `w:numPicBullet`

תבליט שהוא תמונה: `<w:numPicBullet w:numPicBulletId="0"><w:pict>…VML…</w:pict></w:numPicBullet>`.

### 8.5 חישוב המספור (התנהגות מנוע)

- המספור הוא **stateful וגלובלי בסדר המסמך**: צריך מעבר אחד על כל הפסקאות בסדר, לתחזק מונה פר‑(numId, ilvl).
- כניסה לרמה עמוקה יותר ואז חזרה — מפעילה `lvlRestart`.
- פסקה עם `numId="0"` שוברת רצף (אין מספר).
- `isLgl` כופה את כל ה‑`%n` להופיע כעשרוני גם אם רמות אחרות מוגדרות אחרת.

---
## 9. ציור, תמונות, צורות, תיבות טקסט

תוכן גרפי מודרני יושב ב‑`w:drawing` (DrawingML). תוכן ישן ב‑`w:pict` (VML). שניהם בתוך ריצה (`w:r`).

### 9.1 inline מול anchor

```xml
<w:r><w:drawing>
  <wp:inline distT="0" distB="0" distL="0" distR="0"> … </wp:inline>
  <!-- או -->
  <wp:anchor …> … </wp:anchor>
</w:drawing></w:r>
```

- **`wp:inline`** — התמונה היא "תו ענק" בתוך שורת הטקסט (זורמת עם הטקסט).
- **`wp:anchor`** — התמונה **צפה**: מיקום יחסי לעמוד/שוליים/פסקה + עטיפת טקסט.

### 9.2 `wp:inline` — תכונות וילדים

| אלמנט/תכונה | מה עושה |
|---|---|
| `@distT/@distB/@distL/@distR` | מרווח מהטקסט (EMU) |
| `wp:extent` | `cx`,`cy` — גודל התצוגה ב‑**EMU** |
| `wp:effectExtent` | שוליים נוספים לאפקטים (צל וכו') |
| `wp:docPr` | `id`,`name`,`descr`,`title` — מטא/נגישות |
| `wp:cNvGraphicFramePr` | נעילות (locks) |
| `a:graphic` | המעטפת לתוכן הגרפי (ראו §9.4) |

### 9.3 `wp:anchor` — תמונה צפה

| תכונה | מה עושה |
|---|---|
| `@distT/B/L/R` | מרווח מהטקסט מסביב |
| `@simplePos` | אם 1 — השתמש ב‑`wp:simplePos` (x,y מוחלטים) |
| `@relativeHeight` | סדר Z (מי מעל מי) |
| `@behindDoc` | 1=מאחורי הטקסט (רקע/סימן מים), 0=לפניו |
| `@locked`,`@layoutInCell`,`@allowOverlap`,`@hidden` | נעילה / מותר בתוך תא / חפיפה / מוסתר |

**ילדים (סדר מחייב):**

| אלמנט | מה עושה |
|---|---|
| `wp:simplePos` | קואורדינטות מוחלטות (כש‑simplePos=1) |
| `wp:positionH` | מיקום אופקי: `@relativeFrom` (margin/page/column/character/leftMargin/rightMargin/insideMargin/outsideMargin) + `wp:posOffset` (EMU) **או** `wp:align` (left/center/right/inside/outside) |
| `wp:positionV` | מיקום אנכי: `@relativeFrom` (margin/page/paragraph/line/topMargin/bottomMargin/insideMargin/outsideMargin) + posOffset/align (top/center/bottom/inside/outside) |
| `wp:extent` | גודל (EMU) |
| `wp:effectExtent` | שוליי אפקט |
| **סוג עטיפה (אחד)** | ראו §9.5 |
| `wp:docPr`,`wp:cNvGraphicFramePr` | מטא/נעילות |
| `a:graphic` | התוכן |

### 9.4 `a:graphic` → תוכן (תמונה / צורה / קבוצה)

```xml
<a:graphic><a:graphicData uri="…/picture">
  <pic:pic>
    <pic:nvPicPr>…</pic:nvPicPr>
    <pic:blipFill>
      <a:blip r:embed="rId5"/>          <!-- מצביע ל-media דרך rels -->
      <a:srcRect l="0" t="0" r="0" b="0"/> <!-- חיתוך (crop) באלפיות אחוז -->
      <a:stretch><a:fillRect/></a:stretch>
    </pic:blipFill>
    <pic:spPr>
      <a:xfrm rot="0" flipH="0" flipV="0">  <!-- סיבוב (1/60000 מעלה), היפוך -->
        <a:off x="0" y="0"/><a:ext cx="…" cy="…"/>
      </a:xfrm>
      <a:prstGeom prst="rect"/>          <!-- גאומטריה: rect/roundRect/ellipse/… -->
      <a:ln>…</a:ln>                     <!-- מסגרת -->
    </pic:spPr>
  </pic:pic>
</a:graphicData></a:graphic>
```

| `@uri` של graphicData | התוכן |
|---|---|
| `…/picture` | תמונה (`pic:pic`) |
| `…/wordprocessingShape` | צורה/תיבת טקסט (`wps:wsp`) |
| `…/wordprocessingGroup` | קבוצת צורות (`wpg:wgp`) |
| `…/chart` | תרשים (חלק chart נפרד) |
| `…/diagram` | SmartArt |
| `…/wordprocessingCanvas` | קנבס |

**רכיבי תמונה מרכזיים:**

| אלמנט | מה עושה |
|---|---|
| `a:blip @r:embed` | הפניה ל‑`word/media/*` דרך rels (התמונה עצמה) |
| `a:blip @r:link` | תמונה חיצונית מקושרת |
| `a:srcRect` | **חיתוך** — `l/t/r/b` באלפיות אחוז (50000=50%) |
| `a:stretch`/`a:tile` | מתיחה למלא או ריצוף |
| `a:xfrm @rot` | **סיבוב** ביחידות 1/60000 מעלה |
| `a:xfrm @flipH/@flipV` | היפוך אופקי/אנכי |
| `a:prstGeom @prst` | צורת מסגרת (rect, roundRect, ellipse, triangle, … מאות ערכים) |
| `a:custGeom` | גאומטריה מותאמת (path) |
| `a:ln` | קו מתאר (עובי `w` ב‑EMU, צבע, dash, פינות) |
| `a:solidFill`/`a:gradFill`/`a:blipFill`/`a:pattFill`/`a:noFill` | מילוי |
| אפקטים `a:effectLst` | צל (`a:outerShdw`), זוהר, השתקפות, רכות |
| `a:alphaModFix` | שקיפות התמונה |

### 9.5 סוגי עטיפת טקסט (wrap) — סביב anchor

| אלמנט | מה עושה |
|---|---|
| `wp:wrapNone` | אין עטיפה — התמונה מעל/מתחת לטקסט (משולב עם behindDoc) |
| `wp:wrapSquare` | הטקסט עוטף בריבוע סביב התיבה. `@wrapText` (bothSides/left/right/largest) |
| `wp:wrapTight` | עטיפה צמודה למתאר (`wp:wrapPolygon`) |
| `wp:wrapThrough` | כמו tight אבל ממלא גם "חורים" פנימיים |
| `wp:wrapTopAndBottom` | הטקסט מעל ומתחת בלבד, לא בצדדים |

> `@wrapText` ו‑`wrapPolygon` חיוניים לעטיפה 1:1. `bothSides`/`largest` קובעים מאיזה צד הטקסט זורם — חשוב מאוד ב‑RTL.

### 9.6 צורות ותיבות טקסט — `wps:wsp`

```xml
<wps:wsp>
  <wps:spPr>…a:prstGeom, מילוי, קו, a:xfrm…</wps:spPr>
  <wps:style>…הפניות theme לצורה…</wps:style>
  <wps:txbx><w:txbxContent>… פסקאות Word רגילות …</w:txbxContent></wps:txbx>
  <wps:bodyPr anchor="ctr" lIns="…" tIns="…" wrap="square" …/>
</wps:wsp>
```

- **תיבת טקסט** = צורה עם `wps:txbx` שבתוכה `w:txbxContent` עם פסקאות/טבלאות רגילות. מנוע צריך לרנדר אותן בתוך הצורה, עם שוליים פנימיים (`bodyPr lIns/tIns/rIns/bIns`), יישור אנכי (`anchor`=t/ctr/b), וכיוון.
- צורה ללא txbx = צורה גרפית בלבד (מלבן/חץ/וכו') לפי `prstGeom`.

### 9.7 VML (`w:pict`) — fallback ותוכן ישן

```xml
<w:r><w:pict>
  <v:shape style="position:absolute;width:200pt;height:100pt" type="#_x0000_t202">
    <v:textbox><w:txbxContent>…</w:txbxContent></v:textbox>
    <v:fill color="#ffffff"/><v:stroke color="#000000"/>
  </v:shape>
</w:pict></w:r>
```

- VML משמש ל: **סימני מים** (`v:shape` עם `v:textpath`), תיבות טקסט ישנות, ו‑`mc:Fallback` של DrawingML.
- `style` הוא CSS‑like (position, width, height, margin, z-index, rotation, mso-position-*).
- `v:imagedata @r:id` = תמונה ב‑VML.
- מנוע מודרני: אם יש `mc:AlternateContent` — לקרוא את ה‑Choice (DrawingML); ליפול ל‑VML רק כשאין Choice נתמך, או למסמכים ישנים.

### 9.8 תרשימים, SmartArt, OLE

| תוכן | איפה | טיפול במנוע תצוגה |
|---|---|---|
| תרשים (chart) | חלק `word/charts/chartN.xml` (DrawingML chart) | רינדור מלא מורכב; מינימום — להציג כתמונת fallback אם קיימת |
| SmartArt (diagram) | `word/diagrams/*` | לרוב יש `dsp`/תמונת fallback |
| OLE object | `w:object`→`o:OLEObject` + תמונת תצוגה (`v:imagedata`/EMF) | להציג את תמונת התצוגה |

---
## 10. תוכן inline מיוחד

ילדי `w:r` שאינם `w:t` (טקסט), וכן אלמנטים ברמת הפסקה.

### 10.1 תוכן טקסטואלי וסימני שבירה (בתוך `w:r`)

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:t` | `<w:t xml:space="preserve"> טקסט </w:t>` | טקסט ממש | `xml:space="preserve"` חיוני לשמירת רווחים מובילים/עוקבים |
| `w:br` | `<w:br w:type="page"/>` | שבירה: `page` (עמוד), `column` (טור), `textWrapping` (שורה רכה). `@w:clear`=none/left/right/all (היכן להמשיך אחרי עטיפה) | `textWrapping`=Shift+Enter |
| `w:cr` | `<w:cr/>` | מעבר שורה (כמו br textWrapping) | |
| `w:tab` | `<w:tab/>` | תו טאב — קופץ לנקודת הטאב הבאה (§4.5) | |
| `w:noBreakHyphen` | | מקף שלא שובר שורה | |
| `w:softHyphen` | | מקף רך (נקודת מיקוף אופציונלית) | |
| `w:sym` | `<w:sym w:font="Wingdings" w:char="F0E0"/>` | סמל מפונט ספציפי לפי קוד hex | חיוני — לא טקסט רגיל |
| `w:drawing` / `w:pict` / `w:object` | §9 | גרפיקה | |
| `w:ptab` | `@alignment`,`@relativeTo`,`@leader` | טאב מיקום מוחלט (absolute position tab) | |
| `w:lastRenderedPageBreak` | | רמז של Word היכן נשבר עמוד ברינדור הקודם | **לא מחייב** — מנוע מחשב מחדש |

### 10.2 שדות (Fields)

שתי צורות:

**א. שדה פשוט:**
```xml
<w:fldSimple w:instr=" PAGE \* MERGEFORMAT "><w:r><w:t>5</w:t></w:r></w:fldSimple>
```

**ב. שדה מורכב (3 חלקים):**
```xml
<w:r><w:fldChar w:fldCharType="begin"/></w:r>
<w:r><w:instrText xml:space="preserve"> PAGEREF _Toc123 \h </w:instrText></w:r>
<w:r><w:fldChar w:fldCharType="separate"/></w:r>
<w:r><w:t>טקסט תוצאה מאוחסן</w:t></w:r>          <!-- ה-cache; מה שמוצג -->
<w:r><w:fldChar w:fldCharType="end"/></w:r>
```

| חלק | מה עושה |
|---|---|
| `w:fldChar @fldCharType` | `begin` / `separate` (בין קוד לתוצאה) / `end`. `@w:fldLock`,`@w:dirty` |
| `w:instrText` | **קוד השדה** (string) |
| התוכן בין separate ל‑end | תוצאת השדה השמורה (fallback אם לא מחושב מחדש) |

**קודי שדה נפוצים לרינדור:**

| קוד | מה מציג |
|---|---|
| `PAGE` | מספר העמוד הנוכחי (לפי `pgNumType/@fmt`) |
| `NUMPAGES` | סה"כ עמודים |
| `SECTIONPAGES` | עמודים במקטע |
| `PAGEREF bookmark` | מספר העמוד של סימנייה (`\h`=היפר‑קישור) |
| `REF bookmark` | תוכן הסימנייה |
| `STYLEREF "Heading 1"` | טקסט הכותרת הקרובה מסגנון נתון (כותרות רצות) |
| `SEQ name` | מונה רציף (Figure 1, Table 2…) |
| `TOC \o "1-3"` | תוכן עניינים |
| `DATE`/`TIME`/`CREATEDATE` | תאריך/שעה |
| `HYPERLINK "url"` | קישור (לרוב עטוף ב‑`w:hyperlink`) |
| `TC`,`XE`,`INDEX` | רשומות תוכן/אינדקס |
| `=formula` | חישוב (בעיקר בטבלאות) |

> `\* MERGEFORMAT` = שמור עיצוב; `\* Arabic`/`\* roman` = פורמט; `\# "0.00"` = פורמט מספרי; `\@ "dd/MM/yyyy"` = פורמט תאריך. מנוע 1:1 מפענח את ה‑switches.

### 10.3 קישורים — `w:hyperlink`

```xml
<w:hyperlink r:id="rId8" w:anchor="section2" w:tooltip="…" w:history="1">
  <w:r><w:rPr><w:rStyle w:val="Hyperlink"/></w:rPr><w:t>לחץ כאן</w:t></w:r>
</w:hyperlink>
```

| תכונה | מה עושה |
|---|---|
| `@r:id` | יעד חיצוני (URL) דרך rels |
| `@w:anchor` | יעד פנימי (שם סימנייה) |
| `@w:tooltip` | טקסט ריחוף |
| `@w:docLocation`,`@w:history` | מיקום/היסטוריה |

> העיצוב הכחול‑קו‑תחתון בא מסגנון התו `Hyperlink` (לא אוטומטי) — חייב להחיל אותו.

### 10.4 סימניות — `w:bookmarkStart` / `w:bookmarkEnd`

```xml
<w:bookmarkStart w:id="0" w:name="_Toc123"/> … <w:bookmarkEnd w:id="0"/>
```

- `@w:id` מקשר start ל‑end (יכולים להיות במרחק/חופפים). `@w:name`=שם הסימנייה (יעד ל‑PAGEREF/REF/anchor).
- לא ויזואליות בעצמן, אך **חיוניות לשדות** ולניווט. מנוע צריך למפות name→מיקום (עמוד) לצורך PAGEREF.

### 10.5 הערות שוליים וסיום

```xml
<!-- בגוף: -->
<w:r><w:rPr><w:rStyle w:val="FootnoteReference"/></w:rPr>
     <w:footnoteReference w:id="1"/></w:r>
<!-- ב-footnotes.xml: -->
<w:footnote w:id="1"><w:p>…תוכן ההערה…</w:p></w:footnote>
```

| אלמנט | מה עושה |
|---|---|
| `w:footnoteReference @w:id` | סימן ההפניה בגוף (מקבל סגנון `FootnoteReference` — superscript) |
| `w:endnoteReference @w:id` | אותו דבר להערת סיום |
| `w:footnote`/`w:endnote @w:type` | `normal` / `separator` (הקו המפריד) / `continuationSeparator` / `continuationNotice` |
| מאפיינים ב‑settings/sectPr | `pos` (תחתית עמוד/מתחת לטקסט), `numFmt`, `numStart`, `numRestart` |

> מנוע 1:1: הערת שוליים מופיעה **בתחתית העמוד** שבו מופיע הסימן — מחייב שילוב בעימוד (לשריין מקום בתחתית העמוד).

### 10.6 הערות סוקר — `w:comment`

| אלמנט | מה עושה |
|---|---|
| `w:commentRangeStart/End @w:id` | טווח הטקסט שעליו ההערה |
| `w:commentReference @w:id` | סימן ההערה |
| `w:comment` (ב‑comments.xml) | `@w:author`,`@w:date`,`@w:initials` + תוכן |

> בתצוגת קריאה לרוב מציגים בגיליון צד/בלון או מתעלמים; לא משפיע על זרימת הטקסט הראשי.

### 10.7 רובי (פונטי) — `w:ruby`

טקסט הדרכה קטן מעל/ליד טקסט בסיס (נפוץ ב‑EA, קיים גם בהקשרים אחרים):
`w:ruby` → `w:rubyPr` (יישור, גודל, מיקום) + `w:rt` (טקסט הרובי) + `w:rubyBase` (טקסט הבסיס).

### 10.8 נוסחאות — OMML (`m:` namespace)

```xml
<m:oMathPara><m:oMath> … <m:f><m:num>…</m:num><m:den>…</m:den></m:f> … </m:oMath></m:oMathPara>
```

| אלמנט | מה |
|---|---|
| `m:oMathPara` | נוסחה כפסקה (display) |
| `m:oMath` | נוסחה inline |
| `m:f` (שבר), `m:sSup`/`m:sSub` (חזקה/אינדקס), `m:rad` (שורש), `m:nary` (סכום/אינטגרל), `m:d` (סוגריים), `m:func`, `m:m` (מטריצה), `m:r`+`m:t` (טקסט מתמטי) | אבני הבניין |

> רינדור נוסחאות מלא = מנוע נפרד ומורכב. מינימום סביר: לרנדר את הטקסט הליניארי או תמונת fallback. לציין כסטייה מודעת אם לא ממומש מלא.

---

## 11. פקדי תוכן (SDT)

`w:sdt` (Structured Document Tag) — בלוק או inline. מבנה: `w:sdtPr` (מאפיינים) + `w:sdtEndPr` + `w:sdtContent` (התוכן בפועל).

```xml
<w:sdt>
  <w:sdtPr>
    <w:alias w:val="כותרת"/><w:tag w:val="title"/><w:id w:val="123"/>
    <w:lock w:val="sdtContentLocked"/>
    <w:placeholder><w:docPart w:val="DefaultPlaceholder"/></w:placeholder>
    <w:dropDownList>…<w:listItem w:displayText="א" w:value="1"/>…</w:dropDownList>
  </w:sdtPr>
  <w:sdtContent>… פסקאות/ריצות רגילות …</w:sdtContent>
</w:sdt>
```

| אלמנט ב‑sdtPr | מה עושה |
|---|---|
| `w:alias`,`w:tag`,`w:id` | שם תצוגה / תג מזהה לקוד / מזהה |
| `w:lock` | `sdtLocked`/`contentLocked`/`sdtContentLocked`/`unlocked` |
| `w:placeholder` | טקסט מציין מקום |
| `w:showingPlcHdr` | כרגע מציג placeholder |
| `w:dataBinding` | קישור ל‑customXml (`@w:xpath`,`@w:storeItemID`) |
| `w:temporary` | פקד זמני |
| **טיפוסים:** `w:text`,`w:richText`,`w:comboBox`,`w:dropDownList`,`w:date`(@fullDate, format),`w:picture`,`w:checkbox`(w14),`w:docPartObj`/`w:docPartList`,`w:group`,`w:bibliography`,`w:citation`,`w:equation` | סוג הפקד |

> לרינדור: בדרך כלל פשוט מרנדרים את `w:sdtContent` כתוכן רגיל. ה‑checkbox (`w14:checkbox`) דורש מיפוי תו מסומן/לא‑מסומן (`w14:checkedState`/`uncheckedState` — font+char).

---

## 12. מעקב שינויים (Revisions)

כשמעקב שינויים פעיל, Word עוטף תוכן/מאפיינים באלמנטי revision. כולם נושאים `@w:author`,`@w:date`,`@w:id`.

| אלמנט | מה עושה | רינדור |
|---|---|---|
| `w:ins` | טקסט/ריצות **שנוספו** | להציג (אולי בקו‑תחתון/צבע אם "show markup") |
| `w:del` | טקסט **שנמחק** (התוכן ב‑`w:delText` במקום `w:t`) | להסתיר (final) או קו‑חוצה (markup) |
| `w:moveFrom`/`w:moveTo` | טקסט שהוזז | |
| `w:rPrChange` | מאפייני ריצה הקודמים (לפני שינוי) | |
| `w:pPrChange` | מאפייני פסקה קודמים | |
| `w:tblPrChange`/`w:trPrChange`/`w:tcPrChange`/`w:sectPrChange` | מאפיינים קודמים של טבלה/שורה/תא/מקטע | |
| `w:numberingChange` | שינוי מספור (legacy) | |
| `w:cellIns`/`w:cellDel`/`w:cellMerge` | שינויי תא | |

> **קריטי:** במצב "final" (תצוגת קריאה רגילה) — מרנדרים `w:ins` רגיל ו**מתעלמים מתוכן `w:del`**. במצב "show markup" מציגים את שניהם בעיצוב מעקב. `w:delText` הוא **טקסט אמיתי** שאסור לרנדר ב‑final.

---
## 13. ערכת עיצוב — `theme1.xml`

מגדיר את הצבעים והפונטים ש‑`themeColor`/`asciiTheme` מפנים אליהם.

### 13.1 ערכת צבעים — `a:clrScheme`

```xml
<a:clrScheme name="Office">
  <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
  <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
  <a:dk2><a:srgbClr val="44546A"/></a:dk2>
  <a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>
  <a:accent1>…</a:accent1> … <a:accent6>…</a:accent6>
  <a:hlink>…</a:hlink><a:folHlink>…</a:folHlink>
</a:clrScheme>
```

**מיפוי שמות (חשוב!):** ב‑WordprocessingML המיפוי בין `ST_ThemeColor` ל‑slots של ה‑theme אינו 1:1 ישיר — הוא עובר דרך `w:clrSchemeMapping` ב‑settings.xml:

| ST_ThemeColor (במסמך) | סלוט ב‑theme (בד"כ) |
|---|---|
| `text1` / `dark1` | dk1 |
| `background1` / `light1` | lt1 |
| `text2` / `dark2` | dk2 |
| `background2` / `light2` | lt2 |
| `accent1`–`accent6` | accent1–6 |
| `hyperlink` | hlink |
| `followedHyperlink` | folHlink |

> `a:sysClr` (windowText/window) נושא `lastClr` — צבע מטמון אחרון; מנוע יכול להשתמש בו ישירות.

### 13.2 ערכת פונטים — `a:fontScheme`

```xml
<a:fontScheme name="Office">
  <a:majorFont>
    <a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/>
    <a:font script="Hebr" typeface="David"/>      <!-- fallback פר-כתב -->
    <a:font script="Arab" typeface="…"/> …
  </a:majorFont>
  <a:minorFont> … </a:minorFont>
</a:fontScheme>
```

| הפניה ב‑rFonts | מקור |
|---|---|
| `majorHAnsi`/`majorAscii`/`majorBidi`/`majorEastAsia` | `majorFont` (כותרות) — latin/cs/ea בהתאמה |
| `minorHAnsi`/`minorAscii`/`minorBidi`/`minorEastAsia` | `minorFont` (גוף הטקסט) |

> **קריטי לעברית:** `a:font script="Hebr"` ב‑fontScheme נותן את פונט ברירת המחדל לעברית כש‑rFonts מפנה ל‑theme. ה‑`<a:cs>` ו‑script="Hebr" הם המקור לפונט CS.

### 13.3 `a:fmtScheme`

הגדרות מילוי/קו/אפקט לצורות (`fillStyleLst`, `lnStyleLst`, `effectStyleLst`, `bgFillStyleLst`). רלוונטי רק לצורות שמפנות ל‑theme דרך `wps:style`.

---

## 14. הגדרות מסמך — `settings.xml`

הגדרות גלובליות שמשפיעות על רינדור כל המסמך:

| אלמנט | מה עושה | חשיבות לרינדור |
|---|---|---|
| `w:defaultTabStop @w:val` | מרווח טאב ברירת מחדל (twips, בד"כ 720) | גבוהה — טאבים לא מוגדרים |
| `w:evenAndOddHeaders` | header/footer שונים לעמודים זוגיים/אי‑זוגיים | גבוהה |
| `w:mirrorMargins` | שוליים מראתיים (הדפסת ספר) | גבוהה |
| `w:gutterAtTop` | gutter בראש העמוד | בינונית |
| `w:bookFoldPrinting` | הדפסת חוברת | בינונית |
| `w:proofState` | מצב בדיקת איות | אין |
| `w:defaultTableStyle` | סגנון טבלה ברירת מחדל | בינונית |
| `w:autoHyphenation` | מיקוף אוטומטי כללי | גבוהה (שבירת שורה) |
| `w:consecutiveHyphenLimit` | מקס' שורות עוקבות עם מקף | בינונית |
| `w:hyphenationZone` | אזור מיקוף (twips) | בינונית |
| `w:doNotHyphenateCaps` | אל תמקף מילים באותיות גדולות | נמוכה |
| `w:characterSpacingControl` | בקרת ריווח EA (doNotCompress/compressPunctuation/…) | בינונית (EA) |
| `w:drawingGridHorizontalSpacing`/`Vertical` | רשת ציור | נמוכה |
| `w:displayBackgroundShape` | הצג את `w:background` (רקע/סימן מים) | גבוהה |
| `w:documentProtection` | הגנת עריכה | אין (תצוגה) |
| `w:clrSchemeMapping` | מיפוי theme colors (§13.1) | גבוהה |
| `w:themeFontLang @w:val/@w:bidi/@w:eastAsia` | שפת ברירת מחדל לבחירת theme fonts | גבוהה (עברית) |
| `w:compat` → `w:compatSetting` | **דגלי תאימות** רבים שמשנים פריסה לפי גרסת Word | גבוהה — ראו למטה |
| `w:footnotePr`/`w:endnotePr` | מאפייני הערות גלובליים | בינונית |
| `w:defaultParagraphStyle`? | — | |

> **`w:compat`** מכיל עשרות `compatSetting` ודגלים (`doNotExpandShiftReturn`, `balanceSingleByteDoubleByteWidth`, `useWord2013TrackBottomHyphenation`, `splitPgBreakAndParaMark`, ועוד). חלקם משנים שבירת שורה/עמוד בצורה משמעותית. `compatibilityMode` (15=Word2013+) קובע מערך התנהגויות. מנוע 1:1 שמכוון לקבצים מודרניים יכול להניח mode 15, אך כדאי לקרוא דגלים קריטיים.

---

## 15. רקע מסמך וסימני מים

| אלמנט | איפה | מה עושה |
|---|---|---|
| `w:background` | ראש `document.xml` | צבע רקע לכל המסמך (`@w:color`/themeColor) או תמונת רקע (VML `v:background`→`v:fill`). מוצג רק אם `displayBackgroundShape` דלוק (§14). |
| **סימן מים** | ב‑header (לרוב) כ‑VML `v:shape` עם `v:textpath` (טקסט) או `v:imagedata` (תמונה), `style` עם `mso-position` ו‑`behindDoc` | "טיוטה"/"סודי" וכד'. לרוב ב‑`w:pict` בכותרת. |

> סימן מים טקסטואלי = `v:shape type="#_x0000_t136"` (textpath) בכותרת, מוטה באלכסון, צבע אפור שקוף. מנוע 1:1 מרנדר אותו מאחורי תוכן העמוד.

---

## 16. סדר ההחלה והעדיפות

זה הלב של מנוע נכון. עיצוב סופי של ריצה/פסקה מחושב כהצטברות שכבות. **שכבה מאוחרת דורסת מוקדמת** (חוץ מ‑toggle, §16.3).

### 16.1 מאפייני פסקה (pPr) — סדר ההצטברות

1. `w:pPrDefault` (docDefaults)
2. מאפייני פסקה מ**סגנון טבלה** (אם בתוך טבלה) — כולל מותנה (§6.5), לפי סדר wholeTable → band → row/col → cell
3. מאפייני פסקה מ**סגנון המספור** (`lvl/pPr`) — רק לפסקה ממוספרת
4. שרשרת **סגנון הפסקה** (`pStyle`) — מהשורש (`basedOn`) כלפי הסגנון עצמו
5. **עיצוב ישיר** (`w:pPr` בפסקה)

### 16.2 מאפייני ריצה (rPr) — סדר ההצטברות

1. `w:rPrDefault` (docDefaults)
2. rPr מ**סגנון טבלה** (מותנה)
3. rPr מ**סגנון הפסקה** (שרשרת pStyle)
4. rPr מ**סגנון המספור** (`lvl/rPr`) — לתווית בלבד
5. rPr מ**סגנון התו** (`rStyle`, שרשרת basedOn)
6. **עיצוב ריצה ישיר** (`w:rPr` בריצה)

> שים לב: סגנון תו (5) גובר על סגנון פסקה (3) — לכן `Hyperlink` משנה צבע גם בתוך כותרת.

### 16.3 תכונות toggle — לא דריסה אלא XOR

עבור `b, bCs, i, iCs, caps, smallCaps, strike, dstrike, outline, shadow, emboss, imprint, vanish`:
- בין **שכבות סגנון** (docDefaults/style) — XOR.
- **עיצוב ישיר** מנצח: ערך מפורש ב‑rPr ישיר קובע סופית (`val="false"` ⇒ כבוי, גם אם הסגנונות הדליקו).

דוגמה קלאסית: סגנון `Strong` מדליק `b`. בתוך פסקה בסגנון שכבר מודגש, החלת `Strong` ⇒ **לא מודגש** (true XOR true = false). מנוע שמתעלם מזה יציג מודגש שגוי.

### 16.4 מיפוי `w:jc` תלוי‑כיוון (BiDi) — טבלה מחייבת

`jc` מתאר יישור **לוגי**. המיפוי לכיוון פיזי תלוי ב‑`w:bidi` של הפסקה:

| `w:jc` | פסקה LTR (`bidi` כבוי) | פסקה RTL (`bidi` דלוק) |
|---|---|---|
| `start` | שמאל | ימין |
| `end` | ימין | שמאל |
| `left` | שמאל | שמאל |
| `right` | ימין | ימין |
| `center` | מרכז | מרכז |
| `both`/`distribute` | יישור דו‑צדדי | יישור דו‑צדדי (RTL) |

> ערכי `left`/`right` הם **פיזיים** (לא מתהפכים); `start`/`end` הם **לוגיים** (מתהפכים). Word מודרני כותב start/end. מנוע חייב לזהות מאיזה סוג מדובר.

### 16.5 בחירת פונט פר‑תו (BiDi)

באותה ריצה, לכל תו: לפי טווח היוניקוד שלו בחר ascii / hAnsi / eastAsia / cs (§3.2). עברית → `cs` + `szCs`/`bCs`/`iCs`. לטינית → `ascii`/`hAnsi` + `sz`/`b`/`i`. מנוע 1:1 מפצל את הריצה לקטעים פר‑כתב ומחיל את הפונט/גודל/משקל הנכונים.

### 16.6 ירושת רוחב/הצללה/גבול בטבלה

- `tcMar` (תא) דורס `tblCellMar` (טבלה).
- `tcBorders` (תא) > `insideH/V` (טבלה) > גבול מסגנון; פתרון קונפליקט §6.6.
- `shd` תא > שורה (cnfStyle) > טבלה > סגנון.

---
## 17. נספח: טבלאות enum מלאות

רשימות מלאות לכל ה‑enums החשובים. אסור למנוע "ליפול" על ערך לא מוכר — תמיד fallback סביר (לרוב `single`/`decimal`/`auto`).

### 17.1 `ST_Border` — סגנונות גבול (מלא)

**קווים בסיסיים (לרינדור מלא):**
`nil`, `none`, `single`, `thick`, `double`, `dotted`, `dashed`, `dotDash`, `dotDotDash`, `triple`, `thinThickSmallGap`, `thickThinSmallGap`, `thinThickThinSmallGap`, `thinThickMediumGap`, `thickThinMediumGap`, `thinThickThinMediumGap`, `thinThickLargeGap`, `thickThinLargeGap`, `thinThickThinLargeGap`, `wave`, `doubleWave`, `dashSmallGap`, `dashDotStroked`, `threeDEmboss`, `threeDEngrave`, `outset`, `inset`.

**גבולות אמנותיים (art borders — לגבולות עמוד; דורשים אריחי תמונה חוזרים):**
`apples`, `archedScallops`, `babyPacifier`, `babyRattle`, `balloons3Colors`, `balloonsHotAir`, `basicBlackDashes`, `basicBlackDots`, `basicBlackSquares`, `basicThinLines`, `basicWhiteDashes`, `basicWhiteDots`, `basicWhiteSquares`, `basicWideInline`, `basicWideMidline`, `basicWideOutline`, `bats`, `birds`, `birdsFlight`, `cabins`, `cakeSlice`, `candyCorn`, `celticKnotwork`, `certificateBanner`, `chainLink`, `champagneBottle`, `checkedBarBlack`, `checkedBarColor`, `checkered`, `christmasTree`, `circlesLines`, `circlesRectangles`, `classicalWave`, `clocks`, `compass`, `confetti`, `confettiGrays`, `confettiOutline`, `confettiStreamers`, `confettiWhite`, `cornerTriangles`, `couponCutoutDashes`, `couponCutoutDots`, `crazyMaze`, `creaturesButterfly`, `creaturesFish`, `creaturesInsects`, `creaturesLadyBug`, `crossStitch`, `cup`, `decoArch`, `decoArchColor`, `decoBlocks`, `diamondsGray`, `doubleD`, `doubleDiamonds`, `earth1`, `earth2`, `eclipsingSquares1`, `eclipsingSquares2`, `eggsBlack`, `fans`, `film`, `firecrackers`, `flowersBlockPrint`, `flowersDaisies`, `flowersModern1`, `flowersModern2`, `flowersPansy`, `flowersRedRose`, `flowersRoses`, `flowersTeacup`, `flowersTiny`, `gems`, `gingerbreadMan`, `gradient`, `handmade1`, `handmade2`, `heartBalloon`, `heartGray`, `hearts`, `heebieJeebies`, `holly`, `houseFunky`, `hypnotic`, `iceCreamCones`, `lightBulb`, `lightning1`, `lightning2`, `mapPins`, `mapleLeaf`, `mapleMuffins`, `marquee`, `marqueeToothed`, `moons`, `mosaic`, `musicNotes`, `northwest`, `ovals`, `packages`, `palmsBlack`, `palmsColor`, `paperClips`, `papyrus`, `partyFavor`, `partyGlass`, `pencils`, `people`, `peopleWaving`, `peopleHats`, `poinsettias`, `postageStamp`, `pumpkin1`, `pushPinNote2`, `pushPinNote1`, `pyramids`, `pyramidsAbove`, `quadrants`, `rings`, `safari`, `sawtooth`, `sawtoothGray`, `scaredCat`, `seattle`, `shadowedSquares`, `sharksTeeth`, `shorebirdTracks`, `skyrocket`, `snowflakeFancy`, `snowflakes`, `sombrero`, `southwest`, `stars`, `starsTop`, `stars3d`, `starsBlack`, `starsShadowed`, `sun`, `swirligig`, `tornPaper`, `tornPaperBlack`, `trees`, `triangleParty`, `triangles`, `tribal1`–`tribal6`, `twistedLines1`, `twistedLines2`, `vine`, `waveline`, `weavingAngles`, `weavingBraid`, `weavingRibbon`, `weavingStrips`, `whiteFlowers`, `woodwork`, `xIllusions`, `zanyTriangles`, `zigZag`, `zigZagStitch`.

### 17.2 `ST_Underline` — קו תחתון

| ערך | מה |
|---|---|
| `none` | ללא |
| `single` | קו יחיד |
| `words` | קו רק מתחת למילים (לא רווחים) |
| `double` | כפול |
| `thick` | עבה |
| `dotted` / `dottedHeavy` | מנוקד / מנוקד עבה |
| `dash` / `dashedHeavy` | מקווקו / עבה |
| `dashLong` / `dashLongHeavy` | מקפים ארוכים |
| `dotDash` / `dashDotHeavy` | נקודה‑מקף |
| `dotDotDash` / `dashDotDotHeavy` | נקודה‑נקודה‑מקף |
| `wave` / `wavyHeavy` / `wavyDouble` | גלי / גלי עבה / גלי כפול |

### 17.3 `ST_Jc` — יישור

`start`, `end`, `left`, `right`, `center`, `both` (justify), `distribute` (פיזור כולל אות אחרונה), `mediumKashida`/`highKashida`/`lowKashida` (מתיחת קשידה בערבית), `numTab`, `thaiDistribute`.

> הערה: בסכמת 2006 (transitional) מופיעים left/center/right/both; `start`/`end` נוספו בגרסת ISO/strict ו‑Word מודרני כותב אותם. תמוך בשני המקרים (§16.4).

### 17.4 `ST_HighlightColor` — צבעי מרקר

`black`, `blue`, `cyan`, `green`, `magenta`, `red`, `yellow`, `white`, `darkBlue`, `darkCyan`, `darkGreen`, `darkMagenta`, `darkRed`, `darkYellow`, `darkGray`, `lightGray`, `none`.
(16 צבעים קבועים + none — ערכים שמיים, לא hex. מנוע ממפה כל אחד ל‑RGB קבוע.)

### 17.5 `ST_Shd` — תבניות הצללה

`nil`, `clear`, `solid`, `horzStripe`, `vertStripe`, `reverseDiagStripe`, `diagStripe`, `horzCross`, `diagCross`, `thinHorzStripe`, `thinVertStripe`, `thinReverseDiagStripe`, `thinDiagStripe`, `thinHorzCross`, `thinDiagCross`, ואחוזי נקודות: `pct5`, `pct10`, `pct12`, `pct15`, `pct20`, `pct25`, `pct30`, `pct35`, `pct37`, `pct40`, `pct45`, `pct50`, `pct55`, `pct60`, `pct62`, `pct65`, `pct70`, `pct75`, `pct80`, `pct85`, `pct87`, `pct90`, `pct95`.

> `pctNN` = צפיפות תבנית נקודות בין `fill` ל‑`color` (pct50 ≈ ערבוב 50/50). `clear` = רק fill. `solid` = רק color.

### 17.6 `ST_NumberFormat` — פורמטי מספור (מלא)

**מערביים/נפוצים:** `decimal`, `decimalZero`, `upperRoman`, `lowerRoman`, `upperLetter`, `lowerLetter`, `ordinal`, `cardinalText`, `ordinalText`, `hex`, `chicago`, `bullet`, `none`, `numberInDash`.

**עברית (חשוב לפרויקט):** `hebrew1` (אותיות מספריות: א, ב, ג…), `hebrew2` (מספור מלא בגימטריה: א׳, ב׳ … עם גרשיים).

**ערבית/הודית/תאית:** `arabicAlpha`, `arabicAbjad`, `hindiVowels`, `hindiConsonants`, `hindiNumbers`, `hindiCounting`, `thaiLetters`, `thaiNumbers`, `thaiCounting`, `vietnameseCounting`.

**קירילי:** `russianLower`, `russianUpper`.

**מזרח‑אסיה (CJK):** `ideographDigital`, `japaneseCounting`, `aiueo`, `iroha`, `decimalFullWidth`, `decimalHalfWidth`, `japaneseLegal`, `japaneseDigitalTenThousand`, `decimalEnclosedCircle`, `decimalFullWidth2`, `aiueoFullWidth`, `irohaFullWidth`, `ganada`, `chosung`, `decimalEnclosedFullstop`, `decimalEnclosedParen`, `decimalEnclosedCircleChinese`, `ideographEnclosedCircle`, `ideographTraditional`, `ideographZodiac`, `ideographZodiacTraditional`, `taiwaneseCounting`, `ideographLegalTraditional`, `taiwaneseCountingThousand`, `taiwaneseDigital`, `chineseCounting`, `chineseLegalSimplified`, `chineseCountingThousand`, `koreanDigital`, `koreanCounting`, `koreanLegal`, `koreanDigital2`.

> `bullet` = תבליט (התו ב‑`lvlText`). `none` = ללא תווית. fallback בטוח: `decimal`.

### 17.7 `ST_ThemeColor` — צבעי theme

`dark1`, `light1`, `dark2`, `light2`, `accent1`, `accent2`, `accent3`, `accent4`, `accent5`, `accent6`, `hyperlink`, `followedHyperlink`, `background1`, `text1`, `background2`, `text2`, `none`. (מיפוי לסלוטים — §13.1.)

### 17.8 enums קצרים נוספים

| Enum | ערכים | היכן |
|---|---|---|
| `ST_TabJc` (יישור טאב) | clear, left, center, right, decimal, bar, num, start, end | `w:tab/@val` |
| `ST_TabTlc` (מילוי טאב) | none, dot, hyphen, underscore, heavy, middleDot | `w:tab/@leader` |
| `ST_BrType` | page, column, textWrapping | `w:br/@type` |
| `ST_BrClear` | none, left, right, all | `w:br/@clear` |
| `ST_LineSpacingRule` | auto, exact, atLeast | `w:spacing/@lineRule` |
| `ST_HeightRule` | auto, exact, atLeast | `w:trHeight/@hRule` |
| `ST_VerticalJc` (עמוד/תא) | top, center, both, bottom | `sectPr/w:vAlign`, `tcPr/w:vAlign` |
| `ST_VerticalAlignRun` | baseline, superscript, subscript | `w:vertAlign/@val` |
| `ST_TextDirection` | lrTb, tbRl, btLr, lrTbV, tbRlV, tbLrV | `w:textDirection`, `textDirection` בתא |
| `ST_TextAlignment` | auto, baseline, top, center, bottom | `w:textAlignment/@val` |
| `ST_Em` (סימן הדגשה) | none, dot, comma, circle, underDot | `w:em/@val` |
| `ST_TextEffect` (אנימציה) | none, blinkBackground, lights, antsBlack, antsRed, shimmer, sparkle | `w:effect/@val` |
| `ST_SectionMark` | nextPage, continuous, evenPage, oddPage, nextColumn | `sectPr/w:type` |
| `ST_PageOrientation` | portrait, landscape | `w:pgSz/@orient` |
| `ST_TblLayoutType` | fixed, autofit | `w:tblLayout/@type` |
| `ST_Merge` | restart, continue | `w:vMerge`/`w:hMerge` |
| `ST_TblWidth` (סוג רוחב) | nil, pct, dxa, auto | `w:tblW`/`w:tcW`/`w:tblInd`/@type |
| `ST_ChapterSep` | hyphen, period, colon, emDash, enDash | `w:pgNumType/@chapSep` |
| `ST_Hint` | default, eastAsia, cs | `w:rFonts/@hint` |
| `ST_MultiLevelType` | singleLevel, multilevel, hybridMultilevel | `w:multiLevelType/@val` |
| `ST_LevelSuffix` | tab, space, nothing | `w:suff/@val` |
| `ST_DocGrid` | default, lines, linesAndChars, snapToChars | `w:docGrid/@type` |
| `ST_View` (תצוגה) | none, print, outline, masterPages, normal, web | `settings/w:view` |
| `ST_Wrap` (מסגרת) | auto, notBeside, around, none, tight, through | `w:framePr/@wrap` |
| `ST_DropCap` | none, drop, margin | `w:framePr/@dropCap` |
| `ST_CombineBrackets` (EA) | none, round, square, angle, curly | `w:eastAsianLayout/@combineBrackets` |

---

## נספח ב': צ'קליסט כיסוי למנוע רינדור

סדר עבודה מומלץ למימוש (מהקריטי לפינוי):

1. **בסיס טקסט:** rFonts (פר‑כתב), sz/szCs, b/i + CS, color, u, vertAlign, highlight, shd, vanish.
2. **פסקה:** jc (תלוי‑bidi), ind (כולל hanging), spacing (line+before/after), bidi, keepNext/keepLines/pageBreakBefore/widowControl, tabs+leaders.
3. **מקטע ועמוד:** pgSz, pgMar, headers/footers (3 variants + titlePg), cols, pgNumType, sectPr type, vAlign.
4. **סגנונות:** docDefaults → basedOn chain → direct, toggle XOR, rStyle, linked.
5. **מספור:** abstractNum/num, lvlText/numFmt (כולל hebrew1/2), startOverride, lvlRestart, ind מהרמה.
6. **טבלאות:** tblGrid+autofit/fixed, gridSpan/vMerge, גבולות+קונפליקט, tcMar/tblCellMar, vAlign, bidiVisual, tblHeader חוזר, cnfStyle+tblLook+tblStylePr.
7. **ציורים:** inline + anchor (positionH/V, wrap types), pic (crop/rot/flip), תיבות טקסט, behindDoc, VML/AlternateContent.
8. **inline מיוחד:** breaks (page/column/textWrapping), sym, fields (PAGE/PAGEREF/STYLEREF/TOC), hyperlinks, footnotes על העמוד, bookmarks.
9. **theme:** clrScheme+מיפוי, fontScheme (script="Hebr"), themeColor tint/shade.
10. **settings:** defaultTabStop, evenAndOddHeaders, mirrorMargins, autoHyphenation, displayBackgroundShape, compat.
11. **מתקדם/אופציונלי:** w14 effects, OMML math, SmartArt/charts, revisions markup, ruby, art page borders.

> כל פריט שלא ממומש = לתעד כ"סטייה מודעת" בתוכנית הבנייה (§8.2 ב‑[WORD_FIDELITY_VIEWER_PLAN.md](WORD_FIDELITY_VIEWER_PLAN.md)).

---

*סוף המסמך. מקורות: ECMA‑376 / ISO‑IEC 29500 (4th ed.), [MS‑OI29500] (Microsoft), datypic.com OOXML schema reference, officeopenxml.com, Microsoft Learn (Open XML SDK).*
