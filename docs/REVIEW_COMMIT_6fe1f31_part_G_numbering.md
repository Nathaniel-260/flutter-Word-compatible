# סקירת קומיט 6fe1f31 — חלק G: רשימות ומספור 1:1 (NumberingResolver גלובלי)

> מסמך חקירה ובדיקה שנכתב ב‑2026‑06‑15. הקומיט הנסקר הוא ה‑HEAD הנוכחי על ענף `main`.

---

## 1. מה הקומיט עושה (תקציר)

הקומיט מממש את **חלק G** מתוכנית הנאמנות ל‑Word: מנוע מספור־רשימות **גלובלי**.
עד כה כל `DocxList` חישב את סימני המספור **בנפרד**, ולכן רשימה שנקטעה בפסקה רגילה
וממשיכה — או אותו `numId` שמופיע בשני מקומות, או רשימה בתוך תא טבלה — **אתחלה**
את המונה במקום להמשיך כמו Word. הפתרון: מחלקה חדשה `NumberingResolver` שעושה
**מעבר אחד בסדר המסמך** על כל הבלוקים (כולל רקורסיה לתאי טבלה), שומרת מונה אחד
פר‑`(numId, ilvl)`, ומפיקה את מחרוזת הסימן הסופית לכל פריט — **לפי זהות האובייקט,
ללא שינוי ה‑AST**.

| מדד | ערך |
|---|---|
| Author / Date | נתנאל_26 · Mon Jun 15 11:37:22 2026 +0300 |
| קבצים | 11 (1 חדש בליבה, 2 חדשי־בדיקות) |
| שורות | +793 / −70 |
| Co‑Author | Claude Opus 4.8 |

---

## 2. שינויים קובץ‑אחר‑קובץ

### ליבת הפתרון (חדש)
- **[numbering_resolver.dart](../packages/docx_file_viewer/lib/src/layout/numbering_resolver.dart)** (267 שורות, חדש) —
  `NumberingResolver` + פונקציות פורמט משותפות (`composeListLabel`, `expandLvlText`,
  `formatNumberComponent`, `orderedMarkerWithCascade`). מעבר בסדר מסמך, story עצמאי
  לכל header/footer/footnote/endnote, כללי restart + `w:lvlRestart`.

### הרחבת ה‑AST והקורא (תוספת בלבד — תאימות לאחור נשמרת)
- **[docx_list.dart](../packages/docx_creator/lib/src/ast/docx_list.dart)** — שדות חדשים על
  `DocxListLevel`: `numFmtRaw`, `isLgl`, `suff`, `lvlJc`, `lvlRestart` (כולם עם ברירת מחדל).
- **[docx_theme.dart](../packages/docx_creator/lib/src/reader/docx_reader/models/docx_theme.dart)** —
  אותם שדות על `DocxNumberingLevel` + עדכון `copyWith`.
- **[numbering_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/numbering_parser.dart)** —
  פענוח `w:isLgl`/`w:suff`/`w:lvlJc`/`w:lvlRestart`.
- **[block_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/block_parser.dart)** —
  השחלת השדות + `numFmtRaw` ל‑`DocxListLevel`.
- **[number_formatter.dart](../packages/docx_creator/lib/src/core/number_formatter.dart)** —
  פורמטים חדשים `decimalZero` (ריפוד אפס) ו‑`ordinal` (1st/2nd/3rd, אנגלית).

### חיווט ל‑renderer
- **[docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart)** —
  `_initBuilders` מחשב `NumberingResolver().resolveDocument(doc)` פעם אחת ומזין ל‑`ListBuilder`.
- **[list_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/list_builder.dart)** —
  שדה `numberLabels`; כשהמפה קיימת התווית מהרזולבר היא הסמכות. הלוגיקה הכפולה
  (`_expandLvlText`/`_formatComponent`/`_getOrderedMarker`) **נמחקה** והוחלפה באצילה
  לפונקציות המשותפות ברזולבר. כיבוד `suff`/`lvlJc` בפריסה.

### בדיקות ותיעוד
- **[numbering_level_extras_test.dart](../packages/docx_creator/test/numbering_level_extras_test.dart)** (חדש, +3).
- **[numbering_resolver_test.dart](../packages/docx_file_viewer/test/numbering_resolver_test.dart)** (חדש, +13).
- **[WORD_FIDELITY_VIEWER_PLAN.md](WORD_FIDELITY_VIEWER_PLAN.md)** — עדכון §8/§9/§10 + יומן.

---

## 3. ארכיטקטורה וזרימת המידע

```
DocxReader ──► DocxBuiltDocument (AST, עם numId+levels)
                       │
   _initBuilders ──►  NumberingResolver.resolveDocument(doc)
                       │  מעבר אחד בסדר מסמך, counters[numId][ilvl]
                       ▼
            Map<DocxListItem, String> labels   (מפתח = זהות אובייקט)
                       │
                       ▼
                 ListBuilder(numberLabels: labels)
                       │  resolved[item] = הסימן הסופי
                       ▼
                  Flutter Widgets
```

