group = "dev.alihassan.native_video_toolkit"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "dev.alihassan.native_video_toolkit"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        // MediaCodec.getInputImage()/getOutputImage() — used by reverseVideo
        // for stride-correct pixel plane access (see native_video_toolkit_android.dart) —
        // require API 23. MediaExtractor/MediaMuxer/MediaCodec's own buffer-mode
        // APIs go back further, and media3-transformer's own floor is lower
        // than this too, so 23 is the real constraint.
        minSdk = 23
        consumerProguardFiles("consumer-rules.pro")
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

dependencies {
    // Bound via jnigen (see tool/generate_android_bindings.dart) for the
    // real re-encode fallback path in merge/mute — used only when
    // MediaExtractor+MediaMuxer can't just stream-copy the source tracks
    // (mismatched codecs/formats across merge inputs), the same role
    // AVAssetExportPresetHighestQuality plays after
    // AVAssetExportPresetPassthrough fails on the AVFoundation side.
    // android.media.MediaExtractor/MediaMuxer/MediaCodec/MediaFormat need
    // no extra dependency here — they're part of the Android SDK itself
    // (android.jar), already on every app's compile classpath.
    api("androidx.media3:media3-transformer:1.11.0")
    api("androidx.media3:media3-common:1.11.0")
    api("androidx.media3:media3-effect:1.11.0")
    api("androidx.media3:media3-muxer:1.11.0")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
