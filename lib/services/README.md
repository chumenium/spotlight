# Services ディレクトリ

このディレクトリには、アプリケーション全体で使用される共通サービスクラスを配置します。

## ファイル構成

### `firebase_service.dart`
Firebase の初期化と設定を管理するサービスクラス。

**主な機能:**
- Firebase の初期化
- 初期化状態の管理
- プラットフォーム別の設定
- デバッグ情報の出力

**使用例:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.instance.initialize();
  runApp(MyApp());
}
```

### `auth_service.dart`
認証関連のユーティリティ機能を提供するサービスクラス。

**主な機能:**
- メールアドレスのバリデーション
- パスワードのバリデーション
- ユーザー名のバリデーション
- FirebaseAuthException のエラーメッセージ日本語変換
- 認証状態のチェック
- メール確認メール送信

**使用例:**
```dart
// バリデーション
if (!AuthService.isValidEmail(email)) {
  print('無効なメールアドレスです');
}

final passwordError = AuthService.validatePassword(password);
if (passwordError != null) {
  print(passwordError);
}

// エラーメッセージ変換
try {
  await FirebaseAuth.instance.signInWithEmailAndPassword(...);
} on FirebaseAuthException catch (e) {
  final message = AuthService.getAuthErrorMessage(e);
  print(message);
}

// 認証状態チェック
if (AuthService.isLoggedIn()) {
  final userId = AuthService.getCurrentUserId();
}
```

## 設計方針

### サービスクラスの責務
- **ステートレス**: サービスクラスは状態を持たない
- **ユーティリティ**: 共通のロジックを提供
- **再利用性**: 複数の場所から呼び出せる
- **テスタビリティ**: 単体テストが容易

### Providerとの使い分け
- **Provider**: 状態管理が必要な場合（例：AuthProvider）
- **Service**: ユーティリティ機能、状態を持たない処理（例：AuthService）

### 今後追加予定のサービス
- `storage_service.dart` - Firebase Storage の操作
- `firestore_service.dart` - Firestore の操作
- `notification_service.dart` - プッシュ通知
- `analytics_service.dart` - アナリティクス
- `api_service.dart` - バックエンドAPIとの通信

## ベストプラクティス

1. **Singleton パターン**: 必要に応じて Singleton で実装
2. **エラーハンドリング**: 適切なエラー処理を行う
3. **ログ出力**: デバッグモードでのログを適切に出力
4. **ドキュメント**: 各メソッドに適切なコメントを記述
5. **型安全**: null safety を適切に活用

