/// アプリケーション設定
/// 開発モードと本番モードを切り替える
class AppConfig {
  // 開発モード: true = スキップ可能, false = スキップ不可
  // 本番デプロイ時は必ずfalseに変更すること
  static const bool isDevelopment = false;
  
  // スキップボタンの表示制御
  static bool get canSkipAuth => isDevelopment;
  
  // APIのベースURL（将来的に使用）
  static String get apiBaseUrl {
    if (isDevelopment) {
      return 'https://api.spotlight-app.click/api'; // 開発環境のバックエンドサーバー
    } else {
      return 'https://api.spotlight-app.click/api'; // 本番環境のURL
    }
  }

  // 投稿API専用のベースURL（CloudFront回避）
  static String get postApiBaseUrl => 'https://api.spotlight-app.click/api';
  
  // バックエンドサーバーのURL（直接接続）
  static String get backendUrl => 'https://api.spotlight-app.click';
  
  // CloudFrontのURL（S3コンテンツ配信用）
  // メディアファイル（画像、動画、サムネイル）はCloudFront経由で配信
  static String get cloudFrontUrl {
    if (isDevelopment) {
      // 開発環境: CloudFrontのURL
      return 'https://d30se1secd7t6t.cloudfront.net';
    } else {
      // 本番環境: CloudFrontのURL
      return 'https://d30se1secd7t6t.cloudfront.net';
    }
  }
  
  // メディアファイルのベースURL（CloudFront経由）
  // コンテンツ、サムネイル、アイコンなどのメディアファイルに使用
  static String get mediaBaseUrl => cloudFrontUrl;
  
  // デバッグログの表示制御
  static bool get showDebugLog => isDevelopment;

  // 詳細ログの表示制御（false=エラーのみ, true=全ログ）
  // デバッグ中にターミナルが見やすくなる
  static const bool verboseLog = false;

  // TestFlightなど審査前の環境でテスト広告を強制する
  // 本番審査後はfalseに変更すること
  static const bool forceTestAds = false;
}

