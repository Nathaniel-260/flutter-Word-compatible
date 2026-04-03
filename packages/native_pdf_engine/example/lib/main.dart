import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:native_pdf_engine/native_pdf_engine.dart';
import 'package:native_pdf_engine_example/viewer.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Uint8List? _pdfBytes;
  String _statusMessage = 'Keep calm and generate PDF';
  bool _isGenerating = false;

  final TextEditingController _htmlController = TextEditingController(
    text: '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HTML Text Styles Cheat Sheet</title>
    <style>
        /* Adding a little spacing so it's easy to read, 
           but leaving the text styles to their browser defaults */
        body {
            font-family: system-ui, -apple-system, sans-serif;
            margin: 40px auto;
            max-width: 800px;
            line-height: 1.6;
            color: #333;
        }
        .container {
            border: 1px solid #ccc;
            padding: 30px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        hr {
            margin: 30px 0;
            border: 0;
            border-top: 1px solid #eee;
        }
    </style>
</head>
<body>

    <div class="container">
        <h1>This is an Heading 1 (&lt;h1&gt;) - Main Title</h1>
        <h2>This is an Heading 2 (&lt;h2&gt;) - Section Title</h2>
        <h3>This is an Heading 3 (&lt;h3&gt;) - Subsection</h3>
        <h4>This is an Heading 4 (&lt;h4&gt;)</h4>
        <h5>This is an Heading 5 (&lt;h5&gt;)</h5>
        <h6>This is an Heading 6 (&lt;h6&gt;) - Lowest Level</h6>
        
        <hr>

        <h2>Paragraphs and Blocks</h2>
        
        <p>This is a standard paragraph (<code>&lt;p&gt;</code>). It is the most common way to display text on a webpage. Browsers automatically add some space before and after paragraphs.</p>
        
        <blockquote>
            This is a blockquote (<code>&lt;blockquote&gt;</code>). It is typically used to display long quotations from another source. Browsers usually indent it.
        </blockquote>

        <pre>
This is preformatted text (&lt;pre&gt;).
It preserves both      spaces 
and
line breaks exactly as they are written in the code.
        </pre>

        <hr>

        <h2>Inline Text Formatting</h2>
        
        <p><strong>Strong text (&lt;strong&gt;)</strong>: Used to indicate text with strong importance. Browsers render it as bold.</p>
        
        <p><b>Bold text (&lt;b&gt;)</b>: Used to draw attention to text without conveying extra importance. Also rendered as bold.</p>
        
        <p><em>Emphasized text (&lt;em&gt;)</em>: Used to indicate emphasis that changes the meaning of a sentence. Browsers render it as italics.</p>
        
        <p><i>Italic text (&lt;i&gt;)</i>: Used for technical terms, foreign phrases, or thoughts. Rendered as italics.</p>
        
        <p><mark>Marked text (&lt;mark&gt;)</mark>: Used to highlight text for reference purposes, like a yellow highlighter.</p>
        
        <p><small>Small text (&lt;small&gt;)</small>: Used for fine print or copyright notices.</p>
        
        <p><del>Deleted text (&lt;del&gt;)</del>: Used for text that has been removed. Browsers render it with a strikethrough.</p>
        
        <p><ins>Inserted text (&lt;ins&gt;)</ins>: Used for text that has been added. Browsers usually underline it.</p>
        
        <p><s>Strikethrough text (&lt;s&gt;)</s>: Used for text that is no longer relevant or accurate.</p>
        
        <p><u>Underlined text (&lt;u&gt;)</u>: Used to stylistically offset text, such as misspelled words.</p>
        
        <p>Water is H<sub>2</sub>O. (Subscript: <code>&lt;sub&gt;</code> - appears half a character below the normal line)</p>
        
        <p>E = mc<sup>2</sup>. (Superscript: <code>&lt;sup&gt;</code> - appears half a character above the normal line)</p>
    </div>

</body>
</html>
''',
  );
  final TextEditingController _urlController = TextEditingController(
    text: 'https://flutter.dev',
  );

  int _selectedTabIndex = 0;

  @override
  void dispose() {
    _htmlController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _generatePdf() async {
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating PDF...';
      _pdfBytes = null;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final targetPath = '${dir.path}/example.pdf';

      if (_selectedTabIndex == 0) {
        // HTML Mode
        await NativePdf.convert(_htmlController.text, targetPath);
        _pdfBytes = await File(targetPath).readAsBytes();
      } else {
        // URL Mode
        _pdfBytes = await NativePdf.convertUrlToData(_urlController.text);
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'PDF Generated Successfully at:\n$targetPath';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error generating PDF:\n$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Native PDF Engine Example')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Tab Selector
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 0,
                              label: Text('HTML'),
                              icon: Icon(Icons.code),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text('URL'),
                              icon: Icon(Icons.link),
                            ),
                          ],
                          selected: {_selectedTabIndex},
                          onSelectionChanged: (Set<int> newSelection) {
                            setState(() {
                              _selectedTabIndex = newSelection.first;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Input Area
                  SizedBox(
                    height: 150,
                    child: _selectedTabIndex == 0
                        ? TextField(
                            controller: _htmlController,
                            maxLines: null,
                            expands: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'HTML Content',
                              alignLabelWithHint: true,
                            ),
                            textAlignVertical: TextAlignVertical.top,
                          )
                        : TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'URL (e.g., https://example.com)',
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  if (_isGenerating)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _generatePdf,
                      child: const Text('Generate PDF'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _pdfBytes != null
                  ? MainPage(file: _pdfBytes!)
                  : Center(
                      child: Text(
                        'No PDF generated yet',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
