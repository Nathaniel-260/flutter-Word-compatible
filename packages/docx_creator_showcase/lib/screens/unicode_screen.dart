import 'package:flutter/material.dart';

import '../sample_data.dart';
import '../widgets/doc_preview_panel.dart';

/// Demonstrates the PDF exporter's automatic Unicode fallback font: text
/// in Cyrillic, Greek, and Vietnamese renders correctly with zero
/// configuration, via a bundled font embedded on first use.
class UnicodeScreen extends StatelessWidget {
  const UnicodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doc = SampleData.buildUnicodeDemoDocument();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Automatic Unicode Fallback Font',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Open the PDF tab below. No custom font was registered for '
            'this document, yet the Cyrillic, Greek, and Vietnamese text '
            'still renders correctly — docx_creator automatically embeds a '
            'bundled DejaVu Sans font the first time non-Latin text is '
            'encountered, with zero network or filesystem access.',
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DocPreviewPanel(document: doc, fileBaseName: 'unicode_demo'),
        ),
      ],
    );
  }
}
