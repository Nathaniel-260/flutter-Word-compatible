## 0.0.2

* Fix `homepage`/`repository`/`issue_tracker` to point at the canonical
  `flutter-packages` repo.
* Add badges and a License section to the README.

## 0.0.1

Initial release.

### iOS / macOS
* `compressVideo`, `mergeVideos`, `muteVideo`, `reverseVideo`,
  `generateThumbnail`, `ensurePlayableCopy` bound directly to AVFoundation
  via `package:ffigen`'s Objective-C interop — no `MethodChannel`.
* Automatic container/codec normalization (`ensureAvFoundationCompatible`)
  for sources AVFoundation can't open natively, via an FFmpeg pre-pass.
* Swift Package Manager support on both platforms, sharing one generated
  binding set (verified byte-identical bound API surface between the
  macOS and iOS SDKs) — plus a CocoaPods `.podspec` fallback.

### Android
* `mergeVideos` (fast, no-re-encode path only — see Known limitations),
  `muteVideo`, `reverseVideo`, `ensurePlayableCopy` bound directly to
  `android.media` (`MediaExtractor`/`MediaMuxer`/`MediaCodec`) via
  `package:jni`/`package:jnigen` — no `MethodChannel`.
* Every decode/encode/mux operation runs on its own background `Isolate`,
  never blocking the caller's isolate.
* `compressVideo`/`generateThumbnail`/media probing work unmodified on
  Android — they're pure `ffmpeg_kit_flutter_new` calls with no
  AVFoundation/`android.media` involvement on any platform.
* Three real bugs found and fixed via actual device/emulator testing with
  real video files (none of these were catchable by static analysis or a
  clean build):
  * `reverseVideo`'s encoder was being told every frame had 0 bytes of
    data (the `queueInputBuffer` `size` argument, not the pixel data
    itself, which was written correctly via the `Image` API) — silently
    wedged the encoder's entire pipeline with no exception and near-zero
    CPU, one of the harder failure modes to diagnose.
  * `reverseVideo`'s encode loop wrote every encoder output buffer to the
    muxer, including ones flagged `BUFFER_FLAG_CODEC_CONFIG` —
    `MediaMuxer` only ever wants codec-config data from `addTrack`'s
    format, never as a sample; feeding it the redundant buffer anyway
    threw a native `"Already have codec specific data"` error and wedged
    the muxer's writer thread.
  * `mergeVideos`' fast path computed each clip's timestamp offset from
    the container's reported `durationUs`, which can undershoot an audio
    track's actual last sample (encoder priming/padding) — fixed by
    tracking the last *actually-written* timestamp per track instead of
    trusting reported duration.

### Known limitations
* `reverseVideo` has no audio track on either platform (sample-accurate
  audio reversal is out of scope) and decodes every frame into memory
  before writing anything out (rejected above a safety ceiling per
  resolution, rather than hanging).
* Android's `mergeVideos` has no re-encode fallback for clips with
  mismatched encoding settings yet — it throws a clear error instead. A
  fallback via `androidx.media3`'s `Transformer` is planned; the jnigen
  bindings for it are already generated but not wired up.
* Windows and Linux aren't implemented.
