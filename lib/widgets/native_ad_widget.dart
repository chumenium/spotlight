import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/native_ad_manager.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// ネイティブ広告ウィジェット
/// 
/// Instagramのリール広告のような形式で、投稿と同じスタイルで表示される広告です。
/// スワイプでスキップ可能です。
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({
    super.key,
    required this.reloadToken,
  });

  final int reloadToken;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _hasError = false;
  String? _errorMessage;
  TemplateType? _currentTemplateType;
  bool _isLoadingAd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadNativeAd(_selectTemplateType(MediaQuery.of(context).size));
      }
    });
  }

  @override
  void didUpdateWidget(covariant NativeAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken && !_isLoadingAd) {
      _loadNativeAd(_selectTemplateType(MediaQuery.of(context).size));
    }
  }

  /// ネイティブ広告を読み込む
  void _loadNativeAd(TemplateType templateType) async {
    if (_isLoadingAd) {
      return;
    }
    _isLoadingAd = true;
    _currentTemplateType = templateType;
    _nativeAd?.dispose();
    if (mounted) {
      setState(() {
        _isAdLoaded = false;
        _hasError = false;
      });
    }
    try {
      _nativeAd = await NativeAdManager.instance.loadNativeAd(
        templateType: templateType,
        onAdLoaded: (NativeAd ad) {
          if (mounted) {
            setState(() {
              _nativeAd = ad;
              _isAdLoaded = true;
              _hasError = false;
            });
          }
        },
        onAdFailedToLoad: (NativeAd ad, LoadAdError error) {
          if (kDebugMode) {
            debugPrint('❌ ネイティブ広告の読み込み失敗: $error');
            debugPrint('   エラーコード: ${error.code}');
            debugPrint('   エラーメッセージ: ${error.message}');
            debugPrint('   エラードメイン: ${error.domain}');
            debugPrint('   広告ユニットID: ${ad.adUnitId}');
          }
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _hasError = true;
              _errorMessage = '広告の読み込みに失敗しました\n(${error.code}: ${error.message})';
            });
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ネイティブ広告の読み込み例外: $e');
      }
      if (mounted) {
        setState(() {
          _isAdLoaded = false;
          _hasError = true;
          _errorMessage = '広告の読み込みに失敗しました';
        });
      }
    } finally {
      _isLoadingAd = false;
    }
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom + 12;
    final templateType = _selectTemplateType(screenSize);
    if (_currentTemplateType != templateType && !_isLoadingAd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadNativeAd(templateType);
        }
      });
    }
    
    if (_hasError) {
      // エラー時の表示
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    
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

    // 投稿と完全に同じStack構造：全画面コンテンツ + 下部Positionedオーバーレイ
    return Container(
      color: Colors.black,
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        children: [
          // 広告本体：通常投稿と同じように画面中央付近に配置
          // AdWidgetは上から描画するため、サイズを絞ってCenterで中央寄せ
          Center(
            child: SizedBox(
              width: screenSize.width * 0.94,
              height: screenSize.height * 0.65,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AdWidget(ad: _nativeAd!),
              ),
            ),
          ),
          // 下部オーバーレイ：home_screen.dartの_buildBottomControlsと同一構造
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildAdBottomControls(bottomPadding),
          ),
        ],
      ),
    );
  }

  TemplateType _selectTemplateType(Size screenSize) {
    const mediumSize = Size(300, 250);
    final canUseMedium = screenSize.width >= mediumSize.width &&
        screenSize.height >= mediumSize.height;
    return canUseMedium ? TemplateType.medium : TemplateType.small;
  }

  Size _templateSizeFor(TemplateType templateType) {
    switch (templateType) {
      case TemplateType.small:
        return const Size(320, 100);
      case TemplateType.medium:
      default:
        return const Size(300, 250);
    }
  }

  /// 下部コントロール - home_screen.dart の _buildBottomControls と同一構造
  Widget _buildAdBottomControls(double bottomPadding) {
    return AnimatedPadding(
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
              return Row(
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
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '広告',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'スポンサー広告',
                          style: TextStyle(
                            color: Colors.grey[100],
                            fontSize: isWide ? 16 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
