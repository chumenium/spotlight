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
    // 既に読み込み成功したURLの場合は、最小限のチェックのみでCachedNetworkImageを返す
    // これにより、読み込み成功したURLに対するチェック処理の実行頻度を大幅に削減
    if (_loadedUrls.containsKey(imageUrl)) {
      // 読み込み成功したURLは、キャッシュから読み込まれることが確定しているため、
      // 失敗チェックや読み込み中チェックをスキップして、直接CachedNetworkImageを返す
      return CachedNetworkImage(
        imageUrl: imageUrl,
        key: ValueKey(imageUrl),
        cacheKey: imageUrl,
        fit: fit,
        // アスペクト比を保持するために、maxWidthのみを指定
        // maxHeightを指定しないことで、画像の元のアスペクト比が保持される
        memCacheWidth: maxWidth,
        // maxHeightは指定しない（アスペクト比を保持）
        maxHeightDiskCache:
            maxHeight != null ? ((maxHeight! * 2).round()) : 2000,
        maxWidthDiskCache: maxWidth != null ? ((maxWidth! * 2).round()) : 2000,
        httpHeaders: const {
          'Accept': 'image/webp,image/avif,image/*,*/*;q=0.8',
          'User-Agent': 'Flutter-Spotlight/1.0',
        },
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: const Duration(milliseconds: 50),
        // 読み込み成功したURLの場合は、placeholderとprogressIndicatorBuilderを指定しない
        // （キャッシュから即座に読み込まれるため）
        placeholder: null, // 明示的にnullを設定
        progressIndicatorBuilder: null, // 明示的にnullを設定
        errorWidget: errorWidget != null
            ? (context, url, error) => errorWidget!
            : (context, url, error) {
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

    // CachedNetworkImageを使用して、キャッシュから読み込む
    // 同じURLの場合は再取得されない
    // maxCacheAgeを1時間に設定して、AWS使用量を削減
    // キャッシュから読み込まれた場合は、placeholderが表示されずに即座に画像が表示される
    // そのため、次のフレームで読み込み成功を記録する
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // キャッシュから読み込まれた場合、placeholderが表示されないため、
      // 次のフレームで読み込み成功を記録する
      Future.delayed(const Duration(milliseconds: 50), () {
        // まだ記録されていない場合のみ記録
        if (!_loadedUrls.containsKey(imageUrl)) {
          _recordLoadedUrl(imageUrl);
        }
      });
    });

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
      // placeholderとprogressIndicatorBuilderは同時に指定できないため、
      // placeholderを明示的にnullに設定し、progressIndicatorBuilderのみを使用する
      placeholder: null, // 明示的にnullを設定（progressIndicatorBuilderと競合しないように）
      progressIndicatorBuilder: (context, url, downloadProgress) {
        // 読み込みが完了した場合（progress == 1.0）に読み込み成功を記録
        if (downloadProgress.progress == 1.0) {
          // 読み込み完了を即座に記録（同期的に実行）
          _recordLoadedUrl(imageUrl);
          if (_shouldLog(imageUrl)) {
            debugPrint('✅ RobustNetworkImage: 画像読み込み完了: $imageUrl');
          }
        }
        // プログレスインジケーターを表示（読み込み中の場合）
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
