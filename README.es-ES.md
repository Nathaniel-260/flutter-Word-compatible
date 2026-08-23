# Espacio de Trabajo de Paquetes Flutter

¡Bienvenido al monorepo `flutter-packages`! Este repositorio contiene paquetes para convertir HTML y Markdown a PDF en Flutter, utilizando diferentes motores de renderizado.

## Paquetes

| Paquete | Versión | Descargas | Descripción |
| :--- | :--- | :--- | :--- |
| [htmltopdfwidgets](packages/htmltopdfwidgets) | [![pub package](https://img.shields.io/pub/v/htmltopdfwidgets.svg)](https://pub.dev/packages/htmltopdfwidgets) | ![downloads](https://img.shields.io/pub/dm/htmltopdfwidgets) | El paquete principal para convertir HTML y Markdown en widgets PDF. Admite tanto motores de renderizado heredados como nuevos similares a navegadores. |
| [htmltopdf_syncfusion](packages/htmltopdf_syncfusion) | [![pub package](https://img.shields.io/pub/v/htmltopdf_syncfusion.svg)](https://pub.dev/packages/htmltopdf_syncfusion)  | ![downloads](https://img.shields.io/pub/dm/htmltopdf_syncfusion) | Un paquete estable que utiliza widgets PDF de Syncfusion para el renderizado. |
| [docx_creator](packages/docx_creator) | [![pub package](https://img.shields.io/pub/v/docx_creator.svg)](https://pub.dev/packages/docx_creator)  | ![downloads](https://img.shields.io/pub/dm/docx_creator) | Un paquete Dart centrado en el desarrollador para crear documentos DOCX profesionales con una API fluida, análisis de Markdown/HTML y un formato completo. |
| [docx_file_viewer](packages/docx_file_viewer) | [![pub package](https://img.shields.io/pub/v/docx_file_viewer.svg)](https://pub.dev/packages/docx_file_viewer) | ![downloads](https://img.shields.io/pub/dm/docx_file_viewer) |  Un visor nativo de DOCX para Flutter que renderiza documentos de Word utilizando widgets de Flutter. |
| [native_pdf_engine](packages/native_pdf_engine) | [![pub package](https://img.shields.io/pub/v/native_pdf_engine.svg)](https://pub.dev/packages/native_pdf_engine)  | ![downloads](https://img.shields.io/pub/dm/native_pdf_engine) | Un paquete de Flutter de alto rendimiento basado en FFI para convertir HTML y URLs a PDF utilizando webviews nativas del sistema operativo. |
| [native_video_toolkit](packages/native_video_toolkit) | [![pub package](https://img.shields.io/pub/v/native_video_toolkit.svg)](https://pub.dev/packages/native_video_toolkit) | ![downloads](https://img.shields.io/pub/dm/native_video_toolkit) | Comprime, une, silencia e invierte video conectado directamente a AVFoundation (iOS/macOS) y android.media (Android) vía FFI/JNI — sin MethodChannel. |

## Gestión del Espacio de Trabajo

Este repositorio utiliza [Melos](https://melos.invertase.dev/) para gestionar el espacio de trabajo.

### Para Comenzar

1.  **Instalar Melos**:
    ```bash
    dart pub global activate melos
    ```

2.  **Inicializar el espacio de trabajo**:
    ```bash
    melos bootstrap
    ```
    Este comando vincula los paquetes locales entre sí e instala las dependencias.

### Comandos Comunes

-   `melos run analyze`: Ejecutar el analizador de Dart en todos los paquetes.
-   `melos run test`: Ejecutar pruebas en todos los paquetes.
-   `melos run format`: Formatear el código en todos los paquetes.

## Licencia

Este repositorio está licenciado bajo la [Licencia Apache 2.0](LICENSE).
