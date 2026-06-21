# משימה 15 — רקע מסמך וסימני מים

> **מקור:** סעיף §15 מתוך `WORD_FORMATTING_XML_REFERENCE.md` — הועתק כלשונו וללא שינוי.
> **אסור לערוך את "חלק א'".** המימוש והממצאים נכתבים ב"חלק ב'" בלבד.
>
> **סטטוס סריקה:** ✅ נסקר במלואו &nbsp;|&nbsp; **עודכן לאחרונה:** 2026-06-21

---

## חלק א' — הייחוס (העתקה מדויקת מהמסמך הראשי)

| אלמנט | איפה | מה עושה |
|---|---|---|
| `w:background` | ראש `document.xml` | צבע רקע לכל המסמך (`@w:color`/themeColor) או תמונת רקע (VML `v:background`→`v:fill`). מוצג רק אם `displayBackgroundShape` דלוק (§14). |
| **סימן מים** | ב‑header (לרוב) כ‑VML `v:shape` עם `v:textpath` (טקסט) או `v:imagedata` (תמונה), `style` עם `mso-position` ו‑`behindDoc` | "טיוטה"/"סודי" וכד'. לרוב ב‑`w:pict` בכותרת. |

> סימן מים טקסטואלי = `v:shape type="#_x0000_t136"` (textpath) בכותרת, מוטה באלכסון, צבע אפור שקוף. מנוע 1:1 מרנדר אותו מאחורי תוכן העמוד.

---

## חלק ב' — סריקת מימוש ונאמנות 1:1 (ממלא ה‑AI הסורק)

> הוראות מילוי מלאות ב‑[README.md](README.md). בקצרה: לכל פריט בחלק א' — בדוק אם מטופל בקוד;
> אם כן, חקור איך Word מציג אותו והשווה פיקסל‑מול‑פיקסל; אם לא/חלקי/לא‑נאמן — תעד ל‑AI הבא.

> **מפת המימוש.** שני מסלולים נפרדים, שניהם **חלקיים**:
> **(א) צבע רקע מסמך** — `DocxReader.read` קורא את `w:background` הראשון ב‑document.xml,
> מושך **רק** את `@w:color` (hex, פרט ל‑`auto`) ובונה `DocxColor('#…')` (`docx_reader.dart:192‑200`).
> זה מוזרם ל‑`SectionParser.parse(backgroundColor:)` (`section_parser.dart:13,249`) ונשמר ב‑`section.backgroundColor`.
> בעת רינדור הצבע צובע את נייר העמוד (`docx_widget_generator.dart:919‑921` → `decoration.color`, שורה 980).
> **(ב) סימן מים / תמונת רקע** — אין מסלול ל‑`v:background` תקני. הקורא מטפל ב‑`w:pict`+`v:imagedata`
> **בתוך ריצה** דרך `_parseDrawing` (`inline_parser.dart:322‑327,501‑507`): שקופית VML עם מיקום מוחלט
> ו‑`z-index<0` ממופה ל‑`DocxInlineImage(textWrap: behindText)` ע"י `_parseVmlPlacement`
> (`inline_parser.dart:744‑777,1197‑1274`). בצד הצופה, תמונות `behindText` **בגוף** נאספות
> (`_collectBehindTextImages`, `docx_widget_generator.dart:817‑830`) ומצוירות כ‑`DecorationImage`
> מתחת ל‑Stack של העמוד (שורות 983‑990, `BoxFit.fill`). **שלושה חורים מבניים:**
> (1) `themeColor`/`themeTint`/`themeShade` של `w:background` ו‑`displayBackgroundShape` **לא נקראים**;
> (2) `v:textpath` (סימן מים טקסטואלי) **נופל ל‑`DocxRawInline`** שהצופה לא מרנדר כלל;
> (3) האיסוף לרקע סורק **רק את בלוקי הגוף** — סימן מים בכותרת (המקום הרגיל!) לא מצויר מאחורי הגוף,
> ומסלול הרקע מתעלם מסיבוב/מיקום (`BoxFit.fill` בלבד) ומשתמש רק ב‑`backgroundImages.first`.

### ב.1 — סריקה פר‑פריט

