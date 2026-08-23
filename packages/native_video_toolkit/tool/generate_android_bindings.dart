// Generates lib/src/native_video_toolkit_android_bindings.g.dart directly
// from the Android SDK's android.media classes (MediaExtractor/MediaMuxer/
// MediaCodec/MediaFormat — the fast, no-re-encode "stream copy" path,
// playing the same role AVAssetExportPresetPassthrough plays on the
// AVFoundation side) and androidx.media3's Transformer API (the re-encode
// fallback, playing the same role AVAssetExportPresetHighestQuality plays),
// using jnigen + package:jni. No hand-written JNI glue — merge/mute/reverse
// on Android are driven straight from Dart via these generated bindings
// (see lib/src/native_video_toolkit_android.dart), exactly like
// tool/generate_bindings.dart does for AVFoundation on macOS/iOS.
//
// jnigen resolves the full Android classpath (SDK bootclasspath + this
// package's own androidx.media3 Gradle dependencies, see
// android/build.gradle.kts) by running a Gradle stub task inside the
// example app's Android project — hence `androidExample: 'example/'`
// below. This means `example/android` must exist (`flutter create
// --platforms=android .` inside example/) before running this.
//
// Run:
//   dart run tool/generate_android_bindings.dart
import 'dart:io';

import 'package:jnigen/jnigen.dart';
import 'package:logging/logging.dart';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');
  await generateJniBindings(
    Config(
      androidSdkConfig: AndroidSdkConfig(
        addGradleDeps: true,
        androidExample: packageRoot.resolve('example/').toFilePath(),
      ),
      summarizerOptions: SummarizerOptions(backend: SummarizerBackend.asm),
      classes: [
        // --- Fast path: raw android.media, no jnigen-visible re-encode ---
        // (MediaCodec is also this package's only route to *reverse* —
        // there's no AVAssetReader/Writer equivalent in media3, so reverse
        // stays on this API regardless of the merge/mute path taken.)
        'android.media.MediaExtractor',
        'android.media.MediaMuxer',
        'android.media.MediaCodec',
        'android.media.MediaCodecList',
        'android.media.MediaCodecInfo',
        'android.media.MediaFormat',
        'android.media.MediaMetadataRetriever',
        // Plane-correct pixel access for reverse's decode/re-encode loop —
        // MediaCodec's raw ByteBuffer output isn't guaranteed tightly
        // packed (hardware decoders commonly pad row/plane strides), so
        // Image/Image.Plane (with their real rowStride/pixelStride) is
        // used instead of treating getOutputBuffer()'s bytes as raw I420.
        'android.media.Image',

        // --- Re-encode fallback: androidx.media3 Transformer ---
        'androidx.media3.common.MediaItem',
        'androidx.media3.common.audio.AudioProcessor',
        'androidx.media3.transformer.Transformer',
        'androidx.media3.transformer.TransformationRequest',
        'androidx.media3.transformer.EditedMediaItem',
        'androidx.media3.transformer.EditedMediaItemSequence',
        'androidx.media3.transformer.Composition',
        'androidx.media3.transformer.Effects',
        'androidx.media3.transformer.ExportResult',
        'androidx.media3.transformer.ExportException',
      ],
      outputConfig: OutputConfig(
        dartConfig: DartCodeOutputConfig(
          path: packageRoot.resolve(
            'lib/src/native_video_toolkit_android_bindings.g.dart',
          ),
          structure: OutputStructure.singleFile,
        ),
      ),
      logLevel: Level.INFO,
    ),
  );
}
