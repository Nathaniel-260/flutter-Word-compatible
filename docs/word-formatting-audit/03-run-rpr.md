# משימה 03 — עיצוב ריצה / תו — `w:rPr`

> **מקור:** סעיף §3 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —

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

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `rPr` בשלושת ההקשרים (r / pPr mark / style+docDefaults) | | | | |
| 2 | `w:rStyle` (סגנון תו) | | | | |
| 3 | `w:rFonts` — `ascii` | | | | |
| 4 | `w:rFonts` — `hAnsi` | | | | |
| 5 | `w:rFonts` — `cs` (עברית/ערבית — קריטי) | | | | |
| 6 | `w:rFonts` — `eastAsia` | | | | |
| 7 | `w:rFonts` — `asciiTheme`/`hAnsiTheme`/`eastAsiaTheme`/`cstheme` | | | | |
| 8 | `w:rFonts` — `hint` (default/eastAsia/cs) | | | | |
| 9 | בחירת פונט **פר‑תו** לפי טווח יוניקוד (פיצול ריצה) | | | | |
| 10 | `w:b` + `w:bCs` (toggle/XOR) | | | | |
| 11 | `w:i` + `w:iCs` (toggle) | | | | |
| 12 | `w:caps` (ויזואלי, טקסט נשאר lowercase) | | | | |
| 13 | `w:smallCaps` | | | | |
| 14 | `w:strike` (קו חוצה יחיד) | | | | |
| 15 | `w:dstrike` (קו חוצה כפול) | | | | |
| 16 | `w:outline` (מתאר תווים) | | | | |
| 17 | `w:shadow` (צל לתו) | | | | |
| 18 | `w:emboss` (תבליט) | | | | |
| 19 | `w:imprint` (חריטה) | | | | |
| 20 | `w:vanish` (טקסט מוסתר — השפעה על עימוד) | | | | |
| 21 | `w:specVanish` (סימן פסקה מוסתר) | | | | |
| 22 | `w:webHidden` | | | | |
| 23 | `w:noProof` | | | | |
| 24 | `w:snapToGrid` (ריצה) | | | | |
| 25 | `w:color` (val + themeColor + auto) | | | | |
| 26 | `w:sz` (half-points) | | | | |
| 27 | `w:szCs` (גודל CS/עברית — חיוני) | | | | |
| 28 | `w:highlight` (17 צבעים קבועים) | | | | |
| 29 | `w:u` (val + color/theme + `words`) | | | | |
| 30 | `w:em` (סימן הדגשה EA) | | | | |
| 31 | `w:effect` (אנימציה ישנה) | | | | |
| 32 | `w:spacing` (ריצה — tracking, twips שלילי) | | | | |
| 33 | `w:position` (הרמה/הנמכה half-points) | | | | |
| 34 | `w:kern` (kerning מגודל מסוים) | | | | |
| 35 | `w:w` (מתיחה אופקית 1–600%) | | | | |
| 36 | `w:fitText` (val + id) | | | | |
| 37 | `w:bdr` (מסגרת ריצה + מיזוג רצף) | | | | |
| 38 | `w:shd` (הצללת ריצה — שונה מ‑highlight) | | | | |
| 39 | `w:rtl` (ריצת RTL — קובע החלת CS) | | | | |
| 40 | `w:cs` (דגל Complex Script) | | | | |
| 41 | `w:lang` (val/bidi/eastAsia) | | | | |
| 42 | `w:eastAsianLayout` (combine/combineBrackets/vert/vertCompress) | | | | |
| 43 | `w:oMath` (ריצת נוסחה) | | | | |
| 44 | `w:rPrChange` (revision על rPr) | | | | |
| 45 | `w14:glow` | | | | |
| 46 | `w14:shadow` (מתקדם) | | | | |
| 47 | `w14:reflection` | | | | |
| 48 | `w14:textOutline` | | | | |
| 49 | `w14:textFill` | | | | |
| 50 | `w14:scene3d` / `w14:props3d` | | | | |
| 51 | `w14:ligatures` | | | | |
| 52 | `w14:numForm` | | | | |
| 53 | `w14:numSpacing` | | | | |
| 54 | `w14:stylisticSets` | | | | |
| 55 | `w14:cntxtAlts` | | | | |
| 56 | בחירת Choice מול Fallback ב‑`mc:AlternateContent` סביב w14 | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
