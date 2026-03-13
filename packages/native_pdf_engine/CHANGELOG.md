## 0.0.4
* Fixed clipping issues on Android by implementing dynamic height detection using `getContentHeight`.
* Improved rendering quality on Android by enabling `slowWholeDocumentDraw`.
* Enhanced page load detection and layout stability with precise delays.
* Optimized Android conversion logic for better reliability.

## 0.0.2
* Added `convertToData` and `convertUrlToData` to retrieve PDF data directly as `Uint8List`.
* Added `ByteArrayOutputStream` to Android bindings to support in-memory PDF generation.

## 0.0.1

* Initial release.
* Platform implementations for iOS (WKWebView), macOS (WKWebView), and Android (Pure JNI WebView).
* Support for converting HTML strings and URLs to PDF.
