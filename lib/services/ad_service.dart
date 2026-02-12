import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../config/ad_config.dart';

/// Google AdMob広告サービス
/// 
/// iOS/Android両方で動作するGoogle AdMob広告を管理します。
/// 
/// セットアップ手順:
/// 1. https://admob.google.com/ でAdMobアカウントを作成
/// 2. アプリを登録（iOSとAndroid）
/// 3. 広告ユニットを作成（バナー、インタースティシャル、リワード）
/// 4. 広告ユニットIDを取得して`lib/config/ad_config.dart`に設定
class AdService {
  static AdService? _instance;
  static AdService get instance {
    _instance ??= AdService._();
    return _instance!;
  }

  AdService._();

  static bool _isInitialized = false;

  /// AdMobの初期化
  /// main.dartのrunApp()前に呼び出す必要があります
  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('📢 AdMob初期化完了');
      }
    } catch (e) {
      _isInitialized = false;
      if (kDebugMode) {
        debugPrint('❌ AdMob初期化エラー: $e');
      }
      rethrow;
    }
  }

  /// AdMobの初期化が完了しているか確認し、完了するまで待機
  static Future<void> ensureInitialized() async {
    if (_isInitialized) {
      return;
    }

    // 初期化が完了するまで最大5秒待機
    const maxWaitTime = Duration(seconds: 5);
    const checkInterval = Duration(milliseconds: 100);
    final startTime = DateTime.now();

    while (!_isInitialized) {
      if (DateTime.now().difference(startTime) > maxWaitTime) {
        // タイムアウトした場合は初期化を再試行
        try {
          await MobileAds.instance.initialize();
          _isInitialized = true;
          return;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ AdMob初期化の再試行に失敗: $e');
          }
          // 初期化に失敗しても続行（広告は表示されないがアプリは動作する）
          return;
        }
      }
      await Future.delayed(checkInterval);
    }
  }

  /// バナー広告を読み込む
  BannerAd? loadBannerAd({
    required AdSize adSize,
    required BannerAdListener listener,
  }) {
    final bannerAd = BannerAd(
      adUnitId: AdConfig.getBannerAdUnitId(),
      size: adSize,
      request: const AdRequest(),
      listener: listener,
    );
    bannerAd.load();
    return bannerAd;
  }

  /// インタースティシャル広告を読み込む
  InterstitialAd? loadInterstitialAd({
    required InterstitialAdLoadCallback listener,
  }) {
    InterstitialAd.load(
      adUnitId: AdConfig.getInterstitialAdUnitId(),
      request: const AdRequest(),
      adLoadCallback: listener,
    );
    return null; // InterstitialAdはコールバックから取得
  }

  /// リワード広告を読み込む
  RewardedAd? loadRewardedAd({
    required RewardedAdLoadCallback listener,
    String? adUnitId,
  }) {
    RewardedAd.load(
      adUnitId: adUnitId ?? AdConfig.getRewardedAdUnitId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: listener,
    );
    return null; // RewardedAdはコールバックから取得
  }
}
