import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// ネットワークエラーに強い画像ウィジェット
///
/// CachedNetworkImageを使用して確実にキャッシュ
/// 404エラーが発生した場合は1時間リトライしない（AWS使用量削減）
class RobustNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? maxWidth;
  final int? maxHeight;

  // 404エラーが発生したURLとタイムスタンプを記録（1時間に1回の読み込み制限）
  static final Map<String, DateTime> _failedUrls = {};

  // 読み込み中のURLとタイムスタンプを記録（1時間に1回の読み込み制限）
  static final Map<String, DateTime> _loadingUrls = {};

  // 読み込み成功したURLとタイムスタンプを記録（1時間に1回の読み込み制限）
  static final Map<String, DateTime> _loadedUrls = {};

  // ログ出力を制限するためのマップ（URL -> 最後にログを出力した時刻）
  static final Map<String, DateTime> _lastLogTime = {};

  const RobustNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.maxWidth,
    this.maxHeight,
  });

  /// 404エラーが発生したURLかチェック（1時間以内の場合はtrue）
  static bool _isFailedUrl(String url) {
    if (!_failedUrls.containsKey(url)) {
      return false;
    }
    final failedTime = _failedUrls[url]!;
    final now = DateTime.now();
    final difference = now.difference(failedTime);
    // 1時間以上経過した場合は、リトライを許可
    if (difference.inHours >= 1) {
      _failedUrls.remove(url);
      return false;
    }
    return true;
  }

  /// 404エラーを記録
  static void _recordFailedUrl(String url) {
    _failedUrls[url] = DateTime.now();
    _loadingUrls.remove(url); // 読み込み中から削除
    if (kDebugMode) {
      debugPrint('📝 404エラーを記録: $url (1時間以内はリトライしない)');
    }
  }

  /// 読み込み成功を記録（1時間に1回の読み込み制限）
  static void _recordLoadedUrl(String url) {
    _loadedUrls[url] = DateTime.now();
    _loadingUrls.remove(url); // 読み込み中から削除

    // 古い読み込み成功記録をクリア（1時間以上経過したもの）
    final now = DateTime.now();
    _loadedUrls.removeWhere((key, value) {
      final difference = now.difference(value);
      return difference.inHours >= 1;
    });
  }

  /// 外部から読み込み成功を記録するための公開メソッド
  /// プリロードなどで画像が読み込まれた場合に使用
  static void recordLoadedUrl(String url) {
    _recordLoadedUrl(url);
  }

  /// ログを出力するかチェック（同じURLの場合は一定時間内は出力しない）
  static bool _shouldLog(String url,
      {Duration minInterval = const Duration(seconds: 30)}) {
    if (!kDebugMode) return false;

    if (!_lastLogTime.containsKey(url)) {
      _lastLogTime[url] = DateTime.now();
      return true;
    }

    final lastLogTime = _lastLogTime[url]!;
    final now = DateTime.now();
    final difference = now.difference(lastLogTime);

    if (difference >= minInterval) {
      _lastLogTime[url] = now;
      return true;
    }

    return false;
  }

  /// 読み込み開始を記録
  static void _recordLoadingStart(String url) {
    _loadingUrls[url] = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    // NOTE:
    // 以前は _loadedUrls を見て「成功済みURLはplaceholder/progressなしで即返す」最適化をしていましたが、
    // キャッシュが効かない/ネットワークが遅い状況だと “何も描画されない” フレームが発生し、
    // HomeScreen側の背景色だけが見えて「完全な黒(暗転)」になり得ます。
    // そのため、常に progressIndicatorBuilder を通して placeholder を出せる経路に統一します。

    // 404エラーが発生したURLの場合は、エラーウィジェットを表示（1時間に1回の読み込み制限）
    if (_isFailedUrl(imageUrl)) {
      if (_shouldLog(imageUrl)) {
        debugPrint('⏭️ RobustNetworkImage: 404エラーが記録されているためスキップ: $imageUrl');
      }
      if (errorWidget != null) return errorWidget!;
      if (placeholder != null) return placeholder!;
      return const SizedBox(
        width: 80,
        height: 80,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image,
                color: Colors.white38,
                size: 48,
              ),
              SizedBox(height: 8),
              Text(
                '画像の読み込みに失敗',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // 読み込み中のURLチェックを削除
    // CachedNetworkImageは内部的にキャッシュを管理しており、
    // キャッシュから読み込まれた場合は即座に表示される
    // _isLoadingチェックを削除することで、キャッシュから読み込まれた画像が
    // 即座に表示されるようになる

    // 新規読み込み開始の場合のみ、読み込み開始を記録
    // ただし、既に読み込み成功している場合は記録しない
    if (!_loadedUrls.containsKey(imageUrl)) {
      _recordLoadingStart(imageUrl);
    }

    if (_shouldLog(imageUrl)) {
      debugPrint('🖼️ RobustNetworkImage: 画像読み込み開始: $imageUrl');
    }

    // NOTE:
    // Web(Chrome)では progressIndicatorBuilder が呼ばれない/進捗が取れないケースがあり、
    // その場合 placeholder が一切出ずに「何も描画されないフレーム」になって
    // 画面が真っ黒(暗転)に見えることがありました。
    // そのため、placeholder は必ず表示する設計にし、成功判定は imageBuilder
    // （実際に画像が描画できたタイミング）で記録します。

    return CachedNetworkImage(
      imageUrl: imageUrl,
      key: ValueKey(imageUrl), // 同じURLの場合は再構築を防ぐ
      cacheKey: imageUrl, // キャッシュキーを明示的に設定（同じURLの場合はキャッシュから読み込む）
      fit: fit,
      // アスペクト比を保持するために、maxWidthのみを指定
      // maxHeightを指定しないことで、画像の元のアスペクト比が保持される
      memCacheWidth: maxWidth,
      // maxHeightは指定しない（アスペクト比を保持）
      maxHeightDiskCache: maxHeight != null
          ? ((maxHeight! * 2).round())
          : 2000, // ディスクキャッシュの最大高さ（2倍に拡大）
      maxWidthDiskCache: maxWidth != null
          ? ((maxWidth! * 2).round())
          : 2000, // ディスクキャッシュの最大幅（2倍に拡大）
      httpHeaders: const {
        'Accept': 'image/webp,image/avif,image/*,*/*;q=0.8',
        'User-Agent': 'Flutter-Spotlight/1.0',
      },
      fadeInDuration: const Duration(milliseconds: 150), // フェードイン時間を短縮
      fadeOutDuration: const Duration(milliseconds: 50), // フェードアウト時間を短縮
      // 【重要】必ずローディングUIを表示する（Webでprogressが取れない場合でも暗転させない）
      placeholder: (context, url) {
        if (placeholder != null) return placeholder!;
        return const SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFF6B35),
              strokeWidth: 3,
            ),
          ),
        );
      },
      // 実際に画像が描画できる状態になったタイミングで成功扱いを記録
      imageBuilder: (context, imageProvider) {
        if (!_loadedUrls.containsKey(imageUrl)) {
          _recordLoadedUrl(imageUrl);
          if (_shouldLog(imageUrl)) {
            debugPrint('✅ RobustNetworkImage: 画像読み込み完了: $imageUrl');
          }
        }
        return Image(image: imageProvider, fit: fit);
      },
      errorWidget: (context, url, error) {
        // 読み込み中から削除
        _loadingUrls.remove(url);

        final errorString = error.toString();

        // 404エラーの場合は記録（1時間に1回の読み込み制限）
        if (errorString.contains('404') || errorString.contains('Not Found')) {
          _recordFailedUrl(url);
          if (_shouldLog(url)) {
            debugPrint('❌ 画像読み込み404エラー: $error');
            debugPrint('   URL: $imageUrl');
            debugPrint('   エラーURL: $url');
            debugPrint('   1時間以内はリトライしません（AWS使用量削減）');
          }
        }
        // デコードエラーの場合も記録（破損した画像の再試行を防ぐ）
        else if (errorString.contains('EncodingError') ||
            errorString.contains('cannot be decoded') ||
            errorString.contains('decode')) {
          _recordFailedUrl(url);
          if (_shouldLog(url)) {
            debugPrint('❌ 画像デコードエラー: $error');
            debugPrint('   URL: $imageUrl');
            debugPrint('   エラーURL: $url');
            debugPrint('   画像ファイルが破損している可能性があります');
            debugPrint('   1時間以内はリトライしません');
          }
        } else {
          if (_shouldLog(url)) {
            debugPrint('❌ 画像読み込みエラー: $error');
            debugPrint('   URL: $imageUrl');
            debugPrint('   エラーURL: $url');
          }
        }

        if (errorWidget != null) return errorWidget!;
        if (placeholder != null) return placeholder!;
        return const SizedBox(
          width: 80,
          height: 80,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image,
                  color: Colors.white38,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  '画像の読み込みに失敗',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
