import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// ネットワークエラーに強い画像ウィジェット
/// 
/// タイムアウト、リトライ、エラーハンドリングを実装
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
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 10),
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
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    for (int attempt = 0; attempt <= widget.maxRetries; attempt++) {
      if (!mounted) return;

      try {
        if (kDebugMode && attempt > 0) {
          debugPrint('🔄 画像読み込みリトライ ${attempt}/${widget.maxRetries}: ${widget.imageUrl}');
        }

        // HTTPクライアントを明示的に作成して設定
        final client = http.Client();
        http.Response response;
        
        try {
          final request = http.Request('GET', Uri.parse(widget.imageUrl))
            ..headers.addAll({
              'Cache-Control': 'max-age=3600',
              'Connection': 'keep-alive',
              'Accept': 'image/*',
              'Accept-Encoding': 'gzip, deflate',
            });
          
          final streamedResponse = await client.send(request).timeout(
            widget.timeout,
            onTimeout: () {
              throw Exception('タイムアウト: ${widget.timeout.inSeconds}秒');
            },
          );
          
          // ストリームからバイトデータを読み込み（チャンク単位）
          final contentLength = streamedResponse.contentLength;
          
          if (kDebugMode) {
            debugPrint('📊 画像サイズ: ${contentLength != null ? '${(contentLength / 1024).toStringAsFixed(0)} KB' : '不明'}');
          }
          
          // サイズ制限チェック
          if (contentLength != null && contentLength > widget.maxSizeBytes) {
            throw Exception('画像が大きすぎます: ${(contentLength / 1024 / 1024).toStringAsFixed(1)} MB (制限: ${(widget.maxSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB)');
          }
          
          // ストリームから少しずつデータを受信（接続切断対策）
          final List<int> bytes = [];
          int receivedBytes = 0;
          
          await for (final chunk in streamedResponse.stream) {
            bytes.addAll(chunk);
            receivedBytes += chunk.length;
            
            if (kDebugMode && receivedBytes % (100 * 1024) == 0) {
              // 100KBごとにログ出力
              debugPrint('📥 受信中: ${(receivedBytes / 1024).toStringAsFixed(0)} KB');
            }
          }
          
          if (kDebugMode) {
            debugPrint('✅ 受信完了: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(0)} KB)');
          }
          
          response = http.Response.bytes(Uint8List.fromList(bytes), streamedResponse.statusCode, 
              headers: streamedResponse.headers);
          
          client.close();
        } catch (e) {
          client.close();
          rethrow;
        }

        if (response.statusCode == 200) {
          if (!mounted) return;
          
          setState(() {
            _imageBytes = response.bodyBytes;
            _isLoading = false;
            _errorMessage = null;
          });
          
          if (kDebugMode) {
            debugPrint('✅ 画像読み込み成功: ${widget.imageUrl} (${response.bodyBytes.length} bytes)');
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
        if (kDebugMode) {
          debugPrint('❌ 画像読み込みエラー (試行${attempt + 1}/${widget.maxRetries + 1}): $e');
        }

        if (attempt == widget.maxRetries) {
          // 最後のリトライも失敗
          if (!mounted) return;
          
          setState(() {
            _isLoading = false;
            _errorMessage = e.toString();
          });
          return;
        }

        // 次のリトライまで待機（指数バックオフ）
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
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
                  onPressed: _loadImage,
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

