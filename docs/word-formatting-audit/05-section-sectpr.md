# משימה 05 — מקטעים, עמוד, טורים, גבולות, מספור — `w:sectPr`

> **מקור:** סעיף §5 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-19

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

מקטע מגדיר את גאומטריית העמוד וכל מה שתלוי‑עמוד. הסדר של ילדי `CT_SectPr` מחייב:

### 5.1 כותרות/תחתיות והערות

| אלמנט | XML | מה עושה |
|---|---|---|
| `w:headerReference` | `<w:headerReference w:type="default" r:id="rId7"/>` | מצביע לקובץ header. `w:type`: `default` (אי‑זוגי/כל), `even` (זוגי), `first` (עמוד ראשון) |
| `w:footerReference` | אותו דבר ל‑footer | |
| `w:footnotePr` | `pos`, `numFmt`, `numStart`, `numRestart`, `numStartCount` | מאפייני הערות שוליים פר‑מקטע |
| `w:endnotePr` | אותו דבר להערות סיום | |

> שלושת ה‑variants (default/even/first) מופעלים לפי `w:titlePg` (להלן) ו‑`w:evenAndOddHeaders` ב‑settings.xml. בלי `evenAndOddHeaders`, `even` מתעלם וה‑default משמש לכל העמודים.

### 5.2 סוג מקטע, גודל ושוליים

| אלמנט | XML | מה עושה |
|---|---|---|
| `w:type` | `<w:type w:val="nextPage"/>` | תחילת המקטע: `nextPage`, `continuous` (ללא מעבר), `evenPage`, `oddPage`, `nextColumn` |
| `w:pgSz` | `<w:pgSz w:w="11906" w:h="16838" w:orient="portrait" w:code="9"/>` | גודל עמוד ב‑twips (11906×16838 = A4). `orient`: portrait/landscape. `code`=קוד גודל נייר. |
| `w:pgMar` | `<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>` | שוליים ב‑twips. `header`/`footer`=מרחק הכותרת מקצה הנייר. `gutter`=שוליים נוספים לכריכה. top/bottom יכולים להיות שליליים. |
| `w:paperSrc` | `first`, `other` | מגש נייר במדפסת (לא ויזואלי) |

### 5.3 גבולות עמוד — `w:pgBorders`

```xml
<w:pgBorders w:offsetFrom="page" w:display="allPages" w:zOrder="front">
  <w:top    w:val="single" w:sz="24" w:space="24" w:color="auto"/>
  <w:left   .../><w:bottom .../><w:right .../>
</w:pgBorders>
```

| תכונה | ערכים | מה עושה |
|---|---|---|
| `w:offsetFrom` | page / text | האם `space` נמדד מקצה הנייר או מהטקסט |
| `w:display` | allPages / firstPage / notFirstPage | באילו עמודים להציג |
| `w:zOrder` | front / back | מעל או מתחת לתוכן |
| כל גבול (top/left/bottom/right) | `CT_Border` (§2.4) + `w:id` ל‑art borders | art borders (apples, hearts...) דורשים תמונות חוזרות. ראו [§17.1](17-enums.md) |

> ב‑`offsetFrom="text"` ה‑`space` ב‑pgBorders נמדד **בנקודות** מהטקסט; ב‑`page` הוא בנקודות מקצה הנייר.

### 5.4 מספור שורות — `w:lnNumType`

| תכונה | מה עושה |
|---|---|
| `w:countBy` | מספר כל N שורות (1=כל שורה) |
| `w:start` | מספר התחלה |
| `w:distance` | מרחק המספר מהטקסט (twips) |
| `w:restart` | newPage / newSection / continuous |

### 5.5 מספור עמודים — `w:pgNumType`

