import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:jni/jni.dart' as jni;
import 'package:path/path.dart' as p;

import 'cancel_token.dart';
import 'exceptions.dart';
import 'format_compat.dart' show newScratchFile;
import 'native_video_toolkit_android_bindings.g.dart';

/// Compress/merge/mute/reverse on Android, the counterpart of
/// `native_video_toolkit.dart`'s AVFoundation implementation — driven
/// straight from Dart via jnigen-generated bindings to `android.media`
/// (`MediaExtractor`/`MediaMuxer`/`MediaCodec`) (see
/// `tool/generate_android_bindings.dart`). No `MethodChannel`: every real
/// operation here is a direct JNI call.
///
/// Mirrors AVFoundation's own fast-path/re-encode split conceptually: merge
/// and mute try a plain sample copy first (`MediaExtractor` + `MediaMuxer`,
/// no re-encode) — the same role `AVAssetExportPresetPassthrough` plays.
///
/// **Current scope, deliberately**: the re-encode fallback for merge inputs
/// whose encoding parameters don't match (the role
/// `AVAssetExportPresetHighestQuality` plays on the AVFoundation side) is
/// not implemented yet — see [_mergeVideosSync]'s doc. `androidx.media3`'s
/// `Transformer` bindings are already generated
/// (`native_video_toolkit_android_bindings.g.dart` has the full
/// `Transformer`/`EditedMediaItem`/`Composition` surface), but wiring them
/// up correctly — including the async `Transformer.Listener` callback and
/// an Android `Context` obtained via `package:jni_flutter`'s
/// `androidActivity()` — needs its own dedicated pass rather than being
/// bolted on here speculatively. Reverse has no media3 equivalent either
/// way (no "reverse" primitive there, same as AVFoundation) and always
/// re-encodes via `MediaCodec`, mirroring AVAssetReader/AVAssetWriter.
///
/// Every heavy operation below runs on its own background [Isolate] (spawned
/// fresh per call, never reused) rather than blocking the caller's isolate —
/// `package:jni` supports this directly (it attaches whichever OS thread
/// makes a JNI call to the JVM on demand, tracked per Dart isolate via
/// `Jni.getCurrentIsolateId()`). Progress and the final result/error cross
/// the isolate boundary as plain `List`s (`['progress', value]` /
/// `['done', path]` / `['error', message]`) rather than custom classes,
/// sidestepping any question about which object shapes are isolate-sendable.
class NativeVideoToolkitAndroid {
  NativeVideoToolkitAndroid._();

  /// `MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible` — not
  /// bound via jnigen (kept the surface intentional, see the generator),
  /// so the stable public constant value is used directly, same reasoning
  /// as `_kCVPixelFormatType32BGRA` in `native_video_toolkit.dart`.
  static const colorFormatYuv420Flexible = 2135033992;

