/// ソーシャル認証の設定を管理
/// 
/// セキュリティ上重要な認証関連の設定を一元管理します
/// 本番環境では環境変数から読み込むことを推奨します
class AuthConfig {
  AuthConfig._();

  // ==========================================================================
  // Twitter API設定
  // ==========================================================================
  
  /// Twitter API Key
  /// 
  /// Twitter Developer Portalで取得したAPI Keyを設定してください
  /// https://developer.twitter.com/
  /// 
  /// セキュリティ注意:
  /// - 本番環境では環境変数から読み込んでください
  /// - このファイルをGitにコミットする前に、実際のキーを削除してください
  /// - .gitignoreに追加することを推奨します
  static const String twitterApiKey = String.fromEnvironment(
    'TWITTER_API_KEY',
    defaultValue: 'YOUR_TWITTER_API_KEY', // 開発用デフォルト値
  );

  /// Twitter API Secret Key
  /// 
  /// Twitter Developer Portalで取得したAPI Secret Keyを設定してください
  /// 
  /// セキュリティ注意:
  /// - 絶対に公開しないでください
  /// - 本番環境では環境変数から読み込んでください
  static const String twitterApiSecretKey = String.fromEnvironment(
    'TWITTER_API_SECRET_KEY',
    defaultValue: 'YOUR_TWITTER_API_SECRET_KEY', // 開発用デフォルト値
  );

  /// Twitter OAuth Callback URL
  /// 
  /// Twitter認証後にアプリに戻るためのカスタムURLスキーム
  /// 
  /// 設定場所:
  /// - Android: AndroidManifest.xmlのintent-filter
  /// - iOS: Info.plistのCFBundleURLSchemes
  /// - Twitter Developer Portal: Callback URLs
  static const String twitterRedirectUri = 'spotlight://';

  // ==========================================================================
  // ユーザーID管理
  // ==========================================================================
  
  /// Firebase UIDをユーザーIDとして使用
  /// 
  /// true: Firebase Authenticationが生成したUIDをそのまま使用（推奨）
  /// false: 別のユーザーID生成方式を使用
  /// 
  /// 推奨設定: true
  /// 理由:
  /// - Firebase UIDは一意性が保証されている
  /// - すべての認証プロバイダーで一貫している
  /// - セキュリティ上安全
  static const bool useFirebaseUidAsUserId = true;

  // ==========================================================================
  // プロフィール情報の取得設定
  // ==========================================================================
  
  /// ソーシャルログインから取得する情報
  /// 
  /// 各プロバイダーから以下の情報を自動取得します:
  /// 
  /// Google Sign-In:
  /// - Firebase UID (必須)
  /// - メールアドレス
  /// - 表示名
  /// - プロフィール画像URL
  /// 
  /// Apple Sign-In:
  /// - Firebase UID (必須)
  /// - メールアドレス (ユーザーが隠すことも可能)
  /// - 名前 (初回ログイン時のみ)
  /// 
  /// Twitter Sign-In:
  /// - Firebase UID (必須)
  /// - ユーザー名
  /// - プロフィール画像URL
  /// - メールアドレス (API設定により取得可能)
  
  /// Google Sign-Inで要求するスコープ
  /// 
  /// デフォルト: ['email', 'profile']
  /// 追加可能なスコープ: https://developers.google.com/identity/protocols/oauth2/scopes
  static const List<String> googleScopes = [
    'email',
    'profile',
  ];

  /// Apple Sign-Inで要求するスコープ
  /// 
  /// デフォルト: ['email', 'fullName']
  static const List<String> appleScopes = [
    'email',
    'fullName',
  ];

  // ==========================================================================
  // セキュリティ設定
  // ==========================================================================
  
  /// 認証トークンの自動更新を有効化
  /// 
  /// true: Firebase SDKが自動的にトークンを更新（推奨）
  /// false: 手動でトークンを管理
  static const bool autoRefreshToken = true;

  /// 認証状態の永続化
  /// 
  /// true: アプリ再起動後もログイン状態を維持（推奨）
  /// false: アプリ終了時にログアウト
  static const bool persistAuthState = true;

  // ==========================================================================
  // デバッグ設定
  // ==========================================================================
  
  /// 認証フローのデバッグログを出力
  /// 
  /// true: 詳細なログを出力（開発時のみ）
  /// false: ログを出力しない（本番環境推奨）
  static const bool enableAuthDebugLog = true;

  /// テストモード
  /// 
  /// true: テスト用のダミーアカウントを使用可能
  /// false: 通常モード
  static const bool isTestMode = false;
}

