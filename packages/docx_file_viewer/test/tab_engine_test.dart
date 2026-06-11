import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/src/layout/tab_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = TabEngine(); // default 720tw = 48px interval

  group('resolveStops', () {
    test('drops clear entries, sorts, converts twips→px', () {
      final p = DocxParagraph(tabStops: const [
        DocxTabStop(posTwips: 3000, alignment: DocxTabAlignment.right),
        DocxTabStop(posTwips: 1500, alignment: DocxTabAlignment.center),
        DocxTabStop(posTwips: 2000, alignment: DocxTabAlignment.clear),
      ]);
      final stops = engine.resolveStops(p);
      expect(stops.length, 2); // clear removed
      expect(stops[0].posPx, closeTo(100, 0.001)); // 1500/15
      expect(stops[0].alignment, DocxTabAlignment.center);
      expect(stops[1].posPx, closeTo(200, 0.001)); // 3000/15
    });

    test('bar stops are listed separately', () {
      final p = DocxParagraph(tabStops: const [
        DocxTabStop(posTwips: 1500, alignment: DocxTabAlignment.bar),
      ]);
      expect(engine.barStops(p), [closeTo(100, 0.001)]);
    });
  });

  group('position', () {
    final centerAt100 = [
      const ResolvedTabStop(posPx: 100, alignment: DocxTabAlignment.center),
    ];
    final rightAt100 = [
      const ResolvedTabStop(posPx: 100, alignment: DocxTabAlignment.right),
    ];
    final leftAt100 = [
      const ResolvedTabStop(posPx: 100, alignment: DocxTabAlignment.left),
    ];

    test('left tab: next segment starts at the stop', () {
      final segs = engine.position(
        widths: [20, 30],
        tabsBefore: [0, 1],
        stops: leftAt100,
      );
      expect(segs[0].start, 0);
      expect(segs[1].start, 100);
    });

    test('center tab: next segment is centered on the stop', () {
      final segs = engine.position(
        widths: [20, 30],
        tabsBefore: [0, 1],
        stops: centerAt100,
      );
      expect(segs[1].start, closeTo(85, 0.001)); // 100 - 30/2
    });

    test('right tab: next segment ends at the stop', () {
      final segs = engine.position(
        widths: [20, 30],
        tabsBefore: [0, 1],
        stops: rightAt100,
      );
      expect(segs[1].end, closeTo(100, 0.001));
    });

    test('no explicit stops → default 48px interval', () {
      final segs = engine.position(
        widths: [10, 5],
        tabsBefore: [0, 1],
        stops: const [],
      );
      // cursor after seg0 = 10 → next 48px multiple = 48.
      expect(segs[1].start, closeTo(48, 0.001));
    });

    test('"left⇥center⇥right" header line (the §C.3 DoD case)', () {
      final segs = engine.position(
        widths: [20, 30, 25],
        tabsBefore: [0, 1, 1],
        stops: const [
          ResolvedTabStop(posPx: 100, alignment: DocxTabAlignment.center),
          ResolvedTabStop(posPx: 200, alignment: DocxTabAlignment.right),
        ],
      );
      expect(segs[0].start, 0); // left flush
      expect(segs[1].start, closeTo(85, 0.001)); // centered on 100
      expect(segs[2].end, closeTo(200, 0.001)); // right at 200
    });

    test('segment never backs up over earlier content', () {
      // A wide segment whose right-align would overlap the previous one is
      // clamped to start right after it.
      final segs = engine.position(
        widths: [90, 40],
        tabsBefore: [0, 1],
        stops: rightAt100, // 100 - 40 = 60 < cursor(90) → clamp to 90
      );
      expect(segs[1].start, closeTo(90, 0.001));
      expect(segs[1].gapStart, closeTo(90, 0.001));
    });

    test('leader propagates from the matched stop', () {
      final segs = engine.position(
        widths: [10, 10],
        tabsBefore: [0, 1],
        stops: const [
          ResolvedTabStop(
            posPx: 100,
            alignment: DocxTabAlignment.right,
            leader: DocxTabLeader.dot,
          ),
        ],
      );
      expect(segs[1].leader, DocxTabLeader.dot);
      expect(segs[1].gapStart, closeTo(10, 0.001));
    });

    test('multiple consecutive tabs hop multiple stops', () {
      final segs = engine.position(
        widths: [10, 10],
        tabsBefore: [0, 2], // two tabs
        stops: const [
          ResolvedTabStop(posPx: 50, alignment: DocxTabAlignment.left),
          ResolvedTabStop(posPx: 120, alignment: DocxTabAlignment.left),
        ],
      );
      // first tab → 50, second tab → 120; left align there.
      expect(segs[1].start, closeTo(120, 0.001));
    });
  });
}