החלטות תכנון מרכזיות (כולן נכונות ומתועדות):
- **Story עצמאי** — גוף+טבלאות = story אחד; כל header/footer/footnote/endnote = counters טריים, כמו Word.
- **מפתוח לפי זהות** — `DocxListItem` **אינו** דורס `==`/`hashCode` (אומת), ולכן המיפוי לפי
  מופע בטוח; שני פריטים עם טקסט זהה הם מפתחות נפרדים.
- **שיתוף קוד** — נתיב ה‑fallback וה‑resolver מאצילים לאותן פונקציות פורמט → אין כפילות לוגיקה.

---

## 4. אימות שביצעתי בפועל

| בדיקה | תוצאה |
|---|---|
| `dart test` ב‑docx_creator (חבילה מלאה) | ✅ **388 עברו**, ~1 דילוג, exit 0 |
| `flutter test` ב‑docx_file_viewer (חבילה מלאה) | ✅ **203 עברו**, 4 נכשלו |
| הבדיקות החדשות (3 + 13) | ✅ כולן ירוקות |
| `flutter analyze` (viewer) | ✅ No issues found |
| `dart analyze` (docx_creator) | 🟡 3 info בלבד — `unnecessary_import` בקבצי בדיקה **שלא נגעו בקומיט** |
| `dart format --set-exit-if-changed` (4 קבצים שהשתנו) | ✅ 0 שינויים |

