pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    // Declared but never applied, and it has to stay that way. Nothing
    // applies KGP since android.builtInKotlin=true - but this line is
    // also what pins the project's Kotlin version, and the Flutter Gradle
    // plugin validates that. Removed, the build falls back to the Kotlin
    // AGP 9.0.1 brings (2.2.10) and fails: below Flutter's minimum of
    // 2.2.20.
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
