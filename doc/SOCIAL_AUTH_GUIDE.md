# ソーシャルログイン設定ガイド

SpotLightアプリでは、Google、Apple、Twitterの3つのソーシャルログインをサポートしています。

## 📱 サポートする認証方法

- ✅ **Google Sign-In** - Android、iOS、Web対応
- ✅ **Apple Sign-In** - iOS（必須）、Android（オプション）
- ✅ **Twitter Sign-In** - Android、iOS対応

---

## 🔧 Firebase Console設定

### 1. Google Sign-In

#### 1.1 Firebaseで有効化

1. Firebase Console → Authentication → Sign-in method
2. 「Google」をクリック
3. 「有効にする」をオン
4. プロジェクトのサポートメールを選択
5. 「保存」

#### 1.2 Android設定

**SHA-1フィンガープリントの追加:**

```bash
cd android
./gradlew signingReport
```

出力された`SHA1`をコピー → Firebase Console → プロジェクト設定 → Androidアプリ → 「SHA証明書フィンガープリント」に追加

#### 1.3 iOS設定

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
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>
```

---

### 2. Apple Sign-In

#### 2.1 Apple Developer Console設定

1. [Apple Developer Console](https://developer.apple.com/) にアクセス
2. 「Certificates, Identifiers & Profiles」→「Identifiers」
3. App IDを選択
4. 「Sign In with Apple」を有効化
5. 「Save」

#### 2.2 Firebaseで有効化

1. Firebase Console → Authentication → Sign-in method
2. 「Apple」をクリック
3. 「有効にする」をオン
4. 「保存」

#### 2.3 iOS設定

**Capability追加（Xcode）:**

1. `ios/Runner.xcworkspace`をXcodeで開く
2. Runnerプロジェクトを選択
3. 「Signing & Capabilities」タブ
4. 「+ Capability」をクリック
5. 「Sign In with Apple」を追加

**Info.plist設定:**

既にGoogle Sign-In用に設定済みの場合は、Apple用のURLスキームも追加：

```xml
<key>CFBundleURLTypes</key>
<array>
    <!-- Google用 -->
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>
```

---

### 3. Twitter Sign-In

#### 3.1 Twitter Developer Portal設定

1. [Twitter Developer Portal](https://developer.twitter.com/) にアクセス
2. アプリを作成（または既存のアプリを選択）
3. 「Settings」→「User authentication settings」
4. 以下を設定：
   - **App permissions**: Read
   - **Type of App**: Native App
   - **Callback URLs**:
     ```
     spotlight://
     ```
   - **Website URL**: アプリのウェブサイトURL

5. **API Key**と**API Secret Key**をコピーして保存

#### 3.2 Firebaseで有効化

1. Firebase Console → Authentication → Sign-in method
2. 「Twitter」をクリック
3. 「有効にする」をオン
4. Twitter Developer Portalで取得した**API Key**と**API Secret Key**を入力
5. Callback URLをコピー（念のため）
6. 「保存」

#### 3.3 アプリ側の設定

`lib/providers/auth_provider.dart`の`AuthProvider`コンストラクタ内で、Twitter APIキーを設定：

```dart
_twitterLogin = TwitterLogin(
  apiKey: 'YOUR_TWITTER_API_KEY',        // ← 取得したAPI Keyを入力
  apiSecretKey: 'YOUR_TWITTER_API_SECRET_KEY',  // ← 取得したAPI Secret Keyを入力
  redirectURI: 'spotlight://',
);
```

#### 3.4 Android設定

`android/app/src/main/AndroidManifest.xml`に以下を追加：

```xml
<manifest ...>
    <application ...>
        <!-- 既存のactivityの中に追加 -->
        <activity
            android:name="com.flutter.app.MainActivity"
            ...>
            <!-- 既存のintent-filter -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            
            <!-- Twitter用のintent-filterを追加 -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data
                    android:scheme="spotlight"
                    android:host="" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

#### 3.5 iOS設定

`ios/Runner/Info.plist`に以下を追加（既存のCFBundleURLTypesに追加）：

```xml
<key>CFBundleURLTypes</key>
<array>
    <!-- 既存のGoogle/Apple用 -->
    ...
    
    <!-- Twitter用を追加 -->
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>spotlight</string>
        </array>
    </dict>
</array>
```

---

## 📝 設定ファイルの編集

### Twitter API Keyの設定

`lib/providers/auth_provider.dart`を編集：

```dart
AuthProvider() {
  // Twitter認証の初期化
  _twitterLogin = TwitterLogin(
    apiKey: 'YOUR_TWITTER_API_KEY',        // ← ここを変更
    apiSecretKey: 'YOUR_TWITTER_API_SECRET_KEY',  // ← ここを変更
    redirectURI: 'spotlight://',
  );
  // ...
}
```

⚠️ **セキュリティ注意**: 本番環境では、APIキーを環境変数やシークレットマネージャーで管理することを推奨します。

---

## 🚀 動作確認

### テスト手順

