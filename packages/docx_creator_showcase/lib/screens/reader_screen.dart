import 'package:docx_creator/docx_creator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../widgets/doc_preview_panel.dart';

/// Demonstrates DocxReader and PdfReader: upload an existing .docx or .pdf
/// file from your machine and see it parsed back into the same
/// DocxBuiltDocument model used everywhere else in this app.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  DocxBuiltDocument? _document;
  String? _loadedFileName;
  bool _loading = false;
  String? _error;

  Future<void> _pickAndLoad(List<String> extensions) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: extensions,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw StateError('No bytes returned for the selected file.');
      }

      final DocxBuiltDocument doc;
      if (file.extension?.toLowerCase() == 'pdf') {
        final pdf = await PdfReader.loadFromBytes(bytes);
        doc = pdf.toDocx();
      } else {
        doc = await DocxReader.loadFromBytes(bytes);
      }

      setState(() {
        _document = doc;
        _loadedFileName = file.name;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'DOCX & PDF Readers',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload an existing .docx or .pdf file. DocxReader/PdfReader '
            'parse it into the same DocxBuiltDocument model used everywhere '
            'in this app, so you can immediately re-export it to any '
            'other format below.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _loading ? null : () => _pickAndLoad(['docx']),
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload .docx'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _pickAndLoad(['pdf']),
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload .pdf'),
              ),
              if (_loading) ...[
                const SizedBox(width: 16),
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child:
                  Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _document == null
                ? const Center(
                    child: Text('Upload a file above to see it rendered.'))
                : DocPreviewPanel(
                    document: _document!,
                    fileBaseName: (_loadedFileName ?? 'uploaded')
                        .replaceAll(RegExp(r'\.[^.]+$'), ''),
                  ),
          ),
        ],
      ),
    );
  }
}
