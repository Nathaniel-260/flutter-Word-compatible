# Consumer ProGuard/R8 rules for apps that depend on this plugin.
#
# android.media.* (MediaExtractor/MediaMuxer/MediaCodec/MediaFormat/Image)
# are Android SDK framework classes, not part of any app's own compiled
# bytecode — R8 never shrinks or renames platform framework classes, so
# nothing here needs a keep rule for them regardless of minification.
#
# androidx.media3.* is a real library dependency and therefore R8-eligible,
# so it *would* need protecting if this plugin's Dart-side JNI bindings did
# `JClass.forName`-style reflective lookups on it. They're generated (see
# tool/generate_android_bindings.dart) but not currently exercised by any
# hand-written code in this plugin (the media3 Transformer fallback for
# merge is generated-but-unwired, see native_video_toolkit_android.dart's
# class doc) — keep this rule anyway, ahead of that work landing, since a
# consumer's release build enabling minification later would otherwise
# silently strip the exact classes that follow-up needs.
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
