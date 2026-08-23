import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'cancel_token.dart';
import 'exceptions.dart';

/// A fresh, uniquely-named scratch directory under the app's Documents
/// directory (never a system temp dir — sandboxed macOS builds can't
/// reliably use one) for one intermediate file. The caller deletes it once
/// done (see `NativeVideoToolkit._cleanupIfTemp`).
Future<Directory> _newScratchDir() async {
  final documents = await getApplicationDocumentsDirectory();
  final scratchRoot = Directory(
    p.join(documents.path, '.native_video_toolkit_cache'),
  );
  final dir = Directory(
    p.join(scratchRoot.path, '${DateTime.now().microsecondsSinceEpoch}'),
  );
  await dir.create(recursive: true);
  return dir;
}

/// A scratch file path named [name] inside a fresh scratch directory (see
/// [_newScratchDir]) — for a caller that needs to hand AVFoundation an
/// intermediate output path before a final [remuxToMatchFormat] pass, e.g.
/// when the ultimate target container isn't one AVFoundation can write
/// directly.
Future<File> newScratchFile(String name) async {
  final dir = await _newScratchDir();
  return File(p.join(dir.path, name));
}

/// Containers AVFoundation can both read (`AVURLAsset`/`AVAssetReader`) and
/// write (`AVAssetExportSession`/`AVAssetWriter`) natively. There is no
/// OS-level extensibility point for adding container support beyond this
/// set — unlike a full player (VLC/mpv/IINA), which bundles its own
/// FFmpeg-based demux/mux stack instead of using AVFoundation at all.
const avFoundationNativeExtensions = {'mp4', 'mov', 'm4v', '3gp', '3g2'};

/// Whether AVFoundation can open/write [path]'s container directly, with no
/// FFmpeg pre/post-processing needed.
bool isAvFoundationNative(String path) =>
    avFoundationNativeExtensions.contains(_extensionOf(path));

/// Video codecs `AVAssetReader`/`AVAssetExportSession`/`AVPlayer` can
/// actually decode. This is the key distinction `-c copy` doesn't know
/// about: FFmpeg will happily stream-copy VP9 or AV1 video into an mp4 box
/// (it's a legal container for them) and report success, but AVFoundation
/// then opens that mp4, sees a video track it has no decoder for, and
/// silently fails to render it — while the audio track (if its codec *is*
/// supported) keeps playing fine. That's the "video plays audio only, no
/// picture" symptom, and the same undecodable track is why
/// `AVAssetReader`-based reverse fails with "no frames could be decoded"
/// and why mute/compress exports of the same file fail or hang.
const _avFoundationDecodableVideoCodecs = {
  'h264',
  'hevc',
  'mpeg4',
  'mpeg2video',
  'mjpeg',
  'prores',
};

/// Audio codecs AVFoundation can decode. Deliberately conservative — Opus,
/// Vorbis, AC-3/E-AC-3 and DTS (all common in MKV) are excluded even though
/// some ship in some macOS versions, because a codec that quietly fails to
/// decode is worse than an unnecessary re-encode.
const _avFoundationDecodableAudioCodecs = {
  'aac',
  'mp3',
  'alac',
  'flac',
  'pcm_s16le',
  'pcm_s16be',
  'pcm_s24le',
  'pcm_f32le',
};

