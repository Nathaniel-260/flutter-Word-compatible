/// Native PDF Engine - HTML to PDF conversion using native OS webviews
///
/// Supports iOS and macOS platforms only.
library;

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:jni/jni.dart' as jni;
import 'package:jni/jni.dart';
import 'package:objective_c/objective_c.dart' as objc;

import 'src/android/android/view/View.dart' as androidview;
import 'src/android/android/webkit/WebView.dart' as androidwebkit;
import 'src/android/java/lang/Runnable.dart' as javalang;
import 'src/android_bindings.dart' as android;
import 'src/native_pdf_engine_ios_bindings.dart' as ios;
import 'src/native_pdf_engine_linux.dart' as linux;
import 'src/native_pdf_engine_macos_bindings.dart' as macos;
import 'src/native_pdf_engine_windows.dart' as windows;

/// High-level PDF generation API for iOS and macOS.
///
/// This class provides static methods to convert HTML content or URLs to PDF files
/// using native WebKit components for optimal performance and memory efficiency.
class NativePdf {
  NativePdf._(); // Prevent instantiation

  static Completer<dynamic>? _pendingCompleter;

  // Keep strong references to prevent garbage collection
  static Object? _activeWebView;
  static Object? _activeDelegate;
  static String? _activeOutputPath;
  static Object? _activeCompletionHandler;

