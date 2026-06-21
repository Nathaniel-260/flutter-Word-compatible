# משימה 03 — עיצוב ריצה / תו — `w:rPr`

> **מקור:** סעיף §3 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-19

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

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
| `w:highlight` | `<w:highlight w:val="yellow"/>` | סימון מרקר (17 צבעים קבועים) | ערכים: [§17.4](17-enums.md). `none`=ללא. שונה מ‑shd! |
| `w:u` | `<w:u w:val="single" w:color="FF0000"/>` | קו תחתון | val: [§17.2](17-enums.md). `words`=רק מתחת מילים, לא רווחים. תומך `color`/theme. |
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

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

> **היכן ממומש.** צינור ה‑rPr עובר בארבעה קבצים:
> **(1) פיענוח ריצה בגוף המסמך** — `docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart`
> (`parseRun`, שורה 275): קורא `w:rStyle`, בונה `DocxStyle.fromXml` מה‑rPr הישיר, פותר דרך מנוע הסגנונות,
> ומעתיק את התכונות המתקדמות (rtl/bCs/iCs/szCs/kern/position/w/fitText/em/vanish) ל‑`DocxText`.
> **(2) פיענוח תכונות rPr** — `docx_creator/.../models/docx_style.dart` (`_parseRunProperties`, שורה 439).
> **(3) פתרון סגנון/XOR** — `docx_creator/.../models/style_engine.dart` (`resolveRun`, שורה 136).
> **(4) הפיכה ל‑TextStyle ורינדור** — `docx_file_viewer/lib/src/layout/span_factory.dart`
> (`resolveRunStyle`, שורה 167; פיצול פר‑כתב `resolveRunSegments`/`classifyScript`).
> מודל הריצה: `docx_creator/lib/src/ast/docx_inline.dart` (`DocxText`); מודל הפונט: `docx_font.dart`.
> ⚠️ **מתקדם שנקרא אך לא מרונדר:** `w:position`,`w:w`,`w:fitText`,`w:em` נקראים ל‑`DocxText` ומיוצאים
> חזרה ל‑XML, אך **אינם משפיעים על הרינדור** (ה‑viewer לא משתמש בשדות אלו).

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `rPr` בשלושת ההקשרים (r / pPr mark / style+docDefaults) | חלקי | חלקי | (א) ריצה ב‑`w:r` ו‑(ג) סגנון+docDefaults מטופלים. **(ב) mark run properties** (rPr **בתוך** pPr — עיצוב תו סוף‑הפסקה) **לא נקרא** — `_parseParagraphProperties` מתעלם מ‑rPr. משפיע על גובה פסקה ריקה וסימן הפסקה ב‑Word. | `inline_parser.dart:347-375`; `docx_style.dart:138-202`; חסר: `docx_style.dart:296` (pPr) |
| 2 | `w:rStyle` (סגנון תו) | כן | נאמן~ | נקרא ונפתר דרך מנוע הסגנונות: docDefaults → שרשרת סגנון‑פסקה ⊕ שרשרת סגנון‑תו → ישיר. Word ממקם סגנון תו בין סגנון פסקה לעיצוב ישיר — תואם. מגבלות ה‑XOR/דריסה כמשימה 02 פריט 13. | `inline_parser.dart:348-375`; `style_engine.dart:136-160` |
| 3 | `w:rFonts` — `ascii` | כן | נאמן | נקרא; משמש לקטעי לטינית (`classifyScript`→latin). | `docx_style.dart:558`; `span_factory.dart:266` |
| 4 | `w:rFonts` — `hAnsi` | חלקי | חלקי | נקרא, אך הבחירה היא `ascii ?? hAnsi` — Word בוחר hAnsi לפי גבול U+007F (High‑ANSI), כאן כל הלטינית נכרכת ל‑ascii ו‑hAnsi משמש רק כאשר ascii חסר. זניח כש‑ascii=hAnsi (המקרה הרגיל). | `span_factory.dart:267` |
| 5 | `w:rFonts` — `cs` (עברית/ערבית — קריטי) | כן | נאמן | נקרא; משמש לקטעי כתב‑מורכב (`classifyScript`→complex). זהו הליבה לעברית ועובד. | `docx_style.dart:560`; `span_factory.dart:252-256` |
| 6 | `w:rFonts` — `eastAsia` | חלקי | **לא** | נקרא למודל אך **לא נבחר לעולם**: `classifyScript` מכיר 2 כתבים בלבד (latin/complex), ו‑CJK נכרך ל‑latin → תווי מזרח‑אסיה מקבלים את פונט ה‑ascii במקום eastAsia. | `docx_style.dart:561`; `font_resolver.dart:12,34-61` |
| 7 | `w:rFonts` — `asciiTheme`/`hAnsiTheme`/`eastAsiaTheme`/`csTheme` | כן | נאמן~ | כולם נקראים; נפתרים מ‑`docxTheme.fonts.getFont`: `csTheme`→complex, `asciiTheme`/`hAnsiTheme`/`eastAsiaTheme`→latin. תלוי בקיום theme1.xml (משימה 13). `eastAsiaTheme` משמש רק כ‑fallback ללטינית. | `docx_style.dart:563-566`; `span_factory.dart:252-264` |
| 8 | `w:rFonts` — `hint` (default/eastAsia/cs) | חלקי | חלקי | `hint="cs"` בלבד מטופל: גורם לתווים "ניטרליים" (פיסוק/רווח) להסתווג כ‑complex. `hint="eastAsia"`/`default` אינם משפיעים. | `inline_parser.dart` (hint→fonts); `span_factory.dart:398`; `font_resolver.dart:89,106` |
| 9 | בחירת פונט **פר‑תו** לפי טווח יוניקוד (פיצול ריצה) | כן | נאמן~ | ממומש: `classifyScript` חותך את הריצה לקטעי כתב הומוגניים, וכל קטע מקבל font/sz/b/i משלו — "א" מקבל cs, "A" מקבל ascii (בדיוק כמו Word). מגבלה: 2 כתבים בלבד (EA מקופל ל‑latin, פריט 6). | `span_factory.dart:386-421`; `font_resolver.dart:70-141` |
| 10 | `w:b` + `w:bCs` (toggle/XOR) | כן | חלקי | שניהם נקראים; הבחירה פר‑כתב (`bCs` לקטע complex, נופל ל‑`b`). XOR בין רמות סגנון מטופל אך עיצוב **ישיר דורס** במקום XOR, ו‑XOR לא חוצה את שרשרת `basedOn` (משימה 02 פריט 13, TODO golden). | `docx_style.dart:480-484`; `inline_parser.dart:428`; `span_factory.dart:174-176` |
| 11 | `w:i` + `w:iCs` (toggle) | כן | חלקי | זהה ל‑b: `iCs` לקטע complex, נופל ל‑`i`; אותן מגבלות XOR/דריסה ישירה. | `docx_style.dart:486-489`; `inline_parser.dart:429`; `span_factory.dart:179-180` |
| 12 | `w:caps` (ויזואלי, טקסט נשאר lowercase) | כן | נאמן | התוכן מומר ל‑uppercase להצגה בלבד (`resolveContent`); מחרוזת המקור (לחיפוש/העתקה) נשמרת. תואם את Word (ויזואלי בלבד). | `span_factory.dart:146-151`; `docx_style.dart:583` |
| 13 | `w:smallCaps` | כן | **לא** | מקורב גרוע: כל התווים הופכים uppercase ואז הריצה כולה מוקטנת ×0.85. ב‑Word אותיות **קטנות** הופכות לקפיטל מוקטן (≈0.7 מגובה הקפיטל) בעוד הגדולות נשארות בגודל מלא — כאן גם הגדולות מוקטנות, ואין גליף small‑cap אמיתי. | `span_factory.dart:147,287-289` |
| 14 | `w:strike` (קו חוצה יחיד) | כן | נאמן | `lineThrough` מוחל. | `docx_style.dart:511-514`; `span_factory.dart:207-216` |
| 15 | `w:dstrike` (קו חוצה כפול) | כן | חלקי | מוחל כ‑`decorationStyle.double`, **אך** רק כאשר אין קו תחתון (Flutter חולק decorationStyle יחיד לכל הקישוטים) — dstrike+underline יאבד את הכפילות. | `span_factory.dart:207-212` |
| 16 | `w:outline` (מתאר תווים) | כן | חלקי | מקורב: `Paint` stroke ברוחב 0.5 ללא מילוי, וצבע הטקסט מתאופס. לא מתאר חלול אמיתי בעובי תלוי‑גודל כמו Word. | `span_factory.dart:328-335` |
| 17 | `w:shadow` (צל לתו) | כן | חלקי | מקורב: `Shadow` יחיד offset (1,1) blur 2 שחור 30%. לא תואם בדיוק את צל Word (כיוון/עובי). | `span_factory.dart:291-299` |
| 18 | `w:emboss` (תבליט) | כן | חלקי | מקורב: שני צללים (לבן עליון‑שמאל + שחור תחתון‑ימין). אפקט תבליט סביר אך לא פיקסל‑מדויק. | `span_factory.dart:300-312` |
| 19 | `w:imprint` (חריטה) | כן | חלקי | מקורב: שני צללים בכיוון הפוך ל‑emboss. סביר, לא מדויק. | `span_factory.dart:313-326` |
| 20 | `w:vanish` (טקסט מוסתר — השפעה על עימוד) | כן | נאמן~ | `hidden` נקרא; הריצה מדולגת במדידה+רינדור+אינדקס‑חיפוש (לא תופסת מקום). תואם תצוגת‑הדפסה. Word עם "הצג טקסט מוסתר" דלוק *כן* מציג ותופס מקום — מצב זה לא נתמך. | `inline_parser.dart:430`; `span_factory.dart:503`; `paragraph_builder.dart:239,726` |
| 21 | `w:specVanish` (סימן פסקה מוסתר) | **לא** | לא | לא נקרא כלל. נוגע לכותרות מקופלות (always‑hidden paragraph mark) — לא נתמך. | אין |
| 22 | `w:webHidden` | **לא** | לא | לא נקרא. בתצוגת print Word מציג טקסט זה; ההתעלמות מקובלת אך מתועדת. | אין |
| 23 | `w:noProof` | **לא** | n/a | לא נקרא — אך אין לו השפעה ויזואלית (רק ביטול בדיקת איות), כך שאין פגיעה בנאמנות. | אין |
| 24 | `w:snapToGrid` (ריצה) | **לא** | לא | לא נקרא. משפיע על יישור תווים לרשת המסמך (docGrid, בעיקר EA) — לא נתמך. | אין |
| 25 | `w:color` (val + themeColor + auto) | כן | חלקי | val(hex)+themeColor+themeTint/Shade נקראים ומוחלים (`resolveColor`). `auto`→צבע גוף עם היפוך near‑black על רקע גלובלי כהה — אך Word בוחר שחור/לבן מול ה‑`shd` המקומי שמאחורי הטקסט (משימה 02 פריט 15). themeColor עובד (משימה 13). | `docx_style.dart:516-527`; `span_factory.dart:218-226,706-737` |
| 26 | `w:sz` (half-points) | כן | נאמן | `val/2` pt → `×1.333` px; משמש לקטעי לטינית. | `docx_style.dart:546-553`; `span_factory.dart:241-244` |
| 27 | `w:szCs` (גודל CS/עברית — חיוני) | כן | נאמן | `fontSizeCs` נקרא ומוחל לקטעי complex (נופל ל‑`sz` אם חסר) — עברית יכולה לקבל גודל שונה מהלטינית באותה ריצה. | `inline_parser.dart:431`; `span_factory.dart:242` |
| 28 | `w:highlight` (17 צבעים קבועים) | כן | נאמן~ | 17 הערכים ממופים ל‑enum ומרונדרים כ‑backgroundColor. הצבעים הם צבעי Material (למשל darkYellow→yellow.shade800), קירוב גוון — לא הפלטה המדויקת של Word. ראו [§17.4](17-enums.md). | `docx_style.dart:570-581`; `span_factory.dart:237-239,794-831` |
| 29 | `w:u` (val + color/theme + `words`) | כן | חלקי | val ממופה לתבניות Flutter (single/double/dotted/dashed/wavy + עובי 2.5 ל‑heavy); color/theme מוחלים. **`words`** ממופה ל‑solid (קו רציף גם מתחת לרווחים) — לא נאמן. עובי thick=×2.5 קירוב. | `docx_style.dart:490-510`; `span_factory.dart:191-205,761-791` |
| 30 | `w:em` (סימן הדגשה EA) | חלקי | **לא** | `emphasisMark` **נקרא** ל‑`DocxText` ומיוצא חזרה ל‑XML — אך **לא מרונדר** (ה‑viewer לא מצייר את הנקודות/עיגולים מעל/מתחת התווים). | `inline_parser.dart:436-437`; `enums.dart:297`; (לא מרונדר) |
| 31 | `w:effect` (אנימציה ישנה) | **לא** | לא | לא נקרא. האנימציה (sparkle/lights…) לא מיושמת; הטקסט מוצג סטטי ממילא, אך גם אפקט סטטי כלשהו אובד. | אין |
| 32 | `w:spacing` (ריצה — tracking, twips שלילי) | כן | נאמן~ | `characterSpacing` (twips, כולל שלילי) → `letterSpacing = val/15` (96 DPI). תואם tracking של Word; קירוב תת‑פיקסלי בלבד. | `docx_style.dart:538-544`; `span_factory.dart:369-370` |
| 33 | `w:position` (הרמה/הנמכה half-points) | **לא** | לא | `raiseLowerHalfPoints` **נקרא** ל‑`DocxText` ומיוצא חזרה — אך **לא מוחל** ברינדור. הרמה/הנמכה מקו הבסיס ללא שינוי גודל אינה מתרחשת; הטקסט יושב על קו הבסיס הרגיל. | `inline_parser.dart:433`; (לא בשימוש ב‑span_factory) |
| 34 | `w:kern` (kerning מגודל מסוים) | כן | חלקי | `kernMinHalfPoints` נקרא; כש‑גודל הפונט ≥ הסף מופעל `FontFeature.enable('kern')`. קירוב: feature ה‑kern לרוב דלוק כברירת מחדל ב‑Flutter, כך שהאפקט בפועל מינורי; הסף מכובד. | `inline_parser.dart:432`; `span_factory.dart:337-353` |
| 35 | `w:w` (מתיחה אופקית 1–600%) | **לא** | לא | `charScalePercent` **נקרא** ל‑`DocxText` ומיוצא חזרה — אך **לא מוחל**. אין מתיחה/כיווץ אופקי של רוחב התווים (אין `transform`/scaleX על הקטע). | `inline_parser.dart:434`; (לא בשימוש) |
| 36 | `w:fitText` (val + id) | **לא** | לא | `fitTextTwips` **נקרא** (val בלבד) ומיוצא חזרה — אך **לא מוחל**; `id` (קיבוץ ריצות) לא נקרא. אין דחיסה/מתיחה לרוחב נתון. | `inline_parser.dart:435`; (לא בשימוש) |
| 37 | `w:bdr` (מסגרת ריצה + מיזוג רצף) | חלקי | **לא** | נקרא (`_parseBorderSide`→`textBorder`) ומרונדר כ‑`Container` עם `Border.all` סביב הריצה. פערים: (א) **`w:space` לא מכובד** (padding קבוע 2px); (ב) **אין מיזוג** רצף ריצות בעלות אותו bdr (כל ריצה ממוסגרת בנפרד); (ג) מרונדר רק כשאין התאמת חיפוש; (ד) ה‑**measurer לא ממדל את תיבת המסגרת** → אי‑התאמת geometry בין מדידה לרינדור. | `docx_style.dart:599-604,686-713`; `paragraph_builder.dart:892-918` |
| 38 | `w:shd` (הצללת ריצה — שונה מ‑highlight) | חלקי | חלקי | `fill`/`themeFill`+tint/shade נקראים ומרונדרים כרקע אחיד מאחורי הריצה. **`w:val`** (תבנית ST_Shd) ו‑**`w:color`** (צבע התבנית) **לא נקראים** → `val="solid"` ותבניות pct/stripe יוחמצו (משימה 02 פריטים 18,20). | `docx_style.dart:529-536`; `span_factory.dart:228-236` |
| 39 | `w:rtl` (ריצת RTL — קובע החלת CS) | חלקי | חלקי | `rtl` **נקרא** ל‑`DocxText` ומיוצא — אך **לא משמש**: כיוון הריצה והחלת מאפייני ה‑CS נקבעים מסיווג היוניקוד (`classifyScript`/`text_direction_detector`), לא מהדגל. לעברית אמיתית התוצאה זהה; אך `w:rtl` מפורש על תוכן ניטרלי/לטיני (כפיית סדר RTL לספרות/פיסוק) — מתעלמים. | `inline_parser.dart:427`; `font_resolver.dart:70-141`; (הדגל לא בשימוש) |
| 40 | `w:cs` (דגל Complex Script) | **לא** | חלקי | הדגל `w:cs` (להבדיל מתכונת הפונט `w:cs`) **לא נקרא**; ההחלטה אם להחיל עיצוב CS נגזרת מסיווג היוניקוד. עובד לעברית בפועל, אך מתעלם מהדגל המפורש. | (לא נקרא); `font_resolver.dart:34-61` |
| 41 | `w:lang` (val/bidi/eastAsia) | **לא** | לא | לא נקרא. משפיע על מיקוף, איות ובחירת fallback — השפעה ויזואלית מועטה למטרותינו, אך מתועד. | אין |
| 42 | `w:eastAsianLayout` (combine/combineBrackets/vert/vertCompress) | **לא** | לא | לא נקרא. "Two lines in one"/טקסט אנכי/דחיסה — תופעות EA לא נתמכות. | אין |
| 43 | `w:oMath` (ריצת נוסחה) | חלקי | **לא** | OMML מקופל ל**טקסט ליניארי** (שרשור `m:t`) כ‑placeholder — התוכן לא אובד, אך אינו מעומד כנוסחה (Plan §K.6). | `inline_parser.dart:170-176,266-272`; `block_parser.dart:117-118` |
| 44 | `w:rPrChange` (revision על rPr) | **לא** | n/a | מטא‑דאטה של מעקב‑שינויים על rPr לא נקרא. מעקב‑שינויים מטופל בהצגת **המצב הסופי** (del/moveFrom מושמטים, ins/moveTo מוצגים) — ראו משימה 12. | `inline_parser.dart:150-165` |
| 45 | `w14:glow` | **לא** | לא | אפקטי `w14` בתוך rPr לא נקראים כלל; הטקסט מרונדר רגיל. | אין |
| 46 | `w14:shadow` (מתקדם) | **לא** | לא | לא נקרא (ראו 45). הצל המתקדם אובד; `w:shadow` הקלאסי (פריט 17) כן מקורב. | אין |
| 47 | `w14:reflection` | **לא** | לא | לא נקרא. השתקפות לא מרונדרת. | אין |
| 48 | `w14:textOutline` | **לא** | לא | לא נקרא. מתאר מתקדם (gradient/עובי) אובד; `w:outline` הקלאסי (פריט 16) מקורב. | אין |
| 49 | `w14:textFill` | **לא** | לא | לא נקרא. מילוי gradient/דמוי‑תמונה אובד; הטקסט מקבל את צבע ה‑`w:color` בלבד. | אין |
| 50 | `w14:scene3d` / `w14:props3d` | **לא** | לא | לא נקרא. אפקטי תלת‑ממד לא נתמכים. | אין |
| 51 | `w14:ligatures` | **לא** | לא | לא נקרא. הליגטורות לא נשלטות (Flutter מחיל ברירת מחדל של הפונט). | אין |
| 52 | `w14:numForm` | **לא** | לא | לא נקרא. צורת ספרות (lining/oldStyle) לא נשלטת. | אין |
| 53 | `w14:numSpacing` | **לא** | לא | לא נקרא. ריווח ספרות (proportional/tabular) לא נשלט. | אין |
| 54 | `w14:stylisticSets` | **לא** | לא | לא נקרא. ערכות סגנון OpenType (ssXX) לא מופעלות. | אין |
| 55 | `w14:cntxtAlts` | **לא** | לא | לא נקרא. חלופות הקשריות לא נשלטות. | אין |
| 56 | בחירת Choice מול Fallback ב‑`mc:AlternateContent` סביב w14 | חלקי | לא | `AlternateContent` נפתר (מעדיף `Choice`, נופל ל‑`Fallback`) רק עבור **תוכן inline** (למשל ציורים). אפקטי `w14` עטופים **בתוך rPr** אינם נחצים כלל — `parseRun` קורא rPr דרך `getElement` ומתעלם מ‑AlternateContent שם → הטקסט מרונדר רגיל. | `inline_parser.dart:181-191`; (rPr לא נחצה) |

