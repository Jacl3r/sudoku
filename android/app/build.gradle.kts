import com.android.build.api.variant.FilterConfiguration.FilterType
import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile: File = rootProject.file("key.properties")
if (keystorePropertiesFile.exists() ?: false) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.likhithpraveenk.sudoku"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    defaultConfig {
        applicationId = "com.likhithpraveenk.sudoku"
        minSdk = 24
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storePassword = keystoreProperties["storePassword"] as String?
            val keystorePath = keystoreProperties["storeFile"] as String?
            storeFile = keystorePath?.let { file(it) }
        }
    }

    buildTypes {
        release {
            optimization {
                enable = true
            }
            signingConfig = when {
                keystorePropertiesFile.exists() -> signingConfigs.getByName("release")
                else -> {
                    println("WARNING: No signing credentials found. Building unsigned apk")
                    null
                }
            }
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
    val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
    applicationVariants.configureEach {
        val variant = this
        variant.outputs.forEach { output ->
            val abiVersionCode =
                abiCodes[output.filters.find { it.filterType == FilterType.ABI.name }?.identifier]
            if (abiVersionCode != null) {
                (output as ApkVariantOutputImpl).versionCodeOverride =
                    variant.versionCode * 10 + abiVersionCode
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
    }
}

flutter {
    source = "../.."
}
