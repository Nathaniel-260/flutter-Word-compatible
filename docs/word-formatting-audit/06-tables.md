# משימה 06 — טבלאות — `w:tblPr` / `w:trPr` / `w:tcPr`

> **מקור:** סעיף §6 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **סטטוס מימוש:** 🔄 פערים נבחרים מומשו (ראו ב.3); פתרון קונפליקט גבולות נותר נדחה (§8.2) &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-23

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

מבנה: `w:tbl` → `w:tblPr` (מאפייני טבלה) + `w:tblGrid` (הגדרת עמודות) + שורות `w:tr` (כל אחת `w:trPr` + תאים `w:tc`, וכל תא `w:tcPr` + בלוקים).

```xml
<w:tbl>
  <w:tblPr>…</w:tblPr>
  <w:tblGrid><w:gridCol w:w="4675"/><w:gridCol w:w="4675"/></w:tblGrid>
  <w:tr>
    <w:trPr>…</w:trPr>
    <w:tc><w:tcPr>…</w:tcPr><w:p>…</w:p></w:tc>
    <w:tc>…</w:tc>
  </w:tr>
</w:tbl>
```

### 6.1 `w:tblGrid` — שלד העמודות

| אלמנט | מה עושה | קצה |
|---|---|---|
| `w:gridCol` | `w:w` (twips) — רוחב עמודה לוגית | מספר ה‑gridCol = מספר העמודות הלוגיות. תא יכול לפרוס כמה (gridSpan). הרוחבים האלה הם "preferred" — autofit יכול לשנותם. |

### 6.2 `w:tblPr` — מאפייני טבלה

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:tblStyle` | `<w:tblStyle w:val="TableGrid"/>` | מחיל סגנון טבלה | בסיס לעיצוב מותנה (§6.5) |
| `w:tblpPr` | `leftFromText`,`rightFromText`,`topFromText`,`bottomFromText`,`horzAnchor`(text/margin/page),`vertAnchor`,`tblpX`/`tblpXSpec`(left/center/right/...),`tblpY`/`tblpYSpec` | **טבלה צפה** — מיקום מוחלט + עטיפת טקסט | |
| `w:tblOverlap` | never / overlap | האם טבלה צפה יכולה לחפוף לאחרת | |
| `w:bidiVisual` | toggle | **טבלת RTL** — היפוך ויזואלי של סדר העמודות | קריטי לעברית |
| `w:tblStyleRowBandSize` | int | כמה שורות בכל "פס" (banding) | לסגנון band1/band2 |
| `w:tblStyleColBandSize` | int | כמה עמודות בכל פס | |
| `w:tblW` | `<w:tblW w:w="5000" w:type="pct"/>` | רוחב מועדף של הטבלה | `type`: auto/dxa(twips)/pct/nil. pct ב‑1/50% (5000=100%) |
| `w:jc` | start/end/left/right/center | יישור הטבלה בעמוד | תלוי‑כיוון |
| `w:tblCellSpacing` | `w`+`type` | ריווח בין תאים (טבלה "מרווחת") | |
| `w:tblInd` | `w`+`type` | הזחת הטבלה מהשול המתחיל | |
| `w:tblBorders` | top/left/bottom/right/insideH/insideV (כ‑`CT_Border`) | גבולות ברירת מחדל לטבלה | `insideH`/`insideV`=הקווים הפנימיים |
| `w:shd` | §2.3 | הצללת רקע לכל הטבלה | |
| `w:tblLayout` | `<w:tblLayout w:type="fixed"/>` | `fixed`=רוחבים קבועים מ‑gridCol; `autofit`=התאמה לתוכן | קובע אלגוריתם הרוחב |
| `w:tblCellMar` | top/left/bottom/right (כל אחד `w`+`type`) | שולי תא ברירת מחדל | תא יכול לדרוס ב‑tcMar |
| `w:tblLook` | bitmask/תכונות | אילו חלקי הסגנון המותנה פעילים | §6.5 |
| `w:tblCaption`,`w:tblDescription` | מחרוזת | נגישות (alt text) — לא ויזואלי | |

### 6.3 `w:trPr` — מאפייני שורה

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:trHeight` | `<w:trHeight w:val="567" w:hRule="atLeast"/>` | גובה שורה | `hRule`: auto (לפי תוכן), exact (קבוע, חותך), atLeast (מינימום) |
| `w:cantSplit` | toggle | אל תשבור את השורה בין עמודים | |
| `w:tblHeader` | toggle | **שורת כותרת שחוזרת** בראש כל עמוד | קריטי לעימוד טבלאות ארוכות |
| `w:gridBefore`/`w:gridAfter` | int | תאי‑רשת ריקים לפני/אחרי השורה | יוצר שורה "מוזחת" |
| `w:wBefore`/`w:wAfter` | `w`+`type` | רוחב האזור הריק לפני/אחרי | |
| `w:jc` | יישור השורה (כשהיא צרה מהטבלה) | | |
| `w:tblCellSpacing` | ריווח תאים פר‑שורה | | |
| `w:hidden` | toggle | שורה מוסתרת | |
| `w:cnfStyle` | bitmask | עיצוב מותנה פר‑שורה (§6.5) | |
| `w:ins`/`w:del` | מעקב‑שינויים: שורה שנוספה/נמחקה | | §12 |

