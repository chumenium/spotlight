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
      return 'http://localhost:5000/api';
    } else {
      return 'https://api.spotlight.app'; // 本番環境のURL
    }
  }
  
  // デバッグログの表示制御
  static bool get showDebugLog => isDevelopment;
}

