import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:objective_c/objective_c.dart';

import 'native_pdf_engine_macos_bindings.dart';

class MacOSPdfEngine {
  MacOSPdfEngine._();

  // Keep strong references to prevent garbage collection
  static WKWebView? _activeWebView;
  static WKNavigationDelegate? _activeDelegate;
  static ObjCBlock<void Function(NSData?, NSError?)>? _activeCompletionHandler;

  static void cleanup() {
    _activeWebView = null;
    _activeDelegate = null;
    _activeCompletionHandler = null;
  }

  // macOS Implementation
  static void convertMacOS(
    String content, {
    String? outputPath,
    required bool isUrl,
    required void Function([dynamic result]) completeWithSuccess,
    required void Function(Exception error) completeWithError,
  }) {
    // Use Arena to automatically free native memory when done
    final arena = Arena();
    try {
      // Create WKWebViewConfiguration
      final config = WKWebViewConfiguration.alloc().init();

      // Create frame for the web view (1024x768 for PDF generation)
      final framePtr = arena<CGRect>();
      framePtr.ref.origin.x = 0;
      framePtr.ref.origin.y = 0;
      framePtr.ref.size.width = 1024;
      framePtr.ref.size.height = 768;

      // Create WKWebView
      final webView = WKWebView.alloc().initWithFrame$1(
        framePtr.ref,
        configuration: config,
      );

      // Create navigation delegate to handle page load completion
      final delegate = WKNavigationDelegate$Builder.implementAsListener(
        webView_didFinishNavigation_: (wv, navigation) {
          _handleMacOSNavigationFinished(
            wv,
            outputPath,
            completeWithSuccess: completeWithSuccess,
            completeWithError: completeWithError,
          );
        },
        webView_didFailNavigation_withError_: (wv, navigation, error) {
          completeWithError(
            Exception(
              'Navigation failed: ${error.localizedDescription.toDartString()}',
            ),
          );
        },
        webView_didFailProvisionalNavigation_withError_: (wv, navigation, error) {
          completeWithError(
            Exception(
              'Provisional navigation failed: ${error.localizedDescription.toDartString()}',
            ),
          );
        },
      );

      // Keep strong references to prevent GC
      _activeWebView = webView;
      _activeDelegate = delegate;

      webView.navigationDelegate = delegate;

      // Load content
      if (isUrl) {
        final nsUrl = NSURL.URLWithString(NSString(content));
        if (nsUrl == null) {
          completeWithError(Exception('Invalid URL: $content'));
          return;
        }
        final request = NSURLRequest.requestWithURL(nsUrl);
        webView.loadRequest(request);
      } else {
        webView.loadHTMLString(NSString(content), baseURL: null);
      }
    } catch (e) {
      completeWithError(Exception('macOS WebView setup failed: $e'));
    } finally {
      // Arena frees all native allocations (CGRect, etc.)
      arena.releaseAll();
    }
  }

  static void _handleMacOSNavigationFinished(
    WKWebView webView,
    String? outputPath, {
    required void Function([dynamic result]) completeWithSuccess,
    required void Function(Exception error) completeWithError,
  }) {
    try {
      // Create PDF configuration
      final pdfConfig = WKPDFConfiguration.alloc().init();

      // Create completion handler block
      final completionHandler = ObjCBlock_ffiVoid_NSData_NSError.listener((
        NSData? data,
        NSError? error,
      ) async {
        if (error != null) {
          completeWithError(
            Exception(
              'PDF generation failed: ${error.localizedDescription.toDartString()}',
            ),
          );
          return;
        }

        if (data != null) {
          try {
            final ptr = data.bytes.cast<Uint8>();
            final len = data.length;
            final bytes = Uint8List.fromList(ptr.asTypedList(len));
            if (outputPath != null) {
              await File(outputPath).writeAsBytes(bytes);
              completeWithSuccess();
            } else {
              completeWithSuccess(bytes);
            }
          } catch (e) {
            completeWithError(Exception('Failed to generate PDF: $e'));
          }
        } else {
          completeWithError(Exception('PDF data is null'));
        }
      });

      _activeCompletionHandler = completionHandler;

      webView.createPDFWithConfiguration(
        pdfConfig,
        completionHandler: completionHandler,
      );
    } catch (e) {
      completeWithError(Exception('macOS PDF generation setup failed: $e'));
    }
  }
}
