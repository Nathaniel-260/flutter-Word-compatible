# משימה 09 — ציור, תמונות, צורות, תיבות טקסט — DrawingML / VML

> **מקור:** סעיף §9 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-21

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

תוכן גרפי מודרני יושב ב‑`w:drawing` (DrawingML). תוכן ישן ב‑`w:pict` (VML). שניהם בתוך ריצה (`w:r`).

### 9.1 inline מול anchor

```xml
<w:r><w:drawing>
  <wp:inline distT="0" distB="0" distL="0" distR="0"> … </wp:inline>
  <!-- או -->
  <wp:anchor …> … </wp:anchor>
</w:drawing></w:r>
```

- **`wp:inline`** — התמונה היא "תו ענק" בתוך שורת הטקסט (זורמת עם הטקסט).
- **`wp:anchor`** — התמונה **צפה**: מיקום יחסי לעמוד/שוליים/פסקה + עטיפת טקסט.

### 9.2 `wp:inline` — תכונות וילדים

| אלמנט/תכונה | מה עושה |
|---|---|
| `@distT/@distB/@distL/@distR` | מרווח מהטקסט (EMU) |
| `wp:extent` | `cx`,`cy` — גודל התצוגה ב‑**EMU** |
| `wp:effectExtent` | שוליים נוספים לאפקטים (צל וכו') |
| `wp:docPr` | `id`,`name`,`descr`,`title` — מטא/נגישות |
| `wp:cNvGraphicFramePr` | נעילות (locks) |
| `a:graphic` | המעטפת לתוכן הגרפי (ראו §9.4) |

### 9.3 `wp:anchor` — תמונה צפה

| תכונה | מה עושה |
|---|---|
| `@distT/B/L/R` | מרווח מהטקסט מסביב |
| `@simplePos` | אם 1 — השתמש ב‑`wp:simplePos` (x,y מוחלטים) |
| `@relativeHeight` | סדר Z (מי מעל מי) |
| `@behindDoc` | 1=מאחורי הטקסט (רקע/סימן מים), 0=לפניו |
| `@locked`,`@layoutInCell`,`@allowOverlap`,`@hidden` | נעילה / מותר בתוך תא / חפיפה / מוסתר |

**ילדים (סדר מחייב):**

| אלמנט | מה עושה |
|---|---|
| `wp:simplePos` | קואורדינטות מוחלטות (כש‑simplePos=1) |
| `wp:positionH` | מיקום אופקי: `@relativeFrom` (margin/page/column/character/leftMargin/rightMargin/insideMargin/outsideMargin) + `wp:posOffset` (EMU) **או** `wp:align` (left/center/right/inside/outside) |
| `wp:positionV` | מיקום אנכי: `@relativeFrom` (margin/page/paragraph/line/topMargin/bottomMargin/insideMargin/outsideMargin) + posOffset/align (top/center/bottom/inside/outside) |
| `wp:extent` | גודל (EMU) |
| `wp:effectExtent` | שוליי אפקט |
| **סוג עטיפה (אחד)** | ראו §9.5 |
| `wp:docPr`,`wp:cNvGraphicFramePr` | מטא/נעילות |
| `a:graphic` | התוכן |

### 9.4 `a:graphic` → תוכן (תמונה / צורה / קבוצה)

```xml
<a:graphic><a:graphicData uri="…/picture">
  <pic:pic>
    <pic:nvPicPr>…</pic:nvPicPr>
    <pic:blipFill>
      <a:blip r:embed="rId5"/>          <!-- מצביע ל-media דרך rels -->
      <a:srcRect l="0" t="0" r="0" b="0"/> <!-- חיתוך (crop) באלפיות אחוז -->
      <a:stretch><a:fillRect/></a:stretch>
    </pic:blipFill>
    <pic:spPr>
      <a:xfrm rot="0" flipH="0" flipV="0">  <!-- סיבוב (1/60000 מעלה), היפוך -->
        <a:off x="0" y="0"/><a:ext cx="…" cy="…"/>
      </a:xfrm>
      <a:prstGeom prst="rect"/>          <!-- גאומטריה: rect/roundRect/ellipse/… -->
      <a:ln>…</a:ln>                     <!-- מסגרת -->
    </pic:spPr>
  </pic:pic>
</a:graphicData></a:graphic>
```

| `@uri` של graphicData | התוכן |
|---|---|
| `…/picture` | תמונה (`pic:pic`) |
| `…/wordprocessingShape` | צורה/תיבת טקסט (`wps:wsp`) |
| `…/wordprocessingGroup` | קבוצת צורות (`wpg:wgp`) |
| `…/chart` | תרשים (חלק chart נפרד) |
| `…/diagram` | SmartArt |
| `…/wordprocessingCanvas` | קנבס |

**רכיבי תמונה מרכזיים:**

| אלמנט | מה עושה |
|---|---|
| `a:blip @r:embed` | הפניה ל‑`word/media/*` דרך rels (התמונה עצמה) |
| `a:blip @r:link` | תמונה חיצונית מקושרת |
| `a:srcRect` | **חיתוך** — `l/t/r/b` באלפיות אחוז (50000=50%) |
| `a:stretch`/`a:tile` | מתיחה למלא או ריצוף |
| `a:xfrm @rot` | **סיבוב** ביחידות 1/60000 מעלה |
| `a:xfrm @flipH/@flipV` | היפוך אופקי/אנכי |
| `a:prstGeom @prst` | צורת מסגרת (rect, roundRect, ellipse, triangle, … מאות ערכים) |
| `a:custGeom` | גאומטריה מותאמת (path) |
| `a:ln` | קו מתאר (עובי `w` ב‑EMU, צבע, dash, פינות) |
| `a:solidFill`/`a:gradFill`/`a:blipFill`/`a:pattFill`/`a:noFill` | מילוי |
| אפקטים `a:effectLst` | צל (`a:outerShdw`), זוהר, השתקפות, רכות |
| `a:alphaModFix` | שקיפות התמונה |

### 9.5 סוגי עטיפת טקסט (wrap) — סביב anchor

| אלמנט | מה עושה |
|---|---|
| `wp:wrapNone` | אין עטיפה — התמונה מעל/מתחת לטקסט (משולב עם behindDoc) |
| `wp:wrapSquare` | הטקסט עוטף בריבוע סביב התיבה. `@wrapText` (bothSides/left/right/largest) |
| `wp:wrapTight` | עטיפה צמודה למתאר (`wp:wrapPolygon`) |
| `wp:wrapThrough` | כמו tight אבל ממלא גם "חורים" פנימיים |
| `wp:wrapTopAndBottom` | הטקסט מעל ומתחת בלבד, לא בצדדים |

> `@wrapText` ו‑`wrapPolygon` חיוניים לעטיפה 1:1. `bothSides`/`largest` קובעים מאיזה צד הטקסט זורם — חשוב מאוד ב‑RTL.

### 9.6 צורות ותיבות טקסט — `wps:wsp`

```xml
<wps:wsp>
  <wps:spPr>…a:prstGeom, מילוי, קו, a:xfrm…</wps:spPr>
  <wps:style>…הפניות theme לצורה…</wps:style>
  <wps:txbx><w:txbxContent>… פסקאות Word רגילות …</w:txbxContent></wps:txbx>
  <wps:bodyPr anchor="ctr" lIns="…" tIns="…" wrap="square" …/>
</wps:wsp>
```

- **תיבת טקסט** = צורה עם `wps:txbx` שבתוכה `w:txbxContent` עם פסקאות/טבלאות רגילות. מנוע צריך לרנדר אותן בתוך הצורה, עם שוליים פנימיים (`bodyPr lIns/tIns/rIns/bIns`), יישור אנכי (`anchor`=t/ctr/b), וכיוון.
- צורה ללא txbx = צורה גרפית בלבד (מלבן/חץ/וכו') לפי `prstGeom`.

### 9.7 VML (`w:pict`) — fallback ותוכן ישן

```xml
<w:r><w:pict>
  <v:shape style="position:absolute;width:200pt;height:100pt" type="#_x0000_t202">
    <v:textbox><w:txbxContent>…</w:txbxContent></v:textbox>
    <v:fill color="#ffffff"/><v:stroke color="#000000"/>
  </v:shape>
</w:pict></w:r>
```

- VML משמש ל: **סימני מים** (`v:shape` עם `v:textpath`), תיבות טקסט ישנות, ו‑`mc:Fallback` של DrawingML.
- `style` הוא CSS‑like (position, width, height, margin, z-index, rotation, mso-position-*).
- `v:imagedata @r:id` = תמונה ב‑VML.
- מנוע מודרני: אם יש `mc:AlternateContent` — לקרוא את ה‑Choice (DrawingML); ליפול ל‑VML רק כשאין Choice נתמך, או למסמכים ישנים.

### 9.8 תרשימים, SmartArt, OLE

| תוכן | איפה | טיפול במנוע תצוגה |
|---|---|---|
| תרשים (chart) | חלק `word/charts/chartN.xml` (DrawingML chart) | רינדור מלא מורכב; מינימום — להציג כתמונת fallback אם קיימת |
| SmartArt (diagram) | `word/diagrams/*` | לרוב יש `dsp`/תמונת fallback |
| OLE object | `w:object`→`o:OLEObject` + תמונת תצוגה (`v:imagedata`/EMF) | להציג את תמונת התצוגה |

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

### ב.1 — סריקה פר‑פריט

> **מקרא קיצורי נתיב** (כדי לקצר את עמודת "קובץ/שורה"):
> - **reader** = `packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart` (פירוק `w:drawing`/`w:pict`).
> - **img-ast** = `packages/docx_creator/lib/src/ast/docx_image.dart` ; **draw-ast** = `…/ast/docx_drawing.dart` (מודלי AST).
> - **image_builder** / **shape_builder** = `packages/docx_file_viewer/lib/src/widget_generator/…` (רינדור תמונה/צורה).
> - **float_layout** = `packages/docx_file_viewer/lib/src/layout/float_layout.dart` (גאומטריית צף + עטיפה).
> - **span_factory** = `…/layout/span_factory.dart` ; **generator** = `…/widget_generator/docx_widget_generator.dart` ; **paginator** = `…/pagination/paginator.dart`.

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `wp:inline` מול `wp:anchor` (זרימה מול צף) | כן | כן | inline = "תו ענק" בתוך השורה; anchor = צף מחוץ לזרימה. המנוע מבחין ומנתב נכון. | reader:503,707-710; span_factory:543-560 |
| 2 | `wp:inline` — `distT/B/L/R` | לא (לאינליין) | רוב‑המקרים לא רלוונטי | ב‑Word, לתמונת inline distL/R כמעט תמיד מתעלם ו‑distT/B מוסיף רווח אנכי קטן. הקורא קורא dist רק בענף ה‑anchor; ענף ה‑inline מתעלם. | reader:555-564 (anchor בלבד); ענף inline reader:780-793 |
| 3 | `wp:inline` — `wp:extent` (cx/cy ב‑EMU) | כן | כן | EMU→pt (÷914400×72) → גודל התצוגה. | reader:520-526 |
| 4 | `wp:inline` — `wp:effectExtent` | חלקי (round‑trip) | לא | שוליים נוספים לאפקטים (צל) שמרחיבים את תיבת העטיפה. נקרא רק ל‑anchor ונשמר; **לא** נכנס לחישוב ה‑exclusion (העטיפה משתמשת ב‑dist* בלבד). | reader:574-587; float_layout:154-158 |
| 5 | `wp:inline` — `wp:docPr` (id/name/descr/title) | חלקי | — | `descr`/`name` נקראים כ‑altText (בענף anchor בלבד), אך **לא מוצגים** (אין alt/tooltip/נגישות). `title` לא נקרא. | reader:694-700 |
| 6 | `wp:inline` — `wp:cNvGraphicFramePr` (locks) | לא | לא רלוונטי | נעילות עריכה — אין השפעת תצוגה. | — |
| 7 | `wp:anchor` — `distT/B/L/R` | כן | כן | מרווח עטיפה סביב הצף; הופך ל‑marginL/R/T/B של תיבת ההוצאה (exclusion). | reader:555-564; float_layout:216-219,154-158 |
| 8 | `wp:anchor` — `simplePos` + `wp:simplePos` | חלקי | לא | `simplePos` נקרא כ‑bool, אך `wp:simplePos` (x,y מוחלטים) לא נקרא ו‑`resolveFloatRect` תמיד משתמש ב‑positionH/V. אם simplePos=1 → מיקום שגוי (נדיר). | reader:565; float_layout:249 |
| 9 | `wp:anchor` — `relativeHeight` (סדר Z) | חלקי | חלקי | נקרא לתמונה→zOrder, ושכבות‑הצף ממוינות לפי zOrder לפני הציור. אבל **לצורה zOrder מקובע 0**, וסדר Z מול גוף הטקסט אינו ממודל (side‑floats זורמים inline). | reader:566; float_layout:221,240; generator:1024-1025 |
| 10 | `wp:anchor` — `behindDoc` (מאחורי/לפני טקסט) | כן (תמונות) / לא (צורות) | חלקי | תמונת behindDoc → שכבת רקע‑עמוד, כך שהטקסט מעליה. אבל **צורה** behindDocument אינה נאספת (`_collectBehindTextImages` רק `DocxInlineImage`) וגם לא נכנסת ל‑layerFloats → **לא מרונדרת כלל**. | reader:688-691; generator:817-830,753-758 |
| 11 | `wp:anchor` — `locked`/`layoutInCell`/`allowOverlap`/`hidden` | חלקי | לא | שלושת הראשונים נקראים round‑trip בלבד; `allowOverlap` לא נאכף (אין פתרון חפיפה), **`hidden` כלל לא נקרא** (צף מוסתר עדיין יוצג). | reader:569-571 |
| 12 | `wp:positionH` — `relativeFrom` + posOffset/align | כן | חלקי | page/leftMargin/rightMargin/margin/column ממומשים; `character` מקורב לעמודת הגוף. align L/C/R/inside/outside (RTL נפתר). | reader:607-637; float_layout:259-281 |
| 13 | `wp:positionV` — `relativeFrom` + posOffset/align | כן | חלקי | page/topMargin/margin/bottomMargin/paragraph; `line` מקורב ל‑top של הפסקה. align top/center/bottom/inside/outside. | reader:639-669; float_layout:284-309 |
| 14 | `a:graphicData @uri` (picture/shape/group/chart/diagram/canvas) | חלקי | — | מזוהים **picture** (blip) ו‑**shape** (wsp) בלבד. `group` (wpg) לא מטופל — `findAllElements('a:blip')` יתפוס את התמונה הראשונה ויאבד את הקיבוץ/המיקומים. chart/diagram/canvas → fallback `DocxRawInline` (לא מוצג). | reader:505-507,800-806 |
| 15 | `a:blip @r:embed` (תמונה מ‑media) | כן | כן | rel→`word/media/*`, קריאת bytes מהארכיב. | reader:506-517 |
| 16 | `a:blip @r:link` (תמונה חיצונית) | לא | לא | נקרא רק `r:embed`/`r:id`, לא `r:link` → תמונה חיצונית מקושרת אינה מוצגת. | reader:509 |
| 17 | `a:srcRect` (crop — l/t/r/b באלפיות אחוז) | כן | כן | fraction = val/100000; רינדור ע"י הגדלת התמונה + `ClipRect`/`OverflowBox` כך שהחלון הגלוי = תיבת התצוגה. | reader:1022-1031; image_builder:79-110 |
| 18 | `a:stretch` / `a:tile` | חלקי | חלקי | `stretch` הוא ההתנהגות בפועל (התמונה ממלאת את התיבה). `tile` (ריצוף) לא נתמך → מוצג כתמונה מתוחה אחת. | image_builder:116-132 |
| 19 | `a:xfrm @rot` (סיבוב 1/60000 מעלה) | כן | חלקי | סיבוב 1/60000°→deg, `Transform.rotate`. **מגבלה:** תיבת ה‑float משתמשת ב‑extent הלא‑מסובב, לכן ה‑bounding box של צף מסובב (≠180°) אינו מדויק. | reader:1014-1015; image_builder:66-71; generator:793-797 |
| 20 | `a:xfrm @flipH/@flipV` | כן | כן | היפוך אופקי/אנכי. בצורה — מהופכת הגאומטריה ולא הטקסט (כמו Word). | reader:1016-1019; image_builder:55-65; shape_builder:84-92 |
| 21 | `a:prstGeom @prst` (rect/roundRect/ellipse/…) | צורות: כן / תמונות: לא | חלקי | **צורה:** preset נקרא ומרונדר (rect/roundRect/ellipse דרך BoxDecoration; ~30 מצולעים/חצים/כוכבים דרך Path). **תמונה:** prstGeom לא נקרא — מסגרת תמונה לא‑מלבנית (אליפסה/roundRect) מוצגת כמלבן. | reader:829-841; shape_builder:56-82,288-373 |
| 22 | `a:custGeom` (path) | לא | לא | גאומטריה מותאמת לא נקראת → הצורה נופלת ל‑rect (ברירת מחדל). | reader:829 |
| 23 | `a:ln` (מתאר — w/צבע/dash/פינות) | צורות: חלקי / תמונות: לא | חלקי | **צורה:** `w`+`solidFill` נקראים ומרונדרים כ‑border; **`dash` (`a:prstDash`) לא נקרא → תמיד רציף**; פינות לא מטופלות. **תמונה:** `a:ln` כלל לא נקרא → אין מסגרת לתמונה. | reader:858-872; shape_builder:126-129 |
| 24 | מילויים: `a:solidFill`/`gradFill`/`blipFill`/`pattFill`/`noFill` | חלקי | חלקי | צורה: `solidFill`+`gradFill` נקראים ומרונדרים. `blipFill` (צורה ממולאת תמונה) ו‑`pattFill` לא נתמכים. **`noFill` → fillColor=null אך הרינדר ממלא אפור (`Colors.grey.shade200`) במקום שקוף — באג נאמנות.** | reader:846-856; shape_builder:124,147 |
| 25 | `a:effectLst` (outerShdw/glow/reflection/soft) | לא | לא | לא נקרא ולא מרונדר (אין צל/זוהר/השתקפות). | — |
| 26 | `a:alphaModFix` (שקיפות) | לא | לא | שקיפות התמונה לא מיושמת (התמונה מצוירת אטומה). | — |
| 27 | `wp:wrapNone` | כן | חלקי | → `textWrap.none` → שכבת‑צף קדמית (מעל הטקסט, ללא עטיפה). | reader:673-674; float_layout:86-90; generator:753-758 |
| 28 | `wp:wrapSquare` (+`@wrapText`: bothSides/left/right/largest) | square: כן / `@wrapText`: לא | חלקי | עטיפת ריבוע ממומשת כ‑side‑band, אך **`@wrapText` לא נקרא** — הצד שאליו זורם הטקסט נקבע מ‑`hAlign` בלבד, לא מ‑bothSides/left/right/largest. | reader:675-676; float_layout:105-116 |
| 29 | `wp:wrapTight` (+`wrapPolygon`) | חלקי | לא | מקורב ל‑square; `wrapPolygon` לא נקרא → אין עטיפה צמודה למתאר. | reader:677-678; float_layout:80-85 |
| 30 | `wp:wrapThrough` | חלקי | לא | מקורב ל‑square; "חורים" פנימיים לא ממולאים בטקסט. | reader:679-680; float_layout:80-85 |
| 31 | `wp:wrapTopAndBottom` | כן | כן | → `fullWidth`; ה‑paginator שומר פס אנכי, אין טקסט בצדדים. | reader:681-685; float_layout:85; paginator:995-998 |
| 32 | זרימת טקסט נכונה ב‑RTL (bothSides/largest) | חלקי | חלקי | `inside`/`outside` נפתרים לפי `pageIsRtl`; float באמצע העמודה שומר את הצד הרחב. אבל בחירת צד לפי `@wrapText` (bothSides/largest) חסרה (פריט 28). | float_layout:105-116,357-370 |
| 33 | `wps:wsp` — `spPr` (prstGeom/מילוי/קו/xfrm) | חלקי | חלקי | ליבה ממומשת (ראו 21/23/24/19/20); חסרים: dash, blip/patt fill, effects, custGeom. | reader:809-947 |
| 34 | `wps:wsp` — `style` (הפניות theme) | לא | לא | `fillRef`/`lnRef`/`effectRef`/`fontRef` של הצורה לא נקראים — צורה שצבעה מגיע **רק** מ‑style מוצגת באפור ברירת מחדל. ראו משימה 13 (theme). | — |
| 35 | `wps:txbx` → `w:txbxContent` (פסקאות בתוך צורה) | כן | כן | תוכן הבלוקים נפרס מחדש (`BlockParser`) ומרונדר בתוך הצורה דרך `textBlockBuilder` — שומר עיצוב פסקאות/ריצות אמיתי. | reader:874-895; shape_builder:195-208; generator:184-191 |
| 36 | `wps:bodyPr` (lIns/tIns/rIns/bIns/anchor/wrap/כיוון) | לא | חלקי | לא נקרא: שוליים פנימיים מקובעים `EdgeInsets.all(4)`; יישור אנכי (t/ctr/b) מתעלם (תמיד עליון, `ClipRect`+top); כיוון טקסט (vert) מתעלם. | shape_builder:195-208 |
| 37 | צורה גרפית ללא txbx (prstGeom) | כן | חלקי | מרונדרת הגאומטריה (בכפוף לכיסוי ה‑presets; preset לא נתמך → תיבה מעוגלת גלויה). | shape_builder:73-82 |
| 38 | VML `v:shape` (style CSS‑like, type) | חלקי | חלקי | רק `v:shape` שעוטף `v:imagedata` (תמונה/סימן‑מים) מטופל: גודל מ‑`style`, מיקום מ‑`mso-position-*`/`z-index`/`margin-*`. `v:shape` כצורה גאומטרית (v:rect/roundrect עם fill/stroke) לא מרונדר כצורה. | reader:1133-1165,1197-1274 |
| 39 | VML `v:textbox` → `w:txbxContent` | לא | לא | `w:pict` עם `v:textbox` (ללא imagedata/wsp) → fallback `DocxRawInline`; תיבת טקסט VML אינה מוצגת. | reader:800-806 |
| 40 | VML `v:fill` / `v:stroke` | לא | לא | לא נקראים (נתיב התמונה ב‑VML מתעלם מהם). | — |
| 41 | VML `v:imagedata @r:id` | כן | כן | bytes (`r:id`) + גודל (מ‑CSS `style`, ויחס‑ממדים מהותי אם חסר ממד) + מיקום (CSS). | reader:507-509,749-776,1133-1165 |
| 42 | בחירת Choice (DrawingML) מול Fallback (VML) ב‑`mc:AlternateContent` | כן | כן | מעדיף `mc:Choice`, נופל ל‑`mc:Fallback`; התאמה לפי local‑name (תומך גם prefix שונה). | reader:181-191 |
| 43 | תרשים (chart) — fallback תמונה | לא | לא | drawing של chart אין בו blip/wsp → `DocxRawInline`; אין הצגת תמונת fallback. | reader:800-806 |
| 44 | SmartArt (diagram) — dsp/fallback | לא | לא | `uri=…/diagram` לא מטופל; `dsp`/תמונת fallback לא נקראים → לא מוצג. | reader:800-806 |
| 45 | OLE (`w:object`→`o:OLEObject` + תמונת תצוגה) | לא | לא | `w:object` אינו `w:drawing`/`w:pict` ולכן לא מזוהה ב‑`parseRun` → `DocxRawInline`; תמונת התצוגה לא מוצגת. | reader:323-328 |

### ב.2 — פערים והוראות ל‑AI הבא

> סיכום מתועדף — מהמשפיע ביותר על מה שהמשתמש רואה אל הפינוי. כל פריט שאינו ממומש = "סטייה מודעת".

**קריטי / ויזואלי ברור:**

- **`noFill` בצורה מוצג כאפור (פריט 24).** צורה ללא מילוי (`a:noFill`) צריכה להיות **שקופה** ב‑Word; כאן `_decorated`/`_painted` נופלים ל‑`Colors.grey.shade200` כי `fillColor==null`. זה צובע מלבני‑רקע אפורים סביב טקסט/חצים שאמורים להיות שקופים. **המלצה:** להבחין בין "אין צבע ידוע" (ברירת מחדל) לבין `noFill` מפורש — לפרס דגל `noFill` ב‑reader (`spPr.findElements('a:noFill')`) ולהעביר ל‑shape_builder כך ש‑fill=transparent. (`shape_builder.dart:124,147`)
- **צורת `behindDoc` לא מרונדרת כלל (פריט 10).** `_collectBehindTextImages` אוסף רק `DocxInlineImage`, ו‑`_isLayerFloat` מחזיר false ל‑behindText → צורה מאחורי הטקסט נעלמת. **המלצה:** להכליל `DocxShape` באיסוף שכבת‑הרקע, או למפות behindText‑shape ל‑layerFloat שמצויר *מתחת* לגוף. (`docx_widget_generator.dart:817-830,753-758`)
- **`@wrapText` ו‑`wrapPolygon` חסרים → עטיפה ו‑RTL לא נאמנים (פריטים 28-30, 32).** הצד שאליו זורם הטקסט נקבע מ‑hAlign בלבד; `bothSides`/`left`/`right`/`largest` לא נקראים, ו‑tight/through מקורבים ל‑square. ב‑RTL זה קובע מאיזה צד נשאר טקסט — חשוב מאוד. **המלצה:** לקרוא `wp:wrapSquare/@wrapText` ולגזור ממנו `SideBand`; לקרוא `wrapPolygon` עבור tight/through (לפחות bounding‑box צמוד). (`reader inline_parser.dart:675-685`; `float_layout.dart:105-116`)
- **chart / SmartArt / OLE — אובדן תוכן מוחלט (פריטים 43-45, וגם group פריט 14).** drawing של תרשים/דיאגרמה/OLE אין בו blip/wsp → `DocxRawInline` (לא מצויר, ללא placeholder). **המלצה:** מינימום — לאתר תמונת fallback (`mc:Fallback` / `v:imagedata` של ה‑OLE / `pic` בתוך הקבוצה) ולהציגה; אם אין — placeholder גלוי בגודל ה‑extent במקום היעלמות שקטה. עבור `group` (wpg) — לפחות לצייר את כל ה‑`pic`/`wsp` שבתוכו לפי ה‑offset שלהם.
- **מתאר/מסגרת תמונה לא נקראים (פריטים 21+23 לתמונות).** `a:ln` ו‑`prstGeom` של `pic:spPr` מתעלמים → תמונה עם מסגרת או צורת‑חיתוך עגולה מוצגת כמלבן ללא קו. ה‑AST כבר תומך ב‑`DocxInlineImage.border`, אך ה‑reader לא ממלא אותו. **המלצה:** לקרוא `a:ln` בתוך `pic:spPr` ולמלא `border`; לקרוא `prstGeom@prst` לתמונה ולהחיל `ClipPath`/`BorderRadius` בהתאם.

**בינוני:**

- **`dash` במתאר צורה (פריט 23).** `a:prstDash` לא נקרא → מתאר תמיד רציף (dashed/dotted נעלמים). תואם לפער שתועד בטבלאות (משימה 06). **המלצה:** לקרוא `a:prstDash@val` ולצייר עם `PathDashPathEffect`/קו מקווקו ב‑`_ShapePainter`.
- **`wps:bodyPr` — שוליים פנימיים ויישור אנכי (פריט 36).** מקובע `padding:4` ויישור עליון; תיבת טקסט עם `anchor=ctr/b` או `lIns/tIns` מותאמים אינה נאמנה. **המלצה:** לפרס `bodyPr` ולהעביר ל‑shape_builder כ‑padding+alignment.
- **`wps:style` (הפניות theme לצורה, פריט 34).** צורה שצבעה מ‑`fillRef`/`lnRef` מוצגת אפורה. תלוי במשימה 13 (theme). **המלצה:** לפתור `schemeClr` דרך ה‑theme (כבר קיים `_ooxmlColor`/`_schemeToken`) גם עבור ה‑refs.
- **`relativeHeight` לצורות + סדר Z מול טקסט (פריט 9).** zOrder של צורה מקובע 0; שתי צורות צפות חופפות לא ימוינו נכון. **המלצה:** להעביר `relativeHeight` גם ל‑`DocxShape` (כיום אין שדה כזה ב‑AST).
- **`a:effectLst` (צל/זוהר) ו‑`a:alphaModFix` (שקיפות) — פריטים 25, 26.** לא ממומשים. צל הוא ההבדל הוויזואלי השכיח ביותר. **המלצה:** לפחות `outerShdw` → `BoxShadow`, ו‑`alphaModFix` → `Opacity`/`colorFilter`.

**נמוך / נדיר:**

- **`simplePos`/`wp:simplePos` (8), `hidden`/`allowOverlap` (11), `effectExtent` בעטיפה (4)** — קצוות נדירים; לתעד כסטייה מודעת.
- **`r:link` (תמונה חיצונית, 16)** — דורש משיכת קובץ חיצוני; לרוב לא רלוונטי בצפייה מקומית.
- **`a:tile` (18)** ו‑**`blipFill`/`pattFill` בצורה (24)** — נדירים במסמכי טקסט.
- **VML כצורה גאומטרית / `v:textbox` / `v:fill`+`v:stroke` (38-40)** — VML מודרני מגיע כמעט תמיד דרך `mc:Fallback` של DrawingML (שכבר נבחר ה‑Choice עליו), כך שהמסלול הזה רלוונטי בעיקר למסמכים ישנים; לתעד כסטייה מודעת.
- **`docPr@descr/title` (5)** — לא ויזואלי; רלוונטי רק אם תתווסף נגישות/alt‑text.
- **`cNvGraphicFramePr` locks (6)** — אין השפעת תצוגה.
