import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave de envio para a Google Play: android/key.properties aponta para o ficheiro da chave, fora do
// repositório (nem um nem outro vão para o git). Sem ele, a versão final é assinada com a chave de testes.
val ficheiroDaChave = rootProject.file("key.properties")
val propriedadesDaChave = Properties()
if (ficheiroDaChave.exists()) {
    FileInputStream(ficheiroDaChave).use { propriedadesDaChave.load(it) }
}

android {
    namespace = "io.github.kussumba.kussumba"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identificador da KUSSUMBA nas lojas; não pode mudar depois da primeira publicação.
        applicationId = "io.github.kussumba.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (ficheiroDaChave.exists()) {
            create("release") {
                keyAlias = propriedadesDaChave["keyAlias"] as String
                keyPassword = propriedadesDaChave["keyPassword"] as String
                storeFile = file(propriedadesDaChave["storeFile"] as String)
                storePassword = propriedadesDaChave["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (ficheiroDaChave.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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
