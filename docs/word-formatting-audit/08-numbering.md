# משימה 08 — מספור ורשימות — `numbering.xml`

> **מקור:** סעיף §8 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

שני רבדים: `w:abstractNum` (תבנית הרשימה) ו‑`w:num` (מופע שמצביע ל‑abstract, עם דריסות אפשריות). פסקה מצביעה ל‑`numId` של `w:num` דרך `numPr`.

```xml
<w:numbering>
  <w:abstractNum w:abstractNumId="0">
    <w:multiLevelType w:val="hybridMultilevel"/>
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/>
      <w:numFmt w:val="decimal"/>
      <w:lvlText w:val="%1."/>
      <w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>
      <w:rPr><w:rFonts w:hint="default"/></w:rPr>
    </w:lvl>
    <w:lvl w:ilvl="1">…</w:lvl>  <!-- עד ilvl=8 -->
  </w:abstractNum>
  <w:num w:numId="1">
    <w:abstractNumId w:val="0"/>
    <w:lvlOverride w:ilvl="0"><w:startOverride w:val="5"/></w:lvlOverride>
  </w:num>
</w:numbering>
```

### 8.1 `w:abstractNum` (תבנית)

| אלמנט/תכונה | מה עושה |
|---|---|
| `@w:abstractNumId` | מזהה התבנית |
| `w:nsid` | מזהה ייחוס יציב (לסנכרון רשימות) |
| `w:multiLevelType` | singleLevel / multilevel / hybridMultilevel | סוג ההיררכיה |
| `w:tmpl` | קוד תבנית | |
| `w:numStyleLink` | מפנה לסגנון מספור (numbering style) | |
| `w:styleLink` | מסמן שזו ההגדרה של סגנון מספור | |
| `w:lvl` | הגדרת רמה (×9, ilvl 0–8) | |

### 8.2 `w:lvl` (רמה)

| אלמנט/תכונה | ערכים | מה עושה |
|---|---|---|
| `@w:ilvl` | 0–8 | מספר הרמה |
| `@w:tplc` | קוד תבנית לרמה | |
| `@w:tentative` | bool | רמה "זמנית" (Word עשוי להחליפה) |
| `w:start` | int | ערך התחלה |
| `w:numFmt` | ST_NumberFormat | פורמט הספרה ([§17.6](17-enums.md)). `bullet`=תבליט, `none`=ללא מספר |
| `w:lvlRestart` | int | אפס את הרמה כשרמה X מתקדמת (0=אף פעם) |
| `w:pStyle` | styleId | קושר רמה לסגנון פסקה |
| `w:isLgl` | toggle | הצג את כל הרמות כספרות ערביות (מספור "legal" 1.1.1) |
| `w:suff` | tab / space / nothing | מה בין המספר לטקסט (ברירת מחדל tab) |
| `w:lvlText` | מחרוזת עם `%1`–`%9` | **תבנית הטקסט** של התווית. `%1`=ערך רמה 0, `%2`=רמה 1... למשל `%1.%2.` |
| `w:lvlPicBulletId` | int | תבליט תמונה (מפנה ל‑numPicBullet) |
| `w:legacy` | legacy, legacySpace, legacyIndent | התנהגות מספור ישנה (Word 6) |
| `w:lvlJc` | left/center/right (start/end) | יישור התווית |
| `w:pPr` | מאפייני פסקה לרמה (בעיקר `ind` — ההזחה!) | |
| `w:rPr` | מאפייני ריצה ל**תווית** (גופן/גודל של המספר/תבליט) | |

> **`lvlText` ו‑bullet:** ברשימת תבליטים, `numFmt="bullet"` ו‑`lvlText` מכיל את תו התבליט (למשל `` עם פונט Symbol/Wingdings ב‑rPr). מנוע חייב למפות את התו לפונט הנכון.

### 8.3 `w:num` (מופע) ו‑`w:lvlOverride`

| אלמנט/תכונה | מה עושה |
|---|---|
| `@w:numId` | המזהה שאליו `numPr/numId` מפנה |
| `w:abstractNumId` | מצביע לתבנית |
| `w:lvlOverride` | דריסה פר‑רמה למופע הזה: `w:startOverride` (ערך התחלה חדש) או `w:lvl` מלא (החלפת הגדרת הרמה) |

> **`startOverride`** מאפשר ל‑3 פסקאות עם אותו abstractNum להתחיל ממספרים שונים (numId שונה, abstract זהה). קריטי ל"המשך מספור" מול "התחל מחדש".

### 8.4 `w:numPicBullet`

תבליט שהוא תמונה: `<w:numPicBullet w:numPicBulletId="0"><w:pict>…VML…</w:pict></w:numPicBullet>`.

### 8.5 חישוב המספור (התנהגות מנוע)

- המספור הוא **stateful וגלובלי בסדר המסמך**: צריך מעבר אחד על כל הפסקאות בסדר, לתחזק מונה פר‑(numId, ilvl).
- כניסה לרמה עמוקה יותר ואז חזרה — מפעילה `lvlRestart`.
- פסקה עם `numId="0"` שוברת רצף (אין מספר).
- `isLgl` כופה את כל ה‑`%n` להופיע כעשרוני גם אם רמות אחרות מוגדרות אחרת.

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `@w:abstractNumId` | | | | |
| 2 | `w:nsid` | | | | |
| 3 | `w:multiLevelType` (singleLevel/multilevel/hybridMultilevel) | | | | |
| 4 | `w:tmpl` | | | | |
| 5 | `w:numStyleLink` | | | | |
| 6 | `w:styleLink` | | | | |
| 7 | `w:lvl` (×9, ilvl 0–8) | | | | |
| 8 | `@w:ilvl` | | | | |
| 9 | `@w:tplc` | | | | |
| 10 | `@w:tentative` | | | | |
| 11 | `w:start` (ערך התחלה) | | | | |
| 12 | `w:numFmt` (ST_NumberFormat, כולל bullet/none/hebrew1/2) | | | | |
| 13 | `w:lvlRestart` | | | | |
| 14 | `w:pStyle` (קישור רמה לסגנון) | | | | |
| 15 | `w:isLgl` (מספור legal — כל הרמות עשרוני) | | | | |
| 16 | `w:suff` (tab/space/nothing) | | | | |
| 17 | `w:lvlText` (תבנית %1–%9) | | | | |
| 18 | `w:lvlPicBulletId` | | | | |
| 19 | `w:legacy` (legacy/legacySpace/legacyIndent) | | | | |
| 20 | `w:lvlJc` (יישור תווית) | | | | |
| 21 | `w:pPr` של הרמה (בעיקר `ind` — הזחה) | | | | |
| 22 | `w:rPr` של התווית (גופן/גודל של מספר/תבליט) | | | | |
| 23 | מיפוי תו תבליט לפונט הנכון (Symbol/Wingdings) | | | | |
| 24 | `@w:numId` (`w:num`) | | | | |
| 25 | `w:abstractNumId` (מ‑num לתבנית) | | | | |
| 26 | `w:lvlOverride` — `startOverride` | | | | |
| 27 | `w:lvlOverride` — `w:lvl` מלא (החלפת רמה) | | | | |
| 28 | `w:numPicBullet` (תבליט תמונה VML) | | | | |
| 29 | חישוב מספור **stateful גלובלי** (מונה פר‑numId/ilvl) | | | | |
| 30 | `lvlRestart` בעת חזרה מרמה עמוקה | | | | |
| 31 | `numId="0"` שובר רצף | | | | |
| 32 | `isLgl` כופה `%n` עשרוני | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
