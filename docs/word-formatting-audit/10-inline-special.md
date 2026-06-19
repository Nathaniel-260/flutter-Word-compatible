# משימה 10 — תוכן inline מיוחד: שבירות, טאבים, סמלים, שדות, קישורים, סימניות, הערות, נוסחאות

> **מקור:** סעיף §10 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

ילדי `w:r` שאינם `w:t` (טקסט), וכן אלמנטים ברמת הפסקה.

### 10.1 תוכן טקסטואלי וסימני שבירה (בתוך `w:r`)

| אלמנט | XML | מה עושה | קצה |
|---|---|---|---|
| `w:t` | `<w:t xml:space="preserve"> טקסט </w:t>` | טקסט ממש | `xml:space="preserve"` חיוני לשמירת רווחים מובילים/עוקבים |
| `w:br` | `<w:br w:type="page"/>` | שבירה: `page` (עמוד), `column` (טור), `textWrapping` (שורה רכה). `@w:clear`=none/left/right/all (היכן להמשיך אחרי עטיפה) | `textWrapping`=Shift+Enter |
| `w:cr` | `<w:cr/>` | מעבר שורה (כמו br textWrapping) | |
| `w:tab` | `<w:tab/>` | תו טאב — קופץ לנקודת הטאב הבאה (§4.5) | |
| `w:noBreakHyphen` | | מקף שלא שובר שורה | |
| `w:softHyphen` | | מקף רך (נקודת מיקוף אופציונלית) | |
| `w:sym` | `<w:sym w:font="Wingdings" w:char="F0E0"/>` | סמל מפונט ספציפי לפי קוד hex | חיוני — לא טקסט רגיל |
| `w:drawing` / `w:pict` / `w:object` | §9 | גרפיקה | |
| `w:ptab` | `@alignment`,`@relativeTo`,`@leader` | טאב מיקום מוחלט (absolute position tab) | |
| `w:lastRenderedPageBreak` | | רמז של Word היכן נשבר עמוד ברינדור הקודם | **לא מחייב** — מנוע מחשב מחדש |

### 10.2 שדות (Fields)

שתי צורות:

**א. שדה פשוט:**
```xml
<w:fldSimple w:instr=" PAGE \* MERGEFORMAT "><w:r><w:t>5</w:t></w:r></w:fldSimple>
```

**ב. שדה מורכב (3 חלקים):**
```xml
<w:r><w:fldChar w:fldCharType="begin"/></w:r>
<w:r><w:instrText xml:space="preserve"> PAGEREF _Toc123 \h </w:instrText></w:r>
<w:r><w:fldChar w:fldCharType="separate"/></w:r>
<w:r><w:t>טקסט תוצאה מאוחסן</w:t></w:r>          <!-- ה-cache; מה שמוצג -->
<w:r><w:fldChar w:fldCharType="end"/></w:r>
```

| חלק | מה עושה |
|---|---|
| `w:fldChar @fldCharType` | `begin` / `separate` (בין קוד לתוצאה) / `end`. `@w:fldLock`,`@w:dirty` |
| `w:instrText` | **קוד השדה** (string) |
| התוכן בין separate ל‑end | תוצאת השדה השמורה (fallback אם לא מחושב מחדש) |

**קודי שדה נפוצים לרינדור:**

| קוד | מה מציג |
|---|---|
| `PAGE` | מספר העמוד הנוכחי (לפי `pgNumType/@fmt`) |
| `NUMPAGES` | סה"כ עמודים |
| `SECTIONPAGES` | עמודים במקטע |
| `PAGEREF bookmark` | מספר העמוד של סימנייה (`\h`=היפר‑קישור) |
| `REF bookmark` | תוכן הסימנייה |
| `STYLEREF "Heading 1"` | טקסט הכותרת הקרובה מסגנון נתון (כותרות רצות) |
| `SEQ name` | מונה רציף (Figure 1, Table 2…) |
| `TOC \o "1-3"` | תוכן עניינים |
| `DATE`/`TIME`/`CREATEDATE` | תאריך/שעה |
| `HYPERLINK "url"` | קישור (לרוב עטוף ב‑`w:hyperlink`) |
| `TC`,`XE`,`INDEX` | רשומות תוכן/אינדקס |
| `=formula` | חישוב (בעיקר בטבלאות) |

