# משימה 14 — הגדרות מסמך — `settings.xml`

> **מקור:** סעיף §14 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

הגדרות גלובליות שמשפיעות על רינדור כל המסמך:

| אלמנט | מה עושה | חשיבות לרינדור |
|---|---|---|
| `w:defaultTabStop @w:val` | מרווח טאב ברירת מחדל (twips, בד"כ 720) | גבוהה — טאבים לא מוגדרים |
| `w:evenAndOddHeaders` | header/footer שונים לעמודים זוגיים/אי‑זוגיים | גבוהה |
| `w:mirrorMargins` | שוליים מראתיים (הדפסת ספר) | גבוהה |
| `w:gutterAtTop` | gutter בראש העמוד | בינונית |
| `w:bookFoldPrinting` | הדפסת חוברת | בינונית |
| `w:proofState` | מצב בדיקת איות | אין |
| `w:defaultTableStyle` | סגנון טבלה ברירת מחדל | בינונית |
| `w:autoHyphenation` | מיקוף אוטומטי כללי | גבוהה (שבירת שורה) |
| `w:consecutiveHyphenLimit` | מקס' שורות עוקבות עם מקף | בינונית |
| `w:hyphenationZone` | אזור מיקוף (twips) | בינונית |
| `w:doNotHyphenateCaps` | אל תמקף מילים באותיות גדולות | נמוכה |
| `w:characterSpacingControl` | בקרת ריווח EA (doNotCompress/compressPunctuation/…) | בינונית (EA) |
| `w:drawingGridHorizontalSpacing`/`Vertical` | רשת ציור | נמוכה |
| `w:displayBackgroundShape` | הצג את `w:background` (רקע/סימן מים) | גבוהה |
| `w:documentProtection` | הגנת עריכה | אין (תצוגה) |
| `w:clrSchemeMapping` | מיפוי theme colors (§13.1) | גבוהה |
| `w:themeFontLang @w:val/@w:bidi/@w:eastAsia` | שפת ברירת מחדל לבחירת theme fonts | גבוהה (עברית) |
| `w:compat` → `w:compatSetting` | **דגלי תאימות** רבים שמשנים פריסה לפי גרסת Word | גבוהה — ראו למטה |
| `w:footnotePr`/`w:endnotePr` | מאפייני הערות גלובליים | בינונית |
| `w:defaultParagraphStyle`? | — | |

> **`w:compat`** מכיל עשרות `compatSetting` ודגלים (`doNotExpandShiftReturn`, `balanceSingleByteDoubleByteWidth`, `useWord2013TrackBottomHyphenation`, `splitPgBreakAndParaMark`, ועוד). חלקם משנים שבירת שורה/עמוד בצורה משמעותית. `compatibilityMode` (15=Word2013+) קובע מערך התנהגויות. מנוע 1:1 שמכוון לקבצים מודרניים יכול להניח mode 15, אך כדאי לקרוא דגלים קריטיים.

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:defaultTabStop` (twips, בד"כ 720) | | | | |
| 2 | `w:evenAndOddHeaders` | | | | |
| 3 | `w:mirrorMargins` | | | | |
| 4 | `w:gutterAtTop` | | | | |
| 5 | `w:bookFoldPrinting` | | | | |
| 6 | `w:proofState` | | | | |
| 7 | `w:defaultTableStyle` | | | | |
| 8 | `w:autoHyphenation` | | | | |
| 9 | `w:consecutiveHyphenLimit` | | | | |
| 10 | `w:hyphenationZone` | | | | |
| 11 | `w:doNotHyphenateCaps` | | | | |
| 12 | `w:characterSpacingControl` (EA) | | | | |
| 13 | `w:drawingGridHorizontalSpacing`/`Vertical` | | | | |
| 14 | `w:displayBackgroundShape` (תנאי להצגת רקע/סימן מים) | | | | |
| 15 | `w:documentProtection` | | | | |
| 16 | `w:clrSchemeMapping` (מיפוי theme colors) | | | | |
| 17 | `w:themeFontLang` (val/bidi/eastAsia — קריטי לעברית) | | | | |
| 18 | `w:compat` / `w:compatSetting` (דגלי תאימות) | | | | |
| 19 | `compatibilityMode` (15=Word2013+) | | | | |
| 20 | דגלי compat קריטיים (doNotExpandShiftReturn/splitPgBreakAndParaMark/useWord2013TrackBottomHyphenation/…) | | | | |
| 21 | `w:footnotePr` / `w:endnotePr` (גלובליים) | | | | |
| 22 | `w:defaultParagraphStyle` | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
