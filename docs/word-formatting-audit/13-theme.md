# משימה 13 — ערכת עיצוב — `theme1.xml` (צבעים ופונטים)

> **מקור:** סעיף §13 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

מגדיר את הצבעים והפונטים ש‑`themeColor`/`asciiTheme` מפנים אליהם.

### 13.1 ערכת צבעים — `a:clrScheme`

```xml
<a:clrScheme name="Office">
  <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
  <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
  <a:dk2><a:srgbClr val="44546A"/></a:dk2>
  <a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>
  <a:accent1>…</a:accent1> … <a:accent6>…</a:accent6>
  <a:hlink>…</a:hlink><a:folHlink>…</a:folHlink>
</a:clrScheme>
```

**מיפוי שמות (חשוב!):** ב‑WordprocessingML המיפוי בין `ST_ThemeColor` ל‑slots של ה‑theme אינו 1:1 ישיר — הוא עובר דרך `w:clrSchemeMapping` ב‑settings.xml:

| ST_ThemeColor (במסמך) | סלוט ב‑theme (בד"כ) |
|---|---|
| `text1` / `dark1` | dk1 |
| `background1` / `light1` | lt1 |
| `text2` / `dark2` | dk2 |
| `background2` / `light2` | lt2 |
| `accent1`–`accent6` | accent1–6 |
| `hyperlink` | hlink |
| `followedHyperlink` | folHlink |

> `a:sysClr` (windowText/window) נושא `lastClr` — צבע מטמון אחרון; מנוע יכול להשתמש בו ישירות.

### 13.2 ערכת פונטים — `a:fontScheme`

```xml
<a:fontScheme name="Office">
  <a:majorFont>
    <a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/>
    <a:font script="Hebr" typeface="David"/>      <!-- fallback פר-כתב -->
    <a:font script="Arab" typeface="…"/> …
  </a:majorFont>
  <a:minorFont> … </a:minorFont>
</a:fontScheme>
```

| הפניה ב‑rFonts | מקור |
|---|---|
| `majorHAnsi`/`majorAscii`/`majorBidi`/`majorEastAsia` | `majorFont` (כותרות) — latin/cs/ea בהתאמה |
| `minorHAnsi`/`minorAscii`/`minorBidi`/`minorEastAsia` | `minorFont` (גוף הטקסט) |

> **קריטי לעברית:** `a:font script="Hebr"` ב‑fontScheme נותן את פונט ברירת המחדל לעברית כש‑rFonts מפנה ל‑theme. ה‑`<a:cs>` ו‑script="Hebr" הם המקור לפונט CS.

### 13.3 `a:fmtScheme`

הגדרות מילוי/קו/אפקט לצורות (`fillStyleLst`, `lnStyleLst`, `effectStyleLst`, `bgFillStyleLst`). רלוונטי רק לצורות שמפנות ל‑theme דרך `wps:style`.

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `a:clrScheme` — dk1/lt1/dk2/lt2 | | | | |
| 2 | `a:clrScheme` — accent1–accent6 | | | | |
| 3 | `a:clrScheme` — hlink/folHlink | | | | |
| 4 | `a:sysClr` (windowText/window) + `lastClr` | | | | |
| 5 | `a:srgbClr` | | | | |
| 6 | מיפוי `ST_ThemeColor`→slot דרך `w:clrSchemeMapping` | | | | |
| 7 | `a:fontScheme` — `majorFont` (latin/ea/cs) | | | | |
| 8 | `a:fontScheme` — `minorFont` (latin/ea/cs) | | | | |
| 9 | `a:font script="Hebr"` (fallback פר‑כתב — קריטי לעברית) | | | | |
| 10 | `a:font script="…"` נוספים (Arab וכו') | | | | |
| 11 | הפניות `majorHAnsi/Ascii/Bidi/EastAsia` | | | | |
| 12 | הפניות `minorHAnsi/Ascii/Bidi/EastAsia` | | | | |
| 13 | `a:fmtScheme` (fillStyleLst/lnStyleLst/effectStyleLst/bgFillStyleLst — לצורות) | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
