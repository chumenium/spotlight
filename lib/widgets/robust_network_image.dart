import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// ネットワークエラーに強い画像ウィジェット
///
/// シンプルなImage.networkで確実に表示
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
    if (kDebugMode) {
      debugPrint('🖼️ 画像読み込み開始: $imageUrl');
    }

    return Image.network(
      imageUrl,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          if (kDebugMode) {
            debugPrint('✅ 画像読み込み完了: $imageUrl');
          }
          return child;
        }
        
        final progress = loadingProgress.expectedTotalBytes != null
            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
            : null;
        
        if (kDebugMode && progress != null) {
          debugPrint('📊 画像読み込み中: ${(progress * 100).toStringAsFixed(0)}% - $imageUrl');
        }
        
        return placeholder ??
            Center(
              child: CircularProgressIndicator(
                value: progress,
                color: const Color(0xFFFF6B35),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ 画像読み込みエラー: $error');
          debugPrint('   URL: $imageUrl');
          debugPrint('   StackTrace: $stackTrace');
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
                  Text(
                    '画像の読み込みに失敗',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    imageUrl,
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
      },
      cacheWidth: maxWidth,
      cacheHeight: maxHeight,
    );
  }
}
