/// アプリケーション設定
/// 開発モードと本番モードを切り替える
class AppConfig {
  // 開発モード: true = スキップ可能, false = スキップ不可
  // 本番デプロイ時は必ずfalseに変更すること
  static const bool isDevelopment = true;
  
  // スキップボタンの表示制御
  static bool get canSkipAuth => isDevelopment;
  
  // APIのベースURL（将来的に使用）
  static String get apiBaseUrl {
    if (isDevelopment) {
      return 'http://54.150.123.156:5000/api'; // 開発環境のバックエンドサーバー
    } else {
      return 'https://api.spotlight.app'; // 本番環境のURL
    }
  }
  
  // バックエンドサーバーのURL（直接接続）
  static String get backendUrl => 'http://54.150.123.156:5000';
  
  // CloudFrontのURL（S3コンテンツ配信用）
  // メディアファイル（画像、動画、サムネイル、アイコン）はCloudFront経由で配信
  static String get cloudFrontUrl {
    if (isDevelopment) {
      // 開発環境: CloudFrontのURL（実際のURLに置き換えてください）
      return 'https://d1234567890.cloudfront.net';
    } else {
      // 本番環境: CloudFrontのURL（実際のURLに置き換えてください）
      return 'https://d1234567890.cloudfront.net';
    }
  }
  
  // メディアファイルのベースURL（CloudFront経由）
  // コンテンツ、サムネイル、アイコンなどのメディアファイルに使用
  static String get mediaBaseUrl => cloudFrontUrl;
  
  // デバッグログの表示制御
  static bool get showDebugLog => isDevelopment;
}