  /// Convert HTML string to PDF file.
  ///
  /// [html] - The HTML content to convert.
  /// [outputPath] - The file path where the PDF will be saved.
  ///
  /// Returns a [Future] that completes when the PDF has been generated.
  /// Throws [Exception] on failure.
  static Future<void> convert(String html, String outputPath) async {
    if (_pendingCompleter != null) {
      throw StateError('A PDF generation is already in progress');
    }
    _pendingCompleter = Completer<void>();
    _activeOutputPath = outputPath;

    try {
      if (Platform.isIOS) {
        _convertIOS(html, outputPath: outputPath, isUrl: false);
      } else if (Platform.isMacOS) {
        _convertMacOS(html, outputPath: outputPath, isUrl: false);
      } else if (Platform.isAndroid) {
        _convertAndroid(html, outputPath: outputPath, isUrl: false);
      } else if (Platform.isWindows) {
        await windows.NativePdfWindows.convert(
          html,
          outputPath: outputPath,
          isUrl: false,
        );
      } else if (Platform.isLinux) {
        await linux.NativePdfLinux.convert(
          html,
          outputPath: outputPath,
          isUrl: false,
        );
      } else {
        throw UnsupportedError(
          'Platform not supported. Supported: iOS, macOS, Android, Windows, Linux.',
        );
      }
      await _pendingCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'PDF generation timed out after 30 seconds',
            const Duration(seconds: 30),
          );
        },
      );
    } finally {
      _cleanup();
    }
  }

  /// Convert URL to PDF file.
  ///
  /// [url] - The URL to capture (e.g., https://example.com).
  /// [outputPath] - The file path where the PDF will be saved.
  ///
  /// Returns a [Future] that completes when the PDF has been generated.
  /// Throws [Exception] on failure.
  static Future<void> convertUrl(String url, String outputPath) async {
    if (_pendingCompleter != null) {
      throw StateError('A PDF generation is already in progress');
    }
    _pendingCompleter = Completer<void>();
    _activeOutputPath = outputPath;

    try {
      if (Platform.isIOS) {
        _convertIOS(url, outputPath: outputPath, isUrl: true);
      } else if (Platform.isMacOS) {
        _convertMacOS(url, outputPath: outputPath, isUrl: true);
      } else if (Platform.isAndroid) {
        _convertAndroid(url, outputPath: outputPath, isUrl: true);
      } else if (Platform.isWindows) {
        await windows.NativePdfWindows.convert(
          url,
          outputPath: outputPath,
          isUrl: true,
        );
      } else if (Platform.isLinux) {
        await linux.NativePdfLinux.convert(
          url,
          outputPath: outputPath,
          isUrl: true,
        );
      } else {
        throw UnsupportedError(
          'Platform not supported. Supported: iOS, macOS, Android, Windows, Linux.',
        );
      }
      await _pendingCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'PDF generation timed out after 30 seconds',
            const Duration(seconds: 30),
          );
        },
      );
    } finally {
      _cleanup();
    }
  }

  /// Convert HTML string to PDF data.
  ///
  /// [html] - The HTML content to convert.
  ///
  /// Returns a [Future] that completes with the PDF data as [Uint8List].
  /// Throws [Exception] on failure.
  static Future<Uint8List> convertToData(String html) async {
    if (_pendingCompleter != null) {
      throw StateError('A PDF generation is already in progress');
    }
    _pendingCompleter = Completer<Uint8List>();
    _activeOutputPath = null;

    try {
      if (Platform.isIOS) {
        _convertIOS(html, isUrl: false);
      } else if (Platform.isMacOS) {
        _convertMacOS(html, isUrl: false);
      } else if (Platform.isAndroid) {
        _convertAndroid(html, isUrl: false);
      } else if (Platform.isWindows) {
        final result = await windows.NativePdfWindows.convert(
          html,
          outputPath: null,
          isUrl: false,
        );
        return result ?? Uint8List(0);
      } else if (Platform.isLinux) {
        final result = await linux.NativePdfLinux.convert(
          html,
          outputPath: null,
          isUrl: false,
        );
        return result ?? Uint8List(0);
      } else {
        throw UnsupportedError(
          'Platform not supported. Supported: iOS, macOS, Android, Windows, Linux.',
        );
      }
      return await _pendingCompleter!.future.timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'PDF generation timed out after 30 seconds',
                const Duration(seconds: 30),
              );
            },
          )
          as Uint8List;
    } finally {
      _cleanup();
    }
  }

  /// Convert URL to PDF data.
  ///
  /// [url] - The URL to capture (e.g., https://example.com).
  ///
  /// Returns a [Future] that completes with the PDF data as [Uint8List].
  /// Throws [Exception] on failure.
  static Future<Uint8List> convertUrlToData(String url) async {
    if (_pendingCompleter != null) {
      throw StateError('A PDF generation is already in progress');
    }
    _pendingCompleter = Completer<Uint8List>();
    _activeOutputPath = null;

    try {
      if (Platform.isIOS) {
        _convertIOS(url, isUrl: true);
      } else if (Platform.isMacOS) {
        _convertMacOS(url, isUrl: true);
      } else if (Platform.isAndroid) {
        _convertAndroid(url, isUrl: true);
      } else if (Platform.isWindows) {
        final result = await windows.NativePdfWindows.convert(
          url,
          outputPath: null,
          isUrl: true,
        );
        return result ?? Uint8List(0);
      } else if (Platform.isLinux) {
        final result = await linux.NativePdfLinux.convert(
          url,
          outputPath: null,
          isUrl: true,
        );
        return result ?? Uint8List(0);
      } else {
        throw UnsupportedError(
          'Platform not supported. Supported: iOS, macOS, Android, Windows, Linux.',
        );
      }
      return await _pendingCompleter!.future.timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'PDF generation timed out after 30 seconds',
                const Duration(seconds: 30),
              );
            },
          )
          as Uint8List;
    } finally {
      _cleanup();
    }
  }

  static void _cleanup() {
    _pendingCompleter = null;
    _activeWebView = null;
    _activeDelegate = null;
    _activeOutputPath = null;
    _activeCompletionHandler = null;
  }

  static void _completeWithSuccess([dynamic result]) {
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete(result);
    }
  }

  static void _completeWithError(Object error) {
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.completeError(error);
    }
  }
}

