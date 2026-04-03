/// Native PDF Engine - HTML to PDF conversion using native OS webviews
///
/// Supports iOS and macOS platforms only.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'src/android_bindings/android_pdf_engine.dart';
import 'src/ios/ios_pdf_engine.dart';
import 'src/linux/native_pdf_engine_linux.dart';
import 'src/macos/macos_pdf_engine.dart';
import 'src/windows/native_pdf_engine_windows.dart';

/// High-level PDF generation API for iOS and macOS.
///
/// This class provides static methods to convert HTML content or URLs to PDF files
/// using native WebKit components for optimal performance and memory efficiency.
class NativePdf {
  NativePdf._(); // Prevent instantiation

  static Completer<dynamic>? _pendingCompleter;

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

    try {
      if (Platform.isIOS) {
        IOSPdfEngine.convertIOS(
          html,
          outputPath: outputPath,
          isUrl: false,
          completeWithSuccess: _completeWithSuccess,
          completeWithError: _completeWithError,
        );
      } else if (Platform.isMacOS) {
        MacOSPdfEngine.convertMacOS(
          html,
          outputPath: outputPath,
          isUrl: false,
          completeWithSuccess: _completeWithSuccess,
          completeWithError: _completeWithError,
        );
      } else if (Platform.isAndroid) {
        AndroidPdfEngine.convertAndroid(
          html,
          outputPath: outputPath,
          isUrl: false,
          completeWithSuccess: _completeWithSuccess,
          completeWithError: _completeWithError,
        );
      } else if (Platform.isWindows) {
        await NativePdfWindows.convert(
          html,
          outputPath: outputPath,
          isUrl: false,
        );
      } else if (Platform.isLinux) {
        await NativePdfLinux.convert(
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

    try {
      final file = File(outputPath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      if (Platform.isIOS) {
        IOSPdfEngine.convertIOS(
          url,
          outputPath: outputPath,
          isUrl: true,
          completeWithSuccess: _completeWithSuccess,
          completeWithError: _completeWithError,
        );
      } else if (Platform.isMacOS) {
        MacOSPdfEngine.convertMacOS(
          url,
          outputPath: outputPath,
          isUrl: true,
          completeWithSuccess: _completeWithSuccess,
          completeWithError: _completeWithError,
        );
      } else if (Platform.isAndroid) {
        AndroidPdfEngine.convertAndroid(
          url,
          outputPath: outputPath,
          isUrl: true,
          completeWithSuccess: _completeWithSuccess,
          completeWithError: _completeWithError,
        );
      } else if (Platform.isWindows) {
        await NativePdfWindows.convert(
          url,
          outputPath: outputPath,
          isUrl: true,
        );
      } else if (Platform.isLinux) {
        await NativePdfLinux.convert(url, outputPath: outputPath, isUrl: true);
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

    try {
      if (Platform.isIOS) {
        IOSPdfEngine.convertIOS(
          html,
          outputPath: null,
          isUrl: false,
          completeWithSuccess: _completeWithSuccess,
          completeWithError: _completeWithError,
        );
      } else if (Platform.isMacOS) {
        MacOSPdfEngine.convertMacOS(
          html,
          outputPath: null,
          isUrl: false,
          completeWithSuccess: _completeWithSuccess,
          completeWithError: _completeWithError,
        );
      } else if (Platform.isAndroid) {
        AndroidPdfEngine.convertAndroid(
          html,
          outputPath: null,
          isUrl: false,
          completeWithSuccess: _completeWithSuccess,
          completeWithError: _completeWithError,
        );
      } else if (Platform.isWindows) {
        final result = await NativePdfWindows.convert(
          html,
          outputPath: null,
          isUrl: false,
        );
        return result ?? Uint8List(0);
      } else if (Platform.isLinux) {
        final result = await NativePdfLinux.convert(
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

    try {
      if (Platform.isIOS) {
        IOSPdfEngine.convertIOS(
          url,
          outputPath: null,
          isUrl: true,
          completeWithSuccess: _completeWithSuccess,
          completeWithError: _completeWithError,
        );
      } else if (Platform.isMacOS) {
        MacOSPdfEngine.convertMacOS(
          url,
          outputPath: null,
          isUrl: true,
          completeWithSuccess: _completeWithSuccess,
          completeWithError: _completeWithError,
        );
      } else if (Platform.isAndroid) {
        AndroidPdfEngine.convertAndroid(
          url,
          outputPath: null,
          isUrl: true,
          completeWithSuccess: _completeWithSuccess,
          completeWithError: _completeWithError,
        );
      } else if (Platform.isWindows) {
        final result = await NativePdfWindows.convert(
          url,
          outputPath: null,
          isUrl: true,
        );
        return result ?? Uint8List(0);
      } else if (Platform.isLinux) {
        final result = await NativePdfLinux.convert(
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
    if (Platform.isIOS) {
      IOSPdfEngine.cleanup();
    } else if (Platform.isMacOS) {
      MacOSPdfEngine.cleanup();
    } else if (Platform.isAndroid) {
      AndroidPdfEngine.cleanup();
    }
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
