# סריקת נאמנות עיצוב Word — לוח ראשי והוראות

> **מהו הקובץ הזה.** זהו הקובץ הראשי של תיקיית הסריקה: הוראות ל‑AI הסורק + לוח מעקב התקדמות.
> **קבצי המשימות** (`01-…​.md` עד `17-…​.md`) נגזרים אחד‑לאחד מסעיפי מסמך הייחוס
> `WORD_FORMATTING_XML_REFERENCE.md`, ומכילים **העתקה מדויקת ומלאה** של פרטי העיצוב שבו.
>
> **חשוב:** ייתכן שמסמך הייחוס המקורי יימחק. לכן כל פרט עיצוב נשמר *בתוך* קבצי המשימות.
> **אסור לערוך את "חלק א' — הייחוס"** באף קובץ משימה — הוא העתק קפוא של המקור.

---

## מטרת הסריקה

לכל פריט עיצוב של Word (כפי שמתועד בייחוס), לקבוע **שני דברים**:

1. **האם הוא ממומש בכלל** במנוע התצוגה.
2. אם כן — **האם המשתמש רואה אותו בדיוק** כפי שהוא נראה ב‑Microsoft Word
   (נאמנות 1:1, פיקסל מול פיקסל). לשם כך יש **לחקור כיצד Word מציג** את הפריט בפועל.

אם פריט אינו ממומש, ממומש חלקית, או אינו נאמן — **רושמים זאת במפורש ל‑AI הבא**.

> שלב זה הוא **סריקה ותיעוד בלבד** — לא משנים מימוש. רק סורקים את הקוד, חוקרים את Word, ומתעדים.

---

## פרוטוקול עבודה ל‑AI הסורק

1. קרא קובץ זה (לוח + הוראות) ואת `02-units.md` (יחידות וטיפוסי ערכים) — בסיס לכל מדידה.
2. בחר את קובץ המשימה הראשון בלוח שסטטוסו ⬜.
3. קרא את **"חלק א' — הייחוס"** של המשימה. זו רשימת *כל* פריטי העיצוב לסריקה.
4. לכל פריט בטבלת **"ב.1 — סריקה פר‑פריט"**:
   - אתר במימוש (קוד) אם הפריט מטופל; מלא עמודת **"ממומש?"** (כן / חלקי / לא).
   - אם ממומש — **חקור כיצד Word מרנדר** את הפריט (יחידות, מקרי קצה, RTL), השווה למימוש,
     ומלא **"נאמן 1:1?"** + **"איך זה נראה ב‑Word (ממצאי מחקר)"**.
   - ציין **קובץ/שורה** במימוש.
5. סכם ב‑**"ב.2 — פערים והוראות ל‑AI הבא"** את כל מה שלא מטופל / לא נאמן / דורש בדיקה.
6. עדכן את **שדה הסטטוס** בראש קובץ המשימה ואת **הלוח** כאן.
7. **אל תשנה לעולם את חלק א'.**

### מקרא סטטוס

| סימן | משמעות |
|---|---|
| ⬜ | טרם נסקר |
| 🔄 | בסריקה (חלקי) |
| ✅ | נסקר במלואו — כל פריט קיבל הכרעה + הוראות ל‑AI הבא היכן שצריך |

---

## חוקי ברזל לסריקה

- **אל תחסיר פריט.** כל אלמנט/תכונה שמופיע בחלק א' חייב לקבל שורה בסריקה (ב.1).
- **Word הוא הקובע.** כשיש סתירה בין מפרט (ECMA‑376/ISO 29500) להתנהגות Word — Word מנצח, המפרט גיבוי.
- **עברית+אנגלית מעורבבות (BiDi).** כל פריט נבדק גם במצב מעורב באותה פסקה / שורה / ריצת טקסט.
- **נאמנות = פיקסל מול פיקסל.** "ממומש" לא מספיק; השאלה היא אם זה *נראה זהה* ל‑Word.
- **הסריקה היא לא קוד.** לא משנים מימוש בשלב זה — רק סורקים, חוקרים ומתעדים.

---

## לוח מעקב התקדמות

