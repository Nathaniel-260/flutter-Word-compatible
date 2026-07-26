import 'package:flutter/material.dart';

import '../sample_data.dart';
import '../widgets/doc_preview_panel.dart';

/// Demonstrates the fluent [DocxDocumentBuilder] API: headings, styled
/// text, lists, tables, shapes, footnotes, and a drop cap, all built in
/// Dart with no HTML/Markdown involved.
class BuilderScreen extends StatelessWidget {
  const BuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doc = SampleData.buildDemoDocument();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Fluent Builder API',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Every element below — headings, bold/italic/underline text, '
            'superscript/subscript, bullet & numbered lists, a table, a '
            'shape, a footnote, a drop cap, and a blockquote — was created '
            'with docx() chained method calls. Switch tabs to see the exact '
            'same document exported to HTML, Markdown, and PDF.',
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DocPreviewPanel(document: doc, fileBaseName: 'builder_demo'),
        ),
      ],
    );
  }
}
