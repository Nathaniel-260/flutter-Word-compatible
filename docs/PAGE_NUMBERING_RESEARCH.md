# מחקר ותכנון: מספור עמודים אוטומטי נאמן ל‑Word

> מסמך הבסיס למימוש **אפשרות 2 — עימוד מדויק כמו Word**.
> כולל מנוע עימוד מבוסס‑מדידה, פענוח שדות (`PAGE`/`NUMPAGES`/…), `pgNumType`, מקטעים, וריאנטי כותרת/תחתית, ו‑`PAGEREF`.
>
> טווח: שתי החבילות — `docx_creator` (מודל + קורא) ו‑`docx_file_viewer` (עימוד + רינדור).

---

## 1. מטרה והיקף

לאפשר תצוגה נאמנה ל‑Word של מספרי עמודים אוטומטיים: שדה `PAGE` שמראה את **מספר העמוד הנכון בכל עמוד**, `NUMPAGES`/`SECTIONPAGES` עם **ספירה אמיתית**, פורמטים (decimal/roman/alpha/chapter), התחלה/איפוס פר‑מקטע, וריאנטי עמוד ראשון/זוגי/אי‑זוגי, ו‑`PAGEREF` (הפניה לעמוד של סימנייה).

**מחוץ להיקף (שלב זה):** עריכה, חישוב‑מחדש של שדות שאינם עמוד (TOC דינמי, נוסחאות), עימוד רב‑טורי (`w:cols` מרובה‑טורים אמיתי).

---

## 2. רקע: מנגנוני מספור עמודים ב‑OOXML

### 2.1 שדות (Fields)

ב‑OOXML שדה מיוצג בשתי צורות:

**(א) שדה פשוט** — `w:fldSimple`:
```xml
<w:fldSimple w:instr=" PAGE \* MERGEFORMAT ">
  <w:r><w:t>3</w:t></w:r>            <!-- תוצאת מטמון -->
</w:fldSimple>
```

**(ב) שדה מורכב** — רצף ריצות עם `w:fldChar`:
```xml
<w:r><w:fldChar w:fldCharType="begin"/></w:r>
<w:r><w:instrText xml:space="preserve"> PAGE \* ROMAN </w:instrText></w:r>
<w:r><w:fldChar w:fldCharType="separate"/></w:r>
<w:r><w:t>iii</w:t></w:r>            <!-- תוצאת מטמון, בין separate ל-end -->
<w:r><w:fldChar w:fldCharType="end"/></w:r>
```

נקודות קריטיות:
- מחרוזת ההוראה (`instr`) עלולה להיות **מפוצלת על פני כמה `w:instrText`** — חובה לשרשר.
- ה‑`w:t` שבין `separate` ל‑`end` הוא **תוצאת מטמון** (הערך מהפעם האחרונה ש‑Word חישב). אסור להציג אותו כטקסט סטטי — צריך להחליפו בחישוב חי.
- שדות יכולים **להיות מקוננים** (`PAGEREF` בתוך TOC).

### 2.2 שדות רלוונטיים למספור

| שדה | משמעות | מתגים נפוצים |
|---|---|---|
| `PAGE` | מספר העמוד הנוכחי | `\* ROMAN` `\* roman` `\* ALPHABETIC` `\* alphabetic` `\* Arabic` `\* MERGEFORMAT` |
| `NUMPAGES` | סך כל העמודים במסמך | כנ"ל |
| `SECTIONPAGES` | סך העמודים במקטע הנוכחי | כנ"ל |
| `PAGEREF bookmark` | מספר העמוד שבו נמצאת הסימנייה | `\h` (היפר‑קישור), `\p` (יחסי) |

מתגי פורמט (`\*`): `Arabic`=1,2,3 · `ROMAN`=I,II,III · `roman`=i,ii,iii · `ALPHABETIC`=A,B,C · `alphabetic`=a,b,c · `CardText`/`Ordinal`/`OrdText` (נדירים — נטפל כ‑decimal fallback בשלב 1).

### 2.3 `w:pgNumType` (ב‑`sectPr`)

