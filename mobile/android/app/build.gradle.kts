plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.File
import java.util.Properties

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

val defaultApplicationId = "com.mycampusmart.app"
val androidApplicationId = providers
    .gradleProperty("APP_ANDROID_APPLICATION_ID")
    .orElse(System.getenv("APP_ANDROID_APPLICATION_ID") ?: defaultApplicationId)
    .get()
val releaseSigningConfigured = keyPropertiesFile.exists()
    && !keyProperties.getProperty("storeFile").isNullOrBlank()
    && !keyProperties.getProperty("storePassword").isNullOrBlank()
    && !keyProperties.getProperty("keyAlias").isNullOrBlank()
    && !keyProperties.getProperty("keyPassword").isNullOrBlank()
val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    val normalized = taskName.lowercase()
    normalized.contains("release") || normalized.contains("bundle")
}

if (releaseTaskRequested && !releaseSigningConfigured) {
    throw GradleException(
        "Release builds require android/key.properties with a valid signing configuration."
    )
}

android {
    // Keep the Android namespace static so Flutter can discover the package
    // and launcher activity before Gradle evaluates runtime overrides.
    namespace = "com.mycampusmart.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = androidApplicationId
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keyProperties.getProperty("storeFile")
            if (!storeFilePath.isNullOrBlank()) {
                val resolvedStoreFile = if (File(storeFilePath).isAbsolute) {
                    file(storeFilePath)
                } else {
                    rootProject.file(storeFilePath)
                }
                storeFile = resolvedStoreFile
            }
            storePassword = keyProperties.getProperty("storePassword")
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        debug {
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }

        release {
            manifestPlaceholders["usesCleartextTraffic"] = "false"
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