| # | פריט (אלמנט/תכונה) | ממומש? (כן/חלקי/לא) | נאמן 1:1 ל‑Word? | איך זה נראה ב‑Word (ממצאי מחקר) | קובץ/שורה במימוש |
|---|---|---|---|---|---|
| 1 | `w:background` — צבע (`@w:color`/themeColor) | חלקי | נאמן (hex) / **לא** (themeColor) | `@w:color` בפורמט hex נקרא ונשמר (`auto` נדחה כראוי), נפתר ל‑`section.backgroundColor` וצובע את כל נייר העמוד מתחת לטקסט — תואם Word עבור צבע מפורש. **אך** `w:background` יכול לשאת `w:themeColor`(+`themeTint`/`themeShade`) במקום `w:color`; אלה **לא נקראים** → `backgroundColor` נשאר null והעמוד יוצג לבן במקום בצבע הערכה. Word פותר את ה‑themeColor מול ה‑theme. בנוסף ההצגה אינה מותנית ב‑`displayBackgroundShape` (פריט 3). | קריאה: `docx_reader.dart:194‑200` (hex בלבד); רינדור: `docx_widget_generator.dart:919‑921,980` |
| 2 | `w:background` — תמונת רקע (VML `v:background`→`v:fill`) | **לא** | **לא** | האלמנט התקני `<w:background><v:background><v:fill r:id=… type="frame"/>` ב‑document.xml **אינו מנותח כלל**. המסלול היחיד שקיים (`_readBackgroundImage`) נורה **רק** כש‑`headerReference` נושא את ה‑rId הקשיח `'rIdBgHdr'` — מוסכמה שהכותב של ספרייה זו ממציא, ולא פלט Word אמיתי. לכן מסמך Word עם תמונת רקע לעמוד (דרך `v:background`) יוצג ללא הרקע. | פער: `docx_reader.dart:192‑200` (קורא רק color); המסלול הקשיח: `section_parser.dart:345‑395` |
| 3 | תנאי הצגה: `displayBackgroundShape` (§14) | **לא** | **לא** | `parseSettings` קורא רק `evenAndOddHeaders`/`defaultTabStop`/note‑props — `w:displayBackgroundShape` **מתעלם** (הכותב כן פולט אותו ב‑`styles_generator.dart:60`, אך הקורא לא קורא). תוצאה: הצופה צובע את `w:background` **תמיד**, גם כשהדגל כבוי. ב‑Word צבע/אובייקטי רקע מוצגים על המסך **רק** כשהדגל דלוק; מסמך עם `w:background` בלי הדגל יוצג לבן ב‑Word אך צבעוני בצופה. השפעה נמוכה (מסמך שמגדיר רקע בד"כ גם מדליק את הדגל). | פער: `docx_reader.dart:39‑58` (parseSettings — אין `displayBackgroundShape`) |
| 4 | סימן מים טקסטואלי — `v:shape type="#_x0000_t136"` + `v:textpath` | **לא** | **לא** | `_parseDrawing` מזהה רק `a:blip`/`v:imagedata` (תמונה) או `wsp:wsp` (צורת DrawingML). שקופית `t136` עם `v:textpath` נטולת שני אלה → נופלת ל‑`DocxRawInline(drawing.toXmlString())`, והצופה **אינו מרנדר `DocxRawInline` בכלל**. לכן טקסט הסימן ("טיוטה"/"סודי"/"DRAFT") **נעלם לחלוטין** — אין טקסט, אין צורה, אין הטיה. זו הצורה הנפוצה ביותר של סימן מים ב‑Word (Insert→Watermark→Text). Word מצייר אותו מאחורי התוכן, מסובב באלכסון, באפור שקוף. | פער: `inline_parser.dart:501‑507,799‑806` (אין ענף textpath → RawInline); הצופה: אין טיפול ב‑`DocxRawInline` |
| 5 | סימן מים תמונה — `v:imagedata` | חלקי | **לא** (הכותרת — הנפוץ) / חלקית‑נאמן (גוף) | `w:pict`+`v:imagedata` נקרא (`inline_parser.dart:506‑507`), גודלו נמשך מ‑CSS `style` של ה‑shape (`_vmlShapeSize`). מיקום מוחלט + `z-index<0` → `DocxInlineImage(behindText)` (פריט 6). **בגוף** התמונה מצוירת כרקע העמוד (פריט 7). **אך** סימני מים חיים כמעט תמיד ב‑**כותרת**, ושם הצופה אינו מפעיל את `_collectBehindTextImages` (האיסוף רץ רק על בלוקי הגוף) → תמונת הסימן בכותרת לא תצויר מאחורי הגוף; במקרה הטוב תוצג בתוך פס הכותרת בלבד. גם `z-index` חיובי או היעדרו → לא behindText → לא ייכנס לרקע. | קריאה: `inline_parser.dart:744‑777`; איסוף (גוף בלבד): `docx_widget_generator.dart:817‑830`; כותרת: `docx_widget_generator.dart:1033‑1043` (ללא איסוף) |
| 6 | `style` של סימן מים (mso-position + behindDoc, הטיה באלכסון, אפור שקוף) | חלקי | **לא** | `_parseVmlPlacement` מפענח מתוך ה‑CSS `style`: `position:absolute`, `z-index<0`→`behindText`, `mso-position-horizontal/-vertical`(+`-relative`)→align/from, `margin-left/-top`→offset, `rotation`(מעלות)→`rotation`, `alt`. כלומר עיגון‑מיקום והסיבוב **נקראים למודל**. **אך** (א) מסלול ציור‑הרקע בצופה (פריט 7) משתמש ב‑`BoxFit.fill` בלבד ו**אינו מיישם `rotation` ולא את ה‑mso‑position** — ההטיה האלכסונית של הסימן אובדת והתמונה נמתחת לכל העמוד; (ב) ה‑`v:fill opacity`/`o:gfxdata` (השטיפה האפורה‑שקופה האופיינית) **לא נקרא** ולא מיושם. | פענוח: `inline_parser.dart:1197‑1274`; אובדן בצביעה: `docx_widget_generator.dart:983‑990` (fill בלבד, ללא rotation/opacity) |
| 7 | רינדור סימן מים **מאחורי** תוכן העמוד | חלקי | **לא** | תמונת `behindText` **שבגוף** מצוירת כ‑`DecorationImage` של ה‑`Container` של העמוד, מתחת ל‑`Stack` של הגוף — כלומר אכן *מאחורי* הטקסט (נאמן במובן הצר הזה). **אך** רק `backgroundImages.first` נצרכת (כמה סימני מים → רק אחד מצויר), `BoxFit.fill` מותח לכל העמוד (Word ממקם/ממרכז לפי גודל+mso‑position), אין סיבוב, וכאמור (פריט 5) סימן מים בכותרת — המקום הרגיל — **לא** נכנס למסלול הזה. סימן מים טקסטואלי (פריט 4) חסר לגמרי. | `docx_widget_generator.dart:972‑998` |

### ב.2 — פערים והוראות ל‑AI הבא

**עיקרון:** מה שעובד — **צבע רקע מפורש** (`w:background w:color="hex"`) נקרא ומצויר נאמן מתחת לכל העמוד,
ותמונת `behindText` **בגוף** המסמך מצוירת מאחורי הטקסט. כל השאר — תמונת רקע תקנית, סימן מים טקסטואלי,
סימן מים בכותרת, מיפוי themeColor של הרקע, וגיוון ההצגה — **חסר או לא נאמן**.

**פערים בעלי השלכה ויזואלית (לתעד/לשקול מימוש):**
- **סימן מים טקסטואלי `v:textpath` (פריט 4, הקריטי ביותר).** הצורה הנפוצה ביותר של סימן מים נופלת ל‑`DocxRawInline`
  ונעלמת. **תיקון:** להוסיף ל‑`_parseDrawing` ענף שמזהה `v:shape` עם `v:textpath` (לרוב `type="#_x0000_t136"`),
  לחלץ את `string` של ה‑textpath (הטקסט), את צבע/אטימות ה‑`v:fill`, ואת `rotation`/`mso-position` מה‑`style`,
  ולמדל ישות סימן‑מים טקסטואלי שהצופה יצייר מאחורי הגוף, מסובבת באלכסון.
- **סימן מים בכותרת לא מצויר מאחורי הגוף (פריטים 5,7).** `_collectBehindTextImages` רץ רק על בלוקי הגוף.
  סימני מים יושבים ב‑header. **תיקון:** לאסוף תמונות/סימני‑מים `behindText` גם מבלוקי הכותרת הפעילה ולהזרים
  אותם לאותו מסלול רקע‑עמוד (`docx_widget_generator.dart:612` מול בניית הכותרת ב‑1033‑1043).
- **`w:background` עם `themeColor` (פריט 1).** רק `w:color` hex נקרא; רקע מבוסס‑ערכה יוצג לבן.
  להוסיף ב‑`docx_reader.dart:194‑200` קריאת `w:themeColor`/`themeTint`/`themeShade` ולפתור דרך `DocxThemeColors`
  (כמשימה 13). 
- **תמונת רקע `v:background`→`v:fill` (פריט 2).** האלמנט התקני לא מנותח (רק מוסכמת ה‑`rIdBgHdr` הפנימית).
  לקרוא `w:background/v:background/v:fill[@r:id]`, למשוך את התמונה דרך ה‑relationship של document.xml,
  ולצייר כרקע עמוד לפי `type` (frame/tile).
- **מיקום/סיבוב/אטימות במסלול הרקע (פריטים 6,7).** גם כשהמיקום והסיבוב **נקראים** למודל, מסלול
  ה‑`DecorationImage` מתעלם מהם (`BoxFit.fill`). לשקול ציור הסימן כשכבת `Positioned`/`Transform.rotate`
  עם `Opacity`, במקום `DecorationImage` מתוח, ולתמוך ביותר מסימן אחד.

**סטיות מודעות / השפעה נמוכה:**
- **`displayBackgroundShape` (פריט 3).** הדגל לא נקרא → הרקע מוצג תמיד. מסמך שמגדיר `w:background` בלי הדגל
  יוצג צבעוני בצופה אך לבן ב‑Word. נדיר; תלוי במשימה 14 (settings).
- **שטיפה אפורה‑שקופה של textpath (`v:fill opacity`).** מוקדם — תלוי קודם במימוש פריט 4.
