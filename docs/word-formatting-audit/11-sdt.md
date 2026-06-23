# משימה 11 — פקדי תוכן — Structured Document Tags (SDT)

> **מקור:** סעיף §11 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **סטטוס מימוש:** 🔄 SDT בטבלה (1) מפורק; checkbox דינמי/dataBinding נותרו &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-23

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

`w:sdt` (Structured Document Tag) — בלוק או inline. מבנה: `w:sdtPr` (מאפיינים) + `w:sdtEndPr` + `w:sdtContent` (התוכן בפועל).

```xml
<w:sdt>
  <w:sdtPr>
    <w:alias w:val="כותרת"/><w:tag w:val="title"/><w:id w:val="123"/>
    <w:lock w:val="sdtContentLocked"/>
    <w:placeholder><w:docPart w:val="DefaultPlaceholder"/></w:placeholder>
    <w:dropDownList>…<w:listItem w:displayText="א" w:value="1"/>…</w:dropDownList>
  </w:sdtPr>
  <w:sdtContent>… פסקאות/ריצות רגילות …</w:sdtContent>
</w:sdt>
```

| אלמנט ב‑sdtPr | מה עושה |
|---|---|
| `w:alias`,`w:tag`,`w:id` | שם תצוגה / תג מזהה לקוד / מזהה |
| `w:lock` | `sdtLocked`/`contentLocked`/`sdtContentLocked`/`unlocked` |
| `w:placeholder` | טקסט מציין מקום |
| `w:showingPlcHdr` | כרגע מציג placeholder |
| `w:dataBinding` | קישור ל‑customXml (`@w:xpath`,`@w:storeItemID`) |
| `w:temporary` | פקד זמני |
| **טיפוסים:** `w:text`,`w:richText`,`w:comboBox`,`w:dropDownList`,`w:date`(@fullDate, format),`w:picture`,`w:checkbox`(w14),`w:docPartObj`/`w:docPartList`,`w:group`,`w:bibliography`,`w:citation`,`w:equation` | סוג הפקד |

> לרינדור: בדרך כלל פשוט מרנדרים את `w:sdtContent` כתוכן רגיל. ה‑checkbox (`w14:checkbox`) דורש מיפוי תו מסומן/לא‑מסומן (`w14:checkedState`/`uncheckedState` — font+char).

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

