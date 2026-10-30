plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "com.tivini.livingworld"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "com.tivini.livingworld"
        minSdk = 30
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        ndk { abiFilters.clear(); abiFilters.add(providers.gradleProperty("godotTestAbi").getOrElse("arm64-v8a")) }
    }
    sourceSets["androidTest"].java.srcDir("../../../../packages/living_world_godot/android/src/androidTest/kotlin")
}
flutter { source = "../.." }
dependencies {
    // Flutter integration_test brings runner 1.3.0 to debugRuntimeClasspath.
    // Align both sides of AGP's consistent test dependency resolution.
    debugImplementation("androidx.test:runner:1.6.2")
    debugImplementation("androidx.test:core:1.6.1")
    debugImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:core:1.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
