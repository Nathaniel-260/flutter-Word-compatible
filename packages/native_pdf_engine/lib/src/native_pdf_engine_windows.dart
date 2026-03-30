import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'native_pdf_engine_c_bindings.dart';

class NativePdfWindows {
  static native_pdf_engine_c_bindings? _bindings;

  static void _init() {
    if (_bindings != null) return;

    try {
      final library = DynamicLibrary.open('native_pdf_engine_windows.dll');

      _bindings = native_pdf_engine_c_bindings(library);
    } catch (e) {
      throw Exception('Failed to load native_pdf_engine_windows.dll: $e');
    }
  }

  static Future<Uint8List?> convert(
    String content, {
    String? outputPath,
    required bool isUrl,
  }) async {
    _init();

    final engine = _bindings!.NativePdf_CreateEngine();
    if (engine == nullptr) {
      throw Exception('Failed to create PDF engine');
    }

    // Use Arena to automatically free all native allocations
    final arena = Arena();
    final completer = Completer<Uint8List?>();

    // Callback
    late NativeCallable<PdfCompletionCallbackFunction> callback;
    callback = NativeCallable<PdfCompletionCallbackFunction>.listener((
      bool success,
      Pointer<Char> errorMsg,
      Pointer<Uint8> data,
      int length,
      Pointer<Void> userData,
    ) {
      if (success) {
        if (data != nullptr && length > 0) {
          // Copy bytes — pointer only valid during callback
          completer.complete(Uint8List.fromList(data.asTypedList(length)));
        } else {
          completer.complete(null);
        }
      } else {
        final msg = errorMsg.cast<Utf8>().toDartString();
        completer.completeError(Exception(msg));
      }
      callback.close(); // Clean up listener port
    });

    final cContent = content.toNativeUtf8(allocator: arena);
    final cOutputPath = (outputPath ?? "").toNativeUtf8(allocator: arena);

    try {
      _bindings!.NativePdf_Generate(
        engine,
        cContent.cast(),
        isUrl,
        cOutputPath.cast(),
        callback.nativeFunction,
        nullptr,
      );

      return await completer.future;
    } finally {
      // Arena frees cContent + cOutputPath automatically
      arena.releaseAll();
      _bindings!.NativePdf_DestroyEngine(engine);
    }
  }
}
