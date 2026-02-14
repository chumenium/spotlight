import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ad_config.dart';
import 'ad_service.dart';

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
  Future<NativeAd> loadNativeAd({
    required TemplateType templateType,
    required void Function(NativeAd ad) onAdLoaded,
    required void Function(NativeAd ad, LoadAdError error) onAdFailedToLoad,
  }) async {
    // AdMobの初期化が完了していることを確認
    await AdService.ensureInitialized();

    final nativeAd = NativeAd(
      adUnitId: AdConfig.getNativeAdUnitId(),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: templateType,
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          final nativeAd = ad as NativeAd;
          onAdLoaded(nativeAd);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          final nativeAd = ad as NativeAd;
          onAdFailedToLoad(nativeAd, error);
        },
        onAdClicked: (_) {},
        onAdImpression: (_) {},
      ),
    );

    nativeAd.load();
    return nativeAd;
  }
}
