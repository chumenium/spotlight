# Config ディレクトリ

このディレクトリには、アプリケーション全体の設定ファイルを配置します。

## ファイル構成

### `app_config.dart`
アプリケーション全体の基本設定を管理。

**設定項目:**
- 開発モード/本番モードの切り替え
- 認証スキップ機能の制御
- API ベース URL
- デバッグログの表示制御

**使用例:**
```dart
if (AppConfig.isDevelopment) {
  print('開発モード');
}

final apiUrl = AppConfig.apiBaseUrl;
```

### `firebase_config.dart`
Firebase 関連の設定を一元管理。

**設定項目:**

#### 認証設定
- 認証タイムアウト時間
- パスワードの最小文字数
- 各種ソーシャルログインの有効/無効

#### Firestore 設定
- キャッシュの有効化
- キャッシュサイズ
- コレクション名

#### Storage 設定
- アップロード可能なファイルサイズ
- アップロードタイムアウト
- ストレージパス

#### Analytics 設定
- Analytics の有効化
- Crashlytics の有効化
- Performance Monitoring の有効化

#### Cloud Messaging 設定
- プッシュ通知の有効化
- バックグラウンド通知の設定

**使用例:**
```dart
// パスワードバリデーション
if (password.length < FirebaseConfig.minPasswordLength) {
  print('パスワードが短すぎます');
}

// Google Sign-In チェック
if (FirebaseConfig.enableGoogleSignIn) {
  // Google ログイン処理
}

// Firestore コレクション名
final usersRef = FirebaseFirestore.instance
    .collection(FirebaseConfig.usersCollection);
```

## 設計方針

### 設定の分類
1. **環境設定** (`app_config.dart`)
   - 開発/本番の切り替え
   - 環境依存の設定

2. **機能設定** (`firebase_config.dart`)
   - 機能の有効/無効
   - 定数値
   - リソース名

### 設定変更時の注意点

#### 本番デプロイ前
```dart
// app_config.dart
static const bool isDevelopment = false; // 必ず false に変更
```

#### 機能の有効/無効
```dart
// firebase_config.dart
static const bool enableGoogleSignIn = true; // 機能を有効化
```

### 今後追加予定の設定
- `theme_config.dart` - テーマとスタイル設定
- `api_config.dart` - API エンドポイント設定
- `feature_flags.dart` - 機能フラグ管理
- `constants.dart` - アプリ全体の定数

## ベストプラクティス

1. **定数の使用**: マジックナンバーを避け、定数で管理
2. **命名規則**: わかりやすく一貫性のある名前を使用
3. **グループ化**: 関連する設定をまとめる
4. **コメント**: 各設定の目的と影響を記述
5. **型安全**: 適切な型を使用
6. **デフォルト値**: 安全なデフォルト値を設定

## 使用上の注意

### セキュリティ
- API キーなどの機密情報は環境変数で管理
- 設定ファイルを Git にコミットする際は機密情報を含めない

### パフォーマンス
- 頻繁にアクセスする設定は const で定義
- 動的な設定が必要な場合は getter を使用

### メンテナンス
- 使用されていない設定は定期的に削除
- 設定変更時は影響範囲を確認

