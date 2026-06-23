# משימה 16 — סדר ההחלה והעדיפות (resolution) — קריטי למנוע

> **מקור:** סעיף §16 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **סטטוס מימוש:** 🔄 השפעת §16.4 (jc תלוי‑כיוון) שופרה דרך 04/06; ליבת ה‑resolution נשארת כפי שתועדה &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-23

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

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

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

### ב.1 — סריקה פר‑פריט

| # | פריט (כלל resolution) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | סדר pPr: pPrDefault → סגנון טבלה (מותנה) → סגנון מספור → pStyle (basedOn) → ישיר | חלקי | נאמן~ | Word מצטבר את עיצוב הפסקה בחמש שכבות. **ממומש רק החצי המרכזי:** pPrDefault → שרשרת basedOn (root→leaf) → ישיר, דרך המסלול הישן `resolveStyle` + `effectiveStyle.merge(parsedProps)` ב‑block_parser. **חסרות שתי שכבות:** (א) **pPr של סגנון טבלה** (כולל מותנה §6.5) — אינו מוחל על פסקאות בתא (`_parseFullParagraph` גם הוא קורא רק `resolveStyle(pStyle)`); (ב) **lvl/pPr של סגנון המספור** — לא נכנס כשכבה; הזחת רמה מוחלת בנפרד ברינדור (numbering_resolver/list builder), לא כ‑pPr. מנוע הפסקה הנקי `resolveParagraph` קיים אך **לא מחווט**. | מסלול ישן `reader_context.dart:101-136`+`block_parser.dart:190-200`; תא `table_parser.dart:553-563`; מנוע לא‑מחווט `style_engine.dart:164-176` |
| 2 | סדר rPr: rPrDefault → סגנון טבלה → pStyle → סגנון מספור (תווית) → rStyle → ישיר | חלקי | נאמן~ | המנוע `resolveRun` מיישם **rPrDefault → שרשרת pStyle ⊕ שרשרת rStyle → ישיר** (עם XOR בין‑רמתי, פריט 4). הסדר היחסי pStyle→rStyle→ישיר נאמן. **חסרות שתי שכבות:** rPr מ**סגנון טבלה** (מותנה) ו‑rPr מ**סגנון המספור** (תווית `lvl/rPr`) אינן חלק מהחישוב במנוע — תווית המספור מקבלת rPr חלקי בנתיב נפרד (משימה 08). | מנוע `style_engine.dart:136-160,214-224`; חיווט `inline_parser.dart:357-375`; בסיס `reader_context.dart:90-94` |
| 3 | סגנון תו (rStyle) גובר על סגנון פסקה (Hyperlink בכותרת) | כן | נאמן | רשימת השכבות במנוע היא `[pStyle, rStyle]` ממוזגת לפי הסדר, כך ש‑rStyle (5) מנצח את pStyle (3) למאפיינים לא‑toggle — בדיוק התרחיש הקנוני: `Hyperlink` משנה צבע/קו תחתון גם בתוך כותרת. (הצבעת הקישור עצמה מקושחת לכחול+קו תחתון ב‑inline_parser, משימה 10.) | `style_engine.dart:147-152` |
| 4 | toggle XOR בין שכבות סגנון (b/bCs/i/iCs/caps/smallCaps/strike/dstrike/outline/shadow/emboss/imprint/vanish) | חלקי | נאמן~ | `_resolveToggle` מיישם XOR‑parity על **9 toggles**: b, i, caps, smallCaps, dstrike, outline, shadow, emboss, imprint — **בין הרמות** (pStyle‑level מול rStyle‑level), עם hard‑reset על off מפורש (`val="0"`). docDefaults הוא בסיס‑fallback ולא משתתף ב‑XOR (תואם Word). **שתי הגבלות מודעות:** (א) ה‑XOR **לא** מופעל בתוך שרשרת basedOn (השרשרת מקופלת nearest‑wins — מודל שמרני מתועד); (ב) **חסרים מהרשימה:** `bCs`/`iCs` (נקראים ישיר בלבד ב‑inline_parser, לא יורשים/לא XOR), `strike` (חד) שמטופל דרך `decorations` לא‑אדיטיבי, ו‑`vanish` (ישיר בלבד). | `style_engine.dart:228-278` |
| 5 | עיצוב ישיר `val="false"` מנצח סופית | כן~ | נאמן~ | `resolveRun` מסיים ב‑`styleMerged.merge(direct)` — ערך ישיר דורס סופית. **off מפורש** (`w:b w:val="0"`) הוא non‑null ולכן מכבה גם אם הסגנונות הדליקו — נאמן, וזה מה שכפתור Bold של Word כותב בפועל. **נקודת ספק golden:** ISO §17.7.3 מדגים שגם toggle **ישיר** דלוק (`<w:b/>`) על טקסט שכבר מודגש מסגנון → התוצאה **לא** מודגש (XOR ברמה הישירה); הקוד כאן **דורס** (כן מודגש). השפעה מעשית מצומצמת (off מפורש מטופל נכון), אך ה‑on הישיר עדיין פתוח עד golden אמיתי. | `style_engine.dart:153-159` (TODO(golden)) |
| 6 | מיפוי `jc` תלוי‑bidi: start/end (לוגי, מתהפך) | חלקי | **לא** | `start` נאמן: הקורא ממפה `start`→`DocxAlign.left`, והרינדר ממפה `DocxAlign.left`→`start` (לוגי) → ב‑RTL מתהפך לימין ✓. **`end` שבור:** הקורא ממפה `end`→`DocxAlign.right`, והרינדר מתייחס ל‑`DocxAlign.right` כ‑`right` **פיזי** (לא מתהפך) → פסקת RTL עם `jc="end"` תיושר לימין במקום לשמאל. | פירוק `docx_style.dart:330-333`; רינדור `bidi_align.dart:39-41,64-75` |
| 7 | מיפוי `jc`: left/right (פיזי, לא מתהפך) | חלקי | **לא** | `right` נאמן: `right`→`DocxAlign.right`→`right` פיזי, נשאר ימין בשני הכיוונים ✓. **`left` פיזי שבור ב‑RTL:** `left`→`DocxAlign.left`→הרינדר מתייחס כ‑`start` (לוגי) → ב‑RTL מתהפך לימין במקום להישאר שמאל. (מתועד כסטייה מודעת ב‑bidi_align doc + תוכנית §8.2.) | `docx_style.dart:330-333`; `bidi_align.dart:34-35,64-75` |
| 8 | מיפוי `jc`: center / both / distribute | כן | נאמן~ | `center`→`DocxAlign.center`→`TextAlign.center` נאמן; `both`+`distribute` שניהם→`DocxAlign.justify`→`TextAlign.justify`. **קירוב:** `distribute` (פיזור דו‑כיווני כולל פיזור תווים אחרון) מקורב ל‑`both` של Flutter — אין distribution פר‑גליף נפרד; ויזואלית קרוב ברוב המקרים. | `docx_style.dart:330-332`; `bidi_align.dart:42-46` |
| 9 | זיהוי start/end מול left/right | **לא** | **לא** | **שורש הכשל של פריטים 6–7.** `DocxAlign` הוא enum בן 4 ערכים (left/center/right/justify) — הקורא **מוחק את הטוקן** בזמן הפירוק: `start`↔`left` שניהם→`left`, `end`↔`right` שניהם→`right`. בזמן הרינדור `bidi_align` נאלץ "לנחש" סוג (`left`→start לוגי, `right`→right פיזי) ולכן לעולם לא יכול לדעת אם המקור היה לוגי או פיזי. הטבלה המחייבת של §16.4 **אינה ניתנת למימוש** מעל ה‑AST הנוכחי. | enum `docx_style.dart:330-333`; ניחוש `bidi_align.dart:49-75` |
| 10 | בחירת פונט פר‑תו (עברית→cs+szCs/bCs/iCs; לטינית→ascii/hAnsi+sz/b/i) | כן | נאמן | `_classOf` ממיין כל code‑unit לפי טווח יוניקוד: עברית/ערבית/סורית/תאנא/נְקוֹ + טפסי הצגה → `complex` (cs); לטינית/יוונית/קירילית + ספרות ASCII → `latin` (ascii/hAnsi). `resolveRunStyle(script:)` בוחר לכל קטע cs‑slot+szCs+bCs+iCs או ascii‑slot+sz+b+i, עם נפילה ל‑slot הלא‑CS כשה‑CS חסר (תואם מסמכים שמגדירים רק `w:b`/`w:sz`). **הגבלה מודעת:** מזרח‑אסיה מקופל ל‑latin (slot ascii). | מיון `font_resolver.dart:34-61`; סגנון פר‑כתב `span_factory.dart:167-282` |
| 11 | פיצול ריצה לקטעים פר‑כתב | כן | נאמן | `classifyScript` מפצל מחרוזת לריצות מקסימליות חד‑כתב; ניטרליים (רווח/פיסוק) יורשים מהתו החזק הקודם → הבא → ברירת‑מחדל latin, ועם `w:hint="cs"` כל ניטרלי→complex. `resolveRunSegments` מרצף את התוכן **בדיוק** (`Σ length == content.length`) כך ש‑measure≡render, ופסקה חד‑כתב מחזירה קטע יחיד זהה לקדם‑פיצול. | `font_resolver.dart:70-141`; `span_factory.dart:386-421`; חיווט מדידה+רינדור `span_factory.dart:501-513` |
| 12 | `tcMar` > `tblCellMar` | כן | נאמן | `resolveCellMargins` מיישם נפילה **פר‑צד**: `tcM?.left ?? cell.marginLeft ?? tblM?.left ?? defSide` (וכן לכל צד). ברירת Word: 108tw צדדים / 0 עליון‑תחתון; cellPadding ישן (אחיד) דורס. נאמן — Word פותר כל צד עצמאית. | `table_layout.dart:169-190`; שימוש `table_builder.dart:636-647` |
| 13 | `tcBorders` > `insideH/V` > סגנון (+§6.6) | חלקי | חלקי | `_resolveCellBorder`/`_effectiveSource` פותר קדימות **תא > מותנה (row/col) > טבלה** לכל קצה (קצה חיצוני=tblBorders, פנימי=insideH/insideV; אנכי מעדיף עמודה). **חסר:** פתרון קונפליקט בין **תאים שכנים** (§6.6, "הגבול החזק מנצח" + בעלות יחידה) — דורש render‑object מודע‑כיוון; קריטי ל‑RTL, נדחה. בנוסף dashed/dotted נופלים ל‑`BorderStyle.none` (אין מקפים native). | `table_builder.dart:664-723`; נפילת תא→מותנה `table_parser.dart:325-328` |
| 14 | `shd`: תא > שורה (cnfStyle) > טבלה > סגנון | חלקי | חלקי | shd התא מנצח: `c.shadingFill ?? effectiveStyle.shadingFill` (תא > סגנון מותנה). מילוי הטבלה (`tblPr/shd`→`style.fill`) מצויר מאחורי התאים. **חסר:** shd **שורה ישיר** (`trPr/shd`) לא נקרא כלל; דרגת ה"שורה" בקדימות מקורבת רק דרך ה‑cnfStyle של `_resolveCellStyle` (band/firstRow). themeFill של התא יורש מ‑effectiveStyle. | `table_parser.dart:320-323`; מותנה `table_parser.dart:716-778`; מילוי טבלה `table_builder.dart` |

