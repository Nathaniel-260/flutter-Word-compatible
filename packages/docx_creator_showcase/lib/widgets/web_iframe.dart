import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Embeds raw HTML (or a PDF, via a Blob URL) in an `<iframe>` so the
/// showcase app can show a genuine rendered preview - not just a downloaded
/// file - of what docx_creator's HTML/PDF exporters produce.
///
/// Each instance registers its own platform view factory keyed by
/// [viewType], since Flutter web's HtmlElementView requires the factory to
/// exist before the first build.
class WebIframe extends StatefulWidget {
  const WebIframe.html({super.key, required this.content})
      : _mimeType = null,
        _bytes = null;

  const WebIframe.pdf({super.key, required Uint8List this._bytes})
      : content = null,
        _mimeType = 'application/pdf';

  final String? content;
  final String? _mimeType;
  final Uint8List? _bytes;

  @override
  State<WebIframe> createState() => _WebIframeState();
}

class _WebIframeState extends State<WebIframe> {
  late final String _viewType;
  String? _objectUrl;

  @override
  void initState() {
    super.initState();
    _viewType = 'docx-creator-iframe-${identityHashCode(this)}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe = web.HTMLIFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';

      if (widget.content != null) {
        iframe.srcdoc = widget.content!.toJS;
      } else if (widget._bytes != null) {
        final url = web.URL.createObjectURL(
          web.Blob(
            <JSUint8Array>[widget._bytes!.toJS].toJS,
            web.BlobPropertyBag(type: widget._mimeType!),
          ),
        );
        _objectUrl = url;
        iframe.src = url;
      }
      return iframe;
    });
  }

  @override
  void dispose() {
    if (_objectUrl != null) web.URL.revokeObjectURL(_objectUrl!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
