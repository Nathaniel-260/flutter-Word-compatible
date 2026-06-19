# משימה 17 — נספח: טבלאות enum מלאות

> **מקור:** סעיף §17 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ⬜ טרם נסקר &nbsp;|&nbsp; **עודכן לאחרונה:** —
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
| 1 | `ST_Border` — קווים בסיסיים (27 ערכים) | | | | | |
| 2 | `ST_Border` — art borders (~160 ערכים) | | | | | |
| 3 | `ST_Underline` | | | | | |
| 4 | `ST_Jc` (כולל kashida/numTab/thaiDistribute) | | | | | |
| 5 | `ST_HighlightColor` (16 + none) | | | | | |
| 6 | `ST_Shd` (תבניות + pctNN) | | | | | |
| 7 | `ST_NumberFormat` — מערביים/נפוצים | | | | | |
| 8 | `ST_NumberFormat` — עברית (hebrew1/hebrew2) | | | | | |
| 9 | `ST_NumberFormat` — ערבית/הודית/תאית | | | | | |
| 10 | `ST_NumberFormat` — קירילי | | | | | |
| 11 | `ST_NumberFormat` — מזרח‑אסיה (CJK) | | | | | |
| 12 | `ST_ThemeColor` | | | | | |
| 13 | `ST_TabJc` | | | | | |
| 14 | `ST_TabTlc` | | | | | |
| 15 | `ST_BrType` | | | | | |
| 16 | `ST_BrClear` | | | | | |
| 17 | `ST_LineSpacingRule` | | | | | |
| 18 | `ST_HeightRule` | | | | | |
| 19 | `ST_VerticalJc` | | | | | |
| 20 | `ST_VerticalAlignRun` | | | | | |
| 21 | `ST_TextDirection` | | | | | |
| 22 | `ST_TextAlignment` | | | | | |
| 23 | `ST_Em` | | | | | |
| 24 | `ST_TextEffect` | | | | | |
| 25 | `ST_SectionMark` | | | | | |
| 26 | `ST_PageOrientation` | | | | | |
| 27 | `ST_TblLayoutType` | | | | | |
| 28 | `ST_Merge` | | | | | |
| 29 | `ST_TblWidth` | | | | | |
| 30 | `ST_ChapterSep` | | | | | |
| 31 | `ST_Hint` | | | | | |
| 32 | `ST_MultiLevelType` | | | | | |
| 33 | `ST_LevelSuffix` | | | | | |
| 34 | `ST_DocGrid` | | | | | |
| 35 | `ST_View` | | | | | |
| 36 | `ST_Wrap` | | | | | |
| 37 | `ST_DropCap` | | | | | |
| 38 | `ST_CombineBrackets` | | | | | |

### ב.2 — פערים והוראות ל‑AI הבא

- _(ריק — ימולא בסריקה)_
