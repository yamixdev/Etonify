import java.util.Properties
import org.gradle.api.GradleException
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("androidx.baselineprofile")
    // The Flutter Gradle Plugin must be applied after the Android Gradle Plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}
val allowDebugReleaseSigning =
    System.getenv("MEOW_ALLOW_DEBUG_RELEASE_SIGNING")?.equals("true", ignoreCase = true) == true

android {
    namespace = "com.etonify.meow_client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.etonify.meow_client"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += setOf("armeabi-v7a", "arm64-v8a")
        }
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                val storeFilePath = keyProperties.getProperty("storeFile")
                check(!storeFilePath.isNullOrBlank()) {
                    "storeFile is missing in android/key.properties"
                }
                storeFile = rootProject.file(storeFilePath)
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (keyPropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else if (allowDebugReleaseSigning) {
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            // Keep the old Happ native library on disk, but do not package it.
            excludes += setOf("**/liberror-code.so")
        }
    }

    lint {
        // Flutter regenerates android/local.properties with valid Windows paths
        // before Gradle runs, while Android lint incorrectly flags that file.
        disable += "PropertyEscape"
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

gradle.taskGraph.whenReady {
    val releaseTaskRequested = allTasks.any { task ->
        task.project == project && task.name.contains("release", ignoreCase = true)
    }
    if (releaseTaskRequested && !keyPropertiesFile.exists() && !allowDebugReleaseSigning) {
        throw GradleException(
            "Release signing requires android/key.properties. " +
                "Set MEOW_ALLOW_DEBUG_RELEASE_SIGNING=true only for local release testing.",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(files("libs/libbox.aar"))
    implementation("androidx.profileinstaller:profileinstaller:1.4.1")
    baselineProfile(project(":benchmark"))
    testImplementation("junit:junit:4.13.2")
}

tasks.withType<JavaCompile>().configureEach {
    // Legacy Happ native crypt5 bridge is kept in-tree for reference,
    // but crypt5/5.1 now uses the pure Dart implementation.
    exclude(
        "com/etonify/meow_client/happcrypto/**",
        "com/happproxy/util/protection/**",
        "su/happ/proxyutility/**",
    )
}