// iOS Implementation
void _convertIOS(String content, {String? outputPath, required bool isUrl}) {
  // Use Arena to automatically free native memory when done
  final arena = Arena();
  try {
    // Create WKWebViewConfiguration
    final config = ios.WKWebViewConfiguration.alloc().init();

    // Create frame for the web view (1024x768 for PDF generation)
    final framePtr = arena<objc.CGRect>();
    framePtr.ref.origin.x = 0;
    framePtr.ref.origin.y = 0;
    framePtr.ref.size.width = 1024;
    framePtr.ref.size.height = 768;

    // Create WKWebView
    final webView = ios.WKWebView.alloc().initWithFrame$1(
      framePtr.ref,
      configuration: config,
    );

    // Create navigation delegate to handle page load completion
    final delegate = ios.WKNavigationDelegate$Builder.implementAsListener(
      webView_didFinishNavigation_: (wv, navigation) {
        _handleIOSNavigationFinished(wv, outputPath);
      },
      webView_didFailNavigation_withError_: (wv, navigation, error) {
        NativePdf._completeWithError(
          Exception(
            'Navigation failed: ${error.localizedDescription.toDartString()}',
          ),
        );
      },
      webView_didFailProvisionalNavigation_withError_: (wv, navigation, error) {
        NativePdf._completeWithError(
          Exception(
            'Provisional navigation failed: ${error.localizedDescription.toDartString()}',
          ),
        );
      },
    );

    // Keep strong references to prevent GC
    NativePdf._activeWebView = webView;
    NativePdf._activeDelegate = delegate;

    webView.navigationDelegate = delegate;

    // Load content
    if (isUrl) {
      final nsUrl = objc.NSURL.URLWithString(objc.NSString(content));
      if (nsUrl == null) {
        NativePdf._completeWithError(Exception('Invalid URL: $content'));
        return;
      }
      final request = ios.NSURLRequest.requestWithURL(nsUrl);
      webView.loadRequest(request);
    } else {
      webView.loadHTMLString(objc.NSString(content), baseURL: null);
    }
  } catch (e) {
    NativePdf._completeWithError(Exception('iOS WebView setup failed: $e'));
  } finally {
    // Arena frees all native allocations (CGRect, etc.)
    arena.releaseAll();
  }
}

void _handleIOSNavigationFinished(ios.WKWebView webView, String? outputPath) {
  try {
    // Create PDF configuration
    final pdfConfig = ios.WKPDFConfiguration.alloc().init();

    // Create completion handler block
    final completionHandler = ios.ObjCBlock_ffiVoid_NSData_NSError.listener((
      objc.NSData? data,
      objc.NSError? error,
    ) async {
      if (error != null) {
        NativePdf._completeWithError(
          Exception(
            'PDF generation failed: ${error.localizedDescription.toDartString()}',
          ),
        );
        return;
      }

      if (data != null) {
        try {
          final ptr = data.bytes.cast<ffi.Uint8>();
          final len = data.length;
          final bytes = Uint8List.fromList(ptr.asTypedList(len));
          if (outputPath != null) {
            await File(outputPath).writeAsBytes(bytes);
            NativePdf._completeWithSuccess();
          } else {
            NativePdf._completeWithSuccess(bytes);
          }
        } catch (e) {
          NativePdf._completeWithError(Exception('Failed to generate PDF: $e'));
        }
      } else {
        NativePdf._completeWithError(Exception('PDF data is null'));
      }
    });

    NativePdf._activeCompletionHandler = completionHandler;

    webView.createPDFWithConfiguration(
      pdfConfig,
      completionHandler: completionHandler,
    );
  } catch (e) {
    NativePdf._completeWithError(
      Exception('iOS PDF generation setup failed: $e'),
    );
  }
}

