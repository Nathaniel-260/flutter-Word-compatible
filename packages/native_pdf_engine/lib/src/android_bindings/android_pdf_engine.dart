import 'dart:async';
import 'dart:io' as dart_io;

import 'package:flutter/foundation.dart';
import 'package:jni/jni.dart';
import 'package:jni_flutter/jni_flutter.dart';

import 'android_bindings.dart';

class AndroidPdfEngine {
  AndroidPdfEngine._();

  static WebView? _activeWebView;

  static void cleanup() {
    try {
      _activeWebView?.release();
    } catch (_) {}
    _activeWebView = null;
  }

  static void convertAndroid(
    String content, {
    String? outputPath,
    required bool isUrl,
    required void Function([dynamic result]) completeWithSuccess,
    required void Function(Exception error) completeWithError,
  }) async {
    Activity? activity;
    Runnable? runnable;
    try {
      // Retrieve engineId safely
      final engineId = PlatformDispatcher.instance.engineId;
      if (engineId == null) {
        completeWithError(Exception('PlatformDispatcher.engineId is null'));
        return;
      }

      final appActivity = androidActivity(engineId);
      if (appActivity == null) {
        completeWithError(
          Exception('Android Activity is null. Engine not attached?'),
        );
        return;
      }

      // Cast to strongly typed Activity
      activity = appActivity as Activity;

      // Use a Completer to bridge the async gap from the UI thread callback
      final completer = Completer<Uint8List?>();

      // Implement Runnable
      runnable = Runnable.implement(
        $Runnable(
          run: () async {
            WebSettings? settings;
            JString? jContent;
            JString? jEmptyString;
            JString? jMimeType;
            JString? jEncoding;
            try {
              // 1. Create WebView
              // Use the activity as context
              final androidContext = activity as Context;

              // Enable slow whole document draw for Android L and above to capture full document
              WebView.enableSlowWholeDocumentDraw();

              _activeWebView = WebView(androidContext);
              final webView = _activeWebView!;
              final webViewAsView = webView as View;

              // Use software layer to ensure all content is captured to Canvas
              webViewAsView.setLayerType(View.LAYER_TYPE_SOFTWARE, null);

              // 2. Configure Settings
              settings = webView.settings;

              settings?.javaScriptEnabled = true;
              settings?.domStorageEnabled = true;

              // 3. Attach WebView to Activity to ensure it renders
              // We add it with 1x1 size to avoid visual disruption while still being "attached"
              final layoutParams = ViewGroup$LayoutParams.new$2(1, 1);
              activity?.addContentView(webViewAsView, layoutParams);

              // 4. Setup PdfPrinter and prepare WebView BEFORE loading
              final attributesBuilder = PrintAttributes$Builder();
              final mediaSize = PrintAttributes$MediaSize.ISO_A4;
              final resolution = PrintAttributes$Resolution(
                "pdf".toJString(),
                "pdf".toJString(),
                300,
                300,
              );
              final margins = PrintAttributes$Margins.NO_MARGINS;

              attributesBuilder.setMediaSize(mediaSize);
              attributesBuilder.setResolution(resolution);
              attributesBuilder.setMinMargins(margins);
              attributesBuilder.setColorMode(1); // COLOR_MODE_COLOR

              final attributes = attributesBuilder.build();
              if (attributes == null) {
                completer.completeError(
                  Exception('Failed to build PrintAttributes'),
                );
                return;
              }

              final printer = PdfPrinter(attributes);

              // Setup directory and filename
              final actualOutputPath =
                  outputPath ??
                  "${androidContext.cacheDir!.path!.toDartString()}/${DateTime.now().millisecondsSinceEpoch}.pdf";

              final outputFile = dart_io.File(actualOutputPath);
              final directory = outputFile.parent;
              final fileName = outputFile.path.split('/').last;

              final jDirectory = File.new$1(directory.path.toJString());
              final jFileName = fileName.toJString();

              final completerPdf = Completer<void>();

              final callback = PdfPrinter$Callback.implement(
                $PdfPrinter$Callback(
                  onSuccess: (filePath) {
                    debugPrint('PDF Print Success: ${filePath.toDartString()}');
                    completerPdf.complete();
                  },
                  onFailure: () {
                    debugPrint('PDF Print Failed');
                    completerPdf.completeError(Exception('PdfPrinter failed'));
                  },
                ),
              );

              // Prepare WebView (sets the WebViewClient)
              printer.prepareWebView(webView, jDirectory, jFileName, callback);

              // 5. Load Content AFTER setting client
              jContent = content.toJString();
              if (isUrl) {
                webView.loadUrl(jContent);
              } else {
                jEmptyString = "".toJString();
                jMimeType = "text/html".toJString();
                jEncoding = "utf-8".toJString();
                webView.loadDataWithBaseURL(
                  jEmptyString,
                  jContent,
                  jMimeType,
                  jEncoding,
                  jEmptyString,
                );
              }

              // 6. Wait for print process to finish
              await completerPdf.future;

              // 7. Cleanup: Remove WebView from Activity
              final parent = webViewAsView.parent;
              if (parent != null && parent is ViewGroup) {
                parent.removeView(webViewAsView);
              }

              if (outputPath != null) {
                completer.complete(null);
              } else {
                // Read bytes from temporary file
                final bytesFile = await dart_io.File(
                  actualOutputPath,
                ).readAsBytes();
                completer.complete(bytesFile);
                // Cleanup temp file
                try {
                  await dart_io.File(actualOutputPath).delete();
                } catch (_) {}
              }
            } catch (e) {
              completer.completeError(e);
            } finally {
              // Cleanup JNI references if needed
            }
          },
        ),
      );

      // Execute on UI Thread
      activity.runOnUiThread(runnable);

      // Wait for completion
      try {
        final result = await completer.future;
        completeWithSuccess(result);
      } catch (e) {
        completeWithError(Exception('PDF generation failed: $e'));
      }
    } catch (e) {
      completeWithError(Exception('Android PDF setup failed: $e'));
    } finally {
      // Release runnable and activity
      try {
        runnable?.release();
      } catch (_) {}
      try {
        activity?.release();
      } catch (_) {}
    }
  }
}
