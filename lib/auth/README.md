# Auth ディレクトリ

このディレクトリには、Firebase Authenticationを使用したソーシャルログイン機能に関連するすべてのファイルが含まれています。

## 📁 ファイル構成

```
lib/auth/
├── auth_provider.dart         # 認証状態管理（Provider）
├── auth_service.dart          # 認証ユーティリティ
├── auth_config.dart           # 認証設定（Twitter API Keyなど）
├── social_login_screen.dart   # ソーシャルログイン画面
└── README.md                  # このファイル
```

---

## 📄 各ファイルの説明

### `auth_provider.dart`
**役割**: 認証状態の管理とソーシャルログインの実装

**主な機能**:
- Firebase Authenticationとの連携
- Google Sign-In
- Apple Sign-In（iOS）
- Twitter Sign-In
- 認証状態の監視（authStateChanges）
- ログアウト

**使用例**:
```dart
final authProvider = Provider.of<AuthProvider>(context);

// ログイン
await authProvider.loginWithGoogle();
await authProvider.loginWithApple();
await authProvider.loginWithTwitter();

// 現在のユーザー情報
final user = authProvider.currentUser;
print('ユーザーID: ${user?.id}');  // Firebase UID
```

**重要なポイント**:
- `User.id`にはFirebase UIDが格納される（自動生成）
- メールアドレス・パスワードはソーシャルログインから自動取得
- ユーザーが手動で登録する項目はない

---

### `auth_service.dart`
**役割**: 認証関連のユーティリティ機能

**主な機能**:
- FirebaseAuthExceptionのエラーメッセージ日本語変換
- Firebase UID取得
- ログイン状態確認
- プロフィール情報取得（メール、表示名、画像URL）
- 使用中の認証プロバイダー確認

**使用例**:
```dart
// エラーメッセージ変換
try {
  await FirebaseAuth.instance.signInWithCredential(credential);
} on FirebaseAuthException catch (e) {
  final message = AuthService.getAuthErrorMessage(e);
  showError(message);  // 日本語のエラーメッセージ
}

// Firebase UID取得
final userId = AuthService.getCurrentUserId();

// プロバイダー確認
if (AuthService.isSignedInWithProvider('google.com')) {
  print('Googleでログイン中');
}
```

**重要なポイント**:
- ステートレスなユーティリティクラス
- すべてのメソッドはstatic
- Firebase Authenticationと直接やり取り

---

### `auth_config.dart`
**役割**: 認証関連の設定を一元管理

**主な設定**:
- Twitter API Key/Secret Key
- OAuth Callback URL
- プロフィール情報取得スコープ
- デバッグログの有効/無効
- セキュリティ設定

**使用例**:
```dart
// Twitter API設定
final twitterLogin = TwitterLogin(
  apiKey: AuthConfig.twitterApiKey,
  apiSecretKey: AuthConfig.twitterApiSecretKey,
  redirectURI: AuthConfig.twitterRedirectUri,
);

// デバッグログ
if (AuthConfig.enableAuthDebugLog) {
  debugPrint('認証処理開始');
}
```

**セキュリティ注意**:
- 本番環境では環境変数から読み込むこと
- Twitter APIキーを直接コミットしない
- `.gitignore`に追加することを推奨

---

### `social_login_screen.dart`
**役割**: ソーシャルログイン専用の画面UI

**主な機能**:
- Google、Apple、Twitterのログインボタン表示
- プラットフォーム別の表示制御（Apple Sign-InはiOSのみ）
- ローディング状態の表示
- エラーメッセージの表示
- 開発モード用のスキップ機能

**使用例**:
```dart
// main.dartから
home: Consumer<AuthProvider>(
  builder: (context, authProvider, _) {
    if (authProvider.isLoggedIn) {
      return const MainScreen();
    } else {
      return const SocialLoginScreen();
    }
  },
),
```

---

## 🔄 データフロー

```
1. ユーザーがログインボタンをタップ
   ↓
2. SocialLoginScreen → AuthProvider.loginWithGoogle()
   ↓
3. Google Sign-Inダイアログ表示
   ↓
4. ユーザーがGoogleアカウントを選択
   ↓
5. Google認証情報（accessToken、idToken）取得
   ↓
6. Firebase Authenticationに送信
   ↓
7. Firebase UIDが自動生成される
   ↓
8. authStateChangesリスナーが発火
   ↓
9. AuthProvider._onAuthStateChanged()が呼ばれる
   ↓
10. User情報が更新される（id = Firebase UID）
   ↓
11. notifyListeners()でUIが更新される
```

