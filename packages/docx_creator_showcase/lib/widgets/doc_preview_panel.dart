import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:flutter/foundation.dart' show ComputeCallback, compute;
import 'package:flutter/material.dart';

import 'web_iframe.dart';

/// The core reusable piece of the showcase: given any [DocxBuiltDocument],
/// shows every export format docx_creator supports side by side - a native
/// rendered DOCX preview, the generated HTML (source + live rendered
/// iframe), the generated Markdown source, and an embedded PDF preview -
/// plus one-click downloads for each.
///
/// Every demo screen in this app funnels its document through this same
/// widget, so "HTML viewer", "Markdown viewer", etc. are each implemented
/// exactly once.
class DocPreviewPanel extends StatefulWidget {
  const DocPreviewPanel({super.key, required this.document, this.fileBaseName = 'document'});

  final DocxBuiltDocument document;
  final String fileBaseName;

  @override
  State<DocPreviewPanel> createState() => _DocPreviewPanelState();
}

class _DocPreviewPanelState extends State<DocPreviewPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.description_outlined), text: 'DOCX Preview'),
            Tab(icon: Icon(Icons.code), text: 'HTML'),
            Tab(icon: Icon(Icons.article_outlined), text: 'Markdown'),
            Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'PDF'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _DocxPreviewTab(document: widget.document, fileBaseName: widget.fileBaseName),
              _HtmlTab(document: widget.document, fileBaseName: widget.fileBaseName),
              _MarkdownTab(document: widget.document, fileBaseName: widget.fileBaseName),
              _PdfTab(document: widget.document, fileBaseName: widget.fileBaseName),
            ],
          ),
        ),
      ],
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.download),
          label: Text(label),
        ),
      ),
    );
  }
}

// Top-level (isolate-callable) export functions. `compute()` requires a
// top-level or static function so it can be shipped to a background
// isolate/web worker - the actual generation work (DOCX zip/PDF page
// layout/HTML+Markdown conversion) is real CPU work that used to run
// synchronously inside a build() method on the UI thread, which is what
// made switching tabs (or screens - see _Shell in main.dart) feel like the
// app was stuck.
String _computeHtml(DocxBuiltDocument doc) => HtmlExporter().export(doc);

String _computeMarkdown(DocxBuiltDocument doc) => MarkdownExporter().export(doc);

Uint8List _computePdfBytes(DocxBuiltDocument doc) => PdfExporter().exportToBytes(doc);

Future<Uint8List> _computeDocxBytes(DocxBuiltDocument doc) =>
    DocxExporter().exportToBytes(doc);

/// Runs [job] for [document] on a background isolate exactly once, caching
/// the result for the widget's lifetime and only recomputing if [document]
/// is replaced with a different instance (not merely rebuilt).
class _ExportFuture<T> extends StatefulWidget {
  const _ExportFuture({
    required this.document,
    required this.job,
    required this.builder,
  });

  final DocxBuiltDocument document;
  final ComputeCallback<DocxBuiltDocument, T> job;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<_ExportFuture<T>> createState() => _ExportFutureState<T>();
}

class _ExportFutureState<T> extends State<_ExportFuture<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = compute(widget.job, widget.document);
  }

  @override
  void didUpdateWidget(covariant _ExportFuture<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.document, widget.document)) {
      _future = compute(widget.job, widget.document);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Export failed: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return widget.builder(context, snapshot.data as T);
      },
    );
  }
}

class _DocxPreviewTab extends StatelessWidget {
  const _DocxPreviewTab({required this.document, required this.fileBaseName});

  final DocxBuiltDocument document;
  final String fileBaseName;

  @override
  Widget build(BuildContext context) {
    return _ExportFuture<Uint8List>(
      document: document,
      job: _computeDocxBytes,
      builder: (context, bytes) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DownloadButton(
            label: 'Download .docx',
            onPressed: () =>
                DocxExporter().exportToFile(document, '$fileBaseName.docx'),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
              child: DocxView.bytes(
                bytes,
                config: const DocxViewConfig(
                    enableSearch: false, enableZoom: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HtmlTab extends StatelessWidget {
  const _HtmlTab({required this.document, required this.fileBaseName});

  final DocxBuiltDocument document;
  final String fileBaseName;

  @override
  Widget build(BuildContext context) {
    return _ExportFuture<String>(
      document: document,
      job: _computeHtml,
      builder: (context, html) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DownloadButton(
            label: 'Download .html',
            onPressed: () =>
                HtmlExporter().exportToFile(document, '$fileBaseName.html'),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(left: 8, right: 4, bottom: 8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
                    child: WebIframe.html(content: html),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(left: 4, right: 8, bottom: 8),
                    padding: const EdgeInsets.all(8),
                    color: const Color(0xFF1E1E1E),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        html,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownTab extends StatelessWidget {
  const _MarkdownTab({required this.document, required this.fileBaseName});

  final DocxBuiltDocument document;
  final String fileBaseName;

  @override
  Widget build(BuildContext context) {
    return _ExportFuture<String>(
      document: document,
      job: _computeMarkdown,
      builder: (context, markdown) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DownloadButton(
            label: 'Download .md',
            onPressed: () =>
                MarkdownExporter().exportToFile(document, '$fileBaseName.md'),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
              child: SingleChildScrollView(
                child: SelectableText(
                  markdown,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfTab extends StatelessWidget {
  const _PdfTab({required this.document, required this.fileBaseName});

  final DocxBuiltDocument document;
  final String fileBaseName;

  @override
  Widget build(BuildContext context) {
    return _ExportFuture<Uint8List>(
      document: document,
      job: _computePdfBytes,
      builder: (context, bytes) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DownloadButton(
            label: 'Download .pdf',
            onPressed: () =>
                PdfExporter().exportToFile(document, '$fileBaseName.pdf'),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
              child: WebIframe.pdf(bytes: bytes),
            ),
          ),
        ],
      ),
    );
  }
}
