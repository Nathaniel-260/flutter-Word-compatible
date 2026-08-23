// Generates lib/src/native_video_toolkit_bindings.g.dart (and its native
// glue file) directly from the macOS SDK's AVFoundation/CoreMedia/CoreVideo
// headers, using ffigen's Objective-C interop. No hand-written native code —
// compress/merge/mute/reverse are driven straight from Dart via these
// generated bindings (see lib/native_video_toolkit.dart).
//
// Shared with iOS: the AVFoundation/CoreMedia/CoreVideo/CoreFoundation
// surface bound here is identical between the macOS and iOS SDKs (verified
// by generating against both and diffing the output — same classes, same
// selectors, same globals; only an internal, per-run random symbol-name
// hash differs, which is irrelevant since the .g.dart and .g.m below are
// always generated as one matching pair). So there's no separate iOS ffigen
// config to maintain — this script generates once against the macOS SDK and
// copies the resulting Objective-C glue file into the iOS target too, so
// both platforms' native glue can never drift out of sync with each other
// or with the one shared Dart bindings file.
//
// Run after Xcode command line tools are installed:
//   dart run tool/generate_bindings.dart
import 'dart:io';

import 'package:ffigen/ffigen.dart';

final _av =
    '$macSdkPath/System/Library/Frameworks/AVFoundation.framework/Headers';
final _cm = '$macSdkPath/System/Library/Frameworks/CoreMedia.framework/Headers';
final _cv = '$macSdkPath/System/Library/Frameworks/CoreVideo.framework/Headers';
final _cf =
    '$macSdkPath/System/Library/Frameworks/CoreFoundation.framework/Headers';

