## 0.0.7

### Android PDF Engine Stabilization
* **Native Printing Migration**: Refactored the Android conversion logic to use the native `PrintDocumentAdapter` workflow, ensuring high-fidelity rendering for complex and multi-page HTML content.
* **Release Mode Reliability**: Fixed `ClassNotFoundException` in release builds by aligning package namespaces and applying comprehensive ProGuard rules.
* **WebView Lifecycle Optimization**: Improved stability by explicitly attaching the hidden `WebView` to the Activity context and ensuring proper cleanup via `destroy()`.
* **Java SDK Bridge**: Implemented `PrintCallbackShim` in Java to safely access package-private Android printing APIs.
* **Native Threading**: Enhanced thread safety between the Flutter UI thread and the Android main loop for more predictable PDF generation.

### JNI 1.0 Finalization
* **Migrated to `jni: ^1.0.1` and `jnigen: ^0.16.0`:** Updated all Android bindings and usage patterns to comply with JNI 1.0 standards, including reference counting and new property accessors.

## 0.0.6

### JNI 1.0 Migration & Breaking Changes
* **Migrated to `jni: ^1.0.0` and `jnigen: ^0.16.0`:** Updated codebase to work with the latest major versions of JNI and JNIgen.
* **Added `jni_flutter` dependency:** Now uses `jni_flutter` for accessing the current Android activity, replacing the deprecated `jni.Jni.androidActivity`.
* **Updated Android Property Accessors:** Refactored Android platform code to use new property-style getters/setters (e.g., `webView.settings`, `webView.progress`) introduced in `jnigen` 0.16.0.
* **Simplified Binding Casting:** Replaced `fromReference` calls with direct `as` casting for strongly-typed JNI objects.

### Improvements
* **Enhanced Android Layout Stability:** Increased the settling delay from 200ms to 400ms after a layout change to more reliably capture content height.
* **Swift String Extensions:** Refactored Java string creation to use the `.toJString()` extension method for cleaner code.

## 0.0.5

### Stability & Reliability
* **Fixed silent hang on callback failure:** Added 30-second timeout on all pending PDF generation futures to prevent indefinite hangs when native code fails silently.
* **Fixed premature GC of ObjC completion handlers:** Introduced `_activeCompletionHandler` static reference to prevent Dart garbage collection of Objective-C blocks before native callbacks fire (iOS/macOS).
* **Fixed use-after-free on native memory:** Copied PDF data out of native `NSData` buffers via `Uint8List.fromList()` before native memory is deallocated (iOS/macOS).
* **Fixed silent exception swallowing:** Removed `async` from `_handleMacOSNavigationFinished` to prevent exceptions from being silently dropped.
* **Added comprehensive try/catch wrappers:** All platform setup paths now catch exceptions and properly complete the `Completer` with an error instead of leaving it pending.

### Memory Management
* **Arena-based native memory cleanup:** Replaced manual `calloc`/`free` with `Arena` for `CGRect` allocations on iOS/macOS, ensuring memory is freed even on exceptions.
* **Arena for native strings:** Linux and Windows now use `toNativeUtf8(allocator: arena)` with `arena.releaseAll()` in `finally` blocks for leak-proof string management.
* **Android JNI resource cleanup:** Added `finally` block to close `PdfDocument`, `FileOutputStream`, and `ByteArrayOutputStream` even when PDF generation throws.

### Tooling
* **Fixed ffigen URLSession duplicate symbol error:** Added `NSURLRequest.h` as an explicit entry point header for both iOS and macOS binding generation configs.

### Testing
* **Added comprehensive integration tests:** 18 tests covering all API surfaces — HTML/URL to file/data, concurrent call rejection, sequential cleanup, Unicode content, complex CSS, large documents, and mixed-mode memory safety.


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
