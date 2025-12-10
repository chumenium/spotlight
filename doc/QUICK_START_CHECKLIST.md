# 🚀 ログイン機能 クイックスタートチェックリスト

Firebase設定完了後、ログイン機能を使用するために必要な手順です。

---

## ✅ 必須タスク

### 1. Twitter API Keyの設定（必須）

**ファイル**: `lib/auth/auth_config.dart`

現在の状態を確認：
```dart
// 33-36行目あたり
static const String twitterApiKey = String.fromEnvironment(
  'TWITTER_API_KEY',
  defaultValue: 'YOUR_TWITTER_API_KEY', // ← ここを変更
);
```

**手順**:

#### a. Twitter Developer Portalで取得
1. https://developer.twitter.com/ にアクセス
2. アプリを作成
3. Keys and tokens → API Key と API Secret Key をコピー

#### b. auth_config.dartに設定

**方法1: 直接設定（開発用・推奨）**
```dart
static const String twitterApiKey = 'あなたのAPIキー';
static const String twitterApiSecretKey = 'あなたのAPIシークレットキー';
```

**方法2: 環境変数から読み込み（本番用）**
```bash
flutter run --dart-define=TWITTER_API_KEY=your_key --dart-define=TWITTER_API_SECRET_KEY=your_secret
```

⚠️ **重要**: Twitter API Keyを設定しないと、Twitterログインが動作しません。

---

### 2. パッケージのインストール（必須）

```bash
flutter pub get
```

これにより以下のパッケージがインストールされます：
- `firebase_core` - Firebase初期化
- `firebase_auth` - Firebase認証
- `google_sign_in` - Googleログイン
- `sign_in_with_apple` - Appleログイン
- `twitter_login` - Twitterログイン

---

### 3. プラットフォーム別の設定確認

#### Android

**必要なファイル**:
- [x] `android/app/google-services.json` が配置されている
- [x] `android/app/build.gradle.kts` にGoogle Servicesプラグイン追加

**SHA-1フィンガープリント**（Google Sign-In用）:
```bash
cd android
./gradlew signingReport
```
出力されたSHA-1をFirebase Consoleに登録済みか確認

**Twitter用URL Scheme**:
`android/app/src/main/AndroidManifest.xml`に以下が必要：
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="spotlight"
        android:host="" />
</intent-filter>
```

#### iOS

**必要なファイル**:
- [x] `ios/Runner/GoogleService-Info.plist` が配置されている
- [x] Xcodeで`ios/Runner.xcworkspace`を開いてRunnerに追加済み

**URL Scheme**:
`ios/Runner/Info.plist`に以下が必要：
```xml
<key>CFBundleURLTypes</key>
<array>
    <!-- Google用 -->
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
    <!-- Twitter用 -->
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>spotlight</string>
        </array>
    </dict>
</array>
```

**Apple Sign-In Capability**:
- Xcodeで「Sign In with Apple」Capabilityを追加済みか確認

---

## 🧪 動作確認手順

### ステップ1: アプリを起動

```bash
flutter run
```

### ステップ2: ログイン画面の確認

起動すると`SocialLoginScreen`が表示されます：
- ✅ Googleログインボタンが表示される
- ✅ Appleログインボタンが表示される（iOSのみ）
- ✅ Twitterログインボタンが表示される

### ステップ3: 各ログイン方法をテスト

#### Googleログイン
1. 「Googleでログイン」をタップ
2. Googleアカウント選択画面が表示される
3. アカウントを選択
4. ✅ ホーム画面に遷移すれば成功

#### Appleログイン（iOSのみ）
1. 「Appleでログイン」をタップ
2. Face ID/Touch ID/パスワード認証
3. ✅ ホーム画面に遷移すれば成功

#### Twitterログイン
1. 「Twitterでログイン」をタップ
2. Twitterログイン画面が表示される
3. 認証して権限を許可
4. ✅ ホーム画面に遷移すれば成功

### ステップ4: Firebase Consoleで確認

1. Firebase Console → Authentication → Users
2. ログインしたユーザーが表示される
3. プロバイダー列に使用した認証方法が表示される

---

## 🐛 トラブルシューティング

### エラー1: Twitter API Keyエラー
```
Error: Unable to log in with provided credentials
```

**解決策**:
- `lib/auth/auth_config.dart`のAPI Keyが正しいか確認
- Twitter Developer PortalでCallback URL `spotlight://` が設定されているか確認

### エラー2: Google Sign-Inが動作しない（Android）
```
PlatformException(sign_in_failed, ...)
```

**解決策**:
- SHA-1フィンガープリントがFirebase Consoleに登録されているか確認
- `google-services.json`を再ダウンロードして配置
- アプリをアンインストールして再インストール

