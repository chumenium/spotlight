import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// ネットワークエラーに強い画像ウィジェット
///
/// CachedNetworkImageを使用して確実にキャッシュ
class RobustNetworkImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // CachedNetworkImageを使用して、キャッシュから読み込む
    // 同じURLの場合は再取得されない

    if (kDebugMode) {
      debugPrint('🖼️ RobustNetworkImage: 画像読み込み開始: $imageUrl');
    }

    return SizedBox.expand(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        key: ValueKey(imageUrl), // 同じURLの場合は再構築を防ぐ
        fit: fit,
        memCacheWidth: maxWidth,
        memCacheHeight: maxHeight,
        httpHeaders: const {
          'Accept': 'image/webp,image/avif,image/*,*/*;q=0.8',
          'User-Agent': 'Flutter-Spotlight/1.0',
        },
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) {
          if (kDebugMode) {
            debugPrint('⏳ 画像読み込み中: $url');
          }
          return placeholder ??
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF6B35),
                ),
              );
        },
        errorWidget: (context, url, error) {
          if (kDebugMode) {
            debugPrint('❌ 画像読み込みエラー: $error');
            debugPrint('   URL: $imageUrl');
            debugPrint('   エラーURL: $url');
          }

          return errorWidget ??
              placeholder ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      color: Colors.white38,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '画像の読み込みに失敗',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              );
        },
      ),
    );
  }
}
