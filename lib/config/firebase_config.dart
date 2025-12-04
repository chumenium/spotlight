/// Firebase関連の設定を管理
/// 
/// Firebase機能の有効/無効、タイムアウト設定などを一元管理します。
class FirebaseConfig {
  FirebaseConfig._();

  // =========================================================================
  // Authentication設定
  // =========================================================================
  
  /// 認証タイムアウト時間（秒）
  static const int authTimeoutSeconds = 30;
  
  /// メール/パスワード認証の有効化
  static const bool enableEmailAuth = false;
  
  /// Google Sign-Inの有効化
  static const bool enableGoogleSignIn = true;
  
  /// Apple Sign-Inの有効化
  static const bool enableAppleSignIn = false;  // 使用しない
  
  /// 匿名ログインの有効化
  static const bool enableAnonymousAuth = false;

  // =========================================================================
  // Firestore設定
  // =========================================================================
  
  /// Firestoreのキャッシュ有効化
  static const bool enableFirestoreCache = true;
  
  /// Firestoreキャッシュサイズ（MB）
  static const int firestoreCacheSizeMB = 100;

  // =========================================================================
  // Storage設定
  // =========================================================================
  
  /// 画像アップロードの最大ファイルサイズ（MB）
  static const int maxImageUploadSizeMB = 10;
  
  /// 動画アップロードの最大ファイルサイズ（MB）
  static const int maxVideoUploadSizeMB = 100;
  
  /// アップロードタイムアウト時間（秒）
  static const int uploadTimeoutSeconds = 120;

  // =========================================================================
  // Analytics設定
  // =========================================================================
  
  /// Firebase Analyticsの有効化
  static const bool enableAnalytics = true;
  
  /// クラッシュレポートの有効化
  static const bool enableCrashlytics = true;
  
  /// パフォーマンスモニタリングの有効化
  static const bool enablePerformanceMonitoring = true;

  // =========================================================================
  // Cloud Messaging設定
  // =========================================================================
  
  /// プッシュ通知の有効化
  static const bool enablePushNotifications = true;
  
  /// バックグラウンド通知の有効化
  static const bool enableBackgroundNotifications = true;

  // =========================================================================
  // セキュリティ設定
  // =========================================================================
  
  /// App Checkの有効化（本番環境推奨）
  static const bool enableAppCheck = false;
  
  /// デバッグモードでのセキュリティログ出力
  static const bool enableSecurityLogs = true;

  // =========================================================================
  // コレクション名（Firestore）
  // =========================================================================
  
  static const String usersCollection = 'users';
  static const String postsCollection = 'posts';
  static const String commentsCollection = 'comments';
  static const String notificationsCollection = 'notifications';
  static const String searchHistoryCollection = 'search_history';
  static const String playlistsCollection = 'playlists';
  static const String spotlightsCollection = 'spotlights';

  // =========================================================================
  // Storageパス
  // =========================================================================
  
  static const String avatarsPath = 'avatars';
  static const String postsPath = 'posts';
  static const String thumbnailsPath = 'thumbnails';

  // =========================================================================
  // エラーメッセージ
  // =========================================================================
  
  static const String networkErrorMessage = 'ネットワークエラーが発生しました';
  static const String timeoutErrorMessage = '接続がタイムアウトしました';
  static const String unknownErrorMessage = '予期しないエラーが発生しました';
}