// macOS Implementation
void _convertMacOS(String content, {String? outputPath, required bool isUrl}) {
  // Use Arena to automatically free native memory when done
  final arena = Arena();
  try {
    // Create WKWebViewConfiguration
    final config = macos.WKWebViewConfiguration.alloc().init();

    // Create frame for the web view (1024x768 for PDF generation)
    final framePtr = arena<objc.CGRect>();
    framePtr.ref.origin.x = 0;
    framePtr.ref.origin.y = 0;
    framePtr.ref.size.width = 1024;
    framePtr.ref.size.height = 768;

    // Create WKWebView
    final webView = macos.WKWebView.alloc().initWithFrame$1(
      framePtr.ref,
      configuration: config,
    );

    // Create navigation delegate to handle page load completion
    final delegate = macos.WKNavigationDelegate$Builder.implementAsListener(
      webView_didFinishNavigation_: (wv, navigation) {
        _handleMacOSNavigationFinished(wv, outputPath);
      },
      webView_didFailNavigation_withError_: (wv, navigation, error) {
        NativePdf._completeWithError(
          Exception(
            'Navigation failed: ${error.localizedDescription.toDartString()}',
          ),
        );
      },
      webView_didFailProvisionalNavigation_withError_: (wv, navigation, error) {
        NativePdf._completeWithError(
          Exception(
            'Provisional navigation failed: ${error.localizedDescription.toDartString()}',
          ),
        );
      },
    );

    // Keep strong references to prevent GC
    NativePdf._activeWebView = webView;
    NativePdf._activeDelegate = delegate;

    webView.navigationDelegate = delegate;

    // Load content
    if (isUrl) {
      final nsUrl = objc.NSURL.URLWithString(objc.NSString(content));
      if (nsUrl == null) {
        NativePdf._completeWithError(Exception('Invalid URL: $content'));
        return;
      }
      final request = macos.NSURLRequest.requestWithURL(nsUrl);
      webView.loadRequest(request);
    } else {
      webView.loadHTMLString(objc.NSString(content), baseURL: null);
    }
  } catch (e) {
    NativePdf._completeWithError(Exception('macOS WebView setup failed: $e'));
  } finally {
    // Arena frees all native allocations (CGRect, etc.)
    arena.releaseAll();
  }
}

void _handleMacOSNavigationFinished(
  macos.WKWebView webView,
  String? outputPath,
) {
  try {
    // Create PDF configuration
    final pdfConfig = macos.WKPDFConfiguration.alloc().init();

    // Create completion handler block
    final completionHandler = macos.ObjCBlock_ffiVoid_NSData_NSError.listener((
      objc.NSData? data,
      objc.NSError? error,
    ) async {
      if (error != null) {
        NativePdf._completeWithError(
          Exception(
            'PDF generation failed: ${error.localizedDescription.toDartString()}',
          ),
        );
        return;
      }

      if (data != null) {
        try {
          final ptr = data.bytes.cast<ffi.Uint8>();
          final len = data.length;
          final bytes = Uint8List.fromList(ptr.asTypedList(len));
          if (outputPath != null) {
            await File(outputPath).writeAsBytes(bytes);
            NativePdf._completeWithSuccess();
          } else {
            NativePdf._completeWithSuccess(bytes);
          }
        } catch (e) {
          NativePdf._completeWithError(Exception('Failed to generate PDF: $e'));
        }
      } else {
        NativePdf._completeWithError(Exception('PDF data is null'));
      }
    });

    NativePdf._activeCompletionHandler = completionHandler;

    webView.createPDFWithConfiguration(
      pdfConfig,
      completionHandler: completionHandler,
    );
  } catch (e) {
    NativePdf._completeWithError(
      Exception('macOS PDF generation setup failed: $e'),
    );
  }
}

