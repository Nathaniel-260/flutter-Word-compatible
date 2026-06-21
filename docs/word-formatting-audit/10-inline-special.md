# משימה 10 — תוכן inline מיוחד: שבירות, טאבים, סמלים, שדות, קישורים, סימניות, הערות, נוסחאות

> **מקור:** סעיף §10 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-21

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

> **מפת המימוש (4 שכבות):**
> **(1) ניתוח inline** — `docx_creator/.../reader/docx_reader/parsers/inline_parser.dart`
> (`parseChildren` שורה 22 — שדות/קישורים/סימניות/מתמטיקה; `parseRun` שורה 275 — br/cr/מקפים/sym/ptab/tab/הערות).
> **(2) ניתוח שדה** — `field_instruction.dart` (`parse`/`parseHyperlink`/`tokenize`).
> **(3) מודלים** — `ast/docx_inline.dart` (DocxLineBreak/DocxTab/DocxSymbol/DocxPositionalTab),
> `ast/docx_section.dart` (DocxPageNumber/PageCount/PageRef/StyleRef/UnknownField/Bookmark),
> `ast/docx_footnote.dart` (DocxFootnoteRef/EndnoteRef/Footnote/Endnote).
> **(4) רינדור+עימוד** — `docx_file_viewer/lib/src/widget_generator/paragraph_builder.dart`
> (`buildInlineSpans` שורה 705), `layout/span_factory.dart` (`buildMeasurementSpans`/`symbolSpan`),
> `layout/symbol_map.dart`, `pagination/paginator.dart` (הערות/סימניות/מספור),
> `pagination/field_substitution.dart` (החלפת שדות חיה), `pagination/toc_expander.dart`.
> ⚠️ **שכבת הרינדור היא מקור האמת לנאמנות:** פריט יכול להיקרא למודל (חלק 1) ובכל זאת **לא להיות מרונדר**
> (למשל `w:ptab`) — לכן ההכרעה מתבססת על מה שמגיע למסך, לא רק על מה שנקרא.

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:t` + `xml:space="preserve"` (שמירת רווחים) | כן | נאמן | הטקסט נקרא דרך `textElem.innerText` **ללא trim** — רווחים מובילים/עוקבים נשמרים תמיד (חבילת `xml` מחזירה טקסט מילולית), כך ש‑`xml:space` מכובד בפועל גם בלי לקרוא את התכונה. בכתיבה מוסיפים `xml:space="preserve"` כשהשורה מתחילה/מסתיימת ברווח. | קריאה: `inline_parser.dart:378-379`; כתיבה: `docx_inline.dart:1106-1119` |
| 2 | `w:br` (page/column/textWrapping) + `@w:clear` | חלקי | חלקי | `type="page"`/`"column"` → `DocxLineBreak` עם דגלים; `textWrapping`/ברירת מחדל → break רך. **במצב מעומד (paged)** העימוד מפצל את הפסקה בנקודת השבירה → מעבר עמוד/טור אמיתי (נאמן). **במצב continuous** מעבר‑עמוד/טור מתנוון ל‑`\n` (אין מודל עמוד). **`@w:clear`** (היכן להמשיך אחרי עטיפה סביב ציור צף) **לא נקרא**. | `inline_parser.dart:278-285`; `paginator.dart:853-904`; render: `paragraph_builder.dart:734-736` |
| 3 | `w:cr` (מעבר שורה) | כן | נאמן | `getElement('w:cr')` → `DocxLineBreak` רגיל → `'\n'`. זהה ל‑br רך. **קצה:** ריצה שמערבבת טקסט+cr באותו `w:r` תאבד את הטקסט (הבדיקה מחזירה את ה‑break בלבד) — נדיר ב‑Word. | `inline_parser.dart:287-289` |
| 4 | `w:tab` (קפיצה לנקודת טאב) | חלקי | חלקי | עם **tabStops מפורשים** + שורת טקסט פשוטה → מנוע טאבים אמיתי (`TabEngine`/`TabbedLineRenderer`) עם יישור left/center/right/decimal + leaders. **בלי stops מפורשים → 4 רווחים קבועים** ('    ') בלבד — לא קפיצה לנקודת ברירת‑המחדל (defaultTabStop, כל 720tw). **קצה:** ריצה טקסט+tab באותו `w:r` תאבד את הטקסט (`findAllElements('w:tab')`). תלות ב‑defaultTabStop = משימה 04/14. | render: `paragraph_builder.dart:141,422-467,737-739`; measure: `span_factory.dart:517-520`; `inline_parser.dart:318-320` |
| 5 | `w:noBreakHyphen` | כן | נאמן | → `DocxText('‑')` (U+2011 non‑breaking hyphen). תו נכון, נשבר ומוצג כמקף שאינו שובר שורה. | `inline_parser.dart:291-293` |
| 6 | `w:softHyphen` | כן | נאמן~ | → `DocxText('­')` (U+00AD soft hyphen). התו נכון; האם מנוע השורות של Flutter מכבד אותו כהזדמנות‑שבירה תלוי‑מנוע (לא מובטח כמו ב‑Word) — קירוב. | `inline_parser.dart:294-296` |
| 7 | `w:sym` (font + char hex — חיוני) | כן | חלקי | `font`+`char` נקראים → `DocxSymbol`. ברינדור: `SymbolFontMap` ממפה גליפי **Wingdings 1** + **Adobe Symbol** (יווני/מתמטי) ל‑Unicode (מוצג בלי הפונט המקורי); גליף לא‑ממופה נשאר בפונט הסמלים עם fallback. מגבלות: טבלאות מצומצמות (Webdings, Wingdings 2/3 לא ממופים בכוונה); גליף לא‑ממופה תלוי בהתקנת פונט הסמלים. | `inline_parser.dart:298-305`; `symbol_map.dart`; `span_factory.dart:686-702` |
| 8 | `w:ptab` (alignment/relativeTo/leader) | חלקי | **לא** | **נקרא** ל‑`DocxPositionalTab` (alignment/relativeTo/leader) — אך **לא מרונדר כלל**: אין ל‑`DocxPositionalTab` ענף ב‑`buildInlineSpans`/`buildMeasurementSpans` → תורם רוחב אפס (הטאב המוחלט נעלם, גם בלי leader). פער. | קריאה: `inline_parser.dart:307-316`; (לא מרונדר — אין ב‑`paragraph_builder.dart`/`span_factory.dart`) |
| 9 | `w:lastRenderedPageBreak` (רמז — לא מחייב) | לא | n/a | לא נקרא כלל — וזה **נכון**: רמז עימוד בלבד; המנוע מחשב שבירות מחדש. אין פגיעה בנאמנות. | אין (מכוון) |
| 10 | שדה פשוט `w:fldSimple @w:instr` | כן | נאמן | `@w:instr` + התוכן הפנימי נפתרים דרך `_fieldNodes`: שדה מוכר → צומת שדה ייעודי, אחרת → `DocxUnknownField` עם ה‑cache. | `inline_parser.dart:132-139,217-235` |
| 11 | שדה מורכב `w:fldChar` (begin/separate/end + fldLock/dirty) | חלקי | נאמן~ | מכונת‑מצבים מלאה: begin/separate/end, עומק קינון (שדה בתוך תוצאת שדה), צבירת תוצאה בין separate ל‑end, וטיפול בריצה שאורזת שדה שלם. **`@w:fldLock`/`@w:dirty` לא נקראים** — משפיעים רק על האם Word יחשב מחדש, לא על התצוגה. | `inline_parser.dart:56-129` |
| 12 | `w:instrText` (קוד שדה) | כן | נאמן | נצבר כקוד השדה (רק כשלא בתוך תוצאה ובעומק 0). | `inline_parser.dart:108-112` |
| 13 | תוכן cache בין separate ל‑end | כן | נאמן | נאסף ל‑`cached`; `_cachedText` משרשר את הטקסט הגלוי. משמש כ‑fallback לשדות עמוד וכתוצאה מוצגת לשדות לא‑מוכרים. | `inline_parser.dart:32,200-210` |
| 14 | קוד `PAGE` | כן | נאמן | → `DocxPageNumber`; החלפה חיה פר‑עמוד בעימוד, מכבד `\*` ופורמט המקטע (pgNumType). | `field_instruction.dart:19-20`; `field_substitution.dart:57` |
| 15 | קוד `NUMPAGES` | כן | נאמן | → `DocxPageCount`; מוחלף ב‑`totalPages` מהעימוד. | `field_instruction.dart:21-22`; `field_substitution.dart:59` |
| 16 | קוד `SECTIONPAGES` | כן | נאמן | → `DocxPageCount(sectionScope)`; מוחלף ב‑`sectionPages` (מחושב פר‑מקטע בעימוד). | `field_instruction.dart:23-25`; `field_substitution.dart:59` |
| 17 | קוד `PAGEREF` (+`\h`) | חלקי | חלקי | מספר העמוד של הסימנייה נפתר חי ממפת `bookmarkPages` (נאמן). **`\h` נקרא אך לא מחווט להתנהגות קישור** — הערך המוחלף הוא טקסט רגיל, לא קישור לחיץ לקפיצה. מספר נאמן; ניווט ה‑`\h` לא. | `field_instruction.dart:26-34`; `field_substitution.dart:70-74`; `paginator.dart:1030-1032` |
| 18 | קוד `REF` | חלקי | חלקי | לא ממודל → `DocxUnknownField` → מוצג טקסט ה‑cache של Word (סטטי, לא מחושב מחדש). תוכן הסימנייה לא נקרא חי. fallback סביר. | `field_instruction.dart:46-47`; render: `paragraph_builder.dart:793-804` |
| 19 | קוד `STYLEREF` (כותרות רצות) | כן | נאמן~ | → `DocxStyleRef`; פתרון חי של הכותרת הרצה (פסקה ראשונה/אחרונה של הסגנון בעמוד), כולל `\l`. ליבת מסמכי הקודש/מילון. שאר ה‑switches (`\n \w \r \t \p` — מספור/הקשר) מתעלמים. | `field_instruction.dart:35-45`; `field_substitution.dart:76-85`; `page_context.dart` |
| 20 | קוד `SEQ` | חלקי | חלקי | לא ממודל → `DocxUnknownField` → ערך ה‑cache (Figure 1…) מוצג סטטי; מונה רציף לא מחושב מחדש. fallback סביר. | `field_instruction.dart:46-47` |
| 21 | קוד `TOC` | כן | נאמן~ | ברמת בלוק: SDT עם `docPartGallery="Table of Contents"` → `DocxTableOfContents`, מורחב לפסקאות ה‑cache שמרונדרות במסלול הפסקה הרגיל (טאב‑leader + hyperlink anchors) עם **מספרי עמוד חיים** (PAGEREF). מציג את ה‑TOC השמור של Word עם מספרים מעודכנים — לא מחדש את ה‑TOC. קוד TOC inline (לא‑SDT) → `DocxUnknownField`. | `block_parser.dart:138-159`; `toc_expander.dart`; `field_substitution.dart` |
| 22 | קודים `DATE`/`TIME`/`CREATEDATE` | חלקי | חלקי | לא ממודלים → `DocxUnknownField` → טקסט ה‑cache (תאריך/שעה סטטיים שנשמרו). לא מתעדכן לזמן ההצגה. fallback סביר. | `field_instruction.dart:46-47` |
| 23 | קוד `HYPERLINK` | כן | נאמן~ | `parseHyperlink` → `_linkify`: ריצות התוצאה הופכות לקישור (URL חיצוני או `#anchor`) כחול+קו‑תחתון, זהה לאלמנט `w:hyperlink`. תומך `\l` (עוגן), `\o` (tip — מדולג כערך), URL. | `inline_parser.dart:217-256`; `field_instruction.dart:65-89` |
| 24 | קודים `TC`/`XE`/`INDEX` | חלקי | חלקי | לא ממודלים → `DocxUnknownField`. `INDEX` מציג את האינדקס שנוצר ב‑cache; `TC`/`XE` הם קודי שדה נסתרים ללא תוצאה גלויה → בפועל כלום. מקובל. | `field_instruction.dart:46-47` |
| 25 | קוד `=formula` | חלקי | חלקי | לא ממודל → `DocxUnknownField` → ערך ה‑cache שחושב ע"י Word מוצג; לא מחושב מחדש. | `field_instruction.dart:46-47` |
| 26 | פענוח switches (`\*`/`\#`/`\@`/`MERGEFORMAT`) | חלקי | חלקי | **`\*`** (ROMAN/roman/ALPHABETIC/alphabetic/Arabic) מפוענח לפורמט עמוד, רגיש‑רישיות. `MERGEFORMAT`/`CHARFORMAT` → מתעלם (יורש). **`\#` (תמונת מספר) ו‑`\@` (תמונת תאריך) לא מפוענחים** — שדות אלו ממילא `DocxUnknownField` → cache. כך שרק `\*` על PAGE/PAGEREF/וכו' מכובד. | `field_instruction.dart:91-111` |
| 27 | `w:hyperlink @r:id` (URL חיצוני) | כן | נאמן | `r:id` → יעד מ‑rels → href; הריצות הופכות לקישור כחול+קו‑תחתון; הקשה → `onExternalLink`/`url_launcher`. | `inline_parser.dart:468-497`; `paragraph_builder.dart:882-886,1145-1162` |
| 28 | `w:hyperlink @w:anchor` (יעד פנימי) | כן | נאמן | `@w:anchor` (בלי r:id) → href `#anchor`; הקשה → `onInternalLink` → גלילה לעמוד הסימנייה. | `inline_parser.dart:476-479`; `paragraph_builder.dart:1146-1148` |
| 29 | `w:hyperlink @w:tooltip` | לא | לא | לא נקרא. אין tooltip בריחוף. השפעה ויזואלית נמוכה (בעיקר דסקטופ/hover). | אין |
| 30 | `w:hyperlink @w:docLocation`/`@w:history` | לא | לא | לא נקראים. `docLocation` נדיר; `history` (מעקב ביקור) לא ממודל. השפעה זניחה. | אין |
| 31 | החלת סגנון תו `Hyperlink` (כחול+קו תחתון) | חלקי | חלקי | המראה (כחול+קו‑תחתון) **קשיח** ב‑`_linkify`/`_parseHyperlink` (`DocxColor.blue`+underline) וברינדור `theme.linkStyle.color`. סגנון התו `Hyperlink` מ‑styles.xml **לא נשלף ולא מוחל** — הצבע נכפה כחול ולא נגזר מהסגנון/theme. אם הסגנון במסמך שונה (למשל צבע hyperlink מ‑theme) — אי‑התאמה. כפילות עם משימה 07. | `inline_parser.dart:241-256,489-493`; `paragraph_builder.dart:882-886` |
| 32 | `w:bookmarkStart`/`w:bookmarkEnd` (@id/@name) | חלקי | נאמן~ | `bookmarkStart` → `DocxBookmark(name)` (`_GoBack` של Word מדולג); **`@w:id` לא נקרא** ו‑`bookmarkEnd` מתעלם → רק מיקום ה‑start נרשם (עוגן ברוחב‑אפס). מאחר שרק ה‑name משמש ליעדים, מספיק ל‑PAGEREF/ניווט; טווח/חפיפה לא נשמרים. | `inline_parser.dart:46-54`; `docx_section.dart:950-966` |
| 33 | מיפוי name→עמוד עבור PAGEREF | כן | נאמן | בעימוד: `_bookmarkPages[name]=מספר עמוד תצוגה` + `_bookmarkPageIndex`; נצרך ב‑`FieldSubstitution._pageRef`. עוגן ברוחב‑אפס נשמר בצד הנכון בפיצול פסקה. | `paginator.dart:1030-1032`; `field_substitution.dart:70-74`; `span_factory.dart:466-473,643-650` |
| 34 | `w:footnoteReference @w:id` (+סגנון FootnoteReference superscript) | כן | נאמן~ | `@w:id` → `DocxFootnoteRef`; מרונדר superscript ×0.6 בצבע קישור; התווית ממספור העימוד (`footnoteLabels`). **סגנון `FootnoteReference` מ‑styles.xml לא נקרא** — ה‑superscript/גודל קשיחים (לא בדיוק הסגנון). | `inline_parser.dart:331-336`; `paragraph_builder.dart:1084-1097`; `span_factory.dart:561-573` |
| 35 | `w:endnoteReference @w:id` | כן | נאמן~ | `@w:id` → `DocxEndnoteRef`; אותו טיפול superscript; הערות הסיום זורמות בסוף המסמך. סגנון `EndnoteReference` לא נקרא (כמו 34). | `inline_parser.dart:339-343`; `paragraph_builder.dart:1099-1112`; `paginator.dart:484-502` |
| 36 | `w:footnote`/`w:endnote @w:type` (normal/separator/continuationSeparator/continuationNotice) | חלקי | **לא** | כל אלמנטי `w:footnote`/`w:endnote` נקראים כולל הסוגים המיוחדים, אך **`@w:type` לא נקרא**; הערות מיוחדות לעולם לא מסומנות → לא מוצגות, וה‑viewer מצייר **מפריד מובנֵה משלו** (קו ⅓‑רוחב). תוכן ה‑separator/continuationSeparator/continuationNotice המותאם של המסמך **מתעלם**. מראה ברירת‑מחדל סביר; מפריד מותאם לא נאמן. | `docx_reader.dart:276-295`; מפריד: `paginator.dart:212-215,1065` |
| 37 | מאפייני הערות (pos/numFmt/numStart/numRestart) | חלקי | חלקי | `numFmt`(format)+`numRestart` נקראים ל‑`DocxNoteProperties` ומשמשים בתוויות (continuous/eachSect/eachPage). **`pos`** (תחתית עמוד/מתחת לטקסט; סוף‑מסמך/סוף‑מקטע) נקרא אך **לא מנוצל** — הערות שוליים תמיד בתחתית, סיום תמיד בסוף המסמך. **`numStart`** (מספר התחלה) **לא מוחל** — תמיד מתחיל מ‑1. | `section_parser.dart:289+`; `paginator.dart:504-518,1056-1063` |
| 38 | הצגת הערת שוליים **בתחתית העמוד** (שילוב בעימוד) | כן | נאמן~ | העימוד משריין רצועת תחתית ומפצל עמודים כך שהערת השוליים יושבת בעמוד הסימן שלה. ליבת הנאמנות. המפריד מקורב (פריט 36); המשך הערה ארוכה לעמוד הבא = best‑effort. | `paginator.dart:138-166,540-575,924-940,1056-1068` |
| 39 | `w:commentRangeStart/End @w:id` | לא | n/a | לא נקראים — אין ענף ב‑`parseChildren`, מדולגים. אין הדגשת טווח הערה. מקובל לתצוגת קריאה (Word עצמו לרוב מציג בגיליון צד). | אין |
| 40 | `w:commentReference @w:id` | לא | n/a | לא נקרא ככזה; ריצה שמכילה רק `w:commentReference` נופלת ל‑`DocxRawInline` (אין `w:t`) → ה‑viewer לא מרנדר `DocxRawInline` → הסימן נשמט בשקט. מקובל. | `inline_parser.dart:441` (fallback); (לא מרונדר) |
| 41 | `w:comment` (author/date/initials + תוכן) | לא | n/a | `comments.xml` לא נטען כלל — הערות הסוקר מתעלמות לחלוטין. מקובל לתצוגת קריאה (לא משפיע על זרימת הטקסט הראשי); סטייה מתועדת. | אין |
| 42 | `w:ruby` (rubyPr/rt/rubyBase) | **לא** | **לא** | לא מטופל — ריצה שעוטפת `w:ruby` נופלת ל‑`DocxRawInline` (ה‑`w:t` מקונן ב‑`rubyBase`, `getElement('w:t')` מחזיר null) → לא מרונדר. כך **גם טקסט הבסיס וגם טקסט הרובי אובדים** (חמור מהשמטת ההדרכה בלבד). פער. | `inline_parser.dart:441` (fallback); (לא מרונדר) |
| 43 | `m:oMathPara` (נוסחה display) | חלקי | **לא** | OMML מקופל ל**טקסט ליניארי** (שרשור `m:t`): ברמת בלוק → פסקה רגילה; inline → `DocxText`. התוכן נשמר אך לא מעומד כנוסחת display (Plan §K.6). | `block_parser.dart:117-130`; `inline_parser.dart:170-176` |
| 44 | `m:oMath` (נוסחה inline) | חלקי | **לא** | זהה: שרשור `m:t` בלבד (`_ommlLinearText`), טקסט ליניארי ולא מבנה נוסחה. | `inline_parser.dart:170-176,258-272` |
| 45 | אבני בניין OMML (m:f/sSup/sSub/rad/nary/d/func/m/r+t) | **לא** | **לא** | רק `m:t` משורשר; המבנה (שבר/חזקה/אינדקס/שורש/מטריצה/סוגריים) **אובד** — שבר `a/b` יוצא "ab" (מונה+מכנה ללא סימן חלוקה). משמעותי לנוסחאות. סטייה מתועדת (Plan §K.6). | `inline_parser.dart:266-272` |

