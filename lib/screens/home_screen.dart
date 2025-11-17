import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/icon_update_service.dart';
import '../config/app_config.dart';
import '../utils/spotlight_colors.dart';
import '../widgets/robust_network_image.dart';
import '../providers/navigation_provider.dart';
import '../services/comment_service.dart';
import '../services/playlist_service.dart';
import '../models/comment.dart';

/// 音声背景用のカスタムペインター
class _AudioBackgroundPainter extends CustomPainter {
  final bool isPlaying;

  _AudioBackgroundPainter({required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // 波紋エフェクト
    if (isPlaying) {
      final center = Offset(size.width / 2, size.height / 2);
      for (int i = 0; i < 3; i++) {
        paint.color =
            SpotLightColors.getSpotlightColor(2).withOpacity(0.1 - (i * 0.03));
        canvas.drawCircle(
          center,
          size.width * 0.3 + (i * 30),
          paint,
        );
      }
    }

    // グラデーション円
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 1.5,
        colors: [
          SpotLightColors.getSpotlightColor(2).withOpacity(0.2),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 遅延読み込み関連
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  static const int _initialLoadCount = 3; // 初回読み込み件数
  static const int _preloadAheadCount = 3; // 現在のページから先読み込みする件数

  // ジェスチャー関連
  double _swipeOffset = 0.0;
  bool _isSpotlighting = false;
  AnimationController? _ambientAnimationController;
  Animation<double>? _ambientOpacityAnimation;

  // 動画プレイヤー関連
  final Map<int, VideoPlayerController?> _videoControllers = {};
  int? _currentPlayingVideo;
  final Set<int> _initializedVideos = {};

  // シークバー関連（動画用）
  bool _isSeeking = false;
  double? _seekPosition; // シーク中の位置（0.0-1.0）
  Timer? _seekBarUpdateTimer; // シークバー更新用タイマー
  Timer? _seekDebounceTimer; // シーク中のデバウンスタイマー

  // シークバー関連（音声用）
  bool _isSeekingAudio = false;
  double? _seekPositionAudio; // シーク中の位置（0.0-1.0）
  Timer? _seekBarUpdateTimerAudio; // シークバー更新用タイマー
  Timer? _seekDebounceTimerAudio; // シーク中のデバウンスタイマー

  // 音声プレイヤー関連
  final Map<int, AudioPlayer?> _audioPlayers = {};
  int? _currentPlayingAudio;
  final Set<int> _initializedAudios = {};

  // アイコンキャッシュ管理（username -> 更新タイムスタンプ）
  final Map<String, int> _iconCacheKeys = {};

  // アイコン更新イベントのリスナー
  StreamSubscription<IconUpdateEvent>? _iconUpdateSubscription;

  // リアルタイム更新用
  Timer? _updateTimer;
  bool _isUpdating = false;
  static const Duration _updateInterval =
      Duration(seconds: 30); // 30秒ごとに更新（頻度を下げる）
  final Set<String> _fetchedContentIds = {}; // 取得済みのコンテンツID

  // ウィジェットの破棄状態を管理
  bool _isDisposed = false;
  String? _lastTargetPostId; // 最後に処理したターゲット投稿ID

  // 初回起動時のリトライ管理
  int _initialRetryCount = 0;
  static const int _maxInitialRetries = 5; // 最大リトライ回数（初回ログイン後も確実に読み込むため増加）

  @override
  void initState() {
    super.initState();
    // ステータスバーを非表示にする
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // アニメーションコントローラー初期化
    _ambientAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // アニメーション設定
    _ambientOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _ambientAnimationController!,
      curve: Curves.easeInOut,
    ));

    // ライフサイクル監視を追加
    WidgetsBinding.instance.addObserver(this);

    // アイコン更新イベントをリッスン
    _iconUpdateSubscription =
        IconUpdateService().onIconUpdate.listen(_onIconUpdated);

    // バックエンドから投稿を取得
    _fetchPosts();

    // リアルタイム更新を開始
    _startAutoUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // NavigationProviderのtargetPostIdをチェック
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);
    final targetPostId = navigationProvider.targetPostId;

    if (kDebugMode) {
      debugPrint(
          '🔄 didChangeDependencies: targetPostId=$targetPostId, _lastTargetPostId=$_lastTargetPostId, _isLoading=$_isLoading, _posts.length=${_posts.length}');
    }

    // ターゲット投稿IDが変更された場合、かつ投稿リストが読み込まれている場合
    if (targetPostId != null &&
        targetPostId != _lastTargetPostId &&
        !_isLoading) {
      if (kDebugMode) {
        debugPrint('✅ ターゲット投稿IDが変更されました: $targetPostId');
      }

      _lastTargetPostId = targetPostId;

      // 投稿リストが空の場合は、投稿を取得してからジャンプ
      if (_posts.isEmpty) {
        if (kDebugMode) {
          debugPrint('📝 投稿リストが空なので、先に投稿を取得します');
        }
        _fetchPosts().then((_) {
          if (!_isDisposed && mounted) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (!_isDisposed && mounted) {
                _checkAndJumpToTargetPost();
              }
            });
          }
        });
      } else {
        // 少し遅延させてからジャンプ（画面遷移が完了してから）
        if (kDebugMode) {
          debugPrint('⏳ 投稿リストがあるので、遅延後にジャンプします');
        }
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!_isDisposed && mounted) {
            _checkAndJumpToTargetPost();
          }
        });
      }
    }
  }

  /// バックエンドから投稿を取得（初回読み込み）
  Future<void> _fetchPosts() async {
    try {
      if (kDebugMode) {
        debugPrint('📝 投稿取得を開始（初回: $_initialLoadCount件、startId=1）...');
        if (_initialRetryCount > 0) {
          debugPrint('🔄 リトライ試行: $_initialRetryCount回目');
        }
      }

      // 初回読み込みは必ずID=1から開始
      final posts =
          await PostService.fetchPosts(limit: _initialLoadCount, startId: 1);

      if (!_isDisposed && mounted) {
        // 投稿が空の場合でも、初回起動時は自動リトライを続ける
        if (posts.isEmpty && _initialRetryCount < _maxInitialRetries) {
          _initialRetryCount++;
          final retryDelay =
              Duration(seconds: _initialRetryCount); // 1秒、2秒、3秒と段階的に増やす

          if (kDebugMode) {
            debugPrint(
                '📝 投稿が空です。${retryDelay.inSeconds}秒後に自動リトライします（$_initialRetryCount/$_maxInitialRetries）');
          }

          // リトライ前にローディング状態を維持
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });

          // 遅延後に自動リトライ
          Future.delayed(retryDelay, () {
            if (!_isDisposed && mounted) {
              _fetchPosts();
            }
          });
          return; // リトライするのでここで終了
        }

        // 投稿が取得できた、またはリトライ回数が上限に達した場合
        setState(() {
          _posts = posts;
          _isLoading = false;
          // 投稿が空で、リトライ回数が上限に達した場合のみ「投稿がありません」と表示
          _errorMessage = posts.isEmpty ? '投稿がありません' : null;
          _initialRetryCount = 0; // 成功したらリトライカウントをリセット

          // 読み込んだ件数が要求した件数より少ない場合は、これ以上投稿がない
          _hasMorePosts = posts.length >= _initialLoadCount;

          // 取得済みコンテンツIDを記録
          _fetchedContentIds.clear();
          for (final post in posts) {
            _fetchedContentIds.add(post.id);
            if (kDebugMode) {
              debugPrint('📝 取得済みIDを記録: ${post.id}');
            }
          }
        });

        // 投稿が取得できたら初期表示時に現在のページがメディアの場合は自動再生を開始
        if (_posts.isNotEmpty) {
          _handleMediaPageChange(_currentIndex);

          // 初回読み込み後、現在のページから3つ先までを事前読み込み
          _preloadNextPosts(_currentIndex);

          // ターゲット投稿IDが設定されている場合はジャンプ
          final navigationProvider =
              Provider.of<NavigationProvider>(context, listen: false);
          final targetPostId = navigationProvider.targetPostId;
          if (targetPostId != null) {
            if (kDebugMode) {
              debugPrint('🎯 投稿取得完了後、targetPostIdをチェック: $targetPostId');
            }
            // 少し遅延させてからジャンプ（画面構築が完了してから）
            Future.delayed(const Duration(milliseconds: 200), () {
              if (!_isDisposed && mounted) {
                _checkAndJumpToTargetPost();
              }
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 投稿取得エラー: $e');
      }

      // 初回起動時の自動リトライ（最大3回まで）
      if (_initialRetryCount < _maxInitialRetries && !_isDisposed && mounted) {
        _initialRetryCount++;
        final retryDelay =
            Duration(seconds: _initialRetryCount); // 1秒、2秒、3秒と段階的に増やす

        if (kDebugMode) {
          debugPrint(
              '🔄 ${retryDelay.inSeconds}秒後に自動リトライします（$_initialRetryCount/$_maxInitialRetries）');
        }

        // リトライ前にローディング状態を維持
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        // 遅延後に自動リトライ
        Future.delayed(retryDelay, () {
          if (!_isDisposed && mounted) {
            _fetchPosts();
          }
        });
      } else {
        // リトライ回数が上限に達した場合、エラーメッセージを表示
        if (!_isDisposed && mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '投稿の取得に失敗しました';
            _initialRetryCount = 0; // リトライカウントをリセット
          });
        }
      }
    }
  }

  /// ターゲット投稿IDをチェックしてジャンプ
  Future<void> _checkAndJumpToTargetPost() async {
    if (!mounted) return;

    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);
    final targetPostId = navigationProvider.targetPostId;

    if (targetPostId == null) return;

    // 既に処理中の場合はスキップ（同じIDの処理が完了するまで待つ）
    if (_lastTargetPostId == targetPostId) {
      if (kDebugMode) {
        debugPrint('⏭️ 既に処理中のターゲット投稿ID: $targetPostId');
      }
      return;
    }

    // 処理開始前に_lastTargetPostIdを設定（重複実行を防ぐ）
    _lastTargetPostId = targetPostId;

    if (kDebugMode) {
      debugPrint('🎯 ターゲット投稿ID: $targetPostId');
    }

    // 現在の投稿リストから探す（文字列として比較）
    final index = _posts
        .indexWhere((post) => post.id.toString() == targetPostId.toString());

    if (kDebugMode) {
      debugPrint(
          '🔍 投稿検索: targetPostId=$targetPostId, 現在の投稿数=${_posts.length}');
      for (int i = 0; i < _posts.length; i++) {
        debugPrint(
            '  [$i] ID=${_posts[i].id} (type: ${_posts[i].id.runtimeType})');
      }
    }

    if (index >= 0) {
      // 見つかった場合でも、完全なデータを再取得して更新する
      // 検索結果から作成された不完全な投稿の可能性があるため
      if (kDebugMode) {
        debugPrint('✅ 投稿が見つかりました: インデックス $index, 投稿ID=${_posts[index].id}');
        debugPrint('  - 既存の投稿のcontentPath: ${_posts[index].contentPath}');
        debugPrint('  - 既存の投稿のmediaUrl: ${_posts[index].mediaUrl}');
      }

      // 完全なデータを再取得
      final updatedPost = await PostService.fetchPostDetail(targetPostId);
      final expectedTitle = navigationProvider.targetPostTitle;

      // 検索結果のタイトルと取得した投稿のタイトルを比較
      if (updatedPost != null &&
          updatedPost.id.toString() == targetPostId.toString()) {
        // タイトルが一致しない場合は、タイトルで検索して正しい投稿を見つける
        if (expectedTitle != null &&
            expectedTitle.isNotEmpty &&
            updatedPost.title != expectedTitle) {
          if (kDebugMode) {
            debugPrint('⚠️ タイトルが一致しません:');
            debugPrint('  - 検索結果のタイトル: $expectedTitle');
            debugPrint('  - 取得した投稿のタイトル: ${updatedPost.title}');
            debugPrint('  - タイトルで検索して正しい投稿を見つけます...');
          }

          // タイトルで検索して正しい投稿を見つける
          final titleMatchIndex = _posts.indexWhere((post) =>
              post.title == expectedTitle &&
              post.id.toString() != targetPostId.toString());

          if (titleMatchIndex >= 0) {
            if (kDebugMode) {
              debugPrint(
                  '✅ タイトルで一致する投稿を見つけました: インデックス $titleMatchIndex, 投稿ID=${_posts[titleMatchIndex].id}');
            }

            // 正しい投稿にジャンプ
            if (_pageController.hasClients) {
              await _pageController.animateToPage(
                titleMatchIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );

              if (kDebugMode) {
                debugPrint('✅ タイトルで一致する投稿にジャンプ完了: インデックス $titleMatchIndex');
              }
            }

            // ターゲット投稿IDをクリア
            navigationProvider.clearTargetPostId();
            _lastTargetPostId = null;
            return;
          } else {
            if (kDebugMode) {
              debugPrint('⚠️ タイトルで一致する投稿が見つかりませんでした');
            }
          }
        }

        if (kDebugMode) {
          debugPrint('✅ 投稿データを更新:');
          debugPrint('  - 更新後のcontentPath: ${updatedPost.contentPath}');
          debugPrint('  - 更新後のmediaUrl: ${updatedPost.mediaUrl}');
          debugPrint('  - 更新後のtype: ${updatedPost.type}');
          debugPrint('  - 更新後のtitle: ${updatedPost.title}');
          if (expectedTitle != null) {
            debugPrint('  - 検索結果のタイトル: $expectedTitle');
            debugPrint('  - タイトル一致: ${updatedPost.title == expectedTitle}');
          }
        }

        // 投稿リスト内の投稿を更新
        // 既存のメディアコントローラーをクリア（新しいメディアを初期化するため）
        final postIndex = index;
        if (_videoControllers.containsKey(postIndex)) {
          final oldController = _videoControllers[postIndex];
          if (oldController != null) {
            await oldController.dispose();
            _videoControllers.remove(postIndex);
            _initializedVideos.remove(postIndex);
            if (kDebugMode) {
              debugPrint('🗑️ 既存の動画コントローラーをクリア: インデックス $postIndex');
            }
          }
        }
        if (_audioPlayers.containsKey(postIndex)) {
          final oldPlayer = _audioPlayers[postIndex];
          if (oldPlayer != null) {
            await oldPlayer.dispose();
            _audioPlayers.remove(postIndex);
            _initializedAudios.remove(postIndex);
            if (kDebugMode) {
              debugPrint('🗑️ 既存の音声プレイヤーをクリア: インデックス $postIndex');
            }
          }
        }

        setState(() {
          _posts[index] = updatedPost;
        });

        // 投稿データを更新した後、再度インデックスを確認
        // setStateの後なので、確実に更新されているはず
        final verifiedIndex = _posts.indexWhere(
            (post) => post.id.toString() == targetPostId.toString());
        if (verifiedIndex >= 0 && verifiedIndex != index) {
          if (kDebugMode) {
            debugPrint('⚠️ インデックスが変更されました: $index -> $verifiedIndex');
          }
          // インデックスが変更された場合は、新しいインデックスを使用
          final actualIndex = verifiedIndex;

          // PageControllerでジャンプ
          if (_pageController.hasClients) {
            await _pageController.animateToPage(
              actualIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );

            if (kDebugMode) {
              debugPrint(
                  '✅ ジャンプ完了: インデックス $actualIndex, 現在の投稿ID=${_posts[actualIndex].id}');
              debugPrint('  - タイトル: ${_posts[actualIndex].title}');
              debugPrint('  - 投稿者: ${_posts[actualIndex].username}');
              debugPrint('  - タイプ: ${_posts[actualIndex].type}');
            }
          }
        } else {
          // インデックスが変更されていない場合
          if (kDebugMode) {
            debugPrint('🔄 投稿データを更新しました: インデックス $index');
            debugPrint('  - タイトル: ${_posts[index].title}');
            debugPrint('  - 投稿者: ${_posts[index].username}');
            debugPrint('  - タイプ: ${_posts[index].type}');
            debugPrint('  - animateToPageのonPageChangedでメディアが初期化されます');
          }

          // PageControllerでジャンプ
          if (_pageController.hasClients) {
            await _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );

            if (kDebugMode) {
              debugPrint(
                  '✅ ジャンプ完了: インデックス $index, 現在の投稿ID=${_posts[index].id}');
            }
          }
        }
      } else {
        // 投稿データの取得に失敗した場合でも、既存の投稿にジャンプ
        if (kDebugMode) {
          debugPrint('⚠️ 投稿データの取得に失敗しましたが、既存の投稿にジャンプします');
        }

        // PageControllerでジャンプ
        if (_pageController.hasClients) {
          await _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );

          if (kDebugMode) {
            debugPrint('✅ ジャンプ完了: インデックス $index, 現在の投稿ID=${_posts[index].id}');
          }
        }
      }

      // ターゲット投稿IDをクリア
      navigationProvider.clearTargetPostId();
      _lastTargetPostId = null;
    } else {
      // 見つからなかった場合は、その投稿を取得して追加
      if (kDebugMode) {
        debugPrint('🔍 投稿が見つかりません。取得を試みます...');
      }

      final expectedTitle = navigationProvider.targetPostTitle;
      final success =
          await _fetchAndJumpToPost(targetPostId, expectedTitle: expectedTitle);

      // 処理完了後、ターゲット投稿IDをクリア
      if (mounted) {
        if (!success) {
          // 投稿取得に失敗した場合、タイトルで検索を試みる
          if (expectedTitle != null && expectedTitle.isNotEmpty) {
            if (kDebugMode) {
              debugPrint('🔍 タイトルで検索を試みます: $expectedTitle');
            }

            final titleMatchIndex =
                _posts.indexWhere((post) => post.title == expectedTitle);
            if (titleMatchIndex >= 0) {
              if (kDebugMode) {
                debugPrint(
                    '✅ タイトルで一致する投稿を見つけました: インデックス $titleMatchIndex, 投稿ID=${_posts[titleMatchIndex].id}');
              }

              if (_pageController.hasClients) {
                await _pageController.animateToPage(
                  titleMatchIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            } else {
              if (kDebugMode) {
                debugPrint('❌ タイトルで一致する投稿が見つかりませんでした');
              }
            }
          }
        }

        navigationProvider.clearTargetPostId();
        _lastTargetPostId = null;
      }
    }
  }

  /// 特定の投稿を取得してジャンプ
  Future<bool> _fetchAndJumpToPost(String postId,
      {String? expectedTitle}) async {
    try {
      // 投稿IDから数値に変換
      final contentId = int.tryParse(postId);
      if (contentId == null) {
        if (kDebugMode) {
          debugPrint('❌ 無効な投稿ID: $postId');
        }
        return false;
      }

      // その投稿を直接取得（PostService.fetchPostDetailを使用）
      final post = await PostService.fetchPostDetail(postId);

      if (kDebugMode) {
        if (post != null) {
          debugPrint('🔍 投稿取得結果: 成功');
          debugPrint('  - 取得した投稿ID: ${post.id} (type: ${post.id.runtimeType})');
          debugPrint('  - 期待する投稿ID: $postId (type: ${postId.runtimeType})');
          debugPrint('  - title: ${post.title}');
          debugPrint('  - type: ${post.type}');
          debugPrint('  - contentPath: ${post.contentPath}');
          debugPrint('  - mediaUrl: ${post.mediaUrl}');
          debugPrint('  - thumbnailUrl: ${post.thumbnailUrl}');
          debugPrint('  - username: ${post.username}');
        } else {
          debugPrint('🔍 投稿取得結果: 失敗（投稿が見つかりません）');
        }
      }

      if (post != null && post.id.toString() == postId.toString()) {
        final targetPost = post;

        if (!_isDisposed && mounted) {
          // 投稿リストに追加（既に存在する場合はスキップ）
          final existingIndex = _posts
              .indexWhere((post) => post.id.toString() == postId.toString());

          if (existingIndex < 0) {
            // 新しい投稿なので、適切な位置に挿入
            // IDが現在の投稿より小さい場合は先頭に、大きい場合は末尾に追加
            final currentFirstId =
                _posts.isNotEmpty ? int.tryParse(_posts.first.id) : null;
            final targetId = int.tryParse(postId) ?? 0;

            setState(() {
              if (currentFirstId != null && targetId < currentFirstId) {
                _posts.insert(0, targetPost);
              } else {
                _posts.add(targetPost);
              }

              // 取得済みコンテンツIDを記録
              _fetchedContentIds.add(postId);
            });

            // 投稿を追加した後、そのインデックスにジャンプ
            // setStateの完了を待ってからジャンプ
            await Future.delayed(const Duration(milliseconds: 50));

            final newIndex = _posts
                .indexWhere((post) => post.id.toString() == postId.toString());
            if (newIndex >= 0 && _pageController.hasClients) {
              if (kDebugMode) {
                debugPrint(
                    '✅ 投稿を追加しました: インデックス $newIndex, 投稿ID=${_posts[newIndex].id}');
              }

              // animateToPageはonPageChangedを自動的に呼び出す
              await _pageController.animateToPage(
                newIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );

              // animateToPageの完了を待ってから、念のためインデックスを確認
              if (mounted) {
                // 再度インデックスを確認（setStateの後なので確実に更新されているはず）
                final finalIndex = _posts.indexWhere(
                    (post) => post.id.toString() == postId.toString());
                if (finalIndex >= 0) {
                  if (_currentIndex != finalIndex) {
                    setState(() {
                      _currentIndex = finalIndex;
                    });
                    _handleMediaPageChange(finalIndex);
                  }

                  if (kDebugMode) {
                    debugPrint(
                        '✅ ジャンプ完了: インデックス $finalIndex, 現在の投稿ID=${_posts[finalIndex].id}');
                  }

                  // ターゲット投稿IDをクリア
                  final navigationProvider =
                      Provider.of<NavigationProvider>(context, listen: false);
                  navigationProvider.clearTargetPostId();
                  _lastTargetPostId = null;

                  return true; // 成功
                } else {
                  if (kDebugMode) {
                    debugPrint('❌ 投稿を追加したが見つかりません: postId=$postId');
                  }
                  return false; // 失敗
                }
              }
            } else {
              if (kDebugMode) {
                debugPrint('❌ 投稿を追加したが見つかりません: postId=$postId');
              }
              return false; // 失敗
            }
          } else {
            // 既に存在する場合はそのインデックスにジャンプ
            if (_pageController.hasClients) {
              if (kDebugMode) {
                debugPrint(
                    '✅ 既存の投稿にジャンプ: インデックス $existingIndex, 投稿ID=${_posts[existingIndex].id}');
              }

              // animateToPageはonPageChangedを自動的に呼び出す
              await _pageController.animateToPage(
                existingIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );

              // animateToPageの完了を待ってから、念のためインデックスを確認
              if (mounted) {
                if (_currentIndex != existingIndex) {
                  setState(() {
                    _currentIndex = existingIndex;
                  });
                  _handleMediaPageChange(existingIndex);
                }

                if (kDebugMode) {
                  debugPrint(
                      '✅ ジャンプ完了: インデックス $existingIndex, 現在の投稿ID=${_posts[existingIndex].id}');
                }

                // ターゲット投稿IDをクリア
                final navigationProvider =
                    Provider.of<NavigationProvider>(context, listen: false);
                navigationProvider.clearTargetPostId();
                _lastTargetPostId = null;

                return true; // 成功
              }
            }
            return true; // 成功（既存の投稿にジャンプ）
          }
        }
        return false; // 失敗（投稿が見つからない）
      } else {
        if (kDebugMode) {
          debugPrint('❌ 投稿の取得に失敗しました: $postId');
        }
        return false; // 失敗
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 投稿取得エラー: $e');
      }
      return false; // 失敗
    }
  }

  /// 現在のページから3つ先までを事前読み込み
  Future<void> _preloadNextPosts(int currentIndex) async {
    if (_isLoadingMore || !_hasMorePosts || _posts.isEmpty) return;

    // 現在のページから3つ先まで既に読み込まれているかチェック
    final targetIndex = currentIndex + _preloadAheadCount;
    if (targetIndex < _posts.length) {
      // 既に読み込まれている場合はスキップ
      if (kDebugMode) {
        debugPrint(
            '⏭️ 既に読み込み済み: 現在のインデックス=$currentIndex, 目標インデックス=$targetIndex, 現在の投稿数=${_posts.length}');
      }
      return;
    }

    // 必要な投稿数を計算
    final neededCount = targetIndex - _posts.length + 1;
    if (neededCount <= 0) return;

    _isLoadingMore = true;

    try {
      // 最後の投稿のIDから次のIDを計算
      final lastPost = _posts.last;
      final lastId = int.tryParse(lastPost.id) ?? 0;
      final nextStartId = lastId + 1;

      if (kDebugMode) {
        debugPrint(
            '📝 事前読み込み開始: 現在のインデックス=$currentIndex, 最後の投稿ID=$lastId, startId=$nextStartId, 必要件数=$neededCount');
        debugPrint('📝 取得済みID: ${_fetchedContentIds.toList()}');
      }

      // 必要な件数分を読み込む（常に3件読み込む）
      final loadCount = _preloadAheadCount;

      // 次のIDから追加読み込み
      final morePosts = await PostService.fetchPosts(
        limit: loadCount,
        startId: nextStartId,
      );

      if (!_isDisposed && mounted && morePosts.isNotEmpty) {
        // 重複を防ぐために、既に取得済みの投稿を除外
        final newPosts = morePosts
            .where((post) => !_fetchedContentIds.contains(post.id))
            .toList();

        if (kDebugMode) {
          debugPrint(
              '📝 取得した投稿: ${morePosts.length}件、重複除外後: ${newPosts.length}件');
          for (final post in newPosts) {
            debugPrint('  - ID: ${post.id}, タイトル: ${post.title}');
          }
        }

        if (newPosts.isNotEmpty) {
          setState(() {
            _posts.addAll(newPosts);

            // 取得済みコンテンツIDを記録
            for (final post in newPosts) {
              _fetchedContentIds.add(post.id);
            }

            // 読み込んだ件数が要求した件数より少ない場合は、これ以上投稿がない
            _hasMorePosts = newPosts.length >= loadCount;
          });

          if (kDebugMode) {
            debugPrint(
                '📝 事前読み込み完了: ${newPosts.length}件（合計: ${_posts.length}件）');
          }
        } else {
          // 全て重複していた場合は、次のIDから再試行
          if (kDebugMode) {
            debugPrint('📝 全て重複していたため、次のIDから再試行');
          }
          setState(() {
            _hasMorePosts = true; // 再試行のためtrueに設定
          });
        }
      } else {
        setState(() {
          _hasMorePosts = false;
        });

        if (kDebugMode) {
          debugPrint('📝 これ以上投稿がありません');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 事前読み込みエラー: $e');
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  /// 手動で投稿を更新（プルリフレッシュ）
  Future<void> _refreshPosts() async {
    if (_isUpdating) return;

    _isUpdating = true;

    // 手動再試行の場合はリトライカウントをリセット
    _initialRetryCount = 0;

    try {
      // 初回読み込みと同じ件数を取得
      final posts = await PostService.fetchPosts(limit: _initialLoadCount);

      if (!_isDisposed && mounted && posts.isNotEmpty) {
        setState(() {
          _posts = posts;
          _errorMessage = null;
          _hasMorePosts = posts.length >= _initialLoadCount;
          _initialRetryCount = 0; // リトライカウントをリセット

          // 取得済みコンテンツIDを更新
          _fetchedContentIds.clear();
          for (final post in posts) {
            _fetchedContentIds.add(post.id);
          }
        });

        // 現在のページがメディアの場合は自動再生を開始
        if (_posts.isNotEmpty && _currentIndex < _posts.length) {
          _handleMediaPageChange(_currentIndex);
        }
      }
    } catch (e) {
      // エラーは無視（ログも出力しない）
    } finally {
      _isUpdating = false;
    }
  }

  /// アイコン更新イベントを受信したときの処理
  void _onIconUpdated(IconUpdateEvent event) async {
    if (!mounted) return;

    if (kDebugMode) {
      debugPrint(
          '🔔 アイコン更新を検知: ${event.username} -> ${event.iconPath ?? "default"}');
    }

    // 古いアイコンURLをキャッシュから削除
    for (int i = 0; i < _posts.length; i++) {
      if (_posts[i].username == event.username &&
          _posts[i].userIconUrl != null) {
        try {
          final oldUrl = _posts[i].userIconUrl!;
          // cached_network_imageのキャッシュをクリア
          await CachedNetworkImage.evictFromCache(oldUrl);

          if (kDebugMode) {
            debugPrint('🗑️ 古いアイコンをキャッシュから削除: $oldUrl');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ キャッシュ削除エラー: $e');
          }
        }
      }
    }

    // アイコンキャッシュキーを更新（タイムスタンプを変更してウィジェットを再構築）
    setState(() {
      _iconCacheKeys[event.username] = DateTime.now().millisecondsSinceEpoch;

      // 投稿リスト内のアイコンURLを更新
      for (int i = 0; i < _posts.length; i++) {
        if (_posts[i].username == event.username) {
          // アイコンが削除された場合はdefault_icon.jpgに変更
          final newIconPath = event.iconPath ?? 'default_icon.jpg';
          final newIconUrl = '${AppConfig.backendUrl}/icon/$newIconPath';

          if (kDebugMode) {
            debugPrint('🔄 アイコンURL更新: ${_posts[i].username} -> $newIconUrl');
          }

          _posts[i] = Post(
            id: _posts[i].id,
            userId: _posts[i].userId,
            username: _posts[i].username,
            userIconPath: newIconPath,
            userIconUrl: newIconUrl,
            title: _posts[i].title,
            content: _posts[i].content,
            contentPath: _posts[i].contentPath,
            type: _posts[i].type,
            mediaUrl: _posts[i].mediaUrl,
            thumbnailUrl: _posts[i].thumbnailUrl,
            likes: _posts[i].likes,
            playNum: _posts[i].playNum,
            link: _posts[i].link,
            comments: _posts[i].comments,
            shares: _posts[i].shares,
            isSpotlighted: _posts[i].isSpotlighted,
            isText: _posts[i].isText,
            nextContentId: _posts[i].nextContentId,
            createdAt: _posts[i].createdAt,
          );
        }
      }
    });
  }

  /// リアルタイム更新を開始
  void _startAutoUpdate() {
    _updateTimer = Timer.periodic(_updateInterval, (timer) {
      if (!_isDisposed && mounted) {
        _updatePostsInBackground();
      }
    });
  }

  /// バックグラウンドで投稿を更新（新規投稿のチェックのみ）
  Future<void> _updatePostsInBackground() async {
    if (_isUpdating || _isLoading) return;

    _isUpdating = true;

    try {
      // 最初の1件だけ取得して新規投稿をチェック
      final posts = await PostService.fetchPosts(limit: 1);

      if (!_isDisposed && mounted && posts.isNotEmpty) {
        final newPost = posts.first;

        // 既に取得済みのコンテンツIDかチェック
        if (!_fetchedContentIds.contains(newPost.id)) {
          // 新規投稿を先頭に追加
          setState(() {
            _posts.insert(0, newPost);
            _fetchedContentIds.add(newPost.id);
          });
        }
      }
    } catch (e) {
      // エラーは無視（ログも出力しない）
    } finally {
      _isUpdating = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    // リアルタイム更新を停止
    _updateTimer?.cancel();
    _seekBarUpdateTimer?.cancel();
    _seekDebounceTimer?.cancel();
    _seekBarUpdateTimerAudio?.cancel();
    _seekDebounceTimerAudio?.cancel();

    // アイコン更新イベントのリスナーを解除
    _iconUpdateSubscription?.cancel();

    // ライフサイクル監視を解除
    WidgetsBinding.instance.removeObserver(this);

    _pageController.dispose();
    _ambientAnimationController?.dispose();

    // 動画プレイヤーのリソース解放
    for (final controller in _videoControllers.values) {
      controller?.dispose();
    }
    _videoControllers.clear();
    _initializedVideos.clear();

    // 音声プレイヤーのリソース解放
    for (final player in _audioPlayers.values) {
      player?.dispose();
    }
    _audioPlayers.clear();
    _initializedAudios.clear();

    // ステータスバーを表示に戻す
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // アプリがバックグラウンドに行った時は音声/動画を一時停止
        if (_currentPlayingVideo != null) {
          final controller = _videoControllers[_currentPlayingVideo];
          if (controller != null && controller.value.isInitialized) {
            controller.pause();
          }
        }
        if (_currentPlayingAudio != null) {
          final player = _audioPlayers[_currentPlayingAudio];
          if (player != null) {
            player.pause();
          }
        }
        // リアルタイム更新を停止
        _updateTimer?.cancel();
        break;
      case AppLifecycleState.resumed:
        // アプリがフォアグラウンドに戻った時は再生
        if (_posts.isNotEmpty &&
            _currentIndex < _posts.length &&
            _posts[_currentIndex].postType == PostType.video &&
            _currentPlayingVideo != null) {
          final controller = _videoControllers[_currentPlayingVideo];
          if (controller != null && controller.value.isInitialized) {
            controller.play();
          }
        }
        if (_posts.isNotEmpty &&
            _currentIndex < _posts.length &&
            _posts[_currentIndex].postType == PostType.audio &&
            _currentPlayingAudio != null) {
          final player = _audioPlayers[_currentPlayingAudio];
          if (player != null) {
            player.play();
          }
        }
        // リアルタイム更新を再開
        _startAutoUpdate();
        // 即座に更新を実行
        _updatePostsInBackground();
        break;
      case AppLifecycleState.hidden:
        // 何もしない
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // NavigationProviderのtargetPostIdを監視
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, child) {
        // targetPostIdが変更された場合、ジャンプ処理を実行
        final targetPostId = navigationProvider.targetPostId;
        if (targetPostId != null &&
            targetPostId != _lastTargetPostId &&
            !_isLoading &&
            mounted) {
          if (kDebugMode) {
            debugPrint('🔄 build内でターゲット投稿IDを検出: $targetPostId');
          }

          // 次のフレームで実行（build中にsetStateを呼ばないように）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && targetPostId == navigationProvider.targetPostId) {
              // _checkAndJumpToTargetPost内で_lastTargetPostIdを設定するため、ここでは設定しない
              _checkAndJumpToTargetPost();
            }
          });
        }

        return _buildScaffold(context);
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
              ),
            )
          : _errorMessage != null
              ? RefreshIndicator(
                  onRefresh: _refreshPosts,
                  color: const Color(0xFFFF6B35),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white70,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                // 手動再試行の場合はリトライカウントをリセット
                                _initialRetryCount = 0;
                                _fetchPosts();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B35),
                              ),
                              child: const Text('再試行'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : _posts.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _refreshPosts,
                      color: const Color(0xFFFF6B35),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.post_add,
                                  size: 64,
                                  color: Colors.white38,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '投稿がありません',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '引き下げて更新',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onPanUpdate: _handlePanUpdate,
                      onPanEnd: _handlePanEnd,
                      child: Stack(
                        children: [
                          // メイン投稿表示（不透明な背景で完全に覆う）
                          Positioned.fill(
                            child: Transform.translate(
                              offset:
                                  Offset(_swipeOffset * 0.3, 0), // スワイプに応じてズレ
                              child: Transform.rotate(
                                angle: _swipeOffset * 0.001, // スワイプに応じて左下を中心に回転
                                alignment: Alignment.bottomLeft, // 左下を中心に回転
                                child: Container(
                                  color: Colors.black, // 不透明な背景を追加
                                  child: PageView.builder(
                                    controller: _pageController,
                                    scrollDirection: Axis.vertical, // 縦スクロール
                                    // 大量コンテンツ対応：ビューポート範囲を制限
                                    allowImplicitScrolling: false,
                                    onPageChanged: (index) {
                                      if (kDebugMode) {
                                        debugPrint(
                                            '📄 onPageChanged: インデックス $index, 投稿数=${_posts.length}');
                                        if (index < _posts.length) {
                                          debugPrint(
                                              '  - 投稿ID: ${_posts[index].id}');
                                          debugPrint(
                                              '  - タイトル: ${_posts[index].title}');
                                          debugPrint(
                                              '  - 投稿者: ${_posts[index].username}');
                                          debugPrint(
                                              '  - タイプ: ${_posts[index].type}');
                                        }
                                      }

                                      setState(() {
                                        _currentIndex = index;
                                        _resetSpotlightState();
                                        _handleMediaPageChange(index);
                                      });

                                      // 現在のページから3つ先までを事前読み込み
                                      _preloadNextPosts(index);
                                    },
                                    itemCount: _hasMorePosts
                                        ? _posts.length + 1
                                        : _posts.length,
                                    itemBuilder: (context, index) {
                                      // 最後の項目はローディングインジケーター
                                      if (index >= _posts.length) {
                                        return Container(
                                          color: Colors.black,
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Color(0xFFFF6B35),
                                            ),
                                          ),
                                        );
                                      }
                                      return _buildPostContent(_posts[index]);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // スポットライトアンビエントライティング（投稿の上に表示）
                          if (_isSpotlighting &&
                              _ambientOpacityAnimation != null)
                            AnimatedBuilder(
                              animation: _ambientOpacityAnimation!,
                              builder: (context, child) {
                                return Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: Alignment.center,
                                        radius: 1.5,
                                        colors: [
                                          SpotLightColors.getSpotlightColor(0)
                                              .withOpacity(0.3 *
                                                  _ambientOpacityAnimation!
                                                      .value),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                          // 下部の投稿者情報とコントロール
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _buildBottomControls(_posts[_currentIndex]),
                          ),

                          // 右下のコントロールボタン
                          Positioned(
                            bottom: 120,
                            right: 20,
                            child: _buildRightBottomControls(
                                _posts[_currentIndex]),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildPostContent(Post post) {
    switch (post.postType) {
      case PostType.video:
        return _buildVideoContent(post);
      case PostType.image:
        return _buildImageContent(post);
      case PostType.text:
        return _buildTextContent(post);
      case PostType.audio:
        return _buildAudioContent(post);
    }
  }

  Widget _buildVideoContent(Post post) {
    final postIndex = _posts.indexOf(post);
    final controller = _videoControllers[postIndex];

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // 動画プレイヤー
          if (controller != null && controller.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            )
          else
            // 動画初期化中またはサムネイル表示
            Center(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.grey[900],
                child: Stack(
                  children: [
                    // サムネイル画像
                    if (post.thumbnailUrl != null &&
                        post.thumbnailUrl!.isNotEmpty)
                      Center(
                        child: Image.network(
                          post.thumbnailUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            if (kDebugMode) {
                              debugPrint(
                                  '❌ サムネイル読み込みエラー: ${post.thumbnailUrl}');
                            }
                            return Container();
                          },
                        ),
                      ),
                    // 再生ボタン
                    const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 80,
                      ),
                    ),
                    // 動画初期化中のローディング表示
                    if (postIndex == _currentIndex &&
                        post.postType == PostType.video &&
                        !_initializedVideos.contains(postIndex))
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF6B35),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // タップで一時停止/再生、シークバー表示
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (controller != null && controller.value.isInitialized) {
                  // シーク中でない場合は一時停止/再生
                  if (!_isSeeking) {
                    if (controller.value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  }
                } else if (postIndex == _currentIndex &&
                    post.postType == PostType.video) {
                  // 初期化されていない場合は初期化を開始
                  _initializeVideoController(postIndex);
                }
              },
              onHorizontalDragStart: (details) {
                if (controller != null &&
                    controller.value.isInitialized &&
                    postIndex == _currentIndex) {
                  _startSeeking(controller);
                }
              },
              onHorizontalDragUpdate: (details) {
                if (controller != null && controller.value.isInitialized) {
                  if (!_isSeeking) {
                    _startSeeking(controller);
                  }
                  _updateSeeking(details, controller);
                }
              },
              onHorizontalDragEnd: (details) {
                if (_isSeeking &&
                    controller != null &&
                    controller.value.isInitialized) {
                  _endSeeking(controller);
                }
              },
            ),
          ),

          // シークバー（動画が初期化されている場合は常に表示）
          if (postIndex == _currentIndex &&
              controller != null &&
              controller.value.isInitialized)
            _buildSeekBar(controller),
        ],
      ),
    );
  }

  /// シーク開始
  void _startSeeking(VideoPlayerController controller) {
    if (!controller.value.isInitialized) return;

    // シークバー更新タイマーを一時停止
    _seekBarUpdateTimer?.cancel();

    // 動画を一時停止（シーク中は再生を停止）
    final wasPlaying = controller.value.isPlaying;
    if (wasPlaying) {
      controller.pause();
    }

    setState(() {
      _isSeeking = true;
      _seekPosition = controller.value.position.inMilliseconds.toDouble() /
          controller.value.duration.inMilliseconds.toDouble();
    });

    if (kDebugMode) {
      debugPrint(
          '🎯 シーク開始: ${_formatDuration(controller.value.position)} / ${_formatDuration(controller.value.duration)}');
    }
  }

  /// シーク中
  void _updateSeeking(
      DragUpdateDetails details, VideoPlayerController controller) {
    if (!controller.value.isInitialized || _seekPosition == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final dragDelta = details.delta.dx;
    final dragRatio = dragDelta / screenWidth;

    setState(() {
      _seekPosition = _seekPosition! + dragRatio;
      _seekPosition = _seekPosition!.clamp(0.0, 1.0);
    });

    // デバウンス処理：100msごとに動画の再生位置を更新
    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (_seekPosition != null && controller.value.isInitialized) {
        final targetPosition = Duration(
          milliseconds:
              (_seekPosition! * controller.value.duration.inMilliseconds)
                  .round(),
        );
        controller.seekTo(targetPosition);

        if (kDebugMode) {
          debugPrint(
              '🎯 シーク位置更新: ${_formatDuration(targetPosition)} / ${_formatDuration(controller.value.duration)} (progress: ${_seekPosition!.toStringAsFixed(3)})');
        }
      }
    });
  }

  /// シーク終了
  void _endSeeking(VideoPlayerController controller) {
    if (!controller.value.isInitialized || _seekPosition == null) return;

    // デバウンスタイマーをキャンセルして、即座に最終位置に移動
    _seekDebounceTimer?.cancel();

    final targetPosition = Duration(
      milliseconds:
          (_seekPosition! * controller.value.duration.inMilliseconds).round(),
    );

    // 動画の再生位置を変更
    controller.seekTo(targetPosition).then((_) {
      // シーク前が再生中だった場合は再開
      // ただし、シーク中は一時停止しているので、常に再生を再開
      if (!_isDisposed && mounted) {
        controller.play();
      }
    });

    if (kDebugMode) {
      debugPrint(
          '🎯 シーク終了: ${_formatDuration(targetPosition)} / ${_formatDuration(controller.value.duration)}');
    }

    setState(() {
      _isSeeking = false;
      _seekPosition = null;
    });

    // シークバー更新タイマーを再開
    _startSeekBarUpdateTimer();
  }

  /// 音声シーク開始
  void _startSeekingAudio(AudioPlayer player) {
    if (player.duration == null) return;

    // シークバー更新タイマーを一時停止
    _seekBarUpdateTimerAudio?.cancel();

    // 音声を一時停止（シーク中は再生を停止）
    final wasPlaying = player.playing;
    if (wasPlaying) {
      player.pause();
    }

    setState(() {
      _isSeekingAudio = true;
      final currentPosition = player.position;
      final duration = player.duration ?? Duration.zero;
      if (duration.inMilliseconds > 0) {
        _seekPositionAudio = currentPosition.inMilliseconds.toDouble() /
            duration.inMilliseconds.toDouble();
      } else {
        _seekPositionAudio = 0.0;
      }
    });

    if (kDebugMode) {
      debugPrint(
          '🎵 音声シーク開始: ${_formatDuration(player.position)} / ${_formatDuration(player.duration ?? Duration.zero)}');
    }
  }

  /// 音声シーク中
  void _updateSeekingAudio(DragUpdateDetails details, AudioPlayer player) {
    if (player.duration == null || _seekPositionAudio == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final dragDelta = details.delta.dx;
    final dragRatio = dragDelta / screenWidth;

    setState(() {
      _seekPositionAudio = _seekPositionAudio! + dragRatio;
      _seekPositionAudio = _seekPositionAudio!.clamp(0.0, 1.0);
    });

    // デバウンス処理：100msごとに音声の再生位置を更新
    _seekDebounceTimerAudio?.cancel();
    _seekDebounceTimerAudio = Timer(const Duration(milliseconds: 100), () {
      if (_seekPositionAudio != null && player.duration != null) {
        final targetPosition = Duration(
          milliseconds:
              (_seekPositionAudio! * player.duration!.inMilliseconds).round(),
        );
        player.seek(targetPosition);

        if (kDebugMode) {
          debugPrint(
              '🎵 音声シーク位置更新: ${_formatDuration(targetPosition)} / ${_formatDuration(player.duration!)} (progress: ${_seekPositionAudio!.toStringAsFixed(3)})');
        }
      }
    });
  }

  /// 音声シーク終了
  void _endSeekingAudio(AudioPlayer player) {
    if (player.duration == null || _seekPositionAudio == null) return;

    // デバウンスタイマーをキャンセルして、即座に最終位置に移動
    _seekDebounceTimerAudio?.cancel();

    final targetPosition = Duration(
      milliseconds:
          (_seekPositionAudio! * player.duration!.inMilliseconds).round(),
    );

    // 音声の再生位置を変更
    player.seek(targetPosition).then((_) {
      // シーク前が再生中だった場合は再開
      if (!_isDisposed && mounted) {
        player.play();
      }
    });

    setState(() {
      _isSeekingAudio = false;
      _seekPositionAudio = null;
    });

    // シークバー更新タイマーを再開
    _startSeekBarUpdateTimerAudio();
  }

  /// 音声シークバー更新タイマーを開始
  void _startSeekBarUpdateTimerAudio() {
    _seekBarUpdateTimerAudio?.cancel();
    _seekBarUpdateTimerAudio =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isDisposed &&
          mounted &&
          _currentPlayingAudio != null &&
          !_isSeekingAudio) {
        final player = _audioPlayers[_currentPlayingAudio];
        if (player != null) {
          setState(() {
            // シークバーの更新をトリガー
          });
        } else {
          // プレイヤーが初期化されていない場合はタイマーを停止
          timer.cancel();
        }
      } else if (_currentPlayingAudio == null) {
        // 再生中の音声がない場合はタイマーを停止
        timer.cancel();
      }
    });
  }

  /// 音声用シークバーを構築（ナビゲーションバーの真上に表示）
  Widget _buildAudioSeekBar(AudioPlayer player) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, positionSnapshot) {
        final position = _isSeekingAudio && _seekPositionAudio != null
            ? Duration(
                milliseconds: (_seekPositionAudio! *
                        (player.duration?.inMilliseconds ?? 0))
                    .round())
            : (positionSnapshot.data ?? Duration.zero);
        final duration = player.duration ?? Duration.zero;
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

        // ナビゲーションバーの高さを考慮（約80px）
        return Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 時間表示（画面右のシークバーの上）
                Padding(
                  padding: const EdgeInsets.only(right: 0, bottom: 8),
                  child: Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // シークバー（画面の一番左から右まで）
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    if (player.duration == null) return;
                    _startSeekingAudio(player);
                  },
                  onHorizontalDragUpdate: (details) {
                    if (player.duration == null) return;
                    if (!_isSeekingAudio) {
                      _startSeekingAudio(player);
                    }
                    _updateSeekingAudio(details, player);
                  },
                  onHorizontalDragEnd: (details) {
                    if (player.duration == null) return;
                    _endSeekingAudio(player);
                  },
                  onTapDown: (details) {
                    if (player.duration == null) return;

                    // シークバーのコンテナ内の座標を取得
                    final containerWidth = MediaQuery.of(context).size.width;
                    final tapX =
                        details.localPosition.dx.clamp(0.0, containerWidth);
                    final tapRatio = tapX / containerWidth;
                    final targetPosition = Duration(
                      milliseconds:
                          (tapRatio.clamp(0.0, 1.0) * duration.inMilliseconds)
                              .round(),
                    );

                    player.seek(targetPosition);

                    if (kDebugMode) {
                      debugPrint(
                          '🎵 音声シークバータップ: $tapX / $containerWidth = $tapRatio → ${_formatDuration(targetPosition)}');
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 20, // タップ領域を広げる
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Stack(
                      children: [
                        // 背景バー
                        Container(
                          width: double.infinity,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // 再生済み部分（左から右へ）
                        Positioned(
                          left: 0,
                          top: 8,
                          child: FractionallySizedBox(
                            widthFactor: progress,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        // シークハンドル
                        Positioned(
                          left:
                              MediaQuery.of(context).size.width * progress - 6,
                          top: 4,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// シークバーを構築（ナビゲーションバーの真上に表示）
  Widget _buildSeekBar(VideoPlayerController controller) {
    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final position = _isSeeking && _seekPosition != null
        ? Duration(
            milliseconds:
                (_seekPosition! * controller.value.duration.inMilliseconds)
                    .round())
        : controller.value.position;
    final duration = controller.value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    // ナビゲーションバーの高さを考慮（約80px）
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 時間表示（画面右のシークバーの上）
            Padding(
              padding: const EdgeInsets.only(right: 0, bottom: 8),
              child: Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // シークバー（画面の一番左から右まで）
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) {
                if (!controller.value.isInitialized) return;
                _startSeeking(controller);
              },
              onHorizontalDragUpdate: (details) {
                if (!controller.value.isInitialized) return;
                if (!_isSeeking) {
                  _startSeeking(controller);
                }
                _updateSeeking(details, controller);
              },
              onHorizontalDragEnd: (details) {
                if (!controller.value.isInitialized) return;
                _endSeeking(controller);
              },
              onTapDown: (details) {
                if (!controller.value.isInitialized) return;

                // シークバーのコンテナ内の座標を取得
                final containerWidth = MediaQuery.of(context).size.width;
                final tapX =
                    details.localPosition.dx.clamp(0.0, containerWidth);
                final tapRatio = tapX / containerWidth;
                final targetPosition = Duration(
                  milliseconds: (tapRatio.clamp(0.0, 1.0) *
                          controller.value.duration.inMilliseconds)
                      .round(),
                );

                controller.seekTo(targetPosition);

                if (kDebugMode) {
                  debugPrint(
                      '🎯 シークバータップ: $tapX / $containerWidth = $tapRatio → ${_formatDuration(targetPosition)}');
                }
              },
              child: Container(
                width: double.infinity,
                height: 20, // タップ領域を広げる
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Stack(
                  children: [
                    // 背景バー
                    Container(
                      width: double.infinity,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // 再生済み部分（左から右へ）
                    Positioned(
                      left: 0,
                      top: 8,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // シークハンドル
                    Positioned(
                      left: MediaQuery.of(context).size.width * progress - 6,
                      top: 4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(Post post) {
    // 画像URLを取得（mediaUrl優先、なければthumbnailUrl）
    final imageUrl = post.mediaUrl ?? post.thumbnailUrl;

    if (kDebugMode) {
      debugPrint('🖼️ 画像コンテンツ表示:');
      debugPrint('   mediaUrl: ${post.mediaUrl}');
      debugPrint('   thumbnailUrl: ${post.thumbnailUrl}');
      debugPrint('   contentPath: ${post.contentPath}');
      debugPrint('   使用URL: $imageUrl');
    }

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.image_not_supported,
                color: Colors.white38,
                size: 80,
              ),
              const SizedBox(height: 16),
              const Text(
                '画像URLが設定されていません',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'contentPath: ${post.contentPath}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // 画面サイズを取得してキャッシュサイズを計算
    final screenSize = MediaQuery.of(context).size;
    final cacheWidth =
        (screenSize.width * MediaQuery.of(context).devicePixelRatio).round();
    final cacheHeight =
        (screenSize.height * MediaQuery.of(context).devicePixelRatio).round();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: RobustNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        maxWidth: cacheWidth,
        maxHeight: cacheHeight,
      ),
    );
  }

  Widget _buildTextContent(Post post) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black,
            SpotLightColors.getSpotlightColor(0).withOpacity(0.15),
            SpotLightColors.getSpotlightColor(1).withOpacity(0.15),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                post.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              if (post.content != null)
                Text(
                  post.content!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioContent(Post post) {
    final postIndex = _posts.indexOf(post);
    final player = _audioPlayers[postIndex];
    final isPlaying = _currentPlayingAudio == postIndex && player != null;

    return Stack(
      children: [
        // モダンな背景デザイン
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                SpotLightColors.getSpotlightColor(2).withOpacity(0.4),
                SpotLightColors.getSpotlightColor(1).withOpacity(0.3),
                Colors.black,
                Colors.black,
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: CustomPaint(
            painter: _AudioBackgroundPainter(isPlaying: isPlaying),
            child: GestureDetector(
              onTap: () {
                if (!_isSeekingAudio) {
                  _toggleAudioPlayback(postIndex);
                }
              },
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 音声視覚化エフェクト（モダンなデザイン）
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            SpotLightColors.getSpotlightColor(2)
                                .withOpacity(0.6),
                            SpotLightColors.getSpotlightColor(2)
                                .withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SpotLightColors.getSpotlightColor(2)
                                .withOpacity(0.5),
                            blurRadius: isPlaying ? 40 : 20,
                            spreadRadius: isPlaying ? 10 : 5,
                          ),
                        ],
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.3),
                          border: Border.all(
                            color: SpotLightColors.getSpotlightColor(2)
                                .withOpacity(0.8),
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: isPlaying ? 90 : 70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      '音声投稿',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    // 音声初期化中のローディング表示
                    if (postIndex == _currentIndex &&
                        post.postType == PostType.audio &&
                        !_initializedAudios.contains(postIndex))
                      const Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // シークバー（音声が初期化されている場合は常に表示）
        if (postIndex == _currentIndex &&
            player != null &&
            _initializedAudios.contains(postIndex))
          _buildAudioSeekBar(player),
      ],
    );
  }

  Widget _buildBottomControls(Post post) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 投稿者情報
          Row(
            children: [
              // RepaintBoundaryでアイコン部分を分離し、setStateの影響を受けないようにする
              RepaintBoundary(
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: SpotLightColors.getSpotlightColor(0),
                  child: ClipOval(
                    key: ValueKey(
                        '${post.username}_${_iconCacheKeys[post.username] ?? 0}'),
                    child: RobustNetworkImage(
                      imageUrl: post.userIconUrl ??
                          (post.userIconPath.isNotEmpty
                              ? '${AppConfig.backendUrl}/icon/${post.userIconPath}'
                              : '${AppConfig.backendUrl}/icon/default_icon.jpg'),
                      fit: BoxFit.cover,
                      maxWidth: 80,
                      maxHeight: 80,
                      placeholder: Container(),
                      errorWidget: Container(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_getTimeAgo(post.createdAt)}前',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // タイトル
          Text(
            post.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRightBottomControls(Post post) {
    return Column(
      children: [
        // スポットライトボタン
        _buildControlButton(
          icon: post.isSpotlighted
              ? Icons.flashlight_on
              : Icons.flashlight_on_outlined,
          color: post.isSpotlighted
              ? SpotLightColors.getSpotlightColor(0)
              : Colors.white,
          label: '${post.likes}',
          onTap: () => _handleSpotlightButton(post),
        ),
        const SizedBox(height: 20),
        // コメントボタン
        _buildControlButton(
          icon: Icons.chat_bubble_outline,
          color: Colors.white,
          label: '${post.comments}',
          onTap: () => _handleCommentButton(post),
        ),
        const SizedBox(height: 20),
        // プレイリスト追加ボタン
        _buildControlButton(
          icon: Icons.playlist_add,
          color: Colors.white,
          onTap: () => _handlePlaylistButton(post),
        ),
        const SizedBox(height: 20),
        // 共有ボタン
        _buildControlButton(
          icon: Icons.share,
          color: Colors.white,
          onTap: () => _handleShareButton(post),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}日';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分';
    } else {
      return 'たった今';
    }
  }

  // ジェスチャー処理
  void _handlePanUpdate(DragUpdateDetails details) {
    // 右スワイプのみを検出
    if (details.delta.dx > 0) {
      setState(() {
        _swipeOffset = math.min(_swipeOffset + details.delta.dx, 300.0);
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    // スワイプが十分な場合は即座にスポットライト実行
    if (_swipeOffset > 80) {
      _executeSpotlight();
    } else {
      // スワイプが不十分な場合は元に戻す
      setState(() {
        _swipeOffset = 0.0;
      });
    }
  }

  // スポットライト実行（共通処理）
  Future<void> _executeSpotlight() async {
    final currentPost = _posts[_currentIndex];
    final isCurrentlySpotlighted = currentPost.isSpotlighted;

    // バックエンドAPIを呼び出し
    final success = isCurrentlySpotlighted
        ? await PostService.spotlightOff(currentPost.id)
        : await PostService.spotlightOn(currentPost.id);

    if (!success) {
      if (kDebugMode) {
        debugPrint('❌ スポットライト処理に失敗しました');
      }
      return;
    }

    // 投稿のスポットライト状態を更新
    _posts[_currentIndex] = Post(
      id: currentPost.id,
      userId: currentPost.userId,
      username: currentPost.username,
      userIconPath: currentPost.userIconPath,
      userIconUrl: currentPost.userIconUrl,
      title: currentPost.title,
      content: currentPost.content,
      contentPath: currentPost.contentPath,
      type: currentPost.type,
      mediaUrl: currentPost.mediaUrl,
      thumbnailUrl: currentPost.thumbnailUrl,
      likes: isCurrentlySpotlighted
          ? currentPost.likes - 1
          : currentPost.likes + 1,
      playNum: currentPost.playNum,
      link: currentPost.link,
      comments: currentPost.comments,
      shares: currentPost.shares,
      isSpotlighted: !isCurrentlySpotlighted,
      isText: currentPost.isText,
      nextContentId: currentPost.nextContentId,
      createdAt: currentPost.createdAt,
    );

    if (!isCurrentlySpotlighted) {
      // スポットライトをつける場合：アニメーション付き
      setState(() {
        _isSpotlighting = true;
        _swipeOffset = 0.0;
      });

      // アンビエントライティングアニメーション開始
      _ambientAnimationController?.forward();

      // 2秒後にアニメーション付きで消す
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isDisposed && mounted) {
          _ambientAnimationController?.reverse().then((_) {
            if (!_isDisposed && mounted) {
              setState(() {
                _isSpotlighting = false;
              });
              _ambientAnimationController?.reset();
            }
          });
        }
      });
    } else {
      // スポットライトを消す場合：アニメーションなし、色もなし
      setState(() {
        _swipeOffset = 0.0;
      });
    }
  }

  void _resetSpotlightState() {
    if (!_isDisposed && mounted) {
      setState(() {
        _swipeOffset = 0.0;
        _isSpotlighting = false;
      });
    }
    _ambientAnimationController?.reset();
  }

  // ボタン機能実装
  void _handleSpotlightButton(Post post) {
    _executeSpotlight();
  }

  void _handleCommentButton(Post post) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isLoading = false;
            List<Comment> comments = [];

            // コメント一覧を取得
            if (comments.isEmpty && !isLoading) {
              isLoading = true;
              CommentService.getComments(post.id).then((fetchedComments) {
                if (mounted) {
                  setModalState(() {
                    comments = fetchedComments;
                    isLoading = false;
                  });
                }
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ヘッダー
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'コメント',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // コメント一覧
                        Expanded(
                          child: isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFFF6B35),
                                  ),
                                )
                              : comments.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'コメントはありません',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: scrollController,
                                      itemCount: comments.length,
                                      itemBuilder: (context, index) {
                                        return _buildCommentItem(
                                            comments[index]);
                                      },
                                    ),
                        ),

                        // コメント入力
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFFFF6B35),
                                child: const Icon(Icons.person,
                                    size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: commentController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'コメントを追加...',
                                    hintStyle:
                                        TextStyle(color: Colors.grey[400]),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[800],
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: () async {
                                  final commentText =
                                      commentController.text.trim();
                                  if (commentText.isEmpty) return;

                                  // コメント送信
                                  final success =
                                      await CommentService.addComment(
                                    post.id,
                                    commentText,
                                  );

                                  if (success && mounted) {
                                    commentController.clear();
                                    // コメント一覧を再取得
                                    final fetchedComments =
                                        await CommentService.getComments(
                                            post.id);
                                    setModalState(() {
                                      comments = fetchedComments;
                                    });

                                    // 投稿のコメント数を更新
                                    setState(() {
                                      _posts[_currentIndex] = Post(
                                        id: _posts[_currentIndex].id,
                                        userId: _posts[_currentIndex].userId,
                                        username:
                                            _posts[_currentIndex].username,
                                        userIconPath:
                                            _posts[_currentIndex].userIconPath,
                                        userIconUrl:
                                            _posts[_currentIndex].userIconUrl,
                                        title: _posts[_currentIndex].title,
                                        content: _posts[_currentIndex].content,
                                        contentPath:
                                            _posts[_currentIndex].contentPath,
                                        type: _posts[_currentIndex].type,
                                        mediaUrl:
                                            _posts[_currentIndex].mediaUrl,
                                        thumbnailUrl:
                                            _posts[_currentIndex].thumbnailUrl,
                                        likes: _posts[_currentIndex].likes,
                                        playNum: _posts[_currentIndex].playNum,
                                        link: _posts[_currentIndex].link,
                                        comments:
                                            _posts[_currentIndex].comments + 1,
                                        shares: _posts[_currentIndex].shares,
                                        isSpotlighted:
                                            _posts[_currentIndex].isSpotlighted,
                                        isText: _posts[_currentIndex].isText,
                                        nextContentId:
                                            _posts[_currentIndex].nextContentId,
                                        createdAt:
                                            _posts[_currentIndex].createdAt,
                                      );
                                    });
                                  }
                                },
                                icon: const Icon(Icons.send,
                                    color: Color(0xFFFF6B35)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFFF6B35),
                backgroundImage: comment.userIconUrl != null
                    ? CachedNetworkImageProvider(comment.userIconUrl!)
                    : null,
                child: comment.userIconUrl == null
                    ? const Icon(Icons.person, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatCommentTime(comment.commenttimestamp),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.commenttext,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.thumb_up_outlined,
                              color: Colors.grey, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            // 返信機能（将来実装）
                          },
                          icon: const Icon(Icons.reply,
                              color: Colors.grey, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 返信コメント
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Column(
                children: comment.replies
                    .map((reply) => _buildCommentItem(reply))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCommentTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}日前';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}時間前';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}分前';
      } else {
        return 'たった今';
      }
    } catch (e) {
      return timestamp;
    }
  }

  /// プレイリスト追加ボタンの処理
  void _handlePlaylistButton(Post post) async {
    try {
      // プレイリスト一覧を取得
      final playlists = await PlaylistService.getPlaylists();

      if (!mounted) return;

      if (playlists.isEmpty) {
        // プレイリストがない場合は新規作成を促す
        _showCreatePlaylistDialog(post);
        return;
      }

      // プレイリスト選択ダイアログを表示
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'プレイリストに追加',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // プレイリスト一覧
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length + 1, // +1は新規作成ボタン
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // 新規作成ボタン
                        return ListTile(
                          leading: const Icon(
                            Icons.add_circle_outline,
                            color: Color(0xFFFF6B35),
                          ),
                          title: const Text(
                            '新しいプレイリストを作成',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showCreatePlaylistDialog(post);
                          },
                        );
                      }

                      final playlist = playlists[index - 1];
                      return ListTile(
                        leading: playlist.thumbnailpath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  '${AppConfig.backendUrl}${playlist.thumbnailpath}',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.playlist_play,
                                      color: Color(0xFFFF6B35),
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.playlist_play,
                                color: Color(0xFFFF6B35),
                              ),
                        title: Text(
                          playlist.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          final success =
                              await PlaylistService.addContentToPlaylist(
                            playlist.playlistid,
                            post.id,
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success ? 'プレイリストに追加しました' : '追加に失敗しました',
                                ),
                                backgroundColor:
                                    success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📋 プレイリスト取得エラー: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プレイリストの取得に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// プレイリスト作成ダイアログ
  void _showCreatePlaylistDialog(Post post) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            '新しいプレイリストを作成',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'プレイリスト名を入力',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[800],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                Navigator.pop(context);

                final playlistId = await PlaylistService.createPlaylist(title);

                if (playlistId != null && mounted) {
                  // 作成したプレイリストにコンテンツを追加
                  final success = await PlaylistService.addContentToPlaylist(
                    playlistId,
                    post.id,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? 'プレイリストを作成して追加しました' : '追加に失敗しました',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('プレイリストの作成に失敗しました'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text(
                '作成',
                style: TextStyle(color: Color(0xFFFF6B35)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleShareButton(Post post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '共有',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // 共有オプション
              _buildShareOption(
                icon: Icons.copy,
                title: 'リンクをコピー',
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('リンクをコピーしました');
                  setState(() {
                    _posts[_currentIndex] = Post(
                      id: _posts[_currentIndex].id,
                      userId: _posts[_currentIndex].userId,
                      username: _posts[_currentIndex].username,
                      userIconPath: _posts[_currentIndex].userIconPath,
                      userIconUrl: _posts[_currentIndex].userIconUrl,
                      title: _posts[_currentIndex].title,
                      content: _posts[_currentIndex].content,
                      contentPath: _posts[_currentIndex].contentPath,
                      type: _posts[_currentIndex].type,
                      mediaUrl: _posts[_currentIndex].mediaUrl,
                      thumbnailUrl: _posts[_currentIndex].thumbnailUrl,
                      likes: _posts[_currentIndex].likes,
                      playNum: _posts[_currentIndex].playNum,
                      link: _posts[_currentIndex].link,
                      comments: _posts[_currentIndex].comments,
                      shares: _posts[_currentIndex].shares + 1,
                      isSpotlighted: _posts[_currentIndex].isSpotlighted,
                      isText: _posts[_currentIndex].isText,
                      nextContentId: _posts[_currentIndex].nextContentId,
                      createdAt: _posts[_currentIndex].createdAt,
                    );
                  });
                },
              ),
              _buildShareOption(
                icon: Icons.message,
                title: 'メッセージで送信',
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('メッセージアプリを開きます');
                },
              ),
              _buildShareOption(
                icon: Icons.email,
                title: 'メールで送信',
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('メールアプリを開きます');
                },
              ),
              _buildShareOption(
                icon: Icons.bookmark_border,
                title: 'ブックマークに保存',
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('ブックマークに保存しました');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: onTap,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // 動画プレイヤー関連メソッド
  Future<void> _initializeVideoController(int postIndex) async {
    final post = _posts[postIndex];

    // 動画投稿でない場合は何もしない
    if (post.postType != PostType.video || post.mediaUrl == null) {
      return;
    }

    // すでに初期化済みの場合はスキップ
    if (_initializedVideos.contains(postIndex)) {
      return;
    }

    try {
      final videoUrl = post.mediaUrl!;

      if (kDebugMode) {
        debugPrint('📹 動画初期化開始: $videoUrl');
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();

      if (!_isDisposed && mounted) {
        setState(() {
          _videoControllers[postIndex] = controller;
          _initializedVideos.add(postIndex);
        });

        // 再生位置の更新をリッスン（シークバーの更新用）
        controller.addListener(_onVideoPositionChanged);

        if (kDebugMode) {
          debugPrint('✅ 動画初期化成功: ${controller.value.duration}');
        }
      }
    } catch (e) {
      // 動画の初期化に失敗した場合、サンプル動画で再試行
      if (kDebugMode) {
        debugPrint('❌ 動画の初期化に失敗: $e');
        debugPrint('🔄 サンプル動画で再試行...');
      }

      try {
        final sampleUrl =
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
        final controller =
            VideoPlayerController.networkUrl(Uri.parse(sampleUrl));
        await controller.initialize();

        if (!_isDisposed && mounted) {
          setState(() {
            _videoControllers[postIndex] = controller;
            _initializedVideos.add(postIndex);
          });

          // 再生位置の更新をリッスン（シークバーの更新用）
          controller.addListener(_onVideoPositionChanged);

          if (kDebugMode) {
            debugPrint('✅ サンプル動画で初期化成功');
          }
        }
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('❌ サンプル動画も失敗: $e2');
        }
      }
    }
  }

  void _handleMediaPageChange(int newIndex) {
    if (newIndex < 0 || newIndex >= _posts.length) {
      if (kDebugMode) {
        debugPrint('⚠️ 無効なインデックス: $newIndex, 投稿数=${_posts.length}');
      }
      return;
    }

    final newPost = _posts[newIndex];

    if (kDebugMode) {
      debugPrint(
          '🔄 メディアページ変更: インデックス $newIndex, 投稿ID=${newPost.id}, type=${newPost.type}');
    }

    // 前の動画を停止
    if (_currentPlayingVideo != null) {
      final prevController = _videoControllers[_currentPlayingVideo];
      if (prevController != null && prevController.value.isInitialized) {
        prevController.pause();
      }
      _currentPlayingVideo = null;
    }

    // シークバー更新タイマーを停止
    _seekBarUpdateTimer?.cancel();

    // シーク状態をリセット
    setState(() {
      _isSeeking = false;
      _seekPosition = null;
    });

    // 前の音声を停止
    if (_currentPlayingAudio != null) {
      final prevPlayer = _audioPlayers[_currentPlayingAudio];
      if (prevPlayer != null) {
        prevPlayer.pause();
      }
      _currentPlayingAudio = null;
    }

    // 新しいページが動画投稿の場合
    if (newPost.postType == PostType.video) {
      _currentPlayingVideo = newIndex;

      // シークバー更新タイマーを開始
      _startSeekBarUpdateTimer();

      // 動画コントローラーが初期化されていない場合は初期化
      if (!_initializedVideos.contains(newIndex)) {
        _initializeVideoController(newIndex).then((_) {
          if (!_isDisposed && mounted) {
            // 初期化完了後に自動再生
            final controller = _videoControllers[newIndex];
            if (controller != null && controller.value.isInitialized) {
              controller.play();
              controller.setLooping(true);
            }
          }
        });
      } else {
        // 既に初期化済みの場合は即座に再生
        final controller = _videoControllers[newIndex];
        if (controller != null && controller.value.isInitialized) {
          controller.play();
          controller.setLooping(true);
        }
      }
    } else if (newPost.postType == PostType.audio) {
      // 新しいページが音声投稿の場合
      _currentPlayingAudio = newIndex;

      // 音声プレイヤーが初期化されていない場合は初期化
      if (!_initializedAudios.contains(newIndex)) {
        _initializeAudioPlayer(newIndex).then((_) {
          if (!_isDisposed && mounted) {
            // 初期化完了後に自動再生
            final player = _audioPlayers[newIndex];
            if (player != null) {
              player.setLoopMode(LoopMode.one);
              player.play();
              // シークバー更新タイマーを開始
              _startSeekBarUpdateTimerAudio();
            }
          }
        });
      } else {
        // 既に初期化済みの場合は即座に再生
        final player = _audioPlayers[newIndex];
        if (player != null) {
          player.setLoopMode(LoopMode.one);
          player.play();
          // シークバー更新タイマーを開始
          _startSeekBarUpdateTimerAudio();
        }
      }
    } else if (newPost.postType == PostType.image) {
      // 画像は表示時に直接読み込む（事前読み込みなし）
      // _preloadImagesAround(newIndex);
      // _releaseDistantResources(newIndex);
    }
  }

  // 音声プレイヤー初期化メソッド
  Future<void> _initializeAudioPlayer(int postIndex) async {
    final post = _posts[postIndex];

    // 音声投稿でない場合は何もしない
    if (post.postType != PostType.audio || post.mediaUrl == null) {
      return;
    }

    // すでに初期化済みの場合はスキップ
    if (_initializedAudios.contains(postIndex)) {
      return;
    }

    try {
      final audioUrl = post.mediaUrl!;

      if (kDebugMode) {
        debugPrint('🎵 音声初期化開始: $audioUrl');
      }

      final player = AudioPlayer();
      await player.setUrl(audioUrl);

      if (!_isDisposed && mounted) {
        setState(() {
          _audioPlayers[postIndex] = player;
          _initializedAudios.add(postIndex);
        });

        if (kDebugMode) {
          debugPrint('✅ 音声初期化成功: ${player.duration}');
        }
      }
    } catch (e) {
      // 音声の初期化に失敗した場合、サンプル音声で再試行
      if (kDebugMode) {
        debugPrint('❌ 音声の初期化に失敗: $e');
        debugPrint('🔄 サンプル音声で再試行...');
      }

      try {
        final sampleUrl =
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
        final player = AudioPlayer();
        await player.setUrl(sampleUrl);

        if (!_isDisposed && mounted) {
          setState(() {
            _audioPlayers[postIndex] = player;
            _initializedAudios.add(postIndex);
          });

          if (kDebugMode) {
            debugPrint('✅ サンプル音声で初期化成功');
          }
        }
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('❌ サンプル音声も失敗: $e2');
        }
      }
    }
  }

  // 音声の再生/停止を切り替え
  Future<void> _toggleAudioPlayback(int postIndex) async {
    final player = _audioPlayers[postIndex];

    if (player == null) {
      // プレイヤーが初期化されていない場合は初期化
      await _initializeAudioPlayer(postIndex);
      final newPlayer = _audioPlayers[postIndex];
      if (newPlayer != null) {
        setState(() {
          _currentPlayingAudio = postIndex;
        });
        await newPlayer.play();
      }
      return;
    }

    try {
      if (player.playing) {
        await player.pause();
      } else {
        // 他の音声を停止
        if (_currentPlayingAudio != null && _currentPlayingAudio != postIndex) {
          final otherPlayer = _audioPlayers[_currentPlayingAudio];
          if (otherPlayer != null) {
            await otherPlayer.pause();
          }
        }

        setState(() {
          _currentPlayingAudio = postIndex;
        });
        await player.play();
        // シークバー更新タイマーを開始
        _startSeekBarUpdateTimerAudio();
      }
    } catch (e) {
      print('音声の再生に失敗: $e');
    }
  }

  /// シークバー更新タイマーを開始（1秒ごとに更新）
  void _startSeekBarUpdateTimer() {
    _seekBarUpdateTimer?.cancel();
    _seekBarUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isDisposed &&
          mounted &&
          _currentPlayingVideo != null &&
          !_isSeeking) {
        final controller = _videoControllers[_currentPlayingVideo];
        if (controller != null && controller.value.isInitialized) {
          setState(() {
            // シークバーの更新をトリガー
          });
        } else {
          // コントローラーが初期化されていない場合はタイマーを停止
          timer.cancel();
        }
      } else if (_currentPlayingVideo == null) {
        // 動画が再生されていない場合はタイマーを停止
        timer.cancel();
      }
    });
  }

  /// 動画の再生位置が変更されたときのコールバック
  void _onVideoPositionChanged() {
    // シーク中でない場合のみ更新（シーク中は手動で更新しているため）
    if (!_isSeeking && _currentPlayingVideo != null) {
      final controller = _videoControllers[_currentPlayingVideo];
      if (controller != null && controller.value.isInitialized && mounted) {
        setState(() {
          // シークバーの更新をトリガー
        });
      }
    }
  }

  // 時間表示用のフォーマット
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