### エラー3: Apple Sign-Inボタンが表示されない
**解決策**:
- iOSデバイスで実行しているか確認（AndroidではAppleボタンは非表示）
- Xcodeで「Sign In with Apple」Capabilityが追加されているか確認

### エラー4: Firebase初期化エラー
```
[core/no-app] No Firebase App has been created
```

**解決策**:
- `google-services.json`（Android）または`GoogleService-Info.plist`（iOS）が正しく配置されているか確認
- `flutter clean`を実行してから再ビルド

---

## 📊 現在の認証機能の状態

### 実装済み ✅
- [x] Firebase Authenticationとの連携
- [x] Google Sign-In
- [x] Apple Sign-In（iOS）
- [x] Twitter Sign-In
- [x] 自動ログイン（セッション維持）
- [x] ログアウト
- [x] エラーハンドリング
- [x] Firebase UIDをユーザーIDとして使用

### 取得されるユーザー情報
```dart
User {
  id: 'ABC123...',           // Firebase UID（自動生成）
  email: 'user@example.com',  // プロバイダーから取得
  username: 'User Name',      // プロバイダーから取得
  avatarUrl: 'https://...',   // プロバイダーから取得（あれば）
}
```

### ユーザーが入力する項目
- ❌ ユーザーID → Firebase UIDを使用（自動生成）
- ❌ メールアドレス → プロバイダーから取得
- ❌ パスワード → プロバイダーが管理
- ❌ ユーザー名 → プロバイダーから取得

**すべて自動**で取得されるため、ユーザーが手動で入力する項目はありません。

---

## 🔍 デバッグログの確認

アプリ実行中、以下のログが出力されます：

```
🔐 [Google] Sign-In開始
🔐 [Google] 認証情報取得: user@example.com
🔐 [Google] Sign-In成功
🔐 ユーザーログイン: ABC123...
  プロバイダー: google.com
```

これらのログで認証フローを追跡できます。

**ログを無効化するには**:
`lib/auth/auth_config.dart`の149行目：
```dart
static const bool enableAuthDebugLog = false;  // trueをfalseに
```

---

## 🎯 次のステップ

### 1. ユーザープロフィール機能の実装
Firebase UIDをキーにして、ユーザー情報をFirestoreに保存：

```dart
// 例
FirebaseFirestore.instance
  .collection('users')
  .doc(user.id)  // Firebase UID
  .set({
    'email': user.email,
    'username': user.username,
    'avatarUrl': user.avatarUrl,
    'createdAt': FieldValue.serverTimestamp(),
  });
```

### 2. プロフィール画面との連携
`lib/screens/profile_screen.dart`で現在のユーザー情報を表示：

```dart
final authProvider = Provider.of<AuthProvider>(context);
final user = authProvider.currentUser;

Text('ユーザー名: ${user?.username}');
Text('メール: ${user?.email}');
```

### 3. ログアウト機能の実装
プロフィール画面などにログアウトボタンを追加：

```dart
ElevatedButton(
  onPressed: () async {
    await authProvider.logout();
    // ログイン画面に遷移
  },
  child: Text('ログアウト'),
);
```

---

## 📱 開発モードのスキップ機能

開発中、ログイン画面をスキップできます：

**有効化**:
`lib/config/app_config.dart`：
```dart
static const bool isDevelopment = true;  // スキップボタン表示
```

**無効化（本番環境）**:
```dart
static const bool isDevelopment = false;  // スキップボタン非表示
```

---

## 📚 参考ドキュメント

- **lib/auth/README.md** - 認証機能の詳細
- **SOCIAL_AUTH_GUIDE.md** - ソーシャルログイン詳細設定
- **FIREBASE_QUICKSTART.md** - Firebase クイックスタート
- **SECURITY_AND_CODE_IMPROVEMENT.md** - セキュリティ改善内容

---

## ✅ 最終チェックリスト

準備完了の確認：

### Firebase設定
- [x] Firebase Consoleでプロジェクト作成
- [x] Android/iOSアプリを追加
- [x] `google-services.json`配置（Android）
- [x] `GoogleService-Info.plist`配置（iOS）
- [x] Firebase Authenticationで各プロバイダーを有効化

### コード設定
- [ ] `lib/auth/auth_config.dart`にTwitter API Key設定
- [ ] `flutter pub get`実行
- [ ] URL Scheme設定（Android/iOS）
- [ ] SHA-1登録（Android）

### テスト
- [ ] アプリ起動成功
- [ ] ログイン画面表示
- [ ] Googleログイン成功
- [ ] Appleログイン成功（iOS）
- [ ] Twitterログイン成功
- [ ] Firebase Consoleでユーザー確認

すべてチェックが入れば、ログイン機能は完璧に動作します！ 🎉