### ב.2 — פערים והוראות ל‑AI הבא

**קריטי לנאמנות עברית/BiDi:**
- **`eastAsia` font + פיצול פר‑כתב מוגבל ל‑2 כתבים (פריטים 6, 9).** `classifyScript` מכיר latin/complex בלבד; CJK נכרך ל‑latin ופונט `eastAsia` לעולם לא נבחר. לתעד כסטייה מודעת (יעד הספרייה הוא BiDi עברי‑לטיני). אם יידרש EA — להוסיף כתב שלישי ב‑`font_resolver.dart:34-61`.
- **`w:rtl`/דגל `w:cs` לא משפיעים (פריטים 39, 40).** הכיוון/החלת CS נגזרים מיוניקוד בלבד. לעברית אמיתית זה תקין, אך כפיית RTL מפורשת על ספרות/פיסוק ניטרליים מתעלמת מהדגל. לשקול חיווט `text.rtl` כאשר הוא מפורש (כפיית script=complex לקטע ניטרלי).

**מתקדם שנקרא אך לא מרונדר — להשלים ב‑`span_factory.dart` (פריטים 30, 33, 35, 36):**
- **`w:position` (פריט 33).** half‑points → baseline shift. ליישם דרך `FontFeature`/`Transform` או `WidgetSpan` עם offset אנכי. כיום הטקסט יושב על קו הבסיס הרגיל.
- **`w:w` (פריט 35).** קנה‑מידה אופקי 1–600%. ליישם `transform: scaleX(percent/100)` על הקטע (מצריך גם תיקון מדידה).
- **`w:fitText` (פריט 36).** דחיסה לרוחב נתון; דורש מדידת רוחב הקטע מול `val` (twips) וקנה‑מידה. גם `id` (קיבוץ ריצות) לא נקרא.
- **`w:em` (פריט 30).** סימני הדגשה EA (dot/comma/circle/underDot) — לצייר מעל/מתחת התווים. כיום נקרא ל‑model אך לא מצויר.