### ב.2 — פערים והוראות ל‑AI הבא

**קריטי לנאמנות (נקרא אך לא מרונדר — להשלים ברינדור):**
- **`w:ptab` (פריט 8).** נקרא ל‑`DocxPositionalTab` (alignment/relativeTo/leader) אך **אין לו ענף ב‑`buildInlineSpans`/`buildMeasurementSpans`** → תורם רוחב אפס, הטאב המוחלט נעלם. ליישם דרך `TabEngine` (טאב יחסי לשוליים/הזחה) או placeholder ברוחב מחושב; לחווט גם במדידה כדי לשמור measure ≡ render.
- **`w:ruby` (פריט 42).** הריצה נופלת ל‑`DocxRawInline` ו**גם טקסט הבסיס אובד**. מינימום: לחלץ את `rubyBase` ולרנדר לפחות את טקסט הבסיס (ואידאלית את ה‑`rt` קטן מעליו). להוסיף ענף `ruby` ב‑`parseChildren`/`parseRun` (`inline_parser.dart`).

**שדות — fallback מ‑cache במקום חישוב חי (פריטים 18, 20, 22, 24, 25):**
- `REF`/`SEQ`/`DATE`/`TIME`/`INDEX`/`=formula` → `DocxUnknownField` → מציג את ערך ה‑cache הסטטי של Word. עבור מסמך קריאה זה מקובל; מנוע 1:1 מלא יחשב `REF`/`SEQ`/`DATE` חי. לתעד כסטייה מודעת.
- **`PAGEREF \h` (פריט 17):** מספר העמוד נאמן, אך ה‑`\h` (קפיצה לסימנייה בלחיצה) לא מחווט — הערך מוחלף כטקסט. לשקול עטיפת הערך המוחלף ב‑recognizer ל‑`onInternalLink`.
- **switches `\#`/`\@` (פריט 26):** תמונת מספר/תאריך לא מפוענחת. רלוונטי כשירצו לחשב `DATE`/`=formula` חי.

