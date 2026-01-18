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
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom + 12;
    final screenSize = MediaQuery.of(context).size;
    
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

    // Instagramのような全画面広告を表示
    // 投稿と同じスタイルで、下部に「広告」ラベルを表示
    return Container(
      color: Colors.black,
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        children: [
          // 広告コンテンツ（画面の中心に配置）
          Positioned.fill(
            child: Center(
              child: AdWidget(ad: _nativeAd!),
            ),
          ),
          
          // 下部コントロール（広告ラベル）
          Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: bottomPadding,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                        child: SafeArea(
                      top: false,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 420;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: isWide ? 22 : 18,
                                    backgroundColor: const Color(0xFFFF6B35),
                                    child: const Icon(
                                      Icons.ads_click,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '広告',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'スポンサー広告',
                                          style: TextStyle(
                                            color: Colors.grey[100],
                                            fontSize: isWide ? 16 : 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
