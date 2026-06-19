# משימה 11 — פקדי תוכן — Structured Document Tags (SDT)

> **מקור:** סעיף §11 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —

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

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:sdt` בלוק/inline + `w:sdtContent` (רינדור כתוכן רגיל) | | | | |
| 2 | `w:alias` / `w:tag` / `w:id` | | | | |
| 3 | `w:lock` (sdtLocked/contentLocked/sdtContentLocked/unlocked) | | | | |
| 4 | `w:placeholder` (+`w:docPart`) | | | | |
| 5 | `w:showingPlcHdr` | | | | |
| 6 | `w:dataBinding` (xpath/storeItemID) | | | | |
| 7 | `w:temporary` | | | | |
| 8 | טיפוס `w:text` / `w:richText` | | | | |
| 9 | טיפוס `w:comboBox` / `w:dropDownList` (+`listItem`) | | | | |
| 10 | טיפוס `w:date` (@fullDate, format) | | | | |
| 11 | טיפוס `w:picture` | | | | |
| 12 | טיפוס `w:checkbox` (w14 — checkedState/uncheckedState font+char) | | | | |
| 13 | טיפוס `w:docPartObj` / `w:docPartList` | | | | |
| 14 | טיפוס `w:group` | | | | |
| 15 | טיפוסים `w:bibliography` / `w:citation` / `w:equation` | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