// Android Implementation
void _convertAndroid(
  String content, {
  String? outputPath,
  required bool isUrl,
}) async {
  try {
    final activity = jni.Jni.androidActivity(
      PlatformDispatcher.instance.engineId!,
    );
    if (activity == null) {
      NativePdf._completeWithError(
        Exception('Android Activity is null. Engine not attached?'),
      );
      return;
    }

    // Cast to strongly typed Activity
    final androidActivity = android.Activity.fromReference(activity.reference);

    // Use a Completer to bridge the async gap from the UI thread callback
    final completer = Completer<Uint8List?>();

    // Implement Runnable
    final runnable = javalang.Runnable.implement(
      javalang.$Runnable(
        run: () async {
          android.PdfDocument? pdfDoc;
          android.FileOutputStream? fos;
          android.ByteArrayOutputStream? bos;
          try {
            // 1. Create WebView
            final androidContext = android.Context.fromReference(
              androidActivity.reference,
            );

            // Enable slow whole document draw for Android L and above to capture full document
            androidwebkit.WebView.enableSlowWholeDocumentDraw();

            final webView = android.WebView(androidContext);
            NativePdf._activeWebView = webView; // Keep reference

            // 2. Configure Settings
            final settings = webView.getSettings();
            settings?.setJavaScriptEnabled(true);
            settings?.setDomStorageEnabled(true);

            // 3. Set layout manually to fixed width, height will be adjusted later
            final width = 1024;
            int height = 768; // Initial height

            // Cast WebView to View to access layout() and draw()
            final webViewAsView = androidview.View.fromReference(
              webView.reference,
            );

            // Force initial layout
            webViewAsView.layout(0, 0, width, height);

            // 4. Load Content
            if (isUrl) {
              webView.loadUrl(content.toJString());
            } else {
              webView.loadDataWithBaseURL(
                jni.JString.fromString(""),
                content.toJString(),
                "text/html".toJString(),
                "utf-8".toJString(),
                jni.JString.fromString(""),
              );
            }

            // Ensure page is fully loaded
            int attempts = 0;
            while ((webView.getProgress() < 100) && attempts < 100) {
              // 10s timeout
              await Future.delayed(Duration(milliseconds: 100));
              attempts++;
            }

            // Allow a bit more time for rendering after 100%
            await Future.delayed(Duration(milliseconds: 1000));

            // Adjust layout height based on content
            final contentHeight = webView.getContentHeight();
            if (contentHeight > 0) {
              height = (contentHeight * 2.0).toInt() + 100;
              if (height < 768) height = 768;
              webViewAsView.layout(0, 0, width, height);

              // Wait for layout to settle
              await Future.delayed(Duration(milliseconds: 200));
            }

            // 6. Generate PDF
            pdfDoc = android.PdfDocument();

            // Page Info
            final pageBuilder = android.PdfDocument$PageInfo$Builder(
              width,
              height,
              1,
            );
            final pageInfo = pageBuilder.create();

            // Start Page
            final page = pdfDoc.startPage(pageInfo);
            final canvas = page?.getCanvas();

            if (canvas != null) {
              // Draw WebView to Canvas
              webViewAsView.draw(canvas);
            }

            pdfDoc.finishPage(page);

            if (outputPath != null) {
              // 7. Write to file
              final file = android.File.new$1(outputPath.toJString());
              fos = android.FileOutputStream(file);
              pdfDoc.writeTo(fos);
              fos.close();
              fos = null; // Mark as closed
              completer.complete(null);
            } else {
              // Write to ByteArrayOutputStream
              bos = android.ByteArrayOutputStream();
              pdfDoc.writeTo(bos);
              final bytes = bos.toByteArray();

              final int count = bytes!.length;
              final uint8List = Uint8List(count);
              for (var i = 0; i < count; i++) {
                uint8List[i] = bytes[i] & 0xFF; // Handle signed byte
              }

              bos.close();
              bos = null; // Mark as closed
              completer.complete(uint8List);
            }
          } catch (e) {
            completer.completeError(e);
          } finally {
            // Release all JNI/native resources
            try {
              fos?.close();
            } catch (_) {}
            try {
              bos?.close();
            } catch (_) {}
            try {
              pdfDoc?.close();
            } catch (_) {}
            // WebView reference is cleaned up via NativePdf._cleanup()
          }
        },
      ),
    );

    // Execute on UI Thread
    androidActivity.runOnUiThread(runnable);

    // Wait for completion
    try {
      final result = await completer.future;
      NativePdf._completeWithSuccess(result);
    } catch (e) {
      NativePdf._completeWithError(Exception('PDF generation failed: $e'));
    }
  } catch (e) {
    NativePdf._completeWithError(Exception('Android PDF setup failed: $e'));
  }
}
