# משימה 17 — נספח: טבלאות enum מלאות

> **מקור:** סעיף §17 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-21
>
> 💡 הסריקה כאן: לכל enum — האם כל ערכיו ממופים נכון (כולל fallback סביר לערך לא מוכר),
> והאם כל ערך נראה ב‑Word כפי שהמנוע מציג אותו.

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

רשימות מלאות לכל ה‑enums החשובים. אסור למנוע "ליפול" על ערך לא מוכר — תמיד fallback סביר (לרוב `single`/`decimal`/`auto`).

### 17.1 `ST_Border` — סגנונות גבול (מלא)

**קווים בסיסיים (לרינדור מלא):**
`nil`, `none`, `single`, `thick`, `double`, `dotted`, `dashed`, `dotDash`, `dotDotDash`, `triple`, `thinThickSmallGap`, `thickThinSmallGap`, `thinThickThinSmallGap`, `thinThickMediumGap`, `thickThinMediumGap`, `thinThickThinMediumGap`, `thinThickLargeGap`, `thickThinLargeGap`, `thinThickThinLargeGap`, `wave`, `doubleWave`, `dashSmallGap`, `dashDotStroked`, `threeDEmboss`, `threeDEngrave`, `outset`, `inset`.

**גבולות אמנותיים (art borders — לגבולות עמוד; דורשים אריחי תמונה חוזרים):**
`apples`, `archedScallops`, `babyPacifier`, `babyRattle`, `balloons3Colors`, `balloonsHotAir`, `basicBlackDashes`, `basicBlackDots`, `basicBlackSquares`, `basicThinLines`, `basicWhiteDashes`, `basicWhiteDots`, `basicWhiteSquares`, `basicWideInline`, `basicWideMidline`, `basicWideOutline`, `bats`, `birds`, `birdsFlight`, `cabins`, `cakeSlice`, `candyCorn`, `celticKnotwork`, `certificateBanner`, `chainLink`, `champagneBottle`, `checkedBarBlack`, `checkedBarColor`, `checkered`, `christmasTree`, `circlesLines`, `circlesRectangles`, `classicalWave`, `clocks`, `compass`, `confetti`, `confettiGrays`, `confettiOutline`, `confettiStreamers`, `confettiWhite`, `cornerTriangles`, `couponCutoutDashes`, `couponCutoutDots`, `crazyMaze`, `creaturesButterfly`, `creaturesFish`, `creaturesInsects`, `creaturesLadyBug`, `crossStitch`, `cup`, `decoArch`, `decoArchColor`, `decoBlocks`, `diamondsGray`, `doubleD`, `doubleDiamonds`, `earth1`, `earth2`, `eclipsingSquares1`, `eclipsingSquares2`, `eggsBlack`, `fans`, `film`, `firecrackers`, `flowersBlockPrint`, `flowersDaisies`, `flowersModern1`, `flowersModern2`, `flowersPansy`, `flowersRedRose`, `flowersRoses`, `flowersTeacup`, `flowersTiny`, `gems`, `gingerbreadMan`, `gradient`, `handmade1`, `handmade2`, `heartBalloon`, `heartGray`, `hearts`, `heebieJeebies`, `holly`, `houseFunky`, `hypnotic`, `iceCreamCones`, `lightBulb`, `lightning1`, `lightning2`, `mapPins`, `mapleLeaf`, `mapleMuffins`, `marquee`, `marqueeToothed`, `moons`, `mosaic`, `musicNotes`, `northwest`, `ovals`, `packages`, `palmsBlack`, `palmsColor`, `paperClips`, `papyrus`, `partyFavor`, `partyGlass`, `pencils`, `people`, `peopleWaving`, `peopleHats`, `poinsettias`, `postageStamp`, `pumpkin1`, `pushPinNote2`, `pushPinNote1`, `pyramids`, `pyramidsAbove`, `quadrants`, `rings`, `safari`, `sawtooth`, `sawtoothGray`, `scaredCat`, `seattle`, `shadowedSquares`, `sharksTeeth`, `shorebirdTracks`, `skyrocket`, `snowflakeFancy`, `snowflakes`, `sombrero`, `southwest`, `stars`, `starsTop`, `stars3d`, `starsBlack`, `starsShadowed`, `sun`, `swirligig`, `tornPaper`, `tornPaperBlack`, `trees`, `triangleParty`, `triangles`, `tribal1`–`tribal6`, `twistedLines1`, `twistedLines2`, `vine`, `waveline`, `weavingAngles`, `weavingBraid`, `weavingRibbon`, `weavingStrips`, `whiteFlowers`, `woodwork`, `xIllusions`, `zanyTriangles`, `zigZag`, `zigZagStitch`.