### 6.4 `w:tcPr` — מאפייני תא

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:tcW` | `<w:tcW w:w="4675" w:type="dxa"/>` | רוחב מועדף של התא | type כמו tblW |
| `w:gridSpan` | `<w:gridSpan w:val="2"/>` | התא פורס N עמודות לוגיות (מיזוג אופקי) | |
| `w:hMerge` | `restart`/`continue` | מיזוג אופקי בסגנון ישן | חלופה ל‑gridSpan |
| `w:vMerge` | `<w:vMerge w:val="restart"/>` / `<w:vMerge/>` | **מיזוג אנכי**: `restart`=תא ראשון; ללא val (=continue)=המשך המיזוג | התא ה‑continue מצויר ריק, התוכן בא מה‑restart |
| `w:tcBorders` | top/left/bottom/right/insideH/insideV/**tl2br**/**tr2bl** | גבולות התא + אלכסונים | tl2br/tr2bl=קווים אלכסוניים בתא |
| `w:shd` | §2.3 | הצללת התא | גובר על הצללת שורה/טבלה |
| `w:noWrap` | toggle | אל תשבור שורות בתא (התא יתרחב) | |
| `w:tcMar` | top/left/bottom/right | שולי התא (דורס tblCellMar) | |
| `w:textDirection` | lrTb/tbRl/btLr… | כיוון טקסט בתא (טקסט אנכי בכותרות) | |
| `w:tcFitText` | toggle | מתח טקסט למילוי רוחב התא | |
| `w:vAlign` | top / center / bottom | יישור אנכי של התוכן בתא | |
| `w:hideMark` | toggle | התעלם מסימן סוף‑התא בחישוב גובה השורה | |
| `w:cnfStyle` | bitmask | עיצוב מותנה פר‑תא | §6.5 |
| `w:cellIns`/`w:cellDel`/`w:cellMerge` | | מעקב‑שינויים על התא | §12 |

### 6.5 סגנונות טבלה מותנים — `tblStylePr` + `cnfStyle` + `tblLook`

סגנון טבלה (ב‑styles.xml, `type="table"`) יכול להגדיר עיצוב שונה ל**אזורים** שונים דרך `w:tblStylePr w:type="…"`:

| ערך `type` | האזור |
|---|---|
| `wholeTable` | כל הטבלה (בסיס) |
| `firstRow` / `lastRow` | שורת כותרת עליונה / תחתונה |
| `firstCol` / `lastCol` | עמודה ראשונה / אחרונה |
| `band1Horz` / `band2Horz` | פסים אופקיים מתחלפים (שורות) |
| `band1Vert` / `band2Vert` | פסים אנכיים מתחלפים (עמודות) |
| `nwCell` / `neCell` / `swCell` / `seCell` | ארבע פינות הטבלה |

**`w:tblLook`** קובע אילו מהאזורים האלה **פעילים** עבור טבלה ספציפית:

```xml
<w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0"
           w:firstColumn="1" w:lastColumn="0"
           w:noHBand="0" w:noVBand="1"/>
