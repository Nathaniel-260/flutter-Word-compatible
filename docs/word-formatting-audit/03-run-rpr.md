# משימה 03 — עיצוב ריצה / תו — `w:rPr`

> **מקור:** סעיף §3 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **סטטוס מימוש:** 🟨 פערים בני‑מימוש נסגרו 1:1 (smallCaps→smcp אמיתי; דגלי `w:rtl`/`w:cs`→כתב‑מורכב לקטע ניטרלי; `w:u`=`words`→קו רק מתחת מילים; `w:highlight`→פלטה מדויקת; mark‑size→גובה פסקה ריקה + תיקון קיפול‑ל‑0; dstrike+underline→פשרת "הכפול גובר") + אומת ש‑auto‑color ו‑shd‑ריצה כבר נסגרו ב‑task 02; שאר הפערים = סטיות מודעות מנומקות (position/w/fitText/em — אילוץ מבני ב‑Flutter; w14/EA/דגלים נדירים) — כל פער עם הכרעה ב‑ב.2 &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-22

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
| 1 | `rPr` בשלושת ההקשרים (r / pPr mark / style+docDefaults) | כן | נאמן~ | (א) ריצה ב‑`w:r` ו‑(ג) סגנון+docDefaults מטופלים. ✅ **(ב) mark run properties תוקן (חלקית):** **גודל** סימן‑הפסקה (`w:pPr/w:rPr/w:sz`) נקרא ל‑`DocxParagraph.markRunFontSize` (round‑trip) וקובע את **גובה פסקה ריקה** ב‑measure+render (גם תוקן באג קיים: ה‑renderer קיפל פסקה ריקה לגובה 0 בעוד ה‑measurer ספר שורה). שאר מאפייני הסימן (b/i/color) נראים רק על הפילקרו — מוסתר בתצוגת קריאה. | `block_parser.dart`; `docx_block.dart` (`markRunFontSize`); `text_measurer.dart`; `paragraph_builder.dart` |
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
| 13 | `w:smallCaps` | כן | נאמן~ | ✅ **תוקן:** small‑caps אמיתי דרך `FontFeature.enable('smcp')` — רק אותיות **קטנות** הופכות לקפיטל מוקטן, הגדולות נשארות בגודל מלא (בדיוק כמו Word), והטקסט שומר את ה‑case המקורי (אין `toUpperCase`, אין כיווץ ×0.85). פיצ'ר טהור ב‑`TextStyle` → מדידה≡רינדור נשמר. קירוב יחיד: פונט ללא טבלת `smcp` → האותיות הקטנות מוצגות רגיל (נדיר; Calibri/Carlito/Times/Arial והשכיחים כוללים smcp). | `span_factory.dart` (`resolveRunStyle` fontFeatures; `resolveContent`) |
| 14 | `w:strike` (קו חוצה יחיד) | כן | נאמן | `lineThrough` מוחל. | `docx_style.dart:511-514`; `span_factory.dart:207-216` |
| 15 | `w:dstrike` (קו חוצה כפול) | כן | נאמן~ | מוחל כ‑`decorationStyle.double`. בצירוף עם קו תחתון Flutter חולק `decorationStyle` יחיד — ✅ **פשרה מיושמת: הכפול גובר** (`isDoubleStrike`→double תמיד), כך שכפילות הקו‑החוצה (כוונת המחבר) נשמרת; שארית מודעת: קו תחתון מתלווה מוצג אף הוא כפול. 1:1 מלא דורש CustomPaint מודע‑גליפים. | `span_factory.dart` (decoration block) |
| 16 | `w:outline` (מתאר תווים) | כן | חלקי | מקורב: `Paint` stroke ברוחב 0.5 ללא מילוי, וצבע הטקסט מתאופס. לא מתאר חלול אמיתי בעובי תלוי‑גודל כמו Word. | `span_factory.dart:328-335` |
| 17 | `w:shadow` (צל לתו) | כן | חלקי | מקורב: `Shadow` יחיד offset (1,1) blur 2 שחור 30%. לא תואם בדיוק את צל Word (כיוון/עובי). | `span_factory.dart:291-299` |
| 18 | `w:emboss` (תבליט) | כן | חלקי | מקורב: שני צללים (לבן עליון‑שמאל + שחור תחתון‑ימין). אפקט תבליט סביר אך לא פיקסל‑מדויק. | `span_factory.dart:300-312` |
| 19 | `w:imprint` (חריטה) | כן | חלקי | מקורב: שני צללים בכיוון הפוך ל‑emboss. סביר, לא מדויק. | `span_factory.dart:313-326` |
| 20 | `w:vanish` (טקסט מוסתר — השפעה על עימוד) | כן | נאמן~ | `hidden` נקרא; הריצה מדולגת במדידה+רינדור+אינדקס‑חיפוש (לא תופסת מקום). תואם תצוגת‑הדפסה. Word עם "הצג טקסט מוסתר" דלוק *כן* מציג ותופס מקום — מצב זה לא נתמך. | `inline_parser.dart:430`; `span_factory.dart:503`; `paragraph_builder.dart:239,726` |
| 21 | `w:specVanish` (סימן פסקה מוסתר) | **לא** | לא | לא נקרא כלל. נוגע לכותרות מקופלות (always‑hidden paragraph mark) — לא נתמך. | אין |
| 22 | `w:webHidden` | **לא** | לא | לא נקרא. בתצוגת print Word מציג טקסט זה; ההתעלמות מקובלת אך מתועדת. | אין |
| 23 | `w:noProof` | **לא** | n/a | לא נקרא — אך אין לו השפעה ויזואלית (רק ביטול בדיקת איות), כך שאין פגיעה בנאמנות. | אין |
| 24 | `w:snapToGrid` (ריצה) | **לא** | לא | לא נקרא. משפיע על יישור תווים לרשת המסמך (docGrid, בעיקר EA) — לא נתמך. | אין |
| 25 | `w:color` (val + themeColor + auto) | כן | נאמן | ✅ **נסגר ב‑task 02 (פריט 15):** val(hex)+themeColor+themeTint/Shade מוחלים (`resolveColor`); `auto`→שחור/לבן מול ה‑`shd` המקומי (ריצה→פסקה→תא) דרך `resolveAutoTextColor`+`autoBackground` המושחל ל‑`ParagraphBuilder` (רינדור בלבד). themeColor עובד (משימה 13). | `docx_style.dart:539-550`; `span_factory.dart` (`resolveAutoTextColor`); `paragraph_builder.dart` |
| 26 | `w:sz` (half-points) | כן | נאמן | `val/2` pt → `×1.333` px; משמש לקטעי לטינית. | `docx_style.dart:546-553`; `span_factory.dart:241-244` |
| 27 | `w:szCs` (גודל CS/עברית — חיוני) | כן | נאמן | `fontSizeCs` נקרא ומוחל לקטעי complex (נופל ל‑`sz` אם חסר) — עברית יכולה לקבל גודל שונה מהלטינית באותה ריצה. | `inline_parser.dart:431`; `span_factory.dart:242` |
| 28 | `w:highlight` (17 צבעים קבועים) | כן | נאמן | ✅ **תוקן:** 16 הצבעים (+none) ממופים לערכי ה‑RGB **המדויקים** של Word (`ST_HighlightColor`: yellow=FFFF00, blue=0000FF, darkYellow=808000…) במקום קירובי Material (שהיו yellow=FFEB3B, blue=2196F3…). רקע בלבד → מדידה≡רינדור. ראו [§17.4](17-enums.md). | `docx_style.dart:570-581`; `span_factory.dart` (`highlightToColor`) |
| 29 | `w:u` (val + color/theme + `words`) | כן | נאמן~ | val ממופה לתבניות Flutter (single/double/dotted/dashed/wavy + עובי 2.5 ל‑heavy); color/theme מוחלים. ✅ **`words` תוקן:** הריצה מפוצלת סביב רווחים (`_splitWordsUnderline`) — הקו מצויר רק מתחת מילים, לא מתחת לרווחים (קו‑חוצה נשאר רציף). אורך התווים נשמר → מדידה≡רינדור, פיצול‑עימוד וחיפוש לא נפגעים. קירוב שיורי: עובי thick=×2.5, ו‑gap מוגדר כרווח/טאב בלבד. | `docx_style.dart:490-510`; `span_factory.dart` (`_splitWordsUnderline`) |
| 30 | `w:em` (סימן הדגשה EA) | חלקי | **לא** | `emphasisMark` **נקרא** ל‑`DocxText` ומיוצא חזרה ל‑XML — אך **לא מרונדר** (ה‑viewer לא מצייר את הנקודות/עיגולים מעל/מתחת התווים). | `inline_parser.dart:436-437`; `enums.dart:297`; (לא מרונדר) |
| 31 | `w:effect` (אנימציה ישנה) | **לא** | לא | לא נקרא. האנימציה (sparkle/lights…) לא מיושמת; הטקסט מוצג סטטי ממילא, אך גם אפקט סטטי כלשהו אובד. | אין |
| 32 | `w:spacing` (ריצה — tracking, twips שלילי) | כן | נאמן~ | `characterSpacing` (twips, כולל שלילי) → `letterSpacing = val/15` (96 DPI). תואם tracking של Word; קירוב תת‑פיקסלי בלבד. | `docx_style.dart:538-544`; `span_factory.dart:369-370` |
| 33 | `w:position` (הרמה/הנמכה half-points) | **לא** | לא | `raiseLowerHalfPoints` **נקרא** ל‑`DocxText` ומיוצא חזרה — אך **לא מוחל** ברינדור. הרמה/הנמכה מקו הבסיס ללא שינוי גודל אינה מתרחשת; הטקסט יושב על קו הבסיס הרגיל. | `inline_parser.dart:433`; (לא בשימוש ב‑span_factory) |
| 34 | `w:kern` (kerning מגודל מסוים) | כן | חלקי | `kernMinHalfPoints` נקרא; כש‑גודל הפונט ≥ הסף מופעל `FontFeature.enable('kern')`. קירוב: feature ה‑kern לרוב דלוק כברירת מחדל ב‑Flutter, כך שהאפקט בפועל מינורי; הסף מכובד. | `inline_parser.dart:432`; `span_factory.dart:337-353` |
| 35 | `w:w` (מתיחה אופקית 1–600%) | **לא** | לא | `charScalePercent` **נקרא** ל‑`DocxText` ומיוצא חזרה — אך **לא מוחל**. אין מתיחה/כיווץ אופקי של רוחב התווים (אין `transform`/scaleX על הקטע). | `inline_parser.dart:434`; (לא בשימוש) |
| 36 | `w:fitText` (val + id) | **לא** | לא | `fitTextTwips` **נקרא** (val בלבד) ומיוצא חזרה — אך **לא מוחל**; `id` (קיבוץ ריצות) לא נקרא. אין דחיסה/מתיחה לרוחב נתון. | `inline_parser.dart:435`; (לא בשימוש) |
| 37 | `w:bdr` (מסגרת ריצה + מיזוג רצף) | חלקי | **לא** | נקרא (`_parseBorderSide`→`textBorder`) ומרונדר כ‑`Container` עם `Border.all` סביב הריצה. פערים: (א) **`w:space` לא מכובד** (padding קבוע 2px); (ב) **אין מיזוג** רצף ריצות בעלות אותו bdr (כל ריצה ממוסגרת בנפרד); (ג) מרונדר רק כשאין התאמת חיפוש; (ד) ה‑**measurer לא ממדל את תיבת המסגרת** → אי‑התאמת geometry בין מדידה לרינדור. | `docx_style.dart:599-604,686-713`; `paragraph_builder.dart:892-918` |
| 38 | `w:shd` (הצללת ריצה — שונה מ‑highlight) | כן | נאמן~ | ✅ **נסגר ב‑task 02 (פריטים 18,20):** קריאת ה‑shd של הריצה עוברת דרך `resolveShdFill` המשותף — `clear`→fill, **`solid`→color**, `pctN`/פס/רשת→מיזוג ליניארי לפי כיסוי; `w:color`+themeFill+tint/shade מוחלים, מרונדרים כרקע אחיד. סטייה מודעת יחידה: גיאומטריית hatch אמיתית ומיזוג‑theme‑כפול (task 02 §ב.2). | `docx_style.dart:552-559` (`resolveShdFill`); `span_factory.dart:228-236` |
| 39 | `w:rtl` (ריצת RTL — קובע החלת CS) | כן | נאמן~ | ✅ **תוקן:** הדגל `w:rtl` המפורש כופה קטע **ניטרלי** (ספרות/פיסוק) לכתב מורכב (`hintComplex` ב‑`resolveRunSegments`) → פונט ה‑cs ו‑szCs/bCs/iCs חלים, כפי ש‑Word עושה בריצת RTL. לטינית **חזקה** נשארת לטינית (גם Word שומר ספרות בפונט ascii). לעברית אמיתית — ללא שינוי (כבר מורכב). הסיווג משותף ל‑measure+render → מדידה≡רינדור. (סדר‑הצגה דו‑כיווני עדיין מ‑UBA של Flutter.) | `inline_parser.dart:465`; `span_factory.dart` (`resolveRunSegments`) |
| 40 | `w:cs` (דגל Complex Script) | כן | נאמן~ | ✅ **תוקן:** דגל ה‑`w:cs` (אלמנט CT_OnOff ב‑rPr, נבדל מתכונת הפונט `w:rFonts/@w:cs`) נקרא ל‑`DocxText.complexScript` (round‑trip ב‑`buildXml`: `<w:cs/>`/`<w:cs w:val="0"/>`) וכופה קטע ניטרלי לכתב מורכב, כמו `w:rtl`. | `inline_parser.dart:468`; `docx_inline.dart` (`complexScript`); `span_factory.dart` |
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

