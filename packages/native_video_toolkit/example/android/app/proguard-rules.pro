# App-level ProGuard/R8 rules — wired into the release buildType's
# `proguardFiles` below, but only takes effect once `isMinifyEnabled` is
# turned on for that buildType (it currently isn't; this repo's default
# `flutter build apk --release` template doesn't enable minification, and
# turning it on is a separate decision from adding this file).
#
# Every dependency this app actually needs keep rules for already ships
# its own consumerProguardFiles, merged in automatically by AGP:
# package:jni (com.github.dart_lang.jni.**) and native_video_toolkit's own
# JNI-reflected androidx.media3.* classes (see
# packages/native_video_toolkit/android/consumer-rules.pro). Nothing
# app-specific is needed here yet — add rules above this line if a future
# dependency doesn't ship its own.
