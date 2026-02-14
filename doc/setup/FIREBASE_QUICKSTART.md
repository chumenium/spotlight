# Firebase認証 クイックスタート

## 🚀 即座に開始するための手順

### ステップ1: Firebase CLIのインストール（推奨）

```bash
# Firebase CLIをインストール
npm install -g firebase-tools

# Firebaseにログイン
firebase login

# FlutterFireプロジェクトを設定
flutterfire configure
```

`flutterfire configure`を実行すると、自動的に以下が行われます：
- Firebaseプロジェクトの選択または作成
- Android/iOS用の設定ファイルの生成と配置
- 必要な設定の自動適用

### ステップ2: 手動設定（Firebase CLIを使わない場合）

#### 2.1 Firebaseプロジェクトの作成

1. https://console.firebase.google.com/ にアクセス
2. 「プロジェクトを追加」→ プロジェクト名: `SpotLight`

#### 2.2 Androidアプリの追加

1. Firebase Console → プロジェクトの概要 → 「Android」アイコンをクリック
2. パッケージ名を確認（`android/app/build.gradle.kts`の`applicationId`）
3. `google-services.json`をダウンロード → `android/app/`に配置

**`android/build.gradle.kts`に追加：**
```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")  // 追加
    }
}
```

**`android/app/build.gradle.kts`の最後に追加：**
```kotlin
apply(plugin = "com.google.gms.google-services")  // 追加
```

#### 2.3 iOSアプリの追加

1. Firebase Console → プロジェクトの概要 → 「iOS」アイコンをクリック
2. Bundle IDを確認（Xcodeで`ios/Runner.xcworkspace`を開いて確認）
3. `GoogleService-Info.plist`をダウンロード
4. Xcodeで`ios/Runner.xcworkspace`を開く → Runnerフォルダを右クリック → 「Add Files to "Runner"」→ `GoogleService-Info.plist`を追加

### ステップ3: Firebase Authenticationを有効化

1. Firebase Console → Authentication → 「始める」
2. Sign-in methodタブ → 「Google」を有効化
3. Sign-in methodタブ → 「Apple」を有効化
4. Sign-in methodタブ → 「Twitter」を有効化
   - Twitter Developer Portalで取得したAPI KeyとAPI Secret Keyを入力

#### Google Sign-In追加設定（Android）

SHA-1フィンガープリントの取得と登録：

```bash
cd android
./gradlew signingReport
```

出力された`SHA1`をコピー → Firebase Console → プロジェクト設定 → Androidアプリ → 「SHA証明書フィンガープリント」に追加

#### Google Sign-In追加設定（iOS）

`ios/Runner/Info.plist`に以下を追加：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- GoogleService-Info.plistからREVERSED_CLIENT_IDをコピー -->
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

### ステップ4: アプリを実行

```bash
flutter run
```

---

## ✅ 実装済みの機能

### 認証機能（ソーシャルログインのみ）
- ✅ Googleログイン（Android、iOS、Web対応）
- ✅ Apple Sign-In（iOS専用）
- ✅ Twitterログイン（Android、iOS対応）
- ✅ ログアウト
- ✅ 自動ログイン（セッション維持）

⚠️ **注意**: メール/パスワード認証は削除されました。ソーシャルログインのみを使用します。

### エラーハンドリング
- ✅ Firebase Auth例外の日本語メッセージ変換
- ✅ ユーザーフレンドリーなエラー表示

### UI
- ✅ モダンなログイン画面
- ✅ 新規登録画面
- ✅ ローディング状態の表示
- ✅ 開発モード用のスキップ機能

---

## 📝 コード例

### Googleログイン

```dart
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final success = await authProvider.loginWithGoogle();

if (success) {
  // ログイン成功
  Navigator.pushReplacement(context, ...);
} else {
  // エラーメッセージを表示
  print(authProvider.errorMessage);
}
```

### Apple Sign-In（iOSのみ）