### ב.2 — הכרעה לכל פער + הוראות ל‑AI הבא (סגירה)

> **מצב:** כל פער קיבל הכרעה — *מומש 1:1* / *נסגר ב‑task 02* / *סטייה מודעת (סיבה+חומרה)* / *משימה ל‑AI הבא* / *ללא פעולה*. אין פער ללא החלטה. סעיף זה **עצמאי** — כל סיבה+חומרה כתובות כאן.
> **אימות שבוצע (2026-06-22):** `flutter analyze` — viewer נקי; docx_creator עם 3 info‑lints קיימים‑מראש (`unnecessary_import`) בקבצי‑בדיקה שלא נגעתי בהם (`field_parsing_test.dart`, `section_page_numbering_test.dart`). `flutter test` — docx_creator **464✅** (1 דילוג, +6 בדיקות חדשות), docx_file_viewer **399✅** (4 הנכשלות = קובצי‑fixture חסרים בצ'קאאוט ב‑`hebrew_rtl_golden_test.dart` בלבד, `PathNotFoundException`, לא קוד). בדיקות חדשות: `inline_extras_test.dart` (3 — `w:cs`), `paragraph_properties_test.dart` (3 — `markRunFontSize` parse+round‑trip), `script_split_test.dart` (11 — smallCaps→smcp + rtl/cs + `w:u`=words + dstrike+underline), `highlight_palette_test.dart` (2 — ST_HighlightColor), `empty_paragraph_height_test.dart` (3 — גובה פסקה ריקה measure≡render). כל בדיקות הטקסט כוללות עברית+אנגלית.

#### ✅ מומש 1:1 בקובץ זה (קוד + בדיקה נכשלת‑לפני/עוברת‑אחרי)
- **`w:smallCaps` — small‑caps אמיתי (פריט 13).** הוחלף המקורב השגוי (uppercase מלא + כיווץ ×0.85) ב‑`FontFeature.enable('smcp')` ב‑`resolveRunStyle`, ו‑`resolveContent` שוב **לא** הופך smallCaps ל‑uppercase. כך רק אותיות קטנות הופכות לקפיטל מוקטן והגדולות נשארות מלאות — בדיוק כמו Word — והטקסט המקורי (חיפוש/העתקה) נשמר. רשימת ה‑fontFeatures נבנית אדיטיבית כך ש‑smcp דר בכפיפה אחת עם kern. פיצ'ר טהור ב‑`TextStyle` המשותף ל‑measure+render → מדידה≡רינדור. **קירוב/חליפה מתועד (חומרה נמוכה‑בינונית):** פונט **ללא** טבלת `smcp` → האותיות הקטנות מוצגות רגיל (lowercase), בעוד Word **מסנתז** small‑caps בכך שהוא מקטין גליפי‑קפיטל. כלומר עבור פונט מוטמע/לא‑נפוץ ללא smcp זו נסיגה ויזואלית מול המקורב הישן (uppercase+כיווץ) שכן הראה צורת small‑caps כלשהי. ההחלפה מכוונת: לפונטים הנפוצים (Calibri/Carlito/Times/Tinos/Arial/Arimo) יש smcp והתוצאה פיקסל‑מדויקת מול Word; חליפה‑מבוססת‑סינתזה לפונטים ללא הטבלה דורשת פיצול פר‑case + זיהוי יכולת‑הפונט (אין רישום זמין) — **ל‑AI הבא** אם יידרש.
- **`w:rtl` כופה כתב מורכב לקטע ניטרלי (פריט 39).** `resolveRunSegments` מעביר `hintComplex` כש‑`text.rtl == true` (בנוסף ל‑`w:hint=cs`), כך שספרות/פיסוק **ניטרליים** בריצת RTL מפורשת מקבלים את פונט ה‑cs ו‑szCs/bCs/iCs, כפי ש‑Word עושה. לטינית חזקה נשארת לטינית (כמו Word). הסיווג משותף → מדידה≡רינדור.
- **`w:cs` דגל הריצה (פריט 40).** שדה AST חדש `DocxText.complexScript` (אופציונלי, ברירת מחדל null, round‑trip ב‑`buildXml`), נקרא מ‑`w:cs` (אלמנט CT_OnOff ב‑rPr — נבדל מתכונת הפונט `w:rFonts/@w:cs`), ומוזן ל‑`hintComplex` כמו `w:rtl`. API לא נשבר (תוספתי בלבד).
- **mark run properties — גובה פסקה ריקה (פריט 1).** שדה AST חדש `DocxParagraph.markRunFontSize` (תוספתי, round‑trip כ‑`w:pPr/w:rPr/w:sz`+`szCs`), נקרא **ישירות** מ‑`pPr/rPr/sz` ב‑`block_parser` (`parsedProps.fontSize`). גודל זה קובע את גובה הפסקה הריקה בשני הנתיבים: ה‑`TextMeasurer` (שורת ה‑blank) וה‑renderer. **תוקן גם פער measure≠render קיים‑מראש:** ה‑renderer קיפל פסקה ריקה ל‑`SizedBox(0)` בעוד ה‑measurer ספר שורה — כעת ה‑renderer מצייר שורת blank יחידה (ZWSP זהה ל‑measurer) → measure≡render (אומת ב‑widget‑test). פסקה ללא גודל‑סימן מפורש = ברירת הגוף (ללא שינוי עימוד; word_parity 7 עמ' נשמר). *מגבלה מתועדת:* גודל ישיר בלבד (ללא ירושת‑סגנון); b/i/color של הסימן לא ממומשים (נראים רק על הפילקרו, מוסתר בקריאה).
- **`w:highlight` — פלטת ה‑RGB המדויקת של Word (פריט 28).** הוחלפו קירובי ה‑Material ב‑16 ערכי ה‑RGB הקבועים של `ST_HighlightColor` (ISO/IEC 29500) — `highlightToColor` מחזיר כעת `Color(0xFF……)` מדויק (yellow FFFF00, blue 0000FF, darkYellow 808000, lightGray C0C0C0…). רקע בלבד → מדידה≡רינדור. בדיקה: `highlight_palette_test.dart` (כל 16 הערכים + none + רקע‑ריצה עברית+אנגלית).
- **`w:u` ערך `words` — קו רק מתחת מילים (פריט 29).** `_splitWordsUnderline` מפצל כל קטע‑כתב סביב רווחים/טאבים ומסיר את הקו‑התחתון מקטעי‑הרווח בלבד (קו‑חוצה/over נשמרים רציפים). הפיצול מחליף רק את ה‑`decoration` של תת‑הקטע (לא advances/גובה) והקטעים מרצפים את התוכן במדויק → טקסט‑הצייר, שבירת השורות, offsets לפיצול‑עימוד וטווחי החיפוש — ללא שינוי (מדידה≡רינדור). **קירובים מתועדים:** (א) ה‑gap = רווח/טאב ASCII בלבד (רווח‑לבן אקזוטי נחשב תו‑מילה — זניח); (ב) **`words` בתוך היפר‑קישור** — `_overlaySegment` כופה את קו הקישור הסינתטי הרציף (`linkDecoration ?? segStyle.decoration`) ומבטל את הפיצול, כך שקישור עם `u=words` מוצג עם קו רציף. צירוף נדיר; הקו הרציף הוא ממילא ההצגה המקובלת לקישור (חומרה נמוכה).

#### ✅ נסגר ב‑task 02 (קוד משותף; אומת — אין פעולה נדרשת כאן)
- **`auto` color מול ה‑`shd` המקומי (פריט 25).** `resolveAutoTextColor` בוחר שחור/לבן מול ה‑fill המקומי (ריצה→פסקה→תא) המושחל ל‑`ParagraphBuilder`; רינדור בלבד → מטריקות לא מושפעות. (task 02 §ב.2 פריט 15.)
- **`w:shd` ריצה — `val`+`color` (פריט 38).** קריאת ה‑shd של הריצה עוברת דרך `resolveShdFill` המשותף: `clear`→fill, `solid`→color, `pctN`/פס/רשת→מיזוג ליניארי. (task 02 §ב.2 פריטים 18,20.) סטייה שיורית: גיאומטריית hatch + מיזוג‑theme‑כפול (task 02, חומרה נמוכה).

#### 🟨 סטיות מודעות (סיבה+חומרה — עצמאי)
- **מתקדם שנקרא אך לא מרונדר: `w:position`,`w:w`,`w:fitText`,`w:em` (פריטים 33, 35, 36, 30).** *חומרה: נמוכה.* **אילוץ מבני ב‑Flutter:** ל‑`TextStyle` אין הזזת‑בסיס (position), קנה‑מידה אופקי פר‑גליף (w/fitText) או נקודות‑הדגשה (em). מימושם דורש `WidgetSpan`/`Transform`/`CustomPaint`, שהופכים את הריצה ל‑placeholder אטומי יחיד — מה ששובר את מודל ה‑splittable‑text של ה‑`Paginator` (מיפוי offsets לפיצול פסקה ולאינדקס החיפוש) או דורש `RenderObject` ייעודי. `position`/`w` **שקולים בין מדידה לרינדור** (שני הנתיבים מתעלמים זהה → אין סטיית עימוד; ראו plan §8.2 #9). `em` הוא תופעת EA — נדיר בעברית/לטינית. **ל‑AI הבא:** RenderObject ייעודי לריצה שיתמוך ב‑baseline‑shift/scaleX, או מדידת‑עזר + placeholder תואם — רק אם יידרש; לשמור מדידה≡רינדור.
- **`w:dstrike`+underline (פריט 15) — פשרה מיושמת.** *חומרה: נמוכה.* Flutter חולק `decorationStyle` יחיד לכל קישוטי הקטע. נבחרה פשרה (החלטת משתמש): **הכפול גובר** — `decorationStyle=double` מוחל בכל פעם ש‑`isDoubleStrike` (גם עם קו תחתון), כך שכפילות הקו‑החוצה נשמרת. *שארית מודעת:* קו תחתון מתלווה מוצג אף הוא כפול (1:1 מלא דורש CustomPaint מודע‑גליפים — נדחה לפיצ'ר נדיר). מאומת בבדיקה (`script_split_test.dart`).
- **`w:outline`/`w:shadow`/`w:emboss`/`w:imprint` — מקורבים (פריטים 16–19).** *חומרה: נמוכה.* מצוירים כ‑stroke‑Paint / `Shadow`(ים) קבועים; לא תואמים פיקסל את כיוון/עובי האפקט של Word (תלוי‑גודל). אפקטים נדירים; הנראות הכללית סבירה.
- **`w:kern` (פריט 34).** *חומרה: זניחה.* הסף מכובד; `FontFeature.enable('kern')` מופעל מעל הסף, אך kern לרוב דלוק כברירת מחדל ב‑Flutter → אפקט מינורי.
- **`w:bdr` — `w:space`/מיזוג/measurer (פריט 37).** *חומרה: נמוכה‑בינונית.* כיום `Container` עם `Border.all` ו‑padding קבוע 2px, מרונדר רק כשאין התאמת חיפוש, וה‑measurer לא ממדל את תיבת המסגרת. תיקון מלא דורש: כיבוד `side.space` ל‑padding, מיזוג רצף ריצות בעלות אותו bdr, וצמצום רוחב‑הפריסה ב‑`buildMeasurementSpans`/`text_measurer` (במקביל ל‑`_hBorderSpacePx` של גבול‑הפסקה ב‑task 02). היות שתיבת המסגרת היא `WidgetSpan` אטומי ברינדור אך טקסט inline במדידה — סגירה מלאה רגישה ל‑parity; נדחה כיחידה עצמאית.
- **`eastAsia` font + פיצול מוגבל ל‑2 כתבים (פריטים 6, 9).** *חומרה: נמוכה.* `classifyScript` מכיר latin/complex בלבד; CJK נכרך ל‑latin ו‑`eastAsia` לעולם לא נבחר. יעד הספרייה הוא BiDi עברי‑לטיני. **ל‑AI הבא:** כתב שלישי ב‑`font_resolver.dart` אם יידרש EA.
- **`w:hint` (eastAsia/default) + `hAnsi` (פריטים 8, 4).** *חומרה: נמוכה.* רק `hint=cs` מטופל; `hAnsi` משמש כ‑`ascii ?? hAnsi` (זניח כש‑ascii=hAnsi, המקרה הרגיל).
- **`w:specVanish`,`w:webHidden`,`w:snapToGrid`,`w:effect`,`w:lang`,`w:eastAsianLayout` (פריטים 21, 22, 24, 31, 41, 42).** *חומרה: נמוכה.* לא נקראים; השפעה ויזואלית מועטה/EA. `specVanish` רלוונטי לכותרות מקופלות; `lang` למיקוף/איות.
- **`w:oMath` — placeholder לינארי (פריט 43).** *חומרה: נמוכה.* OMML מקופל לטקסט (`m:t` משורשר); לא מעומד כנוסחה (plan §K.6).
- **כל `w14:*` (פריטים 45–55) + AlternateContent ברמת rPr (פריט 56).** *חומרה: נמוכה.* אפקטי `w14` בתוך rPr לא נקראים, וה‑Choice/Fallback לא נחצה ברמת rPr (רק ברמת תוכן inline) → הטקסט מרונדר רגיל. מנוע בסיסי מתעלם — מקובל; מנוע 1:1 מלא יממש לפחות glow/outline/fill/shadow.

#### ➡️ משימה ל‑AI הבא (שייך ל‑task אחר)
- **XOR ל‑`bCs`/`iCs` ולאורך `basedOn` (פריטים 10, 11) → task 16.** הבחירה פר‑כתב עובדת; רזולוציית ה‑toggle (direct‑XOR מול דריסה, XOR חוצה‑basedOn) היא מנוע‑הסגנונות (task 02 §ב.2 פריט 13 → task 16).

#### ⚪ ללא פעולה (אין השפעה ויזואלית)
- **`w:noProof` (פריט 23)** — רק ביטול בדיקת איות. **`w:rPrChange` (פריט 44)** — מטא‑דאטה של מעקב‑שינויים; מטופל דרך הצגת המצב הסופי (task 12).