```

| תכונה | מה מפעיל |
|---|---|
| `w:firstRow` | החל את firstRow |
| `w:lastRow` | החל את lastRow |
| `w:firstColumn` | החל את firstCol |
| `w:lastColumn` | החל את lastCol |
| `w:noHBand` | בטל פסים אופקיים (band1Horz/band2Horz) |
| `w:noVBand` | בטל פסים אנכיים |
| `w:val` | אותו מידע כ‑bitmask hex (גרסה ישנה) |

**`w:cnfStyle`** (על שורה/תא/פסקה) מציין במפורש לאיזה אזור התא שייך (12 ביטים: firstRow, lastRow, firstColumn, lastColumn, firstRowFirstColumn, ...). מנוע 1:1 משתמש בו כדי להחיל את ה‑tblStylePr הנכון.

### 6.6 פתרון קונפליקט גבולות (כלל Word — קריטי)

כששני תאים שכנים מגדירים גבול שונה לאותו קו, Word בוחר גבול **אחד** מנצח (לא מסכם). סדר הקדימה (מהגבוה לנמוך):

1. עובי גדול יותר (`sz`) מנצח.
2. בעובי שווה — לפי **קדימות סגנון הקו**: double > single > dashed > dotted > … (סדר ST_Border).
3. בשוויון מלא — צבע כהה יותר, ואז לפי מיקום (top/left מנצח).
4. גבול `nil` מאבד תמיד מול גבול קיים; אבל גבול `none` מפורש יכול לבטל גבול‑סגנון.

> בנוסף יש קדימות **מקור**: גבול שמוגדר על התא (`tcBorders`) גובר על `insideH/V` של הטבלה, שגובר על גבול מהסגנון. מנוע 1:1 חייב לחשב לכל קו את המנצח פעם אחת, אחרת מקבלים קווים כפולים/שגויים (בעיה נפוצה בטבלאות RTL).

### 6.7 autofit מול fixed

- `tblLayout="fixed"`: רוחבי העמודות = `gridCol` (מותאם ל‑`tcW`); תוכן נשבר/נחתך לרוחב.
- `tblLayout="autofit"` (ברירת מחדל אם חסר): Word מחשב רוחבים מהתוכן ומ‑`tblW`, עם איזון. אלגוריתם מורכב — מנוע 1:1 צריך מדידת תוכן אמיתית פר‑עמודה ואז חלוקה מידתית בכפוף ל‑`tblW`/רוחב הזמין.

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

> **היכן ממומש — שני נתיבים בשני חבילות.** הקריאה: `TableParser.parse`
> (`docx_creator/.../parsers/table_parser.dart`) בונה את ה‑AST `DocxTable`/`DocxTableRow`/`DocxTableCell`
> (`docx_creator/.../ast/docx_table.dart`); סגנונות מותנים (`tblStylePr`) נקראים ב‑`style_parser.dart:118-144`.
> הרינדור: `TableBuilder` (`docx_file_viewer/.../widget_generator/table_builder.dart`) בונה את הווידג'טים;
> חישוב רוחבי העמודות ושולי התא ב‑`table_layout.dart` (משותף לרינדור ולמדידה), ורצפת רוחב‑תוכן
> (longest‑word) ב‑`table_min_widths.dart`. עימוד/שבירה בין עמודים + חזרת כותרת ב‑`paginator.dart`
> (`_splitTable:1169`, `_measureRow:1346`). טבלה צפה ב‑`docx_widget_generator.dart:1164-1224`.
> **עיקרון מנחה:** *measurement ≡ rendering* — אותו `resolveTableColumnWidths` משמש גם את ה‑paginator
> (למדידת גובה לצורך פיצול) וגם את הצייר, כך שהרוחבים שנמדדו = הרוחבים שצוירו.

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:tblGrid` / `w:gridCol` (רוחב עמודה לוגית) | כן | נאמן~ | רוחבי עמודות לוגיות ב‑twips; ב‑autofit הם "preferred" ש‑Word ממדל מחדש לפי תוכן. כאן: נקראים ל‑`gridColumns`, ו‑`resolvedGridColumns` ממיר ל‑px (÷15). חוסר gridGrid → נגזר מתאי השורה הראשונה (9022tw מחולק שווה אם אין רוחבי תא). | קריאה `table_parser.dart:189-198`; המרה `docx_table.dart:287-310`; layout `table_layout.dart:55-73` |
| 2 | `w:tblStyle` | כן | חלקי | מחיל סגנון טבלה מ‑styles.xml. גבולות הסגנון יורשים כשאין `tblBorders` ישיר; אזורים מותנים (`tblStylePr`) נקראים. **אך** רק תת‑קבוצה ממאפייני הסגנון מיושמת (גבולות, fill, bold, color) — לא כל ה‑pPr/rPr של הסגנון. | קריאה `table_parser.dart:66-69`; ירושת גבולות `table_parser.dart:275-290`; render `table_builder.dart:192-227` |
| 3 | `w:tblpPr` (טבלה צפה — anchor/Spec/FromText) | חלקי | לא | Word: מיקום מוחלט (horzAnchor/vertAnchor + tblpX/Y) + עטיפת טקסט סביב הטבלה. כאן נקרא ל‑`DocxTablePosition` (עוגנים, X/Y, *FromText) אך **הרינדור הוא Row גס** (טבלה בצד + עד 5 פסקאות עוקבות ב‑Expanded/Flexible) — לא מיקום מוחלט ולא עטיפה אמיתית. `tblpXSpec`/`tblpYSpec` לא נקראים. | קריאה `table_parser.dart:81-110`; render `docx_widget_generator.dart:1164-1224` |
| 4 | `w:tblOverlap` (never/overlap) | חלקי (נקרא) | לא | האם טבלה צפה מותרת לחפוף לאחרת. נקרא ל‑`tblOverlap` (מחרוזת) אך **לא מנוצל** בשום שלב פריסה. | קריאה `table_parser.dart:113-116`; אין render |
| 5 | `w:bidiVisual` (טבלת RTL — קריטי) | כן | נאמן~ | היפוך ויזואלי של סדר העמודות (התא הלוגי הראשון מימין). מיושם ע"י `Row(textDirection: rtl)` — בלי לגעת ברוחבים/מיזוגים. **מגבלה:** גבולות שמאל/ימין פיזיים (לא תלויי‑כיוון), ולכן פתרון קונפליקט גבולות ב‑RTL נדחה (פריט 45). | קריאה `table_parser.dart:119`; render `table_builder.dart:434` |
| 6 | `w:tblStyleRowBandSize` | **לא** | לא | כמה שורות בכל "פס" banding. **לא נקרא** — ה‑banding מקודד לסירוגין כל שורה (`row % 2`), ללא קשר לגודל הפס. | חסר (`table_parser.dart`); banding `table_builder.dart:232,240-247` |
| 7 | `w:tblStyleColBandSize` | **לא** | לא | כמה עמודות בכל פס. **לא נקרא** — פסי עמודות מחושבים `col % 2` ב‑`_resolveCellStyle` (צד הקורא), גודל הפס מתעלם. | חסר; `table_parser.dart:730-738` |
| 8 | `w:tblW` (w + type: auto/dxa/pct/nil) | כן | נאמן~ | `dxa`=רוחב מוחלט (twips→px), `pct`=אחוז מהרוחב הזמין (5000=100%, ÷5000), `auto`=סכום ה‑gridCol. **`nil` לא מטופל** (נופל ל‑auto). | קריאה `table_parser.dart:55-63`; layout `table_layout.dart:84-98,108-109` |
| 9 | `w:jc` (טבלה — תלוי‑כיוון) | חלקי | חלקי | יישור הטבלה בעמוד. `left`/`center`/`right` נקראים ומיושמים (`Center`/`Align`). **`start`/`end` לא ממופים** → במקטע RTL היישור תלוי‑הכיוון שגוי (start צריך להיות ימין). | קריאה `table_parser.dart:72-78`; render `table_builder.dart:68-72,112-116` |
| 10 | `w:tblCellSpacing` (טבלה) | חלקי (נקרא) | לא | ריווח בין תאים ("טבלה מרווחת"). נקרא ל‑`cellSpacingTwips` אך **לא מרונדר** — אין מרווח בין התאים. | קריאה `table_parser.dart:138-141`; אין render |
| 11 | `w:tblInd` (הזחת טבלה) | חלקי | לא | הזחת הטבלה מהשול המתחיל. נקרא ל‑`indentTwips`, ובחישוב הרוחב **מקטין את הרוחב הזמין** (`usable -= indentPx`) — אך הטבלה **אינה מוסטת בפועל** פנימה (אין offset מוביל), רק נעשית צרה יותר. | קריאה `table_parser.dart:129-132`; layout `table_layout.dart:64-71` |
| 12 | `w:tblBorders` (top/left/bottom/right/insideH/insideV) | כן | חלקי | 6 הצדדים נקראים (val/sz/space/color/theme). מיפוי לכל קצה: חיצוני=top/left/bottom/right, פנימי=insideH/insideV. **חולשות:** `dashed`/`dotted` → קו בלתי‑נראה (ראו 46), `double`/`triple` → single, ואין פתרון קונפליקט שכנים (ראו 45-47). | קריאה `table_parser.dart:34-44`; render `_resolveCellBorder table_builder.dart:664-708`, `_convertSide:727-752` |
| 13 | `w:shd` (הצללת טבלה) | חלקי | חלקי | רק `w:fill` נקרא ומצויר (`DecoratedBox` ברקע הטבלה). **`w:val` (pattern: clear/solid/pct10…) מתעלם** — תבניות הצללה לא נתמכות. | קריאה `table_parser.dart:47-53`; render `table_builder.dart:166-172` |
| 14 | `w:tblLayout` (fixed/autofit) | כן | חלקי | `fixed`=רוחבי gridCol כלשונם (עלול לחרוג); `autofit`=שינוי‑גודל הגריד לרוחב הזמין + רצפת רוחב‑תוכן. נאמן ל‑fixed; autofit מקורב (ראו 51). | קריאה `table_parser.dart:122-126`; layout `table_layout.dart:100-118` |
| 15 | `w:tblCellMar` (שולי תא ברירת מחדל) | כן | נאמן | top/left/bottom/right נקראים (`nil`→0); מיושמים כ‑padding דרך `resolveCellMargins` עם ברירת‑מחדל Word (108tw צד / 0 אנכי). תא יכול לדרוס ב‑tcMar (פריט 35). | קריאה `table_parser.dart:135,575-591`; layout `table_layout.dart:169-190` |
| 16 | `w:tblLook` | כן | נאמן~ | נקרא בשתי הצורות: תכונות מפורשות (firstRow/lastRow/firstColumn/lastColumn/noHBand/noVBand) **וגם** fallback ל‑`w:val` hex. מגייט אילו אזורים מותנים פעילים. | קריאה `table_parser.dart:147-182`; render `table_builder.dart:230-247` |
| 17 | `w:tblCaption` / `w:tblDescription` | **לא** | n/a | נגישות (alt‑text) — לא ויזואלי. לא נקרא. אין השפעה על התצוגה. | אין |
| 18 | `w:trHeight` (val + hRule: auto/exact/atLeast) | כן | נאמן | `val`+`hRule` נקראים. `exact`=גובה קבוע + חיתוך (`OverflowBox`+`ClipRect`); `atLeast`=רצפה (`ConstrainedBox minHeight`); `auto`=הערך מתעלם (גדל לפי תוכן). מדידה זהה לרינדור. | קריאה `table_parser.dart:227-232`; render `table_builder.dart:440-469`; measure `paginator.dart:1369-1375` |
| 19 | `w:cantSplit` | כן | נאמן~ | נקרא; **מכובד מרומז** — הפיצול קורה רק *בין* שורות, אף פעם לא בתוך שורה. מגבלה: שורה בודדת גבוהה מעמוד מוצמדת (overflow) בעמוד חדש במקום להישבר. | קריאה `table_parser.dart:233`; `paginator.dart:1167-1168,1201-1210` |
| 20 | `w:tblHeader` (שורת כותרת חוזרת — קריטי) | כן | נאמן | שורות כותרת מובילות חוזרות בראש כל המשך כשהטבלה נשברת בין עמודים. `_splitTable` סופר את שורות ה‑header ומשרשר אותן ל‑head ול‑tail. | קריאה `table_parser.dart:219`; `paginator.dart:1174-1187,1213-1214` |
| 21 | `w:gridBefore` / `w:gridAfter` | חלקי | חלקי~ | `gridBefore`: מרווח מוביל ברוחב עמודות הגריד (`SizedBox`); `gridAfter`: העמודות הנותרות אחרי התאים האמיתיים מתמלאות ב‑`SizedBox` ריק ברוחב‑גריד. שניהם משתמשים ברוחב ה‑gridCol — לא ב‑wBefore/wAfter (פריט 22). | קריאה `table_parser.dart:234-241`; render `table_builder.dart:281-289,420-424` |
| 22 | `w:wBefore` / `w:wAfter` | חלקי (נקרא) | לא | רוחב מפורש של האזור הריק לפני/אחרי. **נקראים אך לא מנוצלים** — הרינדור משתמש ברוחבי gridCol של העמודות המדולגות (פריט 21), לא ב‑wBefore/wAfter. | קריאה `table_parser.dart:242-245`; אין שימוש |
| 23 | `w:jc` (שורה) | **לא** | לא | יישור השורה כשהיא צרה מהטבלה. **לא נקרא** (ל‑`_TempRow` אין שדה jc). | חסר `table_parser.dart:217-246` |
| 24 | `w:tblCellSpacing` (שורה) | **לא** | לא | ריווח תאים פר‑שורה. לא נקרא ולא מרונדר (אף לא ברמת הטבלה — פריט 10). | חסר |
| 25 | `w:hidden` (שורה מוסתרת) | **לא** | לא | שורה מוסתרת. **לא נקרא** → השורה תמיד מוצגת. | חסר |
| 26 | `w:cnfStyle` (שורה) | חלקי (נקרא) | לא | נקרא ל‑`row.cnfStyle`, אך בחירת האזור המותנה נעשית **לפי מיקום** (`rowIndex`+`look`) ולא לפי ביטי ה‑cnfStyle (ראו 44). | קריאה `table_parser.dart:222-225`; שימוש מיקומי `table_builder.dart:230-247` |
| 27 | `w:ins` / `w:del` (revision שורה) | **לא** | לא | מעקב‑שינויים על שורה. שורות עטופות ב‑`w:ins`/`w:del` **לא מזוהות** (הלולאה מתאימה רק ל‑`w:tr` ישיר). ראו משימה 12. | חסר `table_parser.dart:203-204` |
| 28 | `w:tcW` (רוחב תא + type) | כן | נאמן~ | נקרא ל‑`cellWidth`. **הגריד שולט ברוחבים**; `tcW` משמש fallback רק כש‑gridCol חסר (`resolvedGridColumns` נגזר מרוחבי התא). `type` מעבר ל‑dxa לא מובחן. | קריאה `table_parser.dart:438-441`; `docx_table.dart:298-302` |
| 29 | `w:gridSpan` (מיזוג אופקי) | כן | נאמן | התא פורס N עמודות; הרוחב = סכום רוחבי העמודות הנפרסות. מדידה ורינדור עקביים (שניהם מסכמים את אותן עמודות). | קריאה `table_parser.dart:401-404`; render `table_builder.dart:349-357`; measure `paginator.dart:1352` |
| 30 | `w:hMerge` (restart/continue) | **לא** | לא | מיזוג אופקי בסגנון ישן. **לא נקרא** (רק `gridSpan` נתמך). מסמכים ישנים שמשתמשים ב‑hMerge יציגו תאים נפרדים במקום ממוזגים. | חסר `table_parser.dart:400-462` |
| 31 | `w:vMerge` (מיזוג אנכי — restart/continue) | כן | נאמן~ | `restart`/`continue` נפתרים ל‑`rowSpan` ב‑`_resolveRowSpans`; ה‑continue מצויר כ‑placeholder ריק שיורש את ה‑fill של ה‑restart, וקווי הגבול הפנימיים של המיזוג מדוכאים. | קריאה `table_parser.dart:406-409,651-714`; render `table_builder.dart:295-343,359-376` |
| 32 | `w:tcBorders` (כולל אלכסונים tl2br/tr2bl) | חלקי | חלקי | top/left/bottom/right נקראים ומצוירים. **האלכסונים `tl2br`/`tr2bl` לא נקראים ולא מצוירים** — תא עם קו אלכסוני (נפוץ ב"לא רלוונטי") יוצג ללא האלכסון. | קריאה `table_parser.dart:443-449`; render `table_builder.dart:664-708` |
| 33 | `w:shd` (תא — גובר על שורה/טבלה) | כן | חלקי | `fill`+`themeFill`/`Tint`/`Shade` נקראים; גוברים על רקע שורה/טבלה ומצוירים כרקע התא. **`w:val` (pattern) מתעלם** — כמו בהצללת טבלה (13). | קריאה `table_parser.dart:411-427`; render `table_builder.dart:491-497` |
| 34 | `w:noWrap` (תא) | חלקי (נקרא) | לא | "אל תשבור שורות — התא יתרחב". נקרא ל‑`noWrap` אך **לא מיושם** — התא נשבר רגיל, אינו מתרחב לתוכן. | קריאה `table_parser.dart:459`; אין render |
| 35 | `w:tcMar` (שולי תא — דורס tblCellMar) | כן | נאמן | שולי תא פר‑תא; דורסים את `tblCellMar` (`resolveCellMargins`: tcMar > tblCellMar > ברירת‑מחדל Word) ומיושמים כ‑padding. | קריאה `table_parser.dart:456`; layout `table_layout.dart:179-182`; render `table_builder.dart:638-647` |
| 36 | `w:textDirection` (תא — טקסט אנכי) | חלקי | חלקי | `tbRl`/`tbRlV`→90°CW, `btLr`/`tbLrV`→270°CW דרך `RotatedBox`; `lrTb`=ברירת‑מחדל. **קירוב** — סיבוב הוא לא בדיוק טקסט אנכי של Word (כיוון גליפים/ערימת שורות שונה), אך קרוב ויזואלית. | קריאה `table_parser.dart:457`; render `table_builder.dart:620-633` |
| 37 | `w:tcFitText` | חלקי (נקרא) | לא | מתיחת טקסט למילוי רוחב התא. נקרא ל‑`tcFitText` אך **לא מיושם** — הטקסט לא נמתח. | קריאה `table_parser.dart:460`; אין render |
| 38 | `w:vAlign` (תא — top/center/bottom) | כן | נאמן | יישור אנכי של תוכן התא: `top`/`center`/`bottom` דרך `mainAxisAlignment` של ה‑Column + עטיפת `Center`/`Align`. | קריאה `table_parser.dart:430-436`; render `table_builder.dart:525-548` |
| 39 | `w:hideMark` | חלקי (נקרא) | לא | התעלם מסימן סוף‑תא בחישוב גובה. נקרא ל‑`hideMark` אך **לא מיושם** (סימן סוף‑התא ממילא לא ממודל בחישוב הגובה). השפעה זניחה. | קריאה `table_parser.dart:461`; אין render |
| 40 | `w:cnfStyle` (תא) | חלקי (נקרא) | לא | נקרא ל‑`cell.cnfStyle`; כמו ברמת השורה (26), בחירת האזור היא מיקומית ולא לפי ביטי ה‑cnfStyle (ראו 44). | קריאה `table_parser.dart:451-454` |
| 41 | `w:cellIns` / `w:cellDel` / `w:cellMerge` (revision תא) | **לא** | לא | מעקב‑שינויים ברמת התא. לא נקראים. ראו משימה 12. | חסר |
| 42 | `tblStylePr` — אזורים (wholeTable/firstRow/lastRow/firstCol/lastCol/band1-2Horz/Vert/4 פינות) | חלקי | חלקי | **כל** סוגי האזורים נקראים מ‑styles.xml ל‑`tableConditionals`. מיושמים: בצד הקורא ל‑גבולות/fill/vAlign (`_resolveCellStyle`), ובצייר ל‑רקע/bold/color. **אך** רק תת‑קבוצת מאפיינים פר‑אזור, ופינות (nw/ne/sw/se) ממוזגות בסיסי. | קריאה `style_parser.dart:118-144`; reader `table_parser.dart:716-778`; render `table_builder.dart:235-247,557-591` |
| 43 | `tblLook` מפעיל אזורים (firstRow/lastRow/firstColumn/lastColumn/noHBand/noVBand/val) | כן | נאמן~ | מגייט אילו אזורים פעילים (ראו 16). הצייר בודק `look.firstRow`/`look.noHBand` וכו' לפני החלת האזור. | קריאה `table_parser.dart:147-182`; render `table_builder.dart:230-247` |
| 44 | `cnfStyle` (12 ביטים) → החלת tblStylePr הנכון | **לא** | לא | `cnfStyle` נקרא (26,40) אך האזור מוחל **לפי מיקום** (`rowIndex`/`colIndex`+look), לא לפי הביטים. כשה‑cnfStyle המפורש סותר את המיקום (תא שכותרתו מוגדרת ידנית) → האזור הלא‑נכון. | reader `_resolveCellStyle table_parser.dart:716-778`; render `table_builder.dart:230-247` |
| 45 | פתרון קונפליקט גבולות — sz מנצח | **לא** | לא | "עובי גדול מנצח" בין תאים שכנים **לא ממומש** — הקונפליקט פתור רק לפי קדימות מקור (תא>מותנה>טבלה), לא לפי השכן. נדחה במפורש (§8.2 #22) — דורש grid render‑object תלוי‑כיוון. | הערה `table_builder.dart:660-663` |
| 46 | פתרון קונפליקט — קדימות סגנון קו (double>single>dashed>dotted) | **לא** | לא | קדימות סגנון‑קו **לא ממומשת**. גרוע מכך: `dashed`/`dotted` מצוירים כ‑`BorderStyle.none` (בלתי‑נראים!), ו‑`double`/`triple` מצוירים כ‑single אחיד. | render `_convertSide table_builder.dart:748-750` |
| 47 | פתרון קונפליקט — צבע כהה / מיקום (top/left) | **לא** | לא | שובר‑שוויון לפי צבע/מיקום **לא ממומש** (תלוי בפריט 45). | חסר |
| 48 | פתרון קונפליקט — nil מאבד / none מבטל גבול‑סגנון | חלקי | חלקי | `none`/`nil` → `DocxBorderSide.none()` → `BorderSide.none` (אין קו). **אך** הלוגיקה "nil מאבד מול גבול קיים של השכן" / "none מפורש מבטל גבול‑סגנון" — חסרה (אין השוואת שכנים). | קריאה `table_parser.dart:596`; render `_convertSide:728` |
| 49 | קדימות מקור: tcBorders > insideH/V > סגנון | כן | נאמן~ | קדימות מקור ממומשת: תא > מותנה (row/col) > טבלה ב‑`_effectiveSource`/`_resolveCellBorder`; גבולות הסגנון יורשים כשאין `tblBorders` ישיר. (חסר רק שלב השכן — 45.) | render `table_builder.dart:664-723`; ירושה `table_parser.dart:275-290` |
| 50 | `tblLayout="fixed"` — רוחבים מ‑gridCol, חיתוך תוכן | כן | נאמן~ | רוחבי gridCol כלשונם; טבלה רחבה מהעמוד **מוקטנת פרופורציונלית** (`FittedBox scaleDown`) במקום חיתוך — קירוב ל‑Word (שלא מקטין fixed). | layout `table_layout.dart:100-105`; render `table_builder.dart:96-101` |
| 51 | `tblLayout="autofit"` — מדידת תוכן + חלוקה מידתית בכפוף ל‑tblW | חלקי | חלקי | מקורב: שינוי‑גודל הגריד השמור לרוחב הזמין + רצפת רוחב‑תוכן (longest‑word פר‑עמודה, `table_min_widths`). **לא** אלגוריתם ה‑min/max content‑width המלא של Word (איזון אמיתי בין עמודות לפי תוכן). | layout `table_layout.dart:107-153`; floor `table_min_widths.dart:21-55` |

### ב.2 — פערים והוראות ל‑AI הבא

- **פתרון קונפליקט גבולות בין שכנים — לא ממומש (פריטים 45–47, קריטי ל‑RTL).** הקוד פותר כל קצה לפי קדימות מקור (תא>מותנה>טבלה) אך לא לפי השכן: "sz גדול מנצח", קדימות סגנון‑קו, ושובר‑שוויון צבע/מיקום — כולם חסרים. בטבלאות RTL זה מייצר קווים כפולים/שגויים. **המלצה:** grid render‑object תלוי‑כיוון שמחשב לכל קו (לא לכל תא) מנצח יחיד; ראו ההערה ב‑`table_builder.dart:660-663` (§8.2 #22).
- **סגנונות קו: dashed/dotted נעלמים, double/triple→single (פריט 46).** `_convertSide` ממפה `dashed`/`dotted` ל‑`BorderStyle.none` → הגבול **בלתי‑נראה**. זו רגרסיה ויזואלית (Word מצייר קו מקווקו). יש לצייר עם `CustomPainter`/dash‑path; ולהבחין double/triple מ‑single.
- **autofit מקורב (פריט 51).** הגריד השמור מוקטן + רצפת longest‑word — אך לא איזון min/max content‑width אמיתי. טבלאות ללא gridCol מפורש, או עם תוכן רחב משתנה, יסטו מ‑Word. לשקול מדידת max‑content פר‑עמודה וחלוקה מידתית בכפוף ל‑`tblW`.
- **cnfStyle לא נצרך לבחירת אזור (פריטים 26, 40, 44).** האזור המותנה מוחל לפי מיקום (rowIndex/colIndex+look) ולא לפי ביטי ה‑cnfStyle המפורשים. כשהם סותרים — האזור שגוי. לפענח את 12 הביטים ולמפות ל‑`tblStylePr` הנכון.
- **טבלה צפה — מיקום מוחלט ועטיפה (פריטים 3, 4).** `tblpPr` נקרא אך מרונדר כ‑Row גס (טבלה + עד 5 פסקאות) ללא מיקום מוחלט/עטיפה אמיתית; `tblpXSpec`/`tblpYSpec` ו‑`tblOverlap` לא מנוצלים. נדרש Positioned בקואורדינטות עמוד + עטיפת טקסט (כמו עוגני ציור, משימה 09).
- **מאפיינים שנקראים אך לא מיושמים (פריטים 10, 22, 34, 37, 39, 40).** `tblCellSpacing`, `wBefore`/`wAfter`, `noWrap`, `tcFitText`, `hideMark`, `cnfStyle` — כולם נקראים ל‑AST אך אינם משפיעים על הרינדור. לתעד כסטיות מודעות; לחבר לצייר לפי הצורך.
- **מאפיינים שכלל לא נקראים (פריטים 6, 7, 23, 24, 25, 30, 41).** `tblStyleRowBandSize`/`tblStyleColBandSize` (גודל פס — banding מקודד כל‑שורה/עמודה), `jc`/`tblCellSpacing`/`hidden` ברמת שורה, `hMerge` (מיזוג אופקי ישן), ו‑revision של תא. להוסיף קריאה ב‑`table_parser.dart` (`_TempRow`/`_parseCell`).
- **אלכסונים tl2br/tr2bl (פריט 32).** לא נקראים ולא מצוירים. להוסיף קריאה ב‑`tcBorders` וציור קו אלכסוני (`CustomPainter`) על התא.
- **`tblInd` מקטין רוחב אך לא מזיח (פריט 11).** הטבלה נעשית צרה אך נשארת צמודה לשול המתחיל. להוסיף offset/padding מוביל בגודל `indentTwips` (תלוי‑כיוון ב‑RTL).
- **`w:shd` — רק fill, ללא val/pattern (פריטים 13, 33).** תבניות הצללה (pct/stripe) לא נתמכות בטבלה ובתא; רק צבע מילוי. לתעד כסטייה; אם נדרש — לצייר תבנית.
- **מעקב‑שינויים בטבלה (פריטים 27, 41).** שורות `w:ins`/`w:del` ותאי `cellIns`/`cellDel`/`cellMerge` לא נקראים → שורות מתוקנות עלולות להיעלם. ראו משימה 12.

### ב.3 — עדכון מימוש (בוצע ע"י ה‑AI המבצע, 2026‑06‑23)

> מבוצע לפי `PROMPTER.md`. כל פער שנסגר קיבל בדיקה; `flutter analyze` נקי; סוויטות הטבלאות ירוקות.

**מומש 1:1:**

| פריט | מה תוקן | קובץ | בדיקה |
|---|---|---|---|
| 9 | `jc` של טבלה — `start`/`end` תלויי‑כיוון (RTL→start=ימין); קודם נשמטו | `table_parser.dart` | `table_properties_test.dart` |
| 46 | גבולות תא `dashed`/`dotted` מצוירים כקו **נראה** (solid באותו עובי) במקום `BorderStyle.none` (בלתי‑נראה) | `table_builder.dart` (`_convertSide`) | `table_builder_test.dart` |

**נותר נדחה / סטיות מודעות (פערים גדולים או §8.2 קיימים — לא הוכנסו ברגרסיה):**

- **פתרון קונפליקט גבולות בין שכנים (45–47):** דורש grid render‑object תלוי‑כיוון שמחשב מנצח יחיד לכל קו — נדחה במפורש §8.2 #22. (התיקון ל‑46 מבטיח שלפחות הקו נראה.)
- **autofit מלא (51):** מקורב (גריד שמור + רצפת longest‑word); אלגוריתם min/max content‑width מלא לא מומש.
- **cnfStyle ל‑12 ביטים (44):** האזור עדיין נבחר לפי מיקום ולא לפי הביטים.
- **טבלה צפה — מיקום מוחלט/עטיפה (3,4):** מרונדר כ‑Row גס.
- **אלכסונים tl2br/tr2bl (32), hMerge ישן (30), banding size (6,7), tblInd offset (11), נקרא‑לא‑מומש (10,22,34,37,39), shd pattern (13,33), revision טבלה (27,41):** סטיות מודעות.
