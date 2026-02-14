import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
/// バナー広告ウィジェット
/// 
/// iOS/Android両方で動作するバナー広告を表示します。
/// 
/// 使用例:
/// ```dart
/// BannerAdWidget(
///   adSize: AdSize.banner,
/// )
/// ```
class BannerAdWidget extends StatefulWidget {
  /// 広告サイズ
  final AdSize adSize;

  /// 広告の配置（オプション）
  final Alignment? alignment;

  const BannerAdWidget({
    super.key,
    this.adSize = AdSize.banner,
    this.alignment,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  /// バナー広告を読み込む
  void _loadBannerAd() {
    _bannerAd = AdService.instance.loadBannerAd(
      adSize: widget.adSize,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
        onAdOpened: (_) {},
        onAdClosed: (_) {},
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      // 広告が読み込まれるまでのプレースホルダー（オプション）
      return const SizedBox.shrink();
    }

    final adWidget = AdWidget(ad: _bannerAd!);

    // 広告サイズに合わせてContainerでラップ
    return Container(
      alignment: widget.alignment ?? Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: adWidget,
    );
  }
}