**נאמנות חלקית בקיים:**
- **`w:tab` בלי tabStops מפורשים (פריט 4).** מקורב כ‑4 רווחים במקום קפיצה ל‑`defaultTabStop` (כל 720tw). לחווט את ה‑`TabEngine` גם לטאבים על ברירת‑המחדל (תלוי משימה 14 — `defaultTabStop` מ‑settings.xml).
- **סגנונות `Hyperlink`/`FootnoteReference`/`EndnoteReference` (פריטים 31, 34, 35).** המראה קשיח (כחול+קו‑תחתון / superscript ×0.6) ולא נגזר מ‑styles.xml. לחווט שליפת סגנון התו (כפילות עם משימה 07).
- **`@w:type` של הערות + מפריד מותאם (פריט 36).** ה‑viewer מצייר מפריד מובנה; separator/continuationSeparator/continuationNotice של המסמך מתעלמים. לקרוא `@w:type` ולרנדר את ה‑separator המותאם אם קיים.
- **מאפייני הערות `pos`/`numStart` (פריט 37).** `pos` (מתחת‑לטקסט / סוף‑מקטע) ו‑`numStart` (מספר התחלה) נקראים אך לא מיושמים. `numFmt`/`numRestart` כן.
- **מצב continuous — מעברי עמוד/טור inline (פריט 2).** `w:br type=page/column` מתנוון ל‑`\n` בלי מודל עמוד; נאמן רק במצב paged. `@w:clear` לא נקרא בשום מצב.

**קצה — ריצה מעורבת (פריטים 3, 4):** `parseRun` מזהה break/cr/tab/sym כ"אלמנט יחיד לריצה" (`getElement`/`findAllElements`) — ריצה שמערבבת טקסט+tab/break באותו `w:r` תאבד את הטקסט. נדיר ב‑Word (שמפריד לריצות), אך לתעד.

**לא ממומש — סטייה מודעת (מקובל לתצוגת קריאה):**
- **הערות סוקר — `w:comment`/`commentRange*`/`commentReference` (פריטים 39–41).** `comments.xml` לא נטען; טווחים/סימנים מדולגים. לא משפיע על זרימת הטקסט.
- **OMML מלא (פריטים 43–45).** קיפול לטקסט ליניארי בלבד; מבנה הנוסחה אובד. מנוע נוסחאות = משימה נפרדת (Plan §K.6).
- **`@w:fldLock`/`@w:dirty` (פריט 11), `@w:tooltip`/`docLocation`/`history` (פריטים 29–30), `@w:id` של סימנייה (פריט 32).** מטא‑דאטה ללא השפעה ויזואלית מהותית — אין פעולה נדרשת.
