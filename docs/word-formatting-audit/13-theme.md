# משימה 13 — ערכת עיצוב — `theme1.xml` (צבעים ופונטים)

> **מקור:** סעיף §13 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **סטטוס מימוש:** 🔄 טוקני themeColor (3,6) מומשו; פונט Hebr (9‑10) נותר נדחה &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-23

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

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

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

> **מפת המימוש.** ה‑theme נקרא בעת פתיחת המסמך: `docx_reader.dart:105‑127` מאתר את `theme1.xml`
> דרך יחס ה‑relationship (תומך ב‑theme2.xml וכו') וקורא `ThemeParser.parse` (`style_parser.dart:171`).
> הפענוח מפצל לשניים: **צבעים** ב‑`_parseColors` (`style_parser.dart:180‑220`) → `DocxThemeColors`,
> **פונטים** ב‑`_parseFonts` (`style_parser.dart:222‑251`) → `DocxThemeFonts`. שתי המפות נשמרות ב‑`DocxTheme`
> (`docx_theme.dart`) ומועברות לצופה. **בזמן רינדור:** צבע theme נפתר דרך `DocxThemeColors.getColor`
> (`docx_theme.dart:128‑161`) + tint/shade ב‑`resolveColor` של הצופה (`span_factory.dart:704‑737`,
> וכפילויות ב‑`list_builder`/`table_builder`/`shape_builder`) או `ThemeColorResolver` בצד הקורא
> (`style_engine.dart:295‑333`). פונט theme נפתר דרך `DocxThemeFonts.getFont` (`docx_theme.dart:196‑215`),
> נצרך בפיצול פר‑כתב ב‑`span_factory.dart:250‑269` (CS דרך `csTheme`; לטיני דרך `asciiTheme/hAnsiTheme`).
> **שני חורים מבניים:** (א) המודל `DocxThemeFonts` מחזיק **רק** latin/ea/cs — אין שדה לפונט פר‑כתב
> (`a:font script="Hebr"`); (ב) `w:clrSchemeMapping` מ‑settings.xml **אינו נקרא** — המיפוי
> `ST_ThemeColor`→slot מקודד‑קשיח כברירת‑המחדל של Word בתוך `getColor`.

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `a:clrScheme` — dk1/lt1/dk2/lt2 | כן | נאמן | ארבעת הסלוטים נקראים ונשמרים, ונפתרים בעת הפניית `themeColor`. `getColor` ממפה גם את שמות‑המסמך `text1`→dk1, `background1`→lt1, `text2`→dk2, `background2`→lt2 (התנהגות ברירת‑המחדל של Word). הצבע הסופי זהה ל‑Word כל עוד המסמך אינו מגדיר `w:clrSchemeMapping` מותאם (ר' פריט 6). | קריאה: `style_parser.dart:205‑209`; פתרון: `docx_theme.dart:131‑141`; רינדור: `span_factory.dart:710‑712` |
| 2 | `a:clrScheme` — accent1–accent6 | כן | נאמן | כל ששת הצבעים נקראים, נשמרים ונפתרים נכון (כולל tint/shade ב‑`resolveColor`/`ThemeColorResolver`). נצרכים בטקסט, תבליטים, גבולות טבלה ומילוי צורות. תואם Word. | קריאה: `style_parser.dart:210‑215`; פתרון: `docx_theme.dart:142‑153` |
| 3 | `a:clrScheme` — hlink/folHlink | חלקי | **לא** | שני הסלוטים **נקראים ונשמרים**, אך הטוקן ש‑Word כותב ב‑`w:themeColor` הוא `hyperlink`/`followedHyperlink` — ו‑`getColor` מכיר רק `hlink`/`folHlink`, כך שהפניה אמיתית מהמסמך מחזירה null. בנוסף, צבע הקישור בצופה מקודד‑קשיח (כחול) ואינו נשען על סלוט ה‑theme (ר' משימה 10 — "סגנונות Hyperlink קשיחים"). תוצאה: הערכים נקראים אך **בפועל אינם בשימוש** — קישור בצבע theme לא‑סטנדרטי יוצג בכחול הקבוע. | קריאה: `style_parser.dart:216‑218`; פתרון חסר: `docx_theme.dart:154‑157` (אין `hyperlink`/`followedHyperlink`) |
| 4 | `a:sysClr` (windowText/window) + `lastClr` | כן | נאמן | `getColor` מעדיף `lastClr` (הצבע המטמון האחרון) ונופל ל‑`val` רק בהיעדרו — בדיוק כהמלצת הייחוס. עבור `windowText`/`window` Word כמעט תמיד כותב `lastClr` (000000/FFFFFF). **קצה:** אם `lastClr` חסר, יוחזר המחרוזת `"windowText"`/`"window"` כ"צבע" → כשל פענוח hex → null (נדיר; Word תמיד כותב lastClr). | `style_parser.dart:189‑194` |
| 5 | `a:srgbClr` | כן | נאמן | נקרא ישירות מ‑`@val` (hex 6 ספרות) לכל סלוט. תואם Word. | `style_parser.dart:197‑200` |
| 6 | מיפוי `ST_ThemeColor`→slot דרך `w:clrSchemeMapping` | חלקי | נאמן~ (ברירת‑מחדל) / **לא** (מותאם) | המיפוי **מקודד‑קשיח** כברירת‑המחדל של Word (`text1`→dk1, `background1`→lt1, `text2`→dk2, `background2`→lt2, accent ישיר). `w:clrSchemeMapping` שב‑settings.xml **אינו נקרא**, ולכן מסמך שמחליף/ממחזר את המיפוי (למשל ערכה כהה שממפה bg1↔dk1) יוצג בצבעים הפוכים/שגויים. בנוסף `getColor` **אינו מכיר** את הטוקנים החלופיים `dark1`/`light1`/`dark2`/`light2` (וגם `hyperlink`/`followedHyperlink`, ר' פריט 3) → הפניה כזו מחזירה null. רוב המסמכים משתמשים במיפוי ברירת‑המחדל ובטוקנים `text*/background*` → נאמן בפועל; סטייה מודעת לקצוות. | `docx_theme.dart:128‑161` (קשיח); settings: לא נקרא |
| 7 | `a:fontScheme` — `majorFont` (latin/ea/cs) | כן | נאמן | latin/ea/cs נקראים מ‑`a:majorFont` ונפתרים דרך `getFont('majorHAnsi/EastAsia/Bidi')`. נצרך לטקסט שמפנה `*Theme="major*"` (כותרות). תואם Word. **הסתייגות:** רק שלושת הילדים הללו — `a:font script="…"` שמתחת ל‑`majorFont` מתעלם (ר' פריט 9). | קריאה: `style_parser.dart:226‑245`; פתרון: `docx_theme.dart:198‑204` |
| 8 | `a:fontScheme` — `minorFont` (latin/ea/cs) | כן | נאמן | כמו 7 עבור גוף הטקסט (`minor*`). latin/ea/cs נקראים ונפתרים. תואם Word פרט לפונט פר‑כתב (פריט 9). | קריאה: `style_parser.dart:233‑249`; פתרון: `docx_theme.dart:205‑211` |
| 9 | `a:font script="Hebr"` (fallback פר‑כתב — קריטי לעברית) | **לא** | **לא** | `_parseFonts` קורא **אך ורק** את `a:latin`/`a:ea`/`a:cs`; הצמתים `a:font script="…"` **לא נקראים**, ול‑`DocxThemeFonts` אין שדה פר‑כתב. בערכות Office רבות `<a:cs>` **ריק** והפונט העברי מגיע דווקא מ‑`<a:font script="Hebr" typeface="David"/>` — כך שריצה עברית המפנה `csTheme="minorBidi"` תקבל מחרוזת ריקה ותיפול ל‑fallback העברי הגנרי של הצופה (`Noto Sans Hebrew` וכו', `font_resolver.dart:242‑243`) ולא לפונט שערכת ה‑theme התכוונה אליו. הטקסט **כן** מוצג ובכיוון נכון, אך הפונט עשוי להיות שגוי. מקל: רוב הריצות העבריות מציינות `w:cs="David"` מפורש (לא דרך theme) ואז אין פער. | פער קריאה: `style_parser.dart:222‑251`; מודל חסר שדה: `docx_theme.dart:169‑216` |
| 10 | `a:font script="…"` נוספים (Arab וכו') | **לא** | **לא** | זהה לפריט 9 — כל ה‑`a:font` הפר‑כתביים (Arab/Thai/…) מתעלמים. הפניית theme לכתב שאין לו `a:cs` מתאים תיפול ל‑fallback של הצופה. נדיר יחסית בקורפוס עברי. | כפריט 9 |
| 11 | הפניות `majorHAnsi/Ascii/Bidi/EastAsia` | כן | נאמן | `getFont` ממפה את כל ארבע ההפניות (HAnsi/Ascii→latin, Bidi→cs, EastAsia→ea). הצופה צורך `asciiTheme`/`hAnsiTheme`/`eastAsiaTheme` לסגמנט לטיני ו‑`csTheme` לסגמנט מורכב בפיצול פר‑כתב. בכפוף לחורי פריט 9 (פר‑כתב), תואם Word. | פתרון: `docx_theme.dart:198‑204`; צריכה: `span_factory.dart:252‑264` |
| 12 | הפניות `minorHAnsi/Ascii/Bidi/EastAsia` | כן | נאמן | כמו 11 עבור `minor*`. כל ארבע ההפניות ממופות ונצרכות. | פתרון: `docx_theme.dart:205‑211`; צריכה: `span_factory.dart:252‑264` |
| 13 | `a:fmtScheme` (fillStyleLst/lnStyleLst/effectStyleLst/bgFillStyleLst — לצורות) | **לא** | n/a (סטטי) | הקורא **אינו מפענח** את `a:fmtScheme` כלל (הוא קיים רק בצד **הכותב**, פלט ברירת‑מחדל ב‑`styles_generator.dart:30‑35`). צורה שמפנה לסגנון theme דרך אינדקס ב‑`fillStyleLst`/`lnStyleLst` (`wps:style`→`a:fillRef idx=…`) לא תקבל את המילוי/קו מה‑theme. בפועל הצופה קורא צבע בסיס מ‑`a:schemeClr` של הצורה (`inline_parser.dart:981‑1003`, ממפה `tx1/bg1`→aliases) אך **בלי** טרנספורמי `lumMod/lumOff/shade/tint` ובלי styleLst. רלוונטי רק לצורות תלויות‑theme; רוב הצורות נושאות מילוי מפורש. | פער: אין פענוח `fmtScheme`; כתיבה בלבד: `styles_generator.dart:30‑35` |

### ב.2 — פערים והוראות ל‑AI הבא

**עיקרון:** הבסיס נאמן — ערכת הצבעים (dk/lt/accent) וערכת הפונטים latin/ea/cs נקראות, נשמרות ונפתרות
נכון (כולל tint/shade), והפניות `major*/minor*` עובדות בשני הצירים. הפערים מתרכזים ב‑**פר‑כתב** (עברית!),
ב‑**מיפוי הצבעים המותאם**, ובטוקני‑קצה.

**פערים בעלי השלכה ויזואלית (לתעד/לשקול מימוש):**
- **`a:font script="Hebr"` — פונט עברי מ‑theme (פריטים 9‑10, קריטי).** המודל `DocxThemeFonts` מחזיק רק
  latin/ea/cs; הצמתים הפר‑כתביים מתעלמים. ריצה עברית המפנה `csTheme="minorBidi"` כש‑`<a:cs>` ריק תאבד
  את הפונט המיועד (David/וכו') ותיפול ל‑fallback הגנרי. **תיקון מינימלי:** להוסיף ל‑`DocxThemeFonts` מפת
  `script→typeface` (לפחות `major`/`minor`), לקרוא אותה ב‑`_parseFonts` (`style_parser.dart:222‑251`),
  ובפתרון פונט CS להעדיף את `script="Hebr"` כש‑`a:cs` ריק.
- **`hyperlink`/`followedHyperlink` כטוקני `w:themeColor` (פריט 3).** הסלוטים נקראים אך `getColor` לא
  ממפה את הטוקנים `hyperlink`/`followedHyperlink` (רק `hlink`/`folHlink`) → null. להוסיף aliases ב‑`getColor`
  (`docx_theme.dart:154‑157`). בנוסף, צבע הקישור בצופה קשיח (כחול) — תלוי בפתרון סגנון `Hyperlink` (משימה 10).
- **טוקנים חלופיים `dark1`/`light1`/`dark2`/`light2` (פריט 6).** ערכי `ST_ThemeColor` חוקיים שאינם ממופים
  ב‑`getColor` → null. להוסיף aliases (dark1→dk1, light1→lt1, וכו').
- **`w:clrSchemeMapping` מותאם (פריט 6).** המיפוי קשיח לברירת‑מחדל; מסמך שממחזר את המיפוי יוצג שגוי.
  לשקול קריאת `w:clrSchemeMapping` מ‑settings.xml (כפילות עם משימה 14) והזרמת המיפוי ל‑`getColor`.

**סטיות מודעות / השפעה נמוכה:**
- **`a:fmtScheme` (פריט 13).** לא מפוענח; רלוונטי רק לצורות שמפנות לסגנון theme דרך `fillRef/lnRef idx`.
  טרנספורמי `lumMod/lumOff/shade` על `a:schemeClr` של צורות גם הם לא מיושמים (צבע בסיס בלבד).
- **`a:sysClr` ללא `lastClr` (פריט 4).** קצה תאורטי — Word תמיד כותב `lastClr`.

### ב.3 — עדכון מימוש (בוצע ע"י ה‑AI המבצע, 2026‑06‑23)

> מבוצע לפי `PROMPTER.md`. בדיקה נלווית; `flutter analyze` נקי; הסוויטה ירוקה.

**מומש 1:1:**

| פריט | מה תוקן | קובץ | בדיקה |
|---|---|---|---|
| 3, 6 | טוקני `w:themeColor` (`dark1`/`light1`/`dark2`/`light2`/`hyperlink`/`followedHyperlink`) ממופים ל‑slot ה‑clrScheme המתאים (קודם → null → שחור) | `docx_theme.dart` (`getColor`) | `theme_color_tokens_13_test.dart` |

**נותר נדחה / סטיות מודעות:**

- **`a:font script="Hebr"` — פונט עברי מ‑theme (9‑10, קריטי):** `DocxThemeFonts` ללא שדה פר‑כתב; דורש הרחבת מודל + חיווט — נדחה (גדול).
- **`w:clrSchemeMapping` מותאם (6), `a:fmtScheme` (13), `lumMod/lumOff` לצורות:** נותרו פערים מתועדים.
