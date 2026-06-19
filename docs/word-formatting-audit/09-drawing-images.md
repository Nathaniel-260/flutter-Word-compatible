# משימה 09 — ציור, תמונות, צורות, תיבות טקסט — DrawingML / VML

> **מקור:** סעיף §9 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —

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

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `wp:inline` מול `wp:anchor` (זרימה מול צף) | | | | |
| 2 | `wp:inline` — `distT/B/L/R` | | | | |
| 3 | `wp:inline` — `wp:extent` (cx/cy ב‑EMU) | | | | |
| 4 | `wp:inline` — `wp:effectExtent` | | | | |
| 5 | `wp:inline` — `wp:docPr` (id/name/descr/title) | | | | |
| 6 | `wp:inline` — `wp:cNvGraphicFramePr` (locks) | | | | |
| 7 | `wp:anchor` — `distT/B/L/R` | | | | |
| 8 | `wp:anchor` — `simplePos` + `wp:simplePos` | | | | |
| 9 | `wp:anchor` — `relativeHeight` (סדר Z) | | | | |
| 10 | `wp:anchor` — `behindDoc` (מאחורי/לפני טקסט) | | | | |
| 11 | `wp:anchor` — `locked`/`layoutInCell`/`allowOverlap`/`hidden` | | | | |
| 12 | `wp:positionH` — `relativeFrom` + posOffset/align | | | | |
| 13 | `wp:positionV` — `relativeFrom` + posOffset/align | | | | |
| 14 | `a:graphicData @uri` (picture/shape/group/chart/diagram/canvas) | | | | |
| 15 | `a:blip @r:embed` (תמונה מ‑media) | | | | |
| 16 | `a:blip @r:link` (תמונה חיצונית) | | | | |
| 17 | `a:srcRect` (crop — l/t/r/b באלפיות אחוז) | | | | |
| 18 | `a:stretch` / `a:tile` | | | | |
| 19 | `a:xfrm @rot` (סיבוב 1/60000 מעלה) | | | | |
| 20 | `a:xfrm @flipH/@flipV` | | | | |
| 21 | `a:prstGeom @prst` (rect/roundRect/ellipse/…) | | | | |
| 22 | `a:custGeom` (path) | | | | |
| 23 | `a:ln` (מתאר — w/צבע/dash/פינות) | | | | |
| 24 | מילויים: `a:solidFill`/`gradFill`/`blipFill`/`pattFill`/`noFill` | | | | |
| 25 | `a:effectLst` (outerShdw/glow/reflection/soft) | | | | |
| 26 | `a:alphaModFix` (שקיפות) | | | | |
| 27 | `wp:wrapNone` | | | | |
| 28 | `wp:wrapSquare` (+`@wrapText`: bothSides/left/right/largest) | | | | |
| 29 | `wp:wrapTight` (+`wrapPolygon`) | | | | |
| 30 | `wp:wrapThrough` | | | | |
| 31 | `wp:wrapTopAndBottom` | | | | |
| 32 | זרימת טקסט נכונה ב‑RTL (bothSides/largest) | | | | |
| 33 | `wps:wsp` — `spPr` (prstGeom/מילוי/קו/xfrm) | | | | |
| 34 | `wps:wsp` — `style` (הפניות theme) | | | | |
| 35 | `wps:txbx` → `w:txbxContent` (פסקאות בתוך צורה) | | | | |
| 36 | `wps:bodyPr` (lIns/tIns/rIns/bIns/anchor/wrap/כיוון) | | | | |
| 37 | צורה גרפית ללא txbx (prstGeom) | | | | |
| 38 | VML `v:shape` (style CSS‑like, type) | | | | |
| 39 | VML `v:textbox` → `w:txbxContent` | | | | |
| 40 | VML `v:fill` / `v:stroke` | | | | |
| 41 | VML `v:imagedata @r:id` | | | | |
| 42 | בחירת Choice (DrawingML) מול Fallback (VML) ב‑`mc:AlternateContent` | | | | |
| 43 | תרשים (chart) — fallback תמונה | | | | |
| 44 | SmartArt (diagram) — dsp/fallback | | | | |
| 45 | OLE (`w:object`→`o:OLEObject` + תמונת תצוגה) | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
