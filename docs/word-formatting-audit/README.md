# סריקת נאמנות עיצוב Word — לוח ראשי והוראות

> **מהו הקובץ הזה.** זהו הקובץ הראשי של תיקיית הסריקה: הוראות ל‑AI הסורק + לוח מעקב התקדמות.
> **קבצי המשימות** (`01-…​.md` עד `17-…​.md`) נגזרים אחד‑לאחד מסעיפי מסמך הייחוס
> `WORD_FORMATTING_XML_REFERENCE.md`, ומכילים **העתקה מדויקת ומלאה** של פרטי העיצוב שבו.
>
> **חשוב:** ייתכן שמסמך הייחוס המקורי יימחק. לכן כל פרט עיצוב נשמר *בתוך* קבצי המשימות.
> **אסור לערוך את "חלק א' — הייחוס"** באף קובץ משימה — הוא העתק קפוא של המקור.

---

## מטרת הסריקה

לכל פריט עיצוב של Word (כפי שמתועד בייחוס), לקבוע **שני דברים**:

1. **האם הוא ממומש בכלל** במנוע התצוגה.
2. אם כן — **האם המשתמש רואה אותו בדיוק** כפי שהוא נראה ב‑Microsoft Word
   (נאמנות 1:1, פיקסל מול פיקסל). לשם כך יש **לחקור כיצד Word מציג** את הפריט בפועל.

אם פריט אינו ממומש, ממומש חלקית, או אינו נאמן — **רושמים זאת במפורש ל‑AI הבא**.

> שלב זה הוא **סריקה ותיעוד בלבד** — לא משנים מימוש. רק סורקים את הקוד, חוקרים את Word, ומתעדים.

---

## פרוטוקול עבודה ל‑AI הסורק

1. קרא קובץ זה (לוח + הוראות) ואת `02-units.md` (יחידות וטיפוסי ערכים) — בסיס לכל מדידה.
2. בחר את קובץ המשימה הראשון בלוח שסטטוסו ⬜.
3. קרא את **"חלק א' — הייחוס"** של המשימה. זו רשימת *כל* פריטי העיצוב לסריקה.
4. לכל פריט בטבלת **"ב.1 — סריקה פר‑פריט"**:
   - אתר במימוש (קוד) אם הפריט מטופל; מלא עמודת **"ממומש?"** (כן / חלקי / לא).
   - אם ממומש — **חקור כיצד Word מרנדר** את הפריט (יחידות, מקרי קצה, RTL), השווה למימוש,
     ומלא **"נאמן 1:1?"** + **"איך זה נראה ב‑Word (ממצאי מחקר)"**.
   - ציין **קובץ/שורה** במימוש.
5. סכם ב‑**"ב.2 — פערים והוראות ל‑AI הבא"** את כל מה שלא מטופל / לא נאמן / דורש בדיקה.
6. עדכן את **שדה הסטטוס** בראש קובץ המשימה ואת **הלוח** כאן.
7. **אל תשנה לעולם את חלק א'.**

### מקרא סטטוס

| סימן | משמעות |
|---|---|
| ⬜ | טרם נסקר |
| 🔄 | בסריקה (חלקי) |
| ✅ | נסקר במלואו — כל פריט קיבל הכרעה + הוראות ל‑AI הבא היכן שצריך |

---

## חוקי ברזל לסריקה

- **אל תחסיר פריט.** כל אלמנט/תכונה שמופיע בחלק א' חייב לקבל שורה בסריקה (ב.1).
- **Word הוא הקובע.** כשיש סתירה בין מפרט (ECMA‑376/ISO 29500) להתנהגות Word — Word מנצח, המפרט גיבוי.
- **עברית+אנגלית מעורבבות (BiDi).** כל פריט נבדק גם במצב מעורב באותה פסקה / שורה / ריצת טקסט.
- **נאמנות = פיקסל מול פיקסל.** "ממומש" לא מספיק; השאלה היא אם זה *נראה זהה* ל‑Word.
- **הסריקה היא לא קוד.** לא משנים מימוש בשלב זה — רק סורקים, חוקרים ומתעדים.

---

## לוח מעקב התקדמות

| # | קובץ משימה | נושא (סעיף בייחוס) | סטטוס | הערות |
|---|---|---|---|---|
| 01 | [01-container.md](01-container.md) | §1 מבנה המכל: חלקים, יחסים, namespaces | ⬜ | |
| 02 | [02-units.md](02-units.md) | §2 יחידות מידה וטיפוסי ערכים (twips, EMU, toggle, צבעים, shd, border) | ⬜ | |
| 03 | [03-run-rpr.md](03-run-rpr.md) | §3 עיצוב ריצה / תו — `w:rPr` | ⬜ | |
| 04 | [04-paragraph-ppr.md](04-paragraph-ppr.md) | §4 עיצוב פסקה — `w:pPr` | ⬜ | |
| 05 | [05-section-sectpr.md](05-section-sectpr.md) | §5 מקטעים, עמוד, טורים, גבולות, מספור — `w:sectPr` | ⬜ | |
| 06 | [06-tables.md](06-tables.md) | §6 טבלאות — `w:tblPr` / `w:trPr` / `w:tcPr` | ⬜ | |
| 07 | [07-styles.md](07-styles.md) | §7 סגנונות — `styles.xml` | ⬜ | |
| 08 | [08-numbering.md](08-numbering.md) | §8 מספור ורשימות — `numbering.xml` | ⬜ | |
| 09 | [09-drawing-images.md](09-drawing-images.md) | §9 ציור, תמונות, צורות, תיבות טקסט — DrawingML / VML | ⬜ | |
| 10 | [10-inline-special.md](10-inline-special.md) | §10 תוכן inline מיוחד: שבירות, טאבים, סמלים, שדות, קישורים, סימניות, הערות, נוסחאות | ⬜ | |
| 11 | [11-sdt.md](11-sdt.md) | §11 פקדי תוכן — Structured Document Tags (SDT) | ⬜ | |
| 12 | [12-revisions.md](12-revisions.md) | §12 מעקב שינויים (Revisions) | ⬜ | |
| 13 | [13-theme.md](13-theme.md) | §13 ערכת עיצוב — `theme1.xml` (צבעים ופונטים) | ⬜ | |
| 14 | [14-settings.md](14-settings.md) | §14 הגדרות מסמך — `settings.xml` | ⬜ | |
| 15 | [15-background-watermark.md](15-background-watermark.md) | §15 רקע מסמך וסימני מים | ⬜ | |
| 16 | [16-resolution-order.md](16-resolution-order.md) | §16 סדר ההחלה והעדיפות (resolution) | ⬜ | |
| 17 | [17-enums.md](17-enums.md) | §17 נספח: טבלאות enum מלאות | ⬜ | |

---

## נספח: צ'קליסט כיסוי למנוע רינדור (סדר עבודה מומלץ)

> מועתק כלשונו מ"נספח ב'" של מסמך הייחוס. זהו סדר העבודה המומלץ למימוש — מהקריטי לפינוי.
> הוא מפנה לפריטים שמפוזרים בין קבצי המשימות; השתמש בו כדי לתעדף את הסריקה.

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

> כל פריט שלא ממומש = לתעד כ"סטייה מודעת" ב"חלק ב'" של קובץ המשימה הרלוונטי.
