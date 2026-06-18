import 'package:docx_file_viewer/src/font_loader/font_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan §L.1–§L.3: script classification (Hebrew/Arabic vs Latin), Word-name →
/// available-family resolution, and per-script fallback chains.
void main() {
  group('classifyScript', () {
    test('empty string yields no runs', () {
      expect(classifyScript(''), isEmpty);
    });

    test('pure Latin is one Latin run', () {
      final runs = classifyScript('Hello');
      expect(runs, hasLength(1));
      expect(runs.single.script, DocxScript.latin);
      expect(runs.single.start, 0);
      expect(runs.single.end, 5);
    });

    test('pure Hebrew is one complex run', () {
      final runs = classifyScript('שלום');
      expect(runs, hasLength(1));
      expect(runs.single.script, DocxScript.complex);
    });

    test('"שלום Hello עולם" splits into 3 runs, spaces stay with the word', () {
      const text = 'שלום Hello עולם';
      final runs = classifyScript(text);
      expect(runs, hasLength(3));

      expect(runs[0].script, DocxScript.complex);
      expect(text.substring(runs[0].start, runs[0].end), 'שלום ');

      expect(runs[1].script, DocxScript.latin);
      expect(text.substring(runs[1].start, runs[1].end), 'Hello ');

      expect(runs[2].script, DocxScript.complex);
      expect(text.substring(runs[2].start, runs[2].end), 'עולם');
    });

    test('runs tile the input exactly', () {
      const text = 'a ב c ד';
      final runs = classifyScript(text);
      expect(runs.first.start, 0);
      expect(runs.last.end, text.length);
      for (var i = 1; i < runs.length; i++) {
        expect(runs[i].start, runs[i - 1].end);
      }
    });

    test('ASCII digits are Latin (Word keeps 0-9 in the ascii font)', () {
      final runs = classifyScript('א5');
      expect(runs, hasLength(2));
      expect(runs[0].script, DocxScript.complex); // א
      expect(runs[1].script, DocxScript.latin); // 5
    });

    test('interior punctuation between Hebrew stays complex', () {
      final runs = classifyScript('א.ב');
      expect(runs, hasLength(1));
      expect(runs.single.script, DocxScript.complex);
    });

    test('all-neutral defaults to Latin, but hint=cs forces complex', () {
      expect(classifyScript('. ').single.script, DocxScript.latin);
      expect(
        classifyScript('. ', hintComplex: true).single.script,
        DocxScript.complex,
      );
    });

    test('hint=cs does not override strong Latin letters', () {
      final runs = classifyScript('Hi', hintComplex: true);
      expect(runs.single.script, DocxScript.latin);
    });
  });

  group('FontResolver.resolve', () {
    // Force "nothing is installed" so the built-in substitution branch is
    // exercised deterministically regardless of the host's system fonts.
    FontResolver none({Map<String, String> subs = const {}}) =>
        FontResolver(substitutions: subs, isAvailable: (_) => false);

    test('null / blank → null', () {
      expect(none().resolve(null), isNull);
      expect(none().resolve('   '), isNull);
    });

    test('built-in metric clones', () {
      final r = none();
      expect(r.resolve('Calibri'), 'Carlito');
      expect(r.resolve('Cambria'), 'Caladea');
      expect(r.resolve('Times New Roman'), 'Tinos');
      expect(r.resolve('Arial'), 'Arimo');
      expect(r.resolve('Courier New'), 'Cousine');
      expect(r.resolve('David'), 'David Libre');
      expect(r.resolve('Narkisim'), 'Frank Ruhl Libre');
    });

    test('substitution table is case-insensitive', () {
      expect(none().resolve('CALIBRI'), 'Carlito');
      expect(none().resolve('  calibri '), 'Carlito');
    });

    test('unknown family is kept as-is', () {
      expect(none().resolve('Some Custom Font'), 'Some Custom Font');
    });

    test('an available family is kept (beats the built-in clone)', () {
      final r = FontResolver(isAvailable: (f) => f == 'Arial');
      expect(r.resolve('Arial'), 'Arial');
      expect(
          r.resolve('Calibri'), 'Carlito'); // still substituted (unavailable)
    });

    test('explicit user substitution wins over everything', () {
      final r = FontResolver(
        substitutions: {'Calibri': 'HostCalibri'},
        isAvailable: (_) => true, // even when "available"
      );
      expect(r.resolve('Calibri'), 'HostCalibri');
    });
  });

  group('FontResolver.fallbacksFor', () {
    test('Latin uses only the host fallbacks (Latin layout unchanged)', () {
      final r = FontResolver(extraFallbacks: const ['Roboto', 'Arial']);
      expect(r.fallbacksFor(DocxScript.latin), ['Roboto', 'Arial']);
    });

    test('complex prepends Hebrew families, then the host fallbacks', () {
      final r = FontResolver(extraFallbacks: const ['Roboto']);
      final fb = r.fallbacksFor(DocxScript.complex);
      expect(fb.first, 'David Libre');
      expect(fb, contains('Noto Sans Hebrew'));
      expect(fb.last, 'Roboto');
    });
  });
}