### ב.2 — פערים והוראות ל‑AI הבא

- **§16.4 — קריסת טוקן `jc` בזמן הפירוק (פריטים 6, 7, 9 — קריטי, RTL).** השורש: `DocxAlign` בן 4 ערכים, ו‑`docx_style.dart:330-333` (וגם `table_parser.dart:531-535`) מוחק את ההבחנה לוגי/פיזי — `start`/`left`→`left`, `end`/`right`→`right`. כתוצאה: `jc="end"` בפסקת RTL מיושר ימין במקום שמאל, ו‑`jc="left"` פיזי בפסקת RTL מתהפך לימין. **המלצה:** להוסיף ל‑AST ערך יישור שמשמר את הטוקן המקורי (להרחיב `DocxAlign` ל‑6 ערכים: start/end/left/right/center/both, או לשאת `WordJustification` שכבר קיים ב‑`bidi_align.dart:13`). אז `resolveParagraphTextAlign` יקבל את הטוקן האמיתי במקום לנחש דרך `justificationFromDocxAlign`. זה הפער הבולט ביותר ב‑§16 ומשפיע ישירות על מסמכי קודש עבריים.
- **שכבות סגנון‑טבלה וסגנון‑מספור חסרות מהמנוע (פריטים 1, 2).** `resolveRun`/`resolveParagraph` מכסים rPrDefault/pPrDefault → pStyle(basedOn) → rStyle → ישיר, אך **לא** את שכבת **סגנון הטבלה** (§6.5, כולל מותנה) ולא את שכבת **סגנון המספור** (`lvl/pPr` + `lvl/rPr` לתווית). תוצאה: פסקה/ריצה בתוך תא לא יורשת עיצוב מ‑tblStylePr דרך אותו מנוע (מטופל חלקית רק לתא ב‑`_resolveCellStyle`), והזחת/עיצוב המספור מוחלים בנתיב ad‑hoc. **המלצה:** להזריק את ה‑levels של סגנון הטבלה ושל רמת המספור כשכבות נמוכות יותר ברשימת `levels` ב‑`_mergeStyleLayers` (לפי הסדר ב‑§16.1/§16.2), כך שכל ה‑resolution יעבור בנקודה אחת. ראו משימות 06/08.
- **מנוע הפסקה `resolveParagraph` לא מחווט (פריט 1).** קיים ב‑`style_engine.dart:164-176` אך פסקאות עוברות במסלול הישן `resolveStyle`+merge ב‑`block_parser.dart:190-200` (וכך גם תאי טבלה ב‑`table_parser.dart:553`). המסלול הישן אינו מיישם toggle‑XOR ברמת הפסקה ואינו זהה לאופן שבו `resolveRun` מיישם pPrDefault. **המלצה:** לחווט את `resolveParagraph` (במקביל ל‑`resolveRun` ב‑inline_parser) ולוודא golden — זהה ל‑`TODO(golden)` במשימה 07 פריט 23.
- **כיסוי toggle‑XOR חלקי (פריט 4).** ה‑XOR מכסה 9 toggles ורק **בין רמות** (pStyle↔rStyle), לא בתוך שרשרת basedOn (החלטה שמרנית מתועדת). חסרים `bCs`/`iCs` (נקראים ישיר בלבד — לא יורשים מסגנון ולא XOR), `strike` חד (דרך `decorations` הלא‑אדיטיבי), ו‑`vanish`. **המלצה:** אם golden יראה שצריך — להוסיף את bCs/iCs/strike/vanish ל‑`_toggleOverride` ולהעביר אותם דרך המנוע במקום ישיר בלבד.
- **אינטראקציית toggle ישיר (פריט 5, golden‑blocked).** הקוד מעדיף **דריסה** של עיצוב ישיר על תוצאת הסגנון; ISO §17.7.3 מדגים **XOR** גם ברמה הישירה. `val="0"` מפורש מטופל נכון בשתי הפרשנויות, אז ההשפעה המעשית קטנה, אבל `<w:b/>` ישיר על טקסט מודגש‑מסגנון עדיין פתוח. **המלצה:** לנעול מול Word אמיתי (`style_engine.dart:153-159`); אם XOR מאומת — להחליף את ה‑`merge(direct)` ב‑XOR של ה‑toggles מול תוצאת הסגנון.
- **קונפליקט גבולות בין תאים שכנים (§6.6, פריט 13).** הקדימות תא>מותנה>טבלה מיושמת, אך פתרון "הגבול החזק מנצח" + בעלות יחידה בין שכנים לא ממומש — קריטי ל‑RTL, נדחה (`table_builder.dart:661-663`). ראו משימה 06.
- **shd שורה ישיר לא נקרא (פריט 14).** `trPr/w:shd` (הצללת שורה ישירה) מושמט; דרגת "שורה" בקדימות §16.6 מקורבת רק דרך cnfStyle. לתעד מול משימה 06; להוסיף קריאת `trPr/shd` ולמקם אותה בין מילוי הטבלה למילוי התא.
- **קוד מת — `StyleResolver`/`ResolvedStyle` הישן.** `resolved_style.dart` מגדיר resolver חלופי שאינו בשימוש ייצור (רק טסטים), במקביל ל‑`DocxStyleResolver` ול‑`ReaderContext.resolveStyle`. שלושה נתיבי resolution מקבילים = סיכון לסחף. כשהמנוע יתבסס — למחוק את הישן (כפי שצוין במשימה 07).