**ה‑4 שנכשלו:** כולם ב‑[hebrew_rtl_golden_test.dart](../packages/docx_file_viewer/test/hebrew_rtl_golden_test.dart),
מסוג `PathNotFoundException` (fixtures חסרים). אימתתי ש**הקובץ הזה לא נגע בקומיט** — אלו כשלים
**קדם‑קיימים מחלק A**, לא רגרסיה מחלק G. תואם בדיוק לטענת הקומיט ("4 golden עברית נכשלות על
fixtures חסרים, קדם‑קיים").

**מסקנה:** כל הטענות בהודעת הקומיט (388 + 203 ירוקות, analyze נקי, format הורץ) **אומתו ונכונות**.

---

## 5. נקודות חוזק

1. **תיעוד יוצא דופן** — כל מחלקה ומתודה מתועדות עם הפניה לסעיף בתוכנית ולמוטיבציה ("הבעיה שזה פותר").
2. **תאימות לאחור** — כל ההרחבות הן תוספת בלבד (שדות עם ברירות מחדל); אין שבירת API.
3. **שיתוף קוד אמיתי** — מחיקת הכפילות ב‑ListBuilder והאצלה לרזולבר מבטיחות שה‑fallback וה‑resolver
   מפיקים מחרוזות **זהות**.
4. **כיסוי בדיקות ממוקד** — המקרים הקשים (המשכיות חוצת‑פסקה, רשימה בתא, isLgl, lvlRestart=0,
   גימטריה טו/טז, hebrew2, none, footer‑story, וגם end‑to‑end דרך הגנרטור) מכוסים.
5. **כנות לגבי מגבלות** — הקומיט מתעד מראש את הסטיות (§8.2 #24–26).

---

## 6. ממצאים, סיכונים והמלצות

חקרתי מעבר לטענות הקומיט. להלן הנקודות שמצאתי, לפי חומרה.

### 6.1 🟠 בינוני — נתיב ה‑fallback **מת בייצור**; פריט חסר לא נופל אליו

זהו הממצא המשמעותי ביותר. ב‑[list_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/list_builder.dart)
בחירת הענף היא:

```dart
final resolved = numberLabels;
...
if (resolved != null) {
  if (!isCheckbox) orderedMarker = resolved[item];   // פריט חסר → null
} else {
  ... // נתיב ה-fallback (מונה מקומי) — רץ רק כשהמפה כולה null
}
```

ההערה בקוד טוענת: *"Null (or a missing item) means ... the per-list fallback runs"* — אבל
**הקוד לא מתנהג כך**. הענף נבחר לפי האם **המפה כולה** `null`, לא לפי נוכחות הפריט. ובמסלול הייצור
([docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart))
המפה **תמיד** מחושבת ומוזנת → `resolved != null` תמיד → **ענף ה‑fallback לעולם לא רץ בייצור**.

המשמעות: כל רשימה שהרזולבר **דילג** עליה (ראו `_resolveList`: `if (numId == null || list.levels.isEmpty) return;`)
מאבדת את הסימן שלה — `resolved[item]` מחזיר `null` ולכן:
- רשימה **ordered** → תרונדר בלי מספר (בפועל תיפול לסימן bullet), במקום מספור ברירת‑מחדל
  כפי שהיה לפני הקומיט.

תרחישי הסיכון:
1. **פריט ב‑ilvl שאין לו `DocxListLevel`** (למשל פריט ברמה 3 כשההגדרה מכסה רק 0–2): הרזולבר
   נותן `def == null` → לא מוסיף תווית → בייצור אין מספר. לפני הקומיט ה‑fallback היה מרכיב סימן cascade.
2. **רשימת factory ordered (ללא `numId`) שמוזנת דרך `DocxWidgetGenerator`** (API מיוצא): אין מספור.
3. **רשימה עם `numId` אך הגדרת מספור לא נפתרה** (`levels` ריק): נדיר, אך אובדן סימן שקט.

הקלה: התרחישים נדירים בקבצי Word תקינים (Word כמעט תמיד מגדיר 9 רמות והמספור נפתר), ולכן
**אין רגרסיה גלויה במקרה הנפוץ** — אבל זהו כשל **שקט** (סימנים נעלמים) שסותר את כוונת ההערה.

**המלצה:** להפוך את ה‑fallback לפר‑פריט במקום פר‑מפה. למשל:
```dart
orderedMarker = resolved?[item] ?? _fallbackMarker(item, list, counters);
```
כך פריט שהרזולבר לא כיסה נופל חזרה ללוגיקת הרשימה המקומית, כפי שההערה כבר מבטיחה.
לכל הפחות — לתקן את ההערה כך שתשקף שהמפה‑כולה היא התנאי.

### 6.2 🟡 נמוך — `w:lvlRestart` בערכי ביניים: חשד ל‑off‑by‑one

ב‑`_restartDeeperLevels`: `threshold = r == null ? d : (r - 1); if (level < threshold) remove`.
- `null` (ברירת מחדל) ו‑`0` (לעולם לא) — **נכונים ונבדקים** ✅.
- ערך ביניים `r`: הקוד מאפס רמה עמוקה כש‑`level < r-1`. הקריאה הנפוצה של ISO (1‑based) היא לאפס
  כשמשתמשים ברמה שמספרה ‎≤ r, כלומר `ilvl ≤ r-1` ⟺ `level < r` — **גדול ב‑1** מהקוד.

הצוות כבר תייג זאת מפורשות כסטייה **§8.2 #25** ("ערכי ביניים לא אומתו מול Word"). זו לא תקלה
נסתרת אלא מגבלה ידועה ומתועדת. **המלצה:** נעילת golden מול Word לפני הסתמכות על ערכי ביניים.

### 6.3 🟡 נמוך (לטנטי) — לרזולבר אין מושג של checkbox

הרזולבר מקדם מונה ומוסיף תווית לכל פריט לא‑bullet, כולל פריט שהוא **checkbox**. ה‑renderer
מתעלם מהתווית עבור checkbox (`if (!isCheckbox) ...`) — אבל **המונה הגלובלי כבר התקדם**, כך
שפריט checkbox "אוכל" מספר. לפני הקומיט, ה‑fallback **לא** קידם מונה ל‑checkbox.

**מדוע זה כרגע לא פוגע:** אימתתי ש‑`DocxCheckbox` נוצר **רק** ב‑[document_builder.dart](../packages/docx_creator/lib/src/utils/document_builder.dart)
(factory ל‑HTML/Markdown) ו**אינו** מיוצר ע"י קורא ה‑DOCX. רשימות factory חסרות `numId` →
הרזולבר מדלג עליהן ממילא. כך שהבעיה **תאורטית** היום, אך תתעורר אם הקורא יתחיל לפלוט checkbox
בתוך רשימה עם `numId`. **המלצה:** אם/כאשר מוסיפים תמיכת checkbox מקורית, להעביר לרזולבר predicate
שמדלג על קידום מונה עבור checkbox.

### 6.4 🟢 לתשומת לב — תלות במופע יחיד לאורך הצינור

תקינות המספור תלויה בכך שה**אותו מופע** `DocxListItem` מגיע גם לרזולבר וגם ל‑renderer. כיום זה
מתקיים (אין שיבוט פריטים בין השלבים, ו‑`==` לא נדרס). אך בגלל §6.1, אם שלב עתידי **ישבט** פריטים
(למשל פיצול רשימה בין עמודים בעימוד), חיפוש הזהות ייכשל ו**הסימן ייעלם בשקט** (אין fallback).
תיקון §6.1 (fallback פר‑פריט) מנטרל גם את הסיכון הזה.

---

## 7. סיכום

קומיט **איכותי ובוגר**: ארכיטקטורה נקייה, תיעוד מצוין, תאימות לאחור, שיתוף קוד אמיתי וכיסוי
בדיקות טוב. **כל הטענות המספריות אומתו** (388 + 203 ירוקות, analyze/format נקיים; 4 הכשלים
קדם‑קיימים וזרים לחלק G). הביצוע "חלק" — אין רגרסיה גלויה במקרה הנפוץ.

הנקודה האחת ששווה תיקון לפני שמסתמכים עליה בקצוות היא **§6.1** — נתיב ה‑fallback מת בייצור
וההערה שמבטיחה "פריט חסר → fallback" אינה מדויקת; פריט שהרזולבר דילג עליו מאבד את הסימן בשקט.
התיקון קטן (fallback פר‑פריט) ומסיר גם את הסיכון ב‑§6.4. שאר הממצאים (§6.2, §6.3) הם מגבלות
נדירות, חלקן כבר מתועדות כסטיות מוכרות.

**ציון כולל: גבוה.** מומלץ לתקן את §6.1, ולנעול golden עבור §6.2 בעתיד.
