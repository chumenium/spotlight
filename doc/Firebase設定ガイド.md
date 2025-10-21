# Firebase設定ガイド

このガイドでは、SpotLightアプリにFirebaseを統合する手順を説明します。

## 目次
1. [Firebaseプロジェクトの作成](#1-firebaseプロジェクトの作成)
2. [Androidアプリの設定](#2-androidアプリの設定)
3. [iOSアプリの設定](#3-iosアプリの設定)
4. [Firebase Authenticationの有効化](#4-firebase-authenticationの有効化)
5. [パッケージのインストール](#5-パッケージのインストール)
6. [動作確認](#6-動作確認)

---

## 1. Firebaseプロジェクトの作成

1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. 「プロジェクトを追加」をクリック
3. プロジェクト名を入力（例：`SpotLight`）
4. Google Analyticsの設定（任意）
5. 「プロジェクトを作成」をクリック

---

## 2. Androidアプリの設定

### 2.1 パッケージ名の確認

`android/app/build.gradle.kts`ファイルを開き、`applicationId`を確認します：

```kotlin
defaultConfig {
    applicationId = "com.example.spotlight" // このパッケージ名をコピー
    ...
}
```

### 2.2 Firebase ConsoleでAndroidアプリを追加

1. Firebase Consoleのプロジェクトページで「Android」アイコンをクリック
2. パッケージ名を入力（例：`com.example.spotlight`）
3. アプリのニックネームを入力（任意、例：`SpotLight Android`）
4. デバッグ署名証明書（SHA-1）を入力（任意、後で追加可能）
5. 「アプリを登録」をクリック

### 2.3 google-services.jsonのダウンロードと配置

1. `google-services.json`ファイルをダウンロード
2. ファイルを`android/app/`ディレクトリに配置

```
android/
  └── app/
      └── google-services.json  ← ここに配置
```

### 2.4 Gradleファイルの設定

#### `android/build.gradle.kts`

```kotlin
buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:7.3.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.7.10")
        // Google Servicesプラグインを追加
        classpath("com.google.gms:google-services:4.4.0")
    }
}
```

#### `android/app/build.gradle.kts`

ファイルの最後に以下を追加：

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Google Servicesプラグインを追加
    id("com.google.gms.google-services")
}
```

---

## 3. iOSアプリの設定

### 3.1 Bundle IDの確認

`ios/Runner.xcodeproj/project.pbxproj`または`ios/Runner/Info.plist`でBundle IDを確認します。

もしくは、Xcodeで以下の手順で確認：
1. `ios/Runner.xcworkspace`をXcodeで開く
2. Runnerプロジェクトを選択
3. 「General」タブの「Bundle Identifier」を確認（例：`com.example.spotlight`）

### 3.2 Firebase ConsoleでiOSアプリを追加

1. Firebase Consoleのプロジェクトページで「iOS」アイコンをクリック
2. Bundle IDを入力（例：`com.example.spotlight`）
3. アプリのニックネームを入力（任意、例：`SpotLight iOS`）
4. App Store ID（任意、後で追加可能）
5. 「アプリを登録」をクリック

### 3.3 GoogleService-Info.plistのダウンロードと配置

1. `GoogleService-Info.plist`ファイルをダウンロード
2. Xcodeで`ios/Runner.xcworkspace`を開く
3. Runnerフォルダを右クリック → 「Add Files to "Runner"」
4. ダウンロードした`GoogleService-Info.plist`を選択
5. 「Copy items if needed」にチェックを入れて「Add」をクリック

```
ios/
  └── Runner/
      └── GoogleService-Info.plist  ← ここに配置
```

---

## 4. Firebase Authenticationの有効化

### 4.1 メール/パスワード認証を有効化

1. Firebase Consoleの左メニューから「Authentication」を選択
2. 「始める」をクリック
3. 「Sign-in method」タブを選択
4. 「メール/パスワード」をクリック
5. 「有効にする」をオンにして「保存」をクリック

### 4.2 Google認証を有効化

1. 同じ「Sign-in method」タブで「Google」をクリック
2. 「有効にする」をオンにする
3. プロジェクトのサポートメールを選択
4. 「保存」をクリック

#### Google Sign-In for Android

**重要**: AndroidでGoogle Sign-Inを使用する場合、SHA-1フィンガープリントが必要です。

##### デバッグ用SHA-1の取得（Windows）

```powershell
cd android
./gradlew signingReport
```

もしくは：

```powershell
keytool -list -v -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore
```

デフォルトパスワード: `android`

##### SHA-1をFirebaseに追加

1. Firebase Console → プロジェクト設定 → Androidアプリ
2. 「SHA証明書フィンガープリント」に追加
3. 「保存」をクリック

#### Google Sign-In for iOS

1. `ios/Runner/Info.plist`を開く
2. 以下を追加（Xcodeまたはテキストエディタで編集）：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- GoogleService-Info.plistのREVERSED_CLIENT_IDの値をここに貼り付け -->
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>
```

`GoogleService-Info.plist`から`REVERSED_CLIENT_ID`をコピーして貼り付けます。

---

## 5. パッケージのインストール

プロジェクトのルートディレクトリで以下のコマンドを実行：

```bash
flutter pub get
```

これにより、以下のパッケージがインストールされます：
- `firebase_core: ^2.24.2`
- `firebase_auth: ^4.16.0`
- `google_sign_in: ^6.2.1`

---

## 6. 動作確認

### 6.1 アプリの起動

```bash
flutter run
```

### 6.2 テストアカウントの作成

1. アプリの「新規登録」画面を開く
2. メールアドレス、ユーザー名、パスワードを入力
3. 「アカウント作成」をタップ

### 6.3 Firebase Consoleで確認

1. Firebase Console → Authentication → Users
2. 作成したユーザーが表示されることを確認

### 6.4 Google Sign-Inのテスト

1. アプリの「Googleでログイン」ボタンをタップ
2. Googleアカウントを選択
3. ログインが成功することを確認

---

## トラブルシューティング

### Androidでビルドエラーが発生する

**エラー**: `google-services.json`が見つからない

**解決策**: 
- `android/app/`ディレクトリに`google-services.json`が配置されているか確認
- ファイルのパーミッションを確認

**エラー**: Google Servicesプラグインのバージョン不一致

**解決策**:
```bash
cd android
./gradlew clean
./gradlew build
```

### iOSでビルドエラーが発生する

**エラー**: `GoogleService-Info.plist`が見つからない

**解決策**:
- Xcodeで`ios/Runner.xcworkspace`を開く
- Runnerフォルダ内に`GoogleService-Info.plist`があるか確認
- ない場合は、「Add Files to "Runner"」で追加

**エラー**: Pod installエラー

**解決策**:
```bash
cd ios
pod deintegrate
pod install
```

### Google Sign-Inが動作しない

**Android**:
- SHA-1フィンガープリントがFirebase Consoleに登録されているか確認
- `google-services.json`を再ダウンロードして配置

**iOS**:
- `Info.plist`に`REVERSED_CLIENT_ID`が正しく設定されているか確認
- `GoogleService-Info.plist`が正しく配置されているか確認

### Firebase初期化エラー

**エラー**: `[core/no-app] No Firebase App has been created`

**解決策**:
- `main.dart`で`Firebase.initializeApp()`が呼ばれているか確認
- `WidgetsFlutterBinding.ensureInitialized()`が先に呼ばれているか確認

---

## セキュリティ設定（推奨）

### Firestore Security Rules

Firebase Consoleで以下のセキュリティルールを設定することをお勧めします：

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ユーザー認証済みの場合のみアクセス許可
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 本番環境へのデプロイ前のチェックリスト

- [ ] `AppConfig.isDevelopment`を`false`に変更
- [ ] 本番用のSHA-1フィンガープリントをFirebaseに追加（Android）
- [ ] App Store IDをFirebaseに追加（iOS）
- [ ] Firestore Security Rulesを本番用に更新
- [ ] Firebase Authenticationの制限設定を確認

---

## 参考資料

- [FlutterFire公式ドキュメント](https://firebase.flutter.dev/)
- [Firebase Authentication公式ドキュメント](https://firebase.google.com/docs/auth)
- [Google Sign-In for Flutter](https://pub.dev/packages/google_sign_in)

---

## サポート

問題が解決しない場合は、以下を確認してください：
1. Flutter、Dart、Firebase SDKのバージョンが最新か
2. エラーログの内容
3. 設定ファイルが正しく配置されているか

詳細なエラーメッセージがある場合は、開発チームにご連絡ください。

