import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// ネットワークエラーに強い画像ウィジェット
///
/// 動画と同じようにFlutterの最適化されたImage.networkを使用
/// プログレッシブJPEGやストリーミング読み込みをサポート
/// 大量コンテンツ対応のため、ディスプレイサイズに合わせて画像を最適化
class RobustNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? maxWidth;
  final int? maxHeight;

  const RobustNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.maxWidth,
    this.maxHeight,
  });

  @override
  State<RobustNetworkImage> createState() => _RobustNetworkImageState();
}

class _RobustNetworkImageState extends State<RobustNetworkImage> {
  ImageProvider? _imageProvider;
  int? _cacheWidth;
  int? _cacheHeight;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // initState()ではMediaQueryにアクセスできないため、デフォルト値を設定
    _cacheWidth = widget.maxWidth ?? 1080;
    _cacheHeight = widget.maxHeight ?? 1920;
    _createImageProvider();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies()でMediaQueryにアクセス可能
    if (!_hasInitialized) {
      _calculateCacheSize();
      _preloadImage();
      _hasInitialized = true;
    }
  }

  @override
  void didUpdateWidget(RobustNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.maxHeight != widget.maxHeight) {
      _calculateCacheSize();
      _createImageProvider();
      _preloadImage();
    }
  }

  /// ディスプレイサイズに基づいてキャッシュサイズを計算
  /// didChangeDependencies()またはbuild()から呼び出す（MediaQueryにアクセス可能な状態で）
  void _calculateCacheSize() {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final devicePixelRatio = mediaQuery.devicePixelRatio;

    // ディスプレイサイズの1.5倍（Retina対応）を上限として、指定された最大サイズを適用
    _cacheWidth = widget.maxWidth ??
        (screenSize.width * devicePixelRatio * 1.5).round().clamp(360, 2160);
    _cacheHeight = widget.maxHeight ??
        (screenSize.height * devicePixelRatio * 1.5).round().clamp(640, 3840);
  }

  /// 画像プロバイダーを作成
  void _createImageProvider() {
    _imageProvider = NetworkImage(
      widget.imageUrl,
      headers: {
        'Accept': 'image/webp,image/avif,image/*, */*;q=0.8', // WebP/AVIFを優先
        'User-Agent': 'Flutter-Spotlight/1.0',
      },
    );
  }

  /// 画像を事前読み込み（キャッシュに保存、最適化されたサイズで）
  Future<void> _preloadImage() async {
    if (_imageProvider == null) return;

    try {
      await precacheImage(
        _imageProvider!,
        context,
        size: _cacheWidth != null && _cacheHeight != null
            ? Size(_cacheWidth!.toDouble(), _cacheHeight!.toDouble())
            : null,
      );
      if (kDebugMode) {
        debugPrint(
            '✅ 画像キャッシュ完了: ${widget.imageUrl} (${_cacheWidth}x${_cacheHeight})');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 画像キャッシュエラー: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // FlutterのImage.networkを使用（動画と同じように最適化された読み込み）
    // プログレッシブJPEGやストリーミング読み込みを自動でサポート
    // cacheWidth/cacheHeightでメモリ使用量を最適化
    return Image.network(
      widget.imageUrl,
      fit: widget.fit,
      cacheWidth: _cacheWidth,
      cacheHeight: _cacheHeight,
      headers: {
        'Accept': 'image/webp,image/avif,image/*, */*;q=0.8', // WebP/AVIFを優先
        'User-Agent': 'Flutter-Spotlight/1.0',
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // 同期的に読み込まれた場合は即座に表示
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        // 読み込み中はプレースホルダーを表示
        return widget.placeholder ??
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
              ),
            );
      },
      loadingBuilder: (context, child, loadingProgress) {
        // 読み込み中はプレースホルダーを表示
        if (loadingProgress == null) {
          // 読み込み完了
          if (kDebugMode) {
            debugPrint('✅ 画像読み込み完了: ${widget.imageUrl}');
          }
          return child;
        }
        // 読み込み中はプレースホルダーを表示
        return widget.placeholder ??
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ 画像読み込みエラー: $error');
        }
        // エラー時もプレースホルダーを表示し続ける（エラーウィジェットは表示しない）
        return widget.placeholder ??
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
              ),
            );
      },
    );
  }
}
