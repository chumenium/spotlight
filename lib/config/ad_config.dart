import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:io' show Platform;
import 'app_config.dart';

/// 広告設定
/// 
/// すべての広告ユニットIDを一箇所で管理します。
/// 
/// 【広告ユニットIDの取得方法】
/// 1. https://admob.google.com/ にログイン
/// 2. 左メニュー「アプリ」→ 対象アプリ（Android/iOS）を選択
/// 3. 「広告ユニット」タブ → 対象の広告ユニットを選択
/// 4. 詳細画面の「広告ユニットID」(ca-app-pub-XXXX/YYYY形式) をコピー
/// 5. 以下の本番用定数に貼り付け
class AdConfig {
  AdConfig._(); // プライベートコンストラクタ（インスタンス化不可）

  // ============================================
  // テスト用広告ユニットID（開発時に使用）
  // ============================================
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const String testNativeAdUnitId = 'ca-app-pub-3940256099942544/2247696110';

  // ============================================
  // 本番用広告ユニットID（AdMob Consoleから取得したIDに置き換えてください）
  // ============================================
  
  // Android用
  static const String productionBannerAdUnitIdAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String productionInterstitialAdUnitIdAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String productionRewardedAdUnitIdAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String productionNativeAdUnitIdAndroid = 'ca-app-pub-6754131556002286/4338235560';

  // iOS用
  static const String productionBannerAdUnitIdIOS = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String productionInterstitialAdUnitIdIOS = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String productionRewardedAdUnitIdIOS = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String productionNativeAdUnitIdIOS = 'ca-app-pub-6754131556002286/4700185880';

  // ============================================
  // 広告ユニットID取得メソッド
  // ============================================

  /// バナー広告ユニットIDを取得
  static String getBannerAdUnitId() {
    if (kDebugMode || AppConfig.forceTestAds) {
      return testBannerAdUnitId;
    }
    return Platform.isIOS ? productionBannerAdUnitIdIOS : productionBannerAdUnitIdAndroid;
  }

  /// インタースティシャル広告ユニットIDを取得
  static String getInterstitialAdUnitId() {
    if (kDebugMode || AppConfig.forceTestAds) {
      return testInterstitialAdUnitId;
    }
    return Platform.isIOS ? productionInterstitialAdUnitIdIOS : productionInterstitialAdUnitIdAndroid;
  }

  /// リワード広告ユニットIDを取得
  static String getRewardedAdUnitId() {
    if (kDebugMode || AppConfig.forceTestAds) {
      return testRewardedAdUnitId;
    }
    return Platform.isIOS ? productionRewardedAdUnitIdIOS : productionRewardedAdUnitIdAndroid;
  }

  /// ネイティブ広告ユニットIDを取得
  static String getNativeAdUnitId() {
    if (kDebugMode || AppConfig.forceTestAds) {
      return testNativeAdUnitId;
    }
    return Platform.isIOS ? productionNativeAdUnitIdIOS : productionNativeAdUnitIdAndroid;
  }
}
