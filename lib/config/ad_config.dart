import 'dart:io' show Platform;

/// 広告設定（本番用）
/// 
/// すべての広告ユニットIDを一箇所で管理します。
/// 
/// 【広告ユニットIDの取得方法】
/// 1. https://admob.google.com/ にログイン
/// 2. 左メニュー「アプリ」→ 対象アプリ（Android/iOS）を選択
/// 3. 「広告ユニット」タブ → 対象の広告ユニットを選択
/// 4. 詳細画面の「広告ユニットID」(ca-app-pub-XXXX/YYYY形式) をコピー
/// 5. 以下の定数に貼り付け
class AdConfig {
  AdConfig._();

  // ============================================
  // Android用 広告ユニットID
  // ============================================
  static const String bannerAdUnitIdAndroid = 'ca-app-pub-6754131556002286/4338235560';
  static const String interstitialAdUnitIdAndroid = 'ca-app-pub-6754131556002286/4338235560';
  static const String rewardedAdUnitIdAndroid = 'ca-app-pub-6754131556002286/4338235560';
  static const String nativeAdUnitIdAndroid = 'ca-app-pub-6754131556002286/4338235560';

  // ============================================
  // iOS用 広告ユニットID
  // ============================================
  static const String bannerAdUnitIdIOS = 'ca-app-pub-6754131556002286/4700185880';
  static const String interstitialAdUnitIdIOS = 'ca-app-pub-6754131556002286/4700185880';
  static const String rewardedAdUnitIdIOS = 'ca-app-pub-6754131556002286/4700185880';
  static const String nativeAdUnitIdIOS = 'ca-app-pub-6754131556002286/4700185880';

  // ============================================
  // 広告ユニットID取得メソッド
  // ============================================

  /// バナー広告ユニットIDを取得
  static String getBannerAdUnitId() {
    return Platform.isIOS ? bannerAdUnitIdIOS : bannerAdUnitIdAndroid;
  }

  /// インタースティシャル広告ユニットIDを取得
  static String getInterstitialAdUnitId() {
    return Platform.isIOS ? interstitialAdUnitIdIOS : interstitialAdUnitIdAndroid;
  }

  /// リワード広告ユニットIDを取得
  static String getRewardedAdUnitId() {
    return Platform.isIOS ? rewardedAdUnitIdIOS : rewardedAdUnitIdAndroid;
  }

  /// ネイティブ広告ユニットIDを取得
  static String getNativeAdUnitId() {
    return Platform.isIOS ? nativeAdUnitIdIOS : nativeAdUnitIdAndroid;
  }
}
