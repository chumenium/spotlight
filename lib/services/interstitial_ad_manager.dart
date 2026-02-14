import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';

/// インタースティシャル広告マネージャー
/// 
/// フルスクリーン広告の読み込みと表示を管理します。
/// 投稿の間に表示するのに適しています。
class InterstitialAdManager {
  static InterstitialAdManager? _instance;
  static InterstitialAdManager get instance {
    _instance ??= InterstitialAdManager._();
    return _instance!;
  }

  InterstitialAdManager._();

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;
  bool _isReady = false;

  /// インタースティシャル広告を読み込む
  /// 
  /// 事前に広告を読み込んでおくことで、スムーズに表示できます。
  void loadAd() {
    if (_isLoading || _isReady) return;

    _isLoading = true;

    AdService.instance.loadInterstitialAd(
      listener: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isLoading = false;
          _isReady = true;

          // 広告が閉じられたときの処理
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _interstitialAd = null;
              _isReady = false;
              // 広告を閉じた後、次の広告を事前に読み込む
              loadAd();
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              _interstitialAd = null;
              _isReady = false;
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isLoading = false;
          _isReady = false;
        },
      ),
    );
  }

  /// インタースティシャル広告を表示
  /// 
  /// 広告が読み込まれていない場合は何もしません。
  /// 事前に`loadAd()`を呼び出して広告を読み込んでおく必要があります。
  void showAd() {
    if (_interstitialAd != null && _isReady) {
      _interstitialAd!.show();
      _isReady = false;
    }
  }

  /// 広告が読み込み済みかどうか
  bool get isReady => _isReady;

  /// 広告を破棄
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isReady = false;
    _isLoading = false;
  }
}