### 17.2 `ST_Underline` — קו תחתון

| ערך | מה |
|---|---|
| `none` | ללא |
| `single` | קו יחיד |
| `words` | קו רק מתחת למילים (לא רווחים) |
| `double` | כפול |
| `thick` | עבה |
| `dotted` / `dottedHeavy` | מנוקד / מנוקד עבה |
| `dash` / `dashedHeavy` | מקווקו / עבה |
| `dashLong` / `dashLongHeavy` | מקפים ארוכים |
| `dotDash` / `dashDotHeavy` | נקודה‑מקף |
| `dotDotDash` / `dashDotDotHeavy` | נקודה‑נקודה‑מקף |
| `wave` / `wavyHeavy` / `wavyDouble` | גלי / גלי עבה / גלי כפול |

### 17.3 `ST_Jc` — יישור

`start`, `end`, `left`, `right`, `center`, `both` (justify), `distribute` (פיזור כולל אות אחרונה), `mediumKashida`/`highKashida`/`lowKashida` (מתיחת קשידה בערבית), `numTab`, `thaiDistribute`.

> הערה: בסכמת 2006 (transitional) מופיעים left/center/right/both; `start`/`end` נוספו בגרסת ISO/strict ו‑Word מודרני כותב אותם. תמוך בשני המקרים (§16.4).

### 17.4 `ST_HighlightColor` — צבעי מרקר

`black`, `blue`, `cyan`, `green`, `magenta`, `red`, `yellow`, `white`, `darkBlue`, `darkCyan`, `darkGreen`, `darkMagenta`, `darkRed`, `darkYellow`, `darkGray`, `lightGray`, `none`.
(16 צבעים קבועים + none — ערכים שמיים, לא hex. מנוע ממפה כל אחד ל‑RGB קבוע.)

### 17.5 `ST_Shd` — תבניות הצללה

`nil`, `clear`, `solid`, `horzStripe`, `vertStripe`, `reverseDiagStripe`, `diagStripe`, `horzCross`, `diagCross`, `thinHorzStripe`, `thinVertStripe`, `thinReverseDiagStripe`, `thinDiagStripe`, `thinHorzCross`, `thinDiagCross`, ואחוזי נקודות: `pct5`, `pct10`, `pct12`, `pct15`, `pct20`, `pct25`, `pct30`, `pct35`, `pct37`, `pct40`, `pct45`, `pct50`, `pct55`, `pct60`, `pct62`, `pct65`, `pct70`, `pct75`, `pct80`, `pct85`, `pct87`, `pct90`, `pct95`.

> `pctNN` = צפיפות תבנית נקודות בין `fill` ל‑`color` (pct50 ≈ ערבוב 50/50). `clear` = רק fill. `solid` = רק color.

### 17.6 `ST_NumberFormat` — פורמטי מספור (מלא)

**מערביים/נפוצים:** `decimal`, `decimalZero`, `upperRoman`, `lowerRoman`, `upperLetter`, `lowerLetter`, `ordinal`, `cardinalText`, `ordinalText`, `hex`, `chicago`, `bullet`, `none`, `numberInDash`.

**עברית (חשוב לפרויקט):** `hebrew1` (אותיות מספריות: א, ב, ג…), `hebrew2` (מספור מלא בגימטריה: א׳, ב׳ … עם גרשיים).

**ערבית/הודית/תאית:** `arabicAlpha`, `arabicAbjad`, `hindiVowels`, `hindiConsonants`, `hindiNumbers`, `hindiCounting`, `thaiLetters`, `thaiNumbers`, `thaiCounting`, `vietnameseCounting`.

**קירילי:** `russianLower`, `russianUpper`.