> **מפת המימוש — "unwrap‑and‑forward":** אין מודל `DocxSdt` ואין שכבת רינדור ל‑SDT. בכל מסלולי
> הקריאה ה‑`w:sdt` מטופל כ**מכל שקוף**: שולפים את `w:sdtContent` וממשיכים לפרק את ילדיו כתוכן רגיל;
> שום אלמנט מ‑`w:sdtPr` (alias/tag/id/lock/placeholder/dataBinding/temporary/הטיפוס) **אינו נקרא**.
> 3 מסלולים: **(1) בלוק** — `block_parser.dart:134‑166` (כולל מקרה־קצה: `docPartObj` עם
> `docPartGallery="Table of Contents"` → `DocxTableOfContents`, ר' משימה 10 פריט 21).
> **(2) inline** — `inline_parser.dart:154‑165`. **(3) תא טבלה** — `table_parser.dart:471‑486`.
> ⚠️ הצד ה**כותב** בלבד מכיר `w14:checkbox`: `DocxCheckbox.buildXml` (`docx_inline.dart:1310‑1380`) פולט
> SDT עם גליף ☒/☐ — זו **יצירת מסמך, לא הצופה**; אין מסלול קריאה הפוך שמפענח `w14:checkbox`.
> ⚠️ **הכרעת הנאמנות:** בתצוגת קריאה רגילה Word מרנדר פקד תוכן **בלי גבול/הדגשה** — רק כתוכן הזורם
> (הגבול/תגית מופיעים רק ב‑Design Mode / "Highlight Content Controls" / בעת מיקוד). לכן unwrap לתוכן
> רגיל הוא **התנהגות ברירת‑המחדל הנאמנה**; הפער היחיד הוא בפקדים בעלי לוגיקה דינמית (checkbox/dataBinding/date).

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:sdt` בלוק/inline + `w:sdtContent` (רינדור כתוכן רגיל) | כן | נאמן | בכל 3 המסלולים שולפים `w:sdtContent` וממשיכים לפרק את ילדיו כתוכן רגיל (`parseBlocks`/`parseChildren`). זו **בדיוק** תצוגת ברירת‑המחדל של Word בקריאה — פקד תוכן ללא גבול/רקע, התוכן זורם בשורה/פסקה. **קצה לא מטופל:** SDT ברמת **שורת טבלה** (`<w:sdt>` ישירות תחת `<w:tbl>`) או ברמת **תא** (תחת `<w:tr>`) — איטרציית השורות מזהה רק `tr`/`tc` ולא פורקת SDT, כך ששורה/תא עטופי‑SDT **יושמטו**. נדיר. | בלוק: `block_parser.dart:134‑166`; inline: `inline_parser.dart:154‑165`; תא: `table_parser.dart:471‑486`; קצה שורה/תא: `table_parser.dart:203‑251` (אין unwrap) |
| 2 | `w:alias` / `w:tag` / `w:id` | לא | n/a | לא נקראים. מטא‑דאטה ל‑Design Mode/קוד בלבד; ב‑Word התצוגה הרגילה (קריאה) **אינה מציגה** alias/tag/id — הם נראים רק כתגית במצב עיצוב או בריחוף. אין השפעה ויזואלית בצופה. מקובל. | אין (מכוון) |
| 3 | `w:lock` (sdtLocked/contentLocked/sdtContentLocked/unlocked) | לא | n/a | לא נקרא. נעילת **עריכה** בלבד — אין לה ביטוי ויזואלי בתצוגת קריאה (הצופה ממילא לא עורך). מקובל. | אין (מכוון) |
| 4 | `w:placeholder` (+`w:docPart`) | לא נקרא ישירות / חלקי בפועל | נאמן~ | תכונת ה‑`w:placeholder` (ההפניה ל‑docPart) **לא נקראת**. אך כש‑Word מציג placeholder הוא שומר את הטקסט עצמו **בתוך `w:sdtContent`** (עם `rStyle="PlaceholderText"`) — וזה כן נפרק ומרונדר. הגוון האפור תלוי בפתרון סגנון התו `PlaceholderText` (כפילות עם משימה 07). הטקסט מוצג; הגוון מקורב. | תוכן: `inline_parser.dart:154‑165` / `block_parser.dart:161‑164`; סגנון: משימה 07 |
| 5 | `w:showingPlcHdr` | לא נקרא / חלקי בפועל | נאמן~ | הדגל עצמו לא נקרא, אך כשהוא פעיל ה‑`sdtContent` מכיל את טקסט המציין‑מקום (פריט 4) שמרונדר. אין הבחנה מפורשת בין "מציג placeholder" ל"ערך אמיתי" — שניהם זורמים כתוכן. כמו 4. | כמו פריט 4 |
| 6 | `w:dataBinding` (xpath/storeItemID) | לא | נאמן~ | לא נקרא; `customXml` **לא נטען כלל**. הערך המוצג מגיע מה‑`sdtContent` השמור (Word מסנכרן sdtContent↔customXml בכל שמירה, כך שבקובץ סטטי הם תואמים). לקובץ קריאה — נאמן; מנוע 1:1 מלא היה קורא את ה‑store ומרענן. סטייה מודעת. | אין (customXml לא נטען) |
| 7 | `w:temporary` | לא | n/a | לא נקרא. מורה ל‑Word להסיר את עטיפת ה‑SDT לאחר עריכה — אין השפעה ויזואלית על התוכן. מקובל. | אין (מכוון) |
| 8 | טיפוס `w:text` / `w:richText` | כן | נאמן | אין הבחנה בקוד בין הטיפוסים — בשני המקרים ה‑`sdtContent` מרונדר כטקסט/תוכן עשיר רגיל (ריצות עם rPr מלא). זהה לתצוגת Word. | `inline_parser.dart:154‑165` |
| 9 | טיפוס `w:comboBox` / `w:dropDownList` (+`listItem`) | חלקי | נאמן (סטטי) | הערך ה**נבחר** (הריצה ב‑`sdtContent`) מרונדר נכון. רשימת הפריטים (`w:listItem displayText/value`) **לא נקראת** — אין אינטראקטיביות (פתיחת רשימה). לתצוגת קריאה Word גם הוא מציג רק את הערך הנבחר אלא אם לוחצים. נאמן לתצוגה הסטטית; ללא dropdown. | `inline_parser.dart:154‑165` |
| 10 | טיפוס `w:date` (@fullDate, format) | חלקי | נאמן~ | טקסט התאריך ה**מעוצב** מאוחסן ב‑`sdtContent` ומרונדר כפי שהוא. `@w:fullDate` (הערך הקנוני) ו‑`@w:dateFormat`/`calendar`/`lid` **לא נקראים** — אין עיצוב מחדש. מאחר שהטקסט המוצג כבר מעוצב ע"י Word, התצוגה הסטטית נאמנה; לא מתעדכן ל"היום". | `inline_parser.dart:154‑165` |
| 11 | טיפוס `w:picture` | כן | תלוי משימה 09 | ה‑`w:drawing`/`w:pict` שבתוך ה‑`sdtContent` עובר במסלול הציורים הרגיל (משימה 09). עטיפת ה‑SDT שקופה; נאמנות התמונה = נאמנות משימה 09. | `inline_parser.dart:154‑165`; רינדור: משימה 09 |
| 12 | טיפוס `w:checkbox` (w14 — checkedState/uncheckedState font+char) | חלקי | **לא** (מבני) / נאמן~ (סטטי) | הגליף הנוכחי (☒/☐) מאוחסן ב‑`sdtContent` ומרונדר — כך שמצב התיבה הנראה **כן** מוצג. אך **`w14:checkbox`/`w14:checked`/`w14:checkedState`/`w14:uncheckedState` (font+char) אינם נקראים** בצד הצופה: אין מיפוי דינמי, וגליף מותאם בפונט סמלים ספציפי (למשל MS Gothic char 2612) תלוי בזמינות הפונט/מיפוי `w:sym` (משימה 10 פריט 7) — אם לא ממופה, ייתכן גליף שגוי. אין החלפת מצב (read‑only — תקין). הצד הכותב (`DocxCheckbox`) **כן** פולט w14:checkbox — לא רלוונטי לצופה. | קריאה: `inline_parser.dart:154‑165` (אין פענוח w14); כתיבה בלבד: `docx_inline.dart:1310‑1380` |
| 13 | טיפוס `w:docPartObj` / `w:docPartList` | חלקי | נאמן | מקרה יחיד עם טיפול מיוחד: `docPartObj` שה‑`docPartGallery` שלו `="Table of Contents"` → `DocxTableOfContents` (הרחבה למסלול ה‑TOC, משימה 10 פריט 21). כל שאר ה‑galleries וכן `docPartList` → unwrap רגיל של `sdtContent`. התוכן השמור מרונדר נאמן. | `block_parser.dart:138‑160` (TOC); אחרת `:161‑164` |
| 14 | טיפוס `w:group` | כן | נאמן | אין טיפול ייעודי — ה‑`sdtContent` של הקבוצה (שעשוי להכיל כמה בלוקים/ריצות נעולים יחד) נפרק כתוכן רגיל. ויזואלית זהה ל‑Word (הקיבוץ הוא נעילת עריכה בלבד). | `block_parser.dart:161‑164` / `inline_parser.dart:154‑165` |
| 15 | טיפוסים `w:bibliography` / `w:citation` / `w:equation` | חלקי | נאמן~ (ביבליוגרפיה/ציטוט) / **לא** (נוסחה) | `bibliography`/`citation`: טקסט הציטוט המעוצב שב‑`sdtContent` מרונדר רגיל — נאמן כתצוגה סטטית (לא מחושב מחדש ממקור הציטוטים). `equation`: עוטף OMML → עובר לקיפול **טקסט ליניארי** בלבד (משימה 10 פריטים 43‑45, Plan §K.6) — מבנה הנוסחה אובד. | `inline_parser.dart:154‑165`; OMML: `inline_parser.dart:170‑176` |

### ב.2 — פערים והוראות ל‑AI הבא

**עיקרון מנחה (לא פער):** עטיפת ה‑SDT מטופלת כ**מכל שקוף** — שולפים `w:sdtContent` ומרנדרים כתוכן רגיל.
זו **התנהגות ברירת‑המחדל הנאמנה** של Word בקריאה (פקד תוכן ללא גבול/רקע). לכן רוב הפריטים נאמנים מעצם
ה‑unwrap, והפערים מתרכזים אך ורק בפקדים בעלי **לוגיקה דינמית** או בעטיפות SDT במיקומים שאינם נפרקים.

**פערים בעלי השלכה ויזואלית (לתעד/לשקול מימוש):**
- **`w14:checkbox` — מיפוי מצב דינמי (פריט 12).** הצופה אינו קורא `w14:checked`/`checkedState`/`uncheckedState`
  (font+char) ומסתמך על הגליף השמור ב‑`sdtContent`. בדרך‑כלל זה נאמן, אך גליף מותאם בפונט סמלים שאינו ממופה
  (משימה 10 פריט 7) עלול להופיע שגוי. מינימום: לזהות `w14:checkbox` ולמפות `checkedState/uncheckedState`
  (font+char) דרך אותו מנגנון `w:sym`/`SymbolFontMap`, עם fallback ל‑☒/☐.
- **קצה — SDT ברמת שורה/תא בטבלה (פריט 1).** `<w:sdt>` שעוטף `<w:tr>` (תחת `<w:tbl>`) או `<w:tc>` (תחת `<w:tr>`)
  **אינו נפרק** — איטרציית השורות/תאים מזהה רק `tr`/`tc`. תוצאה: שורה/תא עטופי‑SDT יושמטו. נדיר ב‑Word אך
  קל לתיקון: להוסיף unwrap של `sdt` בלולאות `table_parser.dart:203‑251`.
- **`w:placeholder`/`showingPlcHdr` — גוון אפור (פריטים 4‑5).** הטקסט מוצג (מ‑`sdtContent`) אך גוון ה‑placeholder
  האפור תלוי בפתרון סגנון התו `PlaceholderText` (כפילות עם משימה 07).

**Fallback מ‑cache במקום חישוב חי (מקובל לתצוגת קריאה — סטייה מודעת):**
- **`w:dataBinding` (פריט 6).** `customXml` לא נטען; הערך מגיע מ‑`sdtContent` השמור (תואם בקובץ סטטי).
- **`w:date` — `@fullDate`/`format` (פריט 10).** התאריך מוצג כטקסט שעוצב ע"י Word; לא מעוצב מחדש ולא מתעדכן.
- **`w:comboBox`/`dropDownList` — `listItem` (פריט 9).** רק הערך הנבחר; הרשימה לא אינטראקטיבית.
- **`w:equation` (פריט 15).** OMML מקופל לטקסט ליניארי בלבד (כמשימה 10, Plan §K.6).

**מטא‑דאטה ללא השפעה ויזואלית — אין פעולה נדרשת (פריטים 2,3,7):**
- `w:alias`/`w:tag`/`w:id` (לא נראים בתצוגת קריאה), `w:lock` (נעילת עריכה), `w:temporary` (הסרת עטיפה) —
  כולם ללא ביטוי ויזואלי בצופה; אי‑קריאתם תקינה.

### ב.3 — עדכון מימוש (בוצע ע"י ה‑AI המבצע, 2026‑06‑23)

> מבוצע לפי `PROMPTER.md`. בדיקות נלוות; `flutter analyze` נקי; סוויטות הטבלאות ירוקות.

**מומש 1:1:**

| פריט | מה תוקן | קובץ | בדיקה |
|---|---|---|---|
| 1 | SDT/customXml שעוטף `<w:tr>`/`<w:tc>` בטבלה — מפורק שקוף (`_unwrappedChildren`) כך שהשורה/התא אינם נשמטים | `table_parser.dart` | `table_properties_test.dart` |

**נותר נדחה / סטיות מודעות:** `w14:checkbox` מצב דינמי (12), `dataBinding`/customXml (6), placeholder אפור (4‑5), `date`/`comboBox` אינטראקטיביים (9,10), equation→טקסט (15) — סטיות מודעות (אינטראקטיביות/מטא‑דאטה; הצופה סטטי).
