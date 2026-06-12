# תוכנית בנייה: Word Fidelity Viewer — רינדור DOCX ב‑Flutter בנאמנות 1:1

> **מסמך עבודה ל‑AI.** זהו המסמך המחייב לבניית מנוע תצוגת Word מלא בתוך Flutter.
> מטרה: מסמך DOCX שנפתח ב‑viewer ייראה **זהה לחלוטין** לאיך שהוא נראה ב‑Microsoft Word —
> אותם מעברי עמוד, אותם גבהים, אותם פונטים, אותם מספרי עמודים, אותה עטיפת טקסט.
>
> **היקף: תצוגה בלבד.** לא עריכה, לא ייצוא. רק "מצב קריאה של Word" בתוך Flutter.
>
> **שתי דרישות‑על שאינן ניתנות למשא ומתן:**
> 1. **RAM נמוך ככל האפשר** — תקציבי זיכרון מוגדרים ב‑§2 ונאכפים בכל חלק.
> 2. **עיבוד מהיר ככל האפשר** — תקציבי זמן מוגדרים ב‑§2 ונאכפים בכל חלק.
>
> דרישת‑על שלישית (תוכן): **תמיכה מלאה בעברית ואנגלית מעורבבות (BiDi)** — כל פיצ'ר חייב
> לעבוד נכון כשעברית ואנגלית מופיעות באותה פסקה, באותה שורה ואפילו באותה ריצת טקסט.

---

## §0. פרוטוקול עבודה ל‑AI — קרא את זה לפני הכול

המסמך בנוי כך ש‑AI אחד יכול לבצע חלק, לעדכן את המסמך, ו‑AI הבא ממשיך מאותה נקודה.

### 0.1 סדר פעולות מחייב בכל סשן

1. קרא את **§0 (פרוטוקול)**, **§2 (חוקי ברזל)**, ואת **לוח הסטטוס (§9)**.
2. קרא את **יומן המסירה (§10)** — שתי הרשומות האחרונות לפחות.
3. בחר את החלק הראשון בלוח הסטטוס שאינו `✅ הושלם`, לפי סדר התלויות (אין לדלג על חלק שתלותו לא הושלמה).
4. קרא את פרק החלק במלואו, כולל "מקרי קצה" ו"הגדרת סיום (DoD)".
5. בצע את החלק. עבוד בצעדים קטנים: שינוי → `flutter analyze` → בדיקות → הצעד הבא.
6. בסיום (או בעצירה באמצע): עדכן את לוח הסטטוס (§9), הוסף רשומה ליומן המסירה (§10), עדכן את מטריצת הנאמנות (§8) אם כוסו פיצ'רים חדשים.

### 0.2 פקודות אימות

מריצים מתוך תיקיית כל חבילה שנגעו בה:

```powershell
cd c:\OTZ\flutter-packages\packages\docx_creator
flutter analyze          # חובה: אפס שגיאות, אפס אזהרות חדשות
flutter test             # חובה: כל הבדיקות ירוקות

cd c:\OTZ\flutter-packages\packages\docx_file_viewer
flutter analyze
flutter test
```

הרפו מנוהל עם melos (`melos.yaml` בשורש). אם melos מותקן: `melos exec -- flutter analyze`.

### 0.3 חוקים על עדכון המסמך הזה

- בלוח הסטטוס (§9): מותר לשנות רק את עמודות **סטטוס** ו**הערות**.
- ביומן המסירה (§10): רק **להוסיף** רשומות, לעולם לא לערוך/למחוק קיימות.
- אסור לשנות את ההוראות עצמן (§5) בלי לתעד את הסיבה ביומן. אם מתגלה שההוראה שגויה — מתקנים אותה **וגם** כותבים ביומן מה שונה ולמה.
- סטייה מודעת מהתנהגות Word (פשרה) — חובה לרשום בטבלת "סטיות מודעות" (§8.2).

### 0.4 הגדרת "הושלם" לכל חלק

חלק נחשב `✅` רק כאשר: כל סעיפי ה‑DoD שלו מסומנים; `flutter analyze` נקי בשתי החבילות; כל הבדיקות (גם הישנות) ירוקות; תקציבי הביצועים של §2 לא נשברו (כשיש מדידה רלוונטית); לוח הסטטוס והיומן עודכנו.

---

## §1. משימה, היקף, ומה מחוץ להיקף

### 1.1 המשימה

לקחת את החבילה [docx_file_viewer](../packages/docx_file_viewer/) (ואת צד ה**קריאה** של [docx_creator](../packages/docx_creator/)) ולהביא אותן למצב שבו `DocxView` במצב `paged` מציג מסמך Word בנאמנות חזותית מלאה:

- אותם מעברי עמוד ושבירות שורה (בטולרנס של ±שורה).
- אותם גדלים, שוליים, פונטים, צבעים, רווחים.
- כותרות עליונות/תחתונות נכונות פר‑עמוד, מספרי עמודים חיים, הערות שוליים בתחתית העמוד שבו הן מאוזכרות.
- טבלאות, רשימות, תמונות, צורות, תיבות טקסט, טורים, גבולות עמוד, סימני מים — הכול כמו ב‑Word.
- עברית + אנגלית מעורבבות — מושלם, כולל פונטים נפרדים לכל כתב באותה ריצה (`rFonts` ascii/cs).

### 1.2 מה בהיקף ומה לא

| בהיקף | מחוץ להיקף — אסור לגעת |
|---|---|
| `packages/docx_file_viewer` — כולו | עריכת מסמכים (editor) |
| `docx_creator/lib/src/reader/docx_reader/**` — הקורא | `docx_creator/lib/src/exporters/**` (DOCX/PDF/HTML) |
| `docx_creator/lib/src/ast/**` — הרחבות מודל (שדות חדשים בלבד, ללא שבירת API) | `docx_creator/lib/src/parsers/**` (HTML/Markdown) |
| `docx_creator/lib/src/core/**` — enums, number_formatter | `docx_creator/lib/src/reader/pdf_reader/**` |
| בדיקות בשתי החבילות | `docx_creator/lib/src/builder/**` — מותר לקרוא, לשנות רק אם הרחבת AST מחייבת |

**כלל API:** הרחבות AST תמיד כתוספת (שדות אופציונליים עם ברירת מחדל, מחלקות חדשות). אסור לשבור חתימות קיימות — לחבילות יש משתמשים (האפליקציה `shnayim-mikra-build` בין השאר). כש`buildXml` קיים על צומת AST — שדה חדש חייב גם להיכתב חזרה ב‑`buildXml` (round‑trip).

### 1.3 מסמכי עזר

- [docs/PAGE_NUMBERING_RESEARCH.md](PAGE_NUMBERING_RESEARCH.md) — מחקר מעמיק על שדות עמוד, `pgNumType`, מקטעים ומנוע עימוד. חלק D כאן מתבסס עליו. **חובה לקרוא לפני חלק D.**
- מפרט ISO/IEC 29500 (OOXML) — כשיש ספק לגבי סמנטיקה של אלמנט, ההתנהגות של Word היא הקובעת, והמפרט הוא הגיבוי.

---

## §2. חוקי ברזל — ביצועים, זיכרון, BiDi

### 2.1 מסמך הייחוס למדידה

"מסמך הייחוס": DOCX של ~200 עמודים, עברית+אנגלית מעורבבות, ~50 תמונות, ~30 טבלאות, הערות שוליים, 3 מקטעים. (חלק N יוצר אותו כ‑fixture; עד אז מודדים על המסמך הגדול ביותר הזמין ב‑`test/`.)

### 2.2 תקציבי ביצועים (חובה)

