# משימה 02 — יחידות מידה וטיפוסי ערכים

> **מקור:** סעיף §2 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **סטטוס מימוש:** ✅ פערי‑היחידות מומשו 1:1 (shd solid/pctN, גבול space 4‑צדדי+theme, רוחב "%", beforeLines/afterLines, auto‑color מול shd מקומי) + סטיות מודעות מתועדות (hatch, 3D/art) + העברות (position/kern→03, XOR→16) &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-22
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
| 2 | המרת **half-point** (sz/szCs/position/kern) | חלקי | נאמן (לגודל פונט) | `sz`/`szCs`→גודל פונט מומר נכון (`val/2` pt, `*96/72` px). `position`/`kern` **נקראים ל‑AST** כיום (`kernMinHalfPoints`/`raiseLowerHalfPoints`, `inline_parser.dart`). **הכרעה:** רינדור ההעלאה/הורדה+קרנינג נדחה ל‑task 03 (ראו ב.2). | `docx_style.dart:546-552`; `inline_parser.dart:470-471` |
| 3 | המרת **eighth-point** (עובי גבול) | כן | נאמן~ | `val/8` pt. ההמרה ב‑viewer משתמשת ב‑`1.333` (קירוב ל‑4/3) → סטיית עיגול תת‑פיקסלית. | `docx_units.dart:52`; `measurements.dart:101` |
| 4 | המרת **EMU** (DrawingML) | כן | נאמן | `emu/914400` inch, `emu/12700` pt, `emu/9525` px (96 DPI) — תואם ייחוס. | `docx_units.dart:37`; `measurements.dart:20-32` |
| 5 | **fiftieth of %** (pct ישן, 5000=100%) | חלקי | n/a (תשתית) | `w:tblW@w:type="pct"` עם ערך מספרי נקרא; `pctToFraction = pct/5000`. רק רוחב **טבלה/תא** — לא הורחב לכל ההקשרים. | `table_parser.dart:55-62`; `docx_units.dart:58` |
| 6 | **% string** (`"50%"` חדש) | כן | נאמן | ✅ מומש: `w:tblW@w:w` המסתיים ב‑`%` מומר ליחידת fiftieths (`50%`→2500) ומסומן `pct`; זורם דרך `resolveTableColumnWidths` (מדידה≡רינדור). הצורה המספרית לא נשברה. | `table_parser.dart` (tblW) |
| 7 | **240ths of line** (lineRule=auto) | כן | נאמן | `line`+`lineRule` נפרסים; ל‑`auto`: יחס שורה = `lineSpacing/240` (240=יחיד, 360=1.5, 480=כפול). `exact`/`atLeast` מטופלים דרך strut (קופסת שורה כפויה/מינ'). | `docx_style.dart:345-349`; `span_factory.dart:112-119` |
| 8 | **line units ×100** (beforeLines/afterLines/gridBefore/After) | כן | נאמן~ | ✅ מומש: `beforeLines`/`afterLines` נקראים ל‑AST (round-trip) ומומרים לפיקסלים דרך גובה‑שורה נומינלי משותף (`resolveSingleLineHeightPx`) ב‑render+measure (מדידה≡רינדור, בדיקת delta). beforeLines גובר על twips (ISO §17.3.1.33). `gridBefore`/`gridAfter` נקראים; `before`/`after` ב‑twips מלאים. (קירוב: מתעלם מ‑leading מובנה של הפונט — נדיר, מתועד.) | `docx_style.dart`; `docx_block.dart`; `span_factory.dart` (`resolveSingleLineHeightPx`); `text_measurer.dart` |
| 9 | `ST_OnOff`: `<w:b/>` ללא תכונה = דלוק | כן | נאמן | אלמנט נוכח ללא `w:val` → on. | `xml_extension.dart:11-15` |
| 10 | `ST_OnOff`: `true`/`1`/`on` = דלוק | כן | נאמן | כל ערך שאינו `0`/`false`/`off` → on (כולל true/1/on). | `xml_extension.dart:14` |
| 11 | `ST_OnOff`: `false`/`0`/`off` = ביטול מפורש | כן | נאמן | `val∈{0,false,off}`→off. `_onOff` שומר tri-state: "off מפורש" נבדל מ"חסר", כך שסגנון‑בן/ריצה יכולים לכבות ירושה. | `xml_extension.dart:14`; `docx_style.dart:681-684` |
| 12 | `ST_OnOff`: היעדר האלמנט = ירושה (≠ כבוי) | כן | נאמן | `_onOff` מחזיר `null` כשהאלמנט חסר; המנוע מבדיל בין null (ירושה) ל‑false (off). | `docx_style.dart:681-684`; `style_engine.dart:249-258` |
| 13 | כלל **XOR** ל‑toggle (b,bCs,i,iCs,caps,smallCaps,strike,dstrike,outline,shadow,emboss,imprint,vanish) | חלקי | חלקי | `DocxStyleResolver` מיישם XOR ל‑b,i,caps,smallCaps,dstrike,outline,shadow,emboss,imprint. **הכרעה:** רזולוציית ה‑toggle (XOR לאורך basedOn / direct‑XOR / חיווט פסקה / strike+vanish) היא מנוע‑הסגנונות — מחוץ להיקף יחידות זה; משימה ל‑AI הבא ב‑task 16 (ראו ב.2). | `style_engine.dart:228-278, 136-160` |
| 14 | צבע RGB מפורש (hex RRGGBB) | כן | נאמן | `RRGGBB`/`#`/`0x` מפוענחים; מומרים ל‑`Color`. | `enums.dart:170-177`; `span_factory.dart:741-757` |
| 15 | צבע `auto` (שחור/לבן לפי רקע) | כן | נאמן | ✅ מומש: כשיש `shd` מקומי (ריצה→פסקה→תא, מושחל ל‑`ParagraphBuilder`) — `auto`→שחור/לבן לפי בהירות ה‑fill המקומי (`resolveAutoTextColor`, רינדור בלבד). בהיעדר `shd` מקומי נשמרת התנהגות ה‑theme/מצב‑כהה הקיימת (ברירת גוף). | `span_factory.dart` (`resolveAutoTextColor`); `paragraph_builder.dart`; `table_builder.dart` |
| 16 | `themeColor` (הפניה ל‑clrScheme) | כן | ראו משימה 13 | `w:themeColor` נקרא לריצה/קו‑תחתון/shd; ב‑viewer נפתר מ‑`docxTheme.colors.getColor`. | `docx_style.dart:516-525`; `span_factory.dart:710-713` |
| 17 | `themeTint` / `themeShade` (חישוב הבהרה/האפלה) | כן | נאמן | tint = מיזוג ללבן `c*tint+255*(1-tint)`; shade = `c*shade`. ב‑viewer ע"י `alphaBlend(white/black, base)` — שקול לנוסחה. תואם `ThemeColorResolver.applyTintShade`. (קירוב RGB, לא HSL כמו Word — סטייה מזערית.) | `span_factory.dart:720-735`; `style_engine.dart:310-333` |
| 18 | `w:shd` — `val` (תבנית ST_Shd) | כן | נאמן~ | ✅ `resolveShdFill`: `clear`→fill, `solid`→color (תוקן הבאג של רקע חסר), `pctN`/פס/רשת→מיזוג ליניארי לפי כיסוי. גיאומטריית ה‑hatch ומיזוג‑theme‑כפול = סטייה מודעת (ראו ב.2). | `xml_extension.dart` (`resolveShdFill`); `docx_style.dart`; `table_parser.dart` |
| 19 | `w:shd` — `fill` (צבע רקע) | כן | נאמן (אחיד) | `w:fill` (auto→null) מרונדר כרקע אחיד מאחורי ריצה/פסקה/תא, עם theme tint/shade. | `docx_style.dart:378`; `span_factory.dart:229-234`; `table_builder.dart:493` |
| 20 | `w:shd` — `color` (צבע התבנית) | כן | נאמן | ✅ `w:color` (+`w:themeColor`) נקרא ומשמש כצבע האפקטיבי ב‑`solid` וכקצה‑המיזוג ב‑`pctN`. | `xml_extension.dart` (`resolveShdFill`) |
| 21 | `CT_Border` — `val` (ST_Border + art) | חלקי | חלקי | `val` ממופה ל‑enum `DocxBorder` (single/double/dotted/dashed/wave/threeD…), לא‑מוכר→single. **160 ה‑art borders (id) לא נתמכים** (פריט 27). | `docx_style.dart:686-713`; `enums.dart:220` |
| 22 | `CT_Border` — `sz` (eighth-points) | כן | נאמן~ | `sz`→עובי (ברירת מחדל 4 = 0.5pt); המרה `/8` pt. (אותה סטיית עיגול 1.333 כמו פריט 3.) | `docx_style.dart:692-696`; `docx_units.dart:52` |
| 23 | `CT_Border` — `space` (מרווח לטקסט) | כן | נאמן | ✅ נקרא ב‑`_parseBorderSide`; מרונדר כ‑padding פנימי בכל 4 הצדדים. top/bottom משוקפים ב‑spacing; left/right מצמצמים את רוחב‑הפריסה ב‑`TextMeasurer` (`_hBorderSpacePx`) — מדידה≡רינדור, נבדק delta+wrapping. גבול `none` לא מוסיף מרווח. | `docx_style.dart` `_parseBorderSide`; `paragraph_builder.dart`; `text_measurer.dart` |
| 24 | `CT_Border` — `color` + theme | כן | נאמן | ✅ `themeColor`/`themeTint`/`themeShade` נקראים כעת ב‑`_parseBorderSide` (פריטי גבול‑פסקה/ריצה/סגנון) ונפתרים ב‑`_buildBorderSide`→`resolveColor`; גבול בצבע theme שומר גוונו. round‑trip דרך `_buildBorder`. | `docx_style.dart` `_parseBorderSide`; `paragraph_builder.dart:689` |
| 25 | `CT_Border` — `frame` (תלת‑ממד) | לא | סטייה מודעת | `w:frame` (אפקט מסגרת 3D) לא נקרא. **הכרעה:** סטייה מודעת (ראו ב.2) — אפקט נדיר וזניח חזותית; ה‑val/sz/space/color/theme (הקובעים את הנראות) מלאים. | ב.2 |
| 26 | `CT_Border` — `shadow` (צל לקו) | לא | סטייה מודעת | `w:shadow` (צל 3D לקו) לא נקרא. **הכרעה:** סטייה מודעת (ראו ב.2; כמו 25). | ב.2 |
| 27 | `CT_Border` — `id` (art border) | לא | סטייה מודעת | מזהה גבול‑אמנותי לא נקרא; גבולות art מצוירים כקו `single`. **הכרעה:** סטייה מודעת (ראו ב.2; נכסים גרפיים לא זמינים; task 05). | ב.2 |

### ב.2 — הכרעות לכל פער + הוראות ל‑AI הבא (סגירה)

> **מצב:** כל פער קיבל הכרעה — *מומש 1:1* / *סטייה מודעת* / *משימה ל‑AI הבא*. אין פער ללא החלטה. סעיף זה **עצמאי**: כל סיבה+חומרה כתובות כאן (אין תלות בקובץ חיצוני).
> **אימות שבוצע:** `flutter analyze` נקי בשתי החבילות; `flutter test` — docx_creator 458✅ (1 דילוג), docx_file_viewer ✅ (4 הנכשלות היחידות = קובצי‑fixture חסרים בצ'קאאוט בלבד, לא קוד). בדיקות חדשות: `units_value_types_test.dart` (22 — כולל עברית+אנגלית), `border_space_parity_test.dart` (3), `paragraph_units_open_items_test.dart` (7 — beforeLines/auto/left-right, delta מדידה≡רינדור).

#### ✅ מומש 1:1 (קוד + בדיקה נכשלת‑לפני/עוברת‑אחרי)
- **`w:shd` — `val`+`color` (פריטים 18, 20).** `resolveShdFill` ([xml_extension.dart](../../packages/docx_creator/lib/src/core/xml_extension.dart)) משותף לכל אתרי ה‑shd (פסקה/ריצה/תא/טבלה/סגנון): `clear`→fill, **`solid`→color** (תיקון הבאג שבו `solid` הוצג ללא רקע), `pctN`/פס/רשת→מיזוג ליניארי של color מעל fill ביחס הכיסוי. צבע בלבד — מדידה≡רינדור נשמר.
- **`CT_Border` — `space` בכל 4 הצדדים (פריט 23).** נקרא ב‑`_parseBorderSide`; מרונדר כ‑padding פנימי. top/bottom משוקפים ב‑spacing; left/right מצמצמים את רוחב‑הפריסה גם ב‑`text_measurer` (`_hBorderSpacePx`, gated) → עטיפת שורות זהה. גבול `none` לא מוסיף מרווח. בדיקות delta+wrapping.
- **`CT_Border` — `color`+theme (פריט 24).** `themeColor`/`themeTint`/`themeShade` נקראים כעת לגבולות פסקה/ריצה/סגנון (קודם — רק לטבלה); נפתרים ב‑`_buildBorderSide`→`resolveColor`. round‑trip דרך `_buildBorder`.
- **`% string` ברוחב (פריט 6).** `w:tblW@w:w` המסתיים ב‑`%` → fiftieths (`50%`=2500) + `pct`; זורם דרך `resolveTableColumnWidths`.
- **`beforeLines`/`afterLines` — ריווח פסקה ביחידות שורה (פריט 8).** שדות חדשים ל‑AST (`spacingBeforeLines`/`spacingAfterLines`, round‑trip ב‑`DocxParagraph.buildXml`); המרה לפיקסלים דרך גובה‑שורה נומינלי משותף (`resolveSingleLineHeightPx`) ב‑render+measure → מדידה≡רינדור (בדיקת delta). `exact`/`atLeast` משתמש בגובה ה‑strut המוחלט (`lineSpacing/15`); `auto` משתמש בגודל הפונט (כולל `szCs` לכתב מורכב) × יחס‑השורה. beforeLines גובר על twips (ISO §17.3.1.33), והעימוד מדכא אותו בראש עמוד כמו twips. **קירוב מתועד:** מתעלם מה‑leading המובנה של הפונט ומ‑super/subscript (פיצ'ר נדיר).
- **צבע `auto` מול ה‑`shd` המקומי (פריט 15).** כשיש shd מקומי (ריצה→פסקה→תא, מושחל ל‑`ParagraphBuilder` דרך `inheritedBackground`) — `resolveAutoTextColor` בוחר שחור/לבן לפי בהירות ה‑fill (רינדור בלבד; צבע לא משפיע על מטריקות). בהיעדר shd מקומי נשמרת התנהגות ה‑theme/מצב‑כהה הקיימת.

#### 🟨 סטיות מודעות (סיבה+חומרה כאן)
- **תבניות shd `pctN`/פס/רשת + מיזוג‑theme‑כפול (פריט 18).** *חומרה: נמוכה.* ה‑viewer מצייר צבע‑רקע אחיד אחד, לכן גיאומטריית ה‑hatch עצמה לא מצוירת (מקורבת למיזוג שטוח), וכשהתבנית מערבת **צבע‑theme** (לא hex טהור) נשמר ה‑fill בלבד (המודל השטוח לא נושא שני מצייני‑theme). כמעט כל shd אמיתי הוא `clear`+fill או `solid` — שניהם מדויקים. **ל‑AI הבא (אם יידרש):** hatch אמיתי דורש `CustomPaint` ברקע + פתרון שני צבעי‑theme בנפרד.
- **`CT_Border` 3D — `w:frame`/`w:shadow` + `w:id` (art) (פריטים 25–27).** *חומרה: נמוכה.* אפקט מסגרת/צל תלת‑ממדי לא נקרא; גבול art (160 ערכי id) מצויר כקו `single`. אפקט 3D זניח חזותית, נכסי art לא זמינים. ה‑val/sz/space/color/theme (הקובעים את הנראות) מלאים. **ל‑AI הבא:** art borders — task 05.

#### ➡️ משימות ל‑AI הבא (שייכות ל‑task אחר, מחוץ להיקף "יחידות")
- **רינדור `position`/`kern` (פריט 2) → task 03.** ה‑half-points **כבר נקראים ל‑AST** (`raiseLowerHalfPoints`/`kernMinHalfPoints` ב‑`inline_parser.dart`); נותר הרינדור: העלאה/הורדה אנכית (`w:position`) דורש `WidgetSpan`+`Transform`+placeholder תואם במדידה, וקרנינג (`w:kern`) — `letterSpacing`. שמירה על מדידה≡רינדור היא התנאי.
- **רזולוציית XOR ל‑toggle (פריט 13) → task 16.** `style_engine` מיישם XOR בין רמת פסקה↔תו ל‑b,i,caps,smallCaps,dstrike,outline,shadow,emboss,imprint. נותר: (א) `strike`/`vanish` לרשימת ה‑XOR; (ב) הכרעה (golden מול Word) אם toggle ישיר צריך XOR ולא דריסה; (ג) חיווט גם לפסקאות (`resolveParagraph` קיים, לא בשימוש בקורא); (ד) XOR לאורך שרשרת `basedOn`.