> `\* MERGEFORMAT` = שמור עיצוב; `\* Arabic`/`\* roman` = פורמט; `\# "0.00"` = פורמט מספרי; `\@ "dd/MM/yyyy"` = פורמט תאריך. מנוע 1:1 מפענח את ה‑switches.

### 10.3 קישורים — `w:hyperlink`

```xml
<w:hyperlink r:id="rId8" w:anchor="section2" w:tooltip="…" w:history="1">
  <w:r><w:rPr><w:rStyle w:val="Hyperlink"/></w:rPr><w:t>לחץ כאן</w:t></w:r>
</w:hyperlink>
```

| תכונה | מה עושה |
|---|---|
| `@r:id` | יעד חיצוני (URL) דרך rels |
| `@w:anchor` | יעד פנימי (שם סימנייה) |
| `@w:tooltip` | טקסט ריחוף |
| `@w:docLocation`,`@w:history` | מיקום/היסטוריה |

> העיצוב הכחול‑קו‑תחתון בא מסגנון התו `Hyperlink` (לא אוטומטי) — חייב להחיל אותו.

### 10.4 סימניות — `w:bookmarkStart` / `w:bookmarkEnd`

```xml
<w:bookmarkStart w:id="0" w:name="_Toc123"/> … <w:bookmarkEnd w:id="0"/>
```

- `@w:id` מקשר start ל‑end (יכולים להיות במרחק/חופפים). `@w:name`=שם הסימנייה (יעד ל‑PAGEREF/REF/anchor).
- לא ויזואליות בעצמן, אך **חיוניות לשדות** ולניווט. מנוע צריך למפות name→מיקום (עמוד) לצורך PAGEREF.

### 10.5 הערות שוליים וסיום

```xml
<!-- בגוף: -->
<w:r><w:rPr><w:rStyle w:val="FootnoteReference"/></w:rPr>
     <w:footnoteReference w:id="1"/></w:r>
<!-- ב-footnotes.xml: -->
<w:footnote w:id="1"><w:p>…תוכן ההערה…</w:p></w:footnote>
```

| אלמנט | מה עושה |
|---|---|
| `w:footnoteReference @w:id` | סימן ההפניה בגוף (מקבל סגנון `FootnoteReference` — superscript) |
| `w:endnoteReference @w:id` | אותו דבר להערת סיום |
| `w:footnote`/`w:endnote @w:type` | `normal` / `separator` (הקו המפריד) / `continuationSeparator` / `continuationNotice` |
| מאפיינים ב‑settings/sectPr | `pos` (תחתית עמוד/מתחת לטקסט), `numFmt`, `numStart`, `numRestart` |

> מנוע 1:1: הערת שוליים מופיעה **בתחתית העמוד** שבו מופיע הסימן — מחייב שילוב בעימוד (לשריין מקום בתחתית העמוד).

### 10.6 הערות סוקר — `w:comment`

| אלמנט | מה עושה |
|---|---|
| `w:commentRangeStart/End @w:id` | טווח הטקסט שעליו ההערה |
| `w:commentReference @w:id` | סימן ההערה |
| `w:comment` (ב‑comments.xml) | `@w:author`,`@w:date`,`@w:initials` + תוכן |

> בתצוגת קריאה לרוב מציגים בגיליון צד/בלון או מתעלמים; לא משפיע על זרימת הטקסט הראשי.

### 10.7 רובי (פונטי) — `w:ruby`

טקסט הדרכה קטן מעל/ליד טקסט בסיס (נפוץ ב‑EA, קיים גם בהקשרים אחרים):
`w:ruby` → `w:rubyPr` (יישור, גודל, מיקום) + `w:rt` (טקסט הרובי) + `w:rubyBase` (טקסט הבסיס).

### 10.8 נוסחאות — OMML (`m:` namespace)

```xml
<m:oMathPara><m:oMath> … <m:f><m:num>…</m:num><m:den>…</m:den></m:f> … </m:oMath></m:oMathPara>
```