**מזרח‑אסיה (CJK):** `ideographDigital`, `japaneseCounting`, `aiueo`, `iroha`, `decimalFullWidth`, `decimalHalfWidth`, `japaneseLegal`, `japaneseDigitalTenThousand`, `decimalEnclosedCircle`, `decimalFullWidth2`, `aiueoFullWidth`, `irohaFullWidth`, `ganada`, `chosung`, `decimalEnclosedFullstop`, `decimalEnclosedParen`, `decimalEnclosedCircleChinese`, `ideographEnclosedCircle`, `ideographTraditional`, `ideographZodiac`, `ideographZodiacTraditional`, `taiwaneseCounting`, `ideographLegalTraditional`, `taiwaneseCountingThousand`, `taiwaneseDigital`, `chineseCounting`, `chineseLegalSimplified`, `chineseCountingThousand`, `koreanDigital`, `koreanCounting`, `koreanLegal`, `koreanDigital2`.

> `bullet` = תבליט (התו ב‑`lvlText`). `none` = ללא תווית. fallback בטוח: `decimal`.

### 17.7 `ST_ThemeColor` — צבעי theme

`dark1`, `light1`, `dark2`, `light2`, `accent1`, `accent2`, `accent3`, `accent4`, `accent5`, `accent6`, `hyperlink`, `followedHyperlink`, `background1`, `text1`, `background2`, `text2`, `none`. (מיפוי לסלוטים — §13.1.)

### 17.8 enums קצרים נוספים

| Enum | ערכים | היכן |
|---|---|---|
| `ST_TabJc` (יישור טאב) | clear, left, center, right, decimal, bar, num, start, end | `w:tab/@val` |
| `ST_TabTlc` (מילוי טאב) | none, dot, hyphen, underscore, heavy, middleDot | `w:tab/@leader` |
| `ST_BrType` | page, column, textWrapping | `w:br/@type` |
| `ST_BrClear` | none, left, right, all | `w:br/@clear` |
| `ST_LineSpacingRule` | auto, exact, atLeast | `w:spacing/@lineRule` |
| `ST_HeightRule` | auto, exact, atLeast | `w:trHeight/@hRule` |
| `ST_VerticalJc` (עמוד/תא) | top, center, both, bottom | `sectPr/w:vAlign`, `tcPr/w:vAlign` |
| `ST_VerticalAlignRun` | baseline, superscript, subscript | `w:vertAlign/@val` |
| `ST_TextDirection` | lrTb, tbRl, btLr, lrTbV, tbRlV, tbLrV | `w:textDirection`, `textDirection` בתא |
| `ST_TextAlignment` | auto, baseline, top, center, bottom | `w:textAlignment/@val` |
| `ST_Em` (סימן הדגשה) | none, dot, comma, circle, underDot | `w:em/@val` |
| `ST_TextEffect` (אנימציה) | none, blinkBackground, lights, antsBlack, antsRed, shimmer, sparkle | `w:effect/@val` |
| `ST_SectionMark` | nextPage, continuous, evenPage, oddPage, nextColumn | `sectPr/w:type` |
| `ST_PageOrientation` | portrait, landscape | `w:pgSz/@orient` |
| `ST_TblLayoutType` | fixed, autofit | `w:tblLayout/@type` |
| `ST_Merge` | restart, continue | `w:vMerge`/`w:hMerge` |
| `ST_TblWidth` (סוג רוחב) | nil, pct, dxa, auto | `w:tblW`/`w:tcW`/`w:tblInd`/@type |
| `ST_ChapterSep` | hyphen, period, colon, emDash, enDash | `w:pgNumType/@chapSep` |
| `ST_Hint` | default, eastAsia, cs | `w:rFonts/@hint` |
| `ST_MultiLevelType` | singleLevel, multilevel, hybridMultilevel | `w:multiLevelType/@val` |
| `ST_LevelSuffix` | tab, space, nothing | `w:suff/@val` |
| `ST_DocGrid` | default, lines, linesAndChars, snapToChars | `w:docGrid/@type` |
| `ST_View` (תצוגה) | none, print, outline, masterPages, normal, web | `settings/w:view` |
| `ST_Wrap` (מסגרת) | auto, notBeside, around, none, tight, through | `w:framePr/@wrap` |
| `ST_DropCap` | none, drop, margin | `w:framePr/@dropCap` |
| `ST_CombineBrackets` (EA) | none, round, square, angle, curly | `w:eastAsianLayout/@combineBrackets` |

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל enum — בדוק אם כל ערכיו ממופים בקוד,
> האם יש fallback סביר לערך לא מוכר, והאם כל ערך נראה ב‑Word כפי שהמנוע מציג. תעד ל‑AI הבא חוסרים.