מגדיר את מספור העמודים **למקטע**:
```xml
<w:pgNumType w:fmt="lowerRoman" w:start="1" w:chapStyle="1" w:chapSep="hyphen"/>
```
- `w:fmt` — פורמט ברירת מחדל של מספרי העמוד במקטע (אם השדה עצמו לא מציין `\*`).
- `w:start` — מספר ההתחלה של המקטע (איפוס; היעדר = המשך מהמקטע הקודם).
- `w:chapStyle` — רמת ה‑Heading שממנה נגזר מספר הפרק.
- `w:chapSep` — מפריד: `hyphen`(-) `period`(.) `colon`(:) `emDash`(—) `enDash`(–). תוצאה: "1-1", "2-5".

### 2.4 מקטעים (Sections)

מסמך = רצף מקטעים. כל פסקה אחרונה במקטע מכילה `w:pPr/w:sectPr`; המקטע האחרון ב‑`w:body/w:sectPr`. סוגי שבירה (`w:type`): `nextPage` `evenPage` `oddPage` `continuous`. כל מקטע יכול **לאפס** מספור (`pgNumType w:start`) או **להמשיך**.

### 2.5 וריאנטי כותרת/תחתית

- שלוש הפניות לכל מקטע: `w:type="default" | "first" | "even"`.
- `w:titlePg` ב‑`sectPr` → עמוד ראשון של המקטע משתמש בכותרת/תחתית `first`.
- `w:evenAndOddHeaders` ב‑`settings.xml` → עמודים זוגיים משתמשים בווריאנט `even`; אי‑זוגיים ב‑`default`.
- בלי הדגלים: `default` בכל העמודים.

---

## 3. ניתוח פערים — מצב נוכחי בקוד