/// Ensures [input] is in a container AVFoundation can open, transparently
/// remuxing/transcoding it to a temporary `.mp4` via FFmpeg first if not.
/// Returns [input] unchanged when it's already AVFoundation-native.
///
/// First probes the source's actual video/audio codecs with FFprobe. Only
/// when both are already codecs AVFoundation can decode (see
/// [_avFoundationDecodableVideoCodecs]/[_avFoundationDecodableAudioCodecs])
/// does this try a fast stream copy (`-c copy` — repackage the existing
/// compressed streams into an mp4 container, no re-encoding, seconds not
/// minutes). Otherwise — or if that stream copy still fails for some other
/// reason — it falls back to a full hardware re-encode
/// (`-c:v h264_videotoolbox -c:a aac`), which AVFoundation can always read.
Future<File> ensureAvFoundationCompatible(
  File input, {
  CancelToken? cancelToken,
}) async {
  if (isAvFoundationNative(input.path)) {
    return input;
  }
  cancelToken?.throwIfCancelled();

  final scratchDir = await _newScratchDir();
  final normalized = File(
    p.join(scratchDir.path, '${p.basenameWithoutExtension(input.path)}.mp4'),
  );

  final codecs = await probeMediaInfo(input.path);
  final canStreamCopy =
      (codecs.videoCodec == null ||
          _avFoundationDecodableVideoCodecs.contains(codecs.videoCodec)) &&
      (codecs.audioCodec == null ||
          _avFoundationDecodableAudioCodecs.contains(codecs.audioCodec));

  // `-map 0:v:0 -map 0:a?` picks exactly one video stream plus audio *if
  // present* (the `?` makes the audio map optional) — without it, ffmpeg's
  // default stream selection also tries to carry along subtitle/attachment
  // streams MKV commonly has (SRT/ASS text, embedded fonts), which either
  // aren't legal inside an mp4 box or aren't legal with `-c copy`/`-c:a aac`
  // applied to them, and previously made the whole command fail outright on
  // videos with no audio track or with a subtitle track.
  //
  // `-tag:v hvc1` matters specifically for HEVC (very common in MKV rips,
  // e.g. x265 releases): ffmpeg's default mp4 tag for stream-copied HEVC is
  // `hev1` (out-of-band parameter sets), which AVFoundation/AVPlayer/
  // AVAssetReader largely refuse to decode — it opens the file and reports
  // a video track, but can't produce frames from it (`AVAssetReader`
  // fails with "Cannot Decode"; `AVAssetExportSession` fails with
  // "Operation Stopped"), while an AAC audio track alongside it decodes
  // fine — exactly the "plays audio, no picture" symptom. Retagging the
  // same bitstream as `hvc1` (in-band parameter sets, no re-encode) is the
  // standard fix and is a no-op for every other codec.
  if (canStreamCopy &&
      await _run([
        '-y',
        '-i',
        input.path,
        '-map',
        '0:v:0',
        '-map',
        '0:a?',
        '-c',
        'copy',
        if (codecs.videoCodec == 'hevc') ...['-tag:v', 'hvc1'],
        '-movflags',
        '+faststart',
        normalized.path,
      ])) {
    return normalized;
  }
  cancelToken?.throwIfCancelled();

  // Either the source codec can't legally live inside an mp4 container at
  // all (common for older AVI codecs, WMV/VC-1), or it can be muxed into
  // one but AVFoundation still can't decode it (VP9/AV1/Opus/AC-3 in an
  // MKV, see [_avFoundationDecodableVideoCodecs]) — re-encode to codecs
  // AVFoundation is guaranteed to support either way.
  //
  // Hardware H.264 via VideoToolbox — the same media-engine block
  // AVAssetExportSession itself uses. This used to fall back to software
  // `libx264` if VideoToolbox rejected the source (e.g. an odd pixel
  // format), but this app ships FFmpeg's non-GPL build (no x264 — GPL is
  // legally incompatible with App Store distribution, see
  // packages/ffmpeg_kit_flutter_new_nongpl/README-NONGPL-PATCH.md), so a
  // source VideoToolbox can't hardware-encode now has no further fallback
  // and throws below instead.
  if (await _run([
    '-y',
    '-i',
    input.path,
    '-map',
    '0:v:0',
    '-map',
    '0:a?',
    ..._hardwareVideoEncodeArgs(codecs.estimatedVideoBitRate ?? 8000000),
    '-c:a',
    'aac',
    '-movflags',
    '+faststart',
    normalized.path,
  ])) {
    return normalized;
  }
  cancelToken?.throwIfCancelled();

  throw VideoToolException(
    'Could not read "${p.basename(input.path)}" — this format/codec is not '
    'supported by AVFoundation and FFmpeg could not convert it either.',
  );
}