**נאמנות חלקית בקיים:**
- **`w:smallCaps` (פריט 13).** המימוש הנוכחי (uppercase מלא ×0.85) שגוי לאותיות שכבר גדולות. ליישם small‑caps אמיתי: רק lowercase → caps מוקטן (≈0.7), uppercase נשאר מלא — דורש פיצול נוסף או `FontFeature.enable('smcp')`.
- **`w:u` ערך `words` (פריט 29).** ממופה ל‑solid; ב‑Word הקו רק מתחת מילים (לא מתחת רווחים). דורש פיצול הקטע סביב רווחים.
- **`w:bdr` (פריט 37).** `w:space` לא מכובד (padding קבוע); אין מיזוג רצף ריצות; ה‑measurer לא ממדל את תיבת המסגרת → אי‑התאמת geometry. לחווט גם ב‑`buildMeasurementSpans`.
- **`w:dstrike`+underline (פריט 15).** Flutter חולק `decorationStyle` יחיד; קו‑חוצה‑כפול אובד כשיש קו תחתון. לשקול ציור ידני.
- **`auto` color (פריט 25).** הבחירה מול רקע גלובלי; Word בוחר מול ה‑`shd` המקומי (כפילות עם משימה 02 פריט 15).
- **`w:shd` ריצה — val/color (פריט 38).** רק `fill` נקרא; `val="solid"` ותבניות חסרים (כפילות עם משימה 02 פריטים 18, 20).

**לא ממומש — לתעד כסטייה מודעת:**
- **mark run properties (פריט 1).** rPr בתוך pPr (עיצוב סימן הפסקה) לא נקרא — משפיע על גובה פסקה ריקה. להוסיף ב‑`docx_style.dart:296` (`_parseParagraphProperties`).
- **`w:specVanish`,`w:webHidden`,`w:snapToGrid`,`w:effect`,`w:lang`,`w:eastAsianLayout` (פריטים 21–24, 31, 41, 42).** לא נקראים. רובם השפעה ויזואלית מועטה/EA; `specVanish` רלוונטי לכותרות מקופלות.
- **כל `w14:*` (פריטים 45–55) + AlternateContent ברמת rPr (פריט 56).** אפקטי w14 בתוך rPr לא נקראים כלל, וה‑Choice/Fallback לא נחצה ברמת rPr (רק ברמת תוכן inline). מנוע בסיסי מתעלם ומרנדר טקסט רגיל — מקובל; מנוע 1:1 מלא יממש לפחות glow/outline/fill/shadow.
- **`w:noProof`,`w:rPrChange` (פריטים 23, 44).** ללא השפעה ויזואלית / מטופל דרך הצגת המצב הסופי — אין פעולה נדרשת.
