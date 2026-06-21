# משימה 02 — יחידות מידה וטיפוסי ערכים

> **מקור:** סעיף §2 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-19
>
> ⚠️ זהו הבסיס לכל מדידה — טעות יחידה = פספוס מידות בכל שאר המשימות.

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

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
> ערכי `ST_ThemeColor`: ראו [נספח §17.7](17-enums.md).

### 2.3 מאפיין הצללה משולש: `w:shd`

`w:shd` חוזר בהרבה הקשרים (ריצה, פסקה, תא, טבלה). תמיד שלוש תכונות:

| תכונה | משמעות |
|---|---|
| `w:val` | **תבנית** ההצללה (ST_Shd: `clear`, `solid`, `pct25`, `horzStripe`…). `clear` = אין תבנית, רק `fill`. |
| `w:fill` | צבע **רקע** (hex/auto/themeFill) |
| `w:color` | צבע ה**תבנית** (הפיקסלים של ה‑pattern; רלוונטי רק כש‑val≠clear/solid) |

> מקרה נפוץ: `<w:shd w:val="clear" w:fill="D9D9D9"/>` = רקע אפור אחיד. `<w:shd w:val="solid" w:color="…"/>` = מילוי מלא בצבע ה‑color. ערכי ST_Shd מלאים: [נספח §17.5](17-enums.md).

### 2.4 גבול גנרי: `CT_Border`

כל גבול (ב‑pBdr/tblBorders/tcBorders/bdr/pgBorders) חולק תכונות:

| תכונה | יחידה/ערכים | מה עושה |
|---|---|---|
| `w:val` | `ST_Border` (single, double, dotted, dashed, wave, threeDEmboss, + 160 art borders…) | סגנון הקו. `nil`/`none` = אין גבול. ראו [§17.1](17-enums.md). |
| `w:sz` | eighth-points (1/8 pt) | עובי הקו. טווח שכיח 2–96. |
| `w:space` | נקודות (pt) | מרווח בין הגבול לטקסט. ב‑pgBorders תלוי ב‑`offsetFrom`. |
| `w:color` | hex/auto/theme | צבע הקו |
| `w:themeColor`,`themeTint`,`themeShade` | כמו §2.2 | צבע theme לקו |
| `w:frame` | bool | אפקט תלת‑ממד "מסגרת" |
| `w:shadow` | bool | צל לקו |
| `w:id` | מזהה art border | רק לגבולות עמוד דקורטיביים (`w:val` שהוא art) |

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

> **היכן ממומש.** ההמרות הבסיסיות חיות בשני מקומות: `docx_creator/lib/src/core/measurements.dart`
> (extensions להמרה, צד הפיענוח/ייצוא) ו‑`docx_file_viewer/lib/src/utils/docx_units.dart`
> (המרה ל‑logical pixels ב‑96 DPI, צד הרינדור). פיענוח הערכים (toggle/צבע/shd/border) ב‑reader
> (`docx_style.dart`, `style_engine.dart`, `xml_extension.dart`); יישום הצבע/הצללה ל‑pixels ב‑`span_factory.dart`.

### ב.1 — סריקה פר‑פריט

