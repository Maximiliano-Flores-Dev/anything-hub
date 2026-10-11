import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Lee la configuración de firma (la crea el workflow de GitHub Actions)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // Alineado con applicationId — sin com.example (bandera de plantilla)
    namespace = "com.anything.hub"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.anything.hub"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Ofuscación + tree-shaking de recursos (Code Hardening)
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            // Fail-closed en builds locales: sin keystore → error.
            // En CI (GITHUB_ACTIONS/CI) se permite debug solo para compilar PRs;
            // el workflow de release siempre inyecta key.properties antes de firmar.
            val hasKeystore = keystorePropertiesFile.exists() &&
                !(keystoreProperties["keyAlias"] as String?).isNullOrBlank() &&
                !(keystoreProperties["storeFile"] as String?).isNullOrBlank()
            val isCi = System.getenv("CI") == "true" ||
                System.getenv("GITHUB_ACTIONS") == "true"

            if (hasKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else if (isCi) {
                logger.warn(
                    "WARNING: release sin key.properties en CI — firmando con debug. " +
                        "No publicar este APK."
                )
                signingConfig = signingConfigs.getByName("debug")
            } else {
                throw GradleException(
                    "Release build requiere android/key.properties (keystore). " +
                        "No se permite fallback a debug en builds locales. " +
                        "Crea key.properties o compila con --debug."
                )
            }
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