| # | קובץ משימה | נושא (סעיף בייחוס) | סטטוס | הערות |
|---|---|---|---|---|
| 01 | [01-container.md](01-container.md) | §1 מבנה המכל: חלקים, יחסים, namespaces | ✅ | איתור חלקים בנתיב קשיח; comments/embeddings/glossary לא נתמכים |
| 02 | [02-units.md](02-units.md) | §2 יחידות מידה וטיפוסי ערכים (twips, EMU, toggle, צבעים, shd, border) | ✅ | יחידות+toggle+theme נאמנים; shd val/color, border space/theme/art, beforeLines, % string — חסרים |
| 03 | [03-run-rpr.md](03-run-rpr.md) | §3 עיצוב ריצה / תו — `w:rPr` | ✅ | ליבת התו נאמנה (b/i+CS, sz/szCs, color, u, caps, strike, shd-fill, פיצול פר‑כתב, kern, spacing); position/w/fitText/em נקראים אך לא מרונדרים; smallCaps/outline/shadow/bdr מקורבים; eastAsia/rtl-flag/lang/eastAsianLayout/specVanish/mark-rPr/כל w14 חסרים |
| 04 | [04-paragraph-ppr.md](04-paragraph-ppr.md) | §4 עיצוב פסקה — `w:pPr` | ✅ + מומש | **מומש (ב.3):** numId=0 מבטל מספור, ind תלוי-כיוון ל-RTL, hanging>firstLine, דגלי פסקה יורשים מסגנון (bidi קריטי לעברית), defaultTabStop מ-settings, pBdr w:space, shd themeFill, הוסר Divider continuous, גובה פסקה ריקה. **סטיות מודעות:** framePr צף, pBdr between/bar/מיזוג, shd תבנית, decimal-tab, EA/mirrorIndents/textDirection/cnfStyle |
| 05 | [05-section-sectpr.md](05-section-sectpr.md) | §5 מקטעים, עמוד, טורים, גבולות, מספור — `w:sectPr` | ✅ + מומש | **מומש (ב.3):** פער מבני נסגר (מקטעי ביניים = פיענוח מלא), w:type→breakType (continuous!), rtlGutter, pgBorders zOrder=back + dashed/dotted/triple. **סטיות מודעות:** art borders, lnNumType רינדור, chapStyle/chapSep, docGrid/textDirection, themeColor chrome |
| 06 | [06-tables.md](06-tables.md) | §6 טבלאות — `w:tblPr` / `w:trPr` / `w:tcPr` | ✅ + מומש חלקי | גריד/gridSpan/vMerge/tblHeader חוזר/trHeight/vAlign/tcMar/bidiVisual/tblLook נאמנים; פתרון קונפליקט גבולות בין שכנים לא ממומש (קריטי RTL), dashed/dotted נעלמים + double/triple→single, autofit מקורב, cnfStyle לא נצרך לבחירת אזור, טבלה צפה גסה; hMerge/אלכסונים/banding-size/jc-שורה/hidden/revision חסרים |
| 07 | [07-styles.md](07-styles.md) | §7 סגנונות — `styles.xml` | ✅ + מומש חלקי | docDefaults/basedOn/styleId נאמנים; rPr של סגנון יורש דרך המנוע. פערים: `default="1"` לא נקרא (שם 'Normal' קשיח), pPr של סגנון מנותח חלקית (keepNext/tabs/bidi/pageBreakBefore אובדים), resolveParagraph לא מחווט, tblStylePr wholeTable+סדר‑קדימות, trPr של סגנון לא נחלץ, latentStyles לא נצרך; name/next/link/uiPriority/qFormat וכו' לא‑ויזואליים |
| 08 | [08-numbering.md](08-numbering.md) | §8 מספור ורשימות — `numbering.xml` | ✅ + מומש חלקי | מנוע מספור גלובלי stateful (פר‑numId/ilvl, חוצה בלוקים/תאים/stories), start/startOverride/lvlText‑מורכב/isLgl/lvlRestart/picBullet נאמנים, עברית hebrew1+2 נאמנה. פערים: numId=0 מרונדר תבליט שקרי (באג), numStyleLink/styleLink+lvlOverride‑מלא+lvl/pStyle לא נתמכים, הזחת רמה (ind left/hanging) לא נאמנה, suff=tab לא מיושר, rPr‑תווית חלקי (חסר color‑val/sz/b/i) |
| 09 | [09-drawing-images.md](09-drawing-images.md) | §9 ציור, תמונות, צורות, תיבות טקסט — DrawingML / VML | ✅ + מומש חלקי | תמונה inline/anchor (extent/crop/rot/flip/wrap/positionH-V/behindDoc) + צורה (preset/solid+grad fill/outline/txbx) + VML-image + AlternateContent נאמנים; חוסרים קריטיים: noFill→אפור, צורת behindDoc לא מרונדרת, @wrapText/wrapPolygon, chart/SmartArt/OLE/group (אובדן תוכן), מתאר+מסגרת תמונה, dash בצורה; effects/alpha/bodyPr/wsp:style/r:link חסרים |
| 10 | [10-inline-special.md](10-inline-special.md) | §10 תוכן inline מיוחד: שבירות, טאבים, סמלים, שדות, קישורים, סימניות, הערות, נוסחאות | ✅ + מומש חלקי | t/cr/noBreakHyphen/PAGE/NUMPAGES/SECTIONPAGES/STYLEREF/HYPERLINK/sym/סימניות+PAGEREF/הערות‑שוליים בתחתית העמוד נאמנים; br paged נאמן; פערים: **ptab נקרא אך לא מרונדר**, **ruby אובד כולל טקסט בסיס**, OMML→טקסט ליניארי בלבד, REF/SEQ/DATE/TC/XE/=formula מ‑cache סטטי, tab בלי stops=4 רווחים, סגנונות Hyperlink/FootnoteReference קשיחים, footnote @type+מפריד מותאם/pos/numStart לא ממומשים, comments מתעלמים, PAGEREF \h לא לחיץ |
| 11 | [11-sdt.md](11-sdt.md) | §11 פקדי תוכן — Structured Document Tags (SDT) | ✅ + מומש חלקי | "unwrap‑and‑forward": SDT כמכל שקוף → רינדור sdtContent כתוכן רגיל = ברירת‑המחדל הנאמנה של Word. text/richText/group/picture/docPartObj(TOC) נאמנים; comboBox/date/bibliography/citation נאמנים סטטית מ‑cache. פערים: w14:checkbox (מצב דינמי לא נקרא — מסתמך על גליף שמור), SDT ברמת שורה/תא בטבלה לא נפרק (יושמט), dataBinding/customXml לא נטען, placeholder אפור תלוי משימה 07, equation→טקסט ליניארי; alias/tag/id/lock/temporary מטא‑דאטה ללא ביטוי ויזואלי |
| 12 | [12-revisions.md](12-revisions.md) | §12 מעקב שינויים (Revisions) | ✅ + מומש חלקי | מצב "final" בלבד ומיושם נאמן: ins/moveTo מוצגים, del/moveFrom/delText מוסתרים (delText לעולם לא נקרא); *PrChange מתעלמים נכון (getElement ישיר). אין מצב "show markup" כלל (אין קו‑חוצה/צבע‑מחבר/בלונים) — author/date/id+rPrChange/pPrChange לא נקראים. פערי final: trPr/del (שורת טבלה מחוקה עדיין מוצגת) + cellIns/cellDel/cellMerge לא נקראים, moveTo בלוק בתוך תא אובד, del בתא נפתח במקום מושמט |
| 13 | [13-theme.md](13-theme.md) | §13 ערכת עיצוב — `theme1.xml` (צבעים ופונטים) | ✅ | dk/lt/accent+sysClr(lastClr)/srgbClr נאמנים, tint/shade נאמן, הפניות major*/minor* (latin/ea/cs) נאמנות. פערים: **`a:font script="Hebr"` לא נקרא (מודל ללא שדה פר-כתב — קריטי לעברית)**, hlink/folHlink נקראים אך טוקני `hyperlink/followedHyperlink` לא ממופים + קישור קשיח-כחול, `w:clrSchemeMapping` מותאם לא נקרא (מיפוי קשיח), טוקני dark1/light1 לא ממופים, `a:fmtScheme`+lumMod/shade לצורות לא מפוענחים |
| 14 | [14-settings.md](14-settings.md) | §14 הגדרות מסמך — `settings.xml` | ✅ | נקראים 4 פריטים בלבד: evenAndOddHeaders (נאמן) + footnotePr/endnotePr גלובליים (נאמן, נצרכים בפגינטור). פערים: defaultTabStop מנותח אך לא מחווט (paragraph_builder בונה const TabEngine 720), displayBackgroundShape לא נבדק (w:background מוצג תמיד→over-display), themeFontLang+clrSchemeMapping לא נקראים (קריטי עברית/§13), autoHyphenation+נלווים לא ממומשים (שבירת שורות), mirrorMargins/defaultTableStyle חסרים; compat/compatibilityMode/proofState/documentProtection/drawingGrid — סטיות מודעות |
| 15 | [15-background-watermark.md](15-background-watermark.md) | §15 רקע מסמך וסימני מים | ✅ | צבע רקע `w:color` hex נאמן + תמונת `behindText` בגוף מאחורי הטקסט; חוסרים: **סימן מים טקסטואלי `v:textpath`→נעלם (RawInline)**, סימן מים בכותרת לא מצויר מאחורי הגוף, `v:background` תקני לא מנותח (רק `rIdBgHdr` פנימי), themeColor של רקע + `displayBackgroundShape` לא נקראים, מסלול הרקע מתעלם מסיבוב/mso-position/opacity (`BoxFit.fill`, רק תמונה אחת) |
| 16 | [16-resolution-order.md](16-resolution-order.md) | §16 סדר ההחלה והעדיפות (resolution) | ✅ | ליבת ה‑resolution נאמנה: rPrDefault→pStyle(basedOn)→rStyle→ישיר עם toggle‑XOR בין‑רמתי, rStyle>pStyle, פיצול פר‑כתב (cs/szCs/bCs/iCs), tcMar>tblCellMar, גבול תא>מותנה>טבלה. **פער קריטי §16.4: קריסת טוקן `jc` בפירוק** (DocxAlign בן 4 ערכים → start/left ו‑end/right מתמזגים) ⇒ `jc=end` ו‑`jc=left` פיזי שבורים ב‑RTL. שכבות סגנון‑טבלה+סגנון‑מספור חסרות מהמנוע, resolveParagraph לא מחווט, toggle‑XOR ללא bCs/iCs/strike/vanish, golden פתוח ל‑toggle ישיר, §6.6 קונפליקט גבולות שכנים + trPr/shd לא ממומשים |
| 17 | [17-enums.md](17-enums.md) | §17 נספח: טבלאות enum מלאות | ✅ | fallback קיים כמעט תמיד; הבעיה היא over‑collapse: ST_Border 7/27+art→single (dotted/dashed נעלמים בטבלה), ST_Shd val לא נקרא (solid/pctNN/פסים), ThemeColor hyperlink/dark*/light*→null, NumberFormat לא‑לטיני (ערבי/הינדי/תאי/קירילי/CJK)→decimal (עברית נאמנה), hMerge לא נקרא; נקרא‑לא‑מנוצל: TextDirection/TextAlignment/Em/Hint‑eastAsia; אין מימוש: BrClear/TextEffect/MultiLevelType/DocGrid/View/Wrap/CombineBrackets |

