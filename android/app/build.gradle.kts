import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave de assinatura: lê de android/key.properties (build local) ou de
// variáveis de ambiente (CI). Fora do repositório — ver .gitignore.
// Obs.: nomes locais distintos de `storeFile`/`storePassword`/etc. porque,
// dentro do closure `signingConfigs { create("release") }`, o receiver é o
// SigningConfig e um identificador igual apontaria pra propriedade dele (null).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}
val keystoreFilePath = keystoreProperties.getProperty("storeFile") ?: System.getenv("ANDROID_KEYSTORE_FILE")
val keystoreStorePassword = keystoreProperties.getProperty("storePassword") ?: System.getenv("ANDROID_KEYSTORE_PASSWORD")
val keystoreKeyAlias = keystoreProperties.getProperty("keyAlias") ?: System.getenv("ANDROID_KEY_ALIAS")
val keystoreKeyPassword = keystoreProperties.getProperty("keyPassword") ?: System.getenv("ANDROID_KEY_PASSWORD")
val hasReleaseKey = keystoreFilePath != null

android {
    namespace = "com.redstar.painel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.redstar.painel"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                storeFile = file(keystoreFilePath!!)
                storePassword = keystoreStorePassword
                keyAlias = keystoreKeyAlias
                keyPassword = keystoreKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Assina com a chave de upload quando disponível; senão usa debug
            // (pra permitir `flutter run --release` local sem a chave).
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}