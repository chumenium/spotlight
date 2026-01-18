import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// キーストア設定の読み込み
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.spotlight.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // 署名設定
    signingConfigs {
        create("release") {
            val storeFileStr = keystoreProperties["storeFile"] as String?
            if (storeFileStr != null) {
                val keystoreFile = file(storeFileStr)
                if (keystoreFile.exists()) {
                    keyAlias = keystoreProperties["keyAlias"] as String?
                    keyPassword = keystoreProperties["keyPassword"] as String?
                    storeFile = keystoreFile
                    storePassword = keystoreProperties["storePassword"] as String?
                } else {
                    throw GradleException(
                        "リリース用キーストアファイルが見つかりません: ${keystoreFile.absolutePath}\n" +
                        "android/app/spotlight-release-key.jksファイルが存在することを確認してください。"
                    )
                }
            } else {
                throw GradleException(
                    "key.propertiesにstoreFileが設定されていません。\n" +
                    "android/key.propertiesファイルにstoreFile=spotlight-release-key.jksを設定してください。"
                )
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.spotlight.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // リリース用署名設定を使用（key.propertiesが必須）
            if (keystorePropertiesFile.exists() && keystoreProperties["storeFile"] != null) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                throw GradleException(
                    "リリースビルドにはkey.propertiesファイルが必要です。\n" +
                    "android/key.propertiesファイルを作成し、リリース用キーストアの情報を設定してください。\n" +
                    "詳細はRELEASE_KEYSTORE_SETUP.mdを参照してください。"
                )
            }
        }
        debug {
            // デバッグビルドでもリリース用署名を使用（統一されたフィンガープリントのため）
            // すべての端末で同じフィンガープリントを使用するため、リリース用キーストアを使用
            if (keystorePropertiesFile.exists() && keystoreProperties["storeFile"] != null) {
                // リリース用キーストアを使用（統一されたフィンガープリントのため）
                signingConfig = signingConfigs.getByName("release")
            } else {
                // key.propertiesが存在しない場合、デフォルトのデバッグキーストアを使用
                // リリース段階ではkey.propertiesの設定を推奨
                println("警告: key.propertiesが存在しないため、デフォルトのデバッグキーストアを使用します。")
                println("リリース段階では、統一されたフィンガープリントのためkey.propertiesを設定してください。")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
  // Import the Firebase BoM
  implementation(platform("com.google.firebase:firebase-bom:34.6.0"))


  // TODO: Add the dependencies for Firebase products you want to use
  // When using the BoM, don't specify versions in Firebase dependencies
  implementation("com.google.firebase:firebase-analytics")


  // Add the dependencies for any other desired Firebase products
  // https://firebase.google.com/docs/android/setup#available-libraries
}