---

## נספח: צ'קליסט כיסוי למנוע רינדור (סדר עבודה מומלץ)

> מועתק כלשונו מ"נספח ב'" של מסמך הייחוס. זהו סדר העבודה המומלץ למימוש — מהקריטי לפינוי.
> הוא מפנה לפריטים שמפוזרים בין קבצי המשימות; השתמש בו כדי לתעדף את הסריקה.

סדר עבודה מומלץ למימוש (מהקריטי לפינוי):

1. **בסיס טקסט:** rFonts (פר‑כתב), sz/szCs, b/i + CS, color, u, vertAlign, highlight, shd, vanish.
2. **פסקה:** jc (תלוי‑bidi), ind (כולל hanging), spacing (line+before/after), bidi, keepNext/keepLines/pageBreakBefore/widowControl, tabs+leaders.
3. **מקטע ועמוד:** pgSz, pgMar, headers/footers (3 variants + titlePg), cols, pgNumType, sectPr type, vAlign.
4. **סגנונות:** docDefaults → basedOn chain → direct, toggle XOR, rStyle, linked.
5. **מספור:** abstractNum/num, lvlText/numFmt (כולל hebrew1/2), startOverride, lvlRestart, ind מהרמה.
6. **טבלאות:** tblGrid+autofit/fixed, gridSpan/vMerge, גבולות+קונפליקט, tcMar/tblCellMar, vAlign, bidiVisual, tblHeader חוזר, cnfStyle+tblLook+tblStylePr.
7. **ציורים:** inline + anchor (positionH/V, wrap types), pic (crop/rot/flip), תיבות טקסט, behindDoc, VML/AlternateContent.
8. **inline מיוחד:** breaks (page/column/textWrapping), sym, fields (PAGE/PAGEREF/STYLEREF/TOC), hyperlinks, footnotes על העמוד, bookmarks.
9. **theme:** clrScheme+מיפוי, fontScheme (script="Hebr"), themeColor tint/shade.
10. **settings:** defaultTabStop, evenAndOddHeaders, mirrorMargins, autoHyphenation, displayBackgroundShape, compat.
11. **מתקדם/אופציונלי:** w14 effects, OMML math, SmartArt/charts, revisions markup, ruby, art page borders.

> כל פריט שלא ממומש = לתעד כ"סטייה מודעת" ב"חלק ב'" של קובץ המשימה הרלוונטי.
