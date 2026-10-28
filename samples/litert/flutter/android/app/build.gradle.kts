// Copyright 2026 The Google AI Edge Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Stable keys stay outside the repository (docs/living-memory/v1.3.1/SIGNING.md).
// A release without key.properties is refused unless experimental debug signing
// is explicitly opted into. That certificate cannot promise an existing upgrade.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null
val allowExperimentalSigning = providers.environmentVariable("LM_ALLOW_EXPERIMENTAL_DEBUG_SIGNING").orNull == "true"

android {
    namespace = "com.google.ai.edge.examples.litert_edge_demos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (via flutter_edge_ai_agent) needs java.time desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.google.ai.edge.examples.litert_edge_demos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // .litertlm (LLM, embeddings, speech) fails to load at runtime below API 30.
        minSdk = 30
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // LiteRT-LM ships arm64-v8a only. Replace, don't append: the Flutter Gradle plugin
        // has already filled abiFilters with every Flutter ABI (FlutterPlugin.configureAbiWithoutSplits).
        ndk {
            abiFilters.clear()
            abiFilters += "arm64-v8a"
        }
    }

    // The built-in models stay uncompressed in the APK: the detector is read
    // as one buffer, the others (the 485 MB EmbeddingGemma 2 .litertlm among
    // them) streamed out once. Deflating them saves little and costs a full
    // inflate on every read.
    androidResources {
        noCompress += listOf("tflite", "litertlm")
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // PDFBox explicitly treats JP2 as optional. Text extraction needs
            // no JPEG-2000 codec; silence only that absent optional class.
            proguardFiles("proguard-rules.pro")
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// One warning per release build signed with the debug key (at execution, so configuring or
// building debug stays quiet). preReleaseBuild runs first in every release variant's task graph.
tasks.configureEach {
    if (name == "preReleaseBuild" && !hasReleaseKey) {
        doFirst {
            check(allowExperimentalSigning) {
                "Stable signing required: configure external android/key.properties, or explicitly opt in to LM_ALLOW_EXPERIMENTAL_DEBUG_SIGNING=true for an experimental APK."
            }
            logger.warn(
                "android/key.properties not found: signing the release build with the DEBUG key",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Apache-2.0, text extraction on device, no cloud/OCR.
    implementation("com.tom-roush:pdfbox-android:2.0.27.0")
    // PDFBox's POM asks for 1.72. Use the maintained hardening release
    // (upstream 1.86, Maven coordinates verified), consistently for all three.
    constraints {
        // GHSA-xxph-c9ww-hj94: preserve Android variant, patch unsafe deserialization.
        implementation("com.google.guava:guava:33.7.2-android")
        // GHSA-3cqm-mf7h-prrj: hostname verification fix, minimal compatible update.
        implementation("com.squareup.okhttp3:okhttp:4.9.2")
        implementation("org.bouncycastle:bcprov-jdk15to18:1.86")
        implementation("org.bouncycastle:bcpkix-jdk15to18:1.86")
        implementation("org.bouncycastle:bcutil-jdk15to18:1.86")
    }
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