| תכונה | ערכים | מה עושה |
|---|---|---|
| `w:start` | int | מספר העמוד הראשון במקטע |
| `w:fmt` | ST_NumberFormat (decimal, lowerRoman, upperLetter, hebrew1…) | פורמט מספר העמוד |
| `w:chapStyle` | int | סגנון הכותרת המגדיר מספר פרק (לפורמט "1‑1") |
| `w:chapSep` | hyphen, period, colon, emDash, enDash | מפריד בין מספר פרק למספר עמוד |

> השדה `PAGE` בכותרת מקבל את הפורמט מ‑`pgNumType/@fmt` של המקטע הנוכחי. `start` מאפס את ספירת העמודים.

### 5.6 טורים — `w:cols`

```xml
<w:cols w:num="2" w:space="708" w:equalWidth="0" w:sep="1">
  <w:col w:w="2700" w:space="360"/>
  <w:col w:w="6000"/>
</w:cols>
```

| תכונה | מה עושה |
|---|---|
| `w:num` | מספר הטורים |
| `w:space` | מרווח אחיד בין טורים (twips) — כש‑equalWidth |
| `w:equalWidth` | bool — טורים שווים (אז מתעלמים מ‑`col`) או רוחב פר‑טור |
| `w:sep` | bool — קו מפריד בין טורים |
| `w:col` | `w` (רוחב הטור) + `space` (מרווח אחריו) — כשהרוחבים אינם שווים |

> במקטע **RTL** (`w:bidi`), סדר הטורים מימין לשמאל. מעבר טור = `<w:br w:type="column"/>`.

### 5.7 שאר מאפייני המקטע

| אלמנט | ערכים | מה עושה |
|---|---|---|
| `w:vAlign` | top / center / both / bottom | **יישור אנכי של התוכן בעמוד** (both=justify אנכי) |
| `w:titlePg` | toggle | הפעל header/footer שונה לעמוד הראשון של המקטע |
| `w:bidi` | toggle | מקטע RTL (משפיע על סדר טורים וברירת כיוון) |
| `w:rtlGutter` | toggle | ה‑gutter בצד ימין |
| `w:textDirection` | lrTb, tbRl… | כיוון זרימה למקטע כולו (EA/אנכי) |
| `w:formProt` | toggle | אפשר עריכה רק בשדות טופס |
| `w:noEndnote` | toggle | אל תציג הערות סיום במקטע |
| `w:docGrid` | `type` (default/lines/linesAndChars/snapToChars), `linePitch`, `charSpace` | רשת מסמך — מספר שורות/תווים קבוע לעמוד (EA) |
| `w:printerSettings` | r:id | הפניה לנתוני מדפסת (לא ויזואלי) |
| `w:sectPrChange` | | מעקב‑שינויים על המקטע (§12) |

> **`docGrid`** משפיע על גובה שורה ב‑EA: `linePitch` קובע גובה שורה קבוע ברשת. מנוע לא‑EA יכול לרוב להתעלם, אך שים לב שהוא יכול לשנות גובה שורה גם בלטינית כש‑`type="lines"`.

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