  static Future<String> mergeVideos({
    required List<String> inputPaths,
    required String outputPath,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (inputPaths.isEmpty) {
      throw const VideoToolException('No input files provided.');
    }
    cancelToken?.throwIfCancelled();
    return _runIsolated(
      _mergeVideosWorker,
      [inputPaths, outputPath],
      onProgress: onProgress,
      cancelToken: cancelToken,
      outputPathForCleanup: outputPath,
    );
  }

  static Future<String> muteVideo({
    required String inputPath,
    required String outputPath,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    return _runIsolated(
      _muteVideoWorker,
      [inputPath, outputPath],
      onProgress: onProgress,
      cancelToken: cancelToken,
      outputPathForCleanup: outputPath,
    );
  }

  static Future<String> reverseVideo({
    required String inputPath,
    required String outputPath,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    return _runIsolated(
      _reverseVideoWorker,
      [inputPath, outputPath],
      onProgress: onProgress,
      cancelToken: cancelToken,
      outputPathForCleanup: outputPath,
    );
  }

  /// Android's `MediaExtractor` (used to probe container support below) has
  /// much broader native demuxer coverage than AVFoundation, so most
  /// containers this app's Convert/Compress screens accept need no
  /// pre-processing at all — this only falls back to an FFmpeg remux (same
  /// mechanism as `ensureAvFoundationCompatible`) for the rare container
  /// `MediaExtractor` genuinely can't open.
  static Future<String> ensurePlayableCopy(String inputPath) async {
    final extractor = MediaExtractor();
    var openable = false;
    try {
      extractor.dataSource$3 = inputPath.toJString();
      openable = extractor.trackCount > 0;
    } on jni.JThrowable {
      openable = false;
    } finally {
      extractor.release$1();
      extractor.release();
    }
    if (openable) return inputPath;

    final scratch = await newScratchFile(
      '${p.basenameWithoutExtension(inputPath)}.mp4',
    );
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-i',
      inputPath,
      '-map',
      '0:v:0',
      '-map',
      '0:a?',
      '-c:v',
      'h264_mediacodec',
      '-c:a',
      'aac',
      '-movflags',
      '+faststart',
      scratch.path,
    ]);
    if (!ReturnCode.isSuccess(await session.getReturnCode())) {
      throw VideoToolException(
        'Could not read "${p.basename(inputPath)}" — this format/codec is '
        'not supported.',
      );
    }
    return scratch.path;
  }

  static bool isTemporaryPlayableCopy(String path, String originalInputPath) =>
      path != originalInputPath;

  static Future<void> disposePlayableCopy(
    String path,
    String originalInputPath,
  ) async {
    if (path == originalInputPath) return;
    final dir = File(path).parent;
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

// ---- isolate plumbing ----

/// Spawns [entry] on a fresh background isolate, forwards its
/// `['progress', double]` messages to [onProgress], resolves with the path
/// from its `['done', String]` message, and turns `['error', String]` (or
/// an uncaught isolate error) into a [VideoToolException]. Wiring
/// [cancelToken] to [Isolate.kill] is the only practical way to interrupt
/// JNI work that's mid-loop on another isolate — same-effort tradeoff as
/// AVFoundation's `cancelExport`, just via a coarser primitive; a killed
/// isolate can't clean up its own half-written output, so
/// [outputPathForCleanup] is deleted here instead once cancellation is
/// confirmed.
Future<String> _runIsolated(
  void Function(List<Object?> args) entry,
  List<Object?> args, {
  void Function(double progress)? onProgress,
  CancelToken? cancelToken,
  required String outputPathForCleanup,
}) async {
  final port = ReceivePort();
  final completer = Completer<String>();
  late final Isolate isolate;

  void cleanupAndCancel() {
    isolate.kill(priority: Isolate.immediate);
    final f = File(outputPathForCleanup);
    if (f.existsSync()) f.deleteSync();
    if (!completer.isCompleted) {
      completer.completeError(const VideoToolException('Cancelled.'));
    }
  }

  final sub = port.listen((message) {
    if (message is List && message.isNotEmpty && message[0] is String) {
      switch (message[0]) {
        case 'progress':
          onProgress?.call(message[1] as double);
        case 'done':
          if (!completer.isCompleted) {
            completer.complete(message[1] as String);
          }
        case 'error':
          if (!completer.isCompleted) {
            completer.completeError(VideoToolException(message[1] as String));
          }
      }
    } else if (!completer.isCompleted) {
      // Uncaught error from Isolate.spawn's onError port: a two-element
      // [errorMessage, stackTrace] list per the Isolate.spawn contract.
      completer.completeError(
        VideoToolException(
          message is List ? message.first.toString() : message.toString(),
        ),
      );
    }
  });

  isolate = await Isolate.spawn(
    entry,
    [port.sendPort, ...args],
    onError: port.sendPort,
    onExit: port.sendPort,
    errorsAreFatal: true,
  );
  cancelToken?.attach(cleanupAndCancel);

  try {
    return await completer.future;
  } finally {
    cancelToken?.detach();
    sub.cancel();
    port.close();
    isolate.kill();
  }
}

void _sendProgress(SendPort port, double value) =>
    port.send(['progress', value]);

// ---- mute: MediaExtractor -> MediaMuxer, video track only ----

void _muteVideoWorker(List<Object?> args) {
  final port = args[0] as SendPort;
  final inputPath = args[1] as String;
  final outputPath = args[2] as String;
  try {
    final path = _muteVideoSync(inputPath, outputPath, port);
    port.send(['done', path]);
  } on jni.JThrowable catch (e) {
    port.send(['error', e.message]);
  } catch (e) {
    port.send(['error', e.toString()]);
  }
}

String _muteVideoSync(String inputPath, String outputPath, SendPort port) {
  final finalPath = _withExtensionOf(outputPath, inputPath);
  _deleteIfExists(finalPath);

  final extractor = MediaExtractor();
  extractor.dataSource$3 = inputPath.toJString();
  final videoTrack = _findTrack(extractor, 'video/');
  if (videoTrack == null) {
    throw const VideoToolException('No video track found in this file.');
  }
  extractor.selectTrack(videoTrack.$1);

  final muxer = MediaMuxer.new$1(
    finalPath.toJString(),
    MediaMuxer$OutputFormat.MUXER_OUTPUT_MPEG_4,
  );
  final outVideoTrack = muxer.addTrack(videoTrack.$2);
  muxer.start();

  final durationUs = videoTrack.$2.containsKey('durationUs'.toJString())
      ? videoTrack.$2.getLong('durationUs'.toJString())
      : 0;
  final buffer = jni.JByteBuffer.allocateDirect(1 << 20);
  final bufferInfo = MediaCodec$BufferInfo();
  var framesSinceYield = 0;
  while (true) {
    final size = extractor.readSampleData(buffer, 0);
    if (size < 0) break;
    bufferInfo.offset = 0;
    bufferInfo.size = size;
    bufferInfo.presentationTimeUs = extractor.sampleTime;
    bufferInfo.flags = extractor.sampleFlags;
    muxer.writeSampleData(outVideoTrack, buffer, bufferInfo);
    extractor.advance();

    if (++framesSinceYield >= 30) {
      framesSinceYield = 0;
      if (durationUs > 0) {
        _sendProgress(
          port,
          (bufferInfo.presentationTimeUs / durationUs).clamp(0.0, 1.0),
        );
      }
    }
  }

  muxer.stop();
  muxer.release$1();
  extractor.release$1();
  return finalPath;
}

// ---- merge: fast-path MediaExtractor -> MediaMuxer only (see class doc) ----

void _mergeVideosWorker(List<Object?> args) {
  final port = args[0] as SendPort;
  final inputPaths = (args[1] as List).cast<String>();
  final outputPath = args[2] as String;
  try {
    final path = _mergeVideosSync(inputPaths, outputPath, port);
    port.send(['done', path]);
  } on jni.JThrowable catch (e) {
    port.send(['error', e.message]);
  } catch (e) {
    port.send(['error', e.toString()]);
  }
}

/// Only the fast, no-re-encode path is implemented (see the class doc for
/// why) — if [inputPaths]' video (and, when present, audio) tracks don't
/// all share the same encoding parameters, this throws rather than
/// silently producing a malformed file or a bad merge. Compressing the
/// mismatched clip(s) to matching settings first (this package's own
/// `compressVideo`, which already works on Android via FFmpeg) is the
/// current workaround.
String _mergeVideosSync(
  List<String> inputPaths,
  String outputPath,
  SendPort port,
) {
  final finalPath = _withExtensionOf(outputPath, inputPaths.first);
  _deleteIfExists(finalPath);

  final videoFormats = <MediaFormat>[];
  final audioFormats = <MediaFormat?>[];
  for (final path in inputPaths) {
    final extractor = MediaExtractor();
    extractor.dataSource$3 = path.toJString();
    final video = _findTrack(extractor, 'video/');
    if (video == null) {
      throw VideoToolException(
        'No video track found in "${p.basename(path)}".',
      );
    }
    videoFormats.add(video.$2);
    audioFormats.add(_findTrack(extractor, 'audio/')?.$2);
    extractor.release$1();
  }

  final canStreamCopy =
      _allCompatible(videoFormats) &&
      (audioFormats.every((f) => f == null) ||
          (audioFormats.every((f) => f != null) &&
              _allCompatible(audioFormats.whereType<MediaFormat>().toList())));

  if (!canStreamCopy) {
    throw const VideoToolException(
      'These clips can\'t be merged directly — they have different '
      'resolutions or encoding settings. Try compressing them to matching '
      'settings first, then merge.',
    );
  }

  return _mergeStreamCopy(
    inputPaths,
    finalPath,
    videoFormats.first,
    audioFormats.firstWhere((f) => f != null, orElse: () => null),
    port,
  );
}

/// Whether every format in [formats] has the same mime/width/height (video)
/// or mime/sample-rate/channel-count (audio) and, when both define `csd-0`,
/// byte-identical codec-specific config — i.e. whether `MediaMuxer` (one
/// fixed format per track for the muxer's whole lifetime) can take samples
/// from all of them without a re-encode. This is the Android-side
/// equivalent of AVAssetExportSession silently returning `nil` for
/// `AVAssetExportPresetPassthrough` when clips don't actually share
/// encoding parameters — `MediaMuxer` has no such graceful rejection, it
/// would just write a malformed track, so the check has to happen here.
bool _allCompatible(List<MediaFormat> formats) {
  if (formats.length <= 1) return true;
  final first = formats.first;
  final mime = first.getString('mime'.toJString())?.toDartString();
  for (final f in formats.skip(1)) {
    if (f.getString('mime'.toJString())?.toDartString() != mime) return false;
  }
  final isVideo = mime?.startsWith('video/') ?? false;
  if (isVideo) {
    final w = first.getInteger('width'.toJString());
    final h = first.getInteger('height'.toJString());
    for (final f in formats.skip(1)) {
      if (f.getInteger('width'.toJString()) != w ||
          f.getInteger('height'.toJString()) != h) {
        return false;
      }
    }
  } else {
    final rate = first.getInteger('sample-rate'.toJString());
    final channels = first.getInteger('channel-count'.toJString());
    for (final f in formats.skip(1)) {
      if (f.getInteger('sample-rate'.toJString()) != rate ||
          f.getInteger('channel-count'.toJString()) != channels) {
        return false;
      }
    }
  }
  return _csdMatches(formats, 'csd-0') && _csdMatches(formats, 'csd-1');
}

bool _csdMatches(List<MediaFormat> formats, String key) {
  Uint8List? firstBytes;
  final firstHas = formats.first.containsKey(key.toJString());
  for (final f in formats) {
    final has = f.containsKey(key.toJString());
    if (has != firstHas) return false;
    if (!has) continue;
    final buf = f.getByteBuffer(key.toJString());
    // Not always a direct buffer in practice (found on a real device: a
    // heap/array-backed csd-0 ByteBuffer threw on asUint8List, which
    // requires JByteBuffer.allocateDirect) — fall back to its backing
    // array when it isn't.
    final bytes = buf == null
        ? null
        : buf.isDirect
        ? buf.asUint8List(releaseOriginal: true)
        : Uint8List.fromList(buf.array.asDart().cast<int>());
    if (firstBytes == null) {
      firstBytes = bytes;
    } else if (bytes == null ||
        bytes.length != firstBytes.length ||
        !_bytesEqual(bytes, firstBytes)) {
      return false;
    }
  }
  return true;
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _mergeStreamCopy(
  List<String> inputPaths,
  String finalPath,
  MediaFormat videoFormat,
  MediaFormat? audioFormat,
  SendPort port,
) {
  final muxer = MediaMuxer.new$1(
    finalPath.toJString(),
    MediaMuxer$OutputFormat.MUXER_OUTPUT_MPEG_4,
  );
  final outVideoTrack = muxer.addTrack(videoFormat);
  final outAudioTrack = audioFormat != null
      ? muxer.addTrack(audioFormat)
      : null;
  muxer.start();

  final buffer = jni.JByteBuffer.allocateDirect(1 << 20);
  final bufferInfo = MediaCodec$BufferInfo();
  var videoOffsetUs = 0;
  var audioOffsetUs = 0;
  // MediaMuxer rejects any sample whose presentationTimeUs doesn't strictly
  // increase *within its own track* — clamping against the last value this
  // track actually wrote (rather than trusting each clip's own reported
  // `durationUs` for the next clip's offset) survives the real-world case
  // that broke this: an audio track's last sample can start *after* the
  // container's own reported duration (encoder priming/padding), which
  // made the next clip's audio offset undershoot and land earlier than a
  // sample already written — MediaMuxer then throws with "do not support
  // out of order frames" and the whole export fails.
  var lastVideoPtsWritten = -1;
  var lastAudioPtsWritten = -1;

  for (var clipIndex = 0; clipIndex < inputPaths.length; clipIndex++) {
    final extractor = MediaExtractor();
    extractor.dataSource$3 = inputPaths[clipIndex].toJString();
    final video = _findTrack(extractor, 'video/')!;
    final audio = outAudioTrack != null
        ? _findTrack(extractor, 'audio/')
        : null;
    extractor.selectTrack(video.$1);
    if (audio != null) extractor.selectTrack(audio.$1);

    while (true) {
      final srcTrack = extractor.sampleTrackIndex;
      if (srcTrack < 0) break;
      final size = extractor.readSampleData(buffer, 0);
      if (size < 0) break;
      bufferInfo.offset = 0;
      bufferInfo.size = size;
      bufferInfo.flags = extractor.sampleFlags;
      final ptsUs = extractor.sampleTime;

      if (srcTrack == video.$1) {
        var outPts = ptsUs + videoOffsetUs;
        if (outPts <= lastVideoPtsWritten) outPts = lastVideoPtsWritten + 1;
        bufferInfo.presentationTimeUs = outPts;
        muxer.writeSampleData(outVideoTrack, buffer, bufferInfo);
        lastVideoPtsWritten = outPts;
      } else if (audio != null && srcTrack == audio.$1) {
        var outPts = ptsUs + audioOffsetUs;
        if (outPts <= lastAudioPtsWritten) outPts = lastAudioPtsWritten + 1;
        bufferInfo.presentationTimeUs = outPts;
        muxer.writeSampleData(outAudioTrack!, buffer, bufferInfo);
        lastAudioPtsWritten = outPts;
      }
      extractor.advance();
    }
    extractor.release$1();

    // +1 so the next clip's first sample (offset-adjusted) lands strictly
    // after this clip's last one even before the per-sample clamp above
    // ever has to kick in.
    videoOffsetUs = lastVideoPtsWritten + 1;
    if (audio != null) {
      audioOffsetUs = lastAudioPtsWritten + 1;
    }
    _sendProgress(port, (clipIndex + 1) / inputPaths.length);
  }

  muxer.stop();
  muxer.release$1();
  return finalPath;
}

// ---- reverse: MediaCodec decode (Image) -> reverse -> MediaCodec encode (Image) ----

const _videoMimeAvc = 'video/avc';

void _reverseVideoWorker(List<Object?> args) {
  final port = args[0] as SendPort;
  final inputPath = args[1] as String;
  final outputPath = args[2] as String;
  try {
    final path = _reverseVideoSync(inputPath, outputPath, port);
    port.send(['done', path]);
  } on jni.JThrowable catch (e) {
    port.send(['error', e.message]);
  } catch (e) {
    port.send(['error', e.toString()]);
  }
}

class _Frame {
  _Frame(this.y, this.u, this.v);
  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
}

String _reverseVideoSync(String inputPath, String outputPath, SendPort port) {
  final finalPath = _withExtensionOf(outputPath, inputPath);
  _deleteIfExists(finalPath);

  final extractor = MediaExtractor();
  extractor.dataSource$3 = inputPath.toJString();
  final video = _findTrack(extractor, 'video/');
  if (video == null) {
    throw const VideoToolException('No video track found in this file.');
  }
  extractor.selectTrack(video.$1);

  final format = video.$2;
  final width = format.getInteger('width'.toJString());
  final height = format.getInteger('height'.toJString());
  final durationUs = format.containsKey('durationUs'.toJString())
      ? format.getLong('durationUs'.toJString())
      : 0;
  final frameRate = format.containsKey('frame-rate'.toJString())
      ? format.getInteger('frame-rate'.toJString())
      : 30;
  final mime = format.getString('mime'.toJString())!.toDartString();

  // Same reasoning as the AVFoundation reverse's memory-budget guard: every
  // frame is decoded into memory up front, so a long/high-res clip can
  // demand far more RAM than a phone actually has. YUV420 is 1.5 bytes/px
  // (vs. AVFoundation's 4-byte BGRA), so the safe ceiling here is larger.
  final estimatedFrameCount = ((durationUs / 1000000) * frameRate).round();
  final bytesPerFrame = (width * height * 1.5).round();
  const maxDecodedBytes = 2 * 1024 * 1024 * 1024; // 2 GB
  if (estimatedFrameCount * bytesPerFrame > maxDecodedBytes) {
    final maxSeconds = (maxDecodedBytes / bytesPerFrame / frameRate).floor();
    throw VideoToolException(
      'This video is too long to reverse at its resolution (${width}x$height) '
      '— clips up to about ${maxSeconds}s at this resolution are supported.',
    );
  }

  final decoder = MediaCodec.createDecoderByType(mime.toJString())!;
  decoder.configure(format, null, null, 0);
  decoder.start();

  final frames = <_Frame>[];
  final decInfo = MediaCodec$BufferInfo();
  var sawInputEos = false;
  var sawOutputEos = false;
  var framesSinceYield = 0;
  var decodeLoopIterations = 0;

  while (!sawOutputEos) {
    // A safety net, not an expected case: every real MediaCodec session
    // reaches end-of-stream in well under this many dequeue attempts, even
    // at 10ms timeouts each — if it doesn't, something's genuinely wedged
    // (e.g. a muxer/codec state bug elsewhere), and looping forever with
    // near-zero CPU is a much worse failure mode than a clear error.
    if (++decodeLoopIterations > 20000) {
      throw VideoToolException(
        'Timed out decoding frames (frames=${frames.length}).',
      );
    }
    if (!sawInputEos) {
      final inIndex = decoder.dequeueInputBuffer(10000);
      if (inIndex >= 0) {
        final inBuf = decoder.getInputBuffer(inIndex)!;
        final size = extractor.readSampleData(inBuf, 0);
        if (size < 0) {
          decoder.queueInputBuffer(
            inIndex,
            0,
            0,
            0,
            MediaCodec.BUFFER_FLAG_END_OF_STREAM,
          );
          sawInputEos = true;
        } else {
          decoder.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0);
          extractor.advance();
        }
      }
    }

    final outIndex = decoder.dequeueOutputBuffer(decInfo, 10000);
    if (outIndex >= 0) {
      if (decInfo.size > 0) {
        final image = decoder.getOutputImage(outIndex)!;
        frames.add(_copyImageToFrame(image, width, height));
        image.close();
      }
      decoder.releaseOutputBuffer(outIndex, false);
      if ((decInfo.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
        sawOutputEos = true;
      }
    }

    if (++framesSinceYield >= 15) {
      framesSinceYield = 0;
      if (estimatedFrameCount > 0) {
        _sendProgress(
          port,
          (frames.length / estimatedFrameCount / 2).clamp(0.0, 0.5),
        );
      }
    }
  }
  decoder.stop();
  decoder.release$1();
  extractor.release$1();

  if (frames.isEmpty) {
    throw const VideoToolException(
      'No frames could be decoded from this file.',
    );
  }

  final encodeFormat = MediaFormat.createVideoFormat(
    _videoMimeAvc.toJString(),
    width,
    height,
  )!;
  encodeFormat.setInteger(
    'color-format'.toJString(),
    NativeVideoToolkitAndroid.colorFormatYuv420Flexible,
  );
  encodeFormat.setInteger('bitrate'.toJString(), _bitRateFor(width, height));
  encodeFormat.setInteger('frame-rate'.toJString(), frameRate);
  encodeFormat.setInteger('i-frame-interval'.toJString(), 1);

  final encoder = MediaCodec.createEncoderByType(_videoMimeAvc.toJString())!;
  encoder.configure(encodeFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
  encoder.start();

  final muxer = MediaMuxer.new$1(
    finalPath.toJString(),
    MediaMuxer$OutputFormat.MUXER_OUTPUT_MPEG_4,
  );
  var muxerVideoTrack = -1;
  var muxerStarted = false;
  final encInfo = MediaCodec$BufferInfo();
  final frameDurationUs = (1000000 / frameRate).round();
  final frameByteSize = (width * height * 1.5).round();

  var nextFrameToSend = frames.length - 1;
  var eosQueued = false;
  var encFramesSinceYield = 0;
  var encodeLoopIterations = 0;

  while (true) {
    // Same reasoning as the decode loop's cap above.
    if (++encodeLoopIterations > 20000) {
      throw const VideoToolException('Timed out encoding the reversed video.');
    }
    if (!eosQueued) {
      final inIndex = encoder.dequeueInputBuffer(10000);
      if (inIndex >= 0) {
        if (nextFrameToSend < 0) {
          encoder.queueInputBuffer(
            inIndex,
            0,
            0,
            frames.length * frameDurationUs,
            MediaCodec.BUFFER_FLAG_END_OF_STREAM,
          );
          eosQueued = true;
        } else {
          final image = encoder.getInputImage(inIndex)!;
          _copyFrameToImage(frames[nextFrameToSend], image, width, height);
          image.close();
          final pts = (frames.length - 1 - nextFrameToSend) * frameDurationUs;
          // The `size` argument matters even though the data was written
          // via the Image API (not a raw ByteBuffer) — it's the codec's
          // only signal for how many bytes of the buffer are valid.
          // Passing 0 here (a real bug, found by tracing a hang on a real
          // device: the encoder accepted a handful of frames, then both
          // dequeueInputBuffer and dequeueOutputBuffer returned -1
          // forever, wedged) reads as "empty frame" and this codec
          // implementation stalls its whole pipeline rather than
          // rejecting it cleanly.
          encoder.queueInputBuffer(inIndex, 0, frameByteSize, pts, 0);
          nextFrameToSend--;
        }
      }
    }

    final outIndex = encoder.dequeueOutputBuffer(encInfo, 10000);
    if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
      if (!muxerStarted) {
        muxerVideoTrack = muxer.addTrack(encoder.outputFormat!);
        muxer.start();
        muxerStarted = true;
      }
    } else if (outIndex >= 0) {
      // MediaMuxer's contract: codec-config data (SPS/PPS) is only ever
      // taken from the MediaFormat passed to addTrack (read above from
      // encoder.outputFormat at INFO_OUTPUT_FORMAT_CHANGED) — it must never
      // also be written as a sample via writeSampleData. Some encoders
      // additionally emit an explicit BUFFER_FLAG_CODEC_CONFIG buffer as
      // their first output; feeding that into the muxer anyway produces a
      // native "Already have codec specific data" error and wedges the
      // muxer's writer thread, hanging every subsequent writeSampleData
      // call indefinitely.
      final isCodecConfig =
          (encInfo.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0;
      if (encInfo.size > 0 && muxerStarted && !isCodecConfig) {
        final outBuf = encoder.getOutputBuffer(outIndex)!;
        muxer.writeSampleData(muxerVideoTrack, outBuf, encInfo);
      }
      encoder.releaseOutputBuffer(outIndex, false);
      if ((encInfo.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
        break;
      }
    }

    if (++encFramesSinceYield >= 15) {
      encFramesSinceYield = 0;
      final done = frames.length - 1 - nextFrameToSend;
      _sendProgress(port, 0.5 + (done / frames.length / 2).clamp(0.0, 0.5));
    }
  }

  encoder.stop();
  encoder.release$1();
  if (muxerStarted) {
    muxer.stop();
    muxer.release$1();
  }
  _sendProgress(port, 1.0);
  return finalPath;
}

int _bitRateFor(int width, int height) {
  // A flat, generous-but-bounded target — reverse re-encodes at the
  // source's own resolution with no quality tier selection (unlike
  // compressVideo), so this only needs to avoid visible blocking, not match
  // the source bitrate exactly.
  final pixels = width * height;
  if (pixels >= 1920 * 1080) return 8000000;
  if (pixels >= 1280 * 720) return 5000000;
  return 2500000;
}

_Frame _copyImageToFrame(Image image, int width, int height) {
  final planes = image.planes!;
  final y = _copyPlaneOut(planes[0]!, width, height);
  final chromaW = (width / 2).ceil();
  final chromaH = (height / 2).ceil();
  final u = _copyPlaneOut(planes[1]!, chromaW, chromaH);
  final v = _copyPlaneOut(planes[2]!, chromaW, chromaH);
  return _Frame(y, u, v);
}

Uint8List _copyPlaneOut(Image$Plane plane, int width, int height) {
  final rowStride = plane.rowStride;
  final pixelStride = plane.pixelStride;
  final src = plane.buffer!.asUint8List(releaseOriginal: true);
  final out = Uint8List(width * height);
  var o = 0;
  for (var row = 0; row < height; row++) {
    final rowStart = row * rowStride;
    if (pixelStride == 1) {
      out.setRange(o, o + width, src, rowStart);
      o += width;
    } else {
      for (var col = 0; col < width; col++) {
        out[o++] = src[rowStart + col * pixelStride];
      }
    }
  }
  return out;
}

void _copyFrameToImage(_Frame frame, Image image, int width, int height) {
  final planes = image.planes!;
  final chromaW = (width / 2).ceil();
  final chromaH = (height / 2).ceil();
  _copyPlaneIn(frame.y, planes[0]!, width, height);
  _copyPlaneIn(frame.u, planes[1]!, chromaW, chromaH);
  _copyPlaneIn(frame.v, planes[2]!, chromaW, chromaH);
}

void _copyPlaneIn(Uint8List src, Image$Plane plane, int width, int height) {
  final rowStride = plane.rowStride;
  final pixelStride = plane.pixelStride;
  final dst = plane.buffer!.asUint8List();
  var o = 0;
  for (var row = 0; row < height; row++) {
    final rowStart = row * rowStride;
    if (pixelStride == 1) {
      dst.setRange(rowStart, rowStart + width, src, o);
      o += width;
    } else {
      for (var col = 0; col < width; col++) {
        dst[rowStart + col * pixelStride] = src[o++];
      }
    }
  }
}

// ---- shared helpers ----

/// Returns `(trackIndex, format)` for the first track whose mime starts
/// with [mimePrefix] (`'video/'`/`'audio/'`), or `null`.
(int, MediaFormat)? _findTrack(MediaExtractor extractor, String mimePrefix) {
  final count = extractor.trackCount;
  for (var i = 0; i < count; i++) {
    final format = extractor.getTrackFormat(i)!;
    final mime = format.getString('mime'.toJString())?.toDartString();
    if (mime != null && mime.startsWith(mimePrefix)) return (i, format);
  }
  return null;
}

String _withExtensionOf(String outputPath, String originalPath) {
  final ext = p.extension(originalPath);
  return ext.isEmpty ? outputPath : p.setExtension(outputPath, ext);
}

void _deleteIfExists(String path) {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
}