### ב.1 — סריקה פר‑enum

| # | Enum | כל הערכים ממומשים? (כן/חלקי/לא) | fallback סביר? | נאמן 1:1 ל‑Word? | אילו ערכים חסרים/לא‑נאמנים (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|---|
| 1 | `ST_Border` — קווים בסיסיים (27 ערכים) | לא (7/27) | כן (`single`) | לא | רק `nil/none/single/double/dashed/dotted/thick/triple` ממופים ל‑`DocxBorder`; **20 הערכים הנותרים** (`dotDash`, `dotDotDash`, כל ה‑`thinThick*`/`thickThin*`, `wave`, `doubleWave`, `dashSmallGap`, `dashDotStroked`, `threeDEmboss/Engrave`, `outset`, `inset`) נופלים שקט ל‑`single`. וגם בקרב הממופים: בטבלאות `dotted`/`dashed` → `BorderStyle.none` (**הגבול נעלם**), ו‑`double`/`triple`/`thick` → קו יחיד `solid` (עובי בלבד). | קריאה: `docx_style.dart:686‑713` (`_parseBorderSide`), `table_parser.dart:596`; enum: `enums.dart:221`; רינדור: `table_builder.dart:748‑750` |
| 2 | `ST_Border` — art borders (~160 ערכים) | לא | כן (`single`) | לא | אף ערך אמנותי לא מזוהה — `_parseBorderSide` ממפה לפי `xmlValue` של `DocxBorder` בלבד, כך שכל ~160 הערכים נופלים ל‑`single`. אריחי התמונה החוזרים של גבול אמנותי אינם מצוירים כלל. | `docx_style.dart:704‑710` |
| 3 | `ST_Underline` | כן | כן (`single` ל‑token לא מוכר) | חלקי | כל ה‑tokens נקראים (`fromXml`); הרינדור ב‑`mapUnderline` מקרב: `words` → `solid` רגיל (Word מקו רק מתחת לתווים לא‑רווח — **כאן גם רווחים מקווקווים**); `dashLong`/`dotDash`/`dotDotDash` → `dashed` אחיד (אובדן תבנית נקודה‑מקף); `wavyDouble` → `wavy` יחיד; variant ה‑`Heavy` → עובי ×2.5 (לא קו עבה אמיתי). צבע הקו (`w:color`/theme) כן נאמן. | enum: `enums.dart:326‑405`; קריאה: `docx_style.dart:490‑510`; רינדור: `span_factory.dart:761‑791` |
| 4 | `ST_Jc` (כולל kashida/numTab/thaiDistribute) | חלקי | כן (`left`/ברירת‑מחדל) | חלקי | מטופלים `left/start`, `right/end`, `center`, `both`+`distribute`→justify. **`distribute` מרונדר כ‑`both`** (Word מותח גם את האות האחרונה — כאן לא). **`mediumKashida`/`highKashida`/`lowKashida`/`numTab`/`thaiDistribute` לא מזוהים** ונופלים לערך המוחזק (ברירת‑מחדל) — מתיחת קשידה בערבית אובדת. | `docx_style.dart:327‑334`, `table_parser.dart:534`; רינדור: `paragraph_builder.dart` (`DocxAlign`→`TextAlign`) |
| 5 | `ST_HighlightColor` (16 + none) | כן | כן (`none`) | חלקי | כל 16 הצבעים + `none` ממופים (`highlightToColor`), token לא מוכר → `none`. הגוונים מקורבים לפלטת Material של Flutter (`darkYellow`→`yellow.shade800`, `darkMagenta`→`purple.shade900`, `darkGray`→`grey.shade700`), לא ל‑RGB הקבוע המדויק של מרקר Word. | קריאה: `docx_style.dart:570‑581`; רינדור: `span_factory.dart:794‑831` |
| 6 | `ST_Shd` (תבניות + pctNN) | לא (val לא נקרא) | חלקי (fill בלבד) | לא | נקרא **רק `w:fill`** (צבע הרקע); תכונת **`w:val` (התבנית) מתעלמים ממנה לחלוטין**. לכן: `clear` → fill מוצג (נכון); `solid` → אמור להציג את `w:color` אך מוצג ה‑`fill` (שגוי); `pctNN` → fill מלא ללא ערבוב צפיפות; פסים (`horzStripe`/`diagCross`/…) → לא מצוירים, fill בלבד. | `docx_style.dart:376‑384` (pPr), `:529‑536` (rPr), `table_parser.dart:411` |
| 7 | `ST_NumberFormat` — מערביים/נפוצים | חלקי | כן (`decimal`) | חלקי | נאמנים: `decimal`, `decimalZero`, `upperRoman`, `lowerRoman`, `upperLetter`, `lowerLetter`, `ordinal`, `none`, `bullet`. `cardinalText`/`ordinalText` → `decimal` (מילים אנגליות מחוץ לתחום §8.2). **`hex`, `chicago`, `numberInDash` לא ממומשים** → נופלים ל‑coarse enum → `decimal`. | `numbering_resolver.dart:201‑253`; `number_formatter.dart` |
| 8 | `ST_NumberFormat` — עברית (hebrew1/hebrew2) | כן | כן (`decimal`) | נאמן (עם הסתייגות) | `hebrew1` → גימטריה אדיטיבית עם תיקון `טו`/`טז` (טווח 1..999); `hebrew2` → אותיות ת"ך כסדרן (1→א). מעל הטווח: `hebrew1>999`→decimal, `hebrew2>22`→bijective base‑22 **שאינו מאומת מול Word** (ייתכן ש‑Word חוזר על AA/BB). קריטי לקודש — עובד לטווח הרגיל. | `number_formatter.dart:115‑177`; `numbering_resolver.dart:223‑226` |
| 9 | `ST_NumberFormat` — ערבית/הודית/תאית | לא | חלקי (`decimal`) | לא | אף אחד מ‑`arabicAlpha`/`arabicAbjad`/`hindi*`/`thai*`/`vietnameseCounting` לא ממומש — כולם נופלים ל‑coarse enum → `decimal`. | `numbering_resolver.dart:237‑252` |
| 10 | `ST_NumberFormat` — קירילי | לא | חלקי (`decimal`) | לא | `russianLower`/`russianUpper` לא ממומשים → `decimal`. | `numbering_resolver.dart:207‑236` |
| 11 | `ST_NumberFormat` — מזרח‑אסיה (CJK) | לא | חלקי (`decimal`) | לא | כל ~35 פורמטי ה‑CJK (`ideograph*`, `*Counting`, `aiueo`, `iroha`, `chosung`/`ganada`, `decimalEnclosed*`, `koreanDigital` וכו') לא ממומשים → `decimal`. | `numbering_resolver.dart:237‑252` |
| 12 | `ST_ThemeColor` | חלקי | לא (→ ללא צבע) | חלקי | `getColor` מטפל ב‑`text1/2`, `background1/2`, `accent1‑6`. **חסרים: `hyperlink`/`followedHyperlink`** (קיימים רק שמות הסכמה `hlink`/`folHlink`, לא טוקני ה‑themeColor), **`dark1`/`light1`/`dark2`/`light2`**, ו‑`none`. token לא ממופה → `null` ⇒ אין צבע (לא ברירת‑מחדל סבירה). תואם ממצאי §13. | `docx_theme.dart:128‑161`; `span_factory.dart:706‑737` |
| 13 | `ST_TabJc` | כן | כן (`left`) | חלקי | `fromXml`: `left/center/right/decimal/bar/start/end/clear` + `num`→`decimal`; לא מוכר→`left`. רינדור: `left/center/right` מדויקים; `start`→left, `end`→right; **`decimal` מקורב כ‑right** (יישור לנקודה עשרונית אמיתית — מגבלה מתועדת); `bar` מצייר קו אנכי; `clear` מסיר. | enum: `enums.dart:54‑69`; רינדור: `tab_engine.dart:52‑54,153‑164` |
| 14 | `ST_TabTlc` | כן | כן (`none`) | נאמן | `none/dot/hyphen/underscore/middleDot/heavy` נקראים ומצוירים: `underscore`/`heavy` קו (heavy עבה ×2), `hyphen` מקפים, `dot`/`middleDot` נקודות. | enum: `enums.dart:83‑95`; רינדור: `tabbed_line.dart:136‑158` |
| 15 | `ST_BrType` | כן | כן (line‑break) | נאמן | `page`→מעבר עמוד, `column`→מעבר טור, `textWrapping`/חסר→מעבר שורה רגיל. | `inline_parser.dart:277‑285` |
| 16 | `ST_BrClear` | לא | — | לא | תכונת `w:br/@clear` (`none/left/right/all`) **כלל לא נקראת** — `parseRun` קורא רק `@type`. נדיר; משפיע על מיקום שבירה סביב floats. | `inline_parser.dart:280` |
| 17 | `ST_LineSpacingRule` | כן | כן (`auto`) | נאמן | `auto` → מכפיל גובה (`lineSpacing/240`), `exact`/`atLeast` → `StrutStyle` (`exact` כופה גובה, `atLeast` מינימום). | `span_factory.dart:112‑141` |
| 18 | `ST_HeightRule` | כן | כן (`atLeast`) | נאמן | `auto/atLeast/exact`; חסר→`atLeast` (Word כותב `trHeight` ערום למינימום). `exact` חותך, `atLeast` גדל לתוכן. | `enums.dart:560‑578`; משימה 06 |
| 19 | `ST_VerticalJc` | חלקי | כן (`top`) | חלקי | מקטע (`sectPr/vAlign`): `top/center/bottom` מדויקים, `both`≈`stretch` (מתיחה, לא פיזור אמיתי בין פסקאות). **תא (`tcPr/vAlign`): רק `top/center/bottom` נקראים** — `both` בתא לא ממופה ל‑`DocxVerticalAlign` (נופל ל‑`top`). | מקטע: `docx_widget_generator.dart:937‑942`; תא: `docx_style.dart:622‑628`, `table_builder.dart:525‑545` |
| 20 | `ST_VerticalAlignRun` | כן | כן (`baseline`) | חלקי | `superscript`/`subscript` נקראים ומרונדרים (`FontFeature` + גודל ×0.7); `baseline` = ברירת‑מחדל. ההרמה/הורדה והקטנה מקורבות (לא לפי מטריקת הפונט המדויקת). | קריאה: `docx_style.dart:591‑596`; רינדור: `span_factory.dart:284‑285,346‑350` |
| 21 | `ST_TextDirection` | חלקי (נקרא‑לא‑מנוצל) | כן (`lrTb`) | לא | כל 6 הערכים נקראים ל‑`DocxCellTextDirection` (`fromXml`), אך **סיבוב טקסט התא לא מרונדר** — `tbRl`/`btLr` וכו' מוצגים אופקית. | enum: `enums.dart:593‑608`; קריאה: `table_parser.dart:458`; רינדור: לא קיים (משימה 05/06) |
| 22 | `ST_TextAlignment` | חלקי (נקרא‑לא‑מנוצל) | כן (`auto`) | לא | `DocxTextAlignment.fromXml` קורא `auto/baseline/top/center/bottom`, אך הערך **לא מנוצל ברינדור** (יישור אנכי של גליפים בתוך השורה לא מיושם). | enum: `enums.dart:31‑44`; משימה 04 |
| 23 | `ST_Em` | חלקי (נקרא‑לא‑מנוצל) | כן (אין סימן) | לא | `DocxEmphasisMark.fromXml` קורא `none/dot/comma/circle/underDot` ל‑`emphasisMark`, אך **סימן ההדגשה לא מצויר**. | enum: `enums.dart:299‑312`; קריאה: `inline_parser.dart:436‑437` |
| 24 | `ST_TextEffect` | לא | — | לא | `w:effect` (`blinkBackground/lights/antsBlack/antsRed/shimmer/sparkle`) **כלל לא נקרא** ולא מאוחסן. אנימציות אלו ממילא אינן מוצגות בהדפסה ב‑Word. | אין מימוש |
| 25 | `ST_SectionMark` | חלקי | כן (`nextPage`) | לא | `DocxSectionBreak` = `continuous/nextPage/evenPage/oddPage` — **חסר `nextColumn`**. `sectionType` נשמר כמחרוזת, אך מקטעי ביניים אינם מכבדים את הסוג (תמיד עמוד חדש; ראו §05). | `enums.dart:436`; `docx_theme.dart:402,433` |
| 26 | `ST_PageOrientation` | כן | כן (`portrait`) | נאמן | `portrait`/`landscape` נקראים; ההשפעה בפועל דרך `pgSz` (רוחב/גובה). | `enums.dart:432`; `docx_theme.dart:371,419` |
| 27 | `ST_TblLayoutType` | כן | כן (`autofit`) | חלקי | `fixed`/`autofit`; חסר→`autofit`. `fixed` משתמש ברוחבי הגריד; **`autofit` מקורב** (אלגוריתם ההתאמה לתוכן לא זהה ל‑Word — משימה 06). | `enums.dart:582‑589` |
| 28 | `ST_Merge` | חלקי | כן (`continue`) | חלקי | `vMerge`: `restart`/`continue` (וריק→continue) מטופלים נכון. **`hMerge` (מיזוג אופקי) לא נקרא כלל** → תאים ממוזגים אופקית מוצגים בנפרד. | `table_parser.dart:406‑408,667‑668`; `hMerge` חסר |
| 29 | `ST_TblWidth` | חלקי | כן (`auto`) | חלקי | `dxa`/`pct`/`auto` נקראים ל‑`DocxWidthType`; **`nil` חסר מה‑enum** (ברוחב טבלה/תא נופל ל‑`auto`; בשולי תא `w:type="nil"`→0). `pct` נתמך לרוחב טבלה אך התאמת רוחב כללית מקורבת. | `table_parser.dart:60‑62,580`; `enums.dart:554` |
| 30 | `ST_ChapterSep` | כן | כן (`hyphen`) | נאמן | `hyphen/period/colon/emDash/enDash` קיימים ב‑`DocxChapterSeparator`; משמשים ב‑`pgNumType` (נאמן — משימה 05). | `enums.dart:458` |
| 31 | `ST_Hint` | חלקי | כן (`default`) | חלקי | `w:rFonts/@hint` נקרא; **רק `cs` מנוצל** (`hintComplex` → סיווג כתב מורכב). `eastAsia` לא מאלץ פונט EA; `default` = ללא השפעה. | קריאה: `docx_style.dart:562`; שימוש: `span_factory.dart:398` |
| 32 | `ST_MultiLevelType` | לא | — | לא (לא ויזואלי) | `w:multiLevelType` (`singleLevel/multilevel/hybridMultilevel`) **לא נקרא**. רמז עיצובי בלבד; אינו משנה רינדור ישיר. | אין מימוש |
| 33 | `ST_LevelSuffix` | חלקי | כן (`tab`) | חלקי | `suff` (`tab/space/nothing`) נקרא ל‑`DocxNumberingLevel.suff`, אך **`suff=tab` אינו מיושר לטאב** (מרווח קבוע במקום עצירת טאב — משימה 08); `space`/`nothing` מקורבים. | `docx_theme.dart:273`; משימה 08 |
| 34 | `ST_DocGrid` | לא | — | לא | `w:docGrid` (`default/lines/linesAndChars/snapToChars`) **לא נקרא** — רשת התווים המזרח‑אסיאתית לא ממומשת. | אין מימוש |
| 35 | `ST_View` | לא | — | לא (לא ויזואלי) | `settings/w:view` (`print/web/outline/…`) **לא נקרא** — מצב התצוגה אינו רלוונטי לרינדור עמוד מודפס. | אין מימוש |
| 36 | `ST_Wrap` (framePr) | לא | — | לא | `w:framePr/@wrap` (`auto/around/tight/through/none/notBeside`) **לא ממומש** — מסגרות טקסט (text frames) אינן נתמכות; היחיד מ‑`framePr` שמטופל הוא drop‑cap (פריט 37). | משימה 04 (`framePr` רק drop‑cap) |
| 37 | `ST_DropCap` | חלקי | כן (ללא drop) | חלקי | `drop` ו‑`margin` שניהם מזוהים ויוצרים `DocxDropCap`; **`margin` (אות בשוליים) מרונדר כ‑`drop` (בתוך הטקסט)** — לא 1:1. `none`/חסר = ללא drop‑cap. | קריאה: `block_parser.dart:58‑85`; רינדור: `paragraph_builder.dart:1017‑1079` |
| 38 | `ST_CombineBrackets` | לא | — | לא | `w:eastAsianLayout/@combineBrackets` (`none/round/square/angle/curly`) **לא נקרא** — פריסת ה‑EA (`combine`/`vert`) אינה ממומשת. | אין מימוש (משימה 03) |

### ב.2 — פערים והוראות ל‑AI הבא

**עיקרון‑על שנמצא:** ה‑fallback קיים כמעט בכל מקום (`single`/`left`/`decimal`/`auto`/`none`) — כלומר המנוע כמעט אף פעם לא "נופל" על ערך לא מוכר. הבעיה היא **כיווץ הרזולוציה**: enums רבים מקופלים למספר קטן של ערכים נתמכים, כך שערכים שונים נראים זהים. נאמנות 1:1 נשברת לא מחוסר‑מימוש אלא מ‑over‑collapse.

**קריטי (משפיע על מסמכים נפוצים, כולל עברית):**

1. **`ST_Border` (פריטים 1‑2):** רק 7/27 קווים בסיסיים ממופים; 20 הנותרים + ~160 אמנותיים → `single`. גרוע מכך — בטבלאות `dotted`/`dashed` **נעלמים** (`BorderStyle.none`), ו‑`double`/`triple` → קו יחיד. יש להוסיף שכבת רינדור גבול (dashed/dotted/double אמיתיים) ולשמר את ה‑`rawVal` לכל הטוקנים. (חופף משימות 02/04/05/06.)
2. **`ST_Shd` (פריט 6):** ה‑`w:val` (תבנית) **לא נקרא** — `solid` מציג fill במקום color, `pctNN` ללא ערבוב, פסים לא מצוירים. יש לקרוא `val` ולחשב את צבע התבנית בין `fill` ל‑`color`.
3. **`ST_ThemeColor` (פריט 12):** `hyperlink`/`followedHyperlink`/`dark1`/`light1`/`dark2`/`light2` לא ממופים → `null` (אין צבע). יש למפות גם את טוקני ה‑themeColor הללו ב‑`DocxThemeColors.getColor`. (חופף §13.)
4. **`ST_NumberFormat` לא‑לטיני (פריטים 9‑11):** ערבית/הודית/תאית/קירילי/CJK כולם → `decimal`. עברית (`hebrew1/2`) נאמנה לטווח 1..999/22; יש לאמת `hebrew2` מעל 22 מול Word (חשד לחזרה AA/BB ולא bijective).

**בינוני (נראה בעין אך נדיר יותר):**

5. **`ST_Underline` (פריט 3):** `words` מקווקו גם רווחים; `dashLong`/`dotDash`/`dotDotDash` → `dashed` אחיד; `wavyDouble` → גלי יחיד.
6. **`ST_Jc` (פריט 4):** `distribute` ≡ `both` (האות האחרונה לא נמתחת); kashida ערבי/`numTab`/`thaiDistribute` מתעלמים.
7. **`ST_VerticalJc` תא (פריט 19):** `both` בתא לא ממופה (→`top`).
8. **`ST_Merge` (פריט 28):** `hMerge` לא נקרא — מיזוג אופקי נשבר.
9. **`ST_TabJc` (פריט 13):** `decimal` מיושר כ‑right (אין יישור לנקודה עשרונית).
10. **`ST_DropCap` (פריט 37):** `margin` מרונדר כ‑`drop`.

**נקרא‑אך‑לא‑מנוצל (parsed, not rendered):** `ST_TextDirection` (21), `ST_TextAlignment` (22), `ST_Em` (23), `ST_Hint` eastAsia (31), `ST_LevelSuffix` tab‑align (33). הנתונים זמינים ב‑AST — חסרה שכבת הרינדור בלבד.

**לא נקרא כלל (אין מימוש):** `ST_BrClear` (16), `ST_TextEffect` (24), `ST_MultiLevelType` (32), `ST_DocGrid` (34), `ST_View` (35), `ST_Wrap`/text‑frames (36), `ST_CombineBrackets` (38), וערך `nextColumn` ב‑`ST_SectionMark` (25) + `nil` ב‑`ST_TblWidth` (29). רובם נדירים/לא‑ויזואליים, אך `BrClear` ו‑`SectionMark/nextColumn` משפיעים על פריסה.

**נאמנים במלואם:** `ST_TabTlc` (14), `ST_BrType` (15), `ST_LineSpacingRule` (17), `ST_HeightRule` (18), `ST_PageOrientation` (26), `ST_ChapterSep` (30), ועברית ב‑`ST_NumberFormat` (8, בטווח). `ST_HighlightColor` (5) נאמן מבנית אך הגוונים מקורבים לפלטת Material.