### ב.3 — עדכון מימוש (בוצע ע"י ה‑AI המבצע, 2026‑06‑23)

> מבוצע לפי `PROMPTER.md`. פער §16.4 (קריסת טוקן `jc`) הוא ריפקטור ליבה עם השלכות golden ונשאר נדחה;
> במקום זאת **ההשפעה המעשית** שלו תוקנה היכן שהיא נראית למשתמש:

**שופר (דרך משימות אחרות):**

- **`jc` תלוי‑כיוון לפסקה (§16.4):** `bidi`/`jc` יורשים מסגנון ומיושבים פיזית לפי כיוון הפסקה — משימה 04 (`paragraph_ppr_04_test.dart`, `paragraph_indent_rtl_test.dart`).
- **`jc` של טבלה — `start`/`end` תלויי‑כיוון:** משימה 06 (`table_properties_test.dart`).
- **קדימות מקור לגבול תא (תא>מותנה>טבלה):** קיימת; גבולות `dashed`/`dotted` שוב נראים (משימה 06).

**נותר נדחה:** קריסת טוקן `DocxAlign` (4 ערכים), `resolveParagraph` engine לא מחווט, toggle‑XOR ללא bCs/iCs/strike/vanish, קונפליקט גבולות בין שכנים, `trPr/shd` שורה — ריפקטורים גדולים עם השלכות golden (§8.2).
