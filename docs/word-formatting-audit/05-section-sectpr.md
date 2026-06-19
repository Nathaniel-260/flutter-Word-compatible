# משימה 05 — מקטעים, עמוד, טורים, גבולות, מספור — `w:sectPr`

> **מקור:** סעיף §5 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

מקטע מגדיר את גאומטריית העמוד וכל מה שתלוי‑עמוד. הסדר של ילדי `CT_SectPr` מחייב:

### 5.1 כותרות/תחתיות והערות

| אלמנט | XML | מה עושה |
|---|---|---|
| `w:headerReference` | `<w:headerReference w:type="default" r:id="rId7"/>` | מצביע לקובץ header. `w:type`: `default` (אי‑זוגי/כל), `even` (זוגי), `first` (עמוד ראשון) |
| `w:footerReference` | אותו דבר ל‑footer | |
| `w:footnotePr` | `pos`, `numFmt`, `numStart`, `numRestart`, `numStartCount` | מאפייני הערות שוליים פר‑מקטע |
| `w:endnotePr` | אותו דבר להערות סיום | |

> שלושת ה‑variants (default/even/first) מופעלים לפי `w:titlePg` (להלן) ו‑`w:evenAndOddHeaders` ב‑settings.xml. בלי `evenAndOddHeaders`, `even` מתעלם וה‑default משמש לכל העמודים.

### 5.2 סוג מקטע, גודל ושוליים

| אלמנט | XML | מה עושה |
|---|---|---|
| `w:type` | `<w:type w:val="nextPage"/>` | תחילת המקטע: `nextPage`, `continuous` (ללא מעבר), `evenPage`, `oddPage`, `nextColumn` |
| `w:pgSz` | `<w:pgSz w:w="11906" w:h="16838" w:orient="portrait" w:code="9"/>` | גודל עמוד ב‑twips (11906×16838 = A4). `orient`: portrait/landscape. `code`=קוד גודל נייר. |
| `w:pgMar` | `<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>` | שוליים ב‑twips. `header`/`footer`=מרחק הכותרת מקצה הנייר. `gutter`=שוליים נוספים לכריכה. top/bottom יכולים להיות שליליים. |
| `w:paperSrc` | `first`, `other` | מגש נייר במדפסת (לא ויזואלי) |

### 5.3 גבולות עמוד — `w:pgBorders`

```xml
<w:pgBorders w:offsetFrom="page" w:display="allPages" w:zOrder="front">
  <w:top    w:val="single" w:sz="24" w:space="24" w:color="auto"/>
  <w:left   .../><w:bottom .../><w:right .../>
</w:pgBorders>
```

| תכונה | ערכים | מה עושה |
|---|---|---|
| `w:offsetFrom` | page / text | האם `space` נמדד מקצה הנייר או מהטקסט |
| `w:display` | allPages / firstPage / notFirstPage | באילו עמודים להציג |
| `w:zOrder` | front / back | מעל או מתחת לתוכן |
| כל גבול (top/left/bottom/right) | `CT_Border` (§2.4) + `w:id` ל‑art borders | art borders (apples, hearts...) דורשים תמונות חוזרות. ראו [§17.1](17-enums.md) |

> ב‑`offsetFrom="text"` ה‑`space` ב‑pgBorders נמדד **בנקודות** מהטקסט; ב‑`page` הוא בנקודות מקצה הנייר.

### 5.4 מספור שורות — `w:lnNumType`

| תכונה | מה עושה |
|---|---|
| `w:countBy` | מספר כל N שורות (1=כל שורה) |
| `w:start` | מספר התחלה |
| `w:distance` | מרחק המספר מהטקסט (twips) |
| `w:restart` | newPage / newSection / continuous |

### 5.5 מספור עמודים — `w:pgNumType`

| תכונה | ערכים | מה עושה |
|---|---|---|
| `w:start` | int | מספר העמוד הראשון במקטע |
| `w:fmt` | ST_NumberFormat (decimal, lowerRoman, upperLetter, hebrew1…) | פורמט מספר העמוד |
| `w:chapStyle` | int | סגנון הכותרת המגדיר מספר פרק (לפורמט "1‑1") |
| `w:chapSep` | hyphen, period, colon, emDash, enDash | מפריד בין מספר פרק למספר עמוד |

> השדה `PAGE` בכותרת מקבל את הפורמט מ‑`pgNumType/@fmt` של המקטע הנוכחי. `start` מאפס את ספירת העמודים.

### 5.6 טורים — `w:cols`

```xml
<w:cols w:num="2" w:space="708" w:equalWidth="0" w:sep="1">
  <w:col w:w="2700" w:space="360"/>
  <w:col w:w="6000"/>
</w:cols>
```

