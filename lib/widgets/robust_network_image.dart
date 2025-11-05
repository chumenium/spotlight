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
    this.maxRetries = 5, // 接続切断エラー対策のためリトライ回数を増加
    this.timeout = const Duration(seconds: 30), // タイムアウト時間を延長
    this.maxSizeBytes = 10 * 1024 * 1024, // デフォルト10MB
  });

  @override
  State<RobustNetworkImage> createState() => _RobustNetworkImageState();
}

class _RobustNetworkImageState extends State<RobustNetworkImage> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasFailed = false;
  int _backgroundRetryCount = 0;
  static const int _maxBackgroundRetries = 10; // バックグラウンドリトライの最大回数
  DateTime? _lastRetryTime;

  // チャンク単位の読み込み用
  List<Uint8List> _receivedChunks = []; // 受信済みチャンク
  int _totalReceivedBytes = 0; // 受信済み総バイト数
  int? _expectedTotalBytes; // 期待される総バイト数
  bool _supportsRangeRequests = true; // Range Requestサポートフラグ

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(RobustNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      // URLが変更された場合はリセットして再読み込み
      _hasFailed = false;
      _backgroundRetryCount = 0;
      _receivedChunks.clear();
      _totalReceivedBytes = 0;
      _expectedTotalBytes = null;
      _supportsRangeRequests = true;
      _loadImage();
    } else if (_hasFailed && _imageBytes == null) {
      // 同じURLで失敗していた場合、自動的に再試行
      _scheduleBackgroundRetry();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ウィジェットが表示されたときに、失敗していた場合は即座に再試行
    if (_hasFailed &&
        _imageBytes == null &&
        _backgroundRetryCount < _maxBackgroundRetries) {
      final now = DateTime.now();
      // 最後の試行から3秒以上経過していたら即座に再試行（バックグラウンドリトライを待たない）
      if (_lastRetryTime == null ||
          now.difference(_lastRetryTime!).inSeconds >= 3) {
        if (kDebugMode) {
          debugPrint('👁️ ウィジェットが表示されたため、即座に再試行: ${widget.imageUrl}');
        }
        _loadImage();
      }
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // チャンク単位で読み込みを試みる（接続切断時は続きから再開）
      await _loadImageInChunks();
    } catch (e) {
      final errorStr = e.toString();
      final is404Error =
          errorStr.contains('404') || errorStr.contains('ファイルが見つかりません');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = errorStr;
        _hasFailed = true;
      });

      // 404エラー以外の場合はバックグラウンドで自動的に再試行をスケジュール
      if (!is404Error) {
        _scheduleBackgroundRetry();
      } else {
        if (kDebugMode) {
          debugPrint('⛔ 404エラーのため、バックグラウンドリトライをスキップ: ${widget.imageUrl}');
        }
      }
    }
  }

  /// チャンク単位で画像を読み込み、すべてのデータが揃うまで再試行
  Future<void> _loadImageInChunks() async {
    if (!mounted) return;

    int chunkAttempts = 0;
    const maxChunkAttempts = 100; // 最大チャンク読み込み試行回数（無限ループ防止）

    // 最初のリクエストまたは続きから読み込み
    while (_totalReceivedBytes < (_expectedTotalBytes ?? widget.maxSizeBytes)) {
      if (!mounted) return;

      // 無限ループ防止
      if (chunkAttempts >= maxChunkAttempts) {
        if (kDebugMode) {
          debugPrint('⛔ 最大チャンク読み込み試行回数に達しました: $maxChunkAttempts回');
        }
        break;
      }

      chunkAttempts++;

      try {
        final chunkData = await _loadChunk();
        if (chunkData == null) {
          // チャンク読み込み失敗（416など）、次の試行へ
          await Future.delayed(const Duration(milliseconds: 500));

          // 416の場合は既にすべて受信済みの可能性がある
          if (_expectedTotalBytes != null &&
              _totalReceivedBytes >= _expectedTotalBytes!) {
            _combineChunks();
            return;
          }
          continue;
        }

        // チャンクを追加
        _receivedChunks.add(chunkData);
        _totalReceivedBytes += chunkData.length;

        if (kDebugMode) {
          final progress = _expectedTotalBytes != null
              ? '${((_totalReceivedBytes / _expectedTotalBytes!) * 100).toStringAsFixed(1)}%'
              : '不明';
          debugPrint(
              '📦 チャンク受信: ${(chunkData.length / 1024).toStringAsFixed(0)} KB (累計: ${(_totalReceivedBytes / 1024).toStringAsFixed(0)} KB / ${_expectedTotalBytes != null ? '${(_expectedTotalBytes! / 1024).toStringAsFixed(0)} KB' : '不明'} - $progress) [試行$chunkAttempts]');
        }

        // すべてのデータが揃ったかチェック
        if (_expectedTotalBytes != null &&
            _totalReceivedBytes >= _expectedTotalBytes!) {
          // すべてのチャンクを結合
          _combineChunks();
          return;
        }

        // データが揃っていない場合は続きを読み込む（短い待機後に再試行）
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '❌ チャンク読み込みエラー: $e (累計受信: ${(_totalReceivedBytes / 1024).toStringAsFixed(0)} KB) [試行$chunkAttempts]');
        }

        // 接続エラーの場合は短い待機後に再試行
        final isConnectionError = e.toString().contains('Connection closed') ||
            e.toString().contains('closed while receiving') ||
            e.toString().contains('接続が切断') ||
            e.toString().contains('ClientException');

        if (isConnectionError && _totalReceivedBytes > 0) {
          // 部分データがある場合は続きから再試行
          await Future.delayed(const Duration(milliseconds: 300));
          continue;
        } else if (isConnectionError && _totalReceivedBytes == 0) {
          // データが全くない場合は少し長めに待機
          await Future.delayed(const Duration(milliseconds: 1000));
          continue;
        } else {
          // 404エラーなどは再スロー
          final is404Error = e.toString().contains('404') ||
              e.toString().contains('ファイルが見つかりません');
          if (is404Error) {
            rethrow;
          }
          // その他のエラーは続行を試みる（最大試行回数まで）
          if (chunkAttempts < maxChunkAttempts) {
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          } else {
            rethrow;
          }
        }
      }
    }

    // すべてのデータが揃わなかった場合
    if (_totalReceivedBytes > 0) {
      // 部分データでも結合して表示を試みる
      if (kDebugMode) {
        debugPrint(
            '⚠️ 部分データのみ受信: ${(_totalReceivedBytes / 1024).toStringAsFixed(0)} KB (期待: ${_expectedTotalBytes != null ? '${(_expectedTotalBytes! / 1024).toStringAsFixed(0)} KB' : '不明'})');
      }
      _combineChunks();
    } else {
      throw Exception('画像データが受信できませんでした');
    }
  }

  /// 単一のチャンクを読み込む（Range Requestを使用して続きから読み込む）
  Future<Uint8List?> _loadChunk() async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(widget.imageUrl));

      // ヘッダー設定
      final headers = {
        'Cache-Control': 'max-age=3600',
        'Connection': 'keep-alive',
        'Accept': 'image/*, */*',
        'User-Agent': 'Flutter-Spotlight/1.0',
      };

      // Range Requestを使用（既にデータがある場合）
      if (_supportsRangeRequests && _totalReceivedBytes > 0) {
        headers['Range'] = 'bytes=$_totalReceivedBytes-';
        if (kDebugMode) {
          debugPrint('📡 Range Request: bytes=$_totalReceivedBytes-');
        }
      }

      request.headers.addAll(headers);

      final requestTimeout = Duration(seconds: widget.timeout.inSeconds + 10);
      final streamedResponse = await client.send(request).timeout(
        requestTimeout,
        onTimeout: () {
          throw Exception('リクエストタイムアウト: ${requestTimeout.inSeconds}秒');
        },
      );

      // ステータスコードチェック
      if (streamedResponse.statusCode == 206) {
        // 206 Partial Content - Range Request成功
        _supportsRangeRequests = true;
      } else if (streamedResponse.statusCode == 200) {
        // 200 OK - Range Request非対応、全体を返す
        if (_totalReceivedBytes > 0) {
          // 既にデータがある場合はRange Request非対応として扱う
          _supportsRangeRequests = false;
          if (kDebugMode) {
            debugPrint('⚠️ Range Request非対応サーバー: 全体を再取得');
          }
          // 既存のチャンクをクリアして最初から
          _receivedChunks.clear();
          _totalReceivedBytes = 0;
          // 期待される総バイト数もリセット（新しい全体データを受信するため）
          _expectedTotalBytes = null;
        }
      } else if (streamedResponse.statusCode == 416) {
        // 416 Range Not Satisfiable - 既にすべてのデータを受信済み
        if (kDebugMode) {
          debugPrint('✅ すべてのデータを受信済み (416)');
        }
        client.close();
        return null;
      } else if (streamedResponse.statusCode == 404) {
        throw Exception('ファイルが見つかりません (404)');
      } else {
        throw Exception('HTTPエラー: ${streamedResponse.statusCode}');
      }

      // 期待される総バイト数を取得
      if (_expectedTotalBytes == null) {
        final contentRange = streamedResponse.headers['content-range'];
        if (contentRange != null) {
          // Content-Range: bytes 0-1023/2048 の形式から総バイト数を取得
          final match = RegExp(r'/(\d+)').firstMatch(contentRange);
          if (match != null) {
            _expectedTotalBytes = int.parse(match.group(1)!);
            if (kDebugMode) {
              debugPrint(
                  '📊 総画像サイズ: ${(_expectedTotalBytes! / 1024).toStringAsFixed(0)} KB');
            }
          }
        } else if (streamedResponse.statusCode == 200) {
          // 200の場合はContent-Lengthから取得
          _expectedTotalBytes = streamedResponse.contentLength;
        }
      }

      // サイズ制限チェック
      if (_expectedTotalBytes != null &&
          _expectedTotalBytes! > widget.maxSizeBytes) {
        throw Exception(
            '画像が大きすぎます: ${(_expectedTotalBytes! / 1024 / 1024).toStringAsFixed(1)} MB (制限: ${(widget.maxSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB)');
      }

      // ストリームからデータを受信
      final List<int> chunkBytes = [];
      int chunkReceivedBytes = 0;

      try {
        await for (final chunk in streamedResponse.stream.timeout(
          widget.timeout,
          onTimeout: (sink) {
            throw Exception('ストリーム受信タイムアウト: ${widget.timeout.inSeconds}秒');
          },
        )) {
          if (!mounted) {
            client.close();
            return null;
          }

          chunkBytes.addAll(chunk);
          chunkReceivedBytes += chunk.length;

          // サイズ制限チェック
          if (_totalReceivedBytes + chunkReceivedBytes > widget.maxSizeBytes) {
            throw Exception(
                '画像が大きすぎます: ${((_totalReceivedBytes + chunkReceivedBytes) / 1024 / 1024).toStringAsFixed(1)} MB');
          }
        }
      } catch (streamError) {
        client.close();
        // ストリームエラーは再スローして、呼び出し元で処理
        rethrow;
      }

      client.close();

      if (chunkBytes.isEmpty) {
        return null;
      }

      return Uint8List.fromList(chunkBytes);
    } catch (e) {
      client.close();
      rethrow;
    }
  }

  /// すべてのチャンクを結合して完全な画像データを作成
  void _combineChunks() {
    if (_receivedChunks.isEmpty) {
      throw Exception('結合するチャンクがありません');
    }

    if (kDebugMode) {
      debugPrint(
          '🔗 チャンク結合中: ${_receivedChunks.length}個のチャンク、合計 ${(_totalReceivedBytes / 1024).toStringAsFixed(0)} KB');
    }

    // すべてのチャンクを結合
    final combined = Uint8List(_totalReceivedBytes);
    int offset = 0;
    for (final chunk in _receivedChunks) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    if (!mounted) return;

    setState(() {
      _imageBytes = combined;
      _isLoading = false;
      _errorMessage = null;
      _hasFailed = false;
      _backgroundRetryCount = 0;
    });

    if (kDebugMode) {
      debugPrint(
          '✅ 画像読み込み成功: ${widget.imageUrl} (${combined.length} bytes, ${_receivedChunks.length}チャンク)');
    }

    // チャンクデータをクリア（メモリ節約）
    _receivedChunks.clear();
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
                    // 手動で再試行する場合は、すべての状態をリセット
                    _backgroundRetryCount = 0;
                    _hasFailed = false;
                    _receivedChunks.clear();
                    _totalReceivedBytes = 0;
                    _expectedTotalBytes = null;
                    _supportsRangeRequests = true;
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

  /// バックグラウンドで自動的に再試行をスケジュール
  void _scheduleBackgroundRetry() {
    if (_backgroundRetryCount >= _maxBackgroundRetries) {
      if (kDebugMode) {
        debugPrint('⛔ バックグラウンドリトライの最大回数に達しました: ${widget.imageUrl}');
      }
      return;
    }

    _backgroundRetryCount++;
    _lastRetryTime = DateTime.now();

    // 指数バックオフで再試行（1回目: 3秒、2回目: 6秒、3回目: 12秒...）
    final delaySeconds =
        3 * (1 << (_backgroundRetryCount - 1).clamp(0, 5)); // 最大96秒
    final delay = Duration(seconds: delaySeconds);

    if (kDebugMode) {
      debugPrint(
          '⏰ バックグラウンドリトライをスケジュール: ${widget.imageUrl} (${delaySeconds}秒後, 試行${_backgroundRetryCount}/${_maxBackgroundRetries})');
    }

    Future.delayed(delay, () {
      if (!mounted) return;

      // まだ失敗している状態で、画像が読み込まれていない場合のみ再試行
      if (_hasFailed && _imageBytes == null) {
        if (kDebugMode) {
          debugPrint('🔄 バックグラウンドリトライ開始: ${widget.imageUrl}');
        }
        _loadImage();
      }
    });
  }
}
