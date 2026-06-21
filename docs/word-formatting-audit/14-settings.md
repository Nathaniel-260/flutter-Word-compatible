# משימה 14 — הגדרות מסמך — `settings.xml`

> **מקור:** סעיף §14 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-21

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

> **מפת המימוש (החלטה מרכזית: נקראים 4 פריטים בלבד מתוך עשרות):**
> קובץ `settings.xml` נקרא ב‑`docx_reader.dart:213` (ונשמר גם כ‑raw `settingsXml` לשימור re‑export).
> **הפַּרסר היחיד** הוא `DocxReader.parseSettings` (`docx_reader.dart:39‑58`), והוא מחלץ **בדיוק ארבעה** פריטים:
> `w:evenAndOddHeaders`, `w:defaultTabStop`, `w:footnotePr`, `w:endnotePr`. **כל שאר עשרות האלמנטים** ב‑`CT_Settings`
> (compat, hyphenation, mirrorMargins, clrSchemeMapping, themeFontLang, displayBackgroundShape, …) **מתעלמים בשתיקה**.
> - **evenAndOddHeaders:** `readOnOff` (`docx_reader.dart:48`, מכבד `w:val="false"`) → נצרך `docx_widget_generator.dart:668` (`isEvenPage`) ו‑`page_model.dart:161`.
> - **defaultTabStop:** נקרא (`docx_reader.dart:49‑51`) ונשמר ל‑`DocxBuiltDocument.defaultTabStop`, **אך לא מחווט למנוע הטאבים** — `paragraph_builder.dart:452` בונה `const TabEngine()` (720 קשיח), ו‑`ParagraphBuilder` אף לא מקבל את הערך.
> - **footnotePr/endnotePr:** `SectionParser.parseNoteProperties` (`section_parser.dart:291`) → נצרך `paginator.dart:470‑472` כברירת‑מחדל מסמך (נדרסת פר‑מקטע בשורה 641).
> - **w:background:** צבע רקע העמוד נקרא ב‑`docx_reader.dart:194‑200` ומוצג **תמיד** (`docx_widget_generator.dart:919`) — **ללא** בדיקת `displayBackgroundShape`.
> בדיקות קיימות: `docx_creator/test/settings_parsing_test.dart` (4 הפריטים הנתמכים בלבד).

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:defaultTabStop` (twips, בד"כ 720) | חלקי | **לא** | כל תו טאב שאינו ממוקם ע"י tab‑stop מפורש מתיישר למרווח הקבוע `defaultTabStop` (ברירת‑מחדל 720tw=½"). מסמך שמגדיר ערך אחר (למשל 480) → **כל** הטאבים הלא‑מפורשים בכל המסמך מתיישרים אחרת. | נקרא `docx_reader.dart:49‑51`, נשמר `DocxBuiltDocument.defaultTabStop`. **אך** `paragraph_builder.dart:452` = `const TabEngine()` → 720 קשיח. נאמן רק כשהמסמך משתמש ב‑720 |
| 2 | `w:evenAndOddHeaders` | כן | נאמן | כשהדגל פעיל, עמודים זוגיים מקבלים את גרסת ה‑header/footer מסוג `evenPage` (אחרת כל העמודים משתמשים ב‑default). הדגל הוא toggle — `w:val="false"` מבטל. | `readOnOff` `docx_reader.dart:48`; נצרך `docx_widget_generator.dart:668` (`isEvenPage`), `page_model.dart:161`; בדיקה `settings_parsing_test.dart:26‑36` |
| 3 | `w:mirrorMargins` | **לא** | **לא** | שוליים פנים/חוץ מתחלפים בין עמוד זוגי לאי‑זוגי (כריכת ספר) — השול הפנימי (gutter) זהה בשני הצדדים, החיצוני זהה. | לא נקרא; השוליים מיושמים סימטרית תמיד. פוגע במסמכי דפוס דו‑צדדי |
| 4 | `w:gutterAtTop` | **לא** | **לא**~ | שולי הכריכה (gutter) ממוקמים בראש העמוד במקום בצדו. | לא נקרא; gutter עצמו אינו ממומש כלל (ראה §5), ועל אחת כמה וכמה מיקומו. נדיר |
| 5 | `w:bookFoldPrinting` | **לא** | **לא** | סידור עמודים להדפסת חוברת מקופלת (imposition). | לא נקרא; פריסת חוברת אינה ממומשת. זניח בתצוגת מסך |
| 6 | `w:proofState` | **לא** | n/a | מצב בדיקת איות/דקדוק — **אין כל ביטוי ויזואלי** בתצוגה. | אין (מכוון — נכון להתעלם) |
| 7 | `w:defaultTableStyle` | **לא** | **לא** | טבלה ללא `w:tblStyle` מקבלת את הסגנון הזה כברירת‑מחדל (בד"כ `TableNormal`). | לא נקרא; טבלאות ללא סגנון מקבלות ברירות‑מחדל קשיחות (ראה §6/§7) במקום הסגנון המוגדר. משפיע על גבולות/ריווח ברירת‑מחדל |
| 8 | `w:autoHyphenation` | **לא** | **לא** | מיקוף אוטומטי שובר מילים בקצה השורה ומוסיף מקף → **שינוי מהותי** בשבירת שורות וב‑justify (יותר תווים לשורה). | לא נקרא; המנוע **לעולם אינו ממקף**. במסמך עם מיקוף פעיל הטקסט יגלוש אחרת מ‑Word |
| 9 | `w:consecutiveHyphenLimit` | **לא** | n/a | מגביל שורות עוקבות המסתיימות במקף — תלוי במיקוף שאינו קיים. | אין (תלוי בפריט 8) |
| 10 | `w:hyphenationZone` | **לא** | n/a | רוחב האזור הימני שבו מותר למקף — תלוי במיקוף שאינו קיים. | אין (תלוי בפריט 8) |
| 11 | `w:doNotHyphenateCaps` | **לא** | n/a | מונע מיקוף מילים באותיות גדולות — תלוי במיקוף שאינו קיים. | אין (תלוי בפריט 8) |
| 12 | `w:characterSpacingControl` (EA) | **לא** | **לא**~ | בקרת דחיסת ריווח בין תווי EA/פיסוק (`doNotCompress`/`compressPunctuation`/`compressPunctuationAndJapaneseKana`). | לא נקרא; רלוונטי בעיקר ל‑CJK — השפעה זניחה בעברית/לטינית |
| 13 | `w:drawingGridHorizontalSpacing`/`Vertical` | **לא** | n/a | רשת עזר ל‑snap של ציורים — השפעה ויזואלית מינורית מאוד; בד"כ נכון להתעלם. | אין (מכוון) |
| 14 | `w:displayBackgroundShape` (תנאי להצגת רקע/סימן מים) | **לא** | **חלקי** | ב‑Word, `w:background` (צבע/תמונת רקע עמוד) מוצג ב‑Print Layout **רק** אם `displayBackgroundShape` קיים; בלעדיו הרקע נשמר אך **אינו** מוצג. | המנוע קורא את צבע `w:background` (`docx_reader.dart:194‑200`) ומציג אותו **תמיד** (`docx_widget_generator.dart:919`) ללא בדיקת הדגל → **over‑display**: רקע יוצג גם כשב‑Word היה לבן. סימני מים/תמונות רקע — §15 |
| 15 | `w:documentProtection` | **לא** | n/a | הגנת עריכה — **אין השפעה על התצוגה** (רק על עריכה). | אין (מכוון — נכון להתעלם) |
| 16 | `w:clrSchemeMapping` (מיפוי theme colors) | **לא** | **לא** | ממפה את צבעי ה‑theme לתפקידים (`tx1`/`bg1`/…); שינוי המיפוי משנה לאיזה צבע theme מתייחס כל תפקיד. | לא נקרא; פתרון `themeColor` משתמש במיפוי ברירת‑מחדל קבוע. מסמך עם מיפוי לא‑סטנדרטי → צבעי theme שגויים. תלוי §13 |
| 17 | `w:themeFontLang` (val/bidi/eastAsia — קריטי לעברית) | **לא** | **לא** | קובע את שפת ברירת‑המחדל לבחירת פונט theme; `@bidi` בוחר את גרסת ה‑complex‑script (Hebr) של `minorFont`/`majorFont`. **קריטי לעברית** — שולט באיזה פונט theme נבחר לטקסט עברי. | לא נקרא; בחירת פונט ה‑theme (§13) אינה מתחשבת ב‑`themeFontLang` → עלול להיבחר סקריפט/פונט לא‑נכון |
| 18 | `w:compat` / `w:compatSetting` (דגלי תאימות) | **לא** | **חלקי** | עשרות דגלים המשנים פריסה לפי גרסת Word (שבירת שורה/עמוד, ריווח). | לא נקרא כלל; המנוע מתנהג כמנוע מודרני יחיד ללא קריאת אף דגל |
| 19 | `compatibilityMode` (15=Word2013+) | **לא** | **חלקי** | קובע מערך התנהגויות פריסה; mode נמוך (2003/2007) משנה line‑spacing ושבירות. | לא נקרא; המנוע מניח התנהגות מודרנית קבועה (מעין mode 15) |
| 20 | דגלי compat קריטיים (doNotExpandShiftReturn/splitPgBreakAndParaMark/useWord2013TrackBottomHyphenation/…) | **לא** | **חלקי** | כל אחד משנה התנהגות שבירה/ריווח ספציפית. | לא נקראים; השפעה בעיקר במסמכים ישנים/חריגים |
| 21 | `w:footnotePr` / `w:endnotePr` (גלובליים) | כן | נאמן | ברירות‑מחדל גלובליות לפורמט המספור/מיקום/איפוס של הערות שוליים וסיום, הניתנות לדריסה ב‑`sectPr`. | `parseNoteProperties` `section_parser.dart:291`; נצרך `paginator.dart:470‑472` (`_docFootnoteProps`/`_docEndnoteProps`), נדרס פר‑מקטע בשורה 641. רינדור ההערות עצמן — §10; בדיקה `settings_parsing_test.dart:38‑47` |
| 22 | `w:defaultParagraphStyle` | **לא** (מ‑settings) | n/a | אין אלמנט כזה ב‑`CT_Settings` תקני (במסמך הייחוס מסומן ב‑"?"). שדה `defaultParagraphStyle` שבקוד מגיע מ‑`styles.xml`/`docDefaults` (§07), **לא** מ‑`settings.xml`. | `style_parser.dart:62‑66` (מקור = docDefaults, לא settings) |

### ב.2 — פערים והוראות ל‑AI הבא

**מה ממומש ונאמן:**
- **`evenAndOddHeaders` (פריט 2)** — מלא ונאמן, כולל כיבוי ב‑`w:val="false"` והזרמה לבחירת גרסת ה‑header/footer הזוגית.
- **`footnotePr`/`endnotePr` גלובליים (פריט 21)** — נקראים ומחווטים כברירת‑מחדל מסמך להערות (פורמט/מיקום/איפוס), נדרסים פר‑מקטע. רינדור ההערות — §10.

**פער מימוש עיקרי — `defaultTabStop` מנותח אך לא מחווט (פריט 1):**
- הערך נקרא ונשמר ל‑`DocxBuiltDocument.defaultTabStop`, אך `paragraph_builder.dart:452` בונה `const TabEngine()` (720 קשיח) ו‑`ParagraphBuilder` אף אינו מקבל את הערך. **לתקן:** להעביר את `doc.defaultTabStop` אל `ParagraphBuilder` ולבנות `TabEngine(defaultTabStopTwips: doc.defaultTabStop)`. **השפעה:** כל מסמך עם `defaultTabStop≠720` — כל הטאבים שאינם ממוקמים ב‑tab‑stop מפורש שגויים.

**פערים המשפיעים על נאמנות (לפי עדיפות):**
- **`displayBackgroundShape` לא נבדק (פריט 14):** `w:background` מוצג תמיד; Word מציג רק כשהדגל קיים → over‑display. לתקן: לקרוא את הדגל ב‑`parseSettings` ולגזור `backgroundColor` רק כשהוא קיים.
- **`themeFontLang` (פריט 17) + `clrSchemeMapping` (פריט 16):** בחירת פונט/צבע theme אינה מתחשבת בהם — **קריטי לעברית** ולמסמכים עם מיפוי לא‑סטנדרטי. תלוי במימוש §13.
- **`autoHyphenation` + נלווים (פריטים 8‑11):** אין מיקוף כלל → שבירת שורות שונה מ‑Word במסמכים עם מיקוף פעיל.
- **`mirrorMargins` (פריט 3):** שוליים מראתיים לא ממומשים → שוליים שגויים במסמכי כריכה דו‑צדדיים.
- **`defaultTableStyle` (פריט 7):** טבלאות ללא סגנון מקבלות ברירות‑מחדל קשיחות במקום הסגנון המוגדר.

**סטיות מודעות (תיעוד בלבד — ללא/כמעט‑ללא ביטוי ויזואלי):**
- `proofState` (6), `documentProtection` (15), `drawingGrid` (13) — אין ביטוי בתצוגה.
- `defaultParagraphStyle` (22) — אינו אלמנט `settings` תקני; המקור האמיתי הוא docDefaults (§07).
- `compat`/`compatibilityMode`/דגלי תאימות (18‑20) — המנוע מכוון לקבצים מודרניים; להתייחס רק אם יתגלה מסמך ישן עם פריסה שונה.
- `characterSpacingControl` (12), `bookFoldPrinting` (5), `gutterAtTop` (4) — נדירים/EA, עדיפות נמוכה.
