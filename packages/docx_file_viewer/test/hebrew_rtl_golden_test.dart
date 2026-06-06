import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';

/// בדיקות ויזואליות (golden) לתיקון ה-RTL/כיוון:
///  1. קובץ עברי טהור → RTL, יישור ימין, ניקוד, מודגש, צבע, טבלה.
///  2. קובץ מעורב עברית+אנגלית → כל פסקה בכיוון הנכון לפי "first-strong"
///     (אנגלית→LTR שמאל, עברית→RTL ימין), בלי jc/bidi מפורשים.
/// טוען גופנים אמיתיים (David + Arial) כדי שה-golden יציג אותיות אמיתיות.
const _assetsDir =
    r'C:\OTZ\flutter-packages\packages\docx_file_viewer\example\assets';

Future<void> _loadFonts() async {
  for (final entry in {'David': 'david.ttf', 'Arial': 'arial.ttf'}.entries) {
    final bytes = File('C:\\Windows\\Fonts\\${entry.value}').readAsBytesSync();
    final loader = FontLoader(entry.key)
      ..addFont(
          Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    await loader.load();
  }
}

Widget _viewer(String assetFile) {
  final docxBytes =
      Uint8List.fromList(File('$_assetsDir\\$assetFile').readAsBytesSync());
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SizedBox(
        width: 900,
        height: 1250,
        child: DocxView.bytes(
          docxBytes,
          config: const DocxViewConfig(
            enableSelection: false,
            enableZoom: false,
            enableSearch: false,
            pageMode: DocxPageMode.paged,
            customFontFallbacks: ['Arial', 'David'],
            theme: DocxViewTheme(
              backgroundColor: Colors.white,
              defaultTextStyle: TextStyle(
                fontFamily: 'Arial',
                fontSize: 20,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Hebrew DOCX renders RTL', (tester) async {
    await _loadFonts();
    await tester.pumpWidget(_viewer('hebrew_test.docx'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await expectLater(
      find.byType(DocxView),
      matchesGoldenFile('goldens/hebrew_rtl.png'),
    );
  });

  testWidgets('Mixed EN+HE DOCX picks direction per paragraph', (tester) async {
    await _loadFonts();
    await tester.pumpWidget(_viewer('mixed_test.docx'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await expectLater(
      find.byType(DocxView),
      matchesGoldenFile('goldens/mixed_dir.png'),
    );
  });

  // footer (כותרת תחתונה) — נדחף לתחתית העמוד בלי קריסה (Stack+Positioned,
  // לא IntrinsicHeight+Spacer שקורס ב-ListView לא-חסום).
  testWidgets('footer pinned to page bottom without crash', (tester) async {
    await _loadFonts();
    await tester.binding.setSurfaceSize(const Size(900, 1250));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_viewer('footer_test.docx'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(DocxView),
      matchesGoldenFile('goldens/footer_bottom.png'),
    );
  });

  // behindDoc image (מסגרת עמוד-שער) — הטקסט צריך להופיע *בתוך* המסגרת,
  // כרקע של העמוד, ולא כבלוק מעל הטקסט שדוחף אותו למטה.
  testWidgets('behindDoc frame renders as page background', (tester) async {
    await _loadFonts();
    // runAsync + delay מאפשר ל-DecorationImage (MemoryImage) להיטען בפועל,
    // כדי שה-golden יראה את המסגרת (רקע) עם הטקסט *בתוכה*.
    await tester.runAsync(() async {
      await tester.pumpWidget(_viewer('frame_test.docx'));
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await expectLater(
      find.byType(DocxView),
      matchesGoldenFile('goldens/frame_bg.png'),
    );
  });
}
