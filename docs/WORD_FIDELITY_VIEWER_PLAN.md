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

- [x] בדיקות unit לאלגוריתם הרוחב (fixed/autofit/pct) — 16 בדיקות ב‑[table_layout_test.dart](../packages/docx_file_viewer/test/table_layout_test.dart), מושוות לערכים שמומרים מ‑twips (1px=15tw). כולל pct/dxa/tblInd/רצפת‑min.
- [ ] golden: טבלה עם merge אנכי+אופקי; banding מסגנון; bidiVisual עברית; גבולות מתנגשים (double מול single); שורת כותרת חוזרת אחרי שבירת עמוד (עם חלק D). — **חסום על fixtures חסרים** (קדם‑קיים בכל החלקים). קונפליקט "חזק‑מנצח" עצמו נדחה (§8.2 #22).
- [ ] ביצועים: טבלה 500 שורות — נמדדת ומרונדרת בלי לחרוג מתקציב פריים — **דורש מכשיר/profile** (וירטואליזציה דרך פיצול עמודים של D עוזרת ממילא).

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
| עימוד | מבוסס מדידה + פיצול פסקה/טבלה | 🟨 מנוע `Paginator` **מחווט לייצור** (ההיוריסטי נמחק — נתיב יחיד). M3 מילוי, M4 פיצול פסקה+widow/orphan, M5 פיצול טבלה+חזרת כותרת, מקטעים+evenPage blank, keepNext/keepLines, מפות bookmark/footnote, async time‑slicing + **streaming display + placeholder (§D.2.9/§D.3/§4.4)**. נשאר: אימות תקציבי §2 + Word על מכשיר | D |
| עמוד | גודל/שוליים/gutter מהמסמך | ✅ קיים | — |
| עמוד | header/footer וריאנטים + שדות PAGE/NUMPAGES חיים | ✅ `PageContext` אמיתי פר‑עמוד (D) + קליפת עמוד (E); first/even/default + titlePg | D,E |
| עמוד | vAlign/גבולות עמוד/סימן מים/רקע | 🟨 **vAlign+pgBorders+רקע מקטע מרונדרים (E)**; גובה עמוד קבוע; סימן מים (תלוי H) ומספור שורות נדחו | A,E |
| טבלה | borders/shading/merge/nested | ✅ קיים בסיסי | — |
| טבלה | autofit אמיתי/קונפליקט גבולות/bidiVisual/cellMar/cantSplit | ✅ **רוחבי‑עמודות (autofit/fixed/pct/dxa/tblInd) מחווט למדידה+רינדור; bidiVisual/tcMar/tblCellMar/textDirection/gridBefore/trHeight exact‑atLeast + גבולות בטוחי‑RTL + ירושת גבולות‑מסגנון (Table Grid) + דיכוי קו‑מיזוג + מילוי‑placeholder במיזוג (F); cantSplit+חזרת כותרת (D)**. נשאר: קונפליקט גבולות "חזק‑מנצח"+de‑dup (§8.2 #22), מיזוג‑תוכן rowspan, הצללת conditional כרקע, טבלאות צפות (→H), golden | A,D,F |
| רשימות | מספור בסיסי+roman/alpha | ✅ קיים | — |
| רשימות | resolver גלובלי/startOverride/isLgl/גימטריה/numPicBullet | ✅ `NumberingResolver` גלובלי (מעבר אחד בסדר מסמך, counters פר‑(numId,ilvl), המשכיות חוצת‑בלוקים/תאים, story עצמאי לכותרת/תחתית/הערות); restart+lvlRestart; compound %1.%2.%3; isLgl; suff/lvlJc; פורמטים hebrew1(גימטריה)/hebrew2/decimalZero/ordinal/none; numPicBullet (קיים). cardinalText/ordinalText→decimal (§8.2 #24) | G |
| ציורים | תמונות inline/floating בסיסי/behindDoc | ✅ קיים בסיסי | — |
| ציורים | wrap אמיתי/מיקום מוחלט/תיבות טקסט/rotation/crop/VML | 🟨 **H.1 מודל מלא** (rotation/flipH/V/crop/z-order/anchor-צורות — נקראים+round-trip); **H.3 תמונות:** rotation/flip/crop + `cacheWidth/Height`; **H.2 חיווט מלא:** `float_layout` (FloatRect+פותר-רצועות) מחווט ל‑Paginator (floats פר‑עמוד, `PageModel.floats`; topAndBottom שומר גובה; floats לא נמדדים inline) ול‑renderer (שכבת `Positioned` z-order ל‑topAndBottom+front, behindText=רקע, side=Row-legacy). **נשאר:** עטיפת side אמיתית (band reflow), תיבות-טקסט (re-entry), VML watermark, presets+gradient, מחיקת Row-legacy, golden | H |
| טורים | w:cols | 🟨 `w:cols` נקרא ל‑AST (A); פריסה ב‑I | A,I |
| הערות | שוליים/סיום על העמוד | ⬜ (Dialog כיום) | J |
| שדות | PAGE/NUMPAGES/SECTIONPAGES/PAGEREF | ✅ פענוח+החלפה; פורמטים decimal/roman/letter + **hebrew1/hebrew2** (E) | —,E |
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
| 14 | ~~מדידת טבלה = רוחב עמודות שווה~~ → **נסגר בחלק F:** מדידת הטבלה עוברת כעת דרך `resolveTableColumnWidths` (רוחבים אמיתיים פר‑עמודה, זהים לרינדור). נשאר רק החלק השני: שבירת מקטע `continuous` ממשיכה באותו עמוד עם הגאומטריה הקודמת (שינוי טורים = חלק I) | autofit מומש ב‑F; continuous עם שינוי גאומטריה = חלק I | D/F/I | נמוכה |
| 15 | ה‑`Paginator` נשאר טהור+סינכרוני לבדיקות, אך **time‑slicing אסינכרוני (§4.4), streaming display של עמודים נולדים + placeholder בגובה‑עמוד (§D.2.9/§D.3), ובנייה עצלה פר‑עמוד (`buildPageWidget` ב‑`ListView.builder`) — מומשו ✅**. נשאר: מדידת תקציבי §2.2/§2.3 על מסמך ייחוס (profile) + אימות ידני מול Word — דורשים מכשיר/fixtures (לא בר‑מדידה ב‑test harness) | D/M | נמוכה |
| 16 | בזמן streaming, `NUMPAGES`/`SECTIONPAGES`/`PAGEREF` בכותרת/תחתית מציגים ערך **זמני** (סך העמודים/הסימניות שנולדו עד כה) ומתייצבים לערך הסופי ברגע שהעימוד מסתיים — כמו ספירת העמודים החיה של Word. `PAGE` (העמוד הנוכחי) נכון מיד. אין באג עימוד — רק הצגת שדה שמתעדכנת | D | נמוכה |
| 17 | גבולות עמוד: סגנונות `dashed`/`dotted`/`triple` מצוירים כקו `single` רגיל; `w:zOrder="back"` מצויר בחזית (front); גבול בצבע theme נופל לצבע ברירת מחדל | מימוש dash/triple ב‑CustomPaint + theme‑color resolution לקליפה = עלות גבוהה לפיצ'ר נדיר; single/double/thick (הנפוצים, כולל ה‑DoD) מלאים | E | נמוכה |
| 18 | יישור אנכי דרך `PageBody` (RenderObject ייעודי): גובה טבעי → יישור → clip, **ללא overflow‑assert בשום מצב** (כולל `both` — justify רק כשנכנס, אחרת clip). **telltale ב‑debug** (`debugPrint`) מזהיר כשהגוף חורג מהאזור (מדידה≠פריסה) — קריטי למסמכי קודש, אחרת חיתוך טקסט **שקט** תחת גובה‑עמוד קבוע | מענה לסקירה; release חותך, debug מזהיר+נבדק | E | נמוכה |
| 19 | קליפת העמוד נשארה ב‑`_buildPageContainer` (לא פוצלה ל‑`page_widget.dart` כב‑§E.1.1); סימן מים (§E.1.5, תלוי רינדור צורות H) ומספור שורות (§E.1.6) נדחו | פיצול הקובץ = ארגוני בלבד (אותה התנהגות); סימן מים "יוצא בחינם" כשצורות ה‑header ירונדרו ב‑H; מספור שורות = עדיפות נמוכה מפורשת | E/H | נמוכה |
| 20 | `hebrew2` מעבר ל‑22 אותיות = רצף בייקטיבי בסיס‑22 (23→אא), כמו `\* ALPHABETIC` הלטיני. **לא אומת מול Word** (שבו ALPHABETIC חוזר AA/BB/CC) — לנעול golden ממסמך hebrew2 >22 עמ' לפני הסתמכות. `hebrew1` (גימטריה) ≥1000 → ספרות (אין geresh). 1..22 ו‑1..999 מדויקים | אין מסמך ייחוס לקצוות; הנפוצים מדויקים | E | נמוכה |
| 21 | autofit מכבד את ה‑`tblGrid` של Word (הרוחבים שהוא כבר אפה) ומכווץ פרופורציונלית רק כשחורג מרוחב העמוד. autofit מבוסס‑תוכן אמיתי (מדידת המילה הארוכה פר‑תא ורצפת‑min) **נתמך במנוע** (`minColumnWidths`, נבדק ביחידה) אך **לא מחושב בייצור** — ה‑Paginator סומך על ה‑grid | Word אופה את ה‑grid כמעט בכל קובץ אמיתי, וה‑grid הוא ה‑fit הנכון; מדידת intrinsic פר‑תא לכל טבלה יקרה (תקציב פריים, טבלה 500 שורות). ה‑grid = הערכים שמודדים מול Word | F | נמוכה |
| 22 | פתרון קונפליקט גבולות ("חזק מנצח") + de‑dup (בעלים‑יחיד) **נדחו**. ניסיון ראשון של de‑dup לפי left/right פיזי **שבר טבלאות RTL** (העמודה הראשונה ב‑grid יושבת חזותית מימין, כך ש"צייר right רק בעמודה האחרונה" איבד את הגבול החיצוני הימני) — בוטל. כעת: כל תא מצייר left+right (בטוח‑RTL, גבולות פנימיים מוכפלים ~2px כמו קודם), top/bottom מגודרים כדי לדכא קו פנימי במיזוג אנכי. de‑dup+קונפליקט נכונים דורשים grid RenderObject מודע‑כיוון (start/end) + אימות חזותי מול Word | פיזי‑left/right לא מודע‑RTL; ה‑builder לא יודע גובהי שורות (תלויי‑תוכן) ל‑CustomPainter יחיד. נדחה עד RenderObject ייעודי | F | בינונית |
| 23 | `w:trHeight` **מומש ✅** — `exact` (גובה קבוע + clip), `atLeast` (רצפה), `auto` (לפי תוכן), בשני הנתיבים (מדידה+רינדור). נוסף `DocxTableRowHeightRule` + פענוח `w:hRule` ל‑AST. **ברירת מחדל של ה‑constructor = exact** (שומר על issue #74 — גובה תוכנתי נאכף); ה‑reader ממפה `w:trHeight` ללא hRule → `atLeast` (ברירת Word) | — | — |
| 24 | פורמטי מספור **`cardinalText`/`ordinalText`** (מילים באנגלית: "One"/"First") → fallback ל‑decimal | טקסט‑מילולי תלוי‑שפה ומחוץ להיקף; אנגלית בלבד בתקן, נדיר במסמכי עברית. הצורות המספריות (גימטריה/hebrew2/decimalZero/ordinal/roman/alpha) מדויקות | G | נמוכה |
| 25 | `w:lvlRestart` בערכים בינוניים (לא 0 ולא היעדר) — הפרשנות "אפס רמה D כשרמה ilvl<lvlRestart−1 מתקדמת" (קריאת ISO 1‑based). המקרים הנפוצים (היעדר=restart‑רגיל, 0=ללא restart) מאומתים בבדיקה; ערכי ביניים לא אומתו מול Word | נדיר; אין מסמך ייחוס. נעילת golden לפני הסתמכות על ערכי ביניים | G | נמוכה |
| 26 | `w:suff="tab"` (ברירת המחדל) ממומש כפער קבוע (24px box + 4px) במקום tab אמיתי לעצירת ה‑hanging‑indent דרך `TabEngine`; `nothing`/`space` מכובדים. `lvlJc` מכובד ל‑center/left, ברירת end (צמוד‑טקסט) נשמרת ל‑right/start (הגיון RTL מכוונן) | פריסת הרשימה (ConstrainedBox+Expanded) כבר מקרבת tab‑to‑indent; tab אמיתי דורש חיווט `TabEngine` לתוך פריסת הרשימה — שיפור עתידי, לא חוסם נאמנות הנראית | G | נמוכה |
| 27 | **יחידות גודל ציור:** `float_layout` עובד ב‑px (נקודות→px ×1.333); השכבה הממוקמת מרנדרת כל float ב‑`SizedBox(rect)` עם `FittedBox(fill)` סביב בונה‑התמונה/צורה (שעובד בנקודות) → גודל מרונדר ≡ גאומטריה (נסגר לשכבת ה‑floats). נתיב התמונה ה‑inline ושכבת ה‑side‑Row מנותבים כעת דרך `ImageBuilder` (טרנספורם crop/flip/rotate + פענוח‑ב‑DPR), אך עדיין שומרים על **קונבנציית נקודות‑כ‑px** (`width`/`height` כפי שהם) — ייושב כשה‑side‑Row יוחלף בעטיפת band אמיתית | נאמנות גודל-תמונה inline קיימת נשמרה; שכבת ה‑floats נכונה | H | נמוכה |
| 28 | `tight`/`through` כבר ב‑#1 (≈square). בנוסף: float **מרכז-טור** (לא צמוד לאף שוליים) נפתר בקירוב "שמור את הצד הרחב" ב‑`lineExtent` במקום עטיפה דו‑צדדית; floats מרובים נפתרים סדרתית (שמאל דוחף ימינה, ימין דוחף שמאלה) — מכסה את המקרה הנפוץ של float יחיד פר‑רצועה | עטיפה דו‑צדדית סביב float מרכזי נדירה ב‑Word; הקירוב המלבני תואם §8.2 #1 | H | נמוכה |
| 29 | **עטיפת side (square/tight) — מומש ✅** band‑reflow אמיתי מבוסס `lineExtent`: `layoutFloatWrap` ([float_text_layout.dart](../packages/docx_file_viewer/lib/src/layout/float_text_layout.dart)) פורס שורה‑אחר‑שורה (רוחב פר‑שורה מ‑`lineExtent`, חיתוך span לפי offset), מרונדר ב‑`FloatWrapText` (Stack של שורות+float) ונמדד בו‑זמנית ב‑`Paginator._measureParagraph` (אותה ליבה → measure≡render). נתיב ה‑Row הישן (`getFloatsFromParagraph`) **נמחק**. נותרו כסטיות נפרדות: עטיפה **חוצת‑פסקאות** (float גבוה שגולש לפסקאות הבאות) — לכל פסקה עוטפת רק את ה‑float שלה (§8.2 #32); ובחירה (selection) בפסקת‑float עוברת ל‑RichText לא‑נבחר | — | — |
| 32 | עטיפת side היא **פר‑פסקה** (ה‑float עוטף את טקסט פסקת‑העוגן בלבד). float שגבוה מפסקת‑העוגן לא מאלץ את הפסקאות הבאות לעטוף סביבו (Word כן) — דורש exclusion ברמת‑עמוד (RenderObject של גוף‑העמוד). strut (exact/atLeast) **כן** מושחל כעת לנתיב העטיפה (measure+render). נותרו: first‑line indent ו‑`vFrom`/`vAlign` (מיקום אנכי של ה‑float יחסית לעמוד/שוליים) לא מיושמים בעטיפה הפר‑פסקתית — הצמדה לראש הפסקה (`vOffsetPx`); הבחירה (`SelectableText`) הופכת ל‑`RichText` בפסקת‑float | המקרה הנפוץ (תמונה + טקסט צמוד בפסקתها) מטופל; חוצת‑פסקאות נדיר ויקר | H | נמוכה |
| 30 | **topAndBottom: שמירת הגובה מתחילה ב‑anchorTop** (ראש הפסקה‑מעגנת), כך שה‑float עלול לחפוף את טקסט הפסקה‑המעגנת עצמה (התוכן שאחריה כן נדחק מתחת ל‑float). ב‑Word ה‑float יושב מתחת לשורת‑העיגון | המקרה הנפוץ: פסקת‑עוגן ריקה/קצרה; חישוב מדויק דורש baseline של שורת‑העיגון | H | נמוכה |
| 31 | **float מסובב בזווית ≠180°:** `_buildFloatDrawing` משתמש ב‑rect של ה‑extent הלא‑מסובב + `Transform.rotate` (paint‑only), כך שתיבת‑החוסם בפועל שונה → חיתוך/מילוי‑חסר קל. מטופל נכון רק כשרוטציה=180° (flip) | float מסובב נדיר; חישוב bbox מסובב נכון דורש fixture אמיתי לאימות מול Word | H | נמוכה |
| 33 | **float side ב‑hAlign מרכז (או ממוקם‑offset) מרונדר כבלוק ממורכז** מעל/מתחת לטקסט, לא כעטיפה דו‑צדדית כמו Word. הסיווג המשותף `sideBandOf` ([float_layout.dart](../packages/docx_file_viewer/lib/src/layout/float_layout.dart)) מחזיר `SideBand.none`, וכך **גם** הרינדור (Center block) **וגם** המדידה (`localCenterFloatsHeight` מוסיף את גובהו) — measure≡render נשמר (תוקן הבאג שבו המדידה עיטפה band סביב float שהרינדור מציג כבלוק). רק side floats בקצה (left/right/inside/outside) עוטפים טקסט. **קירוב שיורי:** המדידה מוסיפה את גובה הבלוק בלבד, בעוד הרינדור עוטף כל ילד‑עמודה ב‑`Padding(bottom:8)` — פער של ~8px×(מספר הילדים) בפסקת בלוק‑ממורכז (לא נמדד גם טרם השינוי) | עטיפה דו‑צדדית סביב float מרכזי נדירה (§8.2 #28); הקירוב שומר על מדידה≡רינדור פרט לריווח‑הבלוק הזניח | H | נמוכה |
| 34 | **מצב `continuous`: layer floats (`behindText`/`inFront`/`none`) אינם מרונדרים** — אין page model שיציב אותם בקואורדינטות עמוד‑אבסולוטיות (קיים רק ב‑paged). `topAndBottom` כן מרונדר inline כבלוק מיושר ([paragraph_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/paragraph_builder.dart)) כדי שלא ייעלם. side floats עובדים בשני המצבים (`FloatWrapText`) | מיקום עמוד‑אבסולוטי דורש גאומטריית עמוד שאין במצב הזרימה הרציפה; הנפוץ (תמונה צפה צמודת‑טקסט) מטופל | H | נמוכה |
| 35 | **`justify` מתבטל בנתיב עטיפת ה‑float** — `FloatWrapText` מרנדר כל שורה כ‑`RichText` נפרד (שורה בודדת), ו‑Flutter לא מותח שורה יחידה ב‑justify → פסקה מיושרת‑לשני‑צדדים עם side float מוצגת כ‑ragged. ריווח‑מילים ידני (חלוקת הרווח העודף פר‑שורה) דורש זיהוי שורת‑סיום מול שורת‑band‑break + סיכון parity — נדחה לפיצ'ר נדיר (justify∩float) | עטיפת band מחייבת שורה‑לשורה; justify של שורה בודדת לא נתמך ב‑Flutter. הנפוץ (start/right/center) מדויק | H | נמוכה |
| 36 | **כיסוי גיאומטריית צורות:** `shapePresetPath` ([shape_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/shape_builder.dart)) מצייר נתיב אמיתי (dart:math) ל‑rect/roundRect/ellipse (כ‑`BoxDecoration`), triangle/rtTriangle/diamond/parallelogram/trapezoid, מצולעים רגולריים (pentagon→octagon), כוכבים (star4/5/6), חיצי‑בלוק (4 כיוונים + דו‑ראשיים), chevron, plus/cross, ו‑line/connector. צורות מורכבות (callouts, flowchart, heart, cloud, ribbon, cube, can, smiley…) → **מלבן מעוגל בצבע המילוי** (placeholder נראה). `pentagon` מצויר כ‑5‑גון רגולרי (ולא home‑plate של OOXML). **מילוי:** solid + gradient (linear לפי `a:lin@ang`, radial לפי `a:path`), כולל **צבעי ערכת‑נושא** (`a:schemeClr`, ממופה ל‑theme‑resolver) — round‑trip מלא ב‑reader+buildXml. לא נתמכים (נדיר): טרנספורמי‑צבע `a:lumMod`/`a:lumOff`/`shade`/`tint` (צבע‑בסיס בלבד), מילוי תבנית/תמונה (`a:pattFill`/`a:blipFill`). **קווים** (`line`/`straightConnector1`) מצויירים לאורך הציר הארוך (אופקי/אנכי), לא אלכסון. **flip** ממראה את הגיאומטריה בלבד — הטקסט נשאר קריא | הצורות+המילויים הנפוצים מכוסים נכון; preset‑geometry מלא של DrawingML (adjust‑handles, custGeom) הוא היקף עצום — placeholder נראה עדיף על היעלמות | H | נמוכה |

---

## §9. לוח סטטוס — **ה‑AI מעדכן כאן**

| חלק | שם | סטטוס | הערות |
|---|---|---|---|
| A | השלמת Reader | ✅ הושלם 2026-06-10 | A.1–A.6 מפוענחים + round‑trip; פירוט ביומן |
| B | מנוע סגנונות | ✅ הושלם 2026-06-11 | `DocxStyleResolver` **מחווט לייצור**; 379 בדיקות + אומת על Word אמיתי; auto‑color+perf סגורים (מנוע פי ~5.6 מהיר). סטיות מודעות מתועדות (§8.2 #4–6). שאריות nice‑to‑have: golden ל‑#1, אימוץ helpers ב‑viewer |
| C | מדידה/טאבים/BiDi | ✅ הושלם 2026-06-11 | `SpanFactory` (מקור אמת אחד), `TextMeasurer` (LRU+מטמון, parity ±0.5px, **StrutStyle** ל‑exact/atLeast, baseline), טבלת BiDi C.4, `TabEngine`+`TabbedLineRenderer`, **דילוג vanish**. **97 בדיקות ירוקות** (≈36 חדשות). #7/#8 נסגרו (יומן 2026‑06‑11 "סגירת פערים"). שאריות דחויות = §8.2 **#9–11** (charScale/position, wrapping של tab+decimal+ירושת stops, golden‑image) — נדירים/לא חוסמים את D, parity נשמר |
| D | מנוע עימוד | 🟨 קוד הושלם — נשאר רק אימות על מכשיר | **מנוע+חיווט+§D.2.5+async+streaming הושלמו** (129 בדיקות בחבילה ירוקות): מילוי מבוסס‑מדידה, פיצול פסקה (widow/orphan), פיצול טבלה (חזרת כותרת+cantSplit), מקטעים+evenPage blank, keepNext, פיצול שבירת‑עמוד אמצע‑פסקה (§D.2.5), מפות bookmark/footnote. **ההיוריסטי נמחק** — נתיב יחיד. `PageContext` אמיתי (PAGE/NUMPAGES/SECTIONPAGES/PAGEREF, even/odd, multi‑section); חיפוש מיושר לפרוסות. **time‑slicing אסינכרוני** + **streaming display** — עמודים מוצגים ככל שנולדים (`paginateStreaming`/`onPage`), בנייה עצלה פר‑עמוד (`buildPageWidget`) ב‑`ListView.builder`, placeholder בגובה‑עמוד לזנב (§D.2.9/§D.3/§4.4); חיפוש ממתין לסיום עימוד ואז עובר ל‑keyed list. ריווח ברירת‑מחדל הודק 1.5→1.15; אומת מול Word 7=7 ב‑formatting-demo. **נשאר (דורש מכשיר/fixtures, לא בר‑הרצה ב‑harness):** מדידת תקציבי §2.2/§2.3 על מסמך ייחוס ב‑profile + אימות ידני מול Word (3 מסמכים, ±שורה). יומן 2026‑06‑11/12 |
| E | קליפת עמוד | 🟨 בעבודה — נשאר סימן מים + מספור שורות | **רינדור הושלם:** גובה עמוד **קבוע** (`SizedBox`+clip, §E.2), **vAlign** top/center/bottom/both (§E.1.3), **גבולות עמוד** `w:pgBorders` (`PageBorderPainter` — single/double/thick, offsetFrom text/page, display all/first/notFirst, §E.1.4), **רקע מקטע** `backgroundColor` (§E.1.1), **מספרי עמוד עבריים** hebrew1=גימטריה/hebrew2=אותיות מקצה‑לקצה (enum+`NumberFormatter`+reader, §E.2 — קריטי למסמכי קודש). 6 בדיקות E + 3 ב‑docx_creator. **נשאר:** סימן מים (§E.1.5 — תלוי רינדור צורות H), מספור שורות (§E.1.6, עדיפות נמוכה), פיצול `page_widget.dart` (ארגוני), golden‑image. סטיות §8.2 #17–19. יומן 2026‑06‑12 |
| F | טבלאות 1:1 | ✅ הושלם 2026-06-12 | **§F.1 מנוע רוחבי עמודות** (`table_layout.dart`: fixed verbatim / autofit honour‑grid+scale‑down / `w:tblW` pct+dxa / `w:tblInd` / רצפת‑min) מחווט ל‑**מדידה** (Paginator) ול‑**רינדור** (TableBuilder) → מדידה≡רינדור (§8.2 #14 נסגר). **§F.2 גבולות:** ציור פר‑תא **בטוח‑RTL** (left/right תמיד מצוירים — לא מאבדים גבול חיצוני בטבלת RTL) + דיכוי הקו הפנימי במיזוג אנכי (`drawTop`/`drawBottom` → המיזוג נקרא כבלוק אחד). **קונפליקט "חזק‑מנצח" + de‑dup נדחו** (דורש grid RenderObject מודע‑כיוון — §8.2 #22). **§F.3:** bidiVisual (מראה עמודות), שולי תא אמיתיים (tcMar/tblCellMar 108tw), textDirection (tbRl/btLr→RotatedBox), gridBefore, **trHeight exact/atLeast/auto** (שדה `hRule` נוסף ל‑AST+reader). 24 בדיקות חדשות. סטיות §8.2 #21–23. **נדחה:** מיזוג‑תוכן אמיתי (rowspan), קונפליקט גבולות, טבלאות צפות→H, golden. יומנים 2026‑06‑12 |
| G | רשימות 1:1 | ✅ הושלם 2026-06-15 | **`NumberingResolver` גלובלי** (`lib/src/layout/numbering_resolver.dart`): מעבר אחד בסדר מסמך, counters פר‑`(numId,ilvl)`, מפת `item→label` (ללא שינוי AST). פותר המשכיות אחרי פסקה מפרידה, אותו numId בשני מקומות, ורשימות בתוך תאי טבלה; header/footer/הערות כ‑story עצמאי. כללים: restart בעליית רמה + `w:lvlRestart` (0=לעולם), compound `%1.%2.%3`, **isLgl** (כל הרכיבים decimal), `suff`/`lvlJc` בפריסה. פורמטים: גימטריה (hebrew1, טו/טז), hebrew2, decimalZero, ordinal, none, + roman/alpha/decimal. הקורא הורחב (isLgl/suff/lvlJc/lvlRestart + numFmtRaw). נתיב fallback (רשימות factory) נשמר. **docx_creator 388 + viewer 203 ירוקות** (+3 reader, +13 resolver; +4 golden חסרות‑fixture קדם‑קיים). סטיות §8.2 #24–26. יומן 2026‑06‑15 |
| H | ציורים ועטיפה | 🟨 בעבודה — נשאר עטיפה חוצת-פסקאות (§8.2 #32), golden | **סשן 6 (2026-06-17): VML watermark-behind.** תמונת `w:pict` עם `position:absolute` בסגנון ה-`v:shape` ממופה כעת ל-float: `z-index<0`→`behindText` (סימן מים מאחורי הטקסט), `mso-position-horizontal/-vertical(+-relative)`→align/from, `margin-left/-top`→offset (`_parseVmlPlacement`). +4 בדיקות. <br> **סשן 5 (2026-06-17): צורות — גיאומטריית presets אמיתית + gradient.** שכתוב `shape_builder`: תוקן trig מתוצרת-בית (→dart:math), `shapePresetPath` טהור (triangle/diamond/parallelogram/trapezoid/מצולעים-רגולריים/כוכבים/חיצי-בלוק/chevron/plus/line), ellipse אמיתי, איחוד פתרון-צבע, flipH/flipV. `DocxGradientFill` (AST+reader+buildXml round-trip) + רינדור LinearGradient/RadialGradient (decoration+shader). +18 בדיקות (15 גיאומטריה/רינדור + 4 gradient reader/round-trip). סטיות §8.2 #36. <br> **סשן 4 (2026-06-16): עטיפת side אמיתית (band-reflow, §8.2 #29).** `layoutFloatWrap` (ליבה טהורה) פורס טקסט שורה-אחר-שורה לפי `lineExtent` (חיתוך span פר-offset); `FloatWrapText` מרנדר Stack של שורות+float; `Paginator._measureParagraph` מודד באותה ליבה → **measure≡render**. נתיב ה-Row הישן (`getFloatsFromParagraph`) **נמחק**; `span_factory` מדלג כל float floating. parity 7 עמ' נשמר; +8 בדיקות (core) + עדכון 6 בדיקות float ל-wrap. סטיות §8.2 #31–32. <br> **סשן 3 (2026-06-15): תיבות-טקסט + תיקוני סקירת סשן 2.** `DocxShape.textBlocks` (re-entry: הקורא מפענח `w:txbxContent` כבלוקים דרך `BlockParser`; round-trip ב‑buildXml). `ShapeBuilder` מקבל `textBlockBuilder` (callback מהגנרטור → `_generateBlockWidgets`) ומרנדר את בלוקי התיבה (clipped, top-aligned) במקום מחרוזת שטוחה; `paragraph_builder._buildInlineShape` מנותב כעת ל‑`ShapeBuilder` (איחוד נתיב, תיבה inline/side מרנדרת תוכן). **תיקוני סקירה:** measure≡render ל‑side floats (נמדדים בזרימה; רק fullWidth/layer מדולגים); ניתוב inline/Row images דרך `ImageBuilder` (crop/RAM); Flutter `>=3.27`. +7 בדיקות → **docx_creator 396 + viewer 246**. סטיות §8.2 #31. <br> **סשן 2 (2026-06-15): חיווט floats מקצה-לקצה** — `PageModel.floats` (`PlacedFloat`); ה‑`Paginator` רושם floats פר‑עמוד (rect מ‑`resolveFloatRect`, anchorTop=`_used`), topAndBottom שומר גובה (`exBottom→cursor`), ו‑floats **לא נמדדים inline** (`span_factory` מדלג floating → תוקן measure≡render); ה‑renderer מצייר שכבת `Positioned` z-order ל‑topAndBottom+front, מפשיט אותם מהגוף (`_stripFloats`, ללא רינדור כפול), behindText=רקע, side=Row-legacy. `FittedBox` מיישב יחידות לשכבה (§8.2#27). +8 בדיקות (4 paginator/measure, 4 render) → **viewer 242 ירוקות**. סטיות §8.2 #29–30. <br> **סשן 1:** H.1 מודל + H.3 תמונות + H.2 ליבה טהורה. AST: `DocxInlineImage` קיבל rotation/flipH/flipV/crop(`a:srcRect`); `DocxShape` קיבל flipH/flipV — round-trip מלא ב‑buildXml. הקורא ([inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart)) מפענח `a:xfrm` rot/flip + `a:srcRect` לתמונות+צורות, **ועוגן floating של צורות** (קודם הוזנח). רינדור תמונות ([image_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/image_builder.dart)): crop→flip→rotate + `cacheWidth/Height` (RAM §2.4#2). ליבה טהורה חדשה [float_layout.dart](../packages/docx_file_viewer/lib/src/layout/float_layout.dart): `resolveFloatRect` (כל relativeFrom×align/offset → קואורדינטות-גוף) + `lineExtent`/`nextUsableY` (פותר רצועות, side/topAndBottom/layer, RTL). **docx_creator 393 + viewer 234 ירוקות** (+5 +26 חדשות; 4 golden חסרות-fixture קדם-קיים). **נשאר:** חיווט float ל‑Paginator (רצועות-מדידה) + PageWidget (Positioned z-order), מחיקת Row-grouping הישן, תיבות-טקסט (re-entry לבלוקים), VML watermark, presets נוספים+gradient, יישוב יחידות §8.2#27. סטיות §8.2 #27–28. יומן 2026‑06‑15 |
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

### 2026-06-12 — חלק D — מענה לסקירת קוד (עמידות משאבים + ביצועי חיפוש)
**בוצע (סקירה חיצונית של 3 הקומיטים):**
- **🔴 try/finally סביב `measurer.dispose()`** ([docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart) `_generatePagedWidgets`/`_generatePagedWidgetsAsync`): אם `paginate`/`paginateAsync` זורקים, ה‑`TextPainter` הממוחזר היה דולף. עכשיו משוחרר ב‑`finally`.
- **🔴 חיפוש לא מעמד מחדש:** `_onSearchChanged` ([docx_view.dart](../packages/docx_file_viewer/lib/src/docx_view.dart)) קרא `generateWidgets` → עימוד מלא (מדידה) בכל הקלדה. נוסף `rerenderWidgets` שמשתמש ב‑`_lastPagination` הממוטמן (חיפוש לא משנה layout, §2.4.6) ובונה widgets עם ההדגשות בלבד — **בלי מדידה מחדש**. ב‑continuous נופל ל‑`generateWidgets` כרגיל. (החלפת ה‑GlobalKey‑per‑block ווירטואליזציה מלאה = עדיין חלק M.)
- **נדחה (מתועד):** מפתח קאש `width.round()` — **לא בעיה**: רוחב התוכן קבוע פר‑עימוד (אין וריאציה שברירית), אז אין cache‑miss מיותר. lookahead=5 ל‑float grouping וקאש ל‑`layoutForSplit` — קדם‑קיים/נדיר, נשאר. איחוד inline→span (TODO) = חלק C/L.
**בדיקות:** בדיקה חדשה (`rerenderWidgets` משתמש שוב ב‑pagination — אותו object). `docx_file_viewer`: **122 ירוקות**, analyze נקי, format הורץ.

### 2026-06-12 — חלק D — streaming display אמיתי (§D.2.9/§D.3/§4.4)
**בוצע:** מומשה ההצגה הזורמת — הפריט האחרון שהיה בר‑מימוש בקוד מבין שאריות D (התקציבים על מכשיר ואימות Word הידני דורשים device/fixtures). עכשיו ההצגה במצב paged מציגה עמודים **ככל שהם נולדים** עם placeholder לזנב, במקום להמתין לעימוד מלא.
- **`Paginator.paginateAsync`** ([paginator.dart](../packages/docx_file_viewer/lib/src/pagination/paginator.dart)) קיבל callback `onPage`, שנקרא ב‑`_closePage` עם כל `PageModel` ברגע סגירתו (בסדר מסמך). ה‑`PaginationResult` המלא (עם מפות bookmark/footnote, סופיות רק בסוף) עדיין מוחזר. `_reset` מאפס את ה‑callback כך שהנתיב הסינכרוני (`paginate`) לעולם לא יורש callback ישן.
- **`DocxWidgetGenerator`** ([docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart)):
  - `paginateStreaming(doc, onPage:)` — מודד+זורם, משחרר את ה‑`TextMeasurer` ב‑`finally`, ושומר `lastPagination` (כך ש‑`extractTextForSearch` מיושר לפרוסות).
  - `buildPageWidget(doc, pages, index, {finalResult})` — בונה **עמוד בודד עצלן** (ה‑host קורא מ‑`ListView.builder` → רק עמודים נראים נבנים, §D.3). בלי search keys (אין match בזמן טעינה; ניווט חיפוש משתמש ב‑keyed list של `_renderPages`). `finalResult==null` בזמן זרימה → `NUMPAGES`/`SECTIONPAGES`/`PAGEREF` לפי סך רץ, מתייצבים לערך הסופי בסיום (§8.2 #16).
  - `pageDisplayWidth/Height` — מידות עמוד ל‑placeholder (יציבות scrollbar, §4.4).
  - חולץ `_buildPageFromModel` (מקור רינדור‑עמוד **יחיד** ל‑`_renderPages` העצל וגם ל‑`buildPageWidget`, §2.4.6); `_sectionPageCounts` חולץ. `_initBuilders` קיבל **guard‑זהות** (`_buildersFor`) כדי שבנייה עצלה פר‑פריים לא תאתחל בנאים מחדש כל פריים.
- **`DocxView`** ([docx_view.dart](../packages/docx_file_viewer/lib/src/docx_view.dart)): נתיב טעינה paged כעת **זורם** — `_isLoading=false` נקבע לפני העימוד, `paginateStreaming` ממלא `_pages` (כל עמוד → `setState`, מקובץ פר‑פריים), וה‑`build` מרנדר `ListView.builder(itemCount: pages + (paginating?1:0))` עם itemBuilder עצל ו‑placeholder בגובה‑עמוד לזנב. בסיום: בניית אינדקס חיפוש + `setState` עם הערכים הסופיים. `_onSearchChanged` ממתין ל‑`!_paginating`, ואז `rerenderWidgets` מחליף ל‑keyed eager list לניווט (מודל ה‑GlobalKey‑per‑block נשאר — חלק M). נוסף guard‑דור (`_loadGeneration`) נגד מרוץ של stream מיושן בעת החלפת מסמך. מצב continuous לא השתנה.

**תובנת מפתח:** GlobalKeys מוצמדים רק כשיש match חיפוש פעיל ([paragraph_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/paragraph_builder.dart) `build`) — ולכן בזמן הטעינה הראשונית (חיפוש לא פעיל) בנייה עצלה פר‑עמוד היא נקייה מהתנגשות מפתחות. זה אִפשר זרימה זולה תוך השארת מודל ה‑GlobalKey‑per‑block (שחלק M מחליף) ללא שינוי.

**בדיקות:** [paginator_test.dart](../packages/docx_file_viewer/test/paginator_test.dart) +3 (onPage זורם כל עמוד בסדר; מסמך ריק → עמוד‑ריק יחיד דרך onPage; הנתיב הסינכרוני לא מפעיל callback ישן). [streaming_pagination_test.dart](../packages/docx_file_viewer/test/streaming_pagination_test.dart) חדש +4 (זורם כל עמוד+שומר result; `buildPageWidget` עם NUMPAGES סופי; NUMPAGES זמני‑מול‑סופי; מידות placeholder). `docx_file_viewer`: **129 ירוקות** (122→129), `flutter analyze` נקי, `dart format` הורץ. אותן 4 golden נכשלות על fixtures חסרים (קדם‑קיים — אומת מחדש: PathNotFound ל‑`mixed/footer/frame_test.docx`). `docx_creator` לא נגעתי בו.

**החלטות/סטיות:**
1. **בנייה עצלה רק בזמן streaming/finalized‑ללא‑חיפוש; keyed eager בעת חיפוש.** הסיבה: keys לניווט נחוצים רק אחרי שהחיפוש פעיל, ובנייה עצלה אז הייתה מחזירה את בעיית התנגשות ה‑GlobalKey שחלק M מטפל בה. כך אין dual‑path במדידה (מדידה פעם אחת ב‑`paginateStreaming`) ולא ברינדור (`_buildPageFromModel` יחיד). §8.2 #15.
2. **NUMPAGES זמני בזמן זרימה** (§8.2 #16) — מתייצב לסופי בסיום; PAGE נכון מיד. נבחר על פני עימוד‑כפול (§D.2.10 מתיר זאת; שינוי‑גובה מ‑NUMPAGES בכותרת נדיר).
3. **בדיקות streaming שמרנדרות widgets רצות תחת `tester.runAsync`** — `paginateStreaming` מניב את ה‑UI thread (`Future.delayed`) שלא נפתר ב‑fake‑async של `testWidgets`; בדיקות ללא widget‑tree רצות כ‑`test()` רגיל (real async, כמו בדיקת ה‑`paginateAsync` הקיימת).

**נשאר ל‑D (✅ — דורש מכשיר):** (1) מדידת תקציבי §2.2 (עמוד ראשון ≤1.5s, עימוד מלא ≤6s, פריים ≤16ms) ו‑§2.3 (RAM) על מסמך הייחוס ב‑`--profile`. (2) אימות ידני מול Word על 3 מסמכים אמיתיים, ±שורה. שניהם אינם בני‑מדידה ב‑test harness. שאריות קוד דחויות (לא חוסמות): autofit טבלה (F), continuous עם שינוי גאומטריה (I), וירטואליזציה מלאה+zoom והחלפת GlobalKey‑per‑block (M).

### 2026-06-12 — חלק D — מענה לסקירת קוד של ה‑streaming
**בוצע:** טופלה סקירה חיצונית של קומיט ה‑streaming (לא נמצאו ממצאי 🔴). תוקן/הוחלט:
- **🟡 #2 (data‑loss UX) — שאילתת חיפוש שהוקלדה בזמן streaming נמחקה.** `_isLoading=false` נקבע לפני העימוד, כך שתיבת החיפוש חיה, אבל `_onSearchChanged` חוזר מוקדם כל עוד `_paginating`, ובסיום `setDocument`→`clear()` מחק את השאילתה. תוקן ([docx_view.dart](../packages/docx_file_viewer/lib/src/docx_view.dart)): לוכדים `_searchController.query` לפני `setDocument` ומריצים אותה מחדש (`search(pending)`) אחרי שה‑index והמפתחות קיימים.
- **🟡 #3 (ביטול עימוד מיושם) — עימוד שהוחלף לא בוטל.** בהחלפת מסמך מהירה, ה‑`paginateAsync` הישן המשיך עד הסוף (onPage no‑op דרך guard‑הדור, אבל הלולאה לא נעצרה) — בזבוז UI thread. נוסף **cooperative cancel:** `shouldContinue` מושחל ל‑`paginateAsync` ([paginator.dart](../packages/docx_file_viewer/lib/src/pagination/paginator.dart)), נבדק אחרי כל time‑slice; `DocxView` מעביר `() => mounted && myGen == _loadGeneration`.
- **🟡 #4 (DoS על קלט לא‑אמין) — אין חסם עליון על מספר עמודים.** `.docx` פתולוגי/עוין (עמוד זעיר, גוף ענק) ייצר `_pages`/עימוד בלתי‑חסומים. נוסף **backstop `maxPages`** (ברירת מחדל 50,000 — הרבה מעל כל מסמך אמיתי) ב‑`Paginator`: בהגעה לקאפ, `_closePage` מדליק `_truncated`, ולולאת המילוי + רקורסיית הפיצול נעצרות (guards `_stop` ב‑`_placeBlock`/`_placeGroup`/`_ensurePage`, ו‑`_newPage` לא פותח עמוד מעבר לקאפ). `PaginationResult.truncated` מסומן, ו‑`DocxView` מציג הודעת קיטום בזנב.
- **🟢 #1 (תיעוד מול מציאות) — ה‑placeholder לא מספק "scrollbar יציב" מלא.** יש placeholder יחיד (לא פר‑עמוד שטרם עומד), כך שה‑scroll extent גדל ככל שעמודים נולדים. רוככו ההערות ב‑`_buildPagePlaceholder` ובלולאת ה‑build כדי לתאר "loading affordance בזנב; אזור התוכן גדל ככל שעמודים זורמים", במקום הבטחת יציבות מלאה. אומדן פר‑עמוד = follow‑up (דורש אומדן עמודים מהימן + drift מ‑fixed‑height מול `minHeight`).
- **🟢 #5 (DRY/perf) — `buildPageWidget` סרק את כל העמודים ל‑SECTIONPAGES בכל בנייה.** אוחד עם `_sectionPageCounts` (הגדרה יחידה) + **memoization** (`_finalSectionCounts`) כשה‑`finalResult` ידוע, מאופס ב‑`_initBuilders` בהחלפת מסמך.
- **🟢 #6/#9 — הערות:** תועד ש‑גובה ה‑placeholder קבוע מול `minHeight` הגמיש של עמוד (drift קטן אפשרי), ושה‑guard‑זהות של ה‑builders (`_buildersFor`) מניח "בנאי אחד פר‑טעינה" (לא ירענן על שינוי theme עם אותו doc).
- **נדחה (מתועד):** #8 (batching של setState פר‑slice במקום פר‑עמוד) — Flutter מאחד dirty‑marks פר‑frame, מיקרו‑אופטימיזציה; #7 (שינוי התנהגות: מסמך ריק ב‑paged מרנדר עמוד‑ריק במקום הודעת "Empty document") — **מכוון** (נאמן ל‑Word), ננעל בבדיקה.

**בדיקות:** [paginator_test.dart](../packages/docx_file_viewer/test/paginator_test.dart) +2 (`shouldContinue=false` עוצר מוקדם; `maxPages` חוסם+מסמן `truncated`). [streaming_pagination_test.dart](../packages/docx_file_viewer/test/streaming_pagination_test.dart) +1 (מסמך ריק ב‑paged → עמוד‑ריק יחיד בר‑רינדור, §7). `docx_file_viewer`: **132 ירוקות** (129→132), `flutter analyze` נקי, `dart format` הורץ. אותן 4 golden נכשלות על fixtures חסרים (קדם‑קיים).

### 2026-06-12 — חלק E (קליפת עמוד) — 🟨 בעבודה: רינדור הקליפה הושלם
**בוצע:** מומשו פיצ'רי הרינדור המרכזיים של "קליפת העמוד" (§E.1). **חבילות:** בעיקר `docx_file_viewer`; מספרי עמוד עבריים גם ב‑`docx_creator` (core).
- **מספרי עמוד עבריים (§E.2 — קריטי למסמכי קודש):** `DocxPageNumberFormat` קיבל `hebrew1`/`hebrew2` ([enums.dart](../packages/docx_creator/lib/src/core/enums.dart)). `NumberFormatter.formatPage` ([number_formatter.dart](../packages/docx_creator/lib/src/core/number_formatter.dart)): hebrew1→`hebrew(n)` (גימטריה, כבר היה), hebrew2→`hebrewAlpha(n)` חדש (בייקטיבי בסיס‑22 על 22 האותיות). הקורא ([section_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/section_parser.dart) `mapPageNumberFormat`) ממפה `w:fmt="hebrew1"/"hebrew2"`; ה‑switch ב‑`_formatSwitch` ([docx_section.dart](../packages/docx_creator/lib/src/ast/docx_section.dart)) טופל (Hebrew→ללא `\*` switch). **מקצה‑לקצה ב‑viewer**: `FieldSubstitution`→`formatPage`→עמוד 1 בכותרת תחתונה = "א".
- **גובה עמוד קבוע (§E.2/§D.2.6):** `_buildPageContainer` ([docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart)) עבר מ‑`minHeight` ל‑`height: pageHeight` קבוע + `Clip.hardEdge` — תוכן שנמדד מעט גבוה נחתך במקום למתוח את העמוד.
- **vAlign (§E.1.3):** top/center/bottom עוטפים `OverflowBox` (יישור אנכי ללא overflow‑assert, נחתך לעמוד); both = `Column` עם `spaceBetween`. הגוף ב‑`Positioned`(שוליים)+`ClipRect`.
- **גבולות עמוד (§E.1.4):** [page_chrome.dart](../packages/docx_file_viewer/lib/src/widgets/page_chrome.dart) חדש — `PageBorderPainter` (CustomPainter): מסגרת לפי `offsetFrom` text/page, `w:space` פר‑צד, סגנונות single/double/thick, רוחב מ‑`w:sz` (eighths‑pt). מגודר ב‑`display` (all/first/notFirst) דרך `isFirstPage`. `resolveDocxColor` helper.
- **רקע מקטע (§E.1.1):** `section.backgroundColor` → צבע ה‑paper (מתחת ל‑behindDoc + body).
- **header/footer פר‑עמוד + שדות חיים:** כבר חווט ב‑D (PageContext אמיתי). אומת.

**בדיקות:** [page_chrome_test.dart](../packages/docx_file_viewer/test/page_chrome_test.dart) חדש — 6: גובה קבוע 600px; מיפוי vAlign→`OverflowBox`; `PageBorderPainter` קיים/חסר; גבול firstPage‑only מגודר פר‑עמוד; רקע מקטע אדום; מספר עמוד עברי "א" בכותרת תחתונה. `docx_creator`: number_formatter +2 (`hebrewAlpha`, `formatPage` routing), section_page_numbering +2 asserts → **381 ירוקות**. `docx_file_viewer`: **138 ירוקות** (132→138), `flutter analyze` נקי בשתי החבילות, `dart format` הורץ. אותן 4 golden נכשלות על fixtures חסרים (קדם‑קיים).

**החלטות/סטיות (§8.2 #17–19):**
1. גבולות dashed/dotted/triple→single, zOrderBack→front, theme‑color→fallback (§8.2 #17). single/double/thick (כולל ה‑DoD) מלאים.
2. `vAlign="both"` = spaceBetween; overflow נדיר asserts ב‑debug בלבד (§8.2 #18).
3. **לא פוצל ל‑`page_widget.dart`** (§E.1.1) — מומש in‑place ב‑`_buildPageContainer` (ארגוני בלבד, אותה התנהגות, נבדק). **סימן מים (§E.1.5) נדחה** — תלוי רינדור צורות (rotation+opacity) של חלק H; "יוצא בחינם" כשה‑header ירונדר מלא. **מספור שורות (§E.1.6) נדחה** — עדיפות נמוכה מפורשת. (§8.2 #19)
4. הקורא כבר פענח `w:vAlign`/`w:pgBorders` ל‑AST בחלק A — חלק E רק צורך אותם ברינדור.

**נשאר ל‑E (✅):** סימן מים (אחרי H), מספור שורות (אופציונלי), golden‑image (כשיסופקו fixtures). DoD §E.2: גובה‑קבוע ✅, עברי ✅, golden ⬜ (תלוי fixtures).
**ל‑AI הבא:** חלק F (טבלאות 1:1) — autofit/קונפליקט גבולות/bidiVisual/חזרת שורת כותרת. או השלמת אימות‑מכשיר של D (תקציבי §2 + Word) כשהמשתמש יספק מסמכים.

### 2026-06-12 — חלק E — מענה לסקירת קוד (חיתוך שקט + vAlign both + עקביות)
**בוצע:** טופלה סקירה חיצונית של חלק E (ללא ממצאי 🔴 קורסים). תוקן/הוחלט:
- **🟡 #1 — חיתוך טקסט שקט תחת גובה קבוע (קריטי למסמכי קודש).** המעבר ל‑`height` קבוע + `Clip.hardEdge` חתך תוכן בשקט בכל סטיית מדידה≠פריסה. נבנה **`PageBody`** ([page_chrome.dart](../packages/docx_file_viewer/lib/src/widgets/page_chrome.dart)) — `RenderObject` שמפרס את הגוף בגובהו הטבעי, מיישר (vAlign), חותך לאזור, ו**מזהיר ב‑debug** (`debugPrint`) כשהגוף חורג (telltale; release חותך). מחליף את `OverflowBox`+`ClipRect`.
- **🟡 #2 — `vAlign="both"` היה הענף היחיד שעלול ל‑overflow‑assert.** עכשיו `both` עובר דרך אותו `PageBody` עם `stretch:true`: justify (spaceBetween על מלוא הגובה) **רק כשהתוכן נכנס**, אחרת נופל לגובה טבעי+clip ללא assert — עקבי עם top/center/bottom.
- **🟢 עקביות fallback** — `NumberFormatter._alpha(n<=0)` שונה מ‑`''` ל‑`'$n'` (כמו `hebrew`/`hebrewAlpha`).
- **🟢 #3 (hebrew2 מעבר ל‑22) ו‑#5 (8‑hex) — תועדו** ב‑docstrings: hebrew2>22 = בייקטיבי בסיס‑22 **לא‑מאומת מול Word** (§8.2 #20); 8‑hex מטופל כ‑AARRGGBB (הגנתי; DOCX הוא RGB).
- **נדחה (מתועד):** `shouldRepaint` משווה borders ב‑`!=` — ה‑AST קבוע ומשותף ב‑reference, אז אין repaint מיותר (נכון כפי שהוא). `hebrew1`≥1000→ספרות (קדם‑קיים, §8.2 #20).

**בדיקות:** [page_chrome_test.dart](../packages/docx_file_viewer/test/page_chrome_test.dart) — `vAlign` עודכן ל‑`PageBody` + מקרה `both`; בדיקה חדשה: פסקת‑`keepLines` ענקית → clip ללא assert + telltale נורה. `docx_file_viewer`: **139 ירוקות** (+1), analyze נקי. `docx_creator`: **381 ירוקות** (`_alpha` לא שבר numbering), analyze נקי. `dart format` הורץ. אותן 4 golden נכשלות על fixtures חסרים (קדם‑קיים).

### 2026-06-12 — חלק F (טבלאות 1:1) — 🟨 בעבודה: מנוע רוחבי‑עמודות + BiDi + שוליים
**בוצע:** מומש ה‑chunk הראשון של חלק F — **מנוע רוחבי העמודות (§F.1)** והחיווט שלו קצה‑לקצה, פלוס תיקוני נאמנות ל‑BiDi ולשוליים. **חבילה:** `docx_file_viewer` בלבד (ה‑AST של הטבלה כבר נקרא מלא בחלק A).
- **`lib/src/layout/table_layout.dart` חדש — מודול טהור, נטול‑widget:**
  - `resolveTableColumnWidths(table, availableWidth, {minColumnWidths})` → `TableColumnLayout` (px פר‑עמודת‑grid): **fixed** = grid/`tcW` verbatim (overflow מותר); **autofit** = מכבד את ה‑grid (ה‑fit שאפה Word) ומכווץ פרופורציונלית רק כשחורג מרוחב העמוד; `w:tblW` **pct** (חלקיק‑אחוז מרוחב התוכן) ו‑**dxa** (twips); `w:tblInd` מקטין את הרוחב הזמין; **רצפת‑min** ל‑CSS `table-layout:auto` (`minColumnWidths` — מעלה עמודה צרה מדי ומשלם מעמודות עם slack).
  - `resolveCellMargins(table, cell)` — `tcMar` דורס `tblCellMar` דורס ברירת Word (108tw צדדים / 0 עליון‑תחתון); `cellPadding` הישן + `marginLeft/Right` הישנים כ‑fallback.
  - `cellContentWidthPx(columns, gridIndex, span, margins)` — רוחב התוכן של תא (סכום עמודות נפרשות פחות שוליים) למדידה בדיוק ברוחב הצביעה.
- **חיווט ל‑Paginator** ([paginator.dart](../packages/docx_file_viewer/lib/src/pagination/paginator.dart)): `_measureTable`/`_measureRow` עברו מחלוקת‑עמודות‑שווה ל‑`resolveTableColumnWidths` + מעקב grid‑index פר‑תא (כולל `gridBefore`/`gridSpan`) ושוליים אמיתיים. `_splitTable` משתמש באותם רוחבים. (§8.2 #14 נסגר — מדידה≡רינדור לטבלאות.)
- **חיווט ל‑TableBuilder** ([table_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/table_builder.dart)): רוחבי העמודות נגזרים מאותו מנוע (ב‑`LayoutBuilder` לטבלת‑על עם רוחב העמוד האמיתי; verbatim ל‑nested ברוחב‑אינסוף). חולץ `_buildTableContent` (מקור רינדור יחיד ל‑nested ולעל). **bidiVisual** → `Row.textDirection=rtl` (מראה סדר עמודות חזותי בלי לגעת בלוגיקת ה‑merge). **שולי תא אמיתיים** (`EdgeInsets.fromLTRB` מ‑`resolveCellMargins`) במקום padding אחיד 4px. **textDirection** בתא → `RotatedBox` (tbRl=¼, btLr=¾). **gridBefore** → ריווח מוביל + התחלת ה‑walk בעמודה הנכונה (מקביל למדידה). `trHeight`=atLeast (floor). **נוקו 3 שורות הערות‑זבל** שנשארו בראש `build` מעריכה קודמת.
- **תיקון מודל ל‑fixed:** הוכרע ש‑fixed = grid verbatim תמיד (ISO: ה‑grid/`tcW` קובעים, `tblW` אינפורמטיבי), בלי scaling.

**בדיקות:** [table_layout_test.dart](../packages/docx_file_viewer/test/table_layout_test.dart) חדש — **16 בדיקות יחידה** לאלגוריתם (DoD §F.4 #1): fixed‑verbatim+overflow, autofit honour‑grid/scale‑down/יחס נשמר/אינסוף‑nested, pct, dxa, tblInd, רצפת‑min (העלאה+slack ו‑overflow כשאין slack), `resolveCellMargins` (ברירת מחדל/tcMar דורס/cellPadding), `cellContentWidthPx`. [table_builder_test.dart](../packages/docx_file_viewer/test/table_builder_test.dart) +3 (bidiVisual→Row rtl, textDirection→RotatedBox, שולי 108tw). `docx_file_viewer`: **158 ירוקות** (139→158; +16 יחידה, +3 builder), `flutter analyze` **נקי**, `dart format` הורץ. אותן 4 golden נכשלות על fixtures חסרים (`example/assets/*.docx` — קדם‑קיים מ‑A/B/C/D/E). `docx_creator` לא נגעתי בו.

**החלטות/סטיות (§0.3, מתועד ב‑§8.2 #21–23):**
1. **autofit מכבד את ה‑grid של Word** ומכווץ‑לעמוד; autofit מבוסס‑תוכן (מדידת המילה הארוכה) נתמך במנוע ונבדק (`minColumnWidths`) אך לא מחושב בייצור — ה‑grid הוא ה‑fit הנכון בקבצים אמיתיים, ומדידת intrinsic פר‑תא יקרה (תקציב פריים, טבלה 500 שורות). §8.2 #21.
2. **פתרון קונפליקט הגבולות (§F.2) נדחה** ל‑chunk הבא — rewrite של ציור הגבולות ל‑CustomPainter יחיד הוא רכיב גדול ומסוכן שמגיע לו סקירה ייעודית; הגבולות נשארים פר‑תא עם הקדימות הקיימת. §8.2 #22.
3. **trHeight=atLeast בכל מקום** — `exact` דורש שדה `hRule` שהקורא לא לכד (פער A). §8.2 #23.

**בעיות פתוחות / ל‑AI הבא (השלמת F ל‑✅):**
1. **§F.2 — ציור גבולות מאוחד** עם פתרון קונפליקט Word (הגבול החזק מנצח בין תאים שכנים; tcBorders דורס insideH/V; `nil` מבטל; ירושה מסגנון לפי cnf) דרך CustomPainter יחיד לטבלה (מטריצת קווים H/V) — מהיר וזול, מונע קווים כפולים.
2. **trHeight‑exact** — הוספת `hRule` ל‑`DocxTableRow` ב‑reader (חלק A‑style) + חיתוך לגובה השורה.
3. **טבלאות צפות** (`tblpPr`) → מנגנון ה‑floats של חלק H (מיקום מוחלט+עטיפה) במקום ה‑Row הקיים.
4. **golden** של טבלה (merge/banding/bidiVisual/גבולות מתנגשים/חזרת כותרת) — תלוי באספקת fixtures (כמו שאר החלקים).
5. אופציונלי: autofit מבוסס‑תוכן בייצור (להוסיף `TextMeasurer.intrinsicWidth` ולהזין `minColumnWidths`) אם יתגלה מסמך אמיתי ללא grid משמעותי.

### 2026-06-12 — חלק F — ✅ הושלם: קונפליקט גבולות (§F.2) + trHeight exact (§F.3)
**בוצע:** הושלמו שני הפריטים האחרונים בני‑המימוש של חלק F (טבלאות צפות שייכות לחלק H לפי התוכנית; golden חסום על fixtures).
- **§F.2 — פתרון קונפליקט גבולות + ציור בעלים‑יחיד:**
  - מודול טהור חדש [table_borders.dart](../packages/docx_file_viewer/lib/src/layout/table_borders.dart): `borderStrength` (משקל `w:sz` שולט; הסגנון שובר תיקו: double/triple>thick>single>dashed/dotted; נעדר/none<0) ו‑`strongerBorder(a,b)` (החזק מנצח; תיקו→`a` = העליון/שמאלי, כמו Word).
  - ב‑[table_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/table_builder.dart): פוצל `getSide` ל‑`_effectiveSource` (קדימות cell>conditional>table edge/inside) + `_convertSide` (צבע/רוחב→`BorderSide`). `_resolveCellBorder` מיישם **בעלים‑יחיד**: כל תא מצייר את ה‑top שלו (מיושב מול תחתית התא מעל דרך מערך `aboveBottom`) ואת ה‑left שלו (מול ימין השכן דרך `prevRight`); bottom/right מצוירים **רק** בגבול החיצוני של הטבלה. כך כל קצה פנימי מצויר **פעם אחת** → אין יותר קווים כפולים (כל תא צייר קודם את כל 4 הצדדים). מיזוג אנכי: ה‑leader (`drawBottom:false`) לא מפרסם קו פנימי; ה‑placeholder מפרסם את תחתית המיזוג כשהוא נגמר. **מגבלה מתועדת (§8.2 #22):** double→solid (כקודם ב‑renderer), כך שתיקו double>single הוא למעשה לפי רוחב.
  - **תובנה:** ב‑Flutter גבולות של תאים סמוכים יושבים זה‑ליד‑זה (כל border בפנים הקופסה) → קו פנימי הוכפל ל‑~2px. הבעלים‑היחיד מתקן זאת.
- **§F.3 — trHeight exact/atLeast/auto:**
  - הקורא (`docx_creator`): `DocxTableRowHeightRule{auto,atLeast,exact}` חדש ([enums.dart](../packages/docx_creator/lib/src/core/enums.dart)) + שדה `heightRule` ב‑`DocxTableRow` ([docx_table.dart](../packages/docx_creator/lib/src/ast/docx_table.dart), copyWith+buildXml round‑trip) + פענוח `w:hRule` ב‑[table_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/table_parser.dart). `buildXml` כותב כעת את ה‑hRule האמיתי (היה hard‑coded `exact`).
  - הרינדור: `exact`→`SizedBox(height)`+`ClipRect`+`OverflowBox` (גובה קבוע, תוכן חורג נחתך); `atLeast`→`ConstrainedBox(minHeight)`; `auto`→ללא אילוץ. המדידה (Paginator `_measureRow`) תואמת: `exact`→גובה קבוע, `atLeast`→רצפה, `auto`→לפי תוכן.
  - **הכרעת ברירת‑מחדל:** ה‑constructor של `DocxTableRow` מ‑default `exact` (שומר על hotfix issue #74 — גובה תוכנתי נאכף, ה‑exporter של האפליקציה לא נסוג); ה‑reader תמיד מציב את הכלל מפורשות, וממפה `w:trHeight` ללא hRule → `atLeast` (ברירת Word). בדיקת ה‑viewer לגובה‑כ‑ConstrainedBox עודכנה להעביר `atLeast` מפורש.

**בדיקות:** `docx_file_viewer`: [table_borders_test.dart](../packages/docx_file_viewer/test/table_borders_test.dart) חדש (6: strength/tie/none/wider‑wins/double>single), [table_builder_test.dart](../packages/docx_file_viewer/test/table_builder_test.dart) +2 (de‑dup: רק עמודה‑ימנית מציירת right ושורה‑תחתונה bottom; trHeight exact→SizedBox+ClipRect). **168 ירוקות** (+ אותן 4 golden חסרות‑fixture). `docx_creator`: [table_properties_test.dart](../packages/docx_creator/test/table_properties_test.dart) +1 (hRule round‑trip), hotfix #74 ירוק שוב (default exact). **382 ירוקות**. `flutter analyze` נקי בשתי החבילות; `dart format` הורץ.

**החלטות/סטיות:**
1. **ציור בעלים‑יחיד דרך `Container.border`, לא CustomPainter יחיד לטבלה.** הסיבה: CustomPainter לכל הטבלה דורש את גובהי השורות (תלויי‑תוכן דרך `IntrinsicHeight`), שאינם ידועים ל‑builder בלי measurer → RenderObject מותאם, גדול ומסוכן. הבעלים‑היחיד משיג את היעד הוויזואלי (אין כפילות + חזק‑מנצח) בעלות נמוכה. §8.2 #22.
2. **default `exact` ל‑constructor** (ולא atLeast) — נדרש כדי לא לשבור את hotfix #74 ואת ה‑exporter של האפליקציה; ה‑reader (הנתיב הקריטי לנאמנות) ממפה נכון bare→atLeast. §8.2 #23.

**נשאר ל‑F (לא חוסם — נדחה לפי התוכנית):** טבלאות צפות (`tblpPr`)→חלק H; golden (תלוי fixtures); perf טבלה 500‑שורות על profile; autofit מבוסס‑תוכן בייצור (אופציונלי, §8.2 #21).
**ל‑AI הבא:** חלק G (רשימות ומספור 1:1) — `NumberingResolver` גלובלי, גימטריה, startOverride/isLgl. או אימות‑מכשיר של D (תקציבי §2 + Word) כשיסופקו מסמכים.

### 2026-06-12 — חלק F — תיקון רגרסיה: ביטול de‑dup הגבולות ששבר טבלאות RTL
**הקשר:** המשתמש דיווח (על מסמכי עברית/RTL) שטבלאות **נחתכות בצד ימין** ושמיזוגי תאים אינם נראים מאוחדים, מיד אחרי קומיט ה‑§F.2 (de‑dup + קונפליקט).
**אבחון:** ה‑de‑dup צייר כל קצה אנכי **פעם אחת** לפי בעלות left/right **פיזית** ("צייר right רק בעמודה האחרונה ב‑grid"). ב‑Flutter `Border.left/right` פיזיים (לא directional), וב‑`Row` עם `textDirection: rtl` (כל טבלה במסמך RTL) **העמודה הראשונה ב‑grid יושבת חזותית מימין** — כך שהגבול החיצוני הימני (= ה‑right של עמודה‑0) **לא צויר**. תוצאה: גבול ימני חסר → "נחתך מימין". (החתך בתחתית בתוכן לא‑טבלאי שהמשתמש ציין הוא קליפ‑העמוד של חלק E, נפרד.)
**תיקון (בטוח, ללא RenderObject):**
- חזרה לציור גבול **פר‑תא** עם **left+right תמיד מצוירים** → גבולות חיצוניים נשמרים ב‑LTR ו‑RTL כאחד (גבולות פנימיים אנכיים מוכפלים ~2px, קוסמטי, כמו לפני הסשן).
- שמירת השיפור הבטוח‑לכיוון: `top`/`bottom` מגודרים ב‑`drawTop`/`drawBottom` כך שמיזוג אנכי לא מצייר קו פנימי אופקי (ה‑leader בלי bottom, ה‑placeholder בלי top) → המיזוג נקרא כבלוק.
- נמחקו `table_borders.dart` + הבדיקה (strongerBorder לא בשימוש כעת); הוסר מנגנון ה‑`aboveBottom`/`prevRight`.
- **מיזוג‑תוכן אמיתי (rowspan)** נשאר מגבלה ידועה: ה‑viewer מציג מיזוג אנכי כ‑leader עם תוכן + placeholder ריק מתחתיו (התוכן לא מתפרס/ממורכז על כל הגובה). תיקון מלא דורש פריסת‑grid אמיתית (Table/RenderObject) — נדחה.
**החלטה (§8.2 #22 עודכן):** קונפליקט "חזק‑מנצח" + de‑dup דורשים grid RenderObject מודע‑כיוון (start/end) + אימות חזותי מול Word; נדחו עד שתיבנה פריסת‑grid ייעודית, שתפתור גם את מיזוג‑התוכן.
**מטמון (שאלת המשתמש):** חלק F **לא** מוסיף מטמון ברמת‑מסמך — `resolveTableColumnWidths` מחושב מחדש בכל רינדור; מטמון המדידה (`TextMeasurer` LRU) נוצר **טרי לכל טעינה** וממופתח לפי זהות‑אובייקט (עם אימות `identical`), כך שמסמך טעון‑מחדש לעולם לא רואה רשומות ישנות. אם נראה פלט "תקוע" — כנראה אותו אובייקט‑מסמך/קובץ, לא מנוע הטבלאות.
**בדיקות:** הוחלפה בדיקת ה‑de‑dup ב‑2 בדיקות: גבולות left+right נשמרים בטבלת bidiVisual (RTL‑safe); מיזוג אנכי בלי קו פנימי. `docx_file_viewer`: **161 ירוקות** (+4 golden חסרות‑fixture, קדם‑קיים), analyze נקי, format הורץ. `docx_creator` לא נגעתי (382 נשארות).

### 2026-06-14 — חלק F — תיקוני נאמנות מול קבצים אמיתיים (גבולות‑מסגנון + מילוי מיזוג)
**הקשר:** המשתמש סיפק שני קבצי `.docx` אמיתיים. נפתחו כ‑ZIP ונותחו ה‑XML — שני באגים קיימים אומתו ותוקנו.
- **באג #1 — טבלה בלי גבולות + "נחתכת מימין" (קובץ "מסמך חדש"):** הטבלה משתמשת בסגנון `ae` ("Table Grid", `basedOn="a1"`) **בלי `w:tblBorders` inline** — הגבולות (single sz=4 על כל הצדדים) מוגדרים **בסגנון**. ה‑reader קרא `tblBorders` **רק** מ‑`w:tblPr` של הטבלה, והתעלם מ‑`w:tblPr/w:tblBorders` של הסגנון ([style_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/style_parser.dart)) → הטבלה רונדרה **ללא גבולות**, ובטבלת RTL (`bidiVisual`) הגבול החיצוני הימני החסר נראה כ"חיתוך מימין".
  - **תיקון:** `DocxStyle` קיבל שדה `tableBorders` ([docx_style.dart](../packages/docx_creator/lib/src/reader/docx_reader/models/docx_style.dart)) — `w:tblPr/w:tblBorders` של סגנון‑טבלה נקרא ל‑`DocxTableStyle` ומתמזג ב‑`basedOn` (ae יורש מ‑a1, מיזוג פר‑צד). [table_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/table_parser.dart): כשאין `tblBorders` inline, הטבלה **יורשת** את גבולות הסגנון (inline גובר פר‑צד). **אומת על הקובץ האמיתי**: הטבלה מקבלת כעת top/insideH/insideV = single. תיקון ה‑geometry: גריד 9016tw ≈ רוחב התוכן (9026tw) → אין חיתוך אמיתי, רק הגבול שהיה חסר.
- **באג #2 — מיזוג אנכי לא נראה מאוחד (formatting-demo):** מיזוגים מפוענחים נכון (colSpan/rowSpan), ו‑gridSpan (אופקי) עובד. אבל תא ממוזג‑אנכית מוצלל (למשל "צפון" עם `w:shd fill="D9E2F3"`) — תא‑ההמשך (placeholder) רונדר **לבן** → נראה כשני תאים, לא מאוחד.
  - **תיקון:** מערך `skipFill` ב‑[table_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/table_builder.dart) — ה‑placeholder יורש את צבע המילוי של ה‑leader → הצללה רציפה. יחד עם דיכוי הקו הפנימי (מהיומן הקודם) המיזוג נקרא כבלוק אחד.
- **נשאר מגבלה:** מיזוג‑תוכן אמיתי (התוכן ממורכז אנכית על כל גובה ה‑rowspan) עדיין דורש פריסת‑grid אמיתית; וכן הצללת `firstColumn`/`firstRow` conditional כרקע (כיום רק הצללת‑תא ישירה+banding מרונדרת כרקע).

**בדיקות:** `docx_creator`: +2 (ירושת גבולות‑סגנון + inline‑גובר) ב‑[table_properties_test.dart](../packages/docx_creator/test/table_properties_test.dart) → **384 ירוקות**, analyze נקי. `docx_file_viewer`: +1 (placeholder יורש מילוי) → **162 ירוקות** (+4 golden חסרות‑fixture), analyze נקי, format הורץ. אומת end‑to‑end על שני הקבצים שסופקו.

### 2026-06-14 — חלקים D/E + תצוגה — נאמנות עימוד מול `word_ref` (שוליים, ריווח, גובה‑שורה פר‑פונט, התאמת‑חלון)
**הקשר:** המשתמש דיווח על מספר באגי‑נאמנות מצטברים ב‑`formatting-demo.docx`, בהשוואה לרינדור‑הייחוס של Word (`.tmp_docx/word_ref/ref1‑7.png` — **7 עמודים**). חמישה תוקנו; כולם **נגזרים מנתוני המסמך**, לא קבועים מנוחשים.

- **באג #1 — "הטקסט מסתתר מתחת לפוטר" (§D.2.1/§E.1.3):** חישוב אזור‑הגוף היה **כפול** — ה‑Paginator שמר `bodyBottom = max(שוליים, מרחק‑פוטר+גובה‑פוטר)`, אך ה‑renderer מיקם את הגוף ב‑`bottom: שוליים` בלבד, התעלם מהפוטר; פוטר גבוה מהשוליים (ועוד `Divider` מוזרק שניפח אותו) צויר מעל השורה האחרונה.
  - **תיקון:** מחלקת ערך אחת [PageGeometry](../packages/docx_file_viewer/lib/src/pagination/page_model.dart) — מקור‑אמת יחיד לפריסת העמוד, מחושב פעם אחת ב‑[paginator.dart](../packages/docx_file_viewer/lib/src/pagination/paginator.dart), מאוחסן על כל `PageModel`, ונצרך מילה‑במילה ב‑[docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart) `_buildPageContainer` (גוף ב‑`top:bodyTop/bottom:bodyBottom` השמורים; גבולות‑עמוד עדיין מהשוליים הגולמיים). הוסר ה‑`Divider` המלאכותי לפני הפוטר (וורד לא מוסיף כזה; הפוטר נושא `w:pBdr` משלו). תוצאה: אזור‑אריזה ≡ אזור‑צביעה; כותרת/פוטר גבוהים דוחפים את הגוף פנימה כמו Word.
- **באג #2 — 9 עמודים במקום 7 (סחיפת שבירות):** המודד והרינדור הזריקו ריווח‑פסקה ברירת‑מחדל של **80tw** לפני+אחרי כל פסקה ללא ריווח מפורש. המסמך **חסר סגנון `Normal`** ו‑docDefaults ללא ריווח → ברירת‑המחדל של Word היא **0** (תקן OOXML); ה‑`StyleEngine` כבר מקפל docDefaults+שרשרת‑סגנונות ל‑`spacingBefore/After`, כך ש‑`null` = "המסמך מבקש 0".
  - **תיקון:** ברירת‑המחדל `?? 80 → ?? 0` בשני המקומות המסונכרנים — [text_measurer.dart](../packages/docx_file_viewer/lib/src/layout/text_measurer.dart) `_spacingBefore/_spacingAfter` ו‑[paragraph_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/paragraph_builder.dart) `_wrapWithParagraphStyle`. ספירת העמודים ירדה ל‑**7 כמו Word**.
- **באג #3 — רווח עודף בראש העמוד:** וורד מבטל את ה"רווח‑לפני" של פסקה היושבת בראש עמוד (הבלוק הראשון צמוד לשוליים העליונים); הצופן הוסיף אותו ודחף את השורה הראשונה מטה.
  - **תיקון:** ב‑[paginator.dart](../packages/docx_file_viewer/lib/src/pagination/paginator.dart) `_placeBlock` — כשהעמוד ריק (`_used==0`), הבלוק הראשון מאוחסן עם `spacingBefore:0` (אחרי כל מעבר‑עמוד שמעליו), כך שמדידה≡רינדור.
- **באג #4 — צפיפות‑שורה לא נכונה (גובה‑שורה):** ברירת‑המחדל 1.15 היא מכפיל **קבוע** שמתעלם מהפונט (נכון ל‑Arial, שגוי ל‑David/Times/Calibri). Word מרווח שורה‑בודדת לפי **מטריקות הפונט עצמו**.
  - **תיקון (מהמסמך, פר‑פונט):** פרסר [font_metrics.dart](../packages/docx_file_viewer/lib/src/font_loader/font_metrics.dart) קורא `head`(unitsPerEm)+`OS/2` ומחשב יחס גובה‑שורה לפי מטריקות **typo** (`sTypoAscender−sTypoDescender+sTypoLineGap`, מה ש‑Word משתמש גם כש‑USE_TYPO_METRICS כבוי; win כ‑fallback). [font_metrics_registry.dart](../packages/docx_file_viewer/lib/src/font_loader/font_metrics_registry.dart) — מפת `משפחה→יחס` טהורה (בטוחת‑web). [span_factory.dart](../packages/docx_file_viewer/lib/src/layout/span_factory.dart) `resolveRunStyle` משתמש ביחס הפונט לריווח‑בודד (fallback ל‑theme). אכלוס: פונטים מוטמעים ב‑[embedded_font_loader.dart](../packages/docx_file_viewer/lib/src/font_loader/embedded_font_loader.dart); פונטים מערכתיים ב‑[system_font_metrics_io.dart](../packages/docx_file_viewer/lib/src/font_loader/system_font_metrics_io.dart) (conditional‑import, desktop בלבד) שמופעל מ‑[docx_view.dart](../packages/docx_file_viewer/lib/src/docx_view.dart) על המשפחות שהמסמך מאזכר. ערכים אמיתיים: Arial 1.088, David 1.00, Times 1.06, Calibri 1.22.
- **תצוגה (שאלת המשתמש) — "הדף לא באמת דף; שינוי גודל החלון חותך טקסט":** העימוד כבר תלוי‑רוחב‑עמוד‑קבוע (שבירות שורה לא משתנות עם החלון), אך החבילה ציירה עמוד בגודלו הקבוע **בלי להקטינו לחלון** → חיתוך.
  - **תיקון:** דגל [`fitPageToWidth`](../packages/docx_file_viewer/lib/src/docx_view_config.dart) (ברירת מחדל דולק) + [`_pageSlot`](../packages/docx_file_viewer/lib/src/docx_view.dart) + פונקציה טהורה [page_fit.dart](../packages/docx_file_viewer/lib/src/utils/page_fit.dart) `pageFitScale`: כל עמוד מוקטן (זום ויזואלי) להתאמת רוחב החלון; עמוד שנכנס מוצג ב‑100%. **שבירות שורה/עמוד נשמרות** (העמוד נבנה ברוחב האמיתי ואז מוקטן). אזהרה: אם היישום מעביר `config.pageWidth` לפי גודל החלון — זה כן ישבור שורות מחדש (בעיית‑יישום).

**בדיקות:** `docx_file_viewer`: חדשים — [footer_overlap_test.dart](../packages/docx_file_viewer/test/footer_overlap_test.dart) (2: גוף לא דורס פוטר; אין Divider), [word_parity_test.dart](../packages/docx_file_viewer/test/word_parity_test.dart) (3: ריווח‑0 ביחידה, ריווח‑מפורש נשמר, אינטגרציה=7 עמודים עם פונטים אמיתיים), [font_metrics_test.dart](../packages/docx_file_viewer/test/font_metrics_test.dart) (4: registry + יישום‑יחס + פרסר Arial≈1.088 + bytes‑פגומים), [top_spacing_test.dart](../packages/docx_file_viewer/test/top_spacing_test.dart) (2: ביטול ראש‑עמוד), [page_fit_test.dart](../packages/docx_file_viewer/test/page_fit_test.dart) (3: מדיניות הקטנה‑בלבד). **176 ירוקות** (+4 golden חסרות‑fixture), `analyze` נקי, `dart format` הורץ. `docx_creator` לא נגעתי.

**גבול‑מנוע מתועד (§8.2):** בלוק היושב *בדיוק* על קצה עמוד (למשל רשימת §3.1) עלול ליפול עמוד אחד אחרת מ‑Word — Word מעגל גבהי‑שורה לרשת‑פיקסלים בגודל‑הפונט הספציפי, ומנוע הטקסט של Flutter (Skia) לא משחזר זאת. גם מטריקות typo נכונות (Arial 1.088) משאירות את הרשימה בעמ' 4 בעוד Word בעמ' 3 (סף ≤1.08). זהו **הבדל‑מנוע**, לא קירוב‑נתונים — 1:1 פיקסלי בין שני מנועי‑טקסט אינו בר‑השגה (גם דפדפנים/LibreOffice לא משיגים זאת מול Word).

**החלטות/סטיות:**
1. **גובה‑שורה פר‑פונט ולא מכפיל קבוע** — מספר‑קסם (1.05/1.15) נכון לפונט אחד בלבד; היחס נגזר ממטריקות הפונט (מהמסמך). פונטים לא‑מוכרים נופלים ל‑`theme.height` (1.15) כברירת‑מחדל בטוחה.
2. **`fitPageToWidth` ברירת‑מחדל דולק, הקטנה‑בלבד** — שיפור קפדני (חלונות צרים נכנסים במקום להיחתך), ללא שינוי בחלונות רגילים/רחבים (100%).
3. **מטריקות מערכת חוצות‑פלטפורמה** — io דרך conditional‑import (web=no‑op); משפחות לא‑סטנדרטיות (Times New Roman→times.ttf) דרך מפה קטנה + היוריסטיקה.

**נשאר מגבלה / ל‑AI הבא:** ריווח‑שורה‑מרובה (double) עדיין `M×fontSize` ולא `M×fontRatio` (פר‑פונט) — שיפור עתידי; `word_ref` כ‑golden אמיתי (השוואת‑פיקסלים מול 7 העמודים) חסום על תקציב‑סטייה סביב גבול‑המנוע; פונט Hebrew‑cs (`w:rFonts w:cs`) עדיין לא נבחר ב‑`resolveRunStyle` (נופל ל‑ascii) — רלוונטי למסמכים שמפרידים גופן עברי.

### 2026-06-15 — חלק G (רשימות ומספור 1:1) — ✅ הושלם
**בוצע:** מומש מנוע מספור גלובלי כפי שמתואר ב‑§G, עם הפרדה נקייה בין נתיב‑הייצור (מסמכי DOCX) לבין fallback (רשימות factory/בדיקות) — ללא שבירת API וללא שינוי AST.
- **§G.1 — `NumberingResolver`** ([numbering_resolver.dart](../packages/docx_file_viewer/lib/src/layout/numbering_resolver.dart), חדש): מעבר **אחד בסדר מסמך** על כל הבלוקים, **כולל רקורסיה לתאי טבלה**, עם מצב פנימי `counters[numId][ilvl]`. הפלט הוא מפת `DocxListItem→label` לפי **זהות‑אובייקט** (§2.4.1 — לא נוגע ב‑AST). פותר את שלושת הפערים של §G.1: רשימה שנקטעת בפסקה וממשיכה (אותו `numId`), אותו `numId` בשני בלוקים, ורשימה בתוך תא. **כל "story" עצמאי** (גוף+טבלאות = story אחד; כל כותרת/תחתית/variant + כל הערת שוליים/סיום = counters טריים) — כמו Word.
- **כללי §G.1.3:** עליית רמה מאפסת רמות עמוקות, מגודר ב‑`w:lvlRestart` (`null`=ברירת Word, `0`=לעולם לא מאפס, ערך=סף‑רמה); `start`/`startOverride` (כבר נאפה בקורא ל‑`DocxNumberingLevel.start`) משמש לזריעה בכל restart; compound `%1.%2.%3` מתרחב מול כל ה‑counters החיים; **`isLgl`** → כל רכיב ב‑decimal; `suff`→פער/אין‑פער; `lvlJc`→יישור מספר.
- **§G.1.4 פורמטים:** הוספו ל‑[NumberFormatter](../packages/docx_creator/lib/src/core/number_formatter.dart) `decimalZero` (ריפוד 0) ו‑`ordinal` (1st/2nd, אנגלית). הרזולבר ממפה את ה‑`numFmtRaw` הגולמי: גימטריה (`hebrew1`, כולל טו/טז), `hebrew2` (אלפבית עברי), `decimalZero`, `ordinal`, `none` (תווית ריקה), roman/alpha/decimal. `cardinalText`/`ordinalText`→decimal (§8.2 #24).
- **הקורא הורחב** (תוספת בלבד): `DocxNumberingLevel` קיבל `isLgl`/`suff`/`lvlJc`/`lvlRestart` ([docx_theme.dart](../packages/docx_creator/lib/src/reader/docx_reader/models/docx_theme.dart)) ופענוח `w:isLgl`/`w:suff`/`w:lvlJc`/`w:lvlRestart` ב‑[numbering_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/numbering_parser.dart). ה‑AST הצרכני `DocxListLevel` ([docx_list.dart](../packages/docx_creator/lib/src/ast/docx_list.dart)) קיבל `numFmtRaw`/`isLgl`/`suff`/`lvlJc`/`lvlRestart`, ו‑[block_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/block_parser.dart) משחיל אותם.
- **חיווט:** [docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart) `_initBuilders` מחשב `NumberingResolver().resolveDocument(doc)` פעם אחת פר‑מסמך ומזין ל‑`ListBuilder.numberLabels`. ב‑[list_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/list_builder.dart): כשיש מפה — התווית מהרזולבר היא הסמכות (ה‑counters המקומיים מדלגים); כשאין (רשימת factory) — ה‑fallback הקיים פועל. **שיתוף קוד:** פונקציות הפורמט (`formatNumberComponent`/`expandLvlText`/`orderedMarkerWithCascade`) חולצו לרזולבר, וה‑fallback מאציל אליהן → אין כפל לוגיקה (§2.4.6). `suff`/`lvlJc` מכובדים בפריסה (§G.2).

**בדיקות:** `docx_creator`: [numbering_level_extras_test.dart](../packages/docx_creator/test/numbering_level_extras_test.dart) חדש (3: פענוח isLgl/suff/lvlJc/lvlRestart, ברירות מחדל, numFmt גולמי) → **388 ירוקות**. `docx_file_viewer`: [numbering_resolver_test.dart](../packages/docx_file_viewer/test/numbering_resolver_test.dart) חדש (13: המשכיות חוצת‑פסקה/תא, numId עצמאי, compound, isLgl, lvlRestart=0 מול ברירת‑מחדל, גימטריה+טו/טז+תשפ"ו, hebrew2, decimalZero, none, footer‑story עצמאי, **end‑to‑end דרך הגנרטור** = 1,2,3,4 חוצה פסקה) → **203 ירוקות**. כל 15 בדיקות `nested_list_test` הקיימות ירוקות (ה‑fallback נשמר). `flutter analyze` נקי בשתי החבילות (3 info קדם‑קיימים בקבצי בדיקה של docx_creator שלא נגעתי בהם); `dart format` הורץ. 4 ה‑golden של עברית עדיין נכשלות על fixtures חסרים (קדם‑קיים מ‑A).

**החלטות/סטיות (§0.3, §8.2 #24–26):**
1. **הפרדת נתיב‑ייצור/fallback במקום מסלול יחיד.** הרזולבר מטפל רק ברשימות עם `numId` **וגם** `levels` מפוענחים (= מסמך אמיתי); רשימות factory (בדיקות/HTML/Markdown) נופלות ל‑fallback הקיים. כך אין רגרסיה בהתנהגות הקיימת, ופונקציות הפורמט משותפות לשני המסלולים (אין dual‑path בפורמוט עצמו).
2. **המשכיות דרך counters גלובליים, לא דרך `startIndex` של הקורא.** הרזולבר מתעלם מ‑`DocxList.startIndex` (שספר פריטים, באג ספירה מקונן) וסומך על counters פר‑numId — נכון יותר, ומכסה תאי טבלה.
3. **`cardinalText`/`ordinalText`→decimal** (§8.2 #24); **`lvlRestart` ביניים** = קריאת ISO לא‑מאומתת (§8.2 #25); **`suff=tab`** = פער‑קבוע מקורב (§8.2 #26).

**נשאר (נדחה, לא חוסם):** `suff=tab` כעצירת‑tab אמיתית דרך `TabEngine`; אימות golden של רשימת‑גימטריה רב‑רמתית + bullets של Wingdings (חסום על fixtures — כמו שאר החלקים); `numPicBullet` כבר נתמך (תמונת bullet כ‑`Image.memory`).
**ל‑AI הבא:** חלק H (תמונות/צורות/עטיפת טקסט) — תלוי D. או אימות‑מכשיר של D (תקציבי §2 + Word על 3 מסמכים).

### 2026-06-15 — חלק G — תיקון נאמנות: ריווח בין פריטי רשימה לפי Word (formatting-demo §3.1)
**הקשר:** המשתמש דיווח שהרשימה המקוננת ב‑`formatting-demo.docx` (§3.1) מרונדרת עם **ריווח גדול מדי בין הפריטים** לעומת Word (שמרנדר אותם צמופים). ניתוח ה‑XML של המסמך: פריטי הרשימה הם `pStyle="ListParagraph"` (basedOn=`Normal` שאינו מוגדר; docDefaults ללא ריווח; אין `contextualSpacing`) → **Word מרנדר before=0/after=0, ריווח‑שורה יחיד**.
**אבחון:** כש‑reader ממיר פסקאות‑רשימה ל‑`DocxListItem` הוא **השמיט את ריווח הפסקה**, וה‑`ListBuilder` הוסיף ריווח קבוע משלו: `Container(margin: vertical 4)` + `Padding(top:2, bottom:2)` לכל פריט. כך כל פריט קיבל ~4px עודפים שאינם במסמך.
**תיקון (מהמסמך, לא קבוע מנוחש):**
- `DocxListItem` קיבל `sourceParagraph` ([docx_list.dart](../packages/docx_creator/lib/src/ast/docx_list.dart)) — הפניה לפסקת‑המקור (שיתוף, ללא העתקה; אותו `children`). [block_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/block_parser.dart) מציב אותה.
- מודול טהור חדש [list_layout.dart](../packages/docx_file_viewer/lib/src/layout/list_layout.dart) `listItemSpacingPx`: ריווח before/after מ‑`sourceParagraph` (null→0, כמו פסקאות רגילות), עם **`w:contextualSpacing`** שמכווץ את הרווח **בין** פריטים אחים (משאיר רק מעל הראשון ומתחת לאחרון — בדיוק כמו סגנון "List Paragraph" של Word). רשימות factory (ללא מקור) שומרות פער קטן (2px).
- [list_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/list_builder.dart) צורך את ה‑helper לריווח פר‑פריט ומוותר על ה‑margin סביב רשימת DOCX. [paginator.dart](../packages/docx_file_viewer/lib/src/pagination/paginator.dart) `_measureList` משתמש **באותו** helper (מדידה≡רינדור, §G.2) → ספירת העמודים לא משתנה (formatting-demo נשאר 7 עמודים).
**בדיקות:** [list_spacing_test.dart](../packages/docx_file_viewer/test/list_spacing_test.dart) חדש (4: רשימת‑Word ללא ריווח→0/0; ריווח מפורש 240/120tw→16/8px; contextualSpacing מכווץ אמצע; factory→2/2). `docx_file_viewer`: **207 ירוקות** (+4; +4 golden חסרות‑fixture). `docx_creator`: **388 ירוקות** (sourceParagraph תוספת בלבד). analyze נקי בשתי החבילות, format הורץ. בדיקת ה‑Word‑parity (7 עמודים) נשמרה.

### 2026-06-15 — חלק G — מענה לסקירת קומיט (§6.1: fallback פר‑פריט)
**הקשר:** סקירת קומיט חיצונית של חלק G זיהתה ממצא 🟠 בינוני אמיתי (§6.1): ב‑[list_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/list_builder.dart) בחירת הענף הייתה לפי האם **כל** מפת `numberLabels` היא `null`, לא לפי נוכחות הפריט. בייצור המפה תמיד מוזנת → נתיב ה‑fallback **מת**, ופריט שהרזולבר דילג עליו (`numId==null`/`levels` ריק, או ilvl ללא `DocxListLevel`) **איבד את הסימן בשקט** (נפל ל‑bullet) במקום מספור ברירת‑מחדל. ההערה בקוד אף הבטיחה fallback פר‑פריט שלא קרה.
**תיקון:** המעבר עכשיו תמיד מריץ את מונה ה‑fallback המקומי ומחשב סימן מקומי; **תווית הרזולבר דורסת פר‑פריט** (`resolved[item] ?? localMarker`), והאיפוס של רמות עמוקות תמיד רץ (שומר על נכונות ה‑fallback). כך פריט לא‑מכוסה נופל למספור המקומי במקום להיעלם; התנהגות המקרה הנפוץ (כל הפריטים מכוסים) זהה. ההערות תוקנו.
**בדיקות:** נוספה בדיקה ([numbering_resolver_test.dart](../packages/docx_file_viewer/test/numbering_resolver_test.dart)) — רשימת `numId` שהגדרתה מכסה רק רמה 0; פריט רמה‑1 (שהרזולבר דילג) מקבל סימן fallback `a.` במקום bullet. `docx_file_viewer`: **208 ירוקות** (+4 golden חסרות‑fixture), analyze/format נקי. **§6.2** (`lvlRestart` ביניים) ו‑**§6.3** (checkbox מקדם מונה — תאורטי, checkbox נוצר רק ב‑factory ללא numId) נשארים כסטיות/מגבלות מתועדות (§8.2 #25 ו‑note).

### 2026-06-15 — חלק H (ציורים ועטיפה) — 🟨 בעבודה (סשן 1: מודל + תמונות + ליבת-עטיפה טהורה)
**הקשר:** תחילת חלק H. כמו ב‑F/G, החלק רחב ומפוצל למספר סשנים. סשן זה מספק את **התשתית הבדיקה‑עבירה והבטוחה**: השלמת המודל (H.1), רינדור הטרנספורם של התמונות (H.3), והליבה האלגוריתמית הטהורה של העטיפה (H.2) — בלי לגעת עדיין בנתיב העימוד הפ parity‑רגיש.

**בוצע:**
- **H.1 — מודל טרנספורם + עוגן צורות (docx_creator, תוספת בלבד):**
  - [docx_image.dart](../packages/docx_creator/lib/src/ast/docx_image.dart): `DocxInlineImage` קיבל `rotation` (מעלות), `flipH`/`flipV`, ו‑crop כשברים `cropLeft/Top/Right/Bottom` (+`hasCrop`). round‑trip ב‑`buildXml`: `a:xfrm` rot(×60000)/flipH/flipV ב‑`pic:spPr`, ו‑`a:srcRect` (שבר×100000) ב‑`pic:blipFill` (אפסים מושמטים).
  - [docx_drawing.dart](../packages/docx_creator/lib/src/ast/docx_drawing.dart): `DocxShape` קיבל `flipH`/`flipV` (rotation כבר היה) + round‑trip.
  - [inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart): הקורא מפענח `a:xfrm` rot/flipH/flipV + `a:srcRect` (`_parseDrawingTransform`) לתמונות **ולצורות**; וחשוב — **עוגן floating של צורות נקרא כעת** (`_parseFloatAnchor`: positionH/V, align/offset, wrap, behindDoc) — קודם `_parseShape` התעלם ממנו לחלוטין כך שצורה מעוגנת רונדרה במקום ברירת‑מחדל.
- **H.3 — רינדור טרנספורם של תמונות (docx_file_viewer):** [image_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/image_builder.dart) נכתב מחדש: מחסנית `crop → flip → rotate` (כסדר Word: srcRect, ואז flip+rot סביב המרכז). crop ממומש כ‑`ClipRect`+`OverflowBox`+`Transform.translate` (חלון על תמונה מוגדלת, נסיגה חיננית ל‑crop מנוון). **RAM (§2.4#2):** כל פענוח דרך `cacheWidth/Height = ceil(display×DPR)` (DPR מ‑`MediaQuery`), כך שביטמאפ גדול שמוצג קטן לא מפוענח ברזולוציה מקורית. גדלים ידועים מה‑AST — אין פענוח כדי לדעת גודל.
- **H.2 — ליבה טהורה (docx_file_viewer):** מודול חדש [float_layout.dart](../packages/docx_file_viewer/lib/src/layout/float_layout.dart):
  - `floatPlacementOf(inline)` — מחלץ `FloatPlacement` מ‑`DocxInlineImage`/`DocxShape` floating (נקודות→px, EMU→px ל‑dist).
  - `resolveFloatRect(p, geo, anchorTopPx, pageIsRtl)` — ממפה כל `relativeFrom` (page/margin/column/paragraph/line + topMargin/bottomMargin/leftMargin/rightMargin) × align/offset לקואורדינטות **גוף-עמוד** (origin בפינת אזור-הגוף; page‑relative יכול להיות שלילי = שוליים). flow נגזר מ‑wrap (side/fullWidth/layer).
  - `lineExtent(floats, band)` — הרוחב הזמין לשורה ברצועת‑גובה: side מקצץ מהקצה התואם, float מרכזי שומר את הצד הרחב (קירוב מלבני §8.2#1/#28), topAndBottom חוסם, layer (behindText/inFront) שקוף; dist מנפח את תיבת‑ההדרה; פחות מ‑minWidth → חסום.
  - `nextUsableY(...)` — ה‑y הבא שבו שורה "נקייה" מ‑floats חוסמים (להפלת שורה מתחת ל‑float).

**בדיקות:** `docx_creator`: [drawing_transform_test.dart](../packages/docx_creator/test/drawing_transform_test.dart) חדש (5: buildXml image rot/flip/srcRect, ללא‑טרנספורם, round‑trip image, shape flip buildXml, round‑trip של עוגן+rotation לצורה) → **393 ירוקות** (388+5), 1 דילוג, analyze נקי. `docx_file_viewer`: [float_layout_test.dart](../packages/docx_file_viewer/test/float_layout_test.dart) חדש (21: גאומטריה אופקית/אנכית פר‑relativeFrom+align/offset+RTL, lineExtent side/left+right/mid/topAndBottom/layer/min‑width/dist, nextUsableY, floatPlacementOf) + [image_transform_test.dart](../packages/docx_file_viewer/test/image_transform_test.dart) חדש (5: ללא‑טרנספורם+ResizeImage×DPR, rotation Transform, flipH matrix, crop ClipRect/OverflowBox, crop מנוון) → **234 ירוקות** (208+26), analyze נקי, `dart format` הורץ. 4 ה‑golden של עברית עדיין נכשלות על fixtures חסרים (קדם‑קיים מ‑A).

**החלטות/סטיות (§8.2):**
1. **חלוקה לסשנים:** סשן זה לא נגע ב‑Paginator/PageWidget — נתיב העימוד רגיש‑parity (formatting‑demo=7 עמודים), והעטיפה band‑based דורשת תמיכת‑רצועות במודד. הליבה הטהורה מוכנה ונבדקה כדי שהחיווט בסשן הבא יהיה הרכבה, לא אלגוריתמיקה.
2. **יחידות גודל ציור (§8.2 #27):** ה‑renderer שומר על התנהגות קיימת (נקודות כ‑px); float_layout ממיר נקודות→px (נכון). אין סתירה חיה (float_layout לא מחווט עדיין). חובה ליישב בעת חיווט העטיפה.
3. **קירוב עטיפה מלבני (§8.2 #28):** float מרכזי = "צד רחב"; floats מרובים סדרתית. tight/through≈square (§8.2 #1).

**בעיות פתוחות:** כמו שאר החלקים — golden חסומים על fixtures (`example/assets/*.docx`, `test/goldens/*`). תיבת‑טקסט עדיין נקראת כמחרוזת שטוחה (`DocxShape.text`), לא כבלוקים — re‑entry לבלוקים פנימיים בסשן הבא. VML (`w:pict`) v:rect/v:line/v:oval ו‑watermark עדיין לא; presets מורכבים נופלים למלבן (§8.2 קיים).
**ל‑AI הבא (המשך חלק H):** (1) הרחב את `PageModel` ב‑`List<FloatRect> floats` והזרם floats ב‑`Paginator` (חישוב rect לפי `_used` כ‑anchorTop; topAndBottom מוסיף לגובה; side דורש מדידת‑רצועות במודד). (2) רנדר floats ב‑`_buildPageContainer` כ‑`Positioned` בשכבות z‑order, ומחק את ה‑Row‑grouping הישן (`_generateBlockWidgets`). (3) יישב §8.2 #27 (יחידות). (4) תיבת‑טקסט re‑entry, VML, presets. **תלות D הושלמה (קוד).** או: אימות‑מכשיר של D.

### 2026-06-15 — חלק H (ציורים ועטיפה) — 🟨 בעבודה (סשן 2: חיווט floats מקצה-לקצה)
**הקשר:** המשך חלק H. סשן 1 בנה את הליבה הטהורה (`float_layout`) + רינדור טרנספורם של תמונות + מודל. סשן זה **מחווט** את ה‑floats לתוך העימוד והרינדור — בלי לשבור parity (formatting‑demo נשאר 7 עמודים) ובלי לגעת בנתיב ה‑side‑Row הקיים (כדי לא להכניס רגרסיה).

**בוצע:**
- **`PlacedFloat` + `PageModel.floats`** ([float_layout.dart](../packages/docx_file_viewer/lib/src/layout/float_layout.dart), [page_model.dart](../packages/docx_file_viewer/lib/src/pagination/page_model.dart)): `PlacedFloat{drawing, rect}` — float שנפתר על עמוד מסוים. `PageModel` נושא `List<PlacedFloat> floats` (תוספת בלבד, ברירת `const []`). (import הדדי בין float_layout ל‑page_model — חוקי ב‑Dart, analyze נקי.)
- **מדידה ללא floats inline** ([span_factory.dart](../packages/docx_file_viewer/lib/src/layout/span_factory.dart)): `buildMeasurementSpans` **מדלג** על `DocxInlineImage`/`DocxShape` floating (מוסיף `anchorSeg` בלבד לצורך bookkeeping של פיצול) במקום למדוד אותם כ‑placeholder inline. תיקון **measure≡render** אמיתי — קודם float ניפח את גובה הפסקה כאילו הוא בזרימה.
- **`Paginator` רושם floats** ([paginator.dart](../packages/docx_file_viewer/lib/src/pagination/paginator.dart)): `_recordFloats(block, anchorTop)` נקרא מ‑`_addWhole` ומנתיב‑הפיצול (head) — מחשב `resolveFloatRect` עם `anchorTop=_used` ו‑`pageIsRtl=block.isRtl`, מוסיף ל‑`_floats` (מאופס פר‑עמוד ב‑`_openPage`/`_reset`, נמסר ב‑`_closePage`). **topAndBottom שומר גובה:** `_used` נדחף ל‑`rect.exBottom` (clamp ל‑bodyHeight) → התוכן הבא מתחיל מתחת ל‑float. side/layer נרשמים בלי לשנות זרימה.
- **שכבת floats ברינדור** ([docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart)): `_buildPageFromModel` מסנן `_isLayerFloat` (topAndBottom + wrapNone/inFront), **מפשיט אותם מהגוף** (`_stripFloats`, שיתוף‑reference) כך שלא ירונדרו פעמיים, ומעביר ל‑`_buildPageContainer` שמצייר אותם כ‑`Positioned` ממוין z-order (`relativeHeight`) מעל הגוף. `_buildFloatDrawing` עוטף ב‑`SizedBox(rect)`+`FittedBox(fill)` → גודל מרונדר ≡ גאומטריה (§8.2#27 נסגר לשכבה). **behindText נשאר רקע‑עמוד** (DecorationImage, ללא שינוי); **side נשאר נתיב ה‑Row הישן** (ללא רגרסיה).

**בדיקות:** `docx_file_viewer`: [float_pagination_test.dart](../packages/docx_file_viewer/test/float_pagination_test.dart) חדש (4: מדידה מתעלמת מ‑float; side נרשם עם rect צד; topAndBottom מצמצם שורות בעמ' 1; side לא מצמצם) + [float_render_test.dart](../packages/docx_file_viewer/test/float_render_test.dart) חדש (4: topAndBottom רונדר פעם אחת+מופשט; front רונדר; behindText=רקע ללא Image; side=Row). → **242 ירוקות** (+8), analyze נקי, `dart format` הורץ. **parity נשמר: formatting-demo=7 עמודים**, וכל בדיקות ה‑Row של ה‑ParagraphBuilder ירוקות. 4 golden עברית עדיין על fixtures חסרים (קדם‑קיים). `docx_creator` לא נגעתי (393 נשארות).

**החלטות/סטיות (§8.2 #27 עודכן, #29–30 חדשים):**
1. **side נשאר ב‑Row‑legacy (§8.2 #29):** band‑reflow אמיתי דורש מודד רוחב‑משתנה פר‑שורה + RenderObject; נדחה כדי לא לסכן parity. `lineExtent`/`nextUsableY` מוכנים+נבדקים, ממתינים לחיווט.
2. **topAndBottom שמירה מ‑anchorTop (§8.2 #30):** קירוב — חפיפה אפשרית עם פסקת‑העוגן עצמה; התוכן שאחריה נדחק נכון.
3. **יישוב יחידות (§8.2 #27):** נסגר לשכבת ה‑floats דרך `FittedBox`; נותר פתוח רק לנתיב התמונה ה‑inline ול‑side‑Row.

**בעיות פתוחות:** עטיפת side אמיתית; תיבת‑טקסט (re‑entry לבלוקים — `DocxShape.text` עדיין מחרוזת שטוחה); VML (`w:pict`); presets מורכבים+gradient; מחיקת ה‑Row‑legacy אחרי שה‑side‑band יעבוד; golden (חסום על fixtures).
**ל‑AI הבא (המשך חלק H):** (1) מימוש band‑reflow ל‑side: מתודת מדידה ברוחב‑משתנה ב‑`TextMeasurer` (פר‑שורה לפי `lineExtent`) + ווידג'ט פריסה ייעודי ברינדור; אז מחיקת ה‑Row‑legacy (§8.2 #29). (2) תיבת‑טקסט: AST `DocxShape.textBlocks` + reader + re‑entry לגנרטור ברוחב התיבה. (3) VML watermark + presets. או: אימות‑מכשיר של D.

### 2026-06-15 — חלק H — מענה לסקירת קוד (סשן 2: measure≡render ל‑side + טרנספורם inline)
**הקשר:** סקירת קוד חיצונית של שינויי סשן 2 (לא‑מקומטים) זיהתה שני ממצאי נכונות אמיתיים + תיקון תלות. כולם טופלו בעץ‑העבודה (Part H עדיין 🟨 לא‑מקומט).
- **🟠 #1 — חור measure≡render נפתח מחדש ל‑side floats.** סשן 2 דילג במדידה על **כל** float ([span_factory.dart](../packages/docx_file_viewer/lib/src/layout/span_factory.dart), גובה‑אפס), אבל floats מסוג **side** (square/tight/through) עדיין מרונדרים **בזרימה** דרך `_buildFloatingLayout` (Row+IntrinsicHeight, גובה max(float,text)). כך פסקה עם side‑float גבוה נמדדה‑בחסר → קליפת‑העמוד (§E.2) חותכת/מחפיפה. **תיקון:** בנוי helper `_isOutOfFlowFloat` — מדלג (anchorSeg גובה‑אפס) **רק** ל‑fullWidth (topAndBottom, רצועה שמורה ע"י ה‑Paginator) ול‑layer (behindText/inFront); side נמדד **בזרימה** (`addImage`) כקודם, כך ש‑measure≡render לפסקת side‑float. אין כפל‑ספירה: ה‑Paginator לא שומר גובה ל‑side. הבדיקות ב‑[float_pagination_test.dart](../packages/docx_file_viewer/test/float_pagination_test.dart) שקיבעו את ההתנהגות התת‑מודדת **עודכנו** (side מוסיף גובה ומצמצם שורות; out‑of‑flow לא) — כעת מגנות מפני החיתוך.
- **🟡 #2 — טרנספורם התמונה לא הגיע למסלולי ה‑inline/Row.** crop/flip/rotation + פענוח‑ב‑DPR (תקרת RAM) היו רק ב‑`ImageBuilder` (block + שכבת floats), אך תמונת inline ([paragraph_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/paragraph_builder.dart):702) ו‑floats צד/מרכז (:307/:448) ציירו `Image.memory` גולמי → ללא crop וללא תקרת RAM. **תיקון:** ל‑`ParagraphBuilder` נוסף `ImageBuilder` עצל (תלוי‑config בלבד, ללא שינוי constructor), ושלושת המסלולים מנותבים דרך `buildInlineImage` → crop/flip/rotate + DPR בכל נתיבי התמונה. (§8.2 #27 עודכן — נותרה רק קונבנציית נקודות‑כ‑px.)
- **🔵 #3 — אילוץ Flutter מיושן.** `MediaQuery.maybeDevicePixelRatioOf` (3.10) + `Color.withValues` (3.27, בשימוש נרחב) מול הצהרת `flutter: ">=3.0.0"`. הודק ל‑`flutter: ">=3.27.0"` ו‑`sdk: ^3.6.0` — הרצפה האמיתית (Flutter 3.44 מותקן). [pubspec.yaml](../packages/docx_file_viewer/pubspec.yaml).
- **⚪ #5 — float מסובב ≠180°:** תועד כמגבלה ידועה (§8.2 #31) + הערת‑קוד ב‑`_buildFloatDrawing`; מימוש bbox‑מסובב נדחה עד fixture. **#4** (`lineExtent`/`nextUsableY` לא‑מחווטים) — פיגום מכוון לסשן ה‑band‑reflow, ללא פעולה.

**בדיקות:** `docx_file_viewer`: **243 ירוקות** (+1 — חלוקת בדיקת המדידה ל‑side/out‑of‑flow), `flutter analyze` נקי, `dart format` הורץ; parity נשמר (formatting‑demo=7 עמודים). 4 golden עברית על fixtures חסרים (קדם‑קיים). `docx_creator` לא נגעתי.
**הערה:** התיקונים הוחלו על עבודת Part H הלא‑מקומטת; הקומיט נשאר להחלטת המשתמש/סשן ה‑H.

### 2026-06-15 — חלק H (ציורים ועטיפה) — 🟨 בעבודה (סשן 3: תיבות-טקסט עם תוכן עשיר)
**הקשר:** המשך חלק H. תיבת‑טקסט (`wsp:txbx`) ב‑Word נושאת **תוכן בלוקים** אמיתי (פסקאות/טבלאות), אך עד כה `DocxShape.text` היה מחרוזת שטוחה שרונדרה כתווית ממורכזת אחת. סשן זה נותן לתיבת‑הטקסט את תוכנה האמיתי, דרך re‑entry לגנרטור.
- **AST** ([docx_drawing.dart](../packages/docx_creator/lib/src/ast/docx_drawing.dart)): `DocxShape` קיבל `textBlocks` (`List<DocxBlock>?`, תוספת בלבד). `buildXml` כותב את הבלוקים בתוך `w:txbxContent` כשהם קיימים, אחרת נסוג לפסקה‑שטוחה‑ממורכזת. (`DocxBlock` כבר זמין דרך `docx_node.dart`.)
- **הקורא** ([inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart) `_parseShape`): כש‑`wsp:txbx/w:txbxContent` קיים, **re‑entry** דרך `BlockParser(context).parseBlocks(...)` → `textBlocks`. ה‑`text` השטוח (join של `w:t`) נשמר כ‑fallback לצרכנים פשוטים. (`BlockParser(context)` עצמאי → אין מעגל בנייה; רקורסיה חסומה ע"י עומק קינון התיבות, נדיר.)
- **רינדור** ([shape_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/shape_builder.dart)): `ShapeBuilder` קיבל `textBlockBuilder` (callback). `_shapeTextContent` מרנדר את `textBlocks` (ב‑`ClipRect`+`OverflowBox` top‑aligned — תוכן גבוה נחתך לתיבה ללא overflow‑assert, כמו Word) או נסוג לתווית השטוחה. הגנרטור ([docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart)) מזין `textBlockBuilder: (blocks) => Column(_generateBlockWidgets(blocks))`.
- **איחוד נתיב צורות:** [paragraph_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/paragraph_builder.dart) `_buildInlineShape` (שצייר קופסה ריקה בלבד, dual‑path) מנותב כעת ל‑`ShapeBuilder` המשותף (מוזרק מהגנרטור), כך שתיבת‑טקסט **inline/side** מרנדרת את תוכנה (לא רק floats מרובדים), וצורות inline מקבלות preset/fill/outline אמיתיים. fallback לקופסה כשאין `ShapeBuilder` מוזרק (בדיקות standalone).

**בדיקות:** `docx_creator`: +3 ב‑[drawing_transform_test.dart](../packages/docx_creator/test/drawing_transform_test.dart) (פענוח txbxContent→textBlocks עם bold; buildXml פולט בלוקים; fallback שטוח ממורכז) → **396 ירוקות**. `docx_file_viewer`: [shape_textbox_test.dart](../packages/docx_file_viewer/test/shape_textbox_test.dart) חדש (3: תיבה inline מרנדרת תוכן end‑to‑end; fallback שטוח ללא builder; blocks גוברים על flat) → **246 ירוקות**. `flutter analyze` נקי בשתי החבילות, `dart format` הורץ; parity נשמר (formatting‑demo=7 עמודים); 4 golden עברית על fixtures חסרים (קדם‑קיים).
**נשאר (המשך H):** עטיפת side band אמיתית (§8.2 #29); VML (`w:pict`); presets מורכבים נוספים + gradient; יישוב סופי של יחידות נקודות‑כ‑px (§8.2 #27); golden (חסום על fixtures).

### 2026-06-16 — חלק H — VML (`w:pict`) image sizing
**בוצע:** תמונת VML (`w:pict`→`v:shape`/`v:imagedata`) כבר נקראה ל‑`DocxInlineImage` (ה‑blip נמצא דרך `v:imagedata r:id`), אך **גודלה ננטש ל‑100×100** כי VML אינו נושא `wp:extent`/`a:ext` — הגודל נמצא ב‑CSS `style` של ה‑`v:shape` (`width:Wpt;height:Hpt`). [inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart): כש‑extent חסר, `_vmlShapeSize` עולה אבות עד `v:shape`/`v:rect` עם `style` ומחלץ width/height ב‑points (`_cssPoints`). כך תמונת watermark/legacy מרונדרת בגודלה האמיתי. הרינדור משתמש בנתיב התמונה הקיים (`ImageBuilder`). +1 בדיקה → **docx_creator 397 ירוקות**, analyze נקי. (viewer לא נגע — שינוי קורא בלבד.)
**מגבלה מתועדת:** שכבת watermark "מאחורי הטקסט" אינה מוסקת מ‑VML `style` (z-index/position) — תמונת VML מרונדרת inline בברירת מחדל; מיפוי behindText מ‑VML דורש אותות אמינים (נדחה). presets/WordArt של VML גם נדחים.

### 2026-06-16 — חלק H (ציורים ועטיפה) — 🟨 בעבודה (סשן 4: עטיפת side אמיתית, §8.2 #29)
**הקשר:** הפריט המרכזי שנותר ב‑H — עטיפת טקסט אמיתית סביב floats מסוג side (square/tight). עד כה הטקסט נדחק לעמודה צרה ליד ה‑float לכל גובהו (`getFloatsFromParagraph`+Row), בעוד Word זורם את הטקסט ליד ה‑float **לגובהו** ואז ברוחב מלא מתחתיו. מומש כראוי, עם measure≡render דרך ליבה משותפת.
- **ליבה טהורה** [float_text_layout.dart](../packages/docx_file_viewer/lib/src/layout/float_text_layout.dart) (חדש): `layoutFloatWrap` פורס את הטקסט **שורה‑אחר‑שורה** — לכל שורה שואל את `lineExtent` (חלק H.2) מהו הרוחב הזמין ברצועת‑הגובה הנוכחית (לפי תיבות ה‑exclusion), מפרק את ה‑`InlineSpan` ל‑slice של שורה אחת (`_sliceSpan`, שומר סגנונות+recognizers), ומתקדם. גובה כולל מכבד float גבוה מהטקסט. מחזיר null על `WidgetSpan` (תמונה inline בתוך הטקסט) → נסיגה. `localSideFloatRects` ממפה את ה‑floats לתיבות פר‑פסקה (px), משותף למדידה+רינדור.
- **רינדור** [float_wrap_text.dart](../packages/docx_file_viewer/lib/src/widgets/float_wrap_text.dart) (חדש): `FloatWrapText` עוטף `LayoutBuilder`→`Stack` של שורות `Positioned(RichText)` + ה‑floats כ‑`Positioned(FittedBox)`. [paragraph_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/paragraph_builder.dart) `_buildFloatingLayout` משתמש בו (נסיגה ל‑Row כש‑`WidgetSpan` בטקסט). ה‑classification מגודר ל‑**side‑flow בלבד** (layer/fullWidth/behindText מדולגים — מטופלים בשכבת‑העמוד).
- **מדידה** [paginator.dart](../packages/docx_file_viewer/lib/src/pagination/paginator.dart) `_measureParagraph`: פסקה עם side‑float נמדדת דרך **אותו** `layoutFloatWrap` (ריווח מהמדידה הרגילה) → measure≡render. [span_factory.dart](../packages/docx_file_viewer/lib/src/layout/span_factory.dart) מדלג כעת **כל** float floating (anchorSeg גובה‑אפס) — ה‑geometry שלו מטופל ע"י ה‑wrap/שכבת‑העמוד.
- **מחיקת ה‑Row הישן:** נתיב ה‑block‑grouping ב‑[docx_widget_generator.dart](../packages/docx_file_viewer/lib/src/widget_generator/docx_widget_generator.dart) (`getFloatsFromParagraph`+`consumedFloats`+Row) **נמחק** — פסקאות (עם/בלי floats) עוברות ל‑`build` שעוטף בעצמו.

**בדיקות:** `docx_file_viewer`: [float_text_layout_test.dart](../packages/docx_file_viewer/test/float_text_layout_test.dart) חדש (8: עטיפה left/right, חזרה לרוחב מלא מתחת ל‑float, float גבוה שומר גובה, WidgetSpan→null, slices משמרים טקסט, `localSideFloatRects`); עודכנו 6 בדיקות float שקיבעו את ה‑Row הישן (float_pagination/float_render/float_alignment/rendering_fidelity/widget_test/repro_issues) להתנהגות ה‑wrap. **253 ירוקות** (+8 חדשות; 4 golden עברית על fixtures חסרים — קדם‑קיים). `flutter analyze` נקי, `dart format` הורץ. **parity נשמר: formatting‑demo=7 עמודים.** `docx_creator` לא נגע (397).
**החלטות/סטיות (§8.2 #31–32):** עטיפה **פר‑פסקה** (לא חוצת‑פסקאות — §8.2 #32); first‑line indent/strut לא בנתיב העטיפה; בחירה בפסקת‑float עוברת ל‑RichText. כולן נדירות/מתועדות.
**נשאר (המשך H):** עטיפה חוצת‑פסקאות (exclusion ברמת‑עמוד); VML watermark‑behind; presets+gradient; golden (חסום על fixtures).

### 2026-06-17 — חלק H (ציורים ועטיפה) — 🟨 בעבודה (סשן 5: צורות — presets אמיתי + gradient)
**הקשר:** רינדור הצורות היה שברירי — הכוכבים/הצורות המורכבות צוירו עם `_cos`/`_sin` **מתוצרת‑בית** (טור טיילור קטוע, שגוי לזוויות גדולות, עם קוד מת), פתרון‑הצבע שוכפל בין הבילדר ל‑painter, וה‑presets היו מוגבלים. שוכתב כראוי.
- **גיאומטריה טהורה** [shape_builder.dart](../packages/docx_file_viewer/lib/src/widget_generator/shape_builder.dart): `shapePresetPath(preset, size)` (top‑level, נבדק) מחזיר `Path` אמיתי ב‑`dart:math` ל‑triangle/rtTriangle/diamond/parallelogram/trapezoid, מצולעים רגולריים (pentagon→octagon דרך `_regularPolygon`), כוכבים (`_star`), חיצי‑בלוק (4 כיוונים + דו‑ראשיים), chevron, plus/cross, ו‑line/connector. rect/roundRect/**ellipse אמיתי** (`Radius.elliptical`) כ‑`BoxDecoration`. צורות לא‑נתמכות → מלבן מעוגל נראה (§8.2 #36).
- **איחוד צבע + flip:** `_resolveColor`/`_parseHex` במקום אחד; ה‑`_ShapePainter` מקבל צבעים/gradient מוכנים (אפס כפילות). יושם `flipH`/`flipV` (`Matrix4.diagonal3Values`) + rotation בסדר Word (קודם לא יושם flip).
- **gradient:** AST חדש `DocxGradientFill`/`DocxGradientStop`/`DocxGradientType` ([docx_drawing.dart](../packages/docx_creator/lib/src/ast/docx_drawing.dart)); הקורא ([inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart) `_parseGradientFill`) מפענח `a:gradFill` (gs pos 1/1000%, `a:lin@ang` 1/60000°, `a:path`→radial) **בתוך ה‑spPr בלבד** (לא מבלבל עם fill בתוך txbx); `buildXml` פולט `a:gradFill` (round‑trip). הרינדור: `LinearGradient`(begin/end מהזווית)/`RadialGradient`, ב‑`BoxDecoration.gradient` או shader ב‑painter.
**בדיקות:** [shape_geometry_test.dart](../packages/docx_file_viewer/test/shape_geometry_test.dart) חדש (18: גבולות edge‑touching, חברות פנים/חוץ, כוכב/משושה בתוך התיבה — מגן על תיקון ה‑trig, רינדור CustomPaint/ellipse/transform, ו‑gradient linear/radial/painted); [drawing_transform_test.dart](../packages/docx_creator/test/drawing_transform_test.dart) +4 (gradient reader linear/radial, ללא רגרסיית solid, round‑trip buildXml). **docx_creator 401 + viewer 294 ירוקות** (4 golden עברית חסרי‑fixture — קדם‑קיים). analyze נקי, `dart format` הורץ.
**החלטות/סטיות (§8.2 #36):** preset‑geometry מורכב (callouts/flowchart/heart/cloud…) → placeholder מלבן‑מעוגל; `pentagon`=5‑גון רגולרי (לא home‑plate); מילוי תבנית/תמונה לא נתמך.
**נשאר (המשך H):** עטיפה חוצת‑פסקאות (exclusion ברמת‑עמוד); VML watermark‑behind; golden (חסום על fixtures).

### 2026-06-17 — חלק H (ציורים ועטיפה) — 🟨 בעבודה (סשן 6: VML watermark‑behind)
**הקשר:** תמונת VML (`w:pict`) אין לה `wp:anchor`, ולכן נקראה **תמיד inline** — סימן‑מים ש‑Word ממקם `position:absolute` מאחורי הטקסט אבד את המיקום וה‑z‑order. הושלם המיפוי שנדחה בסשן ה‑VML הקודם.
- **`_parseVmlPlacement`** ([inline_parser.dart](../packages/docx_creator/lib/src/reader/docx_reader/parsers/inline_parser.dart)): עולה לאב ה‑`v:shape` עם ה‑`style`, מפענח כ‑map; כש‑`position:absolute` → float. `z-index<0` → `behindText` (סימן‑מים), אחרת `none` (שכבה קדמית). `mso-position-horizontal/-vertical` → hAlign/vAlign, `…-relative` → hFrom/vFrom (margin/page/text…), ו‑`margin-left/-top` (pt) → offset כשאין align. `_cssPoints` עודכן לקבל ערך שלילי (מרווחים).
- **רינדור:** התוצאה היא `DocxInlineImage` floating עם `behindText` → זורם דרך נתיב שכבת‑הרקע הקיים (כמו behindText של DrawingML), כך שהסימן‑מים מצויר מתחת לטקסט במרכז העמוד.
**בדיקות:** [drawing_transform_test.dart](../packages/docx_creator/test/drawing_transform_test.dart) +4 (watermark מרכזי→floating/behindText/align/from; absolute עם z‑index≥0→none; לא‑absolute נשאר inline; margin offsets). **docx_creator 405 ירוקות.** analyze נקי, format הורץ. viewer לא נגע.
**נשאר (המשך H):** עטיפה חוצת‑פסקאות (exclusion ברמת‑עמוד); golden (חסום על fixtures).