final config = FfiGenerator(
  headers: Headers(
    entryPoints: [
      Uri.file('$_av/AVAsset.h'),

      Uri.file('$_av/AVAssetTrack.h'),
      Uri.file('$_av/AVAssetExportSession.h'),
      Uri.file('$_av/AVComposition.h'),
      Uri.file('$_av/AVCompositionTrack.h'),
      Uri.file('$_av/AVAssetReader.h'),
      Uri.file('$_av/AVAssetReaderOutput.h'),
      Uri.file('$_av/AVAssetWriter.h'),
      Uri.file('$_av/AVAssetWriterInput.h'),
      Uri.file('$_av/AVMediaFormat.h'),
      Uri.file('$_av/AVVideoSettings.h'),
      Uri.file('$_cm/CMTime.h'),
      Uri.file('$_cm/CMTimeRange.h'),
      Uri.file('$_cm/CMSampleBuffer.h'),
      Uri.file('$_cv/CVPixelBuffer.h'),
      Uri.file('$_cf/CFBase.h'),
    ],
  ),

  // C-level structs/functions/globals used to build time ranges and to walk
  // decoded video frames for the reverse operation.
  structs: Structs.includeSet({
    'CMTime',
    'CMTimeRange',
    'CGSize',
    'CGAffineTransform',
  }),
  // AVAssetExportSessionStatus/AVAssetReaderStatus/AVAssetWriterStatus are
  // read via `.status` on the three session/reader/writer classes below.
  // ffigen warns that NS_ENUM's underlying integer size is
  // implementation-defined — true in general, but settled for a fixed
  // macOS/arm64+x86_64 target, so silence it rather than dropping the
  // enums (dropping them broke codegen for every interface that exposes a
  // `status` property, since the enum type couldn't be resolved).
  enums: Enums(include: Declarations.includeAll, silenceWarning: true),
  functions: Functions.includeSet({
    'CMTimeMake',
    'CMTimeAdd',
    'CMTimeRangeMake',
    'CMSampleBufferGetImageBuffer',
    'CMSampleBufferGetDuration',
    'CVPixelBufferRetain',
    'CVPixelBufferRelease',
    // Releases the CF_RETURNS_RETAINED CMSampleBufferRef handed back by
    // AVAssetReaderOutput.copyNextSampleBuffer once its image buffer has
    // been retained separately.
    'CFRelease',
  }),
  globals: Globals.includeSet({
    'kCMTimeZero',
    'AVMediaTypeVideo',
    'AVMediaTypeAudio',
    // One per extension in format_compat.dart's avFoundationNativeExtensions
    // — lets exports match the original input's container instead of
    // always producing mp4.
    'AVFileTypeMPEG4',
    'AVFileTypeQuickTimeMovie',
    'AVFileTypeAppleM4V',
    'AVFileType3GPP',
    'AVFileType3GPP2',
    'AVAssetExportPresetHighestQuality',
    'AVAssetExportPreset1920x1080',
    'AVAssetExportPreset1280x720',
    'AVAssetExportPresetLowQuality',
    'AVAssetExportPresetPassthrough',
    'AVVideoCodecKey',
    'AVVideoCodecTypeH264',
    'AVVideoWidthKey',
    'AVVideoHeightKey',
    'kCVPixelBufferPixelFormatTypeKey',
  }),

  objectiveC: ObjectiveC(
    interfaces: Interfaces(
      include: Declarations.includeSet({
        'AVAsset',
        'AVURLAsset',
        'AVAssetTrack',
        'AVAssetExportSession',
        'AVComposition',
        'AVMutableComposition',
        'AVCompositionTrack',
        'AVMutableCompositionTrack',
        'AVAssetReader',
        'AVAssetReaderOutput',
        'AVAssetReaderTrackOutput',
        'AVAssetWriter',
        'AVAssetWriterInput',
        'AVAssetWriterInputPixelBufferAdaptor',
      }),
      // Fully code-gen superclass members (AVAsset/AVAssetTrack members
      // called on AVURLAsset instances, AVComposition/AVCompositionTrack
      // members called on the Mutable subclasses) instead of stubbing them.
      includeTransitive: true,
      // Keep the generated surface intentional: only the selectors this
      // package actually calls.
      includeMember: Declarations.includeMemberSet({
        'AVAsset': {'tracksWithMediaType:', 'duration'},
        'AVURLAsset': {'URLAssetWithURL:options:'},
        'AVAssetTrack': {
          'naturalSize',
          'preferredTransform',
          'nominalFrameRate',
          'mediaType',
        },
        'AVAssetExportSession': {
          // 'alloc' is a per-class NSObject factory ffigen generates fresh
          // for each bound interface — it must be listed explicitly here
          // just like any other member, or `ClassName.alloc()` won't exist.
          'alloc',
          'initWithAsset:presetName:',
          'outputURL',
          'setOutputURL:',
          'outputFileType',
          'setOutputFileType:',
          'shouldOptimizeForNetworkUse',
          'setShouldOptimizeForNetworkUse:',
          'status',
          'error',
          'progress',
          'exportAsynchronouslyWithCompletionHandler:',
          'cancelExport',
        },
        'AVMutableComposition': {
          'composition',
          'addMutableTrackWithMediaType:preferredTrackID:',
        },
        'AVMutableCompositionTrack': {
          'insertTimeRange:ofTrack:atTime:error:',
          'preferredTransform',
          'setPreferredTransform:',
        },
        'AVAssetReader': {
          'alloc',
          'initWithAsset:error:',
          'canAddOutput:',
          'addOutput:',
          'startReading',
          'status',
          'error',
        },
        'AVAssetReaderOutput': {'copyNextSampleBuffer'},
        'AVAssetReaderTrackOutput': {'alloc', 'initWithTrack:outputSettings:'},
        'AVAssetWriter': {
          'alloc',
          'initWithURL:fileType:error:',
          'canAddInput:',
          'addInput:',
          'startWriting',
          'startSessionAtSourceTime:',
          'finishWritingWithCompletionHandler:',
          'status',
          'error',
        },
        'AVAssetWriterInput': {
          'assetWriterInputWithMediaType:outputSettings:',
          'expectsMediaDataInRealTime',
          'setExpectsMediaDataInRealTime:',
          'transform',
          'setTransform:',
          // Declared as `@property(getter=isReadyForMoreMediaData)` — the
          // member filter matches the selector, not the property name.
          'isReadyForMoreMediaData',
          'markAsFinished',
        },
        'AVAssetWriterInputPixelBufferAdaptor': {
          'assetWriterInputPixelBufferAdaptorWithAssetWriterInput:sourcePixelBufferAttributes:',
          'appendPixelBuffer:withPresentationTime:',
        },
      }),
    ),
  ),

  output: Output(
    dartFile: Platform.script.resolve(
      '../lib/src/native_video_toolkit_bindings.g.dart',
    ),
    // Written into the plugin's macOS Swift Package source directory so it
    // gets compiled and linked into the app automatically — no manual Xcode
    // project edits required.
    // Swift Package Manager doesn't support mixing Swift and Objective-C
    // sources in one target, so the native glue lives in its own target
    // (see macos/native_video_toolkit/Package.swift).
    objectiveCFile: Platform.script.resolve(
      '../macos/native_video_toolkit/Sources/native_video_toolkit_native/native_video_toolkit_bindings.g.m',
    ),
    preamble: '''
// AUTO GENERATED FILE, DO NOT EDIT.
// Regenerate with: dart run tool/generate_bindings.dart
''',
  ),
);

void main() {
  config.generate();

  // See the file-level doc comment: iOS reuses the exact same generated
  // glue rather than a second ffigen config, so keep its copy identical to
  // the macOS one this just (re)generated.
  final macosGlue = File.fromUri(
    Platform.script.resolve(
      '../macos/native_video_toolkit/Sources/native_video_toolkit_native/native_video_toolkit_bindings.g.m',
    ),
  );
  final iosGlue = File.fromUri(
    Platform.script.resolve(
      '../ios/native_video_toolkit/Sources/native_video_toolkit_native/native_video_toolkit_bindings.g.m',
    ),
  );
  iosGlue.parent.createSync(recursive: true);
  macosGlue.copySync(iosGlue.path);
}
