# native_video_toolkit

[![pub package](https://img.shields.io/pub/v/native_video_toolkit.svg?color=blue&style=flat-square)](https://pub.dev/packages/native_video_toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![platform](https://img.shields.io/badge/platform-ios%20%7C%20macos%20%7C%20android-lightgrey.svg?style=flat-square)](#platform-support)

Compress, merge, mute, reverse, and thumbnail video — bound **directly**
to each platform's own native media stack, with no bundled video engine
and no hand-written native glue beyond a trivial plugin-registration stub:

- **iOS / macOS** — [AVFoundation](https://developer.apple.com/av-foundation/)
  (`AVAssetExportSession`, `AVMutableComposition`, `AVAssetReader`/
  `AVAssetWriter`), bound via `package:ffigen`'s Objective-C interop +
  `package:objective_c`.
- **Android** — [`android.media`](https://developer.android.com/reference/android/media/package-summary)
  (`MediaExtractor`, `MediaMuxer`, `MediaCodec`), bound via `package:jni` +
  `package:jnigen`.

There is **no `MethodChannel`** anywhere in this package — every native
call happens straight from Dart through generated bindings. On both
platforms, this is the same technique: point a code generator (ffigen or
jnigen) at the real platform SDK, generate a typed Dart binding, and call
it directly.

`compressVideo`/`generateThumbnail`/media probing don't need any of this —
they're pure [`ffmpeg_kit_flutter_new`](https://pub.dev/packages/ffmpeg_kit_flutter_new)
calls and already work identically on every platform.

## Platform support

| Operation | iOS / macOS | Android |
|---|---|---|
| `compressVideo` | ✅ (FFmpeg, hardware VideoToolbox) | ✅ (FFmpeg, hardware MediaCodec) |
| `generateThumbnail` | ✅ | ✅ |
| `muteVideo` | ✅ (AVFoundation) | ✅ (`MediaExtractor`/`MediaMuxer` stream copy) |
| `mergeVideos` | ✅ (AVFoundation, always re-encodes if needed) | ✅ for clips that already share encoding settings (stream copy, no re-encode) — clips with different resolution/codec settings throw a clear error asking you to compress them to matching settings first; a re-encode fallback isn't wired up yet (see [Known limitations](#known-limitations)) |
| `reverseVideo` | ✅ (`AVAssetReader`/`AVAssetWriter`, no audio) | ✅ (`MediaCodec` decode/encode, no audio) |
| `ensurePlayableCopy` | ✅ | ✅ |

Windows and Linux aren't implemented.

## Installation

```yaml
dependencies:
  native_video_toolkit: ^0.0.1
```

### Android setup

- **`minSdk 23`** or higher (`MediaCodec.getInputImage()`/`getOutputImage()`,
  used for stride-correct pixel access during `reverseVideo`, require it).
- Nothing else — no permissions, no manifest changes. Everything runs
  through `android.media`, which every app already has on its classpath.

### iOS / macOS setup

- **Deployment target 14.0** or higher on both platforms (matches this
  package's own `ffmpeg_kit_flutter_new` dependency's floor — Xcode's
  Swift Package Manager integration fails the whole app build if any two
  plugins disagree on minimum platform version, so this package pins to
  the same number rather than picking its own lower one).
- Nothing else — AVFoundation/CoreMedia/CoreVideo are linked automatically
  by this package's Swift Package Manager target.

## Usage

```dart
import 'package:native_video_toolkit/native_video_toolkit.dart';

// Re-encode at a target quality (0.0 lowest .. 1.0 highest). The target
// bitrate is computed relative to the source's own bitrate, so this can
// never make a file bigger than its source.
final compressed = await NativeVideoToolkit.compressVideo(
  inputPath: input.path,
  outputPath: output.path,
  quality: 0.75,
  onProgress: (p) => print('${(p * 100).round()}%'),
);

// Concatenate, in order.
final merged = await NativeVideoToolkit.mergeVideos(
  inputPaths: [clip1.path, clip2.path],
  outputPath: output.path,
);

// Drop the audio track.
final muted = await NativeVideoToolkit.muteVideo(
  inputPath: input.path,
  outputPath: output.path,
);

// Play the video track backwards (no audio in the output — see above).
final reversed = await NativeVideoToolkit.reverseVideo(
  inputPath: input.path,
  outputPath: output.path,
);

// A real JPEG preview frame for UI thumbnails.
final thumbnail = await NativeVideoToolkit.generateThumbnail(input.path);
```

Every operation is a `static Future<String>` (the output path) and throws
`VideoToolException` on failure — catch it and read `.message`, or just
`.toString()`.

### Cancellation

```dart
final cancelToken = CancelToken();

final future = NativeVideoToolkit.compressVideo(
  inputPath: input.path,
  outputPath: output.path,
  cancelToken: cancelToken,
);

// Later, e.g. from a "Cancel" button or the caller's dispose():
cancelToken.cancel();
```

A cancelled operation completes its `Future` with a `VideoToolException`.
On iOS/macOS this stops the in-flight `AVAssetExportSession` directly; on
Android, where a merge/mute/reverse call runs on its own background
`Isolate` (see [Architecture](#architecture)), cancellation kills that
isolate and deletes its partial output.

### Playback helpers

`video_player` (and any AVFoundation/ExoPlayer-backed player) needs a
container/codec combination its player actually supports. These two
helpers exist for exactly that — not for processing:

```dart
final playablePath = await NativeVideoToolkit.ensurePlayableCopy(input.path);
// ... hand playablePath to your player ...

if (NativeVideoToolkit.isTemporaryPlayableCopy(playablePath, input.path)) {
  await NativeVideoToolkit.disposePlayableCopy(playablePath, input.path);
}
```

`ensurePlayableCopy` returns `input.path` unchanged when the source is
already natively playable, or a remuxed/transcoded scratch copy
otherwise — `isTemporaryPlayableCopy`/`disposePlayableCopy` tell you which
case you're in and clean up the scratch copy once playback ends.

## Architecture

### iOS / macOS

`lib/native_video_toolkit.dart` calls straight into
`lib/src/native_video_toolkit_bindings.g.dart` — ffigen-generated
Objective-C bindings, regenerated with:

```bash
dart run tool/generate_bindings.dart
```

The bound AVFoundation/CoreMedia/CoreVideo/CoreFoundation surface is
*identical* between the macOS and iOS SDKs (verified by generating against
both and diffing the output), so there's one shared binding file and one
generated native glue file (`native_video_toolkit_bindings.g.m`) —
`tool/generate_bindings.dart` regenerates the macOS copy and copies it
into the iOS Swift Package target too, so the two can never drift apart.
Both platforms use a Swift Package Manager target layout (with a CocoaPods
`.podspec` fallback for apps that haven't migrated to SPM).

### Android

`lib/src/native_video_toolkit_android.dart` calls into
`lib/src/native_video_toolkit_android_bindings.g.dart` — jnigen-generated
`android.media` bindings, regenerated with:

```bash
dart run tool/generate_android_bindings.dart
```

(this runs a real Gradle build inside `example/android` to resolve the
Android SDK classpath — the first run takes a few minutes, jnigen caches
the result after that).

`native_video_toolkit.dart`'s public API dispatches to the Android
implementation via `Platform.isAndroid` — callers never need their own
platform checks. Every Android operation that does real decode/encode/mux
work (`mergeVideos`/`muteVideo`/`reverseVideo`) spawns its own background
`Isolate` rather than blocking the caller's isolate; `package:jni`
attaches whichever OS thread makes a JNI call to the JVM on demand, so
this works from a freshly spawned isolate with no extra setup.

`mergeVideos`/`muteVideo` try a plain sample copy first
(`MediaExtractor` + `MediaMuxer`, no re-encode) before ever considering a
real re-encode — merge falls back to a clear error today instead of a
re-encode pass when clips don't share encoding settings (see
[Known limitations](#known-limitations)). `reverseVideo` decodes every
frame via `MediaCodec` (using the `Image`/`Image.Plane` API for
stride-correct pixel access, since raw `ByteBuffer` output isn't
guaranteed tightly packed on every device) and re-encodes them in reverse
order.

## Known limitations

- **`reverseVideo` has no audio track**, on both platforms — sample-accurate
  audio reversal is a separate, much larger problem (reversing raw PCM
  sample order is format-specific) and is intentionally out of scope here.
- **`reverseVideo` decodes every frame into memory before writing anything
  out** — correct and simple, but memory-heavy for long clips. Both
  platforms reject inputs whose estimated decoded footprint would exceed a
  safety ceiling (with a message telling you roughly how long a clip is
  safe at that resolution) rather than hanging or crashing.
- **Android's `mergeVideos` has no re-encode fallback yet.** Clips that
  don't already share the same resolution/codec/csd settings throw a
  clear error asking you to `compressVideo` them to matching settings
  first, rather than attempting an unverified re-encode. A real fallback
  via `androidx.media3`'s `Transformer` is planned — the jnigen bindings
  for it already exist in `native_video_toolkit_android_bindings.g.dart`,
  but wiring up `Transformer`'s builder-heavy API and its async
  `Context`-dependent completion callback is real remaining work (see
  that file's class doc for exactly what's missing).
- Windows and Linux aren't implemented.

## Testing

There's no unit test suite — the real behavior lives in AVFoundation and
`android.media`, not in Dart logic worth mocking. `example/` is a working
integration harness instead:

- **iOS/macOS**: `example/lib/main.dart`'s default `_runAll()` exercises
  every operation against sample files under `/tmp/nvt_format_tests/`.
- **Android**: the same file's `_runAllAndroid()` (used automatically via
  `Platform.isAndroid`) does the same against files pushed into this
  app's own external files directory (the exact path is printed to the
  log on startup) — push real `.mp4` files there via `adb push` before
  running.

Every real bug this package's Android implementation shipped with was
found this way (via `flutter build apk` + a real emulator + real video
files), not by static analysis — see `CHANGELOG.md` for specifics
(a `MediaCodec` buffer-size bug that silently wedged an encoder with 0%
CPU and no exception, a `MediaMuxer` contract violation that only
manifests as a native log error, and a timestamp-ordering edge case that
only shows up at a clip boundary with real audio). If you're extending
this package, especially anything touching `MediaCodec` directly, verify
against a real device/emulator and real files before trusting a clean
`flutter analyze`.

## License

MIT — see [LICENSE](LICENSE).
