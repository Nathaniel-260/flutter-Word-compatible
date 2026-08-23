# Flutter Packages Workspace

Welcome to the `flutter-packages` monorepo! This repository contains packages for converting HTML and Markdown to PDF in Flutter, using different rendering engines.

## Packages

| Package | Version | Downloads | Description |
| :--- | :--- | :--- | :--- |
| [htmltopdfwidgets](packages/htmltopdfwidgets) | [![pub package](https://img.shields.io/pub/v/htmltopdfwidgets.svg)](https://pub.dev/packages/htmltopdfwidgets) | ![downloads](https://img.shields.io/pub/dm/htmltopdfwidgets) | The core package for converting HTML and Markdown to PDF widgets. Supports both legacy and new browser-like rendering engines. |
| [htmltopdf_syncfusion](packages/htmltopdf_syncfusion) | [![pub package](https://img.shields.io/pub/v/htmltopdf_syncfusion.svg)](https://pub.dev/packages/htmltopdf_syncfusion)  | ![downloads](https://img.shields.io/pub/dm/htmltopdf_syncfusion) | A finalized package that uses Syncfusion PDF widgets for rendering. |
| [docx_creator](packages/docx_creator) | [![pub package](https://img.shields.io/pub/v/docx_creator.svg)](https://pub.dev/packages/docx_creator)  | ![downloads](https://img.shields.io/pub/dm/docx_creator) | A developer-first Dart package for creating professional DOCX documents with fluent API, Markdown/HTML parsing, and comprehensive formatting. |
| [docx_file_viewer](packages/docx_file_viewer) | [![pub package](https://img.shields.io/pub/v/docx_file_viewer.svg)](https://pub.dev/packages/docx_file_viewer) | ![downloads](https://img.shields.io/pub/dm/docx_file_viewer) |  A native Flutter DOCX viewer that renders Word documents using Flutter widgets. |
| [native_pdf_engine](packages/native_pdf_engine) | [![pub package](https://img.shields.io/pub/v/native_pdf_engine.svg)](https://pub.dev/packages/native_pdf_engine)  | ![downloads](https://img.shields.io/pub/dm/native_pdf_engine) | A high-performance, FFI-based Flutter package to convert HTML and URLs to PDF using native OS webviews. |
| [native_video_toolkit](packages/native_video_toolkit) | [![pub package](https://img.shields.io/pub/v/native_video_toolkit.svg)](https://pub.dev/packages/native_video_toolkit) | ![downloads](https://img.shields.io/pub/dm/native_video_toolkit) | Compress, merge, mute, and reverse video bound directly to AVFoundation (iOS/macOS) and android.media (Android) via FFI/JNI — no MethodChannel. |

## Workspace Management

This repository uses [Melos](https://melos.invertase.dev/) to manage the workspace.

### Getting Started

1.  **Install Melos**:
    ```bash
    dart pub global activate melos
    ```

2.  **Bootstrap the workspace**:
    ```bash
    melos bootstrap
    ```
    This command links local packages together and installs dependencies.

### Common Commands

-   `melos run analyze`: Run Dart analyzer in all packages.
-   `melos run test`: Run tests in all packages.
-   `melos run format`: Format code in all packages.

## License

This repository is licensed under the [Apache License 2.0](LICENSE).
