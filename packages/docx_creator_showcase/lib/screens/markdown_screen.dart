import 'package:docx_creator/docx_creator.dart';
import 'package:flutter/material.dart';

import '../sample_data.dart';
import '../widgets/doc_preview_panel.dart';

/// Demonstrates the Markdown -> DOCX parser: paste/edit Markdown on the
/// left, convert it, and see the resulting document (and every export
/// format) on the right.
class MarkdownScreen extends StatefulWidget {
  const MarkdownScreen({super.key});

  @override
  State<MarkdownScreen> createState() => _MarkdownScreenState();
}

class _MarkdownScreenState extends State<MarkdownScreen> {
  final _controller = TextEditingController(text: SampleData.sampleMarkdown);
  DocxBuiltDocument? _document;
  bool _converting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _convert();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    setState(() {
      _converting = true;
      _error = null;
    });
    try {
      final elements = await MarkdownParser.parse(_controller.text);
      setState(() => _document = DocxBuiltDocument(elements: elements));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _converting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Markdown -> DOCX Parser',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Edit the Markdown below (GFM tables with '
                    'alignment, nested lists, task lists, and code blocks '
                    'are all supported) and press Convert.'),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _converting ? null : _convert,
                  icon: _converting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.transform),
                  label: const Text('Convert to DOCX'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: _document == null
                ? const Center(child: Text('Converting...'))
                : DocPreviewPanel(
                    document: _document!, fileBaseName: 'from_markdown'),
          ),
        ],
      ),
    );
  }
}
