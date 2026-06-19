# משימה 07 — סגנונות — `styles.xml`

> **מקור:** סעיף §7 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

הקובץ מכיל: `w:docDefaults` (ברירות מחדל לכל המסמך), `w:latentStyles` (הגדרות ל‑built‑in styles לא‑מוגדרים), ורשימת `w:style`.

### 7.1 `w:docDefaults`

```xml
<w:docDefaults>
  <w:rPrDefault><w:rPr>…</w:rPr></w:rPrDefault>
  <w:pPrDefault><w:pPr>…</w:pPr></w:pPrDefault>
</w:docDefaults>
```

- **שכבת הבסיס** של כל עיצוב. כל פסקה/ריצה יורשת מכאן לפני כל סגנון. מכאן בא לרוב הפונט הבסיסי, גודל 22 (11pt), `widowControl`, ריווח שורה ברירת מחדל.

### 7.2 `w:style` — הגדרת סגנון

**תכונות:**

| תכונה | ערכים | מה עושה |
|---|---|---|
| `w:type` | paragraph / character / table / numbering | סוג הסגנון |
| `w:styleId` | מזהה | המזהה שאליו מפנים (`pStyle`/`rStyle`/`tblStyle`) |
| `w:default` | bool | האם זה ברירת המחדל לסוג שלו (חל כשאין הפניה מפורשת) |
| `w:customStyle` | bool | סגנון משתמש (לא built‑in) |

**ילדים מרכזיים:**

| אלמנט | מה עושה | קצה |
|---|---|---|
| `w:name` | שם תצוגה | יכול להבדל מ‑styleId (מיפוי שמות מקומיים) |
| `w:aliases` | שמות חלופיים | |
| `w:basedOn` | **סגנון אב** — ממנו יורשים | שרשרת ירושה; בלי מעגלים |
| `w:next` | סגנון הפסקה הבאה (אחרי Enter) | לא ויזואלי לרינדור קיים |
| `w:link` | קישור בין סגנון פסקה לסגנון תו תואם | "linked style" |
| `w:autoRedefine` | עדכן את הסגנון אוטומטית מעיצוב ידני | נדיר |
| `w:hidden` / `w:semiHidden` | הסתר מה‑UI | לא משפיע רינדור |
| `w:unhideWhenUsed` | הצג אחרי שימוש | |
| `w:uiPriority` | סדר מיון ב‑UI | |
| `w:qFormat` | סגנון "מומלץ" (כותרות) | |
| `w:locked` | אי‑אפשר להחיל | |
| `w:rsid` | מזהה גרסה | |
| `w:pPr` | מאפייני פסקה של הסגנון | |
| `w:rPr` | מאפייני ריצה של הסגנון | |
| `w:tblPr`/`w:trPr`/`w:tcPr` | מאפייני טבלה/שורה/תא (לסגנון טבלה) | |
| `w:tblStylePr` | עיצוב מותנה (§6.5) | רק type=table |

### 7.3 שרשרת הירושה וה‑resolution

עבור פסקה רגילה, סדר ההצטברות (כל שכבה דורסת/מצטברת על הקודמת):

1. `docDefaults` (pPrDefault + rPrDefault)
2. שרשרת `basedOn` של סגנון הפסקה — **מהשורש כלפי מטה** (הסגנון הבסיסי ביותר ראשון)
3. סגנון הפסקה עצמו (`pStyle`)
4. (לריצה) שרשרת סגנון התו (`rStyle`)
5. עיצוב ישיר (`pPr`/`rPr` בתוך הפסקה/ריצה)

> פירוט מלא כולל טבלאות, מספור ו‑toggle: ראו §16.

### 7.4 `w:latentStyles`

```xml
<w:latentStyles w:defLockedState="0" w:defUIPriority="99"
                w:defSemiHidden="1" w:defUnhideWhenUsed="1" w:defQFormat="0"
                w:count="376">
  <w:lsdException w:name="Normal" w:semiHidden="0" w:uiPriority="0" w:qFormat="1"/>
  …
</w:latentStyles>
```

מגדיר התנהגות ל‑built‑in styles שלא הוגדרו מפורשות במסמך. בעיקר משפיע על ה‑UI; לרינדור — רלוונטי רק אם סגנון מופיע ב‑latent ולא בהגדרה מלאה.

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:docDefaults` — `rPrDefault` | | | | |
| 2 | `w:docDefaults` — `pPrDefault` | | | | |
| 3 | `w:style` — `type` (paragraph/character/table/numbering) | | | | |
| 4 | `w:style` — `styleId` | | | | |
| 5 | `w:style` — `default` (ברירת מחדל לסוג) | | | | |
| 6 | `w:style` — `customStyle` | | | | |
| 7 | `w:name` (שם תצוגה ≠ styleId) | | | | |
| 8 | `w:aliases` | | | | |
| 9 | `w:basedOn` (שרשרת ירושה, ללא מעגלים) | | | | |
| 10 | `w:next` | | | | |
| 11 | `w:link` (linked style פסקה↔תו) | | | | |
| 12 | `w:autoRedefine` | | | | |
| 13 | `w:hidden` / `w:semiHidden` | | | | |
| 14 | `w:unhideWhenUsed` | | | | |
| 15 | `w:uiPriority` | | | | |
| 16 | `w:qFormat` | | | | |
| 17 | `w:locked` | | | | |
| 18 | `w:rsid` | | | | |
| 19 | `w:pPr` של סגנון | | | | |
| 20 | `w:rPr` של סגנון | | | | |
| 21 | `w:tblPr`/`w:trPr`/`w:tcPr` (סגנון טבלה) | | | | |
| 22 | `w:tblStylePr` (עיצוב מותנה — type=table) | | | | |
| 23 | שרשרת resolution: docDefaults → basedOn (מהשורש) → pStyle → rStyle → ישיר | | | | |
| 24 | `w:latentStyles` (+`lsdException`) — השפעה על רינדור כשאין הגדרה מלאה | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
