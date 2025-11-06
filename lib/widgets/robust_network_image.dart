import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// ネットワークエラーに強い画像ウィジェット
///
/// cached_network_imageを使用して自動的にキャッシュを管理
/// 分割ダウンロードではなく、確実な一括ダウンロード
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
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: maxWidth,
      memCacheHeight: maxHeight,
      httpHeaders: const {
        'Accept': 'image/webp,image/avif,image/*, */*;q=0.8',
        'User-Agent': 'Flutter-Spotlight/1.0',
      },
      placeholder: (context, url) => placeholder ?? Container(),
      errorWidget: (context, url, error) => errorWidget ?? placeholder ?? Container(),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
      maxWidthDiskCache: maxWidth,
      maxHeightDiskCache: maxHeight,
    );
  }
}
