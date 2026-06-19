# משימה 06 — טבלאות — `w:tblPr` / `w:trPr` / `w:tcPr`

> **מקור:** סעיף §6 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —

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

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:tblGrid` / `w:gridCol` (רוחב עמודה לוגית) | | | | |
| 2 | `w:tblStyle` | | | | |
| 3 | `w:tblpPr` (טבלה צפה — anchor/Spec/FromText) | | | | |
| 4 | `w:tblOverlap` (never/overlap) | | | | |
| 5 | `w:bidiVisual` (טבלת RTL — קריטי) | | | | |
| 6 | `w:tblStyleRowBandSize` | | | | |
| 7 | `w:tblStyleColBandSize` | | | | |
| 8 | `w:tblW` (w + type: auto/dxa/pct/nil) | | | | |
| 9 | `w:jc` (טבלה — תלוי‑כיוון) | | | | |
| 10 | `w:tblCellSpacing` (טבלה) | | | | |
| 11 | `w:tblInd` (הזחת טבלה) | | | | |
| 12 | `w:tblBorders` (top/left/bottom/right/insideH/insideV) | | | | |
| 13 | `w:shd` (הצללת טבלה) | | | | |
| 14 | `w:tblLayout` (fixed/autofit) | | | | |
| 15 | `w:tblCellMar` (שולי תא ברירת מחדל) | | | | |
| 16 | `w:tblLook` | | | | |
| 17 | `w:tblCaption` / `w:tblDescription` | | | | |
| 18 | `w:trHeight` (val + hRule: auto/exact/atLeast) | | | | |
| 19 | `w:cantSplit` | | | | |
| 20 | `w:tblHeader` (שורת כותרת חוזרת — קריטי) | | | | |
| 21 | `w:gridBefore` / `w:gridAfter` | | | | |
| 22 | `w:wBefore` / `w:wAfter` | | | | |
| 23 | `w:jc` (שורה) | | | | |
| 24 | `w:tblCellSpacing` (שורה) | | | | |
| 25 | `w:hidden` (שורה מוסתרת) | | | | |
| 26 | `w:cnfStyle` (שורה) | | | | |
| 27 | `w:ins` / `w:del` (revision שורה) | | | | |
| 28 | `w:tcW` (רוחב תא + type) | | | | |
| 29 | `w:gridSpan` (מיזוג אופקי) | | | | |
| 30 | `w:hMerge` (restart/continue) | | | | |
| 31 | `w:vMerge` (מיזוג אנכי — restart/continue) | | | | |
| 32 | `w:tcBorders` (כולל אלכסונים tl2br/tr2bl) | | | | |
| 33 | `w:shd` (תא — גובר על שורה/טבלה) | | | | |
| 34 | `w:noWrap` (תא) | | | | |
| 35 | `w:tcMar` (שולי תא — דורס tblCellMar) | | | | |
| 36 | `w:textDirection` (תא — טקסט אנכי) | | | | |
| 37 | `w:tcFitText` | | | | |
| 38 | `w:vAlign` (תא — top/center/bottom) | | | | |
| 39 | `w:hideMark` | | | | |
| 40 | `w:cnfStyle` (תא) | | | | |
| 41 | `w:cellIns` / `w:cellDel` / `w:cellMerge` (revision תא) | | | | |
| 42 | `tblStylePr` — אזורים (wholeTable/firstRow/lastRow/firstCol/lastCol/band1-2Horz/Vert/4 פינות) | | | | |
| 43 | `tblLook` מפעיל אזורים (firstRow/lastRow/firstColumn/lastColumn/noHBand/noVBand/val) | | | | |
| 44 | `cnfStyle` (12 ביטים) → החלת tblStylePr הנכון | | | | |
| 45 | פתרון קונפליקט גבולות — sz מנצח | | | | |
| 46 | פתרון קונפליקט — קדימות סגנון קו (double>single>dashed>dotted) | | | | |
| 47 | פתרון קונפליקט — צבע כהה / מיקום (top/left) | | | | |
| 48 | פתרון קונפליקט — nil מאבד / none מבטל גבול‑סגנון | | | | |
| 49 | קדימות מקור: tcBorders > insideH/V > סגנון | | | | |
| 50 | `tblLayout="fixed"` — רוחבים מ‑gridCol, חיתוך תוכן | | | | |
| 51 | `tblLayout="autofit"` — מדידת תוכן + חלוקה מידתית בכפוף ל‑tblW | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
