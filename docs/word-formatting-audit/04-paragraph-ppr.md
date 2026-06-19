# משימה 04 — עיצוב פסקה — `w:pPr`

> **מקור:** סעיף §4 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

`pPr` הוא הילד הראשון של `w:p` (כשקיים). הסדר של ילדיו מחייב לפי הסכמה (`CT_PPr`). הרשימה המלאה, לפי סדר הסכמה:

### 4.1 הפניית סגנון ושמירה (keep)

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:pStyle` | `<w:pStyle w:val="Heading1"/>` | מחיל **סגנון פסקה** | בסיס לשרשרת `basedOn` |
| `w:keepNext` | `<w:keepNext/>` | החזק את הפסקה באותו עמוד עם הבאה אחריה | toggle; מונע יתמות כותרת |
| `w:keepLines` | `<w:keepLines/>` | אל תשבור את שורות הפסקה בין עמודים | toggle |
| `w:pageBreakBefore` | `<w:pageBreakBefore/>` | התחל את הפסקה בראש עמוד חדש | toggle; כופה מעבר עמוד לפני |
| `w:widowControl` | `<w:widowControl/>` | מנע שורה בודדת (אלמנה/יתום) בראש/סוף עמוד | **ברירת מחדל true** ב‑Word (בד"כ ב‑docDefaults) |
| `w:suppressLineNumbers` | | אל תמספר שורות בפסקה זו (כשמספור שורות פעיל) | toggle |
| `w:suppressAutoHyphens` | | בטל מיקוף אוטומטי בפסקה | toggle |

### 4.2 מסגרת טקסט — `w:framePr`

הופך פסקה ל"מסגרת צפה" (text frame) — בסיס drop‑cap וכותרות צד.

| תכונה | ערכים | מה עושה |
|---|---|---|
| `w:dropCap` | none/drop/margin | אות פתיח מוגדלת; `drop`=בתוך הטקסט, `margin`=בשוליים |
| `w:lines` | int | כמה שורות גובה תופסת ה‑drop cap |
| `w:w`,`w:h` | twips | רוחב/גובה המסגרת |
| `w:hRule` | auto/exact/atLeast | כלל הגובה |
| `w:hSpace`,`w:vSpace` | twips | מרווח אופקי/אנכי מהטקסט שמסביב |
| `w:wrap` | around/none/notBeside/through/tight | עטיפת הטקסט סביב המסגרת |
| `w:hAnchor`,`w:vAnchor` | text/margin/page | עוגן המיקום האופקי/האנכי |
| `w:x`,`w:y` | twips | מיקום מוחלט |
| `w:xAlign` | left/center/right/inside/outside | יישור אופקי יחסי |
| `w:yAlign` | inline/top/center/bottom/inside/outside | יישור אנכי יחסי |
| `w:anchorLock` | bool | נעל את העוגן |

### 4.3 מספור (רשימה)

| אלמנט | XML | מה עושה |
|---|---|---|
| `w:numPr` | `<w:numPr><w:ilvl w:val="0"/><w:numId w:val="3"/></w:numPr>` | משייך את הפסקה לרשימה: `numId`→הגדרה ב‑numbering.xml, `ilvl`→רמת היררכיה (0‑based) |
| | `<w:ins .../>` בתוך numPr | מעקב‑שינויים על המספור |

> `numId="0"` = **ביטול מספור** מפורש (שובר מספור שירש מסגנון).

### 4.4 גבולות והצללה של פסקה

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:pBdr` | `<w:pBdr><w:top …/><w:left …/><w:bottom …/><w:right …/><w:between …/><w:bar …/></w:pBdr>` | גבולות פסקה (תכונות `CT_Border`) | `between`=קו בין פסקאות עוקבות עם אותו גבול; `bar`=קו אנכי בצד |
| `w:shd` | `<w:shd w:val="clear" w:fill="E0E0E0"/>` | הצללת רקע לפסקה (§2.3) | מתפרס על כל רוחב אזור הטקסט |

> **מיזוג גבולות פסקה:** פסקאות עוקבות עם `pBdr` זהה ממוזגות לתיבה אחת (Word לא מצייר קו אופקי ביניהן אלא `between`). מקרה קצה למנוע.

### 4.5 טאבים — `w:tabs`

```xml
<w:tabs>
  <w:tab w:val="center" w:pos="4320"/>
  <w:tab w:val="right"  w:pos="8640" w:leader="dot"/>
  <w:tab w:val="clear"  w:pos="2880"/>
</w:tabs>
```

| תכונה | ערכים | מה עושה |
|---|---|---|
| `w:val` | left, center, right, decimal, bar, num, start, end, clear | סוג היישור בנקודת הטאב. `decimal`=יישור לפי נקודה עשרונית; `bar`=מצייר קו אנכי; `clear`=מוחק טאב שירש; `num`=טאב רשימה |
| `w:pos` | twips | מיקום מהשוליים |
| `w:leader` | none, dot, hyphen, underscore, heavy, middleDot | תו מילוי עד הטאב (למשל נקודות בתוכן עניינים) |