1. アプリを起動
2. ソーシャルログイン画面が表示されることを確認
3. 各ログインボタンをタップして認証フローをテスト

#### Googleログインテスト
- Googleアカウント選択画面が表示される
- アカウントを選択してログイン
- ホーム画面に遷移

#### Appleログインテスト（iOSのみ）
- Apple IDログイン画面が表示される
- Face ID/Touch ID/パスワードで認証
- ホーム画面に遷移

#### Twitterログインテスト
- Twitterログイン画面が表示される
- Twitter認証情報を入力
- アプリの権限を許可
- ホーム画面に遷移

### Firebase Consoleでの確認

1. Firebase Console → Authentication → Users
2. ログインしたユーザーが表示される
3. プロバイダー列に使用した認証方法（Google、Apple、Twitter）が表示される

---

## 🔍 トラブルシューティング

### Google Sign-In

**エラー**: `PlatformException(sign_in_failed)`

**解決策**:
- SHA-1フィンガープリントがFirebase Consoleに登録されているか確認
- `google-services.json`（Android）を再ダウンロードして配置
- アプリをアンインストールして再インストール

### Apple Sign-In

**エラー**: Apple Sign-Inボタンが表示されない

**解決策**:
- iOSデバイスまたはシミュレータで実行しているか確認
- `lib/config/firebase_config.dart`で`enableAppleSignIn`が`true`か確認
- Xcodeで「Sign In with Apple」Capabilityが追加されているか確認

**エラー**: `The operation couldn't be completed`

**解決策**:
- Apple Developer ConsoleでApp IDに「Sign In with Apple」が有効化されているか確認
- Bundle IDが正しいか確認
- デバイスのApple IDにサインインしているか確認

### Twitter Sign-In

**エラー**: `Unable to log in with provided credentials`

**解決策**:
- Twitter API KeyとAPI Secret Keyが正しいか確認
- `lib/providers/auth_provider.dart`のAPIキーを確認
- Twitter Developer PortalでCallback URLが正しく設定されているか確認

**エラー**: リダイレクト後にアプリに戻らない

**解決策**:
- `AndroidManifest.xml`（Android）または`Info.plist`（iOS）にURLスキーム`spotlight://`が設定されているか確認
- URLスキームが他のアプリと競合していないか確認

---

## 📋 チェックリスト

### Google Sign-In
- [ ] Firebase Consoleで有効化
- [ ] SHA-1フィンガープリント追加（Android）
- [ ] `google-services.json`配置（Android）
- [ ] `GoogleService-Info.plist`配置（iOS）
- [ ] `Info.plist`にREVERSED_CLIENT_ID追加（iOS）

### Apple Sign-In
- [ ] Apple Developer ConsoleでSign In with Appleを有効化
- [ ] Firebase Consoleで有効化
- [ ] XcodeでCapability追加（iOS）
- [ ] iOSデバイスでテスト

### Twitter Sign-In
- [ ] Twitter Developer Portalでアプリ作成
- [ ] API KeyとAPI Secret Keyを取得
- [ ] Firebase Consoleで有効化
- [ ] `auth_provider.dart`にAPIキーを設定
- [ ] `AndroidManifest.xml`にintent-filter追加（Android）
- [ ] `Info.plist`にURLスキーム追加（iOS）

---

## 🔐 セキュリティベストプラクティス

### 本番環境への移行

1. **APIキーの管理**
   - Twitter API Keyは環境変数で管理
   - `.env`ファイルを使用（Gitにコミットしない）

2. **本番用SHA-1の追加**
   - リリース用のキーストアからSHA-1を取得
   - Firebase Consoleに追加

3. **Apple Sign-In**
   - 本番用のBundle IDでテスト
   - App Store Connect設定の確認

4. **Twitter**
   - 本番用のCallback URLを設定
   - Production Environment用のAPIキーを使用

---

## 📚 参考資料

- [Firebase Authentication - Google Sign-In](https://firebase.google.com/docs/auth/flutter/federated-auth)
- [Sign in with Apple - Flutter](https://pub.dev/packages/sign_in_with_apple)
- [Twitter Login for Flutter](https://pub.dev/packages/twitter_login)
- [Twitter Developer Portal](https://developer.twitter.com/)

---

## 💡 Tips

### カスタムURLスキームの変更

現在は`spotlight://`を使用していますが、変更する場合：

1. `auth_provider.dart`の`redirectURI`を変更
2. `AndroidManifest.xml`のURLスキームを変更
3. `Info.plist`のURLスキームを変更
4. Twitter Developer PortalのCallback URLを更新

### ログインプロバイダーの無効化

特定のプロバイダーを無効にする場合は、`lib/config/firebase_config.dart`で設定：

```dart
static const bool enableGoogleSignIn = true;   // Google
static const bool enableAppleSignIn = false;   // Apple（無効化例）
static const bool enableTwitterSignIn = true;  // Twitter
```

無効化されたプロバイダーのボタンは自動的に非表示になります。

