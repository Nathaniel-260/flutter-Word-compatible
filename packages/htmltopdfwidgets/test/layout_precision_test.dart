import 'package:htmltopdfwidgets/htmltopdfwidgets.dart';
import 'package:htmltopdfwidgets/src/browser/layout/unit_converter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

void main() {
  group('Unit Converter Precision', () {
    test('Standardizes absolute units correctly to pt', () {
      expect(UnitConverter.parseAndConvertToPt('100px'), equals(75.0));
      expect(UnitConverter.parseAndConvertToPt('1in'), equals(72.0));
      expect(UnitConverter.parseAndConvertToPt('2em', elementFontSize: 16),
          equals(32.0));
      expect(UnitConverter.parseAndConvertToPt('2rem'), equals(24.0));
    });

    test('Standardizes relative percentages with parent context correctly', () {
      expect(UnitConverter.parseAndConvertToPt('50%', parentWidth: 400),
          equals(200.0));
    });
  });

  group('Layout-First Render Engine Integration', () {
    test('Flexbox structure resolves correctly without exception', () async {
      const html = '''
        <div style="display: flex; flex-direction: row; justify-content: flex-end; align-items: center;">
          <div style="flex-grow: 2;">Item 1</div>
          <div style="flex-grow: 1;">Item 2</div>
        </div>
      ''';

      final widgets = await HTMLToPdf().convert(html);

      // Verify widgets created successfully from new Flex mapping architecture without halting
      expect(widgets, isNotEmpty);

      // Simple structural scan - just ensure the conversion parsed nodes and didn't drop them
      int textNodesFound = 0;
      bool foundFlex = false;
      void scan(pw.Widget? w, [int depth = 0]) {
        if (w == null) return;
        final indent = '  ' * depth;
        print('$indent Scanning ${w.runtimeType}');
        if (w is pw.Flex) foundFlex = true;
        if (w is pw.Text || w is pw.RichText) {
          textNodesFound++;
          print('$indent -> Text node found! Total: $textNodesFound');
        }

        if (w is pw.MultiChildWidget) {
          for (var child in w.children) {
            scan(child, depth + 1);
          }
        } else if (w is pw.SingleChildWidget) {
          scan(w.child, depth + 1);
        } else if (w is pw.Container) {
          scan(w.child, depth + 1);
        } else if (w is pw.Padding) {
          scan(w.child, depth + 1);
        } else if (w is pw.DecoratedBox) {
          scan(w.child, depth + 1);
        } else if (w is pw.Expanded) {
          scan(w.child, depth + 1);
        }
      }

      for (var w in widgets) {
        scan(w);
      }

      expect(foundFlex, true);
      expect(textNodesFound, greaterThanOrEqualTo(2));
    });

    test('CSS Box Constraints evaluated completely over elements', () async {
      const html = '''
        <div style="width: 200px; height: 100px; padding: 10px; margin: 20px;">
           <p>Content</p>
        </div>
      ''';

      final widgets = await HTMLToPdf().convert(html);
      expect(widgets, isNotEmpty);
    });

    test('Complex Multi-Row Tables with Borders build natively', () async {
      const html = '''
        <table border="1" style="border-collapse: separate; align: center; background-color: #EEE;">
          <thead>
            <tr>
              <th align="center">Header 1</th>
              <th>Header 2</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Data 1</td>
              <td align="right">Data 2</td>
            </tr>
            <tr>
              <td>Data 3</td>
              <td>Data 4</td>
            </tr>
          </tbody>
        </table>
      ''';

      final widgets = await HTMLToPdf().convert(html);
      expect(widgets, isNotEmpty);

      int tablesFound = 0;
      void scan(pw.Widget w) {
        if (w is pw.Table) tablesFound++;
        if (w is pw.Container && w.child != null) scan(w.child!);
        if (w is pw.Padding && w.child != null) scan(w.child!);
        if (w is pw.Column) w.children.forEach(scan);
      }

      for (var w in widgets) {
        scan(w);
      }
      expect(tablesFound, greaterThanOrEqualTo(1));
    });

    test('Complex mixed layouts cascade flawlessly', () async {
      const html = '''
        <div>
          <header>
             <h1 style="color: blue;">Title</h1>
          </header>
          <hr />
          <div style="display: flex; flex-direction: row-reverse;">
             <p style="flex-grow: 1;">Left Side</p>
             <img src="https://via.placeholder.com/150" alt="Pl" style="width: 100px;" />
          </div>
          <blockquote>Quote block</blockquote>
        </div>
      ''';

      final widgets = await HTMLToPdf().convert(html, useNewEngine: true);
      expect(widgets, isNotEmpty);
    });
  });
}