| אלמנט | מה |
|---|---|
| `m:oMathPara` | נוסחה כפסקה (display) |
| `m:oMath` | נוסחה inline |
| `m:f` (שבר), `m:sSup`/`m:sSub` (חזקה/אינדקס), `m:rad` (שורש), `m:nary` (סכום/אינטגרל), `m:d` (סוגריים), `m:func`, `m:m` (מטריצה), `m:r`+`m:t` (טקסט מתמטי) | אבני הבניין |

> רינדור נוסחאות מלא = מנוע נפרד ומורכב. מינימום סביר: לרנדר את הטקסט הליניארי או תמונת fallback. לציין כסטייה מודעת אם לא ממומש מלא.

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:t` + `xml:space="preserve"` (שמירת רווחים) | | | | |
| 2 | `w:br` (page/column/textWrapping) + `@w:clear` | | | | |
| 3 | `w:cr` (מעבר שורה) | | | | |
| 4 | `w:tab` (קפיצה לנקודת טאב) | | | | |
| 5 | `w:noBreakHyphen` | | | | |
| 6 | `w:softHyphen` | | | | |
| 7 | `w:sym` (font + char hex — חיוני) | | | | |
| 8 | `w:ptab` (alignment/relativeTo/leader) | | | | |
| 9 | `w:lastRenderedPageBreak` (רמז — לא מחייב) | | | | |
| 10 | שדה פשוט `w:fldSimple @w:instr` | | | | |
| 11 | שדה מורכב `w:fldChar` (begin/separate/end + fldLock/dirty) | | | | |
| 12 | `w:instrText` (קוד שדה) | | | | |
| 13 | תוכן cache בין separate ל‑end | | | | |
| 14 | קוד `PAGE` | | | | |
| 15 | קוד `NUMPAGES` | | | | |
| 16 | קוד `SECTIONPAGES` | | | | |
| 17 | קוד `PAGEREF` (+`\h`) | | | | |
| 18 | קוד `REF` | | | | |
| 19 | קוד `STYLEREF` (כותרות רצות) | | | | |
| 20 | קוד `SEQ` | | | | |
| 21 | קוד `TOC` | | | | |
| 22 | קודים `DATE`/`TIME`/`CREATEDATE` | | | | |
| 23 | קוד `HYPERLINK` | | | | |
| 24 | קודים `TC`/`XE`/`INDEX` | | | | |
| 25 | קוד `=formula` | | | | |
| 26 | פענוח switches (`\*`/`\#`/`\@`/`MERGEFORMAT`) | | | | |
| 27 | `w:hyperlink @r:id` (URL חיצוני) | | | | |
| 28 | `w:hyperlink @w:anchor` (יעד פנימי) | | | | |
| 29 | `w:hyperlink @w:tooltip` | | | | |
| 30 | `w:hyperlink @w:docLocation`/`@w:history` | | | | |
| 31 | החלת סגנון תו `Hyperlink` (כחול+קו תחתון) | | | | |
| 32 | `w:bookmarkStart`/`w:bookmarkEnd` (@id/@name) | | | | |
| 33 | מיפוי name→עמוד עבור PAGEREF | | | | |
| 34 | `w:footnoteReference @w:id` (+סגנון FootnoteReference superscript) | | | | |
| 35 | `w:endnoteReference @w:id` | | | | |
| 36 | `w:footnote`/`w:endnote @w:type` (normal/separator/continuationSeparator/continuationNotice) | | | | |
| 37 | מאפייני הערות (pos/numFmt/numStart/numRestart) | | | | |
| 38 | הצגת הערת שוליים **בתחתית העמוד** (שילוב בעימוד) | | | | |
| 39 | `w:commentRangeStart/End @w:id` | | | | |
| 40 | `w:commentReference @w:id` | | | | |
| 41 | `w:comment` (author/date/initials + תוכן) | | | | |
| 42 | `w:ruby` (rubyPr/rt/rubyBase) | | | | |
| 43 | `m:oMathPara` (נוסחה display) | | | | |
| 44 | `m:oMath` (נוסחה inline) | | | | |
| 45 | אבני בניין OMML (m:f/sSup/sSub/rad/nary/d/func/m/r+t) | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
