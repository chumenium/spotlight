import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// ネットワークエラーに強い画像ウィジェット
///
/// 動画と同じシンプルなアプローチで実装
class RobustNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int maxRetries;
  final Duration timeout;
  final int maxSizeBytes; // 最大ファイルサイズ（バイト）

  const RobustNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.maxRetries = 3, // 動画と同じシンプルなリトライ回数
    this.timeout = const Duration(seconds: 30),
    this.maxSizeBytes = 10 * 1024 * 1024, // デフォルト10MB
  });

  @override
  State<RobustNetworkImage> createState() => _RobustNetworkImageState();
}

class _RobustNetworkImageState extends State<RobustNetworkImage> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(RobustNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      // URLが変更された場合は再読み込み
      _loadImage();
    }
  }

  /// 動画と同じシンプルなアプローチ: リトライ付きHTTPリクエスト
  Future<void> _loadImage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 動画と同じシンプルなリトライロジック
    for (int attempt = 0; attempt <= widget.maxRetries; attempt++) {
      if (!mounted) return;

      try {
        if (kDebugMode && attempt > 0) {
          debugPrint(
              '🔄 画像読み込みリトライ ${attempt}/${widget.maxRetries}: ${widget.imageUrl}');
        }

        final client = http.Client();
        try {
          final response = await client.get(
            Uri.parse(widget.imageUrl),
            headers: {
              'Accept': 'image/*, */*',
              'User-Agent': 'Flutter-Spotlight/1.0',
            },
          ).timeout(widget.timeout);

          client.close();

          if (response.statusCode == 200) {
            // サイズ制限チェック
            if (response.bodyBytes.length > widget.maxSizeBytes) {
              throw Exception(
                  '画像が大きすぎます: ${(response.bodyBytes.length / 1024 / 1024).toStringAsFixed(1)} MB (制限: ${(widget.maxSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB)');
            }

            if (!mounted) return;

            setState(() {
              _imageBytes = response.bodyBytes;
              _isLoading = false;
              _errorMessage = null;
            });

            if (kDebugMode) {
              debugPrint(
                  '✅ 画像読み込み成功: ${widget.imageUrl} (${response.bodyBytes.length} bytes)');
            }

            return;
          } else if (response.statusCode == 404) {
            // 404の場合はリトライしない
            if (kDebugMode) {
              debugPrint('❌ 画像が存在しません (404): ${widget.imageUrl}');
            }

            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _errorMessage = 'ファイルが見つかりません (404)';
            });
            return;
          } else {
            throw Exception('HTTPエラー: ${response.statusCode}');
          }
        } catch (e) {
          client.close();
          rethrow;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '❌ 画像読み込みエラー (試行${attempt + 1}/${widget.maxRetries + 1}): $e');
        }

        if (attempt == widget.maxRetries) {
          // 最後のリトライも失敗
          if (!mounted) return;

          final errorStr = e.toString();
          final is404Error = errorStr.contains('404') ||
              errorStr.contains('ファイルが見つかりません') ||
              errorStr.contains('存在しません');

          setState(() {
            _isLoading = false;
            _errorMessage = errorStr;
          });

          if (is404Error) {
            if (kDebugMode) {
              debugPrint('⛔ 404エラーのため、リトライを終了: ${widget.imageUrl}');
            }
          }
          return;
        }

        // 次のリトライまで待機（指数バックオフ）
        final delayMs = 500 * (attempt + 1); // 0.5秒、1秒、1.5秒...
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ??
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFF6B35),
            ),
          );
    }

    if (_errorMessage != null || _imageBytes == null) {
      return widget.errorWidget ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.white38, size: 64),
                const SizedBox(height: 16),
                const Text(
                  '画像を読み込めません',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // 手動で再試行
                    _loadImage();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('再試行'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                  ),
                ),
              ],
            ),
          );
    }

    return Image.memory(
      _imageBytes!,
      fit: widget.fit,
    );
  }
}