| נושא | מצב | קובץ |
|---|---|---|
| פענוח שדות (`fldChar`/`instrText`/`fldSimple`) | **חסר לגמרי** — ריצת השדה נקראת כריצה רגילה; ה‑`w:t` המטמון מוצג כטקסט סטטי | [inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart) |
| `DocxPageNumber` / `DocxPageCount` | קיימים, אך **רק לייצוא** (`buildXml`), ללא שדה פורמט; הקורא לא מייצר אותם | [docx_section.dart:492](../packages/docx_creator/lib/src/ast/docx_section.dart#L492) |
| `w:pgNumType` | **לא נפרס** | [section_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/section_parser.dart) |
| header/footer מרובי‑וריאנטים | הקורא שומר **אחד בלבד** (זורק `first`/`even`) | [section_parser.dart:74‑95](../packages/docx_creator/lib/src/reader/docx_reader/parsers/section_parser.dart#L74) |
| `w:titlePg` / `evenAndOddHeaders` | `settings.xml` נקרא כמחרוזת בלבד, לא נפרס | [docx_reader.dart:175](../packages/docx_creator/lib/src/reader/docx_reader/docx_reader.dart#L175) |
| עימוד | **היוריסטי** (`_estimateElementHeight`, ~8px/תו), לא מדידה אמיתית | [docx_widget_generator.dart:329](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart#L329) |
| כותרת/תחתית פר‑עמוד | מרונדרת **זהה בכל עמוד**; header רק בעמוד 1 | [_buildPageContainer](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart#L385) |
| ריבוי מקטעים בתצוגה | מקטע יחיד (`doc.section`); `DocxSectionBreakBlock` רק שובר עמוד | [docx_widget_generator.dart:253](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart#L253) |
| המרת מספרים (roman/alpha) | קיים אך כלוא ב‑`list_builder` | [list_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/list_builder.dart) |
| `TextPainter` (תקדים מדידה) | בשימוש כבר ב‑drop‑cap/paragraph/table | [paragraph_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/paragraph_builder.dart) |

**מסקנה:** התשתית קיימת חלקית. החלק היקר הוא מנוע העימוד (שכבה B).

---

## 4. ארכיטקטורת היעד (שכבות)

```
A. מודל + פענוח (docx_creator)
   ├─ DocxField / DocxPageNumber.format / DocxPageCount / DocxPageRef
   ├─ פענוח fldSimple + fldChar state-machine ב-inline_parser
   ├─ pgNumType → DocxSectionDef
   └─ headers/footers מרובי-וריאנטים + titlePg + evenAndOdd

B. מנוע עימוד מבוסס-מדידה (docx_file_viewer)  ← הלב היקר
   ├─ Paginator: ממיר רשימת בלוקים → List<RenderedPage>
   ├─ מדידת גובה אמיתית (TextPainter / layout pass)
   ├─ פיצול פסקה/טבלה על גבול עמוד
   ├─ keepNext / keepLines / widow-orphan
   ├─ ריבוי מקטעים + restart/continue
   └─ מפת bookmark → pageIndex (ל-PAGEREF)

C. החלפה פר-עמוד (docx_file_viewer)
   ├─ PageContext { pageNumber, totalPages, sectionPages, bookmarkPages }
   ├─ הזרקת ההקשר ל-header/footer של כל עמוד
   └─ בחירת וריאנט (first/even/default)

D. שירות פורמט מספרים משותף
   └─ NumberFormatter: decimal/roman/alpha/chapter (חילוץ מ-list_builder)
```

---

## 5. שינויי מודל מפורטים (שכבה A)

### 5.1 AST — שדות

מאחדים ל‑`DocxField` בסיסי + תת‑סוגים, או מרחיבים את הקיימים. הצעה (תאימות לאחור — נשמרים `DocxPageNumber`/`DocxPageCount`):

```dart
/// פורמט מספור משותף (ממופה גם ל-pgNumType.fmt וגם למתג השדה \*).
enum DocxPageNumberFormat { decimal, upperRoman, lowerRoman, upperAlpha, lowerAlpha }

/// שדה PAGE — מספר העמוד הנוכחי.
class DocxPageNumber extends DocxInline {
  final DocxPageNumberFormat? format; // null = ירושה מ-pgNumType של המקטע
  const DocxPageNumber({this.format, super.id});
}

/// שדה NUMPAGES / SECTIONPAGES.
class DocxPageCount extends DocxInline {
  final bool sectionScope;            // true = SECTIONPAGES
  final DocxPageNumberFormat? format;
  const DocxPageCount({this.sectionScope = false, this.format, super.id});
}

/// שדה PAGEREF — מספר העמוד של סימנייה.
class DocxPageRef extends DocxInline {
  final String bookmark;
  final bool hyperlink;               // מתג \h
  final DocxPageNumberFormat? format;
  const DocxPageRef(this.bookmark, {this.hyperlink = false, this.format, super.id});
}

/// שדה לא-מוכר — נשמרת תוצאת המטמון להצגה (fallback).
class DocxUnknownField extends DocxInline {
  final String instruction;
  final List<DocxInline> cachedResult;
  const DocxUnknownField(this.instruction, this.cachedResult, {super.id});
}
```

סימניות (ל‑`PAGEREF`) — צריך לתפוס `w:bookmarkStart w:name=...`:
```dart
class DocxBookmark extends DocxInline {   // marker; ללא רוחב
  final String name;
  const DocxBookmark(this.name, {super.id});
}
```

### 5.2 פענוח שדות ב‑`inline_parser.dart`

מכונת‑מצבים ברמת `parseChildren` (כי שדה מורכב משתרע על כמה `w:r` אחים):

```
מצב NORMAL:
  - r עם fldChar=begin            → מצב IN_INSTR, אפס buffer
  - fldSimple                     → פרסר instr ישירות, דלג על ילדי התוצאה
  - bookmarkStart                 → הוסף DocxBookmark
  - אחרת                          → כרגיל (parseRun)
מצב IN_INSTR:
  - r עם instrText                → buffer += טקסט
  - r עם fldChar=separate         → מצב IN_RESULT (אסוף תוצאת מטמון)
  - r עם fldChar=end              → סיים שדה (ללא separate)
מצב IN_RESULT:
  - r עם fldChar=end              → בנה צומת מהוראת ה-buffer; אם לא מוכר, צרף cachedResult
  - אחרת                          → אסוף ל-cachedResult
```

מפענח ההוראה: `tokenize(instr)` → המילה הראשונה = שם השדה; חיפוש `\*` ואחריו מזהה הפורמט. דוגמה: `" PAGE \* ROMAN "` → `DocxPageNumber(format: upperRoman)`.

### 5.3 `pgNumType` ב‑`DocxSectionDef`

הוספת שדות (ל‑AST `DocxSectionDef` וגם למודל הקורא):
```dart
final DocxPageNumberFormat pageNumberFormat; // ברירת מחדל decimal
final int? pageNumberStart;                  // null = המשך מהמקטע הקודם
final int? chapterStyleLevel;                // pgNumType.chapStyle
final DocxChapterSeparator chapterSeparator; // hyphen/period/colon/emDash/enDash
final bool titlePage;                        // w:titlePg
```
פענוח ב‑[section_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/section_parser.dart): `sectPr.getElement('w:pgNumType')`.

### 5.4 header/footer מרובי‑וריאנטים

החלפת `header`/`footer` היחידים במפה:
```dart
final Map<DocxHfType, DocxHeader> headers; // {default, first, even}
final Map<DocxHfType, DocxFooter> footers;
enum DocxHfType { default_, first, even }
```
(לשמור getters `header`/`footer` שמחזירים את `default_` — תאימות לאחור עם הקוד הקיים בצופה.)

### 5.5 `settings.xml`

פענוח דגל יחיד: `w:evenAndOddHeaders` → `bool DocxBuiltDocument.evenAndOddHeaders`.

---

## 6. מנוע העימוד (שכבה B) — המפרט המרכזי

### 6.1 עקרון

להחליף את `_generatePagedWidgets` ההיוריסטי ב‑**Paginator** שמודד תוכן אמיתי ושובר בגבול עמוד אמיתי. תוצר: `List<RenderedPage>`, כשכל עמוד יודע את אינדקסו, מקטעו, והבלוקים שבו.

```dart
class RenderedPage {
  final int pageNumber;        // מספר תצוגה (אחרי start/restart)
  final int absoluteIndex;     // 0-based במסמך
  final int sectionIndex;
  final List<DocxNode> blocks; // כולל שברי פסקה/טבלה
}
```

### 6.2 אסטרטגיית מדידה

שתי גישות, מומלץ להתחיל ב‑(א):

**(א) מדידה לוגית עם `TextPainter`** — לכל פסקה בונים `TextSpan` (דרך `ParagraphBuilder`), עושים `layout(maxWidth = contentWidth)` ומקבלים `height` + `computeLineMetrics()` (גובה כל שורה ונקודות שבירה). מהיר, ללא render אמיתי, ויש כבר תקדים בקוד.

**(ב) מדידה פיזית off‑screen** — `RenderObject`/`BuildOwner` נסתר. מדויק יותר לווידג'טים מורכבים (טבלאות מקוננות) אבל יקר. שמור כ‑fallback למקרים ש‑(א) לא מספיק.

`contentWidth = pageWidth − marginLeft − marginRight − gutter` (מ‑`DocxSectionDef`, כפי שכבר מחושב ב‑`_buildPageContainer`).
`contentHeight = pageHeight − marginTop − marginBottom − גובה header/footer בפועל` (לא קבוע 100px כמו היום — נמדד מהווריאנט הרלוונטי).

### 6.3 אלגוריתם המילוי (fill)

```
לכל מקטע:
  לכל בלוק במקטע:
    h = measure(block, contentWidth)
    אם currentY + h <= contentHeight:
      הוסף בלוק לעמוד; currentY += h
    אחרת:
      אם הבלוק ניתן לפיצול (פסקה/טבלה):
        (head, tail) = splitBlock(block, remaining = contentHeight - currentY)
        הוסף head; פתח עמוד חדש; block = tail; חזור
      אחרת (תמונה/צורה שלא נכנסת):
        פתח עמוד חדש; הוסף בלוק (גם אם חורג — clamp)
  בסוף מקטע: החל סוג השבירה (nextPage/even/odd) על פתיחת המקטע הבא
```

### 6.4 פיצול פסקה (הקושי המרכזי)

`TextPainter.computeLineMetrics()` נותן `LineMetrics` לכל שורה (גובה מצטבר). מאתרים את אינדקס השורה האחרונה שנכנסת ב‑`remaining`, וממירים ל‑offset תווים דרך `getPositionForOffset` בקצה אותה שורה. מפצלים את רשימת ה‑`DocxInline` בנקודת ה‑offset:
- מחשבים את ה‑offset הגלובלי בתוך ה‑span המורכב.
- חוצים את ה‑`DocxText` הרלוונטי לשניים (שומרים עיצוב), שאר ה‑inline‑ים מתחלקים לפי הצד.
- `head` = פסקה עם השורות העליונות, `tail` = פסקה עם השאר (יורשת מאפייני פסקה).

מקרי קצה: שורה בודדת שלא נכנסת (מקדמים את כל הפסקה לעמוד הבא), פיצול בתוך היפר‑קישור/ריצה מעוצבת, טקסט RTL (חישוב ה‑offset זהה — `TextPainter` כבר מודע ל‑`textDirection`).

### 6.5 פיצול טבלה

- שובר בין **שורות** (לא בתוך תא); שורה שלא נכנסת → לעמוד הבא.
- אם `w:tblHeader` מסומן על שורת כותרת → **חזרה על שורת הכותרת** בראש כל המשך.
- תא עם תוכן ארוך מאוד מ‑עמוד שלם → שלב 1: מציבים את השורה כפי שהיא (clamp); פיצול תוך‑תאי הוא הרחבה עתידית.

### 6.6 שמירת‑יחד (keep rules)

מ‑`w:pPr`: `w:keepNext` (אל תשבור לפני הפסקה הבאה), `w:keepLines` (אל תפצל את הפסקה), `widowControl` (מינימום 2 שורות בכל צד). בשלב 1 ניתן לכבד `keepLines`+`keepNext` (פשוט יחסית) ולדחות widow/orphan עדין לשלב 2.

### 6.7 ריבוי מקטעים

לפצל את `doc.elements` ל‑runs לפי `DocxSectionBreakBlock`. לכל מקטע: `DocxSectionDef` משלו (גודל/שוליים/כותרות/`pgNumType`). מספר ההתחלה: `pgNumType.start ?? (continue → pageNumber הקודם + 1)`.

### 6.8 מפת `bookmark → pageIndex`

תוך כדי מילוי, כש‑`DocxBookmark` נכנס לעמוד P → `bookmarkPages[name] = P`. נדרש **מעבר עימוד מלא לפני הרינדור** (ממילא כך) כדי ש‑`PAGEREF`/`NUMPAGES` יידעו ערכים. `PAGEREF` מתורגם ל‑`pageNumber` של אותו עמוד בפורמט הרלוונטי.

---

## 7. רינדור פר‑עמוד (שכבה C)

```dart
class PageContext {
  final int pageNumber;     // PAGE (אחרי פורמט/start)
  final int totalPages;     // NUMPAGES
  final int sectionPages;   // SECTIONPAGES
  final Map<String,int> bookmarkPages; // PAGEREF
  final DocxSectionDef section;
}
```

`_buildPageContainer` מקבל `PageContext` ובזמן בניית ה‑header/footer מחליף כל צומת שדה לערך מפורמט דרך `NumberFormatter`. בחירת הווריאנט:
```
isFirstPageOfSection && section.titlePage      → headers[first] ?? default
evenAndOddHeaders && pageNumber.isEven         → headers[even]  ?? default
אחרת                                            → headers[default_]
```

החלפת השדה ברמת ה‑inline: מעבר על ה‑spans וכאשר נתקלים ב‑`DocxPageNumber`/`DocxPageCount`/`DocxPageRef` → מזריקים `TextSpan` עם הערך המחושב (פורמט: `field.format ?? section.pageNumberFormat`). תוצאת המטמון של `DocxUnknownField` מרונדרת כפי שהיא.

---

## 8. שירות פורמט מספרים (שכבה D)

חילוץ `_toRoman`/`_toAlpha`/decimal מ‑[list_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/list_builder.dart) ל‑`NumberFormatter` משותף (חבילת `docx_creator` core או util משותף בצופה). תמיכה ב‑chapter: `"${chapterNumber}${sep}${pageNumber}"`. `list_builder` יואב להשתמש באותו שירות (ללא רגרסיה — אותם פלטים).

---

## 9. שלבי מימוש מדורגים

| Milestone | תוכן | תלוי ב‑ | בדיקות |
|---|---|---|---|
| **M0** | חילוץ `NumberFormatter` (D) + בדיקות שאינן שוברות את `list_builder` | — | unit (roman/alpha/chapter) |
| **M1** | פענוח שדות (A): `fldSimple`+`fldChar`, PAGE/NUMPAGES/PAGEREF/Unknown, מתגי `\*`, bookmarks | M0 | round‑trip reader |
| **M2** | `pgNumType` + headers/footers מרובי‑וריאנטים + `evenAndOddHeaders` (A) | M1 | round‑trip reader |
| **M3** | `Paginator` מבוסס‑מדידה ללא פיצול (בלוק שלם → עמוד) (B) | M2 | golden גבהים |
| **M4** | פיצול פסקה (B) | M3 | unit לפיצול spans + golden |
| **M5** | פיצול טבלה + `tblHeader` + keep rules (B) | M4 | golden טבלאות |
| **M6** | ריבוי מקטעים + restart/continue + מפת bookmark (B) | M5 | golden רב‑מקטעי |
| **M7** | רינדור פר‑עמוד + בחירת וריאנט + החלפת שדות (C) | M6 | widget/golden "X מתוך Y" |

מינימום שימושי: **M0–M3 + M7** כבר נותן `PAGE`/`NUMPAGES` עם ספירה מבוססת‑מדידה (ללא פיצול פסקה — שבירה רק בין בלוקים). M4–M6 משדרגים לדיוק מלא.

---

## 10. מטריצת בדיקות

- **Reader (round‑trip):** `PAGE`, `PAGE \* ROMAN`, `fldSimple` מול `fldChar`, instr מפוצל לכמה `instrText`, `NUMPAGES`, `PAGEREF`, `pgNumType`(fmt/start/chap), `titlePg`, `evenAndOddHeaders`, header `first`/`even`.
- **Paginator (unit):** פסקה שנכנסת/לא‑נכנסת; פיצול בנקודת שורה; שורה בודדת חורגת; פיצול בתוך ריצה מעוצבת/RTL; טבלה החוצה עמוד + חזרת כותרת; `keepLines`/`keepNext`.
- **רינדור (widget/golden):** מספר עמוד שונה בכל עמוד; פורמט roman; start=5; איפוס פר‑מקטע; וריאנט עמוד ראשון; זוגי/אי‑זוגי; "עמוד X מתוך Y" עם Y נכון; `PAGEREF` מצביע לעמוד הנכון.
- **רגרסיה:** golden עברית RTL הקיימים; בדיקות הרשימות הקיימות (D לא משנה פלט).

---

## 11. סיכונים ושאלות פתוחות

1. **דיוק מדידה לעומת Word** — `TextPainter` עשוי לסטות מ‑Word בשבירות שורה (kerning/hyphenation). מקובל פער של ±שורה; golden tolerance.
2. **ביצועים** — מדידת מסמך שלם בטעינה. הקלות: מטמון מדידות פר‑בלוק, מדידה עצלה למקטעים שמעבר ל‑viewport, שימוש חוזר ב‑`TextPainter`.
3. **`virtualization`** הקיים (`ListView.builder`) — צריך לחיות לצד עימוד מדוד; ייתכן שעימוד‑מראש + מחזור עמודים ב‑`ListView.builder` הוא הפתרון.
4. **פיצול בתוך תא טבלה** — נדחה; מסמכים עם תא ענק ייחתכו clamp בשלב 1.
5. **טורים מרובים (`w:cols`)** — לא נתמך; עמוד = טור יחיד.
6. **`SECTIONPAGES` בלי מקטעים מפורשים** = `NUMPAGES`.

### החלטות שדורשות אישור לפני M1
- האם לאחד הכול ל‑`DocxField` יחיד, או להרחיב את `DocxPageNumber`/`DocxPageCount` הקיימים? (המסמך מציע הרחבה + הוספת `DocxPageRef`/`DocxUnknownField`/`DocxBookmark`.)
- מיקום `NumberFormatter` — ב‑`docx_creator` (משותף לשתי החבילות) או ב‑viewer בלבד?

---

## 12. נספח — קבצים מרכזיים לנגיעה

**docx_creator**
- [inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart) — מכונת מצבים לשדות (M1)
- [section_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/section_parser.dart) — `pgNumType` + וריאנטים (M2)
- [docx_section.dart](../packages/docx_creator/lib/src/ast/docx_section.dart) — `DocxPageNumber/Count/Ref`, `DocxSectionDef` (M1‑M2)
- [docx_reader.dart](../packages/docx_creator/lib/src/reader/docx_reader/docx_reader.dart) — `settings.xml` (M2)

**docx_file_viewer**
- [docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart) — `_generatePagedWidgets`→`Paginator`, `_buildPageContainer` (M3‑M7)
- [paragraph_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/paragraph_builder.dart) — בניית spans למדידה ולפיצול (M4)
- [list_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/list_builder.dart) — מקור `NumberFormatter` (M0)
- חדש: `lib/src/pagination/paginator.dart`, `lib/src/pagination/page_context.dart`