| # | פריט (יחידה/טיפוס) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | המרת **twip** (dxa) → px/pt | כן | נאמן | `twip/1440*96` ל‑pixel ו‑`twip/20` ל‑pt — בדיוק נוסחת הייחוס (96 DPI). | `docx_units.dart:15` (`twips/15`); `measurements.dart:54` (`twipsToPoints`) |
| 2 | המרת **half-point** (sz/szCs/position/kern) | חלקי | נאמן (לגודל פונט) | `sz`/`szCs`→גודל פונט מומר נכון (`val/2` pt, `*96/72` px). **אך** `position` (העלאה/הורדה) ו‑`kern` (קרנינג) אינם נקראים/מיושמים. | `docx_style.dart:546-552`; `docx_units.dart:25` |
| 3 | המרת **eighth-point** (עובי גבול) | כן | נאמן~ | `val/8` pt. ההמרה ב‑viewer משתמשת ב‑`1.333` (קירוב ל‑4/3) → סטיית עיגול תת‑פיקסלית. | `docx_units.dart:52`; `measurements.dart:101` |
| 4 | המרת **EMU** (DrawingML) | כן | נאמן | `emu/914400` inch, `emu/12700` pt, `emu/9525` px (96 DPI) — תואם ייחוס. | `docx_units.dart:37`; `measurements.dart:20-32` |
| 5 | **fiftieth of %** (pct ישן, 5000=100%) | חלקי | n/a (תשתית) | `w:tblW@w:type="pct"` עם ערך מספרי נקרא; `pctToFraction = pct/5000`. רק רוחב **טבלה/תא** — לא הורחב לכל ההקשרים. | `table_parser.dart:55-62`; `docx_units.dart:58` |
| 6 | **% string** (`"50%"` חדש) | **לא** | לא | Word כותב לעיתים `w:w="50%"`. כאן `int.tryParse("50%")` מחזיר null → הרוחב נופל בשקט. הצורה המחרוזתית לא נתמכת. | `table_parser.dart:57` (גם משימה 06) |
| 7 | **240ths of line** (lineRule=auto) | כן | נאמן | `line`+`lineRule` נפרסים; ל‑`auto`: יחס שורה = `lineSpacing/240` (240=יחיד, 360=1.5, 480=כפול). `exact`/`atLeast` מטופלים דרך strut (קופסת שורה כפויה/מינ'). | `docx_style.dart:345-349`; `span_factory.dart:112-119` |
| 8 | **line units ×100** (beforeLines/afterLines/gridBefore/After) | **לא** | לא | רק `w:before`/`w:after` ב‑twips נקראים. `beforeLines`/`afterLines` (1/100 שורה) ו‑`gridBefore`/`After` אינם נקראים — מרווח‑פסקה ביחידות שורה יוחמץ. | `docx_style.dart:339-343` (חסר beforeLines) |
| 9 | `ST_OnOff`: `<w:b/>` ללא תכונה = דלוק | כן | נאמן | אלמנט נוכח ללא `w:val` → on. | `xml_extension.dart:11-15` |
| 10 | `ST_OnOff`: `true`/`1`/`on` = דלוק | כן | נאמן | כל ערך שאינו `0`/`false`/`off` → on (כולל true/1/on). | `xml_extension.dart:14` |
| 11 | `ST_OnOff`: `false`/`0`/`off` = ביטול מפורש | כן | נאמן | `val∈{0,false,off}`→off. `_onOff` שומר tri-state: "off מפורש" נבדל מ"חסר", כך שסגנון‑בן/ריצה יכולים לכבות ירושה. | `xml_extension.dart:14`; `docx_style.dart:681-684` |
| 12 | `ST_OnOff`: היעדר האלמנט = ירושה (≠ כבוי) | כן | נאמן | `_onOff` מחזיר `null` כשהאלמנט חסר; המנוע מבדיל בין null (ירושה) ל‑false (off). | `docx_style.dart:681-684`; `style_engine.dart:249-258` |
| 13 | כלל **XOR** ל‑toggle (b,bCs,i,iCs,caps,smallCaps,strike,dstrike,outline,shadow,emboss,imprint,vanish) | חלקי | חלקי | `DocxStyleResolver` מיישם XOR ל‑b,i,caps,smallCaps,dstrike,outline,shadow,emboss,imprint. **פערים:** (א) XOR רק בין רמת סגנון‑פסקה↔סגנון‑תו, לא לאורך שרשרת `basedOn`; (ב) toggle **ישיר** על ריצה **דורס** במקום XOR (מנוגד לדוגמת ISO 17.7.3, מסומן TODO golden); (ג) מחווט ל‑run בלבד (`resolveRun`), פסקה לא; (ד) `strike` ו‑`vanish` אינם ברשימת ה‑XOR. | `style_engine.dart:228-278, 136-160` |
| 14 | צבע RGB מפורש (hex RRGGBB) | כן | נאמן | `RRGGBB`/`#`/`0x` מפוענחים; מומרים ל‑`Color`. | `enums.dart:170-177`; `span_factory.dart:741-757` |
| 15 | צבע `auto` (שחור/לבן לפי רקע) | חלקי | חלקי | ב‑viewer `auto`→צבע גוף + היפוך near-black על **רקע גלובלי** כהה (סף lum 0.5/0.179). Word בוחר שחור/לבן לפי ה‑`shd` שמאחורי הטקסט בפועל. קיים `ThemeColorResolver.resolveAutoColor` עם הכלל הנכון — אך **אינו מחווט** ל‑viewer. | `span_factory.dart:742, 749-752`; (לא בשימוש) `style_engine.dart:348-353` |
| 16 | `themeColor` (הפניה ל‑clrScheme) | כן | ראו משימה 13 | `w:themeColor` נקרא לריצה/קו‑תחתון/shd; ב‑viewer נפתר מ‑`docxTheme.colors.getColor`. | `docx_style.dart:516-525`; `span_factory.dart:710-713` |
| 17 | `themeTint` / `themeShade` (חישוב הבהרה/האפלה) | כן | נאמן | tint = מיזוג ללבן `c*tint+255*(1-tint)`; shade = `c*shade`. ב‑viewer ע"י `alphaBlend(white/black, base)` — שקול לנוסחה. תואם `ThemeColorResolver.applyTintShade`. (קירוב RGB, לא HSL כמו Word — סטייה מזערית.) | `span_factory.dart:720-735`; `style_engine.dart:310-333` |
| 18 | `w:shd` — `val` (תבנית ST_Shd) | **לא** | לא | נקראים `fill`/`themeFill` בלבד; `w:val` (clear/solid/pct25/horzStripe…) **לא נקרא**. תבניות הצללה לא מרונדרות, ו‑`val="solid"` (שמילויו מ‑`w:color`) יוחמץ. | `docx_style.dart:376-383, 529-535` |
| 19 | `w:shd` — `fill` (צבע רקע) | כן | נאמן (אחיד) | `w:fill` (auto→null) מרונדר כרקע אחיד מאחורי ריצה/פסקה/תא, עם theme tint/shade. | `docx_style.dart:378`; `span_factory.dart:229-234`; `table_builder.dart:493` |
| 20 | `w:shd` — `color` (צבע התבנית) | **לא** | לא | `w:color` של `shd` לא נקרא. רלוונטי רק כש‑`val≠clear`; כיוון שגם `val` לא נתמך (פריט 18), צבע התבנית חסר לחלוטין. | אין (`docx_style.dart:376-383`) |
| 21 | `CT_Border` — `val` (ST_Border + art) | חלקי | חלקי | `val` ממופה ל‑enum `DocxBorder` (single/double/dotted/dashed/wave/threeD…), לא‑מוכר→single. **160 ה‑art borders (id) לא נתמכים** (פריט 27). | `docx_style.dart:686-713`; `enums.dart:220` |
| 22 | `CT_Border` — `sz` (eighth-points) | כן | נאמן~ | `sz`→עובי (ברירת מחדל 4 = 0.5pt); המרה `/8` pt. (אותה סטיית עיגול 1.333 כמו פריט 3.) | `docx_style.dart:692-696`; `docx_units.dart:52` |
| 23 | `CT_Border` — `space` (מרווח לטקסט) | **לא** | לא | `w:space` (מרווח גבול↔טקסט) לא נקרא — הגבול ייצמד לטקסט במקום המרווח של Word. | אין (`docx_style.dart:686-713`) |
| 24 | `CT_Border` — `color` + theme | חלקי | חלקי | `w:color` נקרא (auto→שחור). **`themeColor`/`themeTint`/`themeShade` של גבול לא נקראים** — גבול בצבע theme יאבד את גוונו. | `docx_style.dart:698-702` |
| 25 | `CT_Border` — `frame` (תלת‑ממד) | **לא** | לא | `w:frame` לא נקרא. | אין |
| 26 | `CT_Border` — `shadow` (צל לקו) | **לא** | לא | `w:shadow` (של גבול) לא נקרא. | אין |
| 27 | `CT_Border` — `id` (art border) | **לא** | לא | מזהה גבול‑אמנותי דקורטיבי לא נקרא; גבולות עמוד אמנותיים לא יוצגו. ראו משימה 05. | אין |

### ב.2 — פערים והוראות ל‑AI הבא

- **`w:shd` — תבנית וצבע‑תבנית חסרים (פריטים 18, 20).** נקרא רק `fill`. להוסיף קריאת `w:val` (ST_Shd) ו‑`w:color`: לכל הפחות לטפל ב‑`solid` (מילוי = `w:color`) שאחרת מוצג ללא רקע; תבניות pct/stripe — לקרב לצבע ממוצע. ראו [§17.5](17-enums.md).
- **`CT_Border` — שדות חסרים (פריטים 23–27).** `space`, `themeColor/themeTint/themeShade`, `frame`, `shadow`, `id` (art) אינם נקראים ב‑`_parseBorderSide`. `space` ו‑theme‑color משפיעים ישירות על נאמנות גבולות נפוצים. art borders — לתעד כסטייה מודעת (משימה 05).
- **`% string` ברוחב (פריט 6).** להוסיף ב‑`table_parser` ענף ל‑`w:w` המסתיים ב‑`%` (לחלץ את המספר לפני `%`). היום נופל בשקט.
- **`line units ×100` (פריט 8).** `beforeLines`/`afterLines`/`gridBefore`/`After` אינם נקראים → מרווחי פסקה/שורות גריד ביחידות שורה יוחמצו. להוסיף קריאה ל‑`docx_style` + המרה (×גובה שורה).
- **`position`/`kern` (פריט 2).** half-point מיושם לגודל פונט בלבד; העלאה/הורדה אנכית (`w:position`) וקרנינג (`w:kern`) חסרים. ראו משימה 03.
- **XOR toggle (פריט 13).** (א) `strike`/`vanish` להוסיף לרשימת ה‑XOR; (ב) להכריע (golden מול Word אמיתי) אם toggle ישיר צריך XOR ולא דריסה (`style_engine.dart:159`); (ג) לחווט גם פסקאות (`resolveParagraph` קיים אך לא בשימוש בקורא). ראו משימה 16.
- **`auto` color (פריט 15).** הבחירה כיום מול רקע גלובלי; Word בוחר מול ה‑`shd` המקומי. לחווט את `ThemeColorResolver.resolveAutoColor` עם ה‑fill האפקטיבי שמאחורי הריצה.