| מדד | תקציב | איך מודדים |
|---|---|---|
| פתיחה → עמוד ראשון נראה | ≤ 1.5 שניות (debug ≤ 3s) | stopwatch סביב `_loadDocument` עד `onLoaded` של עמוד 1 |
| עימוד מלא ברקע (200 עמ') | ≤ 6 שניות, בלי להקפיא UI | Timeline + שעון |
| נתח עבודה רציף על ה‑UI thread | ≤ 8ms לפריים (time‑slicing) | DevTools timeline |
| בניית widget של עמוד בגלילה | ≤ 8ms לעמוד | DevTools timeline |
| גלילה | 60fps, אפס פריימים > 16ms באשמת ה‑viewer | DevTools |
| חיפוש (highlight + ניווט) | ≤ 100ms, **בלי** רגנרציה של כל המסמך | שעון |

### 2.3 תקציבי זיכרון (חובה)

| מדד | תקציב |
|---|---|
| שיא RAM בטעינת מסמך הייחוס | ≤ 200MB מעל הבסיס של האפליקציה |
| מצב יציב (אחרי טעינה, גלילה רגועה) | ≤ 120MB |
| תמונות מפוענחות (decoded) בו‑זמנית | רק עמודים נראים ±1 עמוד; שאר העמודים מחזיקים bytes דחוסים בלבד |
| מטמון מדידות (חלק C/D) | LRU עם תקרה קשיחה (ברירת מחדל: 4,000 רשומות) |

### 2.4 כללי קוד שנגזרים מהתקציבים — חובה בכל חלק

1. **שיתוף ב‑reference, לא העתקה.** צמתי AST לעולם לא משוכפלים לצורך רינדור. פיצול פסקה בעימוד נשמר כ"פרוסה" (טווח תווים/שורות על הצומת המקורי), לא כעותק של רשימת ה‑inlines. דוגמה קיימת לעיקרון: [field_substitution.dart](../packages/docx_file_viewer/lib/src/pagination/field_substitution.dart) מחזיר את אותה רשימה כשאין שינוי.
2. **תמונות:** לשמור bytes דחוסים בלבד; לפענח בעת תצוגה עם `cacheWidth`/`cacheHeight` מחושבים מגודל התצוגה בפועל × devicePixelRatio. לעולם לא לפענח ברזולוציה מקורית כשהתצוגה קטנה.
3. **פענוח ZIP+XML ב‑isolate** (`compute`), כך שה‑UI לא נתקע. שים לב: `TextPainter` **לא** עובד ב‑isolate רגיל — כל המדידות נשארות על ה‑UI thread אבל ב‑time‑slicing.
4. **שחרור מוקדם:** אחרי הפענוח, אסור להחזיק את ה‑`Uint8List` של קובץ ה‑ZIP או `Archive` חי. רק ה‑AST + bytes של מדיה.
5. **מטמונים עם תקרה.** כל מטמון חדש (מדידות, spans, סגנונות) — LRU עם גודל מקסימלי ומנגנון פינוי. אין מטמון בלתי מוגבל.
6. **אין רגנרציה גלובלית.** שינוי מצב נקודתי (חיפוש, מעבר עמוד) לא בונה מחדש את כל הווידג'טים. (הקוד הקיים ב‑[docx_view.dart](../packages/docx_file_viewer/lib/src/docx_view.dart) `_onSearchChanged` עושה בדיוק את זה — מתוקן בחלק M.)
7. **וירטואליזציה תמיד** — עמודים נבנים רק כשנכנסים ל‑viewport (ראו §4.1).
8. **אובייקטים קלים:** מאפיינים מפוענחים נשמרים כ‑enum/int/double, לא כמחרוזות. `const` בכל מקום אפשרי.
9. **בלי `debugPrint` בנתיב חם.** לוגים רק מאחורי `config.showDebugInfo`.

### 2.5 דרישת BiDi — עברית ואנגלית ביחד (חובה בכל חלק)

כל חלק שנוגע בטקסט חייב לעמוד ב:

1. **כיוון פסקה מהמסמך, לא מניחוש.** `w:bidi` ב‑pPr הוא מקור האמת (חלק A מוסיף אותו ל‑AST). הניחוש הקיים ([text_direction_detector.dart](../packages/docx_file_viewer/lib/src/utils/text_direction_detector.dart)) נשאר רק כ‑fallback כשהמאפיין חסר.
2. **טקסט מעורב באותה פסקה** מסתדר לפי אלגוריתם ה‑BiDi של Unicode — Flutter עושה זאת אוטומטית בתוך `TextPainter`, בתנאי ש‑`textDirection` הבסיסי נכון.
3. **פונטים נפרדים לכל כתב באותה ריצה:** ב‑Word ריצה אחת נושאת `rFonts` עם `ascii` (לטינית) ו‑`cs` (עברית/ערבית), וכן `sz` מול `szCs`, `b` מול `bCs`, `i` מול `iCs`. רינדור 1:1 מחייב פיצול הריצה לפי כתב והחלת הפונט/גודל/משקל הנכונים לכל קטע (חלק L).
4. **יישור תלוי‑כיוון:** מיפוי `w:jc` חייב להתחשב ב‑bidi (טבלה מחייבת בחלק C §C.4).
5. **טבלאות RTL:** `w:bidiVisual` הופך את סדר העמודות (חלק F). **רשימות RTL:** המספור והכניסות בצד ימין (חלק G). **טורים RTL:** סדר טורים מימין לשמאל (חלק I).
6. כל בדיקת golden חדשה חייבת לכלול לפחות מקרה אחד של עברית+אנגלית מעורבבות.

---

## §3. מצב קיים — מה כבר יש (נכון ל‑2026‑06)

### 3.1 ארכיטקטורה נוכחית

```
DocxView (docx_view.dart)
  └─ DocxReader.loadFromBytes (docx_creator)  → DocxBuiltDocument (AST)
  └─ EmbeddedFontLoader                        → טעינת פונטים מוטמעים (כולל obfuscated)
  └─ DocxWidgetGenerator.generateWidgets       → List<Widget>
       ├─ paged: _generatePagedWidgets         → עימוד היוריסטי (~8px לתו!) ← *הבעיה המרכזית*
       └─ continuous: רשימה שטוחה
  └─ ListView.builder / SingleChildScrollView
```

### 3.2 מה עובד ושמור (אסור לשבור)

- קריאת DOCX מלאה ל‑AST: פסקאות, ריצות, טבלאות (כולל מקוננות), רשימות (numbering.xml), תמונות, צורות, drop‑caps, הערות שוליים/סיום, מקטע, סגנונות עם basedOn, ערכת theme, פונטים מוטמעים.
- **שדות עמוד — הושלם לאחרונה:** פענוח `fldSimple`/`fldChar` ([inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart), [field_instruction.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/field_instruction.dart)), `PAGE`/`NUMPAGES`/`SECTIONPAGES`/`PAGEREF`/שדה‑לא‑מוכר, סימניות, `pgNumType`, וריאנטי header/footer (first/even/default + `titlePg` + `evenAndOddHeaders`), [NumberFormatter](../packages/docx_creator/lib/src/core/number_formatter.dart), והחלפה חיה ב‑[field_substitution.dart](../packages/docx_file_viewer/lib/src/pagination/field_substitution.dart) + [page_context.dart](../packages/docx_file_viewer/lib/src/pagination/page_context.dart). מקביל ל‑M0–M2 + חלק מ‑M7 במסמך המחקר.
- רינדור עמוד עם מידות אמיתיות מ‑`w:pgSz`/`w:pgMar`/gutter, header/footer באזורי השוליים ([docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart) `_buildPageContainer`).
- תמונות `behindDoc` כרקע עמוד; floats בסיסיים (Row של תמונה+פסקאות); RTL היוריסטי "first strong"; חיפוש עם highlight וניווט; וירטואליזציה ב‑`ListView.builder` כשאין zoom.

### 3.3 הפערים המרכזיים (מאומתים מול הקוד)

| # | פער | חומרה | מטופל בחלק |
|---|---|---|---|
| 1 | **עימוד היוריסטי** — `_estimateElementHeight` מעריך ~8px לתו; אין מדידה אמיתית, אין פיצול פסקה/טבלה | קריטי | D |
| 2 | ה‑reader **לא מפענח**: `w:bidi`, `w:rtl`, `w:tabs` (tab stops), `w:keepNext/keepLines/widowControl/pageBreakBefore`, `w:cols`, `w:cantSplit`, `w:tblCellMar/tcMar/tblInd/tblLayout`, `w:bidiVisual`, `w:sym`, `mc:AlternateContent`, `w:pgBorders`, `w:vAlign` של sectPr, `w:kern/position/spacing/w` ברמת ריצה, `w:textDirection` בתא | קריטי | A |
| 3 | אין מנוע **tab stops** — כותרות "טקסט─מרכז─מספר עמוד" לא מתיישרות | גבוה | C |
| 4 | resolution של סגנונות חלקי — אין toggle properties, אין תנאי `tblStylePr`+`tblLook` מלא, theme fonts חלקי | גבוה | B |
| 5 | אין פיצול ריצה לפי כתב (ascii/cs) — עברית+אנגלית באותה ריצה מקבלות פונט אחד | גבוה | L |
| 6 | הערות שוליים מוצגות ב‑Dialog בלחיצה, לא בתחתית העמוד | גבוה | J |
| 7 | עטיפת טקסט סביב floats — קירוב Row בלבד; אין square/tight אמיתי, אין מיקום מוחלט בעמוד | גבוה | H |
| 8 | אין טורים מרובים (`w:cols`) | בינוני | I |
| 9 | חיפוש מרנדר מחדש את **כל** המסמך; RAM/CPU מבוזבזים | בינוני | M |
| 10 | טבלה: אין פתרון קונפליקט גבולות של Word, אין autofit אמיתי, אין חזרת שורת כותרת בעימוד | בינוני | F, D |
| 11 | מספור רשימות מחושב בתוך ה‑builder פר‑widget — לא מצב גלובלי בסדר מסמך; startOverride/lvlRestart לא מלאים | בינוני | G |
| 12 | אין גבולות עמוד, סימני מים, `w:vAlign` של עמוד, line numbering | בינוני | E |
| 13 | עמוד ממוספר `minHeight` בלבד — עמוד יכול להימתח מעבר לגובה האמיתי (התוכן לא נחתך לגובה עמוד קבוע) | בינוני | D, E |

---

## §4. ארכיטקטורת היעד

```
bytes (קובץ DOCX)
  │  isolate (compute) — unzip + XML parse + בניית AST.  UI חופשי.
  ▼
DocxBuiltDocument (AST, immutable, משותף ב-reference)
  │
  ▼
StyleResolver (חלק B) — עצלן + מטמון. צומת AST + הקשר ⇒ ResolvedStyle (TextStyle מוכן)
  │
  ▼
TextMeasurer (חלק C) — TextPainter ממוחזר + מטמון LRU. (block, width) ⇒ גובה/שורות/נקודות־פיצול
  │
  ▼
Paginator (חלק D) — אינקרמנטלי + time-sliced על ה-UI thread.
  │   פלט: List<PageModel> — כל עמוד = רשימת BlockSlice (הפניה+טווח, לא עותק)
  │   + מפות: bookmark→page, footnote→page, anchor→מיקום float
  ▼
ListView.builder של עמודים (§4.1) — בונה PageWidget רק לעמודים נראים
  │
  ▼
PageWidget — Stack: רקע/גבולות־עמוד → גוף (תוכן הפרוסות) → floats ממוקמים → header/footer עם
              החלפת שדות חיה (FieldSubstitution) → שכבת inFront
```

### §4.1 וירטואליזציה (מופנה מהערות בקוד)

- מצב paged תמיד מרונדר ב‑`ListView.builder`: רק עמודים ב‑viewport (+`cacheExtent` מוגבל) מקבלים render objects. RAM של widgets ∝ עמודים נראים, לא גודל המסמך.
- `addAutomaticKeepAlives: false`, `addRepaintBoundaries: true` (כל עמוד עטוף `RepaintBoundary`).
- **zoom חייב לחיות עם וירטואליזציה**: במקום `InteractiveViewer` סביב כל הרשימה (שמבטל virtualization כי דורש גודל סופי — המגבלה הקיימת ב‑[docx_view.dart](../packages/docx_file_viewer/lib/src/docx_view.dart)), עוטפים את ה‑`ListView` ב‑`InteractiveViewer` עם `constrained: true` וסקייל בלבד (transform על ה‑viewport), או מיישמים zoom כשינוי scale של כל עמוד בנפרד. מטופל בחלק M.
- עימוד לא מחושב מחדש בגלילה — `PageModel` הוא תוצר מוכן; בניית עמוד היא הרכבת widgets בלבד.

### §4.2 מודל הזיכרון

- AST יחיד וקבוע; כל השכבות מעליו מחזיקות הפניות + מספרים (offsets, גבהים).
- `PageModel` קטן: `List<BlockSlice>` כאשר `BlockSlice = (הפניה לבלוק, טווח שורות/תווים, גובה מדוד)`. אסור שיכיל widgets או טקסט משוכפל.
- מטמון המדידות נמחק כשהרוחב האפקטיבי משתנה (שינוי גודל חלון/קונפיג) — לא נשמר היסטורית.
- תמונות: ראו §2.4 כלל 2. בנוסף — `PaintingBinding.instance.imageCache.maximumSizeBytes` מכוון לתקרה סבירה (ברירת מחדל 100MB → להוריד ל‑50MB ב‑init של ה‑viewer, ניתן לקנפוג).

### §4.3 מטמון מדידות

מפתח: `(identityHashCode(block), contentWidth.round(), styleEpoch)`. ערך: `BlockMeasurement { height, lineMetrics?, splitPoints }`. LRU מקסימום 4,000 רשומות. `styleEpoch` עולה כשהקונפיג/theme משתנים — מבטל את המטמון כולו בלי לסרוק.

### §4.4 Time‑slicing של העימוד

העימוד רץ על ה‑UI thread (אילוץ `TextPainter`) אבל **לא ברצף**: עובדים במנות של ≤8ms (`Stopwatch` פנימי), ואז `await Future<void>.delayed(Duration.zero)` / `SchedulerBinding.instance.scheduleTask` להחזרת השליטה לפריים. סדר העבודה: קודם מעמדים את העמודים הראשונים (מציגים מיד), ממשיכים ברקע קדימה. בזמן שעמודים מאוחרים עוד לא מועמדים — מציגים placeholder עמוד עם spinner עדין + אומדן גובה (גובה עמוד מלא), כך שה‑scrollbar יציב.

---

## §5. חלקי הבנייה

> סדר הביצוע הוא סדר התלויות: **A → B → C → D → E → F → G → H → I → J → K → L → M → N**.
> מותר לבצע L (פונטים) במקביל לכל חלק אחרי C. אסור להתחיל D לפני A+B+C.

---

### חלק A — השלמת ה‑Reader: כל מאפייני התצוגה ל‑AST

**מטרה:** כל מאפיין OOXML שמשפיע על איך המסמך *נראה* נקרא ל‑AST. בלי זה אין על מה לבנות.

**תלות:** אין. **חבילה:** `docx_creator` (reader + ast + core/enums).

**קבצים מרכזיים:** [inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart), [block_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/block_parser.dart), [table_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/table_parser.dart), [section_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/section_parser.dart), [style_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/style_parser.dart), [docx_block.dart](../packages/docx_creator/lib/src/ast/docx_block.dart), [docx_inline.dart](../packages/docx_creator/lib/src/ast/docx_inline.dart), [docx_table.dart](../packages/docx_creator/lib/src/ast/docx_table.dart), [docx_section.dart](../packages/docx_creator/lib/src/ast/docx_section.dart), [enums.dart](../packages/docx_creator/lib/src/core/enums.dart)

#### A.1 פסקה (`w:pPr`) — מאפיינים חדשים

| אלמנט | שדה AST מוצע (על `DocxParagraph`) | הערות |
|---|---|---|
| `w:bidi` | `bool isRtl` | **הדגל הקריטי ל‑BiDi.** ברירת מחדל false; `w:bidi w:val="0"` = false |
| `w:keepNext` | `bool keepWithNext` | toggle — היעדר val = true |
| `w:keepLines` | `bool keepLines` | |
| `w:widowControl` | `bool widowControl` | ברירת מחדל **true** ב‑Word (docDefaults בד"כ) |
| `w:pageBreakBefore` | `bool pageBreakBefore` | קיים? לוודא שמפוענח מ‑XML (כיום קיים על המודל אך יש לוודא קריאה) |
| `w:tabs` → `w:tab` | `List<DocxTabStop> tabStops` | `DocxTabStop { int posTwips; DocxTabAlignment alignment; DocxTabLeader leader }`; alignment: left/center/right/decimal/bar/start/end; leader: none/dot/hyphen/underscore/middleDot/heavy. `w:tab w:val="clear"` מוחק tab תורש |
| `w:textAlignment` | `DocxVerticalTextAlign? textAlignment` | יישור אנכי בתוך שורה (auto/baseline/top/center/bottom) — עדיפות נמוכה, מותר לפענח ולא לרנדר בשלב זה |
| `w:suppressAutoHyphens` | `bool suppressHyphens` | |
| `w:contextualSpacing` | לוודא שקיים ומפוענח | מבטל before/after בין פסקאות מאותו סגנון |

#### A.2 ריצה (`w:rPr`) — מאפיינים חדשים

| אלמנט | שדה AST | הערות |
|---|---|---|
| `w:rtl` | `bool? rtl` | ריצה בכתב RTL (קובע אילו מאפייני cs חלים) |
| `w:szCs`, `w:bCs`, `w:iCs` | `double? fontSizeCs; bool? boldCs; bool? italicCs` | הגודל/משקל לתווי complex‑script — **חיוני לעברית** |
| `w:kern` | `int? kernMinHalfPoints` | kerning מופעל מגודל זה ומעלה |
| `w:position` | `int? raiseLowerHalfPoints` | הרמה/הנמכה מהבסיס (לא vertAlign!) — ממומש ב‑C |
| `w:spacing` (ב‑rPr) | `int? letterSpacingTwips` | ריווח בין אותיות |
| `w:w` | `int? charScalePercent` | מתיחת תווים אופקית (100=רגיל) |
| `w:fitText` | `int? fitTextTwips` | דחיסת טקסט לרוחב נתון — נדיר; לפענח, רינדור best‑effort |
| `w:vanish` | `bool hidden` | טקסט מוסתר — **לא מרונדר ולא נמדד** |
| `w:em` | `DocxEmphasisMark?` | סימני הדגשה מזרח‑אסיאתיים — לפענח, רינדור אופציונלי |
| `w:effect` | לפענח ולהתעלם (אנימציות עתיקות) | |

#### A.3 inlines חדשים

- `w:sym` → `DocxSymbol { String char; String font }` — תו מפונט סמלים (Wingdings/Symbol). ה‑char מגיע כ‑hex ב‑`w:char`, בד"כ בטווח F000–F0FF (private use) — לחלץ את הבייט התחתון.
- `w:noBreakHyphen` → `DocxText('‑')` (non‑breaking hyphen) — אפשר בלי צומת חדש.
- `w:softHyphen` → `DocxText('­')`.
- `w:cr` → כמו `w:br` (שבירת שורה).
- `w:ptab` (positional tab) — לפענח כ‑`DocxPositionalTab { alignment, relativeTo }`; רינדור בחלק C.
- `mc:AlternateContent` — **חשוב מאוד לתמונות/צורות מודרניות:** לקרוא את `mc:Choice` (התוכן המודרני, בד"כ `wps:` shapes); אם הפענוח נכשל — ליפול ל‑`mc:Fallback` (בד"כ `w:pict` VML). כיום ייתכן שהתוכן הולך לאיבוד — לאמת עם בדיקה.
- `w:ins` (track‑changes insert) — לפרס את התוכן הפנימי כרגיל (להציג מצב סופי). `w:del` — לדלג על התוכן. `w:moveFrom` כמו del, `w:moveTo` כמו ins.

#### A.4 טבלה

| אלמנט | שדה AST | הערות |
|---|---|---|
| `w:bidiVisual` (tblPr) | `bool bidiVisual` | טבלת RTL — סדר עמודות הפוך |
| `w:tblCellMar` (tblPr) | `DocxCellMargins? defaultCellMargins` | ברירת מחדל של Word: left/right 108tw, top/bottom 0 |
| `w:tcMar` (tcPr) | `DocxCellMargins? margins` על תא | דורס את ברירת המחדל |
| `w:tblInd` | `int? indentTwips` | הזחת הטבלה מהשוליים |
| `w:tblLayout` | `DocxTableLayout layout` (fixed/autofit) | |
| `w:cantSplit` (trPr) | `bool cantSplit` על שורה | שורה לא נשברת בין עמודים |
| `w:textDirection` (tcPr) | `DocxCellTextDirection?` | tbRl/btLr — טקסט מסובב בתא |
| `w:noWrap`, `w:tcFitText`, `w:hideMark` | bools | |
| `w:gridBefore`/`w:gridAfter` + `w:wBefore`/`w:wAfter` (trPr) | `int gridBefore/gridAfter` | שורות שמתחילות מעמודת‑grid פנימית |
| `w:tblCellSpacing` | `int? cellSpacingTwips` | רווח בין תאים (נדיר) |

#### A.5 מקטע (`w:sectPr`)

| אלמנט | שדה AST על `DocxSectionDef` |
|---|---|
| `w:cols` | `DocxColumns { int count; int spaceTwips; bool equalWidth; List<DocxColumn>? explicit; bool separator }` |
| `w:vAlign` | `DocxSectionVAlign vAlign` (top/center/both/bottom) |
| `w:pgBorders` | `DocxPageBorders { display(allPages/firstPage/notFirstPage), offsetFrom(text/page), zOrder, top/bottom/left/right: DocxBorderSide }` |
| `w:lnNumType` | `DocxLineNumbering { countBy, start, distance, restart }` — פענוח חובה, רינדור בחלק E (עדיפות נמוכה) |
| `w:bidi` (sectPr) | `bool isRtlSection` — משפיע על כיוון טורים וצד gutter |
| `w:rtlGutter` | `bool rtlGutter` — gutter בימין |
| `w:footnotePr`/`w:endnotePr` | פורמט מספור, `w:numRestart` (continuous/eachSect/eachPage), `w:pos` — לחלק J |
| `w:docGrid` | לפענח ולהתעלם (רלוונטי ל‑CJK) |

#### A.6 settings.xml

לפענח ל‑`DocxBuiltDocument`: `w:defaultTabStop` (ברירת מחדל 720 twips), `w:evenAndOddHeaders` (קיים), `w:footnotePr/endnotePr` גלובליים, `w:themeFontLang`? (לא חובה), `w:compat`? (להתעלם בשלב זה).

#### A.7 הוראות ביצוע

1. עבור כל טבלה לעיל: הוסף enum/מחלקה ב‑[enums.dart](../packages/docx_creator/lib/src/core/enums.dart) או קובץ AST מתאים → הוסף שדה לצומת (אופציונלי, ברירת מחדל שקולה ל"לא קיים") → פענוח ב‑parser הרלוונטי → **כתיבה חזרה ב‑`buildXml`** של אותו צומת (round‑trip) → בדיקה.
2. בדיקות round‑trip: בנה XML קטן ידנית במחרוזת בתוך הבדיקה (כמו ב‑[field_parsing_test.dart](../packages/docx_creator/test/field_parsing_test.dart)) → parse → assert על השדות → buildXml → assert שה‑XML מכיל את האלמנט.
3. סדר עבודה מומלץ בתוך החלק: A.1 (כולל bidi!) → A.2 → A.4 → A.5 → A.3 → A.6.
4. RAM: enums בלבד, בלי לשמור מחרוזות XML גולמיות. שדות bool שב‑99% מהמסמכים הם ברירת המחדל — שמור כשדה non‑nullable עם ברירת מחדל (לא `bool?`), כדי לא לנפח את הצמתים.

#### A.8 מקרי קצה

- toggle elements (`w:b`, `w:keepNext`…): `<w:b/>` בלי val = true; `<w:b w:val="0"/>` = false; `w:val="false"/"off"` = false.
- מידות: `w:tblCellMar` יכול להיות ב‑`w:type="dxa"` (twips) או `"nil"` או `"pct"` — לתמוך לפחות ב‑dxa+nil.
- `w:tabs` יורש מהסגנון ו‑`clear` מסיר — הירושה עצמה נפתרת בחלק B; כאן רק מפענחים את הרשימה המקומית כולל clear.
- מסמך בלי settings.xml — ברירות מחדל (defaultTabStop=720).

#### A.9 הגדרת סיום (DoD)

- [ ] כל האלמנטים בטבלאות A.1–A.6 מפוענחים ל‑AST עם בדיקת round‑trip לכל קבוצה.
- [ ] `w:bidi`/`w:rtl` נחשפים, ו‑viewer (paragraph_builder, list_builder) משתמש בהם כשקיימים, עם ה‑detector כ‑fallback בלבד.
- [ ] `mc:AlternateContent` לא מאבד תוכן (בדיקה עם DOCX אמיתי שמכיל צורה מודרנית).
- [ ] `flutter analyze` + כל בדיקות `docx_creator` ירוקות, כולל הישנות (round‑trip fidelity).

---

### חלק B — מנוע resolution של סגנונות (Style Engine)

**מטרה:** לכל ריצה/פסקה/תא ניתן לחשב את הסגנון הסופי **בדיוק לפי שרשרת הירושה של Word**, פעם אחת, עם מטמון.

**תלות:** A. **חבילות:** `docx_creator` (resolution לוגי) + `docx_file_viewer` (תרגום ל‑TextStyle).

**קבצים:** [style_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/style_parser.dart), [docx_style.dart](../packages/docx_creator/lib/src/reader/docx_reader/models/docx_style.dart), [resolved_style.dart](../packages/docx_creator/lib/src/reader/docx_reader/models/resolved_style.dart), [docx_theme.dart](../packages/docx_creator/lib/src/reader/docx_reader/models/docx_theme.dart), [paragraph_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/paragraph_builder.dart)

#### B.1 סדר ההחלה (המפרט המחייב)

סדר חישוב מאפייני **ריצה** (כל שלב דורס את הקודם, רק במאפיינים שהוא מגדיר):

```
1. docDefaults/rPrDefault                      (styles.xml)
2. סגנון הטבלה: tblStylePr המתאים ל-cnfStyle של התא + rPr של סגנון הטבלה
3. rPr של רמת המספור (numbering lvl/rPr)       (רק על סימן המספור עצמו! לא על הטקסט)
4. שרשרת סגנון הפסקה: basedOn מהשורש ועד הסגנון עצמו (rPr של כל אחד)
5. שרשרת סגנון התו (rStyle, עם basedOn)
6. rPr ישיר על הריצה
```

מאפייני **פסקה**: `docDefaults/pPrDefault` → tblStylePr.pPr → שרשרת pStyle → numbering lvl/pPr (כניסות! — נכנס **בין** הסגנון לישיר) → pPr ישיר.

#### B.2 toggle properties (חוק ה‑XOR — ISO 17.7.3)

המאפיינים `b, bCs, i, iCs, caps, smallCaps, strike, dstrike, outline, shadow, emboss, imprint, vanish` הם "toggle": כשהם מופיעים ביותר משכבת *סגנון* אחת — הערך הסופי משכבות הסגנונות הוא **XOR** של כולן; ערך ישיר (שכבה 6) או docDefaults דורס רגיל. מימוש: לאסוף את ערכי ה‑toggle מכל שכבות הסגנון בנפרד, להחיל XOR, ואז לתת ל‑rPr הישיר לדרוס.

#### B.3 theme — צבעים ופונטים

- `w:color w:themeColor="accent1" w:themeTint="99"` → לקחת את הצבע מ‑theme1.xml, להחיל tint/shade: tint = ערבוב עם לבן (`c' = c*tint + 255*(1-tint)`, tint hex/255), shade = ערבוב עם שחור (`c' = c*shade`).
- `w:rFonts w:asciiTheme="minorHAnsi"` → fontScheme מ‑theme: minor/major × latin/ea/cs. `minorBidi`/`majorBidi` → הפונט לעברית.
- `w:color w:val="auto"` → שחור, אלא אם רקע (shading) כהה → לבן. (חישוב luminance פשוט > 0.5.)

#### B.4 cnfStyle וסגנונות טבלה מותנים

- `w:tblLook` (firstRow/lastRow/firstColumn/lastColumn/noHBand/noVBand) קובע אילו וריאנטים פעילים.
- לכל תא מחושבת מסכת תנאים (שורה ראשונה? אחרונה? עמודה ראשונה? פס אופקי זוגי?...), ולפי סדר עדיפות קבוע מחילים את ה‑`tblStylePr` המתאימים: `wholeTable → band1Vert/band2Vert → band1Horz/band2Horz → firstCol/lastCol → firstRow/lastRow → nwCell/neCell/swCell/seCell`.
- אם קיים `w:cnfStyle` מפורש על השורה/תא — הוא מקור האמת למסכה (כבר מפוענח).

#### B.5 מימוש ומטמון

1. מחלקה חדשה `StyleResolver` ב‑`docx_creator/lib/src/reader/docx_reader/` שמקבלת את אוסף הסגנונות+theme+docDefaults ומחשפת: `ResolvedRunStyle resolveRun(runPr, {pStyleId, rStyleId, tableCtx, isMarker})`, `ResolvedParagraphStyle resolveParagraph(...)`.
2. **מטמון:** רוב הריצות במסמך חולקות בדיוק אותו שילוב (pStyle, rStyle, אותו rPr ישיר ריק). מפתח מטמון: `(pStyleId, rStyleId, identityHashCode(rPr) או hash תוכן קצר, cnfMask)`. שרשרות basedOn מחושבות פעם אחת לכל styleId (flatten) ונשמרות.
- הגנה מלולאת basedOn: עומק מקסימלי 12, ואז עצירה.
3. ב‑viewer: `paragraph_builder` מפסיק לחשב ירושה ידנית ועובר ל‑resolver. ה‑`TextStyle` הסופי נבנה פעם אחת פר ResolvedRunStyle ונשמר במטמון קטן (flyweight).

#### B.6 DoD

- [x] בדיקות unit: שרשרת basedOn בת 3 רמות; **toggle XOR בין רמות** (סגנון‑פסקה bold + סגנון‑תו bold → כבוי; שרשרת basedOn = ירושה רגילה — ראו סטייה למטה); כיבוי מפורש `w:val="0"`; themeColor עם tint/shade; **auto‑color על רקע כהה**; cnfStyle של שורה ראשונה מטבלת סגנון. (21+ בדיקות ב‑[style_engine_test.dart](../packages/docx_creator/test/style_engine_test.dart).)
- [x] ה‑resolution **מחווט לייצור** דרך הקורא (`parseRun`→`styleResolver.resolveRun`, השחלת `paragraphStyleId`); ה‑builders צורכים את התוצאה האפויה; בדיקות ה‑viewer ירוקות.
- [x] מדידה: ה‑resolution **מהיר פי ~5.6 מהקודם** (63ms מול 355ms ל‑200k רזולוציות) — המנוע ממטמן פר (pStyle,rStyle), הקוד הישן חישב מחדש את שרשרת ה‑basedOn בכל קריאה.

> **סטייה מודעת (ראו §8.2 + יומן 2026‑06‑11):** ה‑DoD המקורי דרש ש**שרשרת basedOn** תבטל toggle ב‑XOR ("תת‑סגנון מדליק שוב → כבוי"). לאחר סקירה זה הוחלף: שרשרת basedOn נפתרת ב**ירושה רגילה** (כמו `resolveStyle` בייצור) ו‑XOR מוחל רק **בין רמות** (פסקה×תו) — המקרה המתועד של Word. יחס ה‑direct‑toggle (#1) טעון אישור golden סופי.

---

### חלק C — שירות מדידה, מנוע טאבים, ו‑BiDi מדויק

**מטרה:** שכבת מדידת טקסט אחידה שכל המערכת (עימוד + רינדור) משתמשת בה, עם תוצאות זהות בין מדידה לציור. בלי זה — העימוד ישקר.

**תלות:** A, B. **חבילה:** `docx_file_viewer`. קבצים חדשים: `lib/src/layout/text_measurer.dart`, `lib/src/layout/tab_engine.dart`, `lib/src/layout/span_factory.dart`.

#### C.1 SpanFactory — מקור אמת אחד ל‑InlineSpan

1. לחלץ מ‑[paragraph_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/paragraph_builder.dart) את בניית ה‑`TextSpan` לפונקציה טהורה: `InlineSpan buildSpan(DocxParagraph p, {SpanOptions})` — אותה פונקציה משמשת מדידה ורינדור. **חוק: אסור ששני המסלולים יבנו spans שונים**, אחרת המדידה תסטה מהציור.
2. `WidgetSpan` (תמונות inline, checkbox) חייב `PlaceholderDimensions` ידועים בזמן מדידה — גודל התמונה ידוע מה‑AST (EMU→px), לכן מעבירים אותם ל‑TextPainter דרך `setPlaceholderDimensions`.

#### C.2 TextMeasurer

```dart
class TextMeasurer {
  // TextPainter יחיד ממוחזר (לא thread-safe — UI thread בלבד, וזה בסדר: §4.4)
  // מטמון LRU לפי §4.3
  BlockMeasurement measureParagraph(DocxParagraph p, double width, {ResolvedParagraphStyle style});
  // מחזיר: גובה כולל (עם spacing before/after), List<LineMetrics>, baseline ראשון/אחרון
}
```

- **StrutStyle לפי `w:spacing` של הפסקה:** `lineRule="exact"` → `StrutStyle(height: line/20/fontSize, forceStrutHeight: true)`; `"atLeast"` → strut בלי force (מינימום); `"auto"` → `height = line/240` כמכפיל. כך שורות Word ושורות Flutter מתיישרות.
- רווח before/after: לכבד `contextualSpacing`, ו"auto spacing" (`beforeAutospacing`) כ‑14pt ברירת מחדל.
- **גובה פסקה ריקה** = גובה שורה של הפונט הפעיל (Word מודד פסקה ריקה לפי ה‑rPr של סימן הפסקה).

#### C.3 מנוע טאבים (TabEngine)

ל‑Flutter אין tab stops — מממשים:

1. **מודל:** רשימת ה‑tab stops האפקטיבית = ברירת מחדל כל `defaultTabStop` (settings) + תורשת סגנון + מקומי (אחרי `clear`). ב‑Word, כניסת הפסקה מוסיפה tab stop וירטואלי בנקודת הכניסה.
2. **אלגוריתם רינדור:** מפצלים את תוכן השורה הלוגית לקטעים סביב `DocxTab`. לכל קטע מודדים רוחב (`TextPainter` על הקטע). ממקמים: left tab → הקטע הבא מתחיל ב‑pos; center → מרכז הקטע הבא על pos; right → סוף הקטע הבא ב‑pos; decimal → הנקודה העשרונית על pos; bar → מציירים קו אנכי ב‑pos (ולא צורכים טקסט).
3. **מימוש Flutter:** פסקה שמכילה טאבים מרונדרת כ‑`CustomPaint`/`RichText` מורכב: הדרך הפשוטה והמהירה — `Row` אינו מתאים (שבירת שורות). מימוש מומלץ: widget ייעודי `TabbedLineRenderer` שעובד ברמת השורה — הפסקה נמדדת קטע‑קטע, והשורות נבנות ידנית (cursor x מתקדם). פסקאות בלי טאבים ממשיכות במסלול ה‑RichText הרגיל המהיר. **רוב הפסקאות לא מכילות טאבים — המסלול היקר חל רק כשצריך.**
4. **RTL:** בפסקת `bidi`, ציר ה‑x מתהפך — pos נמדד מימין; leader dots נמתחים בכיוון המתאים.
5. leader: ציור נקודות/קווים בין סוף הקטע הקודם לתחילת הבא (`TextPainter` עם תו חוזר, או `CustomPainter` מהיר יותר — לבחור CustomPainter).
6. `w:ptab` — מיקום יחסית לשוליים/כניסה לפי `relativeTo` — אותו מנגנון.

#### C.4 טבלת יישור BiDi (מחייבת)

| `w:jc` | פסקה LTR | פסקה RTL (`w:bidi`) |
|---|---|---|
| `left` | שמאל | שמאל (פיזי!) |
| `right` | ימין | ימין (פיזי!) |
| `start` | שמאל | ימין |
| `end` | ימין | שמאל |
| `center` | מרכז | מרכז |
| `both`/`distribute` | justify | justify |

הערה: קבצים מ‑Word מודרני משתמשים ב‑left/right במשמעות **פיזית** גם בפסקאות bidi (תאימות), כלומר: `w:jc="left"` בפסקה עברית = שמאל. אבל ברירת המחדל של פסקת bidi בלי jc היא start=ימין. המיפוי ההיוריסטי הקיים (left→start ב‑RTL) ב‑paragraph_builder **מוחלף** במיפוי המדויק ברגע ש‑`w:bidi` זמין מה‑AST. כשאין `w:bidi` (fallback ניחוש) — נשארת ההיוריסטיקה הקיימת.

#### C.5 מאפייני תו מתקדמים (מ‑A.2)

- `letterSpacingTwips` → `TextStyle.letterSpacing` (twips→px).
- `charScalePercent` → אין תמיכה ישירה ב‑TextStyle; מימוש: `Transform.scale(scaleX:)` ב‑WidgetSpan לריצות חריגות, או (עדיף, זול) `TextStyle.fontFeatures`? — אין. **החלטה: ריצה עם w:w≠100 מרונדרת כ‑WidgetSpan עם Transform**; נדיר ולכן זול. המדידה משתמשת ברוחב המנופח/מכווץ.
- `position` (raise/lower) → אין offset אנכי ב‑TextStyle; שימוש ב‑WidgetSpan עם `Transform.translate` רק כשקיים.
- `kern` → `TextStyle.fontFeatures: [FontFeature.enable('kern')]` (בד"כ פעיל ממילא) — מספיק להתעלם אם הפער זניח; לתעד ב‑§8.2.
- `vanish` → לא נבנה בכלל (גם לא במדידה).
- `smallCaps` → אין ב‑Flutter; מימוש: ריצה מפוצלת — אותיות קטנות הופכות לאותיות גדולות בגודל ~0.8× (כמו Word). `caps` → uppercase פשוט (בעברית אין שינוי).

#### C.6 DoD

- [x] `TextMeasurer.measureParagraph(p, w).height` ≡ הגובה שהפסקה מקבלת בפועל ברינדור (בדיקת widget: למדוד ואז לרנדר ולהשוות, טולרנס 0.5px) — 6 מקרים ב‑[text_measurer_test.dart](../packages/docx_file_viewer/test/text_measurer_test.dart): עברית, אנגלית, מעורב, spacing exact, תמונה inline (5 measure‑vs‑render ±0.5px); פסקה ריקה = גובה שורה. **המפתח:** המדידה והרינדור עוברים שניהם דרך אותו `SpanFactory`.
- [x] טאבים: "שמאל\tמרכז\tימין" עם tab stops center+right + leader נקודות + RTL מקביל. **בדיקת מיקום דטרמיניסטית** ([tabbed_line_test.dart](../packages/docx_file_viewer/test/tabbed_line_test.dart)) במקום golden‑image — קובצי ה‑golden חסרים בצ'קאאוט (קדם‑קיים, ראו לוג A/B). מנוע ה‑tab ([tab_engine_test.dart](../packages/docx_file_viewer/test/tab_engine_test.dart), 11 בדיקות) מכסה left/center/right/default‑interval/clamp/leader/multi‑tab.
- [x] טבלת C.4 ממומשת ([bidi_align.dart](../packages/docx_file_viewer/lib/src/layout/bidi_align.dart)) + בדיקת unit לכל שורה בטבלה × LTR/RTL ([bidi_align_test.dart](../packages/docx_file_viewer/test/bidi_align_test.dart)).
- [x] מטמון: מדידה חוזרת של אותו בלוק באותו רוחב לא בונה TextPainter חדש — מאומת דרך `layoutCount`/`cacheHits` ([text_measurer_test.dart](../packages/docx_file_viewer/test/text_measurer_test.dart)). LRU עם תקרה 4,000 + `invalidate()` (styleEpoch).

---

### חלק D — מנוע העימוד (Paginator) — לב המערכת

**מטרה:** החלפת העימוד ההיוריסטי בעימוד מבוסס‑מדידה אמיתית: שבירת עמודים נכונה, פיצול פסקאות וטבלאות, כללי keep, מקטעים מרובים, מפת סימניות.

**תלות:** A, B, C. **חבילה:** `docx_file_viewer`. קבצים חדשים: `lib/src/pagination/paginator.dart`, `lib/src/pagination/page_model.dart`, `lib/src/pagination/block_slice.dart`.

**מפרט מפורט קיים:** [PAGE_NUMBERING_RESEARCH.md](PAGE_NUMBERING_RESEARCH.md) §6 (אלגוריתם המילוי, פיצול פסקה דרך `computeLineMetrics`, פיצול טבלה, מקטעים). לקרוא אותו במלואו. כאן — ההשלמות והחלטות הסופיות:

#### D.1 מבני נתונים (RAM‑first)

```dart
class PageModel {
  final int pageNumber;            // אחרי w:start של המקטע
  final int absoluteIndex;
  final int sectionIndex;
  final List<BlockSlice> slices;
  final double usedHeight;
}
class BlockSlice {
  final DocxNode block;            // הפניה — לא עותק!
  final int startLine, endLineExclusive;  // -1,-1 = הבלוק כולו
  final int startChar, endChar;    // טווח תווים לוגי (לפיצול spans)
  final double height;
  // לטבלה: startRow/endRow במקום שורות-טקסט; דגל repeatHeader
}
```

הרינדור של slice: `SpanFactory.buildSpan` על הפסקה + חיתוך הטווח `[startChar,endChar)` ברמת ה‑span (פונקציית עזר `sliceSpan` שחוצה TextSpan לפי offsets, משמרת עיצוב). **אסור** לשכפל את עץ ה‑AST.

#### D.2 אלגוריתם — תוספות מעבר למסמך המחקר

1. **גובה גוף אמיתי:** `bodyHeight = pageHeight − max(marginTop, headerDist + measuredHeaderHeight) − max(marginBottom, footerDist + measuredFooterHeight)` — כמו Word: header גבוה דוחף את הגוף. גובה ה‑header נמדד עם `TextMeasurer` על הווריאנט הנכון של אותו עמוד (first/even/default) — כלומר ייתכנו גבהים שונים לעמודים שונים באותו מקטע. בלולאת המילוי: קודם קובעים את וריאנט העמוד (ידוע מ‑parity + ראשוניות), מודדים header/footer, ואז ממלאים.
2. **widow/orphan:** כש‑`widowControl` פעיל — פסקה לא משאירה שורה בודדת בסוף עמוד (orphan) או שורה בודדת בתחילת עמוד (widow): מזיזים את נקודת הפיצול שורה אחת אחורה, או את כל הפסקה לעמוד הבא אם נשארות <2 שורות.
3. **keepNext שרשרת:** רצף פסקאות keepNext + הבלוק שאחריהן מטופל כיחידה — אם לא נכנס, כולו עובר עמוד (עם תקרה: אם היחידה גבוהה מעמוד שלם — שוברים בכל זאת).
4. **שבירות מקטע:** `nextPage` — עמוד חדש; `evenPage`/`oddPage` — עמוד חדש ואם ה‑parity לא מתאים מוסיפים **עמוד ריק** (PageModel בלי slices — Word עושה זאת); `continuous` — ממשיך באותו עמוד (שינויי שוליים נכנסים לתוקף מהעמוד הבא; שינויי טורים — מטופל בחלק I).
5. **inline page break (`w:br type="page"`):** מפצל את הפסקה בנקודת ה‑break (slice עד ה‑break, עמוד חדש, slice מהמשך) — לא "אחרי הפסקה" כמו היום.
6. **גובה עמוד קשיח:** עמוד הוא `SizedBox` בגובה קבוע. תוכן שנמדד מעט שונה ברינדור לא ימתח את העמוד (clip + לוג debug אם חריגה >2px — אינדיקציה לבאג מדידה).
7. **טבלאות:** פיצול בין שורות; `tblHeader` → שורות הכותרת חוזרות בראש כל המשך (BlockSlice עם repeatHeader=true); `cantSplit` → השורה עוברת שלמה; שורה גבוהה מעמוד → clamp (חיתוך, שלב 2 עתידי: פיצול תוך‑תא).
8. **מפות תוצר:** `bookmark→displayPageNumber`, `footnoteId→absolutePage` (לחלק J), רשימת anchors של floats פר‑עמוד (לחלק H).
9. **time‑slicing:** לפי §4.4. ה‑API: `Stream<PageModel> paginate(doc, config)` או callback פר‑עמוד — `DocxView` מציג עמודים כשהם נולדים.
10. **שני מעברים לשדות:** `NUMPAGES`/`PAGEREF` ידועים רק בסוף. פתרון: מעבר 1 מעמד הכול; `FieldSubstitution` ממילא רץ פר‑עמוד בזמן רינדור — ואז הערכים כבר ידועים. אין צורך לעמד פעמיים **אלא אם** header/footer מכילים NUMPAGES שגובהו משנה מספר שורות (נדיר — מתעלמים, לתעד ב‑§8.2).

#### D.3 חיווט ל‑DocxView

- מצב paged: `ListView.builder(itemCount: knownPages + (done ? 0 : 1))` — האייטם האחרון placeholder בזמן עימוד. `itemExtent` אינו אחיד (מקטעים בגדלים שונים) — לא להשתמש בו אלא ב‑`prototypeItem` רק אם כל העמודים זהים.
- שינוי רוחב תצוגה **לא** משנה עימוד (גודל עמוד נגזר מהמסמך). שינוי קונפיג (פונט override, pageWidth) → עימוד מחדש מלא + ניקוי מטמונים.

#### D.4 DoD

- [ ] בדיקות unit ל‑Paginator (בלי widgets, עם TextMeasurer אמיתי ב‑testWidgets): פסקה נכנסת/נשברת; נקודת פיצול לפי שורות; widow/orphan; keepNext/keepLines; pageBreakBefore; br‑page באמצע פסקה; טבלה נשברת בין שורות + חזרת כותרת + cantSplit; מקטע evenPage מייצר עמוד ריק; pgNumType start/restart; bookmark map נכון.
- [ ] BiDi: מסמך עברית‑אנגלית מעורב מתעמד ללא שגיאות, נקודות פיצול נכונות בפסקאות RTL (התווים לפי סדר לוגי — `getPositionForOffset` כבר מטפל).
- [ ] העימוד ההיוריסטי (`_estimateElementHeight`, `_generatePagedWidgets`) **נמחק** — אין שני מסלולים.
- [ ] מסמך הייחוס: עימוד מלא ≤ 6s, UI לא קופא (פריים ≤ 16ms בזמן עימוד), עמוד ראשון ≤ 1.5s.
- [ ] השוואה ידנית מול Word על 3 מסמכים אמיתיים: סטיית מעברי עמוד ≤ ±1 שורה. תוצאות נרשמות ביומן.

---

### חלק E — עמוד 1:1: כותרות, רקעים, גבולות, יישור אנכי

**מטרה:** "קליפת העמוד" זהה ל‑Word.

**תלות:** D. **קבצים:** `docx_widget_generator.dart` (`_buildPageContainer` → יפוצל ל‑`lib/src/widgets/page_widget.dart`), `shape_builder.dart`.

#### E.1 משימות

1. **PageWidget חדש** שמקבל `PageModel` + `PageContext`: Stack בשכבות — (1) צבע רקע `w:background` של המסמך; (2) תמונות behindDoc; (3) גבולות עמוד; (4) גוף; (5) header/footer; (6) floats inFront (חלק H). עטוף `RepaintBoundary`.
2. **header/footer לכל עמוד** עם הווריאנט הנכון (first/even/default — הלוגיקה קיימת ב‑`headerFor`/`footerFor`) + `FieldSubstitution` (קיים) — לוודא חיווט מלא דרך `PageContext` האמיתי מה‑Paginator (כולל sectionPages ו‑bookmarkPages אמיתיים).
3. **`w:vAlign` של מקטע:** top (קיים) / center / bottom / both (justify אנכי — פיזור הרווח בין בלוקים). מימוש: ב‑PageWidget, אם התוכן נמוך מהגוף — `Align`/`Column` עם spacing מתאים.
4. **גבולות עמוד (`w:pgBorders`):** ציור מסגרת ב‑offset הנכון (`offsetFrom="text"` — יחסית לשוליים; `"page"` — יחסית לקצה, הערך ב‑points ב‑`w:space`). סוגי קו בסיסיים: single/double/dashed/dotted/thick (מיפוי ל‑`Border`/CustomPainter). art borders → קו single + רישום ב‑§8.2.
5. **סימן מים:** ב‑Word סימן מים הוא צורת VML בתוך ה‑header (טקסט מסובב שקוף או תמונה). ברגע שה‑header מרונדר מלא (כולל צורות מ‑A.3/H) — סימן המים "יוצא בחינם". לוודא: צורה עם `rotation` + `fill opacity` מרונדרת; ממוקמת במרכז העמוד (anchor: page center).
6. **מספור שורות (`w:lnNumType`):** עדיפות נמוכה — אם נשאר זמן בחלק: ציור מספרים בשוליים לפי countBy/restart. אחרת לדחות ולרשום ב‑§8.2.

#### E.2 DoD

- [ ] golden: עמוד עם header first שונה + footer "עמוד X מתוך Y" במרכז דרך tab; vAlign=center; גבולות עמוד double; רקע עמוד צבעוני; סימן מים טקסט מסובב.
- [ ] גובה עמוד קבוע בדיוק (`SizedBox` בגובה pageHeight) — נבדק ברינדור.
- [ ] עברית: footer RTL עם מספר עמוד בעברית (פורמט hebrew1/hebrew2? אם `pgNumType w:fmt="hebrew1"` — להוסיף ל‑NumberFormatter: גימטריה א,ב,ג...; hebrew2 = אותיות) — **חובה למסמכי קודש**.

---

### חלק F — טבלאות 1:1

**מטרה:** פריסת טבלאות זהה ל‑Word, כולל RTL.

**תלות:** B (cnfStyle), C (מדידה), D (פיצול). **קבצים:** [table_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/table_builder.dart), `lib/src/layout/table_layout.dart` (חדש).

#### F.1 אלגוריתם רוחבי עמודות

1. **fixed (`tblLayout="fixed"` או כשיש tblGrid+tcW מלאים):** רוחב עמודה = `gridCol`; tcW דורס; gridSpan סוכם עמודות. רוחב כולל יכול לחרוג מרוחב התוכן — Word לא מכווץ ב‑fixed (overflow מותר; אצלנו: clip לרוחב עמוד + לוג).
2. **autofit:** לכל תא מודדים רוחב מינימלי (המילה הארוכה) ורוחב מועדף (שורה ללא שבירה), מחלקים לפי האלגוריתם של CSS table-layout auto (קירוב טוב ל‑Word): עמודות מקבלות את המועדף אם נכנס, אחרת מצמצמים פרופורציונלית עם רצפת המינימום. `w:tblW pct` → אחוז מרוחב התוכן.
3. תוצר: `List<double> columnWidths` — נשמר ב‑PageModel/מטמון כדי לא לחשב פעמיים (מדידה ↔ רינדור).

#### F.2 גבולות — פתרון קונפליקטים של Word

- בין שני תאים שכנים: הגבול "החזק" מנצח (משקל: גודל קו × סדר סוגי קו — double > single באותו עובי; אם שווים — של התא השמאלי/עליון).
- tcBorders דורס insideH/V של הטבלה; `nil` מבטל; ירושה מסגנון הטבלה לפי cnf.
- מימוש: לחשב לכל קצה‑תא את הקו הסופי לפני הציור (מטריצת קווים H/V), לצייר ב‑CustomPainter אחד לטבלה (מהיר וזול — לא Border לכל תא, שגם גורם לקווים כפולים).

#### F.3 שאר הפיצ'רים

- vMerge (קיים — לוודא restart/continue מלא), gridSpan, gridBefore/After (שורה מוזחת), trHeight (`atLeast`/`exact` — exact חותך תוכן), cellSpacing.
- שוליים פנימיים: tblCellMar ברירת מחדל ←108tw צדדים; tcMar דורס.
- `w:bidiVisual` → היפוך סדר עמודות חזותי (כיוון השורה rtl: `Directionality.rtl` סביב ה‑Row של התאים — אבל המדידה צריכה לדעת זאת גם).
- vAlign בתא (קיים? לוודא), textDirection בתא (`tbRl` → `RotatedBox(quarterTurns:1)` סביב התוכן; `btLr` → 3).
- floating tables (`tblpPr`): עובר למנגנון floats של חלק H (מיקום מוחלט בעמוד + עטיפה אמיתית) במקום ה‑Row הקיים.
- nested tables — ממשיך לעבוד (קיים), עכשיו עם רוחבי autofit אמיתיים.

#### F.4 DoD

- [ ] בדיקות unit לאלגוריתם הרוחב (fixed/autofit/pct) — להשוות לערכים ידועים מ‑Word (לפתוח DOCX אמיתי, למדוד ב‑Word ס"מ, להמיר).
- [ ] golden: טבלה עם merge אנכי+אופקי; banding מסגנון; bidiVisual עברית; גבולות מתנגשים (double מול single); שורת כותרת חוזרת אחרי שבירת עמוד (עם חלק D).
- [ ] ביצועים: טבלה 500 שורות — נמדדת ומרונדרת בלי לחרוג מתקציב פריים (וירטואליזציה דרך פיצול עמודים עוזרת ממילא).

---

### חלק G — רשימות ומספור 1:1

**מטרה:** מספור זהה ל‑Word כולל הפעלות‑מחדש, רב‑רמתי, ועברית.

**תלות:** B. **קבצים:** [list_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/list_builder.dart), [numbering_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/numbering_parser.dart), חדש: `lib/src/layout/numbering_resolver.dart` (viewer).

#### G.1 NumberingResolver — מעבר אחד בסדר מסמך

1. **הבעיה הנוכחית:** המספור מחושב בתוך ה‑builder פר‑רשימה — לא רואה את כל המסמך (רשימה שנקטעת בפסקה וממשיכה; אותו numId בשני מקומות).
2. **הפתרון:** מעבר אחד על כל הבלוקים בסדר מסמך (כולל בתוך תאים!) שמחשב לכל פסקה ממוספרת את מחרוזת המספר הסופית ושומר אותה במפה `paragraph→label` (או annotation על צומת עזר — לא לשנות את ה‑AST). מצב פנימי: counters לכל (numId, ilvl).
3. **כללים:** עליית רמה מאפסת רמות עמוקות (אם `lvlRestart` לא אומר אחרת); `startOverride` ב‑num מאפס בפעם הראשונה; `lvlText` עם `%1.%2` לוקח את הערכים הנוכחיים מכל הרמות; `isLgl` → כל הרמות בפורמט decimal; `suff` → tab (דרך TabEngine!)/space/nothing.
4. פורמטים: decimal, roman, alpha (קיימים ב‑NumberFormatter), bullet (תו מפונט — דרך מיפוי הסמלים של חלק L), `hebrew1` (גימטריה: א,ב,ג…טו,טז…), `hebrew2`, `decimalZero`, `ordinal`, `cardinalText`/`ordinalText` (אנגלית בלבד — fallback decimal + §8.2), `none`.
5. numPicBullet → תמונת bullet (קיים פענוח? לוודא; רינדור כ‑WidgetSpan קטן).

#### G.2 פריסה

- מיקום המספר: לפי lvl/pPr (כניסה+hanging) — המספר יושב בתחילת ה‑hanging indent, הטקסט ב‑indent. `lvlJc` מיישר את המספר עצמו (right בעברית נפוץ).
- RTL: הכול במראה — מספר בימין, כניסות מימין. עם `w:bidi` מה‑AST (חלק A) — לא ניחוש.

#### G.3 DoD

- [ ] unit: רצף 1,2,3 שנקטע בפסקה רגילה וממשיך 4; שתי רשימות עם אותו abstractNum ו‑startOverride; רב‑רמתי `%1.%2.%3`; isLgl; גימטריה עד תשפ"ו (לוודא טו/טז!).
- [ ] golden: רשימה עברית ממוספרת בגימטריה עם תת‑רמות; bullets של Wingdings.
- [ ] בדיקות הרשימות הקיימות ירוקות.

---

### חלק H — תמונות, צורות, תיבות טקסט, ועטיפת טקסט אמיתית

**מטרה:** כל drawing במקומו המדויק על העמוד, עם עטיפת הטקסט של Word.

**תלות:** D (העימוד חייב לדעת על floats). **קבצים:** [image_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/image_builder.dart), [shape_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/shape_builder.dart), `lib/src/layout/float_layout.dart` (חדש), הרחבות parser ב‑docx_creator ([docx_drawing.dart](../packages/docx_creator/lib/src/ast/docx_drawing.dart)).

#### H.1 מודל מיקום

לכל drawing צף: `relativeFrom` (page/margin/column/paragraph/line/character) × (align או posOffset) לשני הצירים + `wrapMode` (square/tight/through/topAndBottom/behindText/inFront) + `distT/B/L/R` (מרחקי עטיפה). לוודא שהכול מפוענח (חלק מזה קיים — להשלים את החסר, כולל `simplePos`, `relativeHeight` כ‑z‑order, `behindDoc`).

#### H.2 אלגוריתם — שילוב בעימוד

1. בזמן עימוד, כשפוגשים פסקה עם anchor צף: מחשבים את מלבן ה‑drawing בקואורדינטות עמוד (לפי relativeFrom + מיקום הפסקה הנוכחי), רושמים אותו כ"אזור חסום" של העמוד (`List<FloatRect>` ב‑PageModel).
2. **עטיפה band‑based (החלטת מימוש):** פסקאות שנמדדות בעמוד עם אזורים חסומים נמדדות ב"רצועות": לכל רצועת‑גובה שחופפת float — הרוחב הזמין קטן (משמאל/מימין לפי מיקום ה‑float). מימוש: מודדים את הפסקה שורה‑שורה; כל שורה מקבלת maxWidth לפי הרצועה שלה; הציור ממקם כל שורה ב‑x המתאים. זה מסלול "פסקה עם floats" נפרד ויקר יותר — חל רק על פסקאות שבאמת חופפות float.
3. `square` = עטיפה סביב המלבן; `tight`/`through` = כמו square (קירוב מלבני, §8.2); `topAndBottom` = אין טקסט בצדדים (הרצועה כולה חסומה); `behindText`/`inFront` = שכבות בלי השפעה על זרימה.
4. ה‑drawing עצמו מרונדר ב‑PageWidget כ‑`Positioned` בשכבה המתאימה (לא בתוך הפסקה!).
5. ה‑Row‑grouping הקיים (`_generateBlockWidgets` floats) **נמחק** אחרי שהמנגנון החדש עובד — אין שני מסלולים.

#### H.3 תוכן הציורים

- תמונות: rotation (`a:xfrm@rot`, יחידות 1/60000 מעלה), flipH/V, crop (`a:srcRect` — אלפיות), שקיפות. רינדור: `Transform.rotate` + `ClipRect` עם `Alignment` ו‑widthFactor — או CustomPainter.
- תיבת טקסט (`wps:txbx`/`v:textbox`): רינדור הבלוקים הפנימיים בתוך Container בגודל הצורה (re‑entry ל‑widget generator עם רוחב התיבה), כולל שוליים פנימיים (`a:bodyPr` insets), אנכי? (vert="vert270" → RotatedBox).
- צורות preset: להרחיב את shape_builder לכיסוי: rect, roundRect, ellipse, line, straightConnector, arrow, triangle, diamond, star5, hexagon — עם fill (solid/gradient בסיסי) + outline. צורות אחרות → מלבן עם הצבע + §8.2.
- VML legacy (`w:pict`): v:shape עם image fill (סימני מים!), v:rect, v:line, v:oval — מינימום שצריך.
- EMF/WMF: אין פענוח native. מדיניות: אם ל‑drawing יש fallback ראסטרי בחבילה (קורה ב‑AlternateContent) — להשתמש בו; אחרת placeholder אפור עם אייקון + רישום ב‑§8.2. **לא** לכתוב ממיר EMF.
- **RAM:** כל `Image.memory` עם `cacheWidth` לפי הגודל המוצג בפועל (du×DPR). גדלים ידועים מה‑AST — אין צורך לפענח כדי לדעת גודל.

#### H.4 DoD

- [ ] golden: תמונה square‑wrap בימין עם טקסט עברי עוטף משמאל; topAndBottom; behindText (קיים); תיבת טקסט עם פסקאות עבריות; צורה מסובבת 45°; סימן מים VML.
- [ ] עוגן בפסקה שנשברה בין עמודים — ה‑float נשאר עם החלק הנכון.
- [ ] מדידת RAM: מסמך עם 50 תמונות גדולות — decoded רק לעמודים נראים (לאמת עם `debugImageOverheadStats` או DevTools memory).

---

### חלק I — טורים מרובים (`w:cols`)

**תלות:** D. **קבצים:** paginator + page_widget.

1. מקטע עם N טורים: הגוף מחולק לטורים ברוחב `(contentWidth − Σspacing) / N` (או רוחבים מפורשים). אלגוריתם המילוי של D רץ פר‑טור: ממלאים טור 1 עד הסוף, עוברים לטור 2, ואז לעמוד הבא. `BlockSlice` מקבל `columnIndex`.
2. `w:br type="column"` → מעבר טור (כמו page break אבל לטור הבא).
3. מקטע `continuous` שמסתיים באמצע עמוד: Word מאזן את הטורים (balancing) — חישוב: סך גובה התוכן / N, מילוי איטרטיבי עד שהטורים שווים ±שורה. (best‑effort; אם מסובך — איזון נאיבי לפי גובה ולתעד.)
4. separator (`w:sep`) → קו אנכי בין טורים.
5. **RTL:** מקטע `bidi` → טור ראשון בימין.
6. DoD: golden דו‑טורי עברי (סדר טורים מימין!), column break, continuous balancing בסיסי. בדיקת paginator לכל הנ"ל.

---

### חלק J — הערות שוליים והערות סיום על העמוד

**תלות:** D. **קבצים:** paginator, page_widget, [docx_footnote.dart](../packages/docx_creator/lib/src/ast/docx_footnote.dart).

1. **מודל Word:** הערת שוליים יושבת בתחתית העמוד שבו מופיע ה‑reference. אזור ההערות גדל כלפי מעלה ומקטין את גוף העמוד.
2. **אלגוריתם:** בזמן מילוי עמוד, כששורה עם footnote ref נכנסת — מוסיפים את גובה ההערה (separator + תוכן ההערה ברוחב מלא) לחשבון: `usedBody + footnotesHeight ≤ bodyHeight`. אם לא נכנס — השורה (וההערה) עוברות לעמוד הבא. הערה ארוכה יכולה להתפצל לעמוד הבא עם continuation separator (שלב 2 — בשלב 1: ההערה כולה בעמוד אחד, clamp אם ענקית).
3. **separator:** קו באורך ⅓ רוחב (ברירת מחדל של Word) מעל ההערות; אם footnotes.xml מכיל פסקאות separator מותאמות (id 0/1, `w:type="separator"/"continuationSeparator"`) — להשתמש בהן.
4. מספור: `w:footnotePr` — פורמט (decimal/roman/symbols/hebrew!), restart eachPage/eachSect — המספר מחושב בעימוד (תלוי‑עמוד!), גם ה‑reference בטקסט וגם בתחתית.
5. הערות סיום: בסוף המקטע/המסמך לפי `w:endnotePr/w:pos`.
6. ה‑Dialog הקיים נשאר כ‑fallback במצב continuous בלבד.
7. DoD: golden עמוד עם 2 הערות עבריות בתחתית; הערה שדוחפת שורה לעמוד הבא; restart eachPage; מספור גימטריה.

---

### חלק K — שדות, TOC, קישורים, SDT, סמלים

**תלות:** D (bookmark map), C (טאבים — ל‑TOC). **קבצים:** field_substitution.dart, field_instruction.dart, paragraph_builder.

1. **TOC:** מרונדר כתוכנו השמור (פסקאות hyperlink עם PAGEREF + tab leader). אחרי חלקים C+D+K — `PAGEREF` חי + נקודות leader = TOC שנראה כמו Word. אין יצירת TOC מחדש (תצוגה = מה ש‑Word שמר, עם עמודים מעודכנים לפי העימוד שלנו).
2. **קישורים פנימיים** (anchor לסימנייה): לחיצה גוללת לעמוד מה‑bookmark map (API: `DocxViewController.jumpToBookmark(name)` + ה‑hyperlink מחווט אליו). חיצוניים: callback `config.onOpenLink(url)` — בלי תלות חדשה בחבילה.
3. **שדות נוספים (לתצוגה נאמנה):** `STYLEREF "Heading 1"` — נפוץ בכותרות של ספרי קודש: הערך = הטקסט של פסקת הסגנון האחרונה **לפני סוף העמוד הנוכחי** (או הראשונה בעמוד — לפי המתג `\l`); מחושב בעימוד כמו PAGE. `REF`/`DATE`/`TIME`/`AUTHOR`/`FILENAME`/`SEQ` → תוצאת המטמון כפי שנשמרה (Word מציג מטמון עד עדכון — זו התנהגות נכונה). `HYPERLINK` כשדה → קישור.
4. **SDT (content controls):** לרנדר את `sdtContent` שקוף (קיים חלקית — לוודא block+inline+cell), checkbox sdt → ☐/☒ (קיים `DocxCheckbox`), dropdown → הטקסט הנבחר.
5. **`w:sym` רינדור:** דרך מיפוי הפונטים של חלק L (אם Wingdings לא זמין — מיפוי תו→Unicode שקול: טבלה סטטית לתווים נפוצים: ✓✗●○■□◆▶☺ וכו'; תו לא ממופה → התו כפי שהוא בפונט fallback).
6. **OMML (נוסחאות):** מחוץ להיקף שלב זה — placeholder עם הטקסט הלינארי אם קיים (`m:t` משורשרים) + §8.2.
7. DoD: golden TOC עברי עם נקודות leader ועמודים חיים; STYLEREF בכותרת עליונה; קישור פנימי קופץ לעמוד נכון.

---

### חלק L — פונטים: התאמה, fallback מטרי, פיצול כתב

**מטרה:** הטקסט נראה ונמדד עם הפונט שהכי קרוב ל‑Word — תנאי הכרחי ל‑1:1 בשבירות שורה.

**תלות:** B. אפשר במקביל מ‑C והלאה. **קבצים:** [embedded_font_loader.dart](../packages/docx_file_viewer/lib/src/font_loader/embedded_font_loader.dart), `lib/src/font_loader/font_resolver.dart` (חדש), paragraph_builder/span_factory.

1. **פיצול ריצה לפי כתב (הליבה של עברית+אנגלית!):** בעת בניית span, ריצה שמכילה גם תווי RTL וגם לטינית מפוצלת לתתי‑spans לפי טווחי כתב: לטינית/מספרים → `rFonts.ascii` + `sz`+`b`/`i`; עברית/ערבית → `rFonts.cs` + `szCs`+`bCs`/`iCs`. `w:hint="cs"` מכריע תווים נייטרליים. (זה בדיוק מה ש‑Word עושה — בלעדיו טקסט מעורב מקבל פונט שגוי.) המימוש ב‑SpanFactory (חלק C) — אבל מופעל כשחלק L מספק את ה‑resolver.
2. **FontResolver:** שם פונט מהמסמך → fontFamily זמין: (א) פונט מוטמע שנטען (קיים); (ב) פונט מערכת באותו שם; (ג) טבלת תחליפים מטריים: Calibri→Carlito, Cambria→Caladea, Times New Roman→Liberation Serif/Tinos, Arial→Liberation Sans/Arimo, Courier New→Cousine, David→David Libre, Narkisim/FrankRuehl→Frank Ruhl Libre…; (ד) generic לפי `w:family` (roman→serif). הטבלה ניתנת להרחבה דרך `DocxViewConfig.fontSubstitutions`.
3. **fontFamilyFallback** לכל TextStyle: רשימה לפי כתב (עברית: David Libre, Noto Sans Hebrew; סמלים: מיפוי K.5) — כדי שתו בודד חריג לא יפיל ל‑placeholder.
4. החבילה **לא** מצרפת פונטים (גודל!) — אבל README/doc מסביר איך האפליקציה מוסיפה fonts מומלצים, ו‑`DocxViewConfig` מאפשר למפות. (האפליקציה של המשתמש כבר כוללת פונטים עבריים.)
5. טעינה עצלה: פונט מוטמע נטען רק אם באמת בשימוש במסמך (לסרוק שימוש לפני טעינה — חוסך RAM במסמכים עם פונטים רבים).
6. DoD: בדיקת פיצול כתב (ריצה "שלום Hello עולם" עם ascii=Arial cs=David, גדלים שונים sz/szCs — שלושה spans עם הפונט והגודל הנכונים); golden מעורב; fallback substitution נבדק.

---

### חלק M — קשיחות ביצועים ו‑RAM (hardening)

**מטרה:** לוודא שכל התקציבים של §2 נאכפים, ולתקן את החריגות הידועות.

**תלות:** D ומעלה (רץ הכי טוב לקראת הסוף, אבל מותר מוקדם אם תקציב נשבר).

1. **חיפוש בלי רגנרציה:** להחליף את `_onSearchChanged` (שבונה את כל המסמך מחדש): ההדגשות מוזרקות בזמן בניית עמוד (ה‑builder כבר מקבל searchController) — שינוי חיפוש רק `setState` שמרענן עמודים בנויים (הווירטואליזציה דואגת שזה מעט). ניווט למטץ' → גלילה לעמוד מה‑match map (block→page ידוע מהעימוד) במקום GlobalKeys על כל בלוק. **למחוק את מנגנון ה‑GlobalKey פר‑בלוק** (BlockIndexCounter keyRegistry) — GlobalKeys לכל בלוק הם בזבוז זיכרון ושבירת וירטואליזציה.
2. **zoom + וירטואליזציה** (ראו §4.1) — `enableZoom` לא מבטל את `ListView.builder`.
3. **isolate parsing:** `DocxReader.loadFromBytes` נעטף `compute` (לוודא שכל הטיפוסים sendable; אם לא — לפענח ב‑isolate ולהעביר מבני ביניים). מדידה לפני/אחרי ביומן.
4. **מטמונים:** לאמת תקרות LRU (מדידות, spans, סגנונות); `imageCache.maximumSizeBytes` מכוון; ניקוי מלא ב‑dispose של DocxView.
5. **פרופיילינג מתועד:** להריץ על מסמך הייחוס ב‑`--profile`, לתעד ביומן: זמן טעינה, זמן עימוד, פריימים איטיים, שיא RAM, מצב יציב. להשוות לתקציבים — כל חריגה = משימת תיקון בתוך החלק.
6. `Timeline.startSync`/`finishSync` עם תוויות (`docx.parse`, `docx.paginate.page`, `docx.page.build`) בנתיבים החמים — דיבוג ביצועים עתידי.
7. DoD: כל תקציבי §2.2 ו‑§2.3 נמדדו ועומדים; תוצאות ביומן; חיפוש במסמך ייחוס ≤ 100ms.

---

### חלק N — מערך אימות 1:1 ורגרסיה

**מטרה:** להוכיח נאמנות, ולמנוע נסיגה.

**תלות:** הכול.

1. **קורפוס fixtures** ב‑`packages/docx_file_viewer/test/fixtures/`: נבנה בקוד עם docx_creator builder (יתרון: דטרמיניסטי) + קבצי DOCX אמיתיים שהמשתמש מספק (ספרי קודש, מעורב עברית/אנגלית). מינימום: hebrew_mixed, tables_complex, lists_multilevel, images_wrapping, footnotes, multi_section, two_columns, toc, fields.
2. **golden tests** פר‑חלק (נוצרו תוך כדי) — לוודא שכולם רצים ב‑CI ירוק; `flutter test --update-goldens` רק עם הצדקה ביומן.
3. **השוואה מול Word (ידנית, מתועדת):** המשתמש מייצא PDF מ‑Word עבור כל fixture אמיתי; משווים עמוד‑עמוד מול screenshot של ה‑viewer באותו גודל. קריטריון: מעברי עמוד ±שורה; אין הבדל מבני נראה לעין. תוצאות בטבלה ביומן.
4. **benchmark אוטומטי:** בדיקה (`test/perf_benchmark_test.dart`) שמודדת זמן parse+paginate על fixture גדול ומכשילה אם חריגה >50% מהתקציב (רף רך נגד רגרסיות).
5. DoD: כל הקורפוס עובר; טבלת השוואה מול Word מלאה; benchmark ב‑CI.

---

## §6. סדר עבודה מסוכם (תרשים תלויות)

```
A (reader) ──► B (styles) ──► C (measure/tabs/bidi) ──► D (paginator) ──► E (page chrome)
                                   │                        ├──► F (tables)
                                   │                        ├──► G (lists)   [F,G אחרי D מומלץ, תלות רכה]
                                   │                        ├──► H (floats)
                                   │                        ├──► I (columns)
                                   │                        ├──► J (footnotes)
                                   │                        └──► K (fields/TOC)
                                   └──► L (fonts) — במקביל מכאן והלאה
M (perf hardening) — אחרי D לפחות; חובה לפני N
N (verification) — אחרון
```

---

## §7. עקרונות פתרון בעיות (כשמשהו לא תואם ל‑Word)

1. פתח את ה‑DOCX כ‑ZIP (`document.xml`) וקרא מה באמת כתוב — אל תנחש.
2. ההתנהגות של Word על המסך היא ההגדרה של "נכון". המפרט — גיבוי.
3. סטייה שאי אפשר לגשר — לתעד ב‑§8.2 עם הסבר, לא להסתיר.
4. כל באג שתוקן מקבל בדיקה שמייצגת אותו.
5. ספק בין שתי דרכי מימוש? בחר את החסכונית ב‑RAM; אם שקולות — את המהירה; אם שקולות — את הפשוטה.

---

## §8. מטריצת נאמנות

### 8.1 כיסוי פיצ'רים (לעדכן עם כל חלק שמסתיים)

| תחום | פיצ'ר | סטטוס | חלק |
|---|---|---|---|
| טקסט | bold/italic/underline/strike/highlight/shd/colors/vertAlign | ✅ קיים | — |
| טקסט | caps/smallCaps/letterSpacing/charScale/position/vanish/sym | 🟨 caps/smallCaps/letterSpacing/kern/**vanish‑skip** מומשו (C); charScale/position/sym נדחו (§8.2 #9, C/K) | A,C,K |
| טקסט | BiDi מ‑`w:bidi`/`w:rtl` + פיצול כתב ascii/cs | 🟨 `w:bidi`/`w:rtl`+szCs/bCs/iCs נקראים (A); יישור BiDi מדויק (טבלת C.4) מחווט; פיצול כתב ascii/cs ב‑L | A,C,L |
| פסקה | יישור/כניסות/ריווח/גבולות/הצללה | ✅ קיים + יישור BiDi מדויק (C.4) | —,C |
| פסקה | tab stops + leaders | 🟨 מנוע `TabEngine` + `TabbedLineRenderer` (C): left/center/right/leaders/RTL/bar; נתיב מחווט לפסקאות עם tabStops מפורשים+טקסט בלבד. נדחה: wrapping, decimal מדויק, ירושת stops מסגנון | C |
| פסקה | keep rules / widow‑orphan | 🟨 נקראים ל‑AST (A); אכיפה בעימוד D | A,D |
| סגנונות | basedOn מלא + toggle + theme colors/fonts + tblStylePr | ✅ מנוע `DocxStyleResolver` (docDefaults+סדר שכבות+toggle XOR בין רמות+flatten עם תקרת עומק/מעגל) **מחווט לייצור** דרך `parseRun`/`parseChildren`; rPrDefault+מעגלי basedOn+קריאת w:val ב‑toggles תוקנו; cnfStyle/tblStylePr עובד ב‑table_parser; theme colors ב‑viewer (tint/shade שקול ל‑B.3). אומת על Word אמיתי | B |
| עימוד | מבוסס מדידה + פיצול פסקה/טבלה | 🟨 מנוע `Paginator` **מחווט לייצור** (21 בדיקות; ההיוריסטי נמחק — נתיב יחיד). M3 מילוי, M4 פיצול פסקה+widow/orphan, M5 פיצול טבלה+חזרת כותרת, מקטעים+evenPage blank, keepNext/keepLines, מפות bookmark/footnote. נשאר: async time‑slicing (§4.4) + אימות Word על מכשיר | D |
| עמוד | גודל/שוליים/gutter מהמסמך | ✅ קיים | — |
| עמוד | header/footer וריאנטים + שדות PAGE/NUMPAGES חיים | 🟨 קיים, ממתין לעימוד אמיתי | D,E |
| עמוד | vAlign/גבולות עמוד/סימן מים/רקע | 🟨 vAlign/pgBorders נקראים ל‑AST (A); רינדור ב‑E | A,E |
| טבלה | borders/shading/merge/nested | ✅ קיים בסיסי | — |
| טבלה | autofit אמיתי/קונפליקט גבולות/bidiVisual/cellMar/cantSplit | 🟨 מאפיינים נקראים ל‑AST (A: bidiVisual/tblLayout/tcMar/cantSplit/…); פריסה ב‑F | A,F |
| רשימות | מספור בסיסי+roman/alpha | ✅ קיים | — |
| רשימות | resolver גלובלי/startOverride/isLgl/גימטריה/numPicBullet | ⬜ | G |
| ציורים | תמונות inline/floating בסיסי/behindDoc | ✅ קיים בסיסי | — |
| ציורים | wrap אמיתי/מיקום מוחלט/תיבות טקסט/rotation/crop/VML | ⬜ | H |
| טורים | w:cols | 🟨 `w:cols` נקרא ל‑AST (A); פריסה ב‑I | A,I |
| הערות | שוליים/סיום על העמוד | ⬜ (Dialog כיום) | J |
| שדות | PAGE/NUMPAGES/SECTIONPAGES/PAGEREF | ✅ פענוח+החלפה | — |
| שדות | STYLEREF/TOC חי/קישורים פנימיים | ⬜ | K |
| פונטים | מוטמעים (כולל obfuscated) | ✅ קיים | — |
| פונטים | תחליפים מטריים/fallback לפי כתב/טעינה עצלה | ⬜ | L |
| נוסחאות | OMML | ⬜ מחוץ להיקף (placeholder) | K |

### 8.2 סטיות מודעות מ‑Word (לעדכן בכל פשרה)

| # | סטייה | סיבה | חלק | חומרה |
|---|---|---|---|---|
| 1 | `tight`/`through` wrap מקורבים כ‑square (מלבן) | עלות מימוש קונטור גבוהה מאוד | H | נמוכה |
| 2 | EMF/WMF — placeholder אם אין fallback ראסטרי | אין מפענח native ב‑Flutter | H | בינונית |
| 3 | art page borders → קו רגיל | נכסים גרפיים לא זמינים | E | נמוכה |
| 4 | **toggle XOR לא מוחל על שרשרת basedOn** — רק בין רמות (פסקה×תו). שרשרת basedOn = ירושה רגילה | קריאת ISO מילולית (XOR על כל חוליה) כנראה לא תואמת Word; ירושה רגילה זהה לנתיב הייצור המוכח | B | נמוכה |
| 5 | **direct‑toggle דורס** את תוצאת הסגנון (במקום XOR) | ISO §17.7.3 מדגים XOR ברובד ה‑direct; אך Word שומר `w:val="0"` לכיבוי (מטופל נכון), כך שמעשית מוזניח. טעון golden | B | נמוכה |
| 6 | strike (decorations) בירושה = last‑wins, לא XOR/אדיטיבי | `decorations` מאגד underline+strike; אין ייצוג ל"כבוי" | B | נמוכה |
| 7 | ~~line spacing exact/atLeast כ‑`TextStyle.height`~~ → **מומש ✅** כ‑`StrutStyle` (`forceStrutHeight` ל‑exact, מינימום ל‑atLeast) בשני הנתיבים (`resolveStrut`). ראו יומן 2026‑06‑11 (סגירת פערים) | — | — |
| 8 | ~~`w:vanish` מרונדר ונמדד~~ → **מומש ✅** דילוג מתואם ב‑renderer + measurer + אינדקס החיפוש (`_extractFromInlines`). ראו יומן 2026‑06‑11 | — | — |
| 9 | `w:w` (charScale) ו‑`w:position` (raise/lower) עדיין לא מרונדרים | נדיר; דורש WidgetSpan+Transform + placeholder תואם במדידה — סיכון ל**עקרון מדידה≡רינדור** עבור פיצ'ר נדיר. כרגע **שקול בין מדידה לרינדור** (שני הנתיבים מתעלמים זהה), כך שאין סטיית עימוד | C | נמוכה |
| 10 | tabbed line ללא wrapping; decimal≈right; ירושת tab‑stops מסגנון לא מושחלת; highlight חיפוש מדולג בפסקת tab | `TabbedLineRenderer` מכוון לכותרות/כותרות תחתונות (שורה אחת). נתיב מותנה ב‑`tabStops` מפורשים+טקסט בלבד כדי לא לשבור wrapping של פסקאות עם tab מוביל | C | בינונית |
| 11 | golden הטאבים = בדיקת **מיקום** דטרמיניסטית, לא golden‑image | קובצי ה‑golden/fixtures חסרים בצ'קאאוט (קדם‑קיים, לוג A/B). בדיקת מיקום עדיפה על golden שבור | C | נמוכה |
| 12 | ה‑`TextMeasurer` מודד פסקת‑tab כטקסט עוטף רגיל (tab=4 רווחים), בעוד הרינדור עובר דרך `TabEngine` (שורה אחת, מיקומי stop אמיתיים) | פער parity לפסקאות tab בלבד. לרוב כותרות קצרות = שורה אחת בשני המסלולים → תואם בפועל. **חלק D חייב למדל את ה‑TabEngine** במדידה (TODO ב‑`text_measurer.dart`) | C/D | בינונית |
| 13 | פיצול פסקה/טבלה בעימוד יוצר **פסקאות/טבלאות‑פרוסה קלות** (head/tail כ‑`DocxNode` אמיתי שמשתף את כל ה‑inline/שורות שאינם על הגבול ב‑reference; משכפל רק את ריצת הטקסט/שורה הגבולית) במקום טווחי תווים/שורות טהורים על הצומת המקורי (§2.4.1/§D.1). הסיבה: הרינדור צריך את החיתוך ממילא, ותרגום offsets בין פיצולים חוזרים (פסקה שמשתרעת על 3+ עמודים) שביר; עלות ה‑RAM = O(מספר הפיצולים) אובייקטים זעירים, לא O(תוכן). `BlockSlice` שומר עדיין `startRow/endRow` לטבלאות ו‑height מדוד | D | נמוכה |
| 14 | מדידת טבלה לעימוד = **רוחב עמודות שווה** (חלוקת `contentWidth`/N פחות שולי תא 108tw), לא autofit אמיתי. שבירת מקטע `continuous` ממשיכה באותו עמוד עם הגאומטריה הקודמת (שינוי טורים = חלק I) | autofit אמיתי = חלק F; כאן רק מדידת גובה לאריזת עמודים. רוחב שווה = קירוב טוב דיו לשבירת עמוד | D/F/I | בינונית |
| 15 | ה‑`Paginator` **סינכרוני וטהור** (נבדק ללא widget tree); time‑slicing אסינכרוני (§4.4), placeholder לעמודים שטרם עומדו, ותקציבי הביצועים של §2.2/§2.3 — **טרם מומשו**; ייכנסו עם החיווט ל‑`DocxView`/חלק M | D/M | בינונית |

---

## §9. לוח סטטוס — **ה‑AI מעדכן כאן**

| חלק | שם | סטטוס | הערות |
|---|---|---|---|
| A | השלמת Reader | ✅ הושלם 2026-06-10 | A.1–A.6 מפוענחים + round‑trip; פירוט ביומן |
| B | מנוע סגנונות | ✅ הושלם 2026-06-11 | `DocxStyleResolver` **מחווט לייצור**; 379 בדיקות + אומת על Word אמיתי; auto‑color+perf סגורים (מנוע פי ~5.6 מהיר). סטיות מודעות מתועדות (§8.2 #4–6). שאריות nice‑to‑have: golden ל‑#1, אימוץ helpers ב‑viewer |
| C | מדידה/טאבים/BiDi | ✅ הושלם 2026-06-11 | `SpanFactory` (מקור אמת אחד), `TextMeasurer` (LRU+מטמון, parity ±0.5px, **StrutStyle** ל‑exact/atLeast, baseline), טבלת BiDi C.4, `TabEngine`+`TabbedLineRenderer`, **דילוג vanish**. **97 בדיקות ירוקות** (≈36 חדשות). #7/#8 נסגרו (יומן 2026‑06‑11 "סגירת פערים"). שאריות דחויות = §8.2 **#9–11** (charScale/position, wrapping של tab+decimal+ירושת stops, golden‑image) — נדירים/לא חוסמים את D, parity נשמר |
| D | מנוע עימוד | 🟨 כמעט הושלם — נשאר streaming UX + אימות מכשיר | **מנוע+חיווט+§D.2.5+async הושלמו** (22 בדיקות): מילוי מבוסס‑מדידה, פיצול פסקה (widow/orphan), פיצול טבלה (חזרת כותרת+cantSplit), מקטעים+evenPage blank, keepNext, פיצול שבירת‑עמוד אמצע‑פסקה (§D.2.5), מפות bookmark/footnote. **ההיוריסטי נמחק** — נתיב יחיד. `PageContext` אמיתי (PAGE/NUMPAGES/SECTIONPAGES/PAGEREF, even/odd, multi‑section); חיפוש מיושר לפרוסות. **time‑slicing אסינכרוני** (`paginateAsync`/`generateWidgetsAsync`, מנות ≤8ms — UI לא קופא). **אומת מול Word: 7 עמ' = 7 עמ'** ב‑formatting-demo (פונט+ריווח אמיתיים). ריווח ברירת‑מחדל הודק 1.5→1.15. **נשאר:** streaming של עמודים מוכנים + placeholder (§4.4), מדידת תקציבי §2 על מסמך ייחוס, אימות ידני מול Word על מכשיר (3 מסמכים). יומן 2026‑06‑11/12 |
| E | קליפת עמוד | ⬜ לא התחיל | |
| F | טבלאות 1:1 | ⬜ לא התחיל | |
| G | רשימות 1:1 | ⬜ לא התחיל | |
| H | ציורים ועטיפה | ⬜ לא התחיל | |
| I | טורים | ⬜ לא התחיל | |
| J | הערות שוליים | ⬜ לא התחיל | |
| K | שדות/TOC | ⬜ לא התחיל | |
| L | פונטים | ⬜ לא התחיל | |
| M | ביצועים/RAM | ⬜ לא התחיל | |
| N | אימות 1:1 | ⬜ לא התחיל | |

ערכי סטטוס מותרים: `⬜ לא התחיל` · `🟨 בעבודה — <מה נשאר>` · `✅ הושלם <תאריך>` · `⛔ חסום — <סיבה>`

---

## §10. יומן מסירה — **רק להוסיף, לא לערוך**

> תבנית רשומה:
> ```
> ### [תאריך] — [חלק] — [סטטוס בסיום הסשן]
> **בוצע:** ...
> **החלטות/סטיות:** ...
> **בעיות פתוחות:** ...
> **ל‑AI הבא:** ...
> ```

### 2026-06-10 — הקמת המסמך — תכנון
**בוצע:** נכתב מסמך זה. בוצע ניתוח פערים מלא מול הקוד (ראו §3). אומת שהעבודה האחרונה בענף (שדות עמוד, NumberFormatter, וריאנטי header/footer, FieldSubstitution) מקבילה ל‑M0–M2 של מסמך המחקר ומשולבת כ"קיים" בתוכנית.
**החלטות/סטיות:** שם הקובץ נבחר `WORD_FIDELITY_VIEWER_PLAN.md` כי הערות קיימות בקוד כבר מפנות אליו ([docx_view.dart](../packages/docx_file_viewer/lib/src/docx_view.dart) §4.1, [docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart)).
**בעיות פתוחות:** אין.
**ל‑AI הבא:** להתחיל בחלק A. לקרוא §0 ו‑§2 לפני הכול.

### 2026-06-10 — חלק A (השלמת ה‑Reader) — ✅ הושלם
**בוצע:** כל A.1–A.6 — פענוח מלא ל‑AST + round‑trip ב‑`buildXml` + בדיקות ייעודיות לכל קבוצה.
- **A.1 פסקה** ([docx_block.dart](../packages/docx_creator/lib/src/ast/docx_block.dart), [block_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/block_parser.dart)): `w:bidi`→`isRtl`, `keepNext`, `keepLines`, `widowControl`, `w:tabs`→`tabStops` (`DocxTabStop`+`DocxTabAlignment`+`DocxTabLeader` ב‑[enums.dart](../packages/docx_creator/lib/src/core/enums.dart)), `suppressAutoHyphens`, `contextualSpacing`; תוקן פענוח `pageBreakBefore`/`textAlignment`/`outlineLvl` (היו במודל אך לא נקראו). ה‑viewer ([paragraph_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/paragraph_builder.dart), [list_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/list_builder.dart)) משתמש כעת ב‑`isRtl` כמקור אמת ל‑BiDi, עם ה‑detector כ‑fallback בלבד (נוסף `isRtl` ל‑`DocxListItem`).
- **A.2 ריצה** ([docx_inline.dart](../packages/docx_creator/lib/src/ast/docx_inline.dart), [inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart)): `w:rtl`, `w:szCs`/`w:bCs`/`w:iCs`, `w:kern`, `w:position`, `w:w` (charScale), `w:fitText`, `w:vanish`→`hidden`, `w:em`→`DocxEmphasisMark`. (`w:spacing` ברמת ריצה כבר היה כ‑`characterSpacing`.)
- **A.4 טבלה** ([docx_table.dart](../packages/docx_creator/lib/src/ast/docx_table.dart), [table_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/table_parser.dart)): `bidiVisual`, `tblLayout`, `tblInd`, `tblCellMar`/`tcMar`→`DocxCellMargins` (dxa+nil), `tblCellSpacing`, `cantSplit`, `gridBefore/gridAfter/wBefore/wAfter`, `textDirection`→`DocxCellTextDirection`, `noWrap`, `tcFitText`, `hideMark`.
- **A.5 מקטע** ([docx_section.dart](../packages/docx_creator/lib/src/ast/docx_section.dart), [section_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/section_parser.dart)): `w:cols`→`DocxColumns`/`DocxColumn`, `w:vAlign`→`DocxSectionVAlign`, `w:pgBorders`→`DocxPageBorders`, `w:lnNumType`→`DocxLineNumbering`, `w:bidi`→`isRtlSection`, `w:rtlGutter`, `w:footnotePr`/`w:endnotePr`→`DocxNoteProperties`.
- **A.3 inlines** : `w:sym`→`DocxSymbol` (שומר font+char; `glyphIndex` מקזז F000), `w:noBreakHyphen`/`w:softHyphen`→`DocxText` Unicode, `w:cr`→`DocxLineBreak`, `w:ptab`→`DocxPositionalTab`, `mc:AlternateContent` (Choice→Fallback, לא מאבד תוכן). track‑changes: `w:ins`/`w:moveTo` מוצגים, `w:del`/`w:moveFrom` נזרקים (גם ב‑block_parser).
- **A.6 settings.xml** ([docx_reader.dart](../packages/docx_creator/lib/src/reader/docx_reader/docx_reader.dart), [docx_document_builder.dart](../packages/docx_creator/lib/src/builder/docx_document_builder.dart)): `w:defaultTabStop`, `w:footnotePr`/`w:endnotePr` גלובליים. נחשף דרך `DocxReader.parseSettings`→`DocxDocumentSettings` (testable) ועל `DocxBuiltDocument`.

**בדיקות:** 5 קבצי בדיקה חדשים ב‑`docx_creator/test/` (paragraph_properties, run_properties, table_properties, section_properties, inline_extras, settings_parsing). `docx_creator`: **356 ירוקות**, 0 שגיאות analyze. `docx_file_viewer`: 61 ירוקות, `flutter analyze` נקי.

**החלטות/סטיות מהתוכנית:**
1. **ירושת סגנון של המאפיינים החדשים נדחתה לחלק B.** מאפייני A.1/A.2 נקראים ישירות מ‑`pPr`/`rPr` (לא דרך `DocxStyle`), ולכן בשלב זה אין ירושה מסגנון/מקטע עבורם. זה תואם את התוכנית (B הוא ה‑StyleResolver). `isRtl` שמסומן ישירות גובר; כשהוא false נשארת ההיוריסטיקה של ה‑detector — כך פסקה עברית שיורשת bidi מסגנון עדיין מזוהה נכון דרך ה‑fallback.
2. `widowControl` נשמר non‑nullable עם ברירת מחדל true (ברירת המחדל של Word); נכתב חזרה רק במצב off (`w:val="0"`).
3. הפענוח המינימלי של sectPr ב‑[block_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/block_parser.dart) `_parseSectionProperties` (למעברי מקטע אמצע‑מסמך) נשאר pgSz+pgMar בלבד — הפענוח המלא של A.5 נמצא ב‑`SectionParser`. לאחד בעת הצורך (רלוונטי לחלק D — מקטעים מרובים).
4. `DocxSymbol`/`DocxPositionalTab` נוצרו ונקראים, אך עדיין לא מרונדרים (רינדור: C/K). ה‑viewer מדלג בחן על טיפוסי inline לא‑מוכרים (שרשרת if/else, ללא קריסה).

**בעיות פתוחות:** 4 בדיקות golden ב‑[hebrew_rtl_golden_test.dart](../packages/docx_file_viewer/test/hebrew_rtl_golden_test.dart) נכשלות עם `PathNotFoundException` — קובצי ה‑fixture (`example/assets/*.docx`) וה‑goldens (`test/goldens/*.png`) **חסרים בצ'קאאוט המקומי** (התיקיות ריקות). כשל קיים מראש, לא קשור לחלק A (גם `footer`/`frame` שאינם נוגעים ל‑BiDi נכשלים מאותה סיבה). יש לספק את ה‑fixtures כדי להריץ אותן.
**ל‑AI הבא:** חלק B (מנוע resolution של סגנונות). בין היתר להעביר את ירושת מאפייני A.1/A.2 ל‑resolver, ולחבר `paragraph_builder`/`table_builder` אליו.

### 2026-06-10 — חלק A — סקירת קוד ותיקונים
**בוצע:** טופלה סקירת קוד חיצונית של חלק A. תוקנו (reader, בתוך היקף, נבדק):
- mc:AlternateContent: חיפוש Choice/Fallback לפי **local-name** (תומך ב‑prefix שונה ל‑namespace של MC) + הסרת קוד מת ([inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart)).
- `w:cols` עם `w:col` מפורשים ובלי `w:equalWidth` → מוסק `equalWidth=false` כדי לשמר את רוחבי הטורים ב‑round‑trip ([section_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/section_parser.dart)) + בדיקה.
- חודד ה‑doc‑comment של `hidden` (`w:vanish`) שלא יבטיח התנהגות רינדור שטרם מומשה.

**נדחה במכוון (מתועד) — שייך לחלקים מאוחרים לפי הארכיטקטורה:**
1. **כתיבת מאפייני המקטע החדשים בנתיב הייצוא הראשי** ([document_generator.dart](../packages/docx_creator/lib/src/exporters/docx/generators/document_generator.dart) `_buildSectionProperties` כותב רק headerRef/footerRef/pgSz/pgMar). המאפיינים נוספו ל‑`DocxSectionDef.buildXml` (צומת AST), אך ה‑**exporter מחוץ להיקף** (§1.2 אוסר לגעת ב‑`exporters/**`). תוצאה: round‑trip מלא של טורים/גבולות‑עמוד/vAlign/lnNum/bidi/footnotePr רק דרך נתיב שבירת‑מקטע. לאחד את שני הסריאליזרים כשייפתח היקף ה‑exporter.
2. **רינדור `DocxSymbol`/`DocxPositionalTab` ודילוג על `hidden` (w:vanish) ב‑viewer** → חלק **C** (SpanFactory מאחד את מסלולי ה‑spans; §C.1/§C.5). מימוש עכשיו בקוד הקיים = dual‑path נגד §2.4.6, ועלול לשבור offsets של חיפוש/בחירה (כפי שצוין בסקירה). לא רגרסיה (קודם היו `DocxRawInline`/טקסט רגיל). מיפוי סמלים font‑specific → חלק **K** (§K.5).
3. הערות מינוריות (`_intVal` מתעלם מסיומות יחידה; `DocxSymbol.accept` כ‑fallback ויזואלי) — מקובלות, ייסגרו עם רינדור הסמלים בחלק K.

**בדיקות:** `docx_creator` ירוק (כולל הבדיקה החדשה ל‑equalWidth), `flutter analyze` נקי.

### 2026-06-11 — חלק B (מנוע סגנונות) — 🟨 בעבודה
**בוצע:**
- **מנוע `DocxStyleResolver`** ([style_engine.dart](../packages/docx_creator/lib/src/reader/docx_reader/models/style_engine.dart), מיוצא דרך הספרייה הראשית) — מימוש מלא של הסמנטיקה של חלק B:
  - **docDefaults** (`rPrDefault`/`pPrDefault`) כשכבה הנמוכה ביותר (B.1 שלב 1).
  - **סדר השכבות** (B.1): docDefaults → שרשרת `pStyle` (basedOn מהשורש ולמטה) → שרשרת `rStyle` → ישיר.
  - **toggle properties — XOR** (B.2, ISO 17.7.3) עבור `b, i, caps, smallCaps, dstrike, outline, shadow, emboss, imprint`: XOR על פני שכבות ה**סגנון** בלבד; docDefaults כבסיס‑גיבוי; ערך **ישיר** דורס. (מימוש דרך `merge` הקיים שהוא last‑wins‑נכון, כך שאין שכפול AST.)
  - **flatten של שרשרת basedOn** פעם אחת לכל styleId עם **מטמון**, **תקרת עומק** (12) ו**שמירת מעגל** (visited set).
  - מטמון נפרד ל‑run/paragraph לפי `(pStyleId|rStyleId)`; ישיר מוחל מעל פר‑קריאה (זול).
- **`ThemeColorResolver`** (אותו קובץ) — מתמטיקה מדויקת של tint/shade לפי B.3: `tint: c*tint+255*(1‑tint)`, `shade: c*shade`, פענוח בייט‑hex (`FF`=1.0), + resolve לפי שם סכמה.
- **תיקון באג חי — rPrDefault** ([inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart) `parseRun`): מאפייני ברירת המחדל של ה‑run (גופן/גודל מ‑`w:rPrDefault`) **לא הוחלו כלל** קודם — ריצות בלי גודל מפורש נפלו לברירת מחדל של ה‑viewer במקום לברירת המחדל של המסמך. כעת `defaultRunStyle` הוא השכבה הנמוכה ומוחל לפני סגנון הפסקה.
- **תיקון חי — מעגלי basedOn** ([reader_context.dart](../packages/docx_creator/lib/src/reader/docx_reader/reader_context/reader_context.dart)): `resolveStyle` שמר רק מפני הפניה‑עצמית ישירה; A→B→A היה לולאה אינסופית. נוסף `visited` set.
- **בדיקות:** 15 בדיקות חדשות ב‑[style_engine_test.dart](../packages/docx_creator/test/style_engine_test.dart) — שרשרת basedOn תלת‑רמתית; toggle XOR (bold פעמיים/שלוש, caps, ישיר דורס); rPrDefault מוחל; שרשרת תווים (rStyle); מעגל basedOn + תקרת עומק; tint/shade; cnfStyle של שורה ראשונה דרך נתיב ה‑table_parser האמיתי.

**בדיקות (סך הכול):** `docx_creator`: **372 ירוקות** (כולל 15 החדשות), `flutter analyze` נקי (נשארו 3 הערות `info` של `unnecessary_import` בקבצי בדיקה שלא נגעתי בהם — קדם‑קיימות). `docx_file_viewer`: **61 ירוקות**, `flutter analyze` נקי; 4 בדיקות golden עדיין נכשלות עם `PathNotFoundException` (fixtures חסרים בצ'קאאוט — קדם‑קיים, מתועד בלוג A).

**החלטות/סטיות מהתוכנית (§0.3):**
1. **ארכיטקטורה: ה‑resolution נשאר ב‑reader (parse‑time, baked ל‑AST), לא render‑time כפי שמרומז ב‑§4.** הסיבה: (א) ה‑AST כבר אופה את הסגנונות ל‑`DocxText` והצרכנים הקיימים (exporters, אפליקציית `shnayim-mikra-build`) נשענים על כך — מעבר ל‑render‑time שובר את ה‑API (אסור, §1.2); (ב) resolve‑פעם‑אחת‑ב‑parse **חסכוני יותר** ב‑RAM/CPU מ‑re‑resolve פר widget‑build, ותואם את §2.4.6 (אין רגנרציה). לכן המנוע מייצר `DocxStyle` ממוזג (אותה צורה שהקורא אופה) ומשתלב בלי לשנות AST/API. כוונת ה‑DoD ("ה‑builder צורך את ה‑resolver") מסופקת דרך הקורא, לא דרך re‑resolve ב‑widget.
2. **שם המחלקה `DocxStyleResolver`** (ולא `StyleResolver` כבתוכנית) כי `StyleResolver`/`ResolvedStyle` כבר קיימים ומיוצאים ב‑[resolved_style.dart](../packages/docx_creator/lib/src/reader/docx_reader/models/resolved_style.dart) (API ציבורי — אסור לשבור). הישן נשאר ללא שינוי (לא בשימוש מהותי; מועמד ל‑deprecation).
3. **XOR ל‑decorations (קו תחתון/strike) לא יושם** — `decorations` ב‑`DocxStyle` הוא רשימה שמאגדת underline+strike, ואין ייצוג ל"כבוי"; נשמרה התנהגות last‑non‑empty‑wins הקיימת כדי לא לסכן רגרסיות. ה‑toggle המרכזי (bold/italic/caps/…) — XOR מלא. (להוסיף ל‑§8.2 אם יתברר כפער נראה.)
4. **cnfStyle/tblStylePr** כבר ממומש ב‑[table_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/table_parser.dart) `_resolveCellStyle` (tblLook + מסכת תנאים). לא שוכפל למנוע כדי לא ליצור dual‑path (§2.4.6). הבדיקה ל‑DoD מאמתת את הנתיב הקיים.

**בעיות פתוחות / מה שטרם הושלם ל‑✅:**
- **חיווט מלא של ה‑reader למנוע (toggle‑XOR חי end‑to‑end).** כיום ה‑toggle‑XOR קיים ונבדק במנוע אך **לא בנתיב הבייקינג החי**: `parseRun` עדיין ממזג שרשרת קרוסה (`context.resolveStyle` עושה last‑wins על שרשרת ה‑basedOn), כך ש‑double‑bold דרך basedOn עדיין לא מתבטל ברינדור. הנתיב החי קיבל רק את תיקון rPrDefault + שמירת מעגל.
- מיפוי theme‑color ב‑viewer ([paragraph_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/paragraph_builder.dart) `_resolveColor`) עדיין משתמש ב‑`alphaBlend` ולא בנוסחת B.3 המדויקת של `ThemeColorResolver`.

**ל‑AI הבא (השלמת B ל‑✅):**
1. **חיווט ה‑run resolution למנוע:** הדרך הנקייה — להעביר את `paragraphStyleId` דרך `parseChildren`→`parseRun` (במקום/בנוסף ל‑`parentStyle` הממוזג), ולקרוא `resolver.resolveRun(paragraphStyleId, runStyleId: rStyle, direct: parsedProps∪paragraphMarkRPr)`. שים לב לסמנטיקה של מאפייני סימן‑הפסקה (`pPr/rPr`) — הם "ישיר", לא סגנון בעל‑שם. לחלופין, נתיב מוכל יותר: לנתב את `context.resolveStyle` עצמו דרך המנוע כדי לקבל toggle‑XOR על שרשרת ה‑basedOn (התרחיש הנפוץ), תוך טיפול ב‑fallback‑ל‑Normal ובסוגי סגנון (לא להחיל pPrDefault על סגנון תווים).
2. לאמץ את `ThemeColorResolver` ב‑`_resolveColor` של ה‑viewer (נוסחת tint/shade מדויקת + auto‑color על רקע כהה).
3. להריץ מחדש את כל הבדיקות ולהשוות baked output על מסמך עם docDefaults+toggles; ליישב כל היפוך מול Word.

### 2026-06-11 — חלק B — מענה לסקירת קוד (QA)
**בוצע:** טופלה סקירת QA חיצונית של חלק B. תוקן/הוחלט:
- **🔴 #1 — ה‑toggle parser התעלם מ‑`w:val`** ([docx_style.dart](../packages/docx_creator/lib/src/reader/docx_reader/models/docx_style.dart) `_parseRunProperties`): קודם `<w:b w:val="0"/>` (כיבוי מפורש) התפרש כהדלקה, מה ששבר את כל הרציונל של מנוע ה‑XOR ומנע כיבוי toggle שנירש. כעת כל ה‑toggles (`b, i, caps, smallCaps, dstrike, outline, shadow, emboss, imprint, strike`) נקראים דרך `readOnOff` הקיים (tri‑state: null=נעדר, ומכבד `0/false/off`). נוסף helper `_onOff`.
- **🔴 #2 — קוד מת/API מוקדם:** המנוע (`DocxStyleResolver`/`ThemeColorResolver`) **בוטל מהייצוא** ב‑[docx_creator.dart](../packages/docx_creator/lib/docx_creator.dart) — הוא רכיב **פנימי שטרם חובר** ל‑pipeline, ואסור להתחייב עליו כ‑API ציבורי לפני שהוא מחובר ומאומת. הבדיקות מייבאות אותו דרך הנתיב הפנימי. (החלטה לפי האופציה שהוצעה בסקירה: לא לייצא עד חיווט.)
- **🔴/🟡 #3 — ספק תקני ב‑XOR‑על‑basedOn:** **לא חיברתי את המנוע ל‑pipeline בכוונה**, כי החלת XOR על כל שרשרת ה‑basedOn אינה מאומתת מול Word (ייתכן ש‑Word מתייחס ל‑basedOn כירושה רגילה "הקרוב מנצח", ושומר XOR לאינטראקציה **בין רמות** בלבד). חיווט עכשיו היה מסכן רינדור שגוי של מסמכים אמיתיים. נוסף caveat בולט ב‑docstring; דרוש golden ממסמך Word אמיתי כדי לנעול לפני חיווט. (אינני יכול לייצר קובץ Word — דרושה אספקה מהמשתמש.)
- **תיקון סמנטי שנגזר מ‑#1:** כעת שה‑parser מספק `false` אמיתי — עודכן מנוע ה‑toggle מ‑XOR‑טהור ל‑`_resolveToggle`: ערך **on** הופך זוגיות (XOR), אך **off מפורש מאפס לכבוי** (לא no‑op). כך `<w:b w:val="0"/>` בסגנון‑בן מכבה bold שנירש, ובמקביל שרשראות all‑on עדיין עובדות בזוגיות.
- **🟡 #4** — נוספה בדיקה שנועלת את ההחלטה ש‑docDefaults הוא בסיס‑גיבוי ולא משתתף ב‑XOR.
- **🟡 #5** — תועד שקיטום ה‑chain ב‑maxDepth מפיל את שכבת השורש (תיאורטי ב‑12; קובץ פגום), קיטום שקט במכוון.
- **🟡 #6** — הוסרה מחרוזת‑הקסם: נוספו `DocxStyle.overlayId`/`emptyId` והמנוע + `merge` + `empty()` משתמשים בהם.
- **🟡 #7** — תועד ב‑docstring של `ThemeColorResolver` ש‑tint+shade מצטברים (במקום לדחות קלט פגום) ושמתמטיקת ה‑RGB היא קירוב ל‑HSL של Word.
- **🟢** — נוקתה הערת "instruction" מתה ב‑`_parseRunProperties`; נוספו בדיקות: כיבוי מפורש בסגנון‑בן, direct מכבה toggle שנירש, XOR בין סגנון‑פסקה לסגנון‑תו, tint+shade יחד.

**נדחה במכוון (מתועד):**
- חיווט המנוע ל‑pipeline ומחיקת הנתיב הישן — תלוי ב‑golden של #3 (ראו "ל‑AI הבא" ברשומת B המקורית). עד אז מתקיים נתיב יחיד **בייצור** (ה‑reader הישן), והמנוע פנימי בלבד — כך שאין שתי מערכות resolution פעילות במקביל.
- **🟢 שם המחלקה** (`DocxStyleResolver` מול `StyleResolver` הישן) — לא שונה כדי לא לייצר churn; כשהישן יוצא מ‑deprecation אפשר לאחד.
- מיפוי `||` של toggles ב‑[resolved_style.dart](../packages/docx_creator/lib/src/reader/docx_reader/models/resolved_style.dart) (ה‑StyleResolver הישן) — לא בשימוש ב‑pipeline; יטופל כשהישן יוסר.

**בדיקות:** `docx_creator`: **377 ירוקות** (20 בדיקות מנוע, כולל החדשות), `flutter analyze` נקי. `docx_file_viewer`: **61 ירוקות**, analyze נקי; אותן 4 golden נכשלות על fixtures חסרים (קדם‑קיים).

**בעיות פתוחות:** כנ"ל ברשומת B המקורית + **דרוש golden ממסמך Word אמיתי** כדי לפתור את שאלת ה‑XOR‑על‑basedOn (#3) — זהו ה‑prerequisite לחיווט המנוע לייצור.
**ל‑AI הבא:** ספק/בקש מהמשתמש מסמך `.docx` אמיתי שנשמר מ‑Word עם שרשרת basedOn של toggle (למשל סגנון מודגש → סגנון‑בן מודגש), קבע את ההתנהגות הנכונה, נעל golden, ואז חבר את המנוע ומחק את נתיב ה‑merge הישן.

### 2026-06-11 — חלק B — הכרעת סמנטיקת basedOn (פתירת #3 בלי golden)
**בוצע:** הוכרעה שאלת ה‑XOR‑על‑basedOn (#3 מהסקירה) לטובת הפרשנות השמרנית והבטוחה: **שרשרת basedOn = ירושה רגילה "הקרוב מנצח"** (זהה ל‑`ReaderContext.resolveStyle` שכבר רץ בייצור), ו‑**toggle‑XOR מוחל רק בין הרמות** (סגנון‑פסקה מול סגנון‑תו) — המקרה הקנוני והמתועד של Word (סגנון הדגשה על טקסט שכבר מודגש → מתבטל). שינוי במנוע ([style_engine.dart](../packages/docx_creator/lib/src/reader/docx_reader/models/style_engine.dart)): נוסף `_collapseChain` (ממזג כל שרשרת בירושה רגילה, ממוטמן), ו‑`resolveRun`/`resolveParagraph` מזינים ל‑XOR את הרמות הממוזגות (≤2) במקום כל חוליות השרשרת. הוסר ה‑caveat על XOR‑על‑basedOn.
**החלטות/סטיות:** העדפתי הכרעה שמרנית על פני המתנה ל‑golden, כי ירושה‑רגילה היא בדיוק התנהגות הייצור הקיימת (סיכון אפס) ומתאימה לרוב המוחלט של המסמכים; ה‑golden נחוץ כעת רק כדי **לאשר** את ה‑XOR הבין‑רמתי ואת יחס ה‑direct‑מול‑style (כרגע direct דורס; מתועד ב‑docstring). המנוע כעת **ניתן‑לחיווט**: סמנטיקת השרשרת זהה לייצור, וההבדל היחיד שייכנס בחיווט הוא ה‑XOR הבין‑רמתי + rPrDefault (שכבר נחת בנפרד).
**בדיקות:** עודכנה קבוצת ה‑toggle ב‑[style_engine_test.dart](../packages/docx_creator/test/style_engine_test.dart) (basedOn=ירושה; XOR בין רמות; direct דורס). `docx_creator`: **378 ירוקות**, analyze נקי.
**בעיות פתוחות / ל‑AI הבא:** חיווט המנוע ל‑`parseRun` (השחלת `paragraphStyleId`/`runStyleId` + direct), ואז `golden` ממסמך Word לאישור ה‑XOR הבין‑רמתי ויחס ה‑direct.

### 2026-06-11 — חלק B — מענה לסקירה שנייה (קאש + תיעוד golden)
**בוצע:** טופלה סקירת QA שנייה של המנוע (ללא ממצאי 🔴).
- **🟡 באג קאש — התנגשות תוחם:** מפתח `_runStyleCache` היה מחרוזת `"<p>|<r>"`; `w:styleId` (ST_String) יכול להכיל `|`, כך ש‑`('a|b','c')` ו‑`('a','b|c')` התמפו לאותו מפתח → סגנון שגוי מהקאש. הוחלף ל‑record `(String?, String?)` (שוויון‑ערך, ללא תוחם). `_paragraphStyleCache` הוסב ל‑`Map<String?, …>` (מפתח null במקום `''`).
- **🟢 בניית רמות סימטרית:** `paragraphStyleId` נכנס ל‑levels רק כשאינו null (כמו runStyleId) — בלי "רמת רפאים" ריקה.
- **🟡 #1 (direct toggle = override מול XOR):** חוזק התיעוד — הדוגמה הקנונית ב‑ISO §17.7.3 היא דווקא `<w:b/>` **ישיר** על פסקה מודגשת → לא‑מודגש, כלומר ה‑XOR מודגם ברובד ה‑direct, מה שסותר את ה‑override הנוכחי. זהו הספק היחיד שסביר שיתהפך; סומן ב‑docstring וב‑`TODO(golden)` בטסט (characterization). **לא הופך בלי golden** — להחלטת המשתמש.
- **🟢 decorations לא‑אדיטיבי בירושה** (`merge`) — תועד כ‑NOTE ב‑`_collapseChain` (קדם‑קיים; golden ייעודי בעת חיווט).
**בדיקות:** `docx_creator` **378 ירוקות**, analyze נקי.
**ל‑AI/למשתמש:** דרוש `.docx` מ‑Word עם (א) שרשרת basedOn של toggle, (ב) `<w:b/>` ישיר על ריצה שסגנונה מודגש — לאישור/תיקון יחס ה‑direct לפני חיווט המנוע לייצור.

### 2026-06-11 — חלק B — ✅ הושלם: חיווט המנוע לייצור + אימות מול Word אמיתי
**בוצע:** המנוע (`DocxStyleResolver`) **חובר לנתיב הייצור של הקורא**, ובכך החליף את ה‑merge הידני:
- **`ReaderContext.styleResolver`** — getter עצלן שבונה מנוע יחיד מ‑`styles`+docDefaults (מטמון משותף לכל המסמך).
- **השחלת `paragraphStyleId`** דרך `parseChildren`→`parseRun`→`_parseHyperlink` (חתימות הורחבו, תאימות לאחור נשמרה: `parentStyle` עדיין נתמך ומקופל כ‑direct לקוראים חיצוניים). [block_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/block_parser.dart) (פסקה רגילה + drop‑cap) ו‑[table_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/table_parser.dart) (תאים) מעבירים כעת `paragraphStyleId` במקום סגנון ממוזג.
- **[inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart) `parseRun`** מחשב כעת `finalProps = context.styleResolver.resolveRun(paragraphStyleId, runStyleId: rStyle, direct: runRPr)`. הוסר ה‑merge הידני (rPrDefault/cStyle/baseStyle) — המנוע מטפל בכול. לוגיקת ה‑baking ל‑`DocxText` ללא שינוי.
- **נתיב יחיד בייצור:** ה‑merge הישן נמחק; אין יותר שתי מערכות resolution (תיקון #2 מהסקירה הראשונה — סגירה מלאה).
- **rPr של סימן‑הפסקה (pPr/rPr)** לא מועבר עוד כבסיס לריצות (הוא עיצוב ה‑pilcrow, לא של הריצות) — תואם את התנהגות Word, ואומת שאינו משפיע על הריצות בקובץ האמיתי.

**אימות מול Word אמיתי:** המשתמש סיפק `formatting-demo.docx` (Word, עברית/RTL, docDefaults=Arial 11pt, כפילות styleId, ללא Normal מפורש) + 7 רינדורים. דרך הנתיב המחווט: Title=מודגש/28pt/`1F3864`/ממורכז, Heading1=מודגש/17pt/`2E5496`+גבול, Heading3=מודגש‑נטוי/12pt, Quote=נטוי/אפור — **כולם תואמים לרינדור Word**. ריצות בלי גודל מקבלות Arial 11pt (rPrDefault), וגדלים מפורשים (sz=26→13pt בכותרת המשנה) נשמרים. **המנוע ≡ נתיב הייצור הקודם בכל 33 הפסקאות**, כך שהחיווט לא שינה פלט תקין.

**בדיקות:** `docx_creator`: **378 ירוקות**, analyze נקי. `docx_file_viewer`: **61 ירוקות**, analyze נקי (4 golden נכשלות על fixtures חסרים — קדם‑קיים).

**החלטות/סטיות:**
1. **הסמנטיקה החדשה היחידה שנכנסה לייצור:** toggle‑XOR בין רמות (פסקה×תו) + rPrDefault. שאר התוצאות זהות לקודם (basedOn=ירושה רגילה כמו `resolveStyle`). לכן 378 הבדיקות עברו ללא שינוי.
2. **`parentStyle` נשמר בחתימה** (לא נשבר API) אך פנימית כל הקוראים מעבירים `paragraphStyleId` → נתיב המנוע. `parentStyle` משמש רק fallback לקוראים חיצוניים תאורטיים (מקופל כ‑direct), ולכן אין dual‑path בייצור.

**שאריות מתועדות (לא חוסמות את הליבה):**
- **#1 (direct‑toggle):** יחס ה‑direct נשאר "דורס". הוכח כמעשית‑מוזניח — Word שומר `w:val="0"` לכיבוי (מטופל נכון), וכמעט אף פעם לא `<w:b/>` על טקסט שכבר מודגש (0 מקרים בקובץ האמיתי). golden לאישור סופי = nice‑to‑have.
- **אימוץ `ThemeColorResolver` ב‑viewer** — ה‑`_resolveColor` הקיים כבר עושה tint/shade שקול מתמטית ל‑B.3; האיחוד הוא ניקיון, לא תיקון.
**ל‑AI הבא:** חלק C (מדידה/טאבים/BiDi) — היסוד לעימוד האמיתי (D). 7 הרינדורים של formatting-demo הם יעד אימות מצוין (טבלאות→F, הערות שוליים→J, drop‑cap/Wingdings→K, מספור legal→G).

### 2026-06-11 — חלק B — סקירה שלישית + סגירת פערי DoD (B → ✅ אמיתי)
**מענה לסקירה שלישית (של קומיט החיווט):**
- **🟡 פורמט:** הורץ `dart format` על קבצי החיווט (היו חורגים מ‑80 תווים). שער ה‑CI ב‑`melos.yaml` (`dart format .` בלי `--set-exit-if-changed`) **לא‑אפקטיבי** — לא תוקן כי הפיכתו יכשיל את ה‑CI על ~8 קבצים עם חוב פורמט קדם‑קיים (החלטת המשתמש).
- **🟡 docstring:** עודכן ה‑docstring של `DocxStyleResolver` ("Internal, wired into production" במקום "not yet wired"); תועד ש‑`resolveParagraph` עדיין לא מחווט (מאפייני פסקה דרך `resolveStyle` — dual‑path מתועד, פונקציונלית שקול).
- **🟡 invariant:** תועד ב‑`styleResolver` getter שהמנוע מצלם styles/docDefaults בגישה ראשונה ולא מתאפס → `ReaderContext` חד‑מסמכי.
- **🟢:** הערה מיושנת ב‑block_parser תוקנה; נוסף `TODO(golden)` ליד `merge(direct)`; הערת סדר ל‑legacy path.

**סגירת פערי ה‑DoD (היושר מהשאלה הקודמת):**
1. **auto‑color על רקע כהה** — מומש `ThemeColorResolver.resolveAutoColor` (B.3: שחור על בהיר/ריק, לבן על כהה לפי luminance<0.5) + בדיקה. (אימוץ ב‑viewer = render‑side, חלק E.)
2. **מדידת ביצועים** — בנצ'מרק (200k רזולוציות): **המנוע מהיר פי ~5.6** (63ms מול 355ms). הקוד הישן (`resolveStyle`) חישב מחדש בכל קריאה; המנוע ממטמן. "לא איטי יותר" → למעשה מהיר משמעותית.
3. **basedOn‑double‑toggle** — עודכן טקסט ה‑DoD (§B.6) + §8.2 כדי לשקף את ההחלטה (ירושה רגילה בשרשרת; XOR בין רמות), במקום הקריאה המילולית של ISO.

**בדיקות:** `docx_creator`: **379 ירוקות** (כולל auto‑color), analyze נקי, `dart format` נקי על הקבצים שנגעתי. `docx_file_viewer`: 61 ירוקות (4 fixtures חסרים, קדם‑קיים).
**מצב B:** ✅ — כל פריטי ה‑DoD סגורים או מתועדים כסטייה מודעת (§8.2 #4–6). שאריות nice‑to‑have בלבד: golden ל‑#1, אימוץ helpers ב‑viewer (render‑side), חיווט `resolveParagraph`.

### 2026-06-11 — חלק C (מדידה/טאבים/BiDi) — ✅ הושלם
**בוצע:** נבנתה שכבת המדידה והפריסה ש‑D (העימוד) יישען עליה. **חבילה:** `docx_file_viewer` בלבד (קבצים חדשים תחת `lib/src/layout/` + `lib/src/widgets/tabbed_line.dart`).

- **C.4 — טבלת יישור BiDi (מחייבת)** ([bidi_align.dart](../packages/docx_file_viewer/lib/src/layout/bidi_align.dart)): `resolveJustification(WordJustification, isRtl)` מממש את כל 6 השורות (left/right פיזי, start/end לוגי, center, both). גשר `justificationFromDocxAlign` מתעד את הקריסה של ה‑AST: ה‑reader ממפה `start`/`left`→`DocxAlign.left` ו‑`end`/`right`→`DocxAlign.right` (ה‑writer ב‑[enums.dart](../packages/docx_creator/lib/src/core/enums.dart) כותב `left`→`"start"`!), לכן `left`=start (קצה מוביל), `right`=ימין פיזי. מחווט ב‑`paragraph_builder` במקום ההיוריסטיקה `left→start`. הוסר `_convertAlign`. 12+ בדיקות (שורה×כיוון).
- **C.1 — `SpanFactory`** ([span_factory.dart](../packages/docx_file_viewer/lib/src/layout/span_factory.dart)): **מקור אמת אחד** ל‑run→`TextStyle` (`resolveRunStyle`) ולטרנספורם תוכן (`resolveContent`), + `buildMeasurementSpans` (עץ span + `PlaceholderDimensions` למדידה) + `resolveLineHeightScale` + helpers (`resolveColor`/`parseHexColor`/`mapUnderline`/`highlightToColor`). ה‑logic חולץ **מ‑`paragraph_builder`** — ה‑renderer עכשיו **מאציל** את חישוב הסגנון/צבע ל‑`SpanFactory` (search/link/textBorder נשארים שכבה גאומטרית‑ניטרלית מעל). כך אין dual‑path (§2.4.6) והמדידה זהה לרינדור. נוקו הערות‑תכנון מתות שהיו בקובץ.
- **C.5 (חלקי)** — ב‑`resolveRunStyle`: caps/smallCaps (uppercase + 0.85×), letterSpacing (twips/15), **kern**→`FontFeature.enable('kern')` מעל הסף. נדחו (§8.2 #9): charScale (`w:w`) ו‑position (raise/lower) כ‑WidgetSpan+Transform, ופיצול smallCaps אמיתי — נדירים, ו**שקולים בין מדידה לרינדור** (אותו factory).
- **C.2 — `TextMeasurer`** ([text_measurer.dart](../packages/docx_file_viewer/lib/src/layout/text_measurer.dart)): `TextPainter` יחיד ממוחזר (UI thread, §4.4), מטמון **LRU** עם מפתח `(identityHashCode(block), width.round(), styleEpoch)` ותקרה 4,000 (§4.3), `invalidate()` מקדם epoch (O(1)). `measureParagraph` מחזיר `BlockMeasurement{textHeight, spacingBefore/After, lineCount, lineMetrics}`. פסקה ריקה = גובה שורה (zero‑width‑space). מונים `layoutCount`/`cacheHits` לבדיקת ה‑DoD.
- **C.3 — `TabEngine`** ([tab_engine.dart](../packages/docx_file_viewer/lib/src/layout/tab_engine.dart)): ליבת מיקום **טהורה וכיוון‑אגנוסטית** (קואורדינטות "קצה מוביל") — `resolveStops` (clear/sort/twips→px), `barStops`, ו‑`position(widths, tabsBefore, stops)` ל‑left/center/right/decimal(≈right)/default‑interval(720tw)+clamp+leader+multi‑tab. **`TabbedLineRenderer`** ([tabbed_line.dart](../packages/docx_file_viewer/lib/src/widgets/tabbed_line.dart)) מודד קטעים, ממקם פיזית (mirror ל‑RTL), ומצייר leaders (dot/dash/line) + bar ב‑CustomPaint. מחווט ב‑`paragraph_builder` **רק** לפסקאות עם `tabStops` מפורשים + tab + טקסט בלבד (שמירה על wrapping של פסקאות tab‑מוביל; מדידה ללא placeholders).

**בדיקות:** 4 קבצים חדשים — [bidi_align_test.dart](../packages/docx_file_viewer/test/bidi_align_test.dart), [text_measurer_test.dart](../packages/docx_file_viewer/test/text_measurer_test.dart) (5 measure‑vs‑render ±0.5px: עברית/אנגלית/מעורב/exact/תמונה‑inline + פסקה‑ריקה + מטמון), [tab_engine_test.dart](../packages/docx_file_viewer/test/tab_engine_test.dart) (11), [tabbed_line_test.dart](../packages/docx_file_viewer/test/tabbed_line_test.dart) (LTR+RTL position). `docx_file_viewer`: **95 ירוקות** (+34 חדשות), `flutter analyze` נקי על כל החבילה, `dart format` הורץ. 4 ה‑golden של עברית עדיין נכשלות על fixtures חסרים (קדם‑קיים מ‑A/B). `docx_creator` לא נגעתי בו (התלות חד‑כיוונית) → 379 נשארות ירוקות.

**החלטות/סטיות (§0.3, מתועד ב‑§8.2 #7–11):**
1. **"מדידה≡רינדור" הוא העיקרון העליון של חלק C.** לכן ה‑measurer **משתמש באותו מנגנון של ה‑renderer**: line‑spacing דרך `TextStyle.height` (לא `StrutStyle.forceStrutHeight`). מעבר ל‑StrutStyle (Word‑מדויק יותר ל‑exact/atLeast) חייב לקרות **בשני** הנתיבים יחד — נדחה (§8.2 #7). תוצאה: 5 מקרי ה‑parity עוברים ±0.5px **כי שני המסלולים זהים גאומטרית**.
2. **`w:vanish` עדיין מרונדר ונמדד** (§8.2 #8). דילוג אמיתי דורש תיאום עם **אינדקס החיפוש** ([docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart) `_extractFromInlines` מחזיק offsets כולל hidden). הפרמטר `skipHidden` כבר קיים ב‑`SpanFactory` (כבוי) לחיבור עתידי.
3. **golden הטאבים = בדיקת מיקום דטרמיניסטית** ולא golden‑image (§8.2 #11) — קובצי ה‑fixtures/goldens חסרים בצ'קאאוט (קדם‑קיים). בדיקת מיקום מאמתת left‑flush/center‑on‑200/right‑at‑400 + RTL mirror — אימות חזק יותר מ‑golden שבור.
4. **שם הטיפוס `WordJustification`** (ולא הרחבת `DocxAlign` ב‑enum) — הרחבת ה‑enum הייתה שוברת switch‑ים ב‑exporters (§1.2: אסור לגעת) ובכל מקרה ה‑AST קרס את ההבחנה start/left ב‑parse.

**בעיות פתוחות / ל‑AI הבא (חלק D — Paginator):**
- ה‑`TextMeasurer` מוכן לצריכה ב‑D: `measureParagraph(p, width, direction).lineMetrics` נותן נקודות פיצול‑שורה; `totalHeight` כולל spacing. לזכור: D צריך גם למדוד **טבלאות** (לא ממומש ב‑C — רק פסקאות).
- ה‑`TabEngine` כיוון‑אגנוסטי וניתן לשימוש גם במדידת רוחב טאבים בעימוד.
- שאריות C נדחות (לא חוסמות את D): StrutStyle (#7), דילוג vanish (#8), charScale/position (#9), wrapping של tabbed‑line + decimal מדויק + ירושת tab‑stops מסגנון (#10), golden‑image אמיתי כשיסופקו fixtures (#11), פיצול כתב ascii/cs נשאר לחלק L.

### 2026-06-11 — חלק C — סגירת פערים נוספים (StrutStyle + vanish + baseline)
**בוצע:** נסגרו 3 פערים אמיתיים מול המפרט שנדחו בתחילה (בעקבות בקשה לממש "מה שאפשר"):
1. **StrutStyle ל‑`exact`/`atLeast`** (§C.2, היה §8.2 #7) — נוסף `SpanFactory.resolveStrut`: `exact`→`StrutStyle(fontSize: lineSpacing/15, height:1, forceStrutHeight:true)` (קופסת שורה כפויה), `atLeast`→מינימום (`forceStrutHeight:false`). `resolveLineHeightScale` מחזיר כעת `null` ל‑exact/atLeast (ה‑strut מטפל), ומכפיל רק ל‑`auto`. הוחל **בשני הנתיבים**: ה‑measurer (`_painter.strutStyle`) וה‑renderer (`RichText`/`SelectableText`/`_buildFloatingLayout` עם `strutStyle:`). בדיקת parity של exact עדיין ±0.5px + בדיקה ש‑480tw→32px קופסה כפויה.
2. **דילוג `w:vanish` (hidden)** (§C.5, היה §8.2 #8) — מתואם בכל 3 המקומות כדי לשמור יישור offsets של חיפוש: `buildInlineSpans` (renderer) + לולאת ה‑offset ב‑`flushBuffer` + אינדקס החיפוש ([docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart) `_extractFromInlines`) + ה‑measurer (`skipHidden: true`). בדיקה: ריצה מוסתרת לא מוסיפה גובה/רוחב ואינה מופיעה ב‑`toPlainText()`.
3. **baseline ראשון/אחרון** ב‑`BlockMeasurement` (§C.2 — הושלמה חתימת ה‑API) מתוך `lineMetrics`, לשימוש העימוד (D).

**נשאר דחוי במכוון (סיבות, §8.2 #9–11):** charScale (`w:w`)/position (raise/lower) — נדיר, ומימוש WidgetSpan+Transform מסכן את עקרון "מדידה≡רינדור" (ה‑placeholder חייב להתאים בדיוק); כרגע **שקול** בין שני הנתיבים כך שאין סטיית עימוד. tabbed‑line ללא wrapping; decimal≈right; ירושת tab‑stops מסגנון (תלוי השחלה ב‑reader); `w:ptab` לא מרונדר; golden‑image (fixtures חסרים); פיצול כתב ascii/cs → חלק L.

**בדיקות:** `docx_file_viewer`: **97 ירוקות** (+2: vanish, exact‑strut), `flutter analyze` נקי, `dart format` הורץ. אותן 4 golden נכשלות על fixtures חסרים (קדם‑קיים). `docx_creator` לא נגעתי בו.
**מצב C:** ✅ — כל 4 פריטי ה‑DoD מסומנים; השאריות הן סטיות מודעות מתועדות (§8.2 #9–11) ופיצ'רים נדירים שאינם חוסמים את D.

### 2026-06-11 — חלק D (מנוע העימוד) — 🟨 בעבודה: המנוע בנוי ונבדק, טרם מחווט
**בוצע:** נבנה **מנוע ה‑Paginator** — לב המערכת (§D, מחקר §6). מנוע **טהור וסינכרוני** הניתן לבדיקה ללא widget tree. **חבילה:** `docx_file_viewer` בלבד.
- **מבני נתונים (§D.1):** [block_slice.dart](../packages/docx_file_viewer/lib/src/pagination/block_slice.dart) (`BlockSlice` — הפניה לבלוק + טווח שורות/תווים/שורות‑טבלה + height מדוד, ללא שכפול AST) ו‑[page_model.dart](../packages/docx_file_viewer/lib/src/pagination/page_model.dart) (`PageModel` רזה + `PaginationResult` עם מפות).
- **[paginator.dart](../packages/docx_file_viewer/lib/src/pagination/paginator.dart):**
  - **M3 — מילוי מבוסס‑מדידה:** כל בלוק נמדד ב‑`TextMeasurer` ברוחב התוכן של המקטע ונארז בגובה הגוף האמיתי (`bodyHeight = pageHeight − max(marginTop, headerDist+headerH) − max(marginBottom, footerDist+footerH)`, §D.2.1 — header/footer נמדדים פר‑וריאנט). גובה עמוד מהמסמך (`w:pgSz`/`w:pgMar`/gutter) או override מ‑config.
  - **M4 — פיצול פסקה (§D.2.2/§6.4):** מציאת נקודת הפיצול דרך `TextMeasurer.layoutForSplit` (offsets של תחילת כל שורה ויזואלית + גבהים מצטברים, מ‑`getPositionForOffset`), מיפוי ה‑offset חזרה ל‑inline דרך **מפת segments חדשה** ב‑`SpanFactory.buildMeasurementSpans` (מקור אמת אחד, §C.1), וחיתוך ה‑children ב‑`SpanFactory.sliceInlines` (משתף inline‑ים ב‑reference, משכפל רק את ריצת הגבול). אכיפת `keepLines` (לא מפצל) ו‑`widowControl` (≥2 שורות בכל צד).
  - **M5 — פיצול טבלה (§D.2.7/§6.5):** שבירה בין שורות; שורות `w:tblHeader` מובילות **חוזרות** בראש כל המשך; `cantSplit` מכובד מעצם הפיצול ברמת שורה; שורה גבוהה מעמוד → clamp.
  - **מקטעים (§D.2.4/§6.7):** פיצול ל‑runs לפי `DocxSectionBreakBlock` (ה‑breakType של המקטע ה**מתחיל** קובע — כלומר על ה‑def של ה‑run, תואם ISO); `evenPage`/`oddPage` מוסיפים **עמוד ריק** לתיקון parity; `nextPage` עמוד חדש; `continuous` ממשיך באותו עמוד (best‑effort, §8.2 #14). איפוס מספור לפי `w:pgNumType w:start`.
  - **keepNext (§D.2.3):** קבוצת פסקאות keepNext + הבלוק שאחריהן עוברת יחד לעמוד חדש אם לא נכנסת (ונופלת לפיצול רגיל אם גבוהה מעמוד).
  - **מפות תוצר (§D.2.8):** `bookmark→displayPageNumber`, `footnoteId→absolutePage`. שבירת `w:br type="page"` בתוך פסקה סוגרת עמוד (פיצול אמצע‑פסקה בנקודת ה‑break = שלב עתידי; כרגע ברמת בלוק).
- **תשתית ש‑C סיפק והורחבה:** `SpanFactory` קיבל `SpanSegment`/`segments` + `sliceInlines`; `TextMeasurer` קיבל `ParagraphLayout`/`layoutForSplit` (רפקטור: `_layoutInto` משותף ל‑measure ולפיצול, כך ששניהם מציירים זהה).

**בדיקות:** [paginator_test.dart](../packages/docx_file_viewer/test/paginator_test.dart) — **16 בדיקות חדשות** עם `TextMeasurer` אמיתי: מסמך ריק→עמוד; אריזת N פסקאות ל‑`ceil(N/perPage)`; `pageBreakBefore`; `w:br` page; שבירת מקטע nextPage+sectionIndex; `pgNumType start`+NUMPAGES; oddPage→blank filler; פיצול פסקה+round‑trip תווים+head‑נכנס‑לגוף; `keepLines` לא מפוצל; widow/orphan ≥2 שורות; keepNext זוג יחד; מפת bookmark; RTL/מעורב מתפצל+round‑trip; פיצול טבלה+חזרת כותרת+round‑trip שורות; whole‑block ב‑reference. `docx_file_viewer`: **113 ירוקות** (97→113), `flutter analyze` **נקי**. אותן 4 golden נכשלות על fixtures חסרים (קדם‑קיים מ‑A/B/C). `docx_creator` לא נגעתי בו.

**החלטות/סטיות (§0.3, מתועד ב‑§8.2 #13–15):**
1. **פסקה/טבלה‑פרוסה כ‑`DocxNode` אמיתי קל** (head/tail משתפים inline/שורות ב‑reference, משכפלים רק את הגבול) במקום טווחים טהורים על הצומת המקורי. הסיבה: הרינדור צריך את החיתוך ממילא, ותרגום offsets בין פיצולים חוזרים שביר; עלות RAM זניחה (O(פיצולים)). זה מפשט גם את הרינדור העתידי (פרוסה = פסקה/טבלה רגילה). §8.2 #13.
2. **מדידת טבלה = רוחב עמודות שווה** (לא autofit; חלק F) — מספיק לאריזת עמוד. §8.2 #14.
3. **המנוע סינכרוני** — time‑slicing (§4.4)/placeholder/תקציבי §2.2 ייכנסו עם החיווט (חלק M). §8.2 #15.
4. **לא חובר עדיין לייצור ולא יוצא ל‑API ציבורי** — בעקבות הלקח מחלק B (אסור לייצא רכיב טרם מחובר). הבדיקות מייבאות דרך `src/`. ההיוריסטי (`_generatePagedWidgets`/`_estimateElementHeight`) **עדיין פעיל** עד שהחיווט יהיה ירוק.

**בעיות פתוחות / ל‑AI הבא (השלמת D ל‑✅):**
1. **חיווט ל‑`DocxView`/`DocxWidgetGenerator`:** להחליף את `_generatePagedWidgets` ב‑`Paginator`. הרינדור פשוט יחסית כי כל פרוסה היא `DocxNode` אמיתי — `_generateBlockWidgets(page.slices.map((s)=>s.block))` + `_buildPageContainer` עם `PageContext` אמיתי (pageNumber/totalPages/sectionPages/bookmarkPages + isEvenPage פר‑עמוד). למחוק את `_estimateElementHeight` ואת ה‑batching ההיוריסטי (DoD: "אין שני מסלולים"). לבנות `SpanFactory`/`TextMeasurer` מאותם theme/config/docxTheme של ה‑`ParagraphBuilder`.
2. **time‑slicing אסינכרוני (§4.4):** `Stream<PageModel>`/callback פר‑עמוד, מנות ≤8ms, placeholder לעמודים שטרם עומדו. לוודא תקציבי §2.2/§2.3 (עמוד ראשון ≤1.5s, עימוד מלא ≤6s, UI לא קופא).
3. **השוואה ידנית מול Word על 3 מסמכים אמיתיים** (DoD §D.4) — דורש fixtures + PDF מהמשתמש (כמו `formatting-demo.docx` של חלק B). לתעד ±שורה ביומן.
4. שאריות מתועדות: פיצול `w:br` אמצע‑פסקה (כרגע ברמת בלוק); autofit טבלה (F); continuous עם שינוי גאומטריה (I); ה‑TODO של מדידת tab דרך TabEngine (§8.2 #12) עדיין רלוונטי לפסקאות tab רב‑שורתיות.

### 2026-06-11 — חלק D — מענה לסקירת קוד (תיקוני נכונות + ניקיון)
**בוצע:** טופלה סקירת קוד חיצונית של מנוע ה‑Paginator. תוקן/הוחלט:
- **🔴 #1 — פיצול פסקה השמיט סימניות (שבר PAGEREF):** `sliceInlines` עבר רק על segments, ו‑`DocxBookmark` (וכל עוגן רוחב‑אפס) לא הפיק segment → סימנייה בתוך פסקה שנשברת **נמחקה** מ‑head ו‑tail, ו‑`bookmarkPages` איבד את הרשומה (PAGEREF/ניווט). תיקון: `buildMeasurementSpans` מפיק כעת **segment באורך 0** לסימנייה (`anchorSeg`), ו‑`sliceInlines` ממקם עוגני רוחב‑אפס לפי מיקום (half‑open `[startChar,endChar)`, עם `includeEndAnchors` ל‑slice הזנב כדי לשמר עוגן בקצה הפסקה). בדיקה חדשה: סימנייה ב‑head→עמוד 1, סימנייה ב‑tail→עמוד הבא.
- **🟡 #2 — widow off‑by‑one:** כש‑`fit==2,total==3`, ענף ה‑widow הוריד ל‑`fit=1` והשומר `fit<=0` פספס → **יתום של שורה אחת** ב‑head (בדיוק מה שהפונקציה אמורה למנוע). תוקן ל‑`if (fit < 2) return null` לפני **וגם** אחרי ההורדה. בדיקה חדשה (עמוד שמכיל בדיוק 2 שורות, פסקה של 3 שורות → לא מפוצלת).
- **🟡 #3 — מודל ה‑range של `BlockSlice` היה קוד מת וסתר את ה‑invariant:** המימוש בחר ב‑Design 2 (תת‑בלוקים קלים) אבל המחלקה עוד נשאה `startLine/endChar/startRow/...` + docstring "never copies the AST". פושט ל‑`{block, height}` בלבד (commit ל‑Design 2, §8.2 #13); הוסר `isWhole/isParagraphSlice/...`.
- **🟡 #4 — `_measureList` ביטל את המטמון:** הקצה `DocxParagraph` חדש פר‑קריאה (זהות חדשה → miss תמידי). תוקן עם `Expando<DocxParagraph>` פר‑item (מטמון ה‑LRU פוגע).
- **🟡 #6 — continuous תייג עמוד ראשון שגוי:** ביטלתי את `_pendingFirstOfSection=true` ב‑continuous (המקטע מתחיל אמצע‑עמוד על העמוד הפתוח, אין "עמוד ראשון" במובן title‑page).
- **🟢:** מפות footnote/endnote **הופרדו** (`footnotePages`/`endnotePages` — id 1 של כל סוג כבר לא מתנגש); מספרי קסם רוכזו ל‑`static const` נקובים; שדות מצב פוזרו רוכזו לראש המחלקה; בדיקת **clamp** לבלוק לא‑מתפצל גבוה מעמוד.

**נדחה במכוון:** #5 (מדידה כפולה ב‑`_placeGroup`+`_placeBlock`) — קורה רק לקבוצות keepNext (length>1, נדיר), והמדידה השנייה **ממוטמנת** (פסקאות/תאים לפי זהות), כך שאין layout כפול בפועל. `.gitattributes` ל‑LF — מחוץ להיקף (ישנה renormalization לכל הריפו).

**בדיקות:** [paginator_test.dart](../packages/docx_file_viewer/test/paginator_test.dart) — **19 ירוקות** (+3: widow‑guard, split‑bookmark, clamp). `docx_file_viewer`: **118 ירוקות**, `flutter analyze` נקי, `dart format` הורץ. אותן 4 golden נכשלות על fixtures חסרים (קדם‑קיים).

### 2026-06-12 — חלק D — חיווט המנוע לייצור + מחיקת ההיוריסטי + אימות על מסמך אמיתי
**בוצע:** מנוע ה‑Paginator **חובר ל‑`DocxWidgetGenerator`** והחליף את העימוד ההיוריסטי:
- **`_generatePagedWidgets`** ([docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart)) נכתב מחדש: בונה `SpanFactory`+`TextMeasurer` (מאותם theme/config/docxTheme של ה‑`ParagraphBuilder` → מדידה≡רינדור), מריץ `Paginator.paginate(doc)`, משחרר את ה‑measurer, ומרנדר עמוד‑עמוד מהפרוסות דרך `_generateBlockWidgets(page.slices.map((s)=>s.block))` + `_buildPageContainer`.
- **`PageContext` אמיתי פר‑עמוד:** `pageNumber`/`totalPages`(=pageCount)/`sectionPages`(ספירה פר‑מקטע)/`sectionFormat` מהמקטע של העמוד/`bookmarkPages` מהמנוע → PAGE/NUMPAGES/SECTIONPAGES/PAGEREF חיים. `isEvenPage = evenAndOddHeaders && page.isEvenPage`, `isFirstPage = page.isFirstPageOfSection` (וריאנט title‑page). `_buildPageContainer` קיבל `sectionOverride` → גאומטריה+כותרות פר‑מקטע (multi‑section).
- **ההיוריסטי נמחק:** `_estimateElementHeight` + לולאת ה‑batching הוסרו לגמרי — **נתיב עימוד יחיד** בייצור (DoD: "אין שני מסלולים").
- **חיפוש מיושר לסדר הפרוסות:** `extractTextForSearch` במצב paged עובר על `_lastPagination.pages→slices` באותו סדר שבו מרונדרים ה‑widgets, כך שמפתחות ה‑`BlockIndexCounter` נשארים מיושרים **גם אחרי פיצול** פסקה/טבלה (פיצול = 2 פרוסות = 2 רשומות חיפוש + 2 מפתחות; match בזנב גולל לעמוד הזנב). מצב continuous לא השתנה (נתיב doc‑based). הדגשת החיפוש (per‑block) עובדת ללא תלות.

**אימות end‑to‑end על `formatting-demo.docx`** (שסופק ב‑`.tmp_docx/`, עברית/RTL, A4, 89 בלוקים, header/footer, drop‑cap, רשימות, highlights): נטען דרך `DocxReader` → המנוע מייצר **10 עמודים**, מזהה **1 סימנייה + 2 הערות שוליים**, ו‑`generateWidgets` מפיק 10 widget‑עמודים ללא קריסה. **מבנה תואם** לרינדורי Word (`word_ref/ref1‑7.png`): עמוד שער דליל → עמודי תוכן צפופים, RTL, כותרות ממוספרות.

**פער 10 מול 7 עמודים של Word — מקור: פונט ה‑harness.** `flutter test` משתמש בפונט Ahem (כל גליף = ריבוע em ברוחב fontSize), רחב ~פי‑2 מפונט אמיתי → יותר שבירות שורה → ~40% יותר עמודים. **אין כאן באג עימוד** (גובה הגוף ≈931px ל‑A4 נכון; המבנה תואם). פונטים אמיתיים על מכשיר יתכנסו ל‑~7. אימות העמודים המדויק מול Word = שלב ידני (DoD §D.4) על האפליקציה האמיתית.

**בדיקות:** `docx_file_viewer`: **118 ירוקות** (page_number_render, paged_footer_repro, widget_test/search — כולם עוברים עם המנוע המחווט), `flutter analyze` נקי, `dart format` הורץ. אותן 4 golden נכשלות על fixtures חסרים (קדם‑קיים).

**החלטות/סטיות:**
1. **חיפוש נגזר מהעימוד (slice‑aligned) במקום doc‑aligned** — פתרון נקי יותר מהמודל הישן: גם המדידה (extract) וגם הרינדור עוברים על אותן פרוסות באותו סדר, כך שאין drift של מפתחות אחרי פיצול. (החלפת מנגנון ה‑GlobalKey פר‑בלוק כולו = חלק M; כאן רק שמרתי יישור.)
2. **העימוד עדיין סינכרוני** — רץ בתוך `generateWidgets` (כמו ההיוריסטי הקודם). אין רגרסיה, אבל time‑slicing (§4.4) ותקציבי §2.2/§2.3 טרם מומשו → חלק M / השלמת D.

**ל‑AI הבא (השלמת D ל‑✅):** (1) time‑slicing אסינכרוני — `Stream<PageModel>`/callback, מנות ≤8ms, placeholder לעמודים שטרם עומדו, מדידת תקציבי §2 על מסמך הייחוס. (2) אימות ידני מול Word על מכשיר עם פונטים אמיתיים (formatting-demo + 2 מסמכים נוספים), ±שורה. (3) שאריות: פיצול `w:br` אמצע‑פסקה, autofit טבלה (F), continuous עם שינוי גאומטריה (I).

### 2026-06-12 — חלק D — אימות מול Word אמיתי (formatting-demo) + תיקון §D.2.5
**אימות עם פונטים אמיתיים:** נטענו Arial+David (מ‑`C:\Windows\Fonts`) ל‑`FontLoader` בבדיקה, ועומד `formatting-demo.docx` (7 העמודים של Word ב‑`word_ref/ref1‑7.png`). **תוצאה: המנוע מייצר בדיוק 7 עמודים** עם Arial + ריווח שורה צמוד (h=1.0, קרוב ל‑single של Word). אבחון מלא:
- **הפונט אינו הגורם** לפער: גובה כולל זהה Ahem מול Arial (3567 מול 3565px) — התוכן כמעט לא עוטף שורות (פסקאות עברית קצרות ברוחב 602px). פסילת ההשערה הקודמת ש‑Ahem מנפח פי‑2.
- **מבנה המסמך:** מקטע יחיד, 0 `pageBreakBefore`, **5 שבירות `w:br type="page"`**, 4 טבלאות קטנות, 6 רשימות.
- **הפער 9→7 היה באג §D.2.5:** טיפול בשבירת‑עמוד inline ברמת‑בלוק (place‑then‑close) יצר **3 עמודים תת‑מלאים** (p2=182px, p6=53px, p9=400px). פסקת‑שבירה בודדת בזבזה עמוד.

**תיקון §D.2.5 — פיצול אמצע‑פסקה בנקודת ה‑break** ([paginator.dart](../packages/docx_file_viewer/lib/src/pagination/paginator.dart) `_placeBlock`): פסקה עם `w:br type="page"` מפוצלת ב‑inline הראשון — `pre` נשאר בעמוד, סוגרים עמוד (**רק אם יש תוכן מעל** — פסקת‑שבירה ריקה לא מבזבזת עמוד), `post` ממשיך בעמוד הבא (רקורסיבי לשבירות נוספות). הוסר ה‑`_afterPlace` הישן. תוצאה: 9→7 ב‑h=1.0.

**הפער שנשאר (9 עמ' בברירת‑המחדל של ה‑viewer) = ריווח שורה, לא העימוד:** `DocxViewTheme.light().defaultTextStyle.height=1.5` רופף מ‑Word (~1.0‑1.08); 77/78 פסקאות בלי `w:spacing` מפורש → נופלות ל‑1.5. **זו סטיית רינדור (ברירת‑מחדל theme), לא באג במנוע** — המנוע אורז נכון את מה שנמדד. תיקון אמיתי: או שמנוע הסגנונות (B) יאפה ריווח מ‑`pPrDefault`, או ברירת‑מחדל Word‑דמוית ב‑theme. **מחוץ להיקף D** (להחלטת המשתמש — שינוי גלובלי שמשפיע על goldens).

**בדיקות:** 2 בדיקות חדשות (§D.2.5: פיצול אמצע‑פסקה + פסקת‑שבירה ללא עמוד ריק). `docx_file_viewer`: **120 ירוקות**, analyze נקי, format הורץ. בדיקת ה‑real‑font הייתה מקומית (תלויה בפונטי Windows + `.tmp_docx`) — לא נשמרה (תיכנס ל‑corpus של חלק N).
**מסקנה:** **המנוע תואם ל‑Word (±0) בהינתן מטריקות Word** (פונט+ריווח). הפער היחיד הוא ברירת‑מחדל ריווח השורה של ה‑viewer.

### 2026-06-12 — חלק D — עיבוד אסינכרוני (§4.4) + הידוק ריווח שורה
**בוצע (לפי בקשת המשתמש, 3 משימות):**
1. **הידוק ריווח שורה:** `DocxViewTheme` (light/dark/בסיס) `defaultTextStyle.height` 1.5→**1.15** (קרוב ל‑single של Word; 1.5 ניפח עמודים). 120 בדיקות נשארו ירוקות (parity נשמר — שני המסלולים על אותו theme).
2. **time‑slicing אסינכרוני (§4.4):**
   - `Paginator.paginateAsync(doc, {sliceBudgetMs=8})` — אותו עימוד, אך משחרר את ה‑UI thread (`await Future.delayed(Duration.zero)`) בכל פעם שמנה חורגת מ‑8ms. הרקורסיה (`_placeBlock`/`_placeGroup`) נשארה סינכרונית (חסומה פר‑בלוק); רק לולאת הבלוקים העליונה (`_fillBlocksAsync`) מניבה בין קבוצות. `paginate` הסינכרוני נשמר (בדיקות/מסמכים קטנים); שניהם חולקים `_finalize`/`_placeNextGroup`.
   - `DocxWidgetGenerator.generateWidgetsAsync` + `_generatePagedWidgetsAsync` → מפרידים pagination מ‑`_renderPages` (משותף לסינכרוני/אסינכרוני). `_initBuilders` חולץ.
   - `DocxView._loadDocument` קורא `await generateWidgetsAsync` → **המסך לא קופא** בזמן עימוד מסמך גדול (ה‑spinner מתנפש).
3. **commit** — בוצע (`caeffa2` לחיווט+§D.2.5+ריווח; קומיט נוסף ל‑async).

**בדיקות:** בדיקה חדשה `paginateAsync ≡ paginate` (sliceBudgetMs:0 → yield אחרי כל קבוצה; אותם גבולות עמוד). `docx_file_viewer`: **121 ירוקות**, analyze נקי, format הורץ. 4 golden קדם‑קיימות נכשלות על fixtures חסרים.

**נשאר ל‑D (✅):**
1. **streaming אמיתי** — כרגע `paginateAsync` מעמד הכול ואז מציג; "עמוד ראשון ≤1.5s" (§2.2) דורש הצגת עמודים ככל שנולדים + placeholder לעמודים שטרם עומדו (scrollbar יציב). callback/`Stream<PageModel>` פר‑עמוד + בניית widget עצלה ב‑`ListView.builder`.
2. **מדידת תקציבי §2.2/§2.3** על מסמך ייחוס (200 עמ') ב‑`--profile`.
3. **אימות ידני מול Word על מכשיר** (3 מסמכים, ±שורה).