> **היכן ממומש — ופער מבני קריטי.** למקטע יש **שני נתיבי פיענוח שונים** בקורא:
> ה‑**מקטע האחרון** (sectPr ישיר בסוף ה‑body) עובר דרך `SectionParser.parse`
> (`section_parser.dart`) — פיענוח **מלא** (טורים, גבולות, vAlign, מספור, bidi…).
> כל **מקטע ביניים** (sectPr בתוך `pPr` של פסקה) עובר דרך
> `BlockParser._parseSectionProperties` (`block_parser.dart:463-518`) — שקורא
> **רק `pgSz` + 4 שוליים**. כל שאר תכונות המקטע **אובדות בשקט** בכל מקטע שאינו האחרון
> (ראו ב.2 — "פער מבני"). הרינדור צד‑ה‑viewer: גאומטריית עמוד ב‑`paginator.dart`
> (`_computeGeometry:1418`), כותרות/טורים/vAlign/גבול‑עמוד ב‑`docx_widget_generator.dart`
> (`_buildPageContainer`), ציור גבול ב‑`page_chrome.dart` (`PageBorderPainter`),
> פורמט מספרי‑עמוד ב‑`field_substitution.dart` + `number_formatter.dart`.
> הערה נוספת: **`w:type` (סוג המעבר) אינו נקרא באף נתיב** — `breakType` תמיד נשאר
> `nextPage` בקריאת docx אמיתי (ראו פריט 6).

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:headerReference` (type: default/even/first) | כן¹ | נאמן | Word בוחר וריאנט פר‑עמוד: `default` לכל עמוד, `first` לעמוד‑שער (תלוי `titlePg`), `even` לעמודים זוגיים (תלוי `evenAndOddHeaders`). הכותרת יושבת באזור השוליים העליונים במרחק `w:header`. כאן: 3 הווריאנטים נשמרים בנפרד ונבחרים ע"י `headerFor`; ממוקמים ב‑`headerDist`. | `section_parser.dart:93-114`; בחירה `docx_section.dart:320-324`; מיקום `docx_widget_generator.dart:870,1033-1043` |
| 2 | `w:footerReference` (type: default/even/first) | כן¹ | נאמן | אותו מנגנון ל‑footer, יושב במרחק `w:footer` מתחתית הנייר. | `section_parser.dart:117-135`; `docx_section.dart:327-331`; `docx_widget_generator.dart:873,1044-1054` |
| 3 | `w:footnotePr` (pos/numFmt/numStart/numRestart/numStartCount) | חלקי | חלקי | Word: `pos` קובע מיקום ההערה (תחתית עמוד/מתחת לטקסט/סוף מקטע), `numFmt` פורמט המספר, `numStart` מספר התחלה, `numRestart` איפוס (eachPage/eachSect/continuous). כאן נקראים `pos`,`numFmt`,`numRestart` בלבד — **`numStart`/`numStartCount` לא נקראים**; `numFmt`+`numRestart` מוחלים במספור ה‑paginator, אך `pos` **אינו מוחל** (הערות תמיד בפס בתחתית הגוף). | `section_parser.dart:291-301`; שימוש `paginator.dart:505-517` |
| 4 | `w:endnotePr` | חלקי | חלקי | `numFmt` משמש למספור הערות‑סיום; `pos` נקרא אך לא מוחל — הערות‑סיום תמיד זורמות בסוף המסמך (`docEnd`); `sectEnd` סטייה מודעת. | `section_parser.dart:223`; `paginator.dart:476-484` |
| 5 | החלת variants לפי `titlePg` + `evenAndOddHeaders` | כן | נאמן | `first` מופעל רק כש‑`titlePg` דלוק; `even` מופעל רק כש‑`evenAndOddHeaders` ב‑settings.xml דלוק **וגם** מספר העמוד זוגי. כאן מחווט בדיוק כך. | `section_parser.dart:137`; הגייטינג `docx_widget_generator.dart:668` (`doc.evenAndOddHeaders && page.isEvenPage`); `docx_section.dart:320-331` |
| 6 | `w:type` (nextPage/continuous/evenPage/oddPage/nextColumn) | **לא** (בקריאה) | לא | קובע איך מתחיל המקטע: `nextPage` עמוד חדש, `continuous` ללא מעבר (המשך אותו עמוד), `evenPage`/`oddPage` קופצים לעמוד זוגי/אי‑זוגי, `nextColumn` לטור הבא. **`w:type` אינו נקרא באף נתיב** → `breakType` תמיד `nextPage`. ה‑paginator **כן** יודע לטפל ב‑continuous/even/oddPage (אם היה מסומן), אך מאחר שהקורא לא קובע — כל מקטע ב‑docx אמיתי מתחיל בעמוד חדש. `nextColumn` לא מטופל גם ב‑paginator. | חסר בקריאה (`section_parser.dart`, `block_parser.dart:463`); טיפול לא‑מנוצל `paginator.dart:606-662` |
| 7 | `w:pgSz` (`w`/`h`/`orient`/`code`) | כן | נאמן | `w`/`h` ב‑twips → גודל עמוד; מידות לא‑סטנדרטיות נשמרות מדויק כ‑`custom`. `orient`=landscape מזוהה (portrait ברירת‑מחדל). **`w:code` (קוד גודל נייר) לא נקרא** — לא ויזואלי. | `section_parser.dart:50-69`; גאומטריה `paginator.dart:1423-1426`; `effectiveWidth/Height` `docx_section.dart:407-441` |
| 8 | `w:pgMar` (top/right/bottom/left/header/footer/gutter; שליליים) | כן | נאמן~ | כל 7 התכונות נקראות. `header`/`footer`=מרחק הכותרות מהקצה (מיושם ב‑`headerDist`/`footerDist`); `gutter` מתווסף ל‑padLeft. **שוליים שליליים** (top/bottom — נפוץ בכותרות שחורגות לגוף) נקראים אך אינם מטופלים כ‑overlap אמיתי (Positioned לא תומך padding שלילי). | `section_parser.dart:72-89`; `paginator.dart:1428-1457` |
| 9 | `w:paperSrc` (first/other) | **לא** | n/a | מגש נייר במדפסת — לא ויזואלי. לא נקרא ולא רלוונטי לתצוגה. | אין |
| 10 | `w:pgBorders` — `offsetFrom` (page/text) | כן | נאמן | קובע אם `space` נמדד מקצה הנייר (`page`) או מהטקסט (`text`). מיושם בחישוב מלבן המסגרת. | `section_parser.dart:194`; `page_chrome.dart:158-169` |
| 11 | `w:pgBorders` — `display` (allPages/firstPage/notFirstPage) | כן | נאמן | באילו עמודים לצייר את המסגרת. מחווט בתנאי `drawBorder`. | `section_parser.dart:192`; `docx_widget_generator.dart:925-931` |
| 12 | `w:pgBorders` — `zOrder` (front/back) | חלקי | חלקי | Word: `back` מצייר את המסגרת **מתחת** לטקסט. כאן `zOrderBack` נקרא אך **לא מנוצל** — המסגרת תמיד הילד האחרון ב‑Stack = תמיד `front` (מעל הטקסט). | נקרא `section_parser.dart:196`; לא מנוצל `docx_widget_generator.dart:1055` |
| 13 | `w:pgBorders` — גבולות top/left/bottom/right (CT_Border) | חלקי | חלקי | `val`/`sz`/`space`/`color` נקראים (כולל `space` — בניגוד לגבול פסקה/ריצה במשימה 02). ציור: `single`/`double`/`thick` מצוירים; **`dashed`/`dotted`/`triple` → קו אחיד single**. `themeColor` של צד → נופל לצבע ברירת‑מחדל (לא נפתר ל‑chrome). | קריאה `section_parser.dart:264-287`; ציור `page_chrome.dart:182-209`; theme fallback `page_chrome.dart:11-13` |
| 14 | `w:pgBorders` — `id` ל‑art borders | **לא** | לא | 160 גבולות אמנותיים (תפוחים, לבבות…) דורשים תמונות חוזרות. `w:id` לא נקרא (`_parseSectionBorder` מתעלם) → גבולות עמוד אמנותיים לא יוצגו. | חסר `section_parser.dart:264-287` |
| 15 | `w:lnNumType` — `countBy` | **לא** (מוצג) | לא | מספור שורות בשוליים (כל N שורות). נקרא ל‑AST (`DocxLineNumbering`) אך **אינו מרונדר כלל** בצד ה‑viewer — מספרי השורות לא מוצגים. | נקרא `section_parser.dart:208`; אין רינדור |
| 16 | `w:lnNumType` — `start` | **לא** (מוצג) | לא | מספר התחלה — נקרא, לא מרונדר (כמו 15). | `section_parser.dart:209`; אין רינדור |
| 17 | `w:lnNumType` — `distance` | **לא** (מוצג) | לא | מרחק המספר מהטקסט — נקרא, לא מרונדר. | `section_parser.dart:210`; אין רינדור |
| 18 | `w:lnNumType` — `restart` (newPage/newSection/continuous) | **לא** (מוצג) | לא | מצב איפוס — נקרא, לא מרונדר. | `section_parser.dart:211`; אין רינדור |
| 19 | `w:pgNumType` — `start` (איפוס ספירה) | כן | נאמן | מאפס/קובע את מספר העמוד הראשון במקטע. מיושם: ה‑paginator מציב `_displayNumber` ל‑`start` בתחילת המקטע, וזה זורם לשדות `PAGE`. | `section_parser.dart:145`; `paginator.dart:633-635`,`654` |
| 20 | `w:pgNumType` — `fmt` (ST_NumberFormat, כולל hebrew) | כן | נאמן | פורמט מספר העמוד מוחל על `PAGE`/`NUMPAGES`/`PAGEREF` (כשהשדה ללא מתג `\*`). נתמכים decimal/upperRoman/lowerRoman/upperLetter/lowerLetter/**hebrew1**(גימטריה, כולל טו/טז)/**hebrew2**. פורמטים אחרים (decimalZero, ordinal…) → null → נופל ל‑decimal. | `section_parser.dart:142,305-324`; החלה `field_substitution.dart:57,60,73`; המרה `number_formatter.dart:14-31,115-177` |
| 21 | `w:pgNumType` — `chapStyle` | **לא** (מוצג) | לא | קידומת מספר‑פרק (פורמט "1‑1"). `chapterStyleLevel` נקרא ל‑AST אך **אין רינדור** של קידומת פרק במספרי עמוד. | נקרא `section_parser.dart:146`; אין רינדור |
| 22 | `w:pgNumType` — `chapSep` (hyphen/period/colon/emDash/enDash) | **לא** (מוצג) | לא | מפריד מספר‑פרק↔עמוד — נקרא ל‑AST, לא מרונדר (תלוי בפריט 21). | `section_parser.dart:148`; אין רינדור |
| 23 | `w:cols` — `num` | כן | נאמן | מספר טורים. נפרס, מחושב ל‑`resolveColumnWidths`, וה‑paginator מפצל תוכן לטורים (`_applyColumnLayout`). | `section_parser.dart:167`; `column_layout.dart:10-24`; `paginator.dart:197-210` |
| 24 | `w:cols` — `space` (equalWidth) | כן | נאמן | מרווח אחיד בין טורים שווי‑רוחב (twips→px ÷15). | `section_parser.dart:170`; `column_layout.dart:20-22,38-50` |
| 25 | `w:cols` — `equalWidth` | כן | נאמן | טורים שווים מול רוחב פר‑טור. ברירת‑מחדל נכונה ל‑Word: היעדר התכונה + `col` מפורשים ⇒ לא‑שווה. | `section_parser.dart:156,173-175` |
| 26 | `w:cols` — `sep` (קו מפריד) | כן | נאמן~ | קו מפריד אנכי בין טורים. מצויר כקו 1px ממורכז בפער, בגובה אזור הטורים. (עובי/צבע מקורבים — לא נשלטים מ‑Word.) | `section_parser.dart:176`; `docx_widget_generator.dart:1123-1137` |
| 27 | `w:cols` — `col` (w + space פר‑טור) | כן | נאמן | רוחב פר‑טור + מרווח אחריו (כשלא שווי‑רוחב). הרוחבים נלקחים כלשונם מ‑Word; ה‑gaps פר‑טור מכובדים. | `section_parser.dart:158-164`; `column_layout.dart:13-17,42-48` |
| 28 | סדר טורים RTL + מעבר טור (`<w:br w:type="column"/>`) | כן | נאמן | במקטע RTL (`bidi`) הסדר מתהפך — טור 0 (תוכן ראשון) מימין. מעבר טור (`w:br type="column"`) מקדם לטור הבא / לעמוד הבא בטור אחרון. | RTL `docx_widget_generator.dart:1144-1145`; מעבר טור `paginator.dart:854-878`,`178-192` |
| 29 | `w:vAlign` (top/center/both/bottom — יישור אנכי בעמוד) | כן | נאמן | יישור אנכי של הגוף באזור התוכן. top/center/bottom ע"י `Alignment`; `both` (justify אנכי) פורש מרווח בין בלוקים — אך **רק כשהתוכן נכנס** בעמוד (אחרת natural+clip). | `section_parser.dart:182-186`; `docx_widget_generator.dart:937-958`; `page_chrome.dart:36-109` (PageBody/stretch) |
| 30 | `w:titlePg` | כן | נאמן | מפעיל header/footer שונים לעמוד הראשון של המקטע. honors `w:val="false"` מפורש. | `section_parser.dart:137` (`readOnOff`); `docx_section.dart:321,328` |
| 31 | `w:bidi` (מקטע RTL) | חלקי | חלקי | משפיע על **סדר טורים** (פריט 28) ועל **צד מפריד הערות‑שוליים**. **אך** אינו קובע gutter בצד ימין (זה `rtlGutter` נפרד, פריט 32) וכיוון הפסקה מזוהה עצמאית פר‑פסקה (`paragraph_builder`), לא מהמקטע. | `section_parser.dart:217`; שימוש `docx_widget_generator.dart:1145,966` |
| 32 | `w:rtlGutter` | **לא** | לא | אמור להעביר את מרווח הכריכה לצד ימין. `rtlGutter` נקרא אך **לא מנוצל** — ה‑gutter תמיד מתווסף ל‑padLeft (שמאל), ללא קשר ל‑`rtlGutter`. | נקרא `section_parser.dart:218`; חסר ב‑`paginator.dart:1429` |
| 33 | `w:textDirection` (מקטע) | **לא** | לא | כיוון זרימה למקטע כולו (EA/אנכי, lrTb/tbRl…). **לא נקרא** ברמת המקטע (קיים `textDirection` לתא טבלה בלבד — משימה 06). | אין |
| 34 | `w:formProt` | **לא** | n/a | אפשר עריכה רק בשדות טופס — מאפיין עריכה, לא ויזואלי לתצוגה. לא נקרא. | אין |
| 35 | `w:noEndnote` | **לא** | לא | "אל תציג הערות‑סיום במקטע". לא נקרא → לא מכובד. (השפעה זניחה: הערות‑סיום נאספות לסוף המסמך בכל מקרה.) | אין |
| 36 | `w:docGrid` (type/linePitch/charSpace) | **לא** | לא | רשת מסמך EA — מספר שורות/תווים קבוע לעמוד; יכול לשנות גובה שורה (גם בלטינית כש‑`type="lines"`). **לא נקרא** → גובה שורה לא מושפע מהרשת. | אין |
| 37 | `w:printerSettings` | **לא** | n/a | הפניה לנתוני מדפסת — לא ויזואלי. לא נקרא. | אין |
| 38 | `w:sectPrChange` (revision) | **לא** | לא | מעקב‑שינויים על המקטע. לא נקרא (ראו משימה 12). | אין |

> ¹ נאמן **למקטע האחרון בלבד**. מקטע ביניים מאבד את הכותרות/תחתיות (וכל שאר תכונות המקטע) בגלל הפער המבני — ראו ב.2.

### ב.2 — פערים והוראות ל‑AI הבא

- **פער מבני: מקטעי ביניים מאבדים כמעט הכל (קריטי).** רק המקטע **האחרון** עובר פיענוח מלא (`SectionParser`). כל `sectPr` שבתוך `pPr` (כלומר כל מקטע פרט לאחרון) עובר דרך `BlockParser._parseSectionProperties` (`block_parser.dart:463-518`) שקורא **רק `pgSz` + top/right/bottom/left**. לכן בכל מסמך רב‑מקטעי, המקטעים שאינם האחרון מאבדים: כותרות/תחתיות, טורים, גבולות‑עמוד, vAlign, `pgNumType`, `lnNumType`, `bidi`, `gutter`, מרחקי header/footer, footnote/endnotePr. **המלצה:** למזג — שיקרא `_parseSectionProperties` את אותו קוד כמו `SectionParser.parse` (לחלץ ל‑helper משותף), כך ששני הנתיבים זהים.
- **`w:type` (סוג מעבר המקטע) לא נקרא (פריט 6).** `breakType` תמיד `nextPage` בקריאת docx. הוסף קריאת `sectPr/w:type` ב‑**שני** הנתיבים ומיפוי ל‑`DocxSectionBreak` (continuous/evenPage/oddPage/nextPage). ה‑paginator כבר מטפל ב‑continuous + parity (`paginator.dart:606-662`) — חסר רק שהקורא יזין אותו. שים לב: **`continuous` המוצג היום כעמוד חדש** הוא הפער הנפוץ ביותר.
- **`rtlGutter` לא מכובד (פריט 32).** ה‑gutter תמיד נוסף לשמאל (`paginator.dart:1429`). כש‑`rtlGutter` דלוק — להוסיף את ה‑gutter ל‑`padRight` במקום `padLeft`.
- **`pgBorders` — zOrder=back וסגנונות קו (פריטים 12, 13).** (א) `zOrderBack` נקרא אך המסגרת תמיד מצוירת מעל הטקסט — לצייר אותה כשכבת רקע כש‑`back`. (ב) `dashed`/`dotted`/`triple` מצוירים כ‑single אחיד — להוסיף ציור קו מקווקו/מנוקד; `themeColor` של צד לא נפתר ל‑chrome (`page_chrome.dart:11-13`).
- **גבולות אמנותיים — art borders (פריט 14).** `w:id` + `w:val` אמנותי לא נתמכים. לתעד כסטייה מודעת; אם נדרש — לטעון את תמונות ה‑art מ‑[§17.1](17-enums.md) ולחזור אותן לאורך המסגרת.
- **מספור שורות `lnNumType` לא מרונדר כלל (פריטים 15–18).** נקרא ל‑AST אך אין רינדור. אם נדרש (מסמכים משפטiים/תורניים) — לצייר מספרי שורה בשולי הגוף לפי `countBy`/`start`/`distance`/`restart`.
- **קידומת פרק במספרי עמוד (פריטים 21–22).** `chapStyle`/`chapSep` נקראים אך אין רינדור של קידומת "פרק‑עמוד". לחווט ל‑`field_substitution` (לפני מספר העמוד), בעזרת רזולוציית הסגנון של הפרק.
- **`footnotePr`/`endnotePr` — `numStart`/`numStartCount` ו‑`pos` (פריטים 3–4).** `numStart`/`numStartCount` לא נקראים; `pos` נקרא אך לא מוחל (הערות תמיד בתחתית הגוף / סוף מסמך). ראו משימה 10 לפירוט מלא של הערות.
- **`docGrid`/`textDirection` ברמת מקטע (פריטים 33, 36).** לא נקראים. רלוונטי בעיקר ל‑EA (אנכי/רשת); לזרימה לטינית/עברית רגילה ההשפעה מזערית — לתעד כסטייה מודעת.
- **`w:pgSz w:code` ו‑`paperSrc`/`printerSettings`/`formProt` (פריטים 7, 9, 34, 37).** מאפיינים לא‑ויזואליים (קוד נייר/מגש/מדפסת/הגנת טופס) — אין צורך לרינדור; לתעד כ"לא רלוונטי לתצוגה".
- **שוליים שליליים ב‑`pgMar` (פריט 8).** `top`/`bottom` שליליים (כותרת שחורגת לגוף) נקראים אך `Positioned`/padding לא תומך ערך שלילי → ייתכן חיתוך. לבחון מול קובץ Word עם header גדול.
