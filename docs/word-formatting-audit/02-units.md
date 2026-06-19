# משימה 02 — יחידות מידה וטיפוסי ערכים

> **מקור:** סעיף §2 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —
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

### ב.1 — סריקה פר‑פריט

| # | פריט (יחידה/טיפוס) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | המרת **twip** (dxa) → px/pt | | | | |
| 2 | המרת **half-point** (sz/szCs/position/kern) | | | | |
| 3 | המרת **eighth-point** (עובי גבול) | | | | |
| 4 | המרת **EMU** (DrawingML) | | | | |
| 5 | **fiftieth of %** (pct ישן, 5000=100%) | | | | |
| 6 | **% string** (`"50%"` חדש) | | | | |
| 7 | **240ths of line** (lineRule=auto) | | | | |
| 8 | **line units ×100** (beforeLines/afterLines/gridBefore/After) | | | | |
| 9 | `ST_OnOff`: `<w:b/>` ללא תכונה = דלוק | | | | |
| 10 | `ST_OnOff`: `true`/`1`/`on` = דלוק | | | | |
| 11 | `ST_OnOff`: `false`/`0`/`off` = ביטול מפורש (גובר על ירושה) | | | | |
| 12 | `ST_OnOff`: היעדר האלמנט = ירושה (≠ כבוי) | | | | |
| 13 | כלל **XOR** ל‑toggle (b,bCs,i,iCs,caps,smallCaps,strike,dstrike,outline,shadow,emboss,imprint,vanish) | | | | |
| 14 | צבע RGB מפורש (hex RRGGBB) | | | | |
| 15 | צבע `auto` (שחור/לבן לפי רקע) | | | | |
| 16 | `themeColor` (הפניה ל‑clrScheme) | | | | |
| 17 | `themeTint` / `themeShade` (חישוב הבהרה/האפלה) | | | | |
| 18 | `w:shd` — `val` (תבנית ST_Shd) | | | | |
| 19 | `w:shd` — `fill` (צבע רקע) | | | | |
| 20 | `w:shd` — `color` (צבע התבנית) | | | | |
| 21 | `CT_Border` — `val` (ST_Border + art) | | | | |
| 22 | `CT_Border` — `sz` (eighth-points) | | | | |
| 23 | `CT_Border` — `space` (מרווח לטקסט) | | | | |
| 24 | `CT_Border` — `color` + theme(`themeColor`/`themeTint`/`themeShade`) | | | | |
| 25 | `CT_Border` — `frame` (תלת‑ממד) | | | | |
| 26 | `CT_Border` — `shadow` (צל לקו) | | | | |
| 27 | `CT_Border` — `id` (art border) | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