| תכונה | מה עושה |
|---|---|
| `w:num` | מספר הטורים |
| `w:space` | מרווח אחיד בין טורים (twips) — כש‑equalWidth |
| `w:equalWidth` | bool — טורים שווים (אז מתעלמים מ‑`col`) או רוחב פר‑טור |
| `w:sep` | bool — קו מפריד בין טורים |
| `w:col` | `w` (רוחב הטור) + `space` (מרווח אחריו) — כשהרוחבים אינם שווים |

> במקטע **RTL** (`w:bidi`), סדר הטורים מימין לשמאל. מעבר טור = `<w:br w:type="column"/>`.

### 5.7 שאר מאפייני המקטע

| אלמנט | ערכים | מה עושה |
|---|---|---|
| `w:vAlign` | top / center / both / bottom | **יישור אנכי של התוכן בעמוד** (both=justify אנכי) |
| `w:titlePg` | toggle | הפעל header/footer שונה לעמוד הראשון של המקטע |
| `w:bidi` | toggle | מקטע RTL (משפיע על סדר טורים וברירת כיוון) |
| `w:rtlGutter` | toggle | ה‑gutter בצד ימין |
| `w:textDirection` | lrTb, tbRl… | כיוון זרימה למקטע כולו (EA/אנכי) |
| `w:formProt` | toggle | אפשר עריכה רק בשדות טופס |
| `w:noEndnote` | toggle | אל תציג הערות סיום במקטע |
| `w:docGrid` | `type` (default/lines/linesAndChars/snapToChars), `linePitch`, `charSpace` | רשת מסמך — מספר שורות/תווים קבוע לעמוד (EA) |
| `w:printerSettings` | r:id | הפניה לנתוני מדפסת (לא ויזואלי) |
| `w:sectPrChange` | | מעקב‑שינויים על המקטע (§12) |

> **`docGrid`** משפיע על גובה שורה ב‑EA: `linePitch` קובע גובה שורה קבוע ברשת. מנוע לא‑EA יכול לרוב להתעלם, אך שים לב שהוא יכול לשנות גובה שורה גם בלטינית כש‑`type="lines"`.

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:headerReference` (type: default/even/first) | | | | |
| 2 | `w:footerReference` (type: default/even/first) | | | | |
| 3 | `w:footnotePr` (pos/numFmt/numStart/numRestart/numStartCount) | | | | |
| 4 | `w:endnotePr` | | | | |
| 5 | החלת variants לפי `titlePg` + `evenAndOddHeaders` | | | | |
| 6 | `w:type` (nextPage/continuous/evenPage/oddPage/nextColumn) | | | | |
| 7 | `w:pgSz` (`w`/`h`/`orient`/`code`) | | | | |
| 8 | `w:pgMar` (top/right/bottom/left/header/footer/gutter; שליליים) | | | | |
| 9 | `w:paperSrc` (first/other) | | | | |
| 10 | `w:pgBorders` — `offsetFrom` (page/text) | | | | |
| 11 | `w:pgBorders` — `display` (allPages/firstPage/notFirstPage) | | | | |
| 12 | `w:pgBorders` — `zOrder` (front/back) | | | | |
| 13 | `w:pgBorders` — גבולות top/left/bottom/right (CT_Border) | | | | |
| 14 | `w:pgBorders` — `id` ל‑art borders | | | | |
| 15 | `w:lnNumType` — `countBy` | | | | |
| 16 | `w:lnNumType` — `start` | | | | |
| 17 | `w:lnNumType` — `distance` | | | | |
| 18 | `w:lnNumType` — `restart` (newPage/newSection/continuous) | | | | |
| 19 | `w:pgNumType` — `start` (איפוס ספירה) | | | | |
| 20 | `w:pgNumType` — `fmt` (ST_NumberFormat, כולל hebrew) | | | | |
| 21 | `w:pgNumType` — `chapStyle` | | | | |
| 22 | `w:pgNumType` — `chapSep` (hyphen/period/colon/emDash/enDash) | | | | |
| 23 | `w:cols` — `num` | | | | |
| 24 | `w:cols` — `space` (equalWidth) | | | | |
| 25 | `w:cols` — `equalWidth` | | | | |
| 26 | `w:cols` — `sep` (קו מפריד) | | | | |
| 27 | `w:cols` — `col` (w + space פר‑טור) | | | | |
| 28 | סדר טורים RTL + מעבר טור (`<w:br w:type="column"/>`) | | | | |
| 29 | `w:vAlign` (top/center/both/bottom — יישור אנכי בעמוד) | | | | |
| 30 | `w:titlePg` | | | | |
| 31 | `w:bidi` (מקטע RTL) | | | | |
| 32 | `w:rtlGutter` | | | | |
| 33 | `w:textDirection` (מקטע) | | | | |
| 34 | `w:formProt` | | | | |
| 35 | `w:noEndnote` | | | | |
| 36 | `w:docGrid` (type/linePitch/charSpace) | | | | |
| 37 | `w:printerSettings` | | | | |
| 38 | `w:sectPrChange` (revision) | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