class ProbedMediaInfo {
  const ProbedMediaInfo({
    required this.videoCodec,
    required this.audioCodec,
    required this.videoBitRate,
    required this.formatBitRate,
    required this.sizeBytes,
    required this.durationSeconds,
    required this.width,
    required this.height,
  });

  final String? videoCodec;
  final String? audioCodec;

  /// The video stream's own reported bitrate in bits/sec, or `null` — many
  /// MKV/AVI muxers simply never write this field, so [estimatedVideoBitRate]
  /// is almost always the one worth using instead.
  final int? videoBitRate;

  /// The *container's* average bitrate (video + audio combined) in bits/sec,
  /// or `null` if ffprobe didn't report one either.
  final int? formatBitRate;
  final int? sizeBytes;
  final double? durationSeconds;
  final int? width;
  final int? height;

  /// Best-effort real estimate of the video track's own bitrate, in
  /// bits/sec — `null` only when literally nothing (not even file size +
  /// duration) was probeable.
  ///
  /// Falls back through: the stream's own reported bitrate (rare for MKV)
  /// → the container's average bitrate minus a typical AAC audio share →
  /// size/duration as a last resort. This exists because a source that's
  /// already efficiently encoded (e.g. HEVC at a genuinely low bitrate) has
  /// to be measured, not assumed — re-encoding it against a fixed flat
  /// default instead of this estimate is exactly what previously made
  /// "Compress Video" balloon a 99MB HEVC episode into a 2.3GB H.264 one.
  int? get estimatedVideoBitRate {
    if (videoBitRate != null && videoBitRate! > 0) return videoBitRate;
    final total = (formatBitRate != null && formatBitRate! > 0)
        ? formatBitRate
        : (sizeBytes != null && durationSeconds != null && durationSeconds! > 0
              ? (sizeBytes! * 8 / durationSeconds!).round()
              : null);
    if (total == null || total <= 0) return null;
    // Only one audio stream ever survives `-map 0:a?` regardless of how many
    // the source has, so a flat single-track subtraction (not per-track) is
    // the right estimate here.
    final audioShare = audioCodec != null ? 128000 : 0;
    final videoOnly = total - audioShare;
    return videoOnly > 0 ? videoOnly : total;
  }
}

/// Probes [path] for the facts [ensureAvFoundationCompatible] and
/// `NativeVideoToolkit.compressVideo` need to size a re-encode relative to
/// the source rather than against a fixed, source-blind target. Probe
/// failures are treated as "unknown" (an all-null [ProbedMediaInfo]) rather
/// than thrown — callers fall through to a safe default in that case.
Future<ProbedMediaInfo> probeMediaInfo(String path) async {
  try {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    final streams = info?.getStreams() ?? const [];

    // ffprobe's own `codec_type` field values — "video"/"audio"/"subtitle"/
    // "data" — not something the plugin exposes as named constants.
    String? codecOf(String codecType) {
      for (final stream in streams) {
        if (stream.getType() == codecType) {
          return stream.getCodec()?.toLowerCase();
        }
      }
      return null;
    }

    int? videoBitRateOf() {
      for (final stream in streams) {
        if (stream.getType() == 'video') {
          return int.tryParse(stream.getBitrate() ?? '');
        }
      }
      return null;
    }

    int? videoDimension(int? Function(dynamic stream) getter) {
      for (final stream in streams) {
        if (stream.getType() == 'video') return getter(stream);
      }
      return null;
    }

    final file = File(path);
    return ProbedMediaInfo(
      videoCodec: codecOf('video'),
      audioCodec: codecOf('audio'),
      videoBitRate: videoBitRateOf(),
      formatBitRate: int.tryParse(info?.getBitrate() ?? ''),
      sizeBytes: file.existsSync() ? file.lengthSync() : null,
      durationSeconds: double.tryParse(info?.getDuration() ?? ''),
      width: videoDimension((s) => s.getWidth()),
      height: videoDimension((s) => s.getHeight()),
    );
  } catch (_) {
    return const ProbedMediaInfo(
      videoCodec: null,
      audioCodec: null,
      videoBitRate: null,
      formatBitRate: null,
      sizeBytes: null,
      durationSeconds: null,
      width: null,
      height: null,
    );
  }
}

