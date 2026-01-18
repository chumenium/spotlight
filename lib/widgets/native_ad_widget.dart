import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/native_ad_manager.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// ネイティブ広告ウィジェット
/// 
/// Instagramのリール広告のような形式で、投稿と同じスタイルで表示される広告です。
/// スワイプでスキップ可能です。
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  /// ネイティブ広告を読み込む
  void _loadNativeAd() {
    _nativeAd = NativeAdManager.instance.loadNativeAd(
      onAdLoaded: (NativeAd ad) {
        if (mounted) {
          setState(() {
            _nativeAd = ad;
            _isAdLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (NativeAd ad, LoadAdError error) {
        if (kDebugMode) {
          debugPrint('❌ ネイティブ広告の読み込み失敗: $error');
        }
        ad.dispose();
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _nativeAd == null) {
      // 広告が読み込まれるまでのプレースホルダー
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF6B35),
          ),
        ),
      );
    }

    // ネイティブ広告を表示
    // AdMobのネイティブ広告テンプレートを使用
    // フルスクリーンで表示し、スワイプでスキップ可能
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}
