import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

import 'exceptions.dart';

/// Lets a caller stop an in-flight [NativeVideoToolkit] operation —
/// compress/merge/mute/reverse can each take minutes on a large file, and
/// without this, closing the dialog that started one just detaches the UI
/// while the AVFoundation export or FFmpeg process keeps running invisibly
/// in the background until it finishes on its own.
///
/// Pass the same token into a `compressVideo`/`mergeVideos`/`muteVideo`/
/// `reverseVideo` call and hold onto it; call [cancel] (e.g. from the
/// caller's `dispose()`) to stop that operation as soon as possible. A
/// cancelled operation completes its `Future` with a [VideoToolException].
class CancelToken {
  bool _cancelled = false;
  void Function()? _onCancel;

  bool get isCancelled => _cancelled;

  /// Registered by whichever native primitive is currently running (an
  /// `AVAssetExportSession`, at most one at a time per token) so [cancel]
  /// can stop it directly instead of just setting a flag nothing reads.
  void attach(void Function() onCancel) {
    _onCancel = onCancel;
    if (_cancelled) onCancel();
  }

  void detach() {
    _onCancel = null;
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call();
    // Covers the FFmpeg side (format normalization / remux) — there's no
    // per-call session handle surfaced by `_run` to target individually,
    // and this toolkit never has more than one tool operation in flight at
    // once, so cancelling every running FFmpeg session is equivalent to
    // cancelling *this* operation's.
    FFmpegKit.cancel();
  }

  void throwIfCancelled() {
    if (_cancelled) {
      throw const VideoToolException('Cancelled.');
    }
  }
}
