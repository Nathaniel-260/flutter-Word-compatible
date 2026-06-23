# משימה 07 — סגנונות — `styles.xml`

> **מקור:** סעיף §7 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **סטטוס מימוש:** 🔄 פערים מרכזיים (5,19) מומשו; resolveParagraph engine נותר נדחה &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-23

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

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

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:docDefaults` — `rPrDefault` | כן | נאמן | שכבת הבסיס של **כל ריצה**. Word מחיל rPrDefault מתחת לכל סגנון/עיצוב ישיר (פונט, גודל, צבע ברירת‑מחדל). כאן נקרא ל‑`defaultRunStyle` ומוזרק כבסיס במנוע הריצה (`_mergeStyleLayers(docDefaultsRun,…)`). הוא בסיס‑fallback ו**אינו** משתתף ב‑XOR של toggles — תואם ל‑Word. | קריאה `style_parser.dart:71-81`; בסיס `style_engine.dart:151,214-224`; חיווט `reader_context.dart:90-94`+`inline_parser.dart:371` |
| 2 | `w:docDefaults` — `pPrDefault` | כן~ | נאמן~ | בסיס **כל פסקה**. נקרא ל‑`defaultParagraphStyle` ומוחל דרך ה‑resolver הישן (`resolveStyle`) כשורש שרשרת ה‑basedOn. **אך** מנוע הפסקה החדש (`resolveParagraph`) שמיישם pPrDefault נקי **אינו מחווט** — פסקאות עוברות במסלול הישן, וכיסוי ה‑pPr מצומצם (פריט 19). | קריאה `style_parser.dart:58-68`; החלה `reader_context.dart:107,126-129`; לא‑מחווט `style_engine.dart:30-31,164-176` |
| 3 | `w:style` — `type` (paragraph/character/table/numbering) | חלקי | חלקי | נקרא ונשמר; משמש להחלטה אם למזג `defaultParagraphStyle` (paragraph/null) ולזיהוי סגנון טבלה. **ההבחנה paragraph↔character חלשה**: סגנון תו ללא `basedOn` אינו יורש נכון מ"Default Paragraph Font"; `type=numbering` אינו משפיע רינדור. | `style_parser.dart:108`; שימוש `reader_context.dart:126-133` |
| 4 | `w:style` — `styleId` | כן | נאמן | מפתח מפת הסגנונות (`context.styles[styleId]`); כל ההפניות (`pStyle`/`rStyle`/`tblStyle`) נפתרות לפיו. ליבה. | `style_parser.dart:107,135` |
| 5 | `w:style` — `default` (ברירת מחדל לסוג) | **לא** | לא | התכונה `w:default="1"` **אינה נקראת**. במקום, שם ברירת‑המחדל לפסקה **מקושח** ל‑`'Normal'` (`pStyle ?? 'Normal'`). אם ברירת‑המחדל היא styleId אחר → פסקה ללא `pStyle` מקבלת docDefaults בלבד (כי `resolveStyle('Normal')` נכשל) ומאבדת את עיצוב סגנון ברירת‑המחדל האמיתי. ברירת‑מחדל לתו/טבלה אף היא לא מכובדת. | קשיח `block_parser.dart:190,206`; חסר ב‑`style_parser.dart` |
| 6 | `w:style` — `customStyle` | **לא** | n/a | לא נקרא. דגל built‑in מול סגנון‑משתמש — לא ויזואלי, אין השפעת רינדור. | אין |
| 7 | `w:name` (שם תצוגה ≠ styleId) | **לא** | לא (לא ויזואלי) | שם התצוגה אינו נקרא ל‑`w:style` (נקרא רק ל‑`lsdException`/פונטים). הפניות נפתרות לפי styleId, לכן ברוב המקרים אין השפעה; אך מנגנונים התלויים בשם הסגנון (התאמת "Heading 1" ל‑TOC/`STYLEREF`) לא ייתמכו. | קריאה רק ב‑latent `style_parser.dart:90` |
| 8 | `w:aliases` | **לא** | n/a | לא נקרא. שמות חלופיים ל‑UI. אין השפעת רינדור. | אין |
| 9 | `w:basedOn` (שרשרת ירושה, ללא מעגלים) | כן | נאמן | נקרא ומוחל בשני ה‑resolvers: מיזוג root→leaf, עם שמירת‑מעגל (`visited`) ותקרת עומק (12). יורש מאפיינים לאורך השרשרת. | קריאה `style_parser.dart:111`; ירושה `reader_context.dart:111-116`; מנוע `style_engine.dart:104-131,187-196` |
| 10 | `w:next` | **לא** | n/a | לא נקרא. סגנון הפסקה הבאה (אחרי Enter) — רלוונטי לעריכה בלבד, לא לרינדור מסמך קיים. | אין |
| 11 | `w:link` (linked style פסקה↔תו) | **לא** | לא (לא ויזואלי) | לא נקרא. הקישור פסקה↔תו משפיע על ה‑UI; לרינדור הריצה כבר נושאת `rStyle` משלה. | אין |
| 12 | `w:autoRedefine` | **לא** | n/a | לא נקרא. עדכון‑סגנון‑מעיצוב‑ידני בעריכה. לא ויזואלי. | אין |
| 13 | `w:hidden` / `w:semiHidden` | **לא** | n/a | לא נקרא ל‑`w:style` (`semiHidden` נקרא רק ל‑latent ולא מנוצל). מסתיר את הסגנון מגלריית ה‑UI — **אינו** מסתיר תוכן (טקסט מוסתר=`vanish`, משימה 03). אין השפעת רינדור. | קריאה latent בלבד `style_parser.dart:95` |
| 14 | `w:unhideWhenUsed` | **לא** | n/a | נקרא ל‑latent ונשמר ב‑theme, **לא מנוצל**. UI בלבד. | `style_parser.dart:96` (לא מנוצל) |
| 15 | `w:uiPriority` | **לא** | n/a | נקרא רק ל‑latent (`LatentStyleDef`), נשמר ולא מנוצל; ל‑`w:style` לא נקרא. מיון בגלריה בלבד. | `style_parser.dart:97-98` |
| 16 | `w:qFormat` | **לא** | n/a | נקרא רק ל‑latent ולא מנוצל. דגל "מומלץ" ב‑UI. | `style_parser.dart:99` |
| 17 | `w:locked` | **לא** | n/a | לא נקרא. מגבלת עריכה. לא ויזואלי. | אין |
| 18 | `w:rsid` | **לא** | n/a | לא נקרא. מזהה גרסת‑שמירה, לא ויזואלי. | אין |
| 19 | `w:pPr` של סגנון | חלקי | **לא** | **פער מרכזי:** pPr של סגנון מנותח ב‑`_parseParagraphProperties` שמכסה רק jc/spacing/line+rule/ind/shd‑fill/numPr/pBdr‑sides. שאר תכונות הפסקה (`keepNext`,`keepLines`,`widowControl`,`pageBreakBefore`,`bidi`,`tabs`,`outlineLvl`,`textAlignment`,`contextualSpacing`,`suppressAutoHyphens`,`framePr`/drop‑cap) נקראות **רק מ‑pPr הישיר של הפסקה** ב‑block_parser → אם הוגדרו בסגנון בלבד הן **לא מוחלות**. | פירוק מצומצם `docx_style.dart:296-433`; קריאה‑ישירה בלבד `block_parser.dart:209-231,270-281` |
| 20 | `w:rPr` של סגנון | כן~ | נאמן~ | rPr של סגנון יורש דרך מנוע הריצה (`resolveRun`): כיסוי ליבת התו של משימה 03 (b/i+CS, u+style/color, strike, color, shd‑fill, sz, rFonts, highlight, caps/smallCaps/dstrike/outline/shadow/emboss/imprint, vertAlign, spacing‑val, bdr). מאפיינים שנקראים רק מ‑rPr הישיר של הריצה (position/kern/w/fitText/em) **אינם** יורשים מסגנון. | פירוק `docx_style.dart:439-671`; החלה `inline_parser.dart:357-375` |
| 21 | `w:tblPr`/`w:trPr`/`w:tcPr` (סגנון טבלה) | חלקי | חלקי | מסגנון טבלה נחלצים: מ‑`tblPr` → **רק `tblBorders`** (→`tableBorders`, יורש כשאין `tblBorders` ישיר); מ‑`tcPr` → shd/vAlign/tcBorders. **`trPr` של סגנון לא מנותח כלל**; שאר `tblPr` (tblCellMar/tblInd/tblLayout/tblCellSpacing/shd/jc/tblLook) לא נחלץ מהסגנון. | `style_parser.dart:114-115`; tblBorders `docx_style.dart:263-274`; שימוש `table_parser.dart:275-290`; tcPr `docx_style.dart:607-637` |
| 22 | `w:tblStylePr` (עיצוב מותנה — type=table) | חלקי | חלקי | האזורים נפרסים ל‑`tableConditionals` ומוחלים גם בזמן‑קריאה (`_resolveCellStyle`) וגם בזמן‑רינדור (`table_builder`). **פערים:** `wholeTable` נפרס אך **לא מוחל** כבסיס; סדר הקדימות שונה מ‑Word (עמודות ממוזגות אחרי שורות → עמודה גוברת על שורה, הפוך מ‑Word); banding מניח `row%2/col%2` ומתעלם מ‑`tblStyleRow/ColBandSize`. | פירוק `style_parser.dart:119-133`; החלה `table_parser.dart:716-778`; רינדור `table_builder.dart:237-389` |
| 23 | שרשרת resolution: docDefaults → basedOn (מהשורש) → pStyle → rStyle → ישיר | חלקי | נאמן~ | **לריצות** מיושמת במלואה (docDefaults‑run → שרשרת pStyle ⊕ שרשרת rStyle עם XOR בין‑רמתי של toggles → ישיר). **לפסקאות** המנוע (`resolveParagraph`) לא מחווט: מסלול ישן `resolveStyle` (docDefaults→basedOn→pStyle) + מיזוג ישיר ב‑block_parser, **ללא XOR**. סדר מלא: §16. | ריצה `style_engine.dart:136-160`+`inline_parser.dart:371`; פסקה `reader_context.dart:101-136`+`block_parser.dart:200` |
| 24 | `w:latentStyles` (+`lsdException`) — השפעה על רינדור כשאין הגדרה מלאה | **לא** | לא | נפרס (semiHidden/unhideWhenUsed/uiPriority/qFormat) ונשמר ב‑`theme.latentStyles`, אך **לא נצרך כלל** ברינדור. תוצאה: built‑in style שמופיע רק ב‑latent (ללא `w:style` מלא) → `resolveStyle` נכשל ונופל ל‑'Normal'/docDefaults במקום לברירות‑המחדל המובנות של אותו סגנון. | פירוק `style_parser.dart:85-101`; אחסון‑בלבד `docx_theme.dart:32,219` |

### ב.2 — פערים והוראות ל‑AI הבא

- **`w:default="1"` לא נקרא — שם ברירת‑המחדל מקושח ל'Normal' (פריט 5, קריטי).** `block_parser.dart:190,206` משתמש ב‑`pStyle ?? 'Normal'`. במסמכים שבהם סגנון ברירת‑המחדל לפסקה אינו "Normal" (למשל "Standard" מ‑LibreOffice, או לוקליזציה), כל פסקה ללא `pStyle` תאבד את עיצוב הסגנון. **המלצה:** בעת פירוק styles.xml, לאתר את ה‑`w:style` עם `w:default="1"` לכל `type` (paragraph/character/table) ולשמור את ה‑styleId; להחליף את ה‑'Normal' הקשיח בערך הזה.
- **pPr של סגנון מנותח חלקית (פריט 19, קריטי).** `keepNext`/`keepLines`/`widowControl`/`pageBreakBefore`/`bidi`/`tabs`/`outlineLvl`/`textAlignment`/`contextualSpacing`/`framePr` המוגדרים **בסגנון** לא מוחלים — הם נקראים רק מ‑pPr הישיר ב‑`block_parser.dart:209-231`. **המלצה:** לאחד את הפירוק — או להרחיב את `_parseParagraphProperties` (`docx_style.dart:296`) לכלול את התכונות האלה, ואז למשוך אותן מ‑`finalProps` במקום מ‑`pPr` הישיר; או לקרוא אותן גם מהסגנון הנפתר. זה גם תנאי מקדים לכך שכותרות (Heading styles) המגדירות keepNext/pageBreakBefore יתנהגו כמו ב‑Word.
- **מנוע הפסקה `resolveParagraph` לא מחווט (פריטים 2, 23).** קיים ב‑`style_engine.dart:164-176` אך לא בשימוש; פסקאות עוברות במסלול הישן `resolveStyle` שאינו מחיל toggle‑XOR ברמת הפסקה ואינו מיישם pPrDefault באותה נאמנות כמו מסלול הריצה. **המלצה:** לחווט את `resolveParagraph` ב‑block_parser (במקביל לאופן ש‑`resolveRun` מחווט ב‑inline_parser), ולוודא golden מול Word לאינטראקציית toggle ישיר↔סגנון (ה‑`TODO(golden)` ב‑`style_engine.dart:156-159`).
- **`tblStylePr` — `wholeTable`, סדר קדימות, ו‑bandSize (פריט 22).** (א) `tableConditionals['wholeTable']` נפרס אך לא מוחל כבסיס ב‑`_resolveCellStyle` (`table_parser.dart:716`); (ב) הקדימות הפוכה מ‑Word — לפי ISO הסדר (מהנמוך לגבוה) הוא wholeTable→bands→firstCol/lastCol→firstRow/lastRow→פינות, אך כאן עמודות ממוזגות **אחרי** שורות; (ג) banding מתעלם מ‑`tblStyleRowBandSize`/`tblStyleColBandSize` (מניח 1). ראו גם משימה 06.
- **`trPr` של סגנון טבלה + רוב `tblPr` לא נחלצים (פריט 21).** `style_parser` קורא מהסגנון רק `tblPr/tblBorders` ו‑`tcPr`; `trPr` (גובה שורה/tblHeader/cantSplit מהסגנון) ושאר `tblPr` (tblCellMar/tblInd/tblLayout/jc/shd) אובדים. לתעד מול משימה 06.
- **`latentStyles` נפרס אך לא נצרך (פריט 24).** נשמר ב‑`theme.latentStyles` ללא שימוש. השפעה אמיתית רק כשמסמך מפנה ל‑built‑in style שאינו מוגדר כ‑`w:style` מלא — אז הוא נופל ל‑Normal במקום לברירות‑המחדל המובנות של אותו סגנון (נדיר ב‑.docx שנשמר מ‑Word, נפוץ יותר ב‑.docx מינימליים). לתעד כסטייה מודעת; פתרון מלא דורש טבלת built‑in styles מובנית.
- **מאפיינים לא‑ויזואליים / UI‑בלבד (פריטים 6–8, 10–18).** `customStyle`/`aliases`/`next`/`autoRedefine`/`hidden`/`semiHidden`/`unhideWhenUsed`/`uiPriority`/`qFormat`/`locked`/`rsid` — אין צורך ברינדור; לתעד כ"לא רלוונטי לתצוגה". **חריג לבדיקה:** `w:name` (פריט 7) ו‑`w:link` (פריט 11) עשויים להידרש לעתיד אם יתווסף תמיכה ב‑`STYLEREF`/TOC המתאימים סגנון לפי שם.
- **`StyleResolver`/`ResolvedStyle` הישן הוא קוד מת.** `resolved_style.dart` מגדיר resolver חלופי שאינו מחווט לאף נתיב ייצור (רק טסטים). אם המנוע (`DocxStyleResolver`) יתבסס — למחוק את הישן כדי למנוע בלבול בין שני ה‑resolvers.

### ב.3 — עדכון מימוש (בוצע ע"י ה‑AI המבצע, 2026‑06‑23)

> מבוצע לפי `PROMPTER.md`. בדיקות נלוות; `flutter analyze` נקי; הסוויטה ירוקה.

**מומש 1:1:**

| פריט | מה תוקן | קובץ | בדיקה |
|---|---|---|---|
| 5 | `w:default="1"` (סוג paragraph) נקרא → `ReaderContext.defaultParagraphStyleId`; פסקה ללא `pStyle` יורשת את סגנון ברירת‑המחדל האמיתי (למשל 'Standard') במקום 'Normal' קשיח | `style_parser.dart`, `reader_context.dart`, `block_parser.dart` | `styles_default_07_test.dart` |
| 19 (רוב) | **נסגר דרך משימה 04:** pPr של סגנון — `keepNext`/`keepLines`/`widowControl`/`pageBreakBefore`/`bidi`/`outlineLvl`/`textAlignment`/`contextualSpacing`/`suppressAutoHyphens` נקראים ל‑`DocxStyle` ומיושבים `direct ?? style ?? default`. קריטי לעברית (סגנון עם `w:bidi`) ולכותרות (keepNext). | `docx_style.dart`, `block_parser.dart` | `paragraph_ppr_04_test.dart` |

**נותר נדחה / סטיות מודעות:**

- **`resolveParagraph` engine לא מחווט (2, 23):** פסקאות עדיין במסלול `resolveStyle` הישן (ללא toggle‑XOR ברמת פסקה); ריפקטור עם השלכות golden — נדחה (`TODO(golden)` ב‑`style_engine.dart`).
- **`tabs`/`framePr` של סגנון (חלק מ‑19):** עדיין נקראים מ‑pPr ישיר בלבד (סמנטיקת `clear` של tabs מורכבת) — סטייה מודעת.
- **`trPr` של סגנון + רוב `tblPr` (21), `tblStylePr` wholeTable/קדימות/bandSize (22), `latentStyles` (24):** ראו גם משימה 06 — נותרו פערים מתועדים.
- **מאפיינים לא‑ויזואליים/UI (6–18 חלקם):** `customStyle`/`aliases`/`next`/`link`/`hidden`/`uiPriority`/`qFormat`/`rsid` וכו' — לא רלוונטיים לתצוגה.
