import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../config/ad_config.dart';

/// ネイティブ広告マネージャー
/// 
/// Instagramのリール広告のような形式で、投稿と同じスタイルで表示される広告を管理します。
/// スワイプでスキップ可能です。
/// 
/// 広告ユニットIDは`lib/config/ad_config.dart`で管理されています。
class NativeAdManager {
  static NativeAdManager? _instance;
  static NativeAdManager get instance {
    _instance ??= NativeAdManager._();
    return _instance!;
  }

  NativeAdManager._();

  /// ネイティブ広告を読み込む
  /// 
  /// [onAdLoaded]: 広告が読み込まれたときに呼ばれるコールバック
  /// [onAdFailedToLoad]: 広告の読み込みに失敗したときに呼ばれるコールバック
  NativeAd loadNativeAd({
    required void Function(NativeAd ad) onAdLoaded,
    required void Function(NativeAd ad, LoadAdError error) onAdFailedToLoad,
  }) {
    final nativeAd = NativeAd(
      adUnitId: AdConfig.getNativeAdUnitId(),
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (kDebugMode) {
            debugPrint('✅ ネイティブ広告の読み込み完了');
          }
          final nativeAd = ad as NativeAd;
          onAdLoaded(nativeAd);
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            debugPrint('❌ ネイティブ広告の読み込み失敗: $error');
          }
          ad.dispose();
          final nativeAd = ad as NativeAd;
          onAdFailedToLoad(nativeAd, error);
        },
        onAdClicked: (_) {
          if (kDebugMode) {
            debugPrint('📢 ネイティブ広告がクリックされました');
          }
        },
        onAdImpression: (_) {
          if (kDebugMode) {
            debugPrint('📢 ネイティブ広告が表示されました');
          }
        },
      ),
    );

    nativeAd.load();
    return nativeAd;
  }
}