/// Encoder args for a hardware H.264 re-encode via VideoToolbox — the same
/// hardware media-engine block `AVAssetExportSession` itself uses, and the
/// only H.264 encoder available at all now that this app ships FFmpeg's
/// non-GPL build (no software `libx264` — see packages/
/// ffmpeg_kit_flutter_new_nongpl/README-NONGPL-PATCH.md). VideoToolbox's
/// ffmpeg wrapper has no `-crf`-style constant-quality mode, so
/// [targetBitRate] (bits/sec) drives it directly via
/// `-b:v`/`-maxrate`/`-bufsize`.
///
/// `-maxrate`/`-bufsize` are kept tight (close to `-b:v` itself) rather than
/// the more generous headroom a CRF-like encode would want — VideoToolbox's
/// average bitrate control is loose enough that a looser VBV budget let real
/// output run ~40% over the requested target on one low-bitrate test file,
/// which is exactly the kind of overshoot `NativeVideoToolkit.compressVideo`
/// can't afford (its whole guarantee is "never bigger than the source").
List<String> _hardwareVideoEncodeArgs(int targetBitRate) {
  final maxRate = (targetBitRate * 1.1).round();
  final bufSize = targetBitRate;
  return [
    '-c:v',
    'h264_videotoolbox',
    '-b:v',
    '$targetBitRate',
    '-maxrate',
    '$maxRate',
    '-bufsize',
    '$bufSize',
  ];
}

