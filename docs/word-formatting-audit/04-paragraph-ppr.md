# משימה 04 — עיצוב פסקה — `w:pPr`

> **מקור:** סעיף §4 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-19

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

> **צנרת התצוגה.** עיצוב הפסקה מפוענח ב‑**reader** (`docx_creator`): התכונות הסגנוניות
> (jc/spacing/ind/shd/pBdr/numPr) דרך `DocxStyle.fromXml` → `effectiveStyle.merge(direct)`,
> ודגלי toggle (keepNext/keepLines/widowControl/pageBreakBefore/bidi/suppressAutoHyphens/
> contextualSpacing/tabs/outlineLvl/textAlignment) נקראים **ישירות מ‑pPr** ב‑`parseParagraph`
> (`block_parser.dart:209-231`) ולכן **אינם יורשים** משרשרת הסגנונות. הרינדור ב‑**viewer**:
> `ParagraphBuilder._wrapWithParagraphStyle` (הזחה/רקע/גבולות/ריווח), `bidi_align` (jc),
> `span_factory` (line/lineRule), `tab_engine`/`TabbedLineRenderer` (טאבים) ו‑`paginator`
> (keepNext/keepLines/widowControl/pageBreakBefore). פריט שאינו ויזואלי מסומן `n/a`.

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:pStyle` (סגנון פסקה) | כן | ראו משימה 07 | מחיל סגנון פסקה. מיושב דרך `resolveStyle(pStyle)` ואז `effectiveStyle.merge(direct pPr)`; שרשרת `basedOn`+`docDefaults` במנוע הסגנונות. | `block_parser.dart:183-190`; merge `docx_style.dart:205-259` |
| 2 | `w:keepNext` | כן | חלקי | Word שומר את הפסקה באותו עמוד עם הבאה. הפַּגינטור מקבץ פסקאות `keepNext` ומעביר את הקבוצה לעמוד/טור הבא אם אינה נכנסת — **best‑effort** (קבוצה גדולה מעמוד מתפצלת רגיל). נקרא רק מ‑pPr ישיר. | `block_parser.dart:210`; `paginator.dart:806-841` |
| 3 | `w:keepLines` | כן | כן (מצב מעומד) | מונע פיצול הפסקה בין עמודים; `_splitParagraph` מחזיר null ל‑`keepLines`. ב‑continuous אין עמודים → לא רלוונטי. ישיר בלבד. | `block_parser.dart:211`; `paginator.dart:1100` |
| 4 | `w:pageBreakBefore` | כן | חלקי | במצב מעומד — `_newPage` אמיתי. ב‑continuous מצויר `Divider` קו אופקי (**ארטיפקט** — Word לא מצייר קו). ישיר בלבד. | `block_parser.dart:217`; `paginator.dart:847-851`; `paragraph_builder.dart:596-613` |
| 5 | `w:widowControl` (ברירת מחדל true) | כן | חלקי | ברירת המחדל true מיושמת (`readOnOff(..., orElse:true)`); בפיצול נדרשות ≥2 שורות בכל צד. **לא** יורש מ‑docDefaults של סגנון — רק מ‑pPr ישיר. | `block_parser.dart:213-214`; `paginator.dart:1126-1130` |
| 6 | `w:suppressLineNumbers` | לא | לא | מספור שורות עצמו אינו ממומש במנוע, ולכן גם הדגל אינו נקרא/רלוונטי. | אין |
| 7 | `w:suppressAutoHyphens` | חלקי | n/a | נקרא ל‑`suppressHyphens`, אך מיקוף אוטומטי כלל אינו ממומש (Flutter שובר ברווחים) → הדגל ללא אפקט. | `block_parser.dart:215` (נקרא, לא מוחל) |
| 8 | `w:framePr` — `dropCap` (none/drop/margin) | חלקי | חלקי | רק `drop`/`margin` מזוהים ויוצרים `DocxDropCap` (rendered ע"י `DropCapText`); `none` ושאר השימושים ב‑framePr מתעלמים. | `block_parser.dart:57-90,523-529`; `paragraph_builder.dart:1017-1082` |
| 9 | `w:framePr` — `lines` | כן | חלקי | נקרא וקובע את גובה ה‑drop cap (קירוב `lines×fontSize`). | `block_parser.dart:531-533`; `paragraph_builder.dart:1025` |
| 10 | `w:framePr` — `w`/`h` | לא | לא | רוחב/גובה המסגרת אינם נקראים (אין מסגרת טקסט צפה כללית). | אין |
| 11 | `w:framePr` — `hRule` | לא | לא | כלל הגובה אינו נקרא. | אין |
| 12 | `w:framePr` — `hSpace`/`vSpace` | חלקי | חלקי | `hSpace` בלבד נקרא (padding ימני ל‑drop cap); `vSpace` מתעלם. | `block_parser.dart:536-537`; `paragraph_builder.dart:1078-1079` |
| 13 | `w:framePr` — `wrap` | לא | לא | עטיפת טקסט סביב המסגרת אינה נתמכת (drop cap מקורב בלבד). | אין |
| 14 | `w:framePr` — `hAnchor`/`vAnchor` | לא | לא | עוגני המיקום אינם נקראים. | אין |
| 15 | `w:framePr` — `x`/`y` | לא | לא | מיקום מוחלט אינו נקרא. | אין |
| 16 | `w:framePr` — `xAlign`/`yAlign` | לא | לא | יישור יחסי אינו נקרא. | אין |
| 17 | `w:framePr` — `anchorLock` | לא | לא | אינו נקרא. | אין |
| 18 | `w:numPr` — `ilvl` + `numId` | כן | ראו משימה 08 | `numId`+`ilvl` נקראים; פסקאות עוקבות עם אותו `numId` מקובצות ל‑`DocxList`. | `docx_style.dart:387-398`; `block_parser.dart:93-99,287-381` |
| 19 | `numId="0"` (ביטול מספור מפורש) | לא | לא | **באג נאמנות:** Word מפרש `numId=0` כביטול מספור שירש. כאן `0` נקרא כ‑int ומקבץ לרשימה עם numId 0 (def חסר → תבליט ברירת מחדל) → מציג תבליט שגוי במקום לבטל. | `docx_style.dart:392-394`; `block_parser.dart:93` |
| 20 | `w:ins` בתוך numPr (revision על מספור) | לא | לא | מעקב‑שינויים על המספור אינו מטופל; רק `numId`/`ilvl` נקראים. | אין |
| 21 | `w:pBdr` — top/left/bottom/right | כן | חלקי | נקראים ומצוירים כ‑`Border` של ה‑`Container`. **ללא** `w:space` (ריווח גבול) וללא לוגיקת קונפליקט/עובי מדויק (eighths→px עם clamp 0.5–10). | `docx_style.dart:401-406`; `paragraph_builder.dart:640-657,682-700` |
| 22 | `w:pBdr` — `between` (קו בין פסקאות) | חלקי | לא | `borderBetween` נקרא אך בויואר משמש רק כ‑fallback לגבול תחתון (`bottomSpec = bottom ?? between`) — לא קו אמיתי בין פסקאות עוקבות. | `docx_style.dart:407`; `paragraph_builder.dart:646` |
| 23 | `w:pBdr` — `bar` (קו אנכי בצד) | לא | לא | אינו נקרא (רק top/bottom/left/right/between). | אין |
| 24 | מיזוג גבולות פסקה עוקבות זהות | לא | לא | כל פסקה מציירת תיבת `Container` נפרדת; אין מיזוג של `pBdr` זהה לתיבה אחת (Word ממזג). | אין (`paragraph_builder.dart:628-679` פר‑פסקה) |
| 25 | `w:shd` (הצללת פסקה) | חלקי | חלקי | רק `w:fill` (צבע מפורש) מצויר כרקע ה‑`Container`. `w:val` (תבנית pct/diagStripe), `w:color` ו‑`themeFill`/tint/shade — **לא** מיושמים. ראו §2.3/משימה 02. | `docx_style.dart:376-384`; `paragraph_builder.dart:629-631` |
| 26 | `w:tabs` — `val` (left/center/right/decimal/bar/num/start/end/clear) | חלקי | חלקי | left/center/right/bar/start/end/clear נתמכים; `decimal` ו‑`num`→decimal מקורבים כ‑**right** (ללא יישור לנקודה עשרונית — מגבלה מתועדת). | `enums.dart:54-68`; `tab_engine.dart:152-167` |
| 27 | `w:tabs` — `pos` (twips) | כן | כן | twips→px (`/15`), ממוין; clamp הגנתי לערכי קצה. | `block_parser.dart:275`; `tab_engine.dart:75-87` |
| 28 | `w:tabs` — `leader` (none/dot/hyphen/underscore/heavy/middleDot) | כן | חלקי | כל הערכים נקראים; ה‑leader מועבר ל‑`TabbedLineRenderer` שמצייר אותו. רק במסלול הטאבים המתואם (פריט 29). | `block_parser.dart:280`; `enums.dart:83-94`; `paragraph_builder.dart:452-461` |
| 29 | נפילה ל‑`defaultTabStop` כשאין טאב מוגדר | חלקי | לא | המסלול המתואם נכנס **רק** כשיש `w:tabs` מפורש ותוכן טקסט פשוט; פסקה עם תו טאב **ללא** `w:tabs` יורדת ל‑`RichText` שבו `DocxTab`=4 רווחים. בנוסף, המרווח ברירת המחדל **מקודד קשיח 720** ולא נקרא מ‑settings.xml (`w:defaultTabStop`). | `paragraph_builder.dart:141-143,737-740`; `tab_engine.dart:57` |
| 30 | `w:kinsoku` (EA) | לא | לא | כללי שבירת‑שורה של EA אינם ממומשים. | אין |
| 31 | `w:wordWrap` (שבירה ברמת תו) | לא | לא | אינו נקרא; השבירה לפי מנוע Flutter. | אין |
| 32 | `w:overflowPunct` | לא | לא | אינו נקרא. | אין |
| 33 | `w:topLinePunct` | לא | לא | אינו נקרא. | אין |
| 34 | `w:autoSpaceDE` | לא | לא | אינו נקרא. | אין |
| 35 | `w:autoSpaceDN` | לא | לא | אינו נקרא. | אין |
| 36 | `w:snapToGrid` (פסקה) | לא | לא | יישור ל‑docGrid אינו ממומש. | אין |
| 37 | `w:adjustRightInd` | לא | לא | אינו נקרא. | אין |
| 38 | `w:bidi` (כיוון פסקה RTL — קריטי) | כן | כן | **מקור האמת לכיוון**: `isRtl`→`Directionality` עוטף את הפסקה, וקובע את מיפוי `jc` תלוי‑הכיוון. נופל לזיהוי‑תוכן רק כשחסר. קריטי לעברית. | `block_parser.dart:209`; `paragraph_builder.dart:129-132,199-202`; `bidi_align.dart` |
| 39 | `w:spacing` — `before` | כן | חלקי | רווח עליון כ‑`padding.top` (twips/15). היוריסטיקת כותרת (fontSize≥20) מצמידה מינימום 16px → עלולה לסטות מ‑Word. | `docx_style.dart:342-343`; `paragraph_builder.dart:577,583-591` |
| 40 | `w:spacing` — `after` | כן | חלקי | כמו `before`; היוריסטיקת כותרת מצמידה מינימום 8px. | `docx_style.dart:339-340`; `paragraph_builder.dart:579,588-590` |
| 41 | `w:spacing` — `beforeLines`/`afterLines` | לא | לא | רווח ביחידות שורה (1/100) אינו נקרא. ראו משימה 02. | אין |
| 42 | `w:spacing` — `beforeAutospacing`/`afterAutospacing` | לא | לא | רווח אוטומטי (כמו HTML `<p>`) אינו נקרא. | אין |
| 43 | `w:spacing` — `line` + `lineRule` (auto/exact/atLeast) | כן | כן (מקורב) | `auto`→`height=line/240` (multiplier); `exact`→`StrutStyle.forceStrutHeight`; `atLeast`→strut מינימלי. נחלק בין renderer ל‑measurer. | `docx_style.dart:345-349`; `span_factory.dart:112-141` |
| 44 | `w:ind` — `start`/`left` | כן | חלקי | נקרא (`left` או `start`) ומיושם כ‑`leftPadding` **פיזי**. ב‑RTL: `w:start` אמור להיות בצד ימין אך מיושם משמאל → **שגוי ל‑RTL**. | `docx_style.dart:355-357`; `paragraph_builder.dart:561` |
| 45 | `w:ind` — `end`/`right` | כן | חלקי | כמו 44: `rightPadding` פיזי; `end` הלוגי אינו ממופה לפי כיוון → שגוי ל‑RTL. | `docx_style.dart:359-361`; `paragraph_builder.dart:570` |
| 46 | `w:ind` — `firstLine` | כן | כן | spacer באורך אפס בתחילת השורה הראשונה. | `docx_style.dart:363-365`; `paragraph_builder.dart:211-213,714-719` |
| 47 | `w:ind` — `hanging` (גובר על firstLine) | חלקי | חלקי | מאוחסן כ‑`firstLine` שלילי; הקונטיינר מוזז שמאלה ושורות הגוף מקבלות spacer חיובי. **אם גם `firstLine` וגם `hanging` קיימים — כאן `firstLine` גובר (הפוך מהמפרט שבו hanging גובר).** | `docx_style.dart:363-372`; `paragraph_builder.dart:565-569,214-215` |
| 48 | `w:ind` — `startChars`/`endChars`/`firstLineChars`/`hangingChars` | לא | לא | הזחות ביחידות תו (EA) אינן נקראות. | אין |
| 49 | `w:contextualSpacing` | חלקי | חלקי | מיושם **רק לפריטי רשימה** (איפוס רווח בין פריטים מאותו סגנון); לפסקאות רגילות עוקבות אינו מוחל. ישיר בלבד. | `block_parser.dart:216`; `list_layout.dart:7,28` |
| 50 | `w:mirrorIndents` | לא | לא | הזחות מראה (הדפסת ספר) אינן נקראות. | אין |
| 51 | `w:suppressOverlap` | לא | לא | אינו נקרא. | אין |
| 52 | `w:jc` (יישור — תלוי‑bidi, §16.4) | כן | חלקי | start/end/left/right/center/both ממופים, והיישור הפיזי מיושב לפי הכיוון (`bidi_align`). `both`/`distribute`→justify (distribute לא מובחן). הקורא מכווץ start/left→left ו‑end/right→right, ולכן `jc=left` פיזי בתוך RTL מטופל שגוי (**סטייה מודעת §8.2**). | `docx_style.dart:327-334`; `bidi_align.dart:29-82`; `paragraph_builder.dart:199-202` |
| 53 | `w:textDirection` (פסקה — lrTb/tbRl/…) | לא | לא | כיוון זרימה אנכי (tbRl/btLr וכו') אינו נקרא. | אין |
| 54 | `w:textAlignment` (יישור אנכי בשורה) | חלקי | לא | נקרא ל‑`DocxParagraph.textAlignment` אך **אינו מיושם** ברינדור הויואר (משמש רק בייצוא `buildXml`). | `block_parser.dart:226-231` (לא מצויר) |
| 55 | `w:textboxTightWrap` | לא | לא | אינו נקרא. | אין |
| 56 | `w:outlineLvl` (0–9) | חלקי | n/a | נקרא ל‑`outlineLevel` אך **אינו מנוצל** בויואר (אין ניווט/TOC מ‑outline; ה‑TOC מגיע מ‑cache נפרד). | `block_parser.dart:220-224` (לא בשימוש) |
| 57 | `w:divId` | לא | n/a | קישור ל‑HTML div — לא ויזואלי, אינו נקרא. | אין |
| 58 | `w:cnfStyle` (פסקה — bitmask) | לא | לא | `parseParagraph` אינו קורא `cnfStyle` (השדה קיים ב‑AST אך אינו מאוכלס לפסקה); עיצוב מותנה מטופל ברמת תא/טבלה. ראו §6.5/משימה 06. | `block_parser.dart:177-266` (חסר) |
| 59 | `w:rPr` בתוך `pPr` (mark run — גובה פסקה ריקה) | חלקי | לא | ה‑rPr נקרא וממוזג ל‑`finalProps` אך לא מוחל: לא מועבר לריצות (לפי תכנון) **וגם** אינו קובע את גובה הפסקה הריקה (ב‑Word גודל סימן הפיד קובע את גובה השורה הריקה). | `block_parser.dart:196-200` (נקרא, לא משפיע על גובה ריק) |

### ב.2 — פערים והוראות ל‑AI הבא

- **`numId="0"` מציג תבליט שגוי (פריט 19).** Word מפרש `numId=0` כ**ביטול** מספור שירש. כאן הוא מקובץ לרשימה. **תיקון:** ב‑`block_parser.parseParagraph`/`parseBlocks` לטפל ב‑`numId==0` כ"ללא רשימה" (לא להוסיף ל‑`pendingListItems`).
- **הזחות תלויות‑כיוון שגויות ל‑RTL (פריטים 44/45).** `w:start`/`w:end` מיושמים פיזית כ‑left/right padding; במסמך עברי (RTL) ההזחה מופיעה בצד הלא‑נכון. **המלצה:** למפות start/end ל‑padding לפי כיוון הפסקה (`isRtl`).
- **`framePr` כמסגרת טקסט כללית (פריטים 10–17).** רק drop cap (`drop`/`margin`) מטופל; מסגרות צף/כותרות צד (`w`/`h`/`wrap`/`hAnchor`/`vAnchor`/`x`/`y`) אינן נתמכות. אם נדרש — לממש מסגרת צפה אמיתית.
- **גבולות פסקה (פריטים 21–24).** חסרים: `w:space` (ריווח גבול), `between` כקו אמיתי בין פסקאות, `bar` (קו אנכי בצד), ומיזוג `pBdr` זהה של פסקאות עוקבות לתיבה אחת.
- **הצללת פסקה חלקית (פריט 25).** רק `w:fill`; חסרים `w:val` (תבנית), `w:color` ו‑`themeFill`/tint/shade. ראו משימות 02/13.
- **טאבים (פריטים 26/29).** (א) `decimal`/`num` מקורבים כ‑right ללא יישור לנקודה. (ב) `defaultTabStop` מקודד קשיח 720 — לחבר ל‑`settings.xml` (`w:defaultTabStop`, ראו משימה 14). (ג) פסקה עם תו טאב **ללא** `w:tabs` מציגה 4 רווחים במקום קפיצה לטאב ברירת מחדל — לשקול הרחבת המסלול המתואם גם למקרה זה.
- **דגלי פסקה אינם יורשים מסגנון.** keepNext/keepLines/widowControl/pageBreakBefore/bidi/suppressAutoHyphens/contextualSpacing/tabs/outlineLvl/textAlignment נקראים **רק מ‑pPr ישיר** (`block_parser.dart:209-231`) — סגנון שמגדיר אותם (למשל `keepNext` ב‑Heading) לא ישפיע. **המלצה:** ליישב גם דגלים אלו דרך מנוע הסגנונות (`merge`), כמו שעושים ל‑jc/spacing/ind.
- **`hanging` מול `firstLine` (פריט 47).** סדר העדיפות הפוך מהמפרט (כאן firstLine גובר; אמור hanging). מקרה קצה אך אמיתי ברשימות.
- **נקרא‑אך‑לא‑מנוצל:** `textAlignment` (54) ו‑`outlineLvl` (56) מפוענחים אך אינם משפיעים על התצוגה — להשלים מימוש או לתעד כסטייה מודעת.
- **`pageBreakBefore` ב‑continuous (פריט 4) מצייר `Divider`** — ארטיפקט ויזואלי שאין לו מקבילה ב‑Word; לשקול הסרה במצב רציף.
- **היוריסטיקת כותרת בריווח (פריטים 39/40).** הצמדת מינימום 16/8px לפי fontSize≥20 משנה רווחים מ‑Word — לבחון הסרה לטובת הערכים המיושבים בלבד.
- **`mark run` rPr (פריט 59) אינו קובע גובה פסקה ריקה** — פוגע בגובה שורות ריקות/מרווחים. ראו משימה 03 (rPr).
- **לא ממומשים (לרוב EA/נדיר/לא‑ויזואלי) — לתעד כסטייה מודעת:** suppressLineNumbers (6), כל טיפוגרפיית EA (30–37), mirrorIndents (50), suppressOverlap (51), textDirection (53), textboxTightWrap (55), divId (57), cnfStyle בפסקה (58).
