import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Clé d'envoi Play Store. Le keystore et ses mots de passe ne sont jamais
// versionnés : voir android/key.properties.exemple et le fichier .gitignore.
val uploadKeyPropertiesFile = rootProject.file("key.properties")
val uploadKeyProperties = Properties().apply {
    if (uploadKeyPropertiesFile.exists()) {
        FileInputStream(uploadKeyPropertiesFile).use { stream -> load(stream) }
    }
}
val hasUploadKey = uploadKeyPropertiesFile.exists()

android {
    namespace = "com.okata.echelleeg39"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.okata.echelleeg39"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile = rootProject.file(uploadKeyProperties.getProperty("storeFile"))
                storePassword = uploadKeyProperties.getProperty("storePassword")
                keyAlias = uploadKeyProperties.getProperty("keyAlias")
                keyPassword = uploadKeyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Sans cette configuration, le bundle partirait avec la clé de debug,
            // publique et refusée par Google Play.
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Un bundle release signé en debug est refusé par Play : on échoue tôt, mais
// uniquement sur les tâches release, pour ne pas bloquer les builds debug.
tasks.configureEach {
    val isReleasePackaging = name.startsWith("bundleRelease") ||
        name.startsWith("assembleRelease") ||
        name.startsWith("packageRelease")
    if (isReleasePackaging) {
        doFirst {
            if (!hasUploadKey) {
                throw GradleException(
                    "Clé d'envoi manquante : créez android/key.properties à partir de " +
                        "android/key.properties.exemple avant de construire un bundle release."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
