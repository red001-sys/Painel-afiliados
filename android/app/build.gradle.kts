import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ============================================================
// CONFIGURAÇÃO DE ASSINATURA
//
// Fontes da chave, em ordem de precedência:
//   1. android/key.properties          (build local)   → storeFile/storePassword/keyAlias/keyPassword
//   2. ANDROID_KEYSTORE_BASE64 + senhas (CI/GitHub)    → keystore decodificada do secret
//   3. ANDROID_KEYSTORE_FILE + senhas  (CI/GitHub)     → caminho para o arquivo .jks
//
// Se nada for encontrado, o release usa a assinatura DEBUG
// (permite `flutter build apk --release` local sem chave).
//
// Obs.: nomes locais distintos de `storeFile`/`storePassword`/etc. porque,
// dentro do closure `signingConfigs { create("release") }`, o receiver é o
// SigningConfig e um identificador igual apontaria pra propriedade dele (null).
// ============================================================

// 1. Tenta ler key.properties (build local)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

// 2. Resolve a senha/alias (key.properties > env vars)
val keystoreStorePassword = keystoreProperties.getProperty("storePassword")
    ?: System.getenv("ANDROID_KEYSTORE_PASSWORD")
val keystoreKeyAlias = keystoreProperties.getProperty("keyAlias")
    ?: System.getenv("ANDROID_KEY_ALIAS")
val keystoreKeyPassword = keystoreProperties.getProperty("keyPassword")
    ?: System.getenv("ANDROID_KEY_PASSWORD")

// 3. Resolve o arquivo da keystore
//    a) base64 (secret do GitHub) → decodifica para build/keystores/
//    b) key.properties storeFile
//    c) ANDROID_KEYSTORE_FILE (caminho no runner)
var keystoreFilePath: String? = null
val keystoreBase64 = System.getenv("ANDROID_KEYSTORE_BASE64")
if (!keystoreBase64.isNullOrBlank()) {
    try {
        val keystoreDir = File(project.buildDir, "keystores").apply { mkdirs() }
        val decodedFile = File(keystoreDir, "upload-keystore.jks")
        decodedFile.writeBytes(Base64.getDecoder().decode(keystoreBase64))
        decodedFile.setReadable(true, false)
        keystoreFilePath = decodedFile.absolutePath
        logger.lifecycle("Keystore: decodificada do ANDROID_KEYSTORE_BASE64 -> ${decodedFile.absolutePath}")
    } catch (e: Exception) {
        logger.warn("Keystore: falha ao decodificar ANDROID_KEYSTORE_BASE64 -> ${e.message}")
    }
}
if (keystoreFilePath == null) {
    keystoreFilePath = keystoreProperties.getProperty("storeFile")
        ?: System.getenv("ANDROID_KEYSTORE_FILE")
}

val hasReleaseKey = keystoreFilePath != null &&
    keystoreStorePassword != null &&
    keystoreKeyAlias != null &&
    keystoreKeyPassword != null

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

            // Ofusca nomes de classe/método e remove código morto (R8) +
            // remove recursos não usados. Isso é sobre a camada
            // Java/Kotlin do app (plugins nativos); o código Dart em si é
            // ofuscado separadamente via `flutter build ... --obfuscate`.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
