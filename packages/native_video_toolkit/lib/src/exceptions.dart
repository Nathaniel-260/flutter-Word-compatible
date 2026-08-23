/// Thrown by any [NativeVideoToolkit] operation that AVFoundation reports as
/// failed (export/read/write status went to `Failed`/`Cancelled`, or an
/// `NSError` was produced by a synchronous call).
class VideoToolException implements Exception {
  final String message;
  const VideoToolException(this.message);

  @override
  String toString() => message;
}