```dart
final authProvider = Provider.of<AuthProvider>(context, listen: false);

if (authProvider.canUseApple) {
  final success = await authProvider.loginWithApple();
  if (success) {
    // ログイン成功
  }
}
```

### Twitterログイン

```dart
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final success = await authProvider.loginWithTwitter();

if (success) {
  // ログイン成功
} else {
  print(authProvider.errorMessage);
}
```

### ログアウト

```dart
final authProvider = Provider.of<AuthProvider>(context, listen: false);
await authProvider.logout();
```

### 現在のユーザー取得

```dart
final authProvider = Provider.of<AuthProvider>(context);
final user = authProvider.currentUser;

if (authProvider.isLoggedIn) {
  print('ユーザーID: ${user?.id}');
  print('メール: ${user?.email}');
  print('ユーザー名: ${user?.username}');
}
```

---

## 🔧 トラブルシューティング

### 問題1: Firebase初期化エラー

**エラー**: `[core/no-app] No Firebase App has been created`

**解決策**:
- `google-services.json`（Android）または`GoogleService-Info.plist`（iOS）が正しく配置されているか確認
- `flutter clean`を実行してから再ビルド

### 問題2: Google Sign-Inが動作しない（Android）

**解決策**:
- SHA-1フィンガープリントがFirebase Consoleに登録されているか確認
- `google-services.json`を再ダウンロードして配置
- アプリを完全にアンインストールしてから再インストール

### 問題3: Google Sign-Inが動作しない（iOS）

**解決策**:
- `Info.plist`に`REVERSED_CLIENT_ID`が正しく設定されているか確認
- `GoogleService-Info.plist`がXcodeのRunner内に追加されているか確認

### 問題4: Apple Sign-Inが表示されない

**解決策**:
- iOSデバイスまたはシミュレータで実行しているか確認（Androidでは非表示）
- XcodeでSign In with Apple Capabilityが追加されているか確認
- `lib/config/firebase_config.dart`で`enableAppleSignIn`が`true`か確認

### 問題5: Twitter Sign-Inが動作しない

**解決策**:
- `lib/providers/auth_provider.dart`にTwitter API KeyとSecret Keyが設定されているか確認
- Twitter Developer PortalでCallback URL `spotlight://`が設定されているか確認
- `AndroidManifest.xml`（Android）または`Info.plist`（iOS）にURLスキームが追加されているか確認

### 問題6: ビルドエラー

```bash
# キャッシュをクリア
flutter clean
flutter pub get

# Android
cd android
./gradlew clean

# iOS
cd ios
pod deintegrate
pod install
```

---

## 📚 詳細ドキュメント

より詳しい設定方法やトラブルシューティングについては、以下のドキュメントを参照してください：

- **[SOCIAL_AUTH_GUIDE.md](SOCIAL_AUTH_GUIDE.md)** - ソーシャルログイン詳細設定ガイド ⭐ 必読
- **[doc/ソーシャル認証への移行.md](doc/ソーシャル認証への移行.md)** - 移行内容と変更点
- [Firebase設定ガイド](doc/Firebase設定ガイド.md) - Firebase基本設定
- [FlutterFire公式ドキュメント](https://firebase.flutter.dev/)
- [Firebase Authentication公式ドキュメント](https://firebase.google.com/docs/auth)

---

## 🎯 次のステップ

Firebase認証が正常に動作したら、以下の機能を追加することをお勧めします：

1. **Firestoreの統合**: ユーザープロフィール、投稿データの保存
2. **Firebase Storage**: 画像やメディアファイルのアップロード
3. **Cloud Messaging**: プッシュ通知
4. **Analytics**: ユーザー行動の分析

---

## 本番環境へのデプロイ前のチェックリスト

- [ ] `lib/config/app_config.dart`の`isDevelopment`を`false`に変更
- [ ] 本番用のSHA-1フィンガープリントを追加（Android）
- [ ] App Store IDを追加（iOS）
- [ ] Firebase Authenticationの設定を確認
- [ ] セキュリティルールを本番用に更新
- [ ] テストアカウントで動作確認