---

## 🔐 セキュリティのベストプラクティス

### 1. Twitter API Keyの管理

**開発環境**:
```dart
// auth_config.dartに直接記述（開発用）
static const String twitterApiKey = 'YOUR_DEV_API_KEY';
```

**本番環境**:
```dart
// 環境変数から読み込み
static const String twitterApiKey = String.fromEnvironment(
  'TWITTER_API_KEY',
  defaultValue: '',  // 本番ではデフォルト値を空に
);
```

実行時:
```bash
flutter run --dart-define=TWITTER_API_KEY=prod_key_here
```

### 2. Firebase UID の使用

```dart
// ✅ 正しい: Firebase UIDをそのまま使用
User(
  id: firebaseUser.uid,  // 自動生成される一意のID
  ...
);

// ❌ 間違い: 独自のIDを生成
User(
  id: generateCustomId(),  // NG
  ...
);
```

### 3. プロフィール情報の取得

```dart
// ソーシャルログインから自動取得
email: firebaseUser.email,              // プロバイダーから
username: firebaseUser.displayName,     // プロバイダーから
avatarUrl: firebaseUser.photoURL,       // プロバイダーから

// ユーザーに手動入力させない
// メールアドレス・パスワードの登録画面は不要
```

---

## 🧪 テスト

### ユニットテスト例

```dart
test('Firebase UID取得テスト', () {
  // モックユーザーでログイン
  final userId = AuthService.getCurrentUserId();
  expect(userId, isNotNull);
  expect(userId, matches(r'^[a-zA-Z0-9]{20,}$'));
});

test('エラーメッセージ変換テスト', () {
  final exception = FirebaseAuthException(code: 'user-not-found');
  final message = AuthService.getAuthErrorMessage(exception);
  expect(message, 'このメールアドレスは登録されていません');
});
```

---

## 📚 関連ドキュメント

- [SOCIAL_AUTH_GUIDE.md](../../SOCIAL_AUTH_GUIDE.md) - ソーシャルログイン詳細設定ガイド
- [SECURITY_AND_CODE_IMPROVEMENT.md](../../SECURITY_AND_CODE_IMPROVEMENT.md) - セキュリティ改善内容
- [Firebase Authentication公式ドキュメント](https://firebase.google.com/docs/auth)

---

## 🔧 トラブルシューティング

### Google Sign-Inが動作しない
- SHA-1フィンガープリントがFirebase Consoleに登録されているか確認
- `google-services.json`（Android）が正しく配置されているか確認

### Apple Sign-Inが表示されない
- iOSデバイスで実行しているか確認
- XcodeでSign In with Apple Capabilityが追加されているか確認

### Twitter Sign-Inが動作しない
- `auth_config.dart`にAPI KeyとSecret Keyが設定されているか確認
- Twitter Developer PortalでCallback URLが設定されているか確認

---

## 💡 今後の拡張

### 追加予定の機能
- [ ] メールアドレス確認機能
- [ ] 電話番号認証
- [ ] 多要素認証（MFA）
- [ ] ソーシャルログインのアカウントリンク

### リファクタリング案
- [ ] Riverpod への移行（Provider から）
- [ ] go_router との統合
- [ ] 認証状態の永続化強化

---

## 📝 注意事項

1. **Firebase UIDの重要性**
   - すべての認証プロバイダーで一意
   - 変更されない永続的な識別子
   - データベースのキーとして使用

2. **ソーシャルログインの特性**
   - メールアドレス・パスワードはプロバイダーが管理
   - ユーザーが手動で登録する項目はない
   - プロフィール情報は自動取得

3. **セキュリティ**
   - Twitter API Keyは環境変数で管理
   - 本番環境ではデバッグログを無効化
   - Firebase Consoleのセキュリティルールを設定

この構造により、認証関連のコードがすべて`lib/auth/`ディレクトリに集約され、
保守性と可読性が大幅に向上します。

