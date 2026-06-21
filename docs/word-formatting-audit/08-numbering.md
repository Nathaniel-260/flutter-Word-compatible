# משימה 08 — מספור ורשימות — `numbering.xml`

> **מקור:** סעיף §8 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-21

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
| 1 | `@w:abstractNumId` | כן | נאמן | מזהה התבנית. נקרא ומשמש כמפתח מפת `_abstractNums`, ומקושר מ‑`w:num/w:abstractNumId`. ליבת המספור. | `numbering_parser.dart:37-48` (מפתח), `51-58` (קישור מ‑num) |
| 2 | `w:nsid` | **לא** | n/a | מזהה ייחוס יציב לסנכרון רשימות בין מסמכים — לא ויזואלי. לא נקרא ב‑reader (הexporter כותב ערך קבוע). אין השפעת רינדור. | אין קריאה; כתיבה בלבד `numbering_generator.dart:65,94,131` |
| 3 | `w:multiLevelType` (singleLevel/multilevel/hybridMultilevel) | **לא** | לא (כמעט‑לא‑ויזואלי) | קובע ב‑Word אם הרשימה חד‑רמתית/רב‑רמתית/היברידית; משפיע בעיקר על התנהגות UI ובחירת ברירות‑מחדל. לרינדור מסמך קיים ההתנהגות נקבעת בפועל מ‑`lvlText`+`lvlRestart`. לא נקרא. סטייה מודעת זניחה. | אין |
| 4 | `w:tmpl` | **לא** | n/a | קוד תבנית פנימי של Word (Gallery). לא ויזואלי. לא נקרא. | אין |
| 5 | `w:numStyleLink` | **לא** | **לא** | מפנה את התבנית לסגנון מספור (`type=numbering` ב‑styles.xml) — הרשימה "שואבת" את הגדרת הרמות מהסגנון. **לא נקרא**: abstractNum שמכיל `numStyleLink` במקום `w:lvl` יחזיר `levels` ריק → הרשימה תרונדר ללא הגדרות (fallback לתבליט/עשרוני ברירת‑מחדל). | אין; פירוק עוצר ב‑`numbering_parser.dart:43-47` |
| 6 | `w:styleLink` | **לא** | **לא** | מסמן ש‑abstractNum זה הוא ההגדרה של סגנון מספור (הצד השני של 5). לא נקרא; סגנונות מסוג numbering לא מחווטים למנוע (ראו משימה 07, `type=numbering` ללא השפעה). | אין |
| 7 | `w:lvl` (×9, ilvl 0–8) | כן | נאמן | כל `w:lvl` תחת abstractNum מנותח ל‑`DocxNumberingLevel` ונאסף ל‑`levels`. אין הגבלת מספר; הצרכן מצמצם ל‑0–8 (`maxLevels=9`). | `numbering_parser.dart:43-47,126-239`; clamp `numbering_resolver.dart:93` + `docx_list.dart:238` |
| 8 | `@w:ilvl` | כן | נאמן | מזהה הרמה — נקרא ל‑`level`, ומחובר ל‑`numPr/ilvl` של הפסקה דרך `levelFor(level)`. פסקה ללא ilvl → רמה 0. | פירוק רמה `numbering_parser.dart:127`; פסקה `docx_style.dart:390,395-397`; שיוך `block_parser.dart:323` |
| 9 | `@w:tplc` | **לא** | n/a | קוד תבנית פר‑רמה (Gallery). לא ויזואלי. לא נקרא. | אין |
| 10 | `@w:tentative` | **לא** | לא (כמעט‑לא‑ויזואלי) | רמה "זמנית" ש‑Word עשוי להחליף; ב‑hybridMultilevel רמות tentative קיימות אך לא "בבעלות" המסמך. לרינדור פסיבי אין הבדל נראה. לא נקרא. | אין |
| 11 | `w:start` (ערך התחלה) | כן | נאמן | ערך ההתחלה של הרמה. נקרא (ברירת‑מחדל 1), נשמר ב‑`DocxListLevel.start`, וזורע את המונה בהופעה ראשונה/לאחר restart. גם דריסה דרך `startOverride` ממוזגת לכאן. | `numbering_parser.dart:133-135`; זריעה `numbering_resolver.dart:101`,`list_builder.dart:139-143` |
| 12 | `w:numFmt` (ST_NumberFormat, כולל bullet/none/hebrew1/2) | חלקי | חלקי | נתמכים: decimal, decimalZero, upper/lowerRoman, upper/lowerLetter(=Alpha), **hebrew1 (גימטריה)**, **hebrew2 (אלפבית עברי)**, ordinal (אנגלי), none(=ריק), bullet. `cardinalText`/`ordinalText` → נופלים ל‑decimal. **חסרים** (→decimal): כל המוקפים (`decimalEnclosedCircle/Paren/Fullstop` ①/(1)/1.), `chicago` (סמלי הערה *,†,‡), aiueo/iroha/chinese/japanese/korean/arabicAbjad/arabicAlpha/russian וכו'. עבור עברית (מוקד הפרויקט) — נאמן. | `_mapNumFmt` `block_parser.dart:384-404`; פורמט גולמי `numbering_resolver.dart:201-253`; עברית `number_formatter.dart:115-177` |
| 13 | `w:lvlRestart` | חלקי | נאמן~ | נקרא ל‑`lvlRestart`. במנוע הגלובלי (`NumberingResolver`) ממומש מלא: null=אפס בכל התקדמות רמה נמוכה‑יותר, 0=לעולם לא, r=אפס רק כשרמה `< r-1` מתקדמת. **אך מסלול ה‑fallback המקומי** ב‑list_builder מוחק תמיד רמות עמוקות ומתעלם מ‑lvlRestart. רוב הרשימות עוברות במנוע הגלובלי, אז נאמן בפועל. | מנוע `numbering_resolver.dart:117-124`; fallback מתעלם `list_builder.dart:108-110` |
| 14 | `w:pStyle` (קישור רמה לסגנון) | **לא** | **לא** | קושר רמת מספור לסגנון פסקה (Word: פסקה בסגנון "Heading 2" מקבלת אוטומטית את רמה 1 של רשימת הכותרות). **לא נקרא**. תוצאה: מסמכים שמסתמכים על מספור‑דרך‑סגנון‑כותרת (ללא `numPr` ישיר בפסקה) לא יקבלו מספר אם הקישור הוא רק מצד ה‑lvl. (מספור שמגיע מ‑`numPr` *בתוך* הסגנון כן עובד — ראו פריט 24.) | אין |
| 15 | `w:isLgl` (מספור legal — כל הרמות עשרוני) | כן | נאמן | נקרא ל‑bool, ומוחל בהרחבת `lvlText`: כשפעיל כל `%n` מרונדר עשרוני בלי קשר לפורמט הרמה המקורית (1.1.1 במקום I.A.1). תואם Word. | קריאה `numbering_parser.dart:139`; החלה `numbering_resolver.dart:182-183` |
| 16 | `w:suff` (tab/space/nothing) | חלקי | **לא** | נקרא; אך מתורגם לפער קבוע: `nothing`→0px, כל השאר→4px. **לא נאמן:** ב‑Word `tab` מיישר את תחילת הטקסט ל‑tab‑stop (בד"כ מיקום ה‑hanging) כך שכל הטקסט מתחיל באותו X; כאן זה רק רווח 4px אחרי תיבת marker ברוחב‑מינ' 24px — שתי הרמות עלולות להתחיל ב‑X שונה. `space` ו‑`tab` מטופלים זהה. | קריאה `numbering_parser.dart:140`; פער `list_builder.dart:208` |
| 17 | `w:lvlText` (תבנית %1–%9) | כן | נאמן~ | נקרא ל‑`lvlText`. תבנית מורכבת (`%1.%2.%3.`) מורחבת מול מוני האבות (`expandLvlText`) עם הפורמט של כל רמה — משחזר מספור רב‑רמתי/legal. תווי קבע בתבנית נשמרים. **קצה:** הרגקס `%(\d)` תומך ב‑%1–%9 בלבד (תקין, Word מוגבל ל‑9); תו `%` ספרותי (נדיר, `%%`) לא נתמך. | `numbering_resolver.dart:139-191` (גם `list_builder.dart:152-164`) |
| 18 | `w:lvlPicBulletId` | כן | נאמן~ | נקרא; נפתר דרך `numPicBullet`→rId→מדיה ל‑bytes, ומאוחסן כ‑`picBulletImage`→`imageBulletBytes`. מרונדר כ‑`Image.memory` בגודל קבוע 12×12px. **קצה נאמנות:** הגודל קשיח 12px ואינו מתאים לגובת הטקסט/לגודל שב‑rPr. | קריאה+פתרון `numbering_parser.dart:195-217`; רינדור `list_builder.dart:269-275` |
| 19 | `w:legacy` (legacy/legacySpace/legacyIndent) | **לא** | לא | התנהגות מספור ישנה (Word 6/95) — הזחות/ריווח legacy. נדיר במסמכים מודרניים. לא נקרא; ההזחה תחושב מ‑`ind` הרגיל. סטייה מודעת זניחה. | אין |
| 20 | `w:lvlJc` (יישור תווית) | חלקי | חלקי | נקרא; ממופה ל‑`TextAlign` של ה‑marker בתוך תיבת minWidth:24 (center/start/end; ברירת‑מחדל end ל‑RTL). **לא נאמן מלא:** ב‑Word `lvlJc` מיישר את ה‑marker יחסית לנקודת ההזחה (right=המספר *מסתיים* בנקודת ההזחה — קריטי ל‑RTL ולמספרים ארוכים), ולא רק יישור‑טקסט בתוך תיבה ברוחב מינימלי. | קריאה `numbering_parser.dart:141`; יישור `list_builder.dart:201-205,292` |
| 21 | `w:pPr` של הרמה (בעיקר `ind` — הזחה) | חלקי | **לא** | מ‑`w:pPr/w:ind` של הרמה נקראים **רק** `left` ו‑`hanging` (לא `right`/`firstLine`/`start`/`end`). וגם אלה לא מיושמים נאמנה: list_builder מתעלם מ‑`left` המוחלט ומחשב `16px + level×clamp(left/15,16,48)` — כלומר רמה 0 תמיד 16px, וההזחה היא "פר‑רמה" כפול level במקום הערך המוחלט של Word. `hanging` נשמר אך **לא משמש** למיקום ה‑marker (פריסת marker↔טקסט קבועה ב‑minWidth:24). שאר תוכן ה‑pPr של הרמה (jc/spacing/tabs) לא נקרא. | קריאה `numbering_parser.dart:148-155`; הזחה שגויה `list_builder.dart:191-194` |
| 22 | `w:rPr` של התווית (גופן/גודל של מספר/תבליט) | חלקי | **לא** | מ‑rPr של הרמה נקראים **רק**: `rFonts` (font לתבליט בלבד; ל‑`asciiTheme`/`hAnsiTheme`→themeFont), ו‑`color` **themeColor/tint/shade בלבד**. **לא נקראים:** `color w:val` (צבע מפורש — תבליט/מספר אדום יאבד), `sz` (גודל התווית), `b`/`i` (מודגש/נטוי), פונט המספר עבור רמות ממוספרות (רק תבליט מקבל font). התוצאה: marker מקבל את גודל גוף הטקסט וצבע שחור כברירת‑מחדל אלא אם themeColor/themeFont הוגדרו. | קריאה חלקית `numbering_parser.dart:166-186`; markerStyle `list_builder.dart:233-265` |
| 23 | מיפוי תו תבליט לפונט הנכון (Symbol/Wingdings) | חלקי | חלקי | שם הפונט (`rFonts/ascii`) נשמר כ‑`bulletFont` ומועבר כ‑`fontFamily` ל‑`Text` של ה‑marker. **תלות:** הרינדור נאמן רק אם פונט Symbol/Wingdings זמין באפליקציה ותו ה‑PUA (למשל ``) קיים בו; אין מיפוי‑גיבוי לתו Unicode מקביל (• U+2022) כשהפונט חסר → עלול להופיע tofu/ריבוע. | `numbering_parser.dart:169-174,188-190`; `list_builder.dart:259-260,287` |
| 24 | `@w:numId` (`w:num`) | כן | נאמן | מזהה המופע. נקרא ל‑`_numberings`, וזה ה‑numId שאליו `numPr/numId` של הפסקה מפנה (כולל כש‑numId מגיע מ‑pPr של **סגנון** — ממוזג ב‑`merge` Style<Direct). | `numbering_parser.dart:51-79`; קישור פסקה `docx_style.dart:392-393,216`; שימוש `block_parser.dart:93,290` |
| 25 | `w:abstractNumId` (מ‑num לתבנית) | כן | נאמן | מקשר מופע לתבנית; ה‑levels של ה‑abstract מועתקים ל‑`DocxNumberingDef`. אם ה‑abstract חסר → `levels` ריק (ראו 5). | `numbering_parser.dart:55-78` |
| 26 | `w:lvlOverride` — `startOverride` | כן | נאמן | נקרא; ממוזג כ‑`copyWith(start:)` על עותק רמת ה‑abstract, כך ש‑numId שונה עם abstract זהה יכול להתחיל ממספר אחר ("התחל מחדש" מול "המשך"). | `numbering_parser.dart:63-72,113-124` |
| 27 | `w:lvlOverride` — `w:lvl` מלא (החלפת רמה) | **לא** | **לא** | דריסה שמחליפה הגדרת רמה שלמה (פורמט/lvlText/ind) למופע ספציפי — **לא נתמכת**: `_parseStartOverrides` קורא רק `w:startOverride`, ומתעלם מ‑`w:lvl` שבתוך `w:lvlOverride`. מסמך ששינה פורמט רמה לרשימה אחת בלבד יקבל את פורמט ה‑abstract המקורי. | קורא רק startOverride `numbering_parser.dart:113-124` |
| 28 | `w:numPicBullet` (תבליט תמונה VML) | כן | נאמן~ | מעבר ראשון פורס `w:numPicBullet`→`w:pict`→`v:shape`→`v:imagedata[@r:id]`, נפתר למדיה ומרונדר כתמונה (ראו 18). **קצה:** רק נתיב ה‑VML הקלאסי נתמך; גודל 12×12px קשיח. | פירוק `numbering_parser.dart:87-109`; רינדור `list_builder.dart:269-275` |
| 29 | חישוב מספור **stateful גלובלי** (מונה פר‑numId/ilvl) | כן | נאמן | `NumberingResolver` עושה מעבר אחד בסדר‑מסמך, שומר מונה פר‑(numId, ilvl) **חוצה גבולות `DocxList`** (פסקאות מפסיקות, אותו numId בשני מקומות, רשימה בתוך תא טבלה — נכנס לרקורסיה לתאים). כל "story" (גוף, כל כותרת/תחתית, הערות שוליים/סיום) ממוספר עצמאית — תואם Word. | `numbering_resolver.dart:31-110`; חיווט `docx_widget_generator.dart:170` |
| 30 | `lvlRestart` בעת חזרה מרמה עמוקה | כן | נאמן | פריט רדוד מאפס רמות עמוקות יותר (ברירת‑מחדל Word), בכפוף ל‑`lvlRestart` של כל רמה עמוקה (ראו 13). ממומש ב‑`_restartDeeperLevels`. | `numbering_resolver.dart:108,117-124` |
| 31 | `numId="0"` שובר רצף | **לא** | **לא (באג)** | ב‑Word `numId=0` מבטל מספור (פסקה ללא marker, בד"כ ביטול מספור שמגיע מסגנון). **כאן:** `block_parser` בודק `numId != null` בלבד — אז 0 מטופל כפריט רשימה אמיתי; `parsedNumberings[0]` חסר → `levels` ריק → `_isOrderedList` מחזיר false → **מרונדר תבליט שקרי** במקום פסקה רגילה. גם מקבץ פסקאות numId=0 סמוכות לרשימה אחת. | באג `block_parser.dart:93`; ראו גם `numbering_resolver.dart:89` |
| 32 | `isLgl` כופה `%n` עשרוני | כן | נאמן | זהה לפריט 15: בהרחבת `lvlText`, כש‑`isLgl` פעיל כל רכיב מרונדר ב‑`value.toString()` עשרוני. | `numbering_resolver.dart:182-183` |

### ב.2 — פערים והוראות ל‑AI הבא

- **`numId="0"` מרונדר כתבליט שקרי במקום לבטל מספור (פריט 31, באג).** `block_parser.dart:93` מקבץ כל פסקה עם `numId != null` לרשימה — כולל `numId=0`, שמשמעותו ב‑Word "אין מספור". התוצאה: פסקה כזו (וכל רצף של פסקאות numId=0 סמוכות) מקבלת תבליט ברירת‑מחדל ומאוחדת לרשימה. **המלצה:** ב‑`block_parser` להתייחס ל‑`numId==0` כפסקה רגילה (להריץ `flushPendingList()` ולהוסיף כ‑`DocxParagraph`), לא כפריט רשימה. זה גם מבטל מספור שמגיע מסגנון (Word: numId=0 ישיר דורס numId של הסגנון).
- **`numStyleLink`/`styleLink` — רשימות שמוגדרות דרך סגנון מספור לא מקבלות רמות (פריטים 5–6, קריטי לחלק מהמסמכים).** `abstractNum` שמכיל `numStyleLink` במקום `w:lvl` מחזיר `levels` ריק → הרשימה מאבדת פורמט/lvlText/הזחה. **המלצה:** ב‑`numbering_parser`, כשל‑abstractNum אין `w:lvl` אך יש `numStyleLink` — לפתור את ה‑styleId (סגנון `type="numbering"` ב‑styles.xml), למצוא דרך ה‑`w:numPr` שלו את ה‑abstractNum האמיתי (זה שמסומן `styleLink`), ולשאוב ממנו את הרמות. דורש חיווט בין `style_parser` ל‑`numbering_parser`.
- **`w:lvlOverride` עם `w:lvl` מלא לא נתמך (פריט 27).** `_parseStartOverrides` (`numbering_parser.dart:113-124`) קורא רק `startOverride`; דריסת הגדרת רמה שלמה למופע מסוים נופלת לפורמט ה‑abstract. **המלצה:** להרחיב את הפונקציה כך שתזהה `w:lvl` בתוך `w:lvlOverride` ותבנה ממנו `DocxNumberingLevel` שדורס את רמת ה‑abstract (כמו `_parseLevel`), לא רק `start`.
- **הזחת רמה (`pPr/ind`) לא נאמנה — ההזחה המוחלטת מוחלפת בנוסחה פר‑רמה (פריט 21, מרכזי לפיקסל).** `list_builder.dart:191-194` מחשב `16 + level×clamp(left/15,16,48)` ומתעלם מ‑`left` המוחלט של הרמה ומ‑`hanging` למיקום ה‑marker. ב‑Word מיקום ה‑marker וטקסט הפסקה נקבעים מ‑`left` (תחילת הטקסט) ו‑`hanging` (כמה ה‑marker יוצא שמאלה/ימינה ממנו). **המלצה:** להשתמש ב‑`indentLeft` המוחלט (twips→px ב‑÷15) כריפוד ההתחלתי, וב‑`hanging` כרוחב תיבת ה‑marker (במקום minWidth:24 קבוע), עם שיקוף RTL. גם לקרוא `right`/`firstLine`/`start`/`end` מ‑`ind` של הרמה.
- **`w:suff` — tab לא מיושר ל‑tab‑stop (פריט 16).** רק `nothing` מטופל; `tab`/`space` שניהם = פער 4px. **המלצה:** עבור `tab` (ברירת‑המחדל) ליישר את תחילת הטקסט למיקום ה‑`hanging`/tab‑stop כך שכל הפריטים מתחילים באותו X; עבור `space` להשתמש ברווח בודד. תלוי בתיקון פריט 21 (מודל ההזחה).
- **`w:rPr` של התווית — חסרים `color w:val`, `sz`, `b`/`i`, ופונט מספר (פריט 22).** כיום נקראים רק font‑של‑תבליט, themeFont, ו‑themeColor. **המלצה:** להרחיב את `_parseLevel` (`numbering_parser.dart:166-186`) לקרוא צבע מפורש, גודל ומשקל/נטוי לתווית, ולהחיל אותם ב‑`markerStyle` (`list_builder.dart:251`). גם לקרוא `rFonts/ascii` עבור רמות *ממוספרות* (לא רק תבליט) כדי שהמספר יקבל את גופן התווית.
- **`w:lvlJc` — יישור יחסי לנקודת ההזחה, לא יישור‑טקסט בתיבה (פריט 20).** קריטי במיוחד ל‑`right`/RTL ולמספרים ארוכים (גימטריה/Roman). **המלצה:** לאחר תיקון מודל ההזחה, למקם את ה‑marker כך ש‑`right`=מסתיים בנקודת ההזחה, `left`=מתחיל בה, `center`=ממורכז סביבה.
- **`w:pStyle` ברמה (מספור‑דרך‑סגנון‑כותרת) לא נקרא (פריט 14).** מסמכים שבהם הכותרות ממוספרות רק דרך קישור lvl→pStyle (ללא `numPr` בפסקה) לא יקבלו מספר. **המלצה:** לבנות מפה `pStyle → (numId, ilvl)` מתוך הרמות, ובזמן פירוק פסקה — אם אין `numPr` ישיר/בסגנון אך ה‑pStyle מופיע במפה, להזריק את ה‑numId/ilvl. נדיר במסמכי Word רגילים, נפוץ במספור‑כותרות אקדמי.
- **fallback מקומי ב‑list_builder מתעלם מ‑`lvlRestart` (פריט 13).** רק כשהמנוע הגלובלי (§G) לא כיסה פריט — נדיר. **לתעד כסטייה זניחה**; אם המנוע הגלובלי תמיד רץ (כפי שמחווט ב‑`docx_widget_generator.dart:170`), אין השפעה בפועל.
- **פורמטי `numFmt` חסרים (פריט 12).** מוקפים (`decimalEnclosedCircle/Paren/Fullstop`), `chicago` (סמלי הערת‑שוליים *,†,‡ — רלוונטי למשימה 10), ו‑CJK/ערבית/רוסית → כולם נופלים ל‑decimal. **לתעד כסטייה מודעת**; להוסיף ב‑`number_formatter.dart`+`formatNumberComponent` לפי הצורך. **עברית (hebrew1/2) נאמנה** — מוקד הפרויקט מכוסה.
- **גודל תבליט‑תמונה קשיח 12×12px (פריטים 18, 28).** אינו מתאים לגובה הטקסט/גודל rPr. לתעד; להתאים לגובת הגופן של הפריט.
- **מאפיינים לא‑ויזואליים (פריטים 2, 4, 9, 10, 19).** `nsid`/`tmpl`/`tplc`/`tentative`/`legacy` — אין צורך ברינדור; לתעד כ"לא רלוונטי לתצוגה". `multiLevelType` (פריט 3) כמעט‑לא‑ויזואלי לרינדור פסיבי.