/// Runs a real compress: a hardware (VideoToolbox) H.264 re-encode of
/// [inputPath]'s video track at [targetBitRate] bits/sec (optionally
/// downscaled to [scaleHeight]), with audio copied through unchanged —
/// compress only ever targets the video track, and copying avoids any extra
/// audio quality loss or re-encode time. Reports real per-second progress
/// via FFmpeg's statistics callback (media time processed / [durationSeconds])
/// when both are available.
///
/// Reads [inputPath] directly — unlike the AVFoundation-based tools
/// elsewhere in this package, FFmpeg can decode almost any source container/
/// codec itself, so no [ensureAvFoundationCompatible] normalization pass is
/// needed first (and skipping it also means a source FFmpeg can't
/// hardware-encode isn't re-encoded twice).
///
/// Tried in tiers: hardware encode + audio copy, then hardware encode with
/// audio re-encoded to AAC (only needed if the source's audio codec isn't
/// legal to just copy into [outputPath]'s container). This used to have a
/// third/fourth tier retrying with software `libx264` if VideoToolbox
/// rejected the source outright, but this app ships FFmpeg's non-GPL build
/// (no x264 — see packages/ffmpeg_kit_flutter_new_nongpl/
/// README-NONGPL-PATCH.md), so that case now just throws.
Future<void> runCompressEncode({
  required String inputPath,
  required String outputPath,
  required int targetBitRate,
  int? scaleHeight,
  double? durationSeconds,
  void Function(double progress)? onProgress,
  CancelToken? cancelToken,
}) async {
  cancelToken?.throwIfCancelled();
  _deleteIfExists(outputPath);

  final scaleArgs = scaleHeight != null
      ? ['-vf', 'scale=-2:$scaleHeight']
      : <String>[];
  final faststartArgs = {'mp4', 'mov', 'm4v'}.contains(_extensionOf(outputPath))
      ? ['-movflags', '+faststart']
      : <String>[];

  Future<bool> attempt(List<String> videoArgs, String audioCodec) {
    cancelToken?.throwIfCancelled();
    return _runAsync(
      [
        '-y',
        '-i',
        inputPath,
        '-map',
        '0:v:0',
        '-map',
        '0:a?',
        ...videoArgs,
        ...scaleArgs,
        '-c:a',
        audioCodec,
        ...faststartArgs,
        outputPath,
      ],
      durationSeconds: durationSeconds,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  final hardwareArgs = _hardwareVideoEncodeArgs(targetBitRate);
  if (await attempt(hardwareArgs, 'copy')) return;
  if (await attempt(hardwareArgs, 'aac')) return;

  cancelToken?.throwIfCancelled();
  throw const VideoToolException('Could not compress this video.');
}

/// Explicit video/audio encoder args for target containers FFmpeg wouldn't
/// otherwise guess well for. Left to its own default codec selection,
/// FFmpeg's per-container default can be a poor/legacy choice (e.g. some
/// builds default `.avi` audio to MP2 or default `.wmv` to WMV1) — spelling
/// out a known-good, broadly-compatible codec per container avoids that.
/// Containers not listed here (rare/exotic targets) fall back to letting
/// FFmpeg choose, since there's no single well-known "right" codec to
/// hardcode for them.
///
/// `mkv`/`ts` used software `libx264` here previously; this app ships
/// FFmpeg's non-GPL build (see packages/ffmpeg_kit_flutter_new_nongpl/
/// README-NONGPL-PATCH.md), so they reuse the same hardware
/// [_hardwareVideoEncodeArgs] every other H.264 encode in this file goes
/// through, at a fixed bitrate since no per-source estimate is available at
/// this remux stage.
Map<String, List<String>> get _explicitContainerEncoderArgs {
  final hardwareH264 = _hardwareVideoEncodeArgs(8000000);
  return {
    'webm': [
      '-c:v',
      'libvpx-vp9',
      '-b:v',
      '0',
      '-crf',
      '32',
      '-c:a',
      'libopus',
    ],
    'ogv': ['-c:v', 'libtheora', '-q:v', '7', '-c:a', 'libvorbis', '-q:a', '5'],
    'ogg': ['-c:v', 'libtheora', '-q:v', '7', '-c:a', 'libvorbis', '-q:a', '5'],
    'avi': [
      '-c:v',
      'mpeg4',
      '-vtag',
      'xvid',
      '-q:v',
      '5',
      '-c:a',
      'libmp3lame',
      '-q:a',
      '4',
    ],
    'flv': ['-c:v', 'flv', '-c:a', 'libmp3lame'],
    'wmv': ['-c:v', 'wmv2', '-c:a', 'wmav2'],
    'mkv': [...hardwareH264, '-c:a', 'aac'],
    'ts': [...hardwareH264, '-c:a', 'aac'],
    'mpg': ['-c:v', 'mpeg2video', '-q:v', '5', '-c:a', 'mp2'],
    'mpeg': ['-c:v', 'mpeg2video', '-q:v', '5', '-c:a', 'mp2'],
  };
}

/// The mirror image of [ensureAvFoundationCompatible]: AVFoundation just
/// wrote [avFoundationOutput] (always an mp4, its only broadly-compatible
/// write format) — this remuxes/transcodes it into [targetPath]'s container
/// so the tool's output matches the *original* input's format rather than
/// silently always producing mp4. Deletes [avFoundationOutput] once
/// [targetPath] exists. No-ops (just renames) if they're already the same
/// extension.
Future<File> remuxToMatchFormat(
  File avFoundationOutput,
  String targetPath, {
  CancelToken? cancelToken,
}) async {
  if (_extensionOf(avFoundationOutput.path) == _extensionOf(targetPath)) {
    if (avFoundationOutput.path == targetPath) return avFoundationOutput;
    return avFoundationOutput.rename(targetPath);
  }
  cancelToken?.throwIfCancelled();

  if (await _run([
    '-y',
    '-i',
    avFoundationOutput.path,
    '-map',
    '0:v:0',
    '-map',
    '0:a?',
    '-c',
    'copy',
    targetPath,
  ])) {
    await avFoundationOutput.delete();
    return File(targetPath);
  }
  cancelToken?.throwIfCancelled();

  // Stream copy into the target container failed — e.g. H.264/AAC (what
  // AVFoundation just produced) can't legally live inside a WebM/OGV
  // container, which need VP8/9+Opus or Theora+Vorbis respectively.
  final explicitArgs = _explicitContainerEncoderArgs[_extensionOf(targetPath)];
  final reencodeArgs = [
    '-y',
    '-i', avFoundationOutput.path,
    '-map', '0:v:0',
    '-map', '0:a?',
    // Only a handful of exotic target containers have no entry above and
    // fall through to FFmpeg's own default codec choice for that muxer.
    ...?explicitArgs,
    targetPath,
  ];
  if (await _run(reencodeArgs)) {
    await avFoundationOutput.delete();
    return File(targetPath);
  }
  cancelToken?.throwIfCancelled();

  throw VideoToolException(
    'Processed the video successfully, but could not export it back to '
    '"${p.extension(targetPath)}" — FFmpeg could not write that container.',
  );
}

/// Extracts a single JPEG frame from [inputPath] as a lightweight preview
/// thumbnail, written to [outputPath]. Seeks to 0.1s rather than frame zero
/// since some encoders emit an all-black or otherwise unrepresentative
/// first frame.
Future<void> extractThumbnail(String inputPath, String outputPath) async {
  // `-update 1` tells the image2 muxer this is a single still image, not the
  // first frame of a sequence — without it, ffmpeg still writes the file but
  // logs a spurious "does not contain an image sequence pattern" warning.
  if (await _run([
    '-y',
    '-ss',
    '00:00:00.1',
    '-i',
    inputPath,
    '-frames:v',
    '1',
    '-update',
    '1',
    '-vf',
    'scale=480:-2',
    '-q:v',
    '4',
    outputPath,
  ])) {
    return;
  }

  // Some very short clips don't have a frame at 0.1s — fall back to frame 0.
  if (await _run([
    '-y',
    '-i',
    inputPath,
    '-frames:v',
    '1',
    '-update',
    '1',
    '-vf',
    'scale=480:-2',
    '-q:v',
    '4',
    outputPath,
  ])) {
    return;
  }

  throw const VideoToolException(
    'Could not generate a thumbnail for this video.',
  );
}

String _extensionOf(String path) =>
    p.extension(path).replaceFirst('.', '').toLowerCase();

void _deleteIfExists(String path) {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
}

/// Runs FFmpeg with [args] as a real argument vector — never a
/// shell-quoted command string. `FFmpegKit.execute(String)` re-splits its
/// input through a simplistic shell-like tokenizer that mishandles paths
/// containing spaces or characters like `"`, `'`, `\` even when the caller
/// wraps them in quotes (a path such as `My "Trip".mov` breaks it outright,
/// and it silently mis-tokenizes plenty of others) — using
/// `executeWithArguments` with each argument as its own list entry hands
/// FFmpeg the exact bytes with no re-parsing step to get wrong.
Future<bool> _run(List<String> args) async {
  final session = await FFmpegKit.executeWithArguments(args);
  final returnCode = await session.getReturnCode();
  return ReturnCode.isSuccess(returnCode);
}

/// The async counterpart of [_run] — runs FFmpeg via
/// `executeWithArgumentsAsync` instead so a statistics callback can report
/// real per-second progress ([durationSeconds] is known up front for a
/// compress, unlike the fire-and-forget normalize/remux steps [_run]
/// handles). Cancellation doesn't need an explicit session handle here:
/// [CancelToken.cancel] already calls `FFmpegKit.cancel()` globally (this
/// toolkit never runs more than one FFmpeg session at a time), so this just
/// has to notice that happened and stop retrying further encode tiers.
Future<bool> _runAsync(
  List<String> args, {
  double? durationSeconds,
  void Function(double progress)? onProgress,
  CancelToken? cancelToken,
}) async {
  final completer = Completer<ReturnCode?>();
  await FFmpegKit.executeWithArgumentsAsync(
    args,
    (session) async {
      final code = await session.getReturnCode();
      if (!completer.isCompleted) completer.complete(code);
    },
    null,
    (durationSeconds != null && durationSeconds > 0 && onProgress != null)
        ? (stats) {
            onProgress(
              (stats.getTime() / 1000 / durationSeconds).clamp(0.0, 1.0),
            );
          }
        : null,
  );
  final returnCode = await completer.future;
  cancelToken?.throwIfCancelled();
  return ReturnCode.isSuccess(returnCode);
}