> טאבים שלא הוגדרו במפורש נופלים ל‑`w:defaultTabStop` מ‑settings.xml (ברירת מחדל 720 twips = חצי אינץ').

### 4.6 טיפוגרפיית מזרח‑אסיה (ברמת פסקה)

| אלמנט | מה עושה |
|---|---|
| `w:kinsoku` | החל כללי שבירת‑שורה של EA (אסור להתחיל/לסיים שורה בתווים מסוימים) |
| `w:wordWrap` | התר שבירה ברמת תו (לא רק רווח) |
| `w:overflowPunct` | אפשר לפיסוק לחרוג מעבר לשוליים |
| `w:topLinePunct` | דחוס פיסוק בתחילת שורה |
| `w:autoSpaceDE` | רווח אוטומטי בין לטינית ל‑EA |
| `w:autoSpaceDN` | רווח אוטומטי בין EA לספרות |
| `w:snapToGrid` | יישר את הפסקה ל‑docGrid |
| `w:adjustRightInd` | התאם אוטומטית הזחה ימנית לרשת |

### 4.7 כיוון, ריווח, הזחה, יישור

| אלמנט | XML | יחידה/ערכים | מה עושה | קצה |
|---|---|---|---|---|
| `w:bidi` | `<w:bidi/>` | toggle | **כיוון פסקה RTL** | **דגל הכיוון הקריטי**; קובע גם את מיפוי `jc` (§16.4) |
| `w:spacing` | `<w:spacing w:before="240" w:after="120" w:line="360" w:lineRule="auto"/>` | ראה למטה | ריווח לפני/אחרי + גובה שורה | |
| `w:ind` | `<w:ind w:start="720" w:hanging="360"/>` | twips | הזחות | |
| `w:contextualSpacing` | toggle | | בטל before/after בין פסקאות מאותו סגנון רצופות | קריטי לרשימות צפופות |
| `w:mirrorIndents` | toggle | | התייחס להזחה left/right כ‑inside/outside (הדפסת ספר) | |
| `w:suppressOverlap` | toggle | | מנע ממסגרות טקסט לחפוף | |
| `w:jc` | `<w:jc w:val="both"/>` | start,end,left,right,center,both,distribute,… | **יישור אופקי** | תלוי‑כיוון! ראו §16.4 + [§17.3](17-enums.md) |
| `w:textDirection` | `<w:textDirection w:val="tbRl"/>` | lrTb, tbRl, btLr, lrTbV, tbRlV, tbLrV | כיוון זרימת הטקסט (אופקי/אנכי) | רלוונטי לתאים ול‑EA |
| `w:textAlignment` | `<w:textAlignment w:val="center"/>` | auto, baseline, top, center, bottom | יישור **אנכי** של תווים בשורה (כשגדלים שונים) | |
| `w:textboxTightWrap` | none/allLines/firstAndLastLine/… | | עטיפה צמודה לתוכן תיבת טקסט | |
| `w:outlineLvl` | `<w:outlineLvl w:val="0"/>` | 0–9 (9=body) | רמת תוכן עניינים/חלוקה לראשי פרקים | משפיע על TOC ועל ניווט |
| `w:divId` | int | | קישור ל‑HTML div | לא ויזואלי |
| `w:cnfStyle` | `<w:cnfStyle w:val="100000000000"/>` | bitmask | עיצוב מותנה (firstRow/lastRow/...) — בעיקר בתאים | ראו §6.5 |

#### פירוט `w:spacing` (פסקה)

| תכונה | יחידה | מה עושה |
|---|---|---|
| `w:before` | twips | רווח מעל הפסקה |
| `w:after` | twips | רווח מתחת לפסקה |
| `w:beforeLines`,`w:afterLines` | 1/100 שורה | רווח לפני/אחרי ביחידות שורה |
| `w:beforeAutospacing`,`w:afterAutospacing` | toggle | רווח אוטומטי (כמו ב‑HTML `<p>`); כשדלוק, מתעלם מ‑before/after המספריים |
| `w:line` | תלוי lineRule | גובה שורה |
| `w:lineRule` | auto/exact/atLeast | פירוש `line`: **auto**→`line` ב‑240ths (240=יחיד, 360=1.5, 480=כפול); **exact**→`line` ב‑twips (גובה קבוע, חותך תוכן גדול); **atLeast**→`line` ב‑twips כמינימום (גדל לפי הצורך) |

#### פירוט `w:ind` (הזחה)

| תכונה | מה עושה | קצה |
|---|---|---|
| `w:start` / `w:left` | הזחה מהצד המתחיל (start = תלוי‑כיוון, החדש; left = הישן) | Word החדש כותב start/end |
| `w:end` / `w:right` | הזחה מהצד המסיים | |
| `w:firstLine` | הזחה נוספת **לשורה הראשונה** | |
| `w:hanging` | הזחה **תלויה** — השורה הראשונה שמאלה משאר הפסקה | `hanging` גובר על `firstLine`; בסיס לרשימות |
| `w:startChars`/`w:endChars`/`w:firstLineChars`/`w:hangingChars` | אותו דבר ביחידות תו (EA) | |

### 4.8 `w:rPr` בתוך `w:pPr` (mark run properties)

עיצוב של **תו סוף‑הפסקה** (סימן הפיד). קובע את גובה השורה הריקה ועיצוב סימן הפסקה. קריטי: גודל פונט של mark run משפיע על גובה פסקה ריקה ועל מרווחים.

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:pStyle` (סגנון פסקה) | | | | |
| 2 | `w:keepNext` | | | | |
| 3 | `w:keepLines` | | | | |
| 4 | `w:pageBreakBefore` | | | | |
| 5 | `w:widowControl` (ברירת מחדל true) | | | | |
| 6 | `w:suppressLineNumbers` | | | | |
| 7 | `w:suppressAutoHyphens` | | | | |
| 8 | `w:framePr` — `dropCap` (none/drop/margin) | | | | |
| 9 | `w:framePr` — `lines` | | | | |
| 10 | `w:framePr` — `w`/`h` | | | | |
| 11 | `w:framePr` — `hRule` | | | | |
| 12 | `w:framePr` — `hSpace`/`vSpace` | | | | |
| 13 | `w:framePr` — `wrap` | | | | |
| 14 | `w:framePr` — `hAnchor`/`vAnchor` | | | | |
| 15 | `w:framePr` — `x`/`y` | | | | |
| 16 | `w:framePr` — `xAlign`/`yAlign` | | | | |
| 17 | `w:framePr` — `anchorLock` | | | | |
| 18 | `w:numPr` — `ilvl` + `numId` | | | | |
| 19 | `numId="0"` (ביטול מספור מפורש) | | | | |
| 20 | `w:ins` בתוך numPr (revision על מספור) | | | | |
| 21 | `w:pBdr` — top/left/bottom/right | | | | |
| 22 | `w:pBdr` — `between` (קו בין פסקאות) | | | | |
| 23 | `w:pBdr` — `bar` (קו אנכי בצד) | | | | |
| 24 | מיזוג גבולות פסקה עוקבות זהות | | | | |
| 25 | `w:shd` (הצללת פסקה) | | | | |
| 26 | `w:tabs` — `val` (left/center/right/decimal/bar/num/start/end/clear) | | | | |
| 27 | `w:tabs` — `pos` (twips) | | | | |
| 28 | `w:tabs` — `leader` (none/dot/hyphen/underscore/heavy/middleDot) | | | | |
| 29 | נפילה ל‑`defaultTabStop` כשאין טאב מוגדר | | | | |
| 30 | `w:kinsoku` (EA) | | | | |
| 31 | `w:wordWrap` (שבירה ברמת תו) | | | | |
| 32 | `w:overflowPunct` | | | | |
| 33 | `w:topLinePunct` | | | | |
| 34 | `w:autoSpaceDE` | | | | |
| 35 | `w:autoSpaceDN` | | | | |
| 36 | `w:snapToGrid` (פסקה) | | | | |
| 37 | `w:adjustRightInd` | | | | |
| 38 | `w:bidi` (כיוון פסקה RTL — קריטי) | | | | |
| 39 | `w:spacing` — `before` | | | | |
| 40 | `w:spacing` — `after` | | | | |
| 41 | `w:spacing` — `beforeLines`/`afterLines` | | | | |
| 42 | `w:spacing` — `beforeAutospacing`/`afterAutospacing` | | | | |
| 43 | `w:spacing` — `line` + `lineRule` (auto/exact/atLeast) | | | | |
| 44 | `w:ind` — `start`/`left` | | | | |
| 45 | `w:ind` — `end`/`right` | | | | |
| 46 | `w:ind` — `firstLine` | | | | |
| 47 | `w:ind` — `hanging` (גובר על firstLine) | | | | |
| 48 | `w:ind` — `startChars`/`endChars`/`firstLineChars`/`hangingChars` | | | | |
| 49 | `w:contextualSpacing` | | | | |
| 50 | `w:mirrorIndents` | | | | |
| 51 | `w:suppressOverlap` | | | | |
| 52 | `w:jc` (יישור — תלוי‑bidi, §16.4) | | | | |
| 53 | `w:textDirection` (פסקה — lrTb/tbRl/…) | | | | |
| 54 | `w:textAlignment` (יישור אנכי בשורה) | | | | |
| 55 | `w:textboxTightWrap` | | | | |
| 56 | `w:outlineLvl` (0–9) | | | | |
| 57 | `w:divId` | | | | |
| 58 | `w:cnfStyle` (פסקה — bitmask) | | | | |
| 59 | `w:rPr` בתוך `pPr` (mark run — גובה פסקה ריקה) | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
