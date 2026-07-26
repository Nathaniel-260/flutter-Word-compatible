import 'package:flutter/material.dart';

class _Feature {
  const _Feature(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;
}

const _features = [
  _Feature(Icons.edit_note, 'Fluent Builder API',
      'Chain methods to create headings, text, lists, tables, shapes, footnotes, and drop caps.'),
  _Feature(Icons.language, 'HTML -> DOCX',
      'Convert HTML (incl. 141 named CSS colors, tables, nested lists) into a full DOCX document.'),
  _Feature(Icons.article, 'Markdown -> DOCX',
      'Parse GitHub-Flavored Markdown, including aligned tables and nested lists, into DOCX.'),
  _Feature(Icons.description, 'DOCX -> HTML / Markdown / PDF',
      'Every document can be exported to Word, HTML, Markdown, or a pure-Dart-rendered PDF.'),
  _Feature(Icons.folder_open, 'DOCX & PDF Readers',
      'Load an existing .docx or .pdf file back into the same document model this app uses.'),
  _Feature(Icons.translate, 'Automatic Unicode Fallback Font',
      'PDF export auto-embeds a bundled font for Cyrillic/Greek/Vietnamese text with zero setup.'),
];

/// Landing screen: a short pitch plus a feature grid linking to each demo.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key, required this.onNavigate});

  final void Function(int index) onNavigate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('docx_creator',
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'A pure-Dart library for creating, reading, and converting '
            'DOCX documents — no native dependencies, works on every '
            'platform Dart runs on, including this web app.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.code, size: 18),
                label: const Text('View on pub.dev'),
                onPressed: () {},
              ),
              ActionChip(
                avatar: const Icon(Icons.book, size: 18),
                label: const Text('View source on GitHub'),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text('Explore every feature',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 220,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _features.length,
            itemBuilder: (context, index) {
              final feature = _features[index];
              return Card(
                child: InkWell(
                  onTap: () => onNavigate(index + 1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(feature.icon,
                            size: 28,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 8),
                        Text(feature.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        // Expanded (rather than a bare Text) so a longer
                        // description, a narrower card (more columns on a
                        // wide screen), or larger system font scaling clips
                        // with an ellipsis instead of throwing a RenderFlex
                        // overflow - the fixed mainAxisExtent grid cell
                        // can't grow to fit unbounded text.
                        Expanded(
                          child: Text(
                            feature.description,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
