import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'dart:async';
import 'dart:math' as math;
import 'package:share_plus/share_plus.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../services/post_service.dart';
import '../services/comment_service.dart';
import '../services/report_service.dart';
import '../services/playlist_service.dart';
import '../services/icon_update_service.dart';
import '../auth/auth_provider.dart';
import '../config/app_config.dart';
import '../utils/spotlight_colors.dart';
import '../providers/navigation_provider.dart';
import 'user_profile_screen.dart';
import '../widgets/native_ad_widget.dart';
import '../services/share_link_service.dart';

/// ホーム画面 - 垂直フィード型ソーシャルメディアアプリのメイン画面
///
/// 段階1: 基本的な画面構造とPageView実装（垂直スワイプナビゲーション）
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // PageViewコントローラー
  late PageController _pageController;

  // 現在のインデックス
  int _currentIndex = 0;

  // 投稿リスト
  List<Post> _posts = [];

  // 広告設定
  static const int _adInterval = 5; // 5投稿ごとに広告を表示

  // 読み込み状態
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _noMoreContent = false;
  bool _hasQueuedLoadMore = false;

  // 取得済みコンテンツID管理（重複除外用）
  final Set<String> _fetchedContentIds = <String>{};

  // ウィジェットの破棄状態を管理
  bool _isDisposed = false;

  // 初回起動時のリトライ管理
  int _initialRetryCount = 0;
  static const int _maxInitialRetries = 5;

  // 動画プレイヤー管理（段階4）
  final Map<int, VideoPlayerController> _videoControllers = {};
  final Set<int> _initializedVideos = {};
  int? _currentPlayingVideo;

  // 音声プレイヤー管理（段階5）
  final Map<int, AudioPlayer> _audioPlayers = {};
  final Set<int> _initializedAudios = {};
  int? _currentPlayingAudio;

  // 画面遷移時のメディア再生状態管理
  int? _lastNavigationIndex;
  int? _lastPlayingVideoBeforeNavigation;
  int? _lastPlayingAudioBeforeNavigation;
  VoidCallback? _navigationListener;

  // シークバー関連（段階11）
  bool _isSeeking = false;
  bool _isSeekingAudio = false;
  Duration? _currentVideoPosition;
  Duration? _currentVideoDuration;
  Duration? _currentAudioPosition;
  Duration? _currentAudioDuration;
  Timer? _seekBarUpdateTimer;
  Timer? _seekDebounceTimer;
  Timer? _seekBarUpdateTimerAudio;
  Timer? _loadMoreRetryTimer;

  // リアルタイム更新関連（段階12）
  Timer? _backgroundUpdateTimer;
  StreamSubscription<IconUpdateEvent>? _iconUpdateSubscription;
  Set<String> _recordedPlayHistoryIds = {}; // 重複記録防止

  // スポットライト関連（段階7）
  bool _isSpotlighting = false;
  String? _pendingTargetPostId;
  bool _isFetchingTargetPost = false;
  bool _isCommentSheetVisible = false;
  late final AnimationController _spotlightAnimationController;
  late final Animation<double> _spotlightAnimation;

  // プレースホルダー表示状態
  bool _isShowingLoadingPlaceholder = false;
  bool _wasShowingLoadingPlaceholderAtLoadStart = false;

  // 読み込み開始時のインデックス（読み込み完了時の自動遷移判定用）
  int? _loadingStartIndex;
  String? _lastRecordedPostId;

  @override
  void initState() {
    super.initState();

    // ステータスバーを表示（edgeToEdgeモードで表示）
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
    // ステータスバーのスタイルを設定
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    // PageControllerの初期化
    _pageController = PageController(
      initialPage: 0,
    );

    _spotlightAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _spotlightAnimation = CurvedAnimation(
      parent: _spotlightAnimationController,
      curve: Curves.easeOutCubic,
    );

    // ライフサイクル監視を追加
    WidgetsBinding.instance.addObserver(this);

    // NavigationProviderの変更を監視（ナビゲーション変更時にメディア再生を制御）
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);
    _lastNavigationIndex = navigationProvider.currentIndex;
    _navigationListener = () {
      if (_isDisposed) return;
      final currentNavIndex = navigationProvider.currentIndex;
      _handleNavigationMediaControl(currentNavIndex);
    };
    navigationProvider.addListener(_navigationListener!);

    // 初期データ読み込み（段階2で実装）
    _loadInitialPosts();
  }

  @override
  void dispose() {
    _isDisposed = true;

    // NavigationProviderのリスナーを解除
    if (_navigationListener != null) {
      final navigationProvider =
          Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.removeListener(_navigationListener!);
      _navigationListener = null;
    }

    // ライフサイクル監視を解除
    WidgetsBinding.instance.removeObserver(this);

    // タイマーをクリア（段階4-5）
    _seekBarUpdateTimer?.cancel();
    _seekDebounceTimer?.cancel();
    _seekBarUpdateTimerAudio?.cancel();
    _loadMoreRetryTimer?.cancel();
    _spotlightAnimationController.dispose();

    // PageControllerを破棄
    _pageController.dispose();

    // 動画プレイヤーのリソース解放（段階4）
    for (final controller in _videoControllers.values) {
      controller.removeListener(_onVideoPositionChanged);
      controller.pause();
      controller.dispose();
    }
    _videoControllers.clear();
    _initializedVideos.clear();

    // 音声プレイヤーのリソース解放（段階5）
    for (final player in _audioPlayers.values) {
      player.pause();
      player.dispose();
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
        // アプリがバックグラウンドに行った時は動画を一時停止（段階4）
        if (kDebugMode) {
          debugPrint('📱 [ライフサイクル] アプリがバックグラウンドに移動');
        }
        _pauseAllMedia();
        break;
      case AppLifecycleState.resumed:
        // アプリがフォアグラウンドに戻った時は動画を再開（段階4）
        if (kDebugMode) {
          debugPrint('📱 [ライフサイクル] アプリがフォアグラウンドに戻った');
        }
        _resumeCurrentMedia();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// すべてのメディアを一時停止（段階4-5）
  void _pauseAllMedia() {
    // 動画を一時停止
    if (_currentPlayingVideo != null) {
      final controller = _videoControllers[_currentPlayingVideo];
      if (controller != null && controller.value.isInitialized) {
        controller.pause();
      }
    }
    // 音声を一時停止（段階5）
    if (_currentPlayingAudio != null) {
      final player = _audioPlayers[_currentPlayingAudio];
      if (player != null) {
        player.pause();
      }
    }
  }

  /// 現在のメディアを再開（段階4-5）
  void _resumeCurrentMedia() {
    // ナビゲーション状態を確認（段階12で詳細実装）
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);
    final currentNavIndex = navigationProvider.currentIndex;

    // ホーム画面が表示されている場合のみ再開
    if (currentNavIndex == 0) {
      // 動画を再開（段階4）
      if (_currentPlayingVideo != null) {
        final controller = _videoControllers[_currentPlayingVideo];
        if (controller != null &&
            controller.value.isInitialized &&
            !controller.value.isPlaying) {
          controller.play();
        }
      }
      // 音声を再開（段階5）
      if (_currentPlayingAudio != null) {
        final player = _audioPlayers[_currentPlayingAudio];
        if (player != null && player.playing == false) {
          player.play();
        }
      }
    }
  }

  /// 初期データ読み込み（段階3: PostServiceから投稿を取得、重複除外対応）
  Future<void> _loadInitialPosts() async {
    if (_isDisposed) return;

    setState(() {
      _isLoading = true;
      _noMoreContent = false;
    });

    try {
      // PostServiceから投稿を取得（初期読み込み時は除外IDなし）
      List<Post> fetchedPosts = [];
      int retryCount = 0;
      const maxRetries = 3; // 最大3回まで再試行

      while (retryCount <= maxRetries) {
        try {
          fetchedPosts = await PostService.fetchContents(excludeContentIDs: []);
          break; // 成功したらループを抜ける
        } on TooManyRequestsException catch (e) {
          retryCount++;
          if (retryCount > maxRetries) {
            // 最大再試行回数に達した場合は、429エラーを再スロー
            rethrow;
          }

          // 429エラー時は待機してから再試行
          if (kDebugMode) {
            debugPrint(
                '⚠️ 429エラー（初期読み込み）: ${e.retryAfterSeconds}秒待機してから再試行します (試行回数: $retryCount/$maxRetries)');
          }

          await Future.delayed(Duration(seconds: e.retryAfterSeconds));
        }
      }

      if (_isDisposed) return;

      if (fetchedPosts.isEmpty) {
        // リトライ処理
        if (_initialRetryCount < _maxInitialRetries) {
          _initialRetryCount++;
          if (kDebugMode) {
            debugPrint(
                '⚠️ 投稿が取得できませんでした。リトライします ($_initialRetryCount/$_maxInitialRetries)');
          }
          await Future.delayed(const Duration(seconds: 2));
          return _loadInitialPosts();
        }

        if (kDebugMode) {
          debugPrint('⚠️ 投稿が取得できませんでした（リトライ上限に達しました）');
        }

        // エラー時は空のリストを設定
        setState(() {
          _posts = [];
          _isLoading = false;
        });
      } else {
        // 重複除外処理
        final uniquePosts = <Post>[];
        for (final post in fetchedPosts) {
          if (!_fetchedContentIds.contains(post.id)) {
            uniquePosts.add(post);
            _addFetchedContentId(post.id);
          }
        }

        setState(() {
          _posts = uniquePosts;
          _isLoading = false;
          // 初期読み込み時は、取得できた場合は続きがある可能性があると判断
          _hasMorePosts = uniquePosts.length >= 3; // 3件以上取得できた場合は続きがあると判断
          if (kDebugMode) {
            debugPrint(
                '📄 初期読み込み完了: ${uniquePosts.length}件, _hasMorePosts=$_hasMorePosts');
          }
        });
        _schedulePendingTargetCheck();

        if (kDebugMode) {
          debugPrint(
              '✅ 投稿を取得しました: ${uniquePosts.length}件（重複除外後: ${fetchedPosts.length - uniquePosts.length}件）');
        }

        // 初期ロード完了後、最初の投稿の動画を初期化・再生（初期表示時に動画が表示されない問題を修正）
        if (uniquePosts.isNotEmpty && !_isDisposed) {
          // 次のフレームで動画を初期化（UI更新後に実行）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isDisposed && _posts.isNotEmpty && _currentIndex == 0) {
              final firstPost = _posts[0];
              if (firstPost.postType == PostType.video) {
                if (kDebugMode) {
                  debugPrint('🎬 初期表示: 最初の動画を初期化します: postId=${firstPost.id}');
                }
                _handleMediaPageChange(0);
              }
            }
          });
        }
      }
    } on TooManyRequestsException catch (e) {
      // 429エラー時は一時的なエラーとして扱い、リトライする
      if (kDebugMode) {
        debugPrint('⚠️ 429エラー（レート制限）: ${e.message}');
      }

      // リトライ処理
      if (_initialRetryCount < _maxInitialRetries) {
        _initialRetryCount++;
        if (kDebugMode) {
          debugPrint(
              '⚠️ エラーが発生しました。リトライします ($_initialRetryCount/$_maxInitialRetries)');
        }
        await Future.delayed(Duration(seconds: e.retryAfterSeconds));
        return _loadInitialPosts();
      }

      if (kDebugMode) {
        debugPrint('⚠️ 投稿が取得できませんでした（リトライ上限に達しました）');
      }

      // エラー時は空のリストを設定
      setState(() {
        _posts = [];
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 投稿取得エラー: $e');
      }

      // リトライ処理
      if (_initialRetryCount < _maxInitialRetries) {
        _initialRetryCount++;
        if (kDebugMode) {
          debugPrint(
              '⚠️ エラーが発生しました。リトライします ($_initialRetryCount/$_maxInitialRetries)');
        }
        await Future.delayed(const Duration(seconds: 2));
        return _loadInitialPosts();
      }

      if (_isDisposed) return;

      // エラー時は空のリストを設定
      setState(() {
        _posts = [];
        _isLoading = false;
      });
    }
  }

  /// 取得済みIDを追加し、最大数を超えた場合は古いものを削除
  void _addFetchedContentId(String id) {
    _fetchedContentIds.add(id);
    // 最大500件まで保持（メモリ管理）
    if (_fetchedContentIds.length > 500) {
      final idsList = _fetchedContentIds.toList();
      _fetchedContentIds.clear();
      // 最新の400件を保持
      _fetchedContentIds.addAll(idsList.skip(idsList.length - 400));
    }
  }

  /// 直近の取得済みIDのみを取得（ランダム取得時の重複チェック用）
  Set<String> _getRecentFetchedContentIds({int limit = 50}) {
    final idsList = _fetchedContentIds.toList();
    if (idsList.length <= limit) {
      return _fetchedContentIds;
    }
    // 最新のlimit件のみを返す
    return idsList.skip(idsList.length - limit).toSet();
  }

  /// 古い取得履歴をクリア（直近のkeepRecent件のみ保持）
  void _clearOldFetchedContentIds({int keepRecent = 10}) {
    final idsList = _fetchedContentIds.toList();
    if (idsList.length <= keepRecent) {
      return; // 保持する件数以下の場合は何もしない
    }
    // 最新のkeepRecent件のみを保持
    final recentIds = idsList.skip(idsList.length - keepRecent).toSet();
    _fetchedContentIds.clear();
    _fetchedContentIds.addAll(recentIds);

    if (kDebugMode) {
      debugPrint(
          '📄 取得履歴をクリア: ${idsList.length}件 → ${recentIds.length}件（直近${keepRecent}件のみ保持）');
    }
  }

  /// PageViewのページ変更処理（段階4: 動画再生制御を追加）
  void _onPageChanged(int index) {
    if (_isDisposed) return;

    final previousIndex = _currentIndex;
    setState(() {
      _currentIndex = index;
    });

    // 前の動画を停止（段階4）- 逆スクロール時も対応
    if (previousIndex != index) {
      final prevPostIndex = _getActualPostIndex(previousIndex);
      if (prevPostIndex != null) {
        final prevPost = _posts[prevPostIndex];
        if (prevPost.postType == PostType.video) {
          final prevController = _videoControllers[prevPostIndex];
          if (prevController != null && prevController.value.isInitialized) {
            prevController.pause();
            prevController.seekTo(Duration.zero);

            // 前の動画が現在再生中の場合は、再生状態をクリア
            if (_currentPlayingVideo == prevPostIndex) {
              _currentPlayingVideo = null;
            }

            if (kDebugMode) {
              debugPrint(
                  '⏸️ 前の動画を停止: postId=${prevPost.id}, index=$previousIndex');
            }
          }
        }

        // 前の音声も停止（段階5）
        if (prevPost.postType == PostType.audio) {
          final prevPlayer = _audioPlayers[prevPostIndex];
          if (prevPlayer != null) {
            prevPlayer.pause();
            prevPlayer.seek(Duration.zero);

            // 前の音声が現在再生中の場合は、再生状態をクリア
            if (_currentPlayingAudio == prevPostIndex) {
              _currentPlayingAudio = null;
            }
          }
        }
      }
    }

    // 現在の投稿の動画を再生（段階4）
    _handleMediaPageChange(index);

    // 読み込み中プレースホルダー表示状態を判定
    final hasMoreContent = !_noMoreContent || _isLoadingMore;
    _isShowingLoadingPlaceholder = hasMoreContent && index == _posts.length;

    // 次のページを事前読み込み
    _preloadNextPages(index);

    // 余裕をもって追加コンテンツを読み込む
    if (_shouldTriggerPrefetch(index)) {
      if (kDebugMode) {
        debugPrint(
            '📄 読み込み条件チェック（余裕あり）: index=$index, posts=${_posts.length}, _hasMorePosts=$_hasMorePosts, _noMoreContent=$_noMoreContent');
      }
      _scheduleLoadMoreWithGrace();
    } else if (kDebugMode && index >= _posts.length - 3) {
      debugPrint(
          '📄 読み込みスキップ: index=$index, _isLoadingMore=$_isLoadingMore, _noMoreContent=$_noMoreContent');
    }
  }

  bool _shouldTriggerPrefetch(int index) {
    if (_posts.isEmpty) return false;
    final prefetchThreshold = _posts.length > 8 ? _posts.length - 8 : 0;
    return index >= prefetchThreshold;
  }

  /// メディアページ変更時の処理（段階4-5: 動画・音声の初期化・再生）
  Future<void> _handleMediaPageChange(int index) async {
    if (_isDisposed) return;

    final postIndex = _getActualPostIndex(index);
    if (postIndex == null) return;

    final post = _posts[postIndex];
    _recordPlayHistoryIfNeeded(post);

    // 動画コンテンツの場合（段階4）
    if (post.postType == PostType.video) {
      await _initializeVideoController(postIndex, post);

      // 逆スクロール時も確実に動画を再生するため、状態を再確認
      final currentPostIndex = _getActualPostIndex(_currentIndex);
      if (!_isDisposed && currentPostIndex == postIndex) {
        final controller = _videoControllers[postIndex];
        if (controller != null &&
            controller.value.isInitialized &&
            !controller.value.isPlaying) {
          _startVideoPlayback(postIndex);
          if (kDebugMode) {
            debugPrint('✅ 逆スクロール時の動画再生: postId=${post.id}, index=$postIndex');
          }
        }
      }
    }
    // 音声コンテンツの場合（段階5）
    else if (post.postType == PostType.audio) {
      await _initializeAudioPlayer(postIndex, post);
    }
  }

  void _recordPlayHistoryIfNeeded(Post post) {
    if (post.id.isEmpty) return;
    if (_lastRecordedPostId == post.id) return;
    _lastRecordedPostId = post.id;

    PostService.recordPlayHistory(post.id).then((success) {
      if (success && !_isDisposed) {
        final navigationProvider =
            Provider.of<NavigationProvider>(context, listen: false);
        navigationProvider.notifyProfileHistoryUpdated();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final targetPostId = navigationProvider.targetPostId;
    final targetPost = navigationProvider.targetPost;
    final currentNavIndex = navigationProvider.currentIndex;

    // 画面遷移時のメディア再生制御
    _handleNavigationMediaControl(currentNavIndex);

    if (kDebugMode) {
      debugPrint(
          '📱 [didChangeDependencies] targetPostId=$targetPostId, targetPost=${targetPost != null ? "存在(Id: ${targetPost.id})" : "null"}, _pendingTargetPostId=$_pendingTargetPostId');
    }

    if (targetPostId != null && targetPostId != _pendingTargetPostId) {
      _pendingTargetPostId = targetPostId;
      // targetPostが挿入された場合は、API呼び出しをスキップ
      final inserted = _insertProviderPostIfNeeded(targetPostId);
      if (kDebugMode) {
        debugPrint(
            '📱 [didChangeDependencies] _insertProviderPostIfNeeded結果: inserted=$inserted');
      }
      if (!inserted) {
        // targetPostが挿入されなかった場合のみ、APIから取得を試みる
        if (kDebugMode) {
          debugPrint(
              '📱 [didChangeDependencies] targetPostが挿入されなかったため、APIから取得を試みます: postId=$targetPostId');
        }
        _fetchTargetPost(targetPostId);
      } else {
        if (kDebugMode) {
          debugPrint(
              '📱 [didChangeDependencies] targetPostが挿入されたため、API呼び出しをスキップします');
        }
      }
      _schedulePendingTargetCheck();
    }
    _tryJumpToPendingTarget();
  }

  /// 画面遷移時のメディア再生制御
  void _handleNavigationMediaControl(int currentNavIndex) {
    // 初回呼び出し時は前回のインデックスを記録して終了
    if (_lastNavigationIndex == null) {
      _lastNavigationIndex = currentNavIndex;
      return;
    }

    // ナビゲーションインデックスが変更されていない場合は何もしない
    if (_lastNavigationIndex == currentNavIndex) {
      return;
    }

    // ホーム画面（インデックス0）から別画面に遷移した場合
    if (_lastNavigationIndex == 0 && currentNavIndex != 0) {
      if (kDebugMode) {
        debugPrint('📱 [画面遷移] ホーム画面から別画面に遷移: currentIndex=$currentNavIndex');
      }

      // 現在再生中の動画を記録して停止
      if (_currentPlayingVideo != null) {
        final controller = _videoControllers[_currentPlayingVideo];
        if (controller != null &&
            controller.value.isInitialized &&
            controller.value.isPlaying) {
          _lastPlayingVideoBeforeNavigation = _currentPlayingVideo;
        }
      }

      // 現在再生中の音声を記録して停止
      if (_currentPlayingAudio != null) {
        final player = _audioPlayers[_currentPlayingAudio];
        if (player != null && player.playing) {
          _lastPlayingAudioBeforeNavigation = _currentPlayingAudio;
        }
      }

      // すべての動画を確実に停止（裏で再生されている可能性があるため）
      _stopAllVideos();

      // すべての音声を確実に停止（裏で再生されている可能性があるため）
      _stopAllAudios();
    }
    // 別画面からホーム画面に戻った場合
    else if (_lastNavigationIndex != 0 && currentNavIndex == 0) {
      if (kDebugMode) {
        debugPrint(
            '📱 [画面遷移] 別画面からホーム画面に戻る: previousIndex=$_lastNavigationIndex');
      }

      // 現在表示中の投稿のメディアを自動再生
      if (!_isDisposed) {
        final currentPostIndex = _getActualPostIndex(_currentIndex);
        if (currentPostIndex != null) {
          final currentPost = _posts[currentPostIndex];

          // 前回再生していた動画がある場合、それが現在の投稿と同じなら再開
          if (_lastPlayingVideoBeforeNavigation != null &&
              _lastPlayingVideoBeforeNavigation == currentPostIndex &&
              currentPost.postType == PostType.video) {
            final controller =
                _videoControllers[_lastPlayingVideoBeforeNavigation!];
            if (controller != null &&
                controller.value.isInitialized &&
                !controller.value.isPlaying) {
              controller.play();
              _currentPlayingVideo = _lastPlayingVideoBeforeNavigation;
              if (kDebugMode) {
                debugPrint(
                    '▶️ [画面遷移] 動画を再開: index=$_lastPlayingVideoBeforeNavigation');
              }
            }
          } else if (currentPost.postType == PostType.video) {
            // 前回の動画と異なる場合は、現在の投稿の動画を再生
            _handleMediaPageChange(_currentIndex);
          }

          // 前回再生していた音声がある場合、それが現在の投稿と同じなら再開
          if (_lastPlayingAudioBeforeNavigation != null &&
              _lastPlayingAudioBeforeNavigation == currentPostIndex &&
              currentPost.postType == PostType.audio) {
            final player = _audioPlayers[_lastPlayingAudioBeforeNavigation!];
            if (player != null && !player.playing) {
              player.play();
              _currentPlayingAudio = _lastPlayingAudioBeforeNavigation;
              _startSeekBarUpdateTimerAudio();
              if (kDebugMode) {
                debugPrint(
                    '▶️ [画面遷移] 音声を再開: index=$_lastPlayingAudioBeforeNavigation');
              }
            }
          } else if (currentPost.postType == PostType.audio) {
            // 前回の音声と異なる場合は、現在の投稿の音声を再生
            _handleMediaPageChange(_currentIndex);
          }
        }
      }

      // 再開後はクリア（次回の遷移時に備える）
      _lastPlayingVideoBeforeNavigation = null;
      _lastPlayingAudioBeforeNavigation = null;
    }

    // 前回のナビゲーションインデックスを更新
    _lastNavigationIndex = currentNavIndex;
  }

  void _schedulePendingTargetCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) return;
      _tryJumpToPendingTarget();
    });
  }

  /// targetPostを挿入または更新（既に存在する場合は更新）
  /// 戻り値: 挿入または更新された場合はtrue、スキップされた場合はfalse
  bool _insertProviderPostIfNeeded(String postId) {
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);
    final providerPost = navigationProvider.targetPost;

    if (kDebugMode) {
      debugPrint('📱 [insertProviderPost] 開始: postId=$postId');
      debugPrint(
          '  - providerPost: ${providerPost != null ? "存在(Id: ${providerPost.id}, username: ${providerPost.username})" : "null"}');
      debugPrint('  - _posts.length: ${_posts.length}');
      debugPrint('  - 既存投稿のID: ${_posts.map((p) => p.id).toList()}');
    }

    if (providerPost == null) {
      if (kDebugMode) {
        debugPrint('📱 [insertProviderPost] providerPostがnullのため、スキップします');
      }
      return false;
    }

    if (providerPost.id != postId) {
      if (kDebugMode) {
        debugPrint(
            '📱 [insertProviderPost] providerPost.id(${providerPost.id}) != postId($postId)のため、スキップします');
      }
      return false;
    }

    // まずは、usernameやuserIconPathが空でもPostを挿入または更新する
    // これにより、少なくともコンテンツは表示される
    // 既存の投稿を探す
    final existingIndex =
        _posts.indexWhere((existing) => existing.id == postId);

    if (existingIndex >= 0) {
      // 既存の投稿がある場合、targetPostで更新
      if (kDebugMode) {
        debugPrint(
            '📱 [insertProviderPost] 既存の投稿を更新します: postId=$postId, index=$existingIndex');
        debugPrint(
            '  - 既存: username=${_posts[existingIndex].username}, userIconPath=${_posts[existingIndex].userIconPath}');
        debugPrint(
            '  - 更新後: username=${providerPost.username}, userIconPath=${providerPost.userIconPath}');
      }

      // 既存の投稿の動画コントローラーをクリア（mediaUrlが更新される可能性があるため）
      final oldPost = _posts[existingIndex];
      if (oldPost.postType == PostType.video) {
        final controller = _videoControllers[existingIndex];
        if (controller != null) {
          controller.removeListener(_onVideoPositionChanged);
          controller.pause();
          controller.dispose();
          _videoControllers.remove(existingIndex);
          _initializedVideos.remove(existingIndex);
          if (_currentPlayingVideo == existingIndex) {
            _currentPlayingVideo = null;
          }
          if (kDebugMode) {
            debugPrint(
                '📱 [insertProviderPost] 既存の動画コントローラーをクリアしました: index=$existingIndex');
          }
        }
      }

      setState(() {
        // 既存の投稿をtargetPostで置き換え
        _posts[existingIndex] = providerPost;
        // 既に存在するので、取得済みIDには追加しない
      });

      if (kDebugMode) {
        debugPrint(
            '📱 [insertProviderPost] 既存の投稿を更新しました: postId=$postId, username=${providerPost.username}');
      }
    } else {
      // 既存の投稿がない場合、新規に挿入
      _shiftMediaStateForInsertedIndex(0);
      setState(() {
        _posts.insert(0, providerPost);
        _addFetchedContentId(postId);
      });

      if (kDebugMode) {
        debugPrint(
            '📱 [insertProviderPost] targetPostを挿入しました: postId=$postId, username=${providerPost.username}, userIconPath=${providerPost.userIconPath}');
      }
    }

    // usernameやuserIconPathが空の場合、バックグラウンドでAPIから取得して更新する
    if (providerPost.username.isEmpty || providerPost.userIconPath.isEmpty) {
      if (kDebugMode) {
        debugPrint(
            '📱 [insertProviderPost] ユーザー情報が不完全なため、バックグラウンドで補完します: username=${providerPost.username}, userIconPath=${providerPost.userIconPath}');
      }
      // バックグラウンドでAPIから取得して更新（非同期で実行）
      _fetchTargetPost(postId).then((_) {
        if (kDebugMode) {
          debugPrint('📱 [insertProviderPost] バックグラウンド補完完了: postId=$postId');
        }
      }).catchError((e) {
        if (kDebugMode) {
          debugPrint(
              '⚠️ [insertProviderPost] バックグラウンド補完エラー: postId=$postId, error=$e');
        }
      });
    }

    return true;
  }

  Future<void> _fetchTargetPost(String postId) async {
    if (_isFetchingTargetPost) return;
    _isFetchingTargetPost = true;
    try {
      final post = await PostService.fetchContentById(postId);
      if (post == null || _isDisposed) return;

      // 既存の投稿を探す
      final existingIndex =
          _posts.indexWhere((existing) => existing.id == post.id);

      if (existingIndex >= 0) {
        // 既存の投稿がある場合、APIから取得した完全な情報で更新
        if (kDebugMode) {
          debugPrint(
              '📱 [fetchTargetPost] 既存の投稿を更新します: postId=$postId, index=$existingIndex');
          debugPrint(
              '  - 既存: username=${_posts[existingIndex].username}, userIconPath=${_posts[existingIndex].userIconPath}');
          debugPrint(
              '  - 更新後: username=${post.username}, userIconPath=${post.userIconPath}');
        }

        setState(() {
          _posts[existingIndex] = post;
        });
      } else {
        // 既存の投稿がない場合、新規に挿入
        _shiftMediaStateForInsertedIndex(0);
        setState(() {
          _posts.insert(0, post);
          _addFetchedContentId(post.id);
        });
      }

      _schedulePendingTargetCheck();
    } finally {
      _isFetchingTargetPost = false;
    }
  }

  void _tryJumpToPendingTarget() {
    if (_pendingTargetPostId == null || _posts.isEmpty || _isDisposed) return;
    final targetIndex =
        _posts.indexWhere((post) => post.id == _pendingTargetPostId);
    if (targetIndex < 0 || targetIndex >= _posts.length) return;

    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);
    final shouldOpenComments = navigationProvider.shouldOpenComments;
    final targetCommentId = navigationProvider.targetCommentId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed || !mounted) return;
      if (targetIndex >= _posts.length) return;
      if (!_pageController.hasClients) {
        _schedulePendingTargetCheck();
        return;
      }
      _pageController.jumpToPage(targetIndex);
      if (mounted) {
        setState(() {
          _currentIndex = targetIndex;
        });
      }
      _handleMediaPageChange(targetIndex);

      // コメント画面を開く必要がある場合
      if (shouldOpenComments && targetIndex < _posts.length) {
        final post = _posts[targetIndex];
        // 少し待ってからコメント画面を開く（投稿が表示されるのを待つ）
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isDisposed) {
            _handleCommentButton(post);
          }
        });
      }

      navigationProvider.clearTargetPostId();
      _pendingTargetPostId = null;
      if (kDebugMode) {
        debugPrint('📱 ナビゲーション: targetPostIdを表示しました (index=$targetIndex)');
        if (shouldOpenComments) {
          debugPrint('💬 コメント画面を開きます: commentID=$targetCommentId');
        }
      }
    });
  }

  /// インデックス0 などで投稿を挿入した際にメディア管理マップを再インデックス
  void _shiftMediaStateForInsertedIndex(int insertionIndex) {
    if (insertionIndex < 0) return;

    final shiftedVideoControllers = <int, VideoPlayerController>{};
    _videoControllers.forEach((index, controller) {
      final newIndex = index >= insertionIndex ? index + 1 : index;
      shiftedVideoControllers[newIndex] = controller;
    });
    _videoControllers
      ..clear()
      ..addAll(shiftedVideoControllers);

    final shiftedInitializedVideos = _initializedVideos
        .map((index) => index >= insertionIndex ? index + 1 : index)
        .toSet();
    _initializedVideos
      ..clear()
      ..addAll(shiftedInitializedVideos);

    final shiftedAudioPlayers = <int, AudioPlayer>{};
    _audioPlayers.forEach((index, player) {
      final newIndex = index >= insertionIndex ? index + 1 : index;
      shiftedAudioPlayers[newIndex] = player;
    });
    _audioPlayers
      ..clear()
      ..addAll(shiftedAudioPlayers);

    final shiftedInitializedAudios = _initializedAudios
        .map((index) => index >= insertionIndex ? index + 1 : index)
        .toSet();
    _initializedAudios
      ..clear()
      ..addAll(shiftedInitializedAudios);

    if (_currentPlayingVideo != null &&
        _currentPlayingVideo! >= insertionIndex) {
      _currentPlayingVideo = _currentPlayingVideo! + 1;
    }
    if (_lastPlayingVideoBeforeNavigation != null &&
        _lastPlayingVideoBeforeNavigation! >= insertionIndex) {
      _lastPlayingVideoBeforeNavigation =
          _lastPlayingVideoBeforeNavigation! + 1;
    }

    if (_currentPlayingAudio != null &&
        _currentPlayingAudio! >= insertionIndex) {
      _currentPlayingAudio = _currentPlayingAudio! + 1;
    }
    if (_lastPlayingAudioBeforeNavigation != null &&
        _lastPlayingAudioBeforeNavigation! >= insertionIndex) {
      _lastPlayingAudioBeforeNavigation =
          _lastPlayingAudioBeforeNavigation! + 1;
    }

    if (_currentIndex >= insertionIndex) {
      _currentIndex += 1;
    }
  }

  /// 動画コントローラーを初期化（段階4）
  Future<void> _initializeVideoController(int postIndex, Post post) async {
    if (_isDisposed || postIndex < 0 || postIndex >= _posts.length) return;

    // 既に初期化済みの場合は、再生状態を確認して再生
    if (_initializedVideos.contains(postIndex)) {
      final controller = _videoControllers[postIndex];
      if (controller != null && controller.value.isInitialized) {
        // 現在表示中の動画を確実に再生（逆スクロール時も対応）
        if (_currentIndex == postIndex) {
          if (!controller.value.isPlaying) {
            _startVideoPlayback(postIndex);
            if (kDebugMode) {
              debugPrint('✅ 既存動画を再生しました: postId=${post.id}, index=$postIndex');
            }
          }
        }
      }
      return;
    }

    final mediaUrl = post.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ 動画URLが空です: postId=${post.id}');
        debugPrint('   - link: ${post.link}');
        debugPrint('   - contentPath: ${post.contentPath}');
        debugPrint('   - mediaUrl: ${post.mediaUrl}');
      }

      // URLが空の場合でも、UIを更新してエラー状態を解除
      if (mounted) {
        setState(() {
          // エラー状態を記録（オプション：エラーメッセージを表示する場合）
        });
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('🎬 動画を初期化中: postId=${post.id}, url=$mediaUrl');
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(mediaUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
        ),
      );

      // 初期化にタイムアウトを設定（30秒）
      await controller.initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('❌ 動画の初期化がタイムアウトしました: postId=${post.id}');
          }
          controller.dispose();
          throw TimeoutException('動画の初期化がタイムアウトしました');
        },
      );

      if (_isDisposed || !mounted) {
        controller.dispose();
        return;
      }

      // リスナーを追加
      controller.addListener(_onVideoPositionChanged);
      _applyDefaultVideoSettings(controller);

      setState(() {
        _videoControllers[postIndex] = controller;
        _initializedVideos.add(postIndex);
      });

      // 現在表示中の動画を再生
      if (_currentIndex == postIndex) {
        _startVideoPlayback(postIndex);

        if (kDebugMode) {
          debugPrint('✅ 動画を初期化・再生しました: postId=${post.id}, index=$postIndex');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 動画の初期化に失敗しました: postId=${post.id}, error=$e');
        debugPrint('   - mediaUrl: $mediaUrl');
      }

      // エラー時にUIを更新（エラー状態を解除して再試行可能にする）
      if (mounted) {
        setState(() {
          // エラー状態を記録（オプション：エラーメッセージを表示する場合）
          // 初期化済みリストから削除して、次回再試行可能にする
          _initializedVideos.remove(postIndex);
          _videoControllers.remove(postIndex);
        });
      }
    }
  }

  /// 動画の位置変更リスナー（段階11でシークバー更新に使用）
  void _onVideoPositionChanged() {
    // 段階11でシークバー更新処理を実装
  }

  /// シークバー更新タイマーを開始（段階11で詳細実装）
  void _startSeekBarUpdateTimer() {
    _seekBarUpdateTimer?.cancel();
    _seekBarUpdateTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isDisposed || _currentPlayingVideo == null) {
        timer.cancel();
        return;
      }

      final controller = _videoControllers[_currentPlayingVideo];
      if (controller != null && controller.value.isInitialized) {
        // 段階11でシークバー更新処理を実装
        // setState(() { ... });
      }
    });
  }

  void _applyDefaultVideoSettings(VideoPlayerController controller) {
    if (!controller.value.isLooping) {
      controller.setLooping(true);
    }
    if (controller.value.volume != 1.0) {
      controller.setVolume(1.0);
    }
  }

  /// すべての動画を停止する
  void _stopAllVideos() {
    for (final entry in _videoControllers.entries) {
      final controller = entry.value;
      if (controller != null && controller.value.isInitialized) {
        if (controller.value.isPlaying) {
          controller.pause();
          controller.seekTo(Duration.zero);
          if (kDebugMode) {
            debugPrint('⏸️ すべての動画を停止: index=${entry.key}');
          }
        }
      }
    }
    _currentPlayingVideo = null;
  }

  /// すべての音声を停止する
  void _stopAllAudios() {
    for (final entry in _audioPlayers.entries) {
      final player = entry.value;
      if (player != null && player.playing) {
        player.pause();
        player.seek(Duration.zero);
        if (kDebugMode) {
          debugPrint('⏸️ すべての音声を停止: index=${entry.key}');
        }
      }
    }
    _currentPlayingAudio = null;
  }

  /// スクロール開始時の処理（動画・音声の停止・初期化）
  void _handleScrollStart() {
    if (_isDisposed) return;

    // 現在再生中の動画・音声を停止
    _stopAllVideos();
    _stopAllAudios();

    if (kDebugMode) {
      debugPrint('🛑 スクロール開始: すべての動画・音声を停止しました');
    }
  }

  /// 広告の数を計算
  ///
  /// [postCount]: 投稿の数
  /// 戻り値: 広告の数
  int _calculateAdCount(int postCount) {
    if (postCount < _adInterval) return 0;
    // 最初の広告は_adInterval番目の投稿の後に表示
    // その後は_adIntervalごとに表示
    return (postCount - 1) ~/ _adInterval;
  }

  /// 指定されたインデックスが広告のインデックスかどうかを判定
  ///
  /// [index]: PageViewのインデックス
  /// 戻り値: 広告のインデックス（広告の場合）、null（投稿の場合）
  int? _getAdIndex(int index) {
    if (index < _adInterval) return null; // 最初の_adInterval個は投稿

    // 広告の位置を計算
    // 最初の広告は_adInterval番目の投稿の後（index = _adInterval）
    // 2番目の広告は_adInterval * 2番目の投稿の後（index = _adInterval * 2 + 1）
    // 3番目の広告は_adInterval * 3番目の投稿の後（index = _adInterval * 3 + 2）
    // ...
    // n番目の広告は_adInterval * n番目の投稿の後（index = _adInterval * n + (n - 1)）

    // indexから広告の位置を逆算
    // index = _adInterval * n + (n - 1) = _adInterval * n + n - 1 = n * (_adInterval + 1) - 1
    // n * (_adInterval + 1) = index + 1
    // n = (index + 1) / (_adInterval + 1)

    final adNumber = (index + 1) ~/ (_adInterval + 1);
    final expectedAdIndex = adNumber * (_adInterval + 1) - 1;

    if (index == expectedAdIndex && adNumber > 0) {
      return adNumber - 1; // 広告のインデックス（0から始まる）
    }

    return null; // 投稿
  }

  /// 投稿のインデックスを計算（広告を考慮）
  ///
  /// [index]: PageViewのインデックス
  /// 戻り値: 投稿のインデックス
  int _getPostIndex(int index) {
    // 広告のインデックスかどうかを判定
    final adIndex = _getAdIndex(index);
    if (adIndex != null) {
      // 広告の場合は-1を返す（呼び出し側で処理）
      return -1;
    }

    // 投稿のインデックスを計算
    // 広告の数だけインデックスを調整
    final adCountBeforeIndex = _calculateAdCountBeforeIndex(index);
    return index - adCountBeforeIndex;
  }

  int _getPageIndexForPostIndex(int postIndex) {
    if (postIndex <= 0) return 0;
    final adCountBeforePost = postIndex ~/ _adInterval;
    return postIndex + adCountBeforePost;
  }

  /// 指定されたインデックスより前にある広告の数を計算
  ///
  /// [index]: PageViewのインデックス
  /// 戻り値: 広告の数
  int _calculateAdCountBeforeIndex(int index) {
    if (index < _adInterval) return 0;

    // 広告の位置を計算
    final adNumber = (index + 1) ~/ (_adInterval + 1);
    return adNumber;
  }

  /// PageViewのインデックスに対応する投稿のインデックスを返す（広告ならnull）
  int? _getActualPostIndex(int pageIndex) {
    final postIndex = _getPostIndex(pageIndex);
    if (postIndex < 0 || postIndex >= _posts.length) {
      return null;
    }
    return postIndex;
  }

  void _showLoadedContentIfOnPlaceholder(int previousPostCount) {
    if (_isDisposed || !_pageController.hasClients) return;
    final previousAdCount = _calculateAdCount(previousPostCount);
    final loadingPlaceholderPageIndex =
        previousPostCount + previousAdCount;
    final currentPageValue = _pageController.page;
    final currentPageIndex = currentPageValue?.round() ?? _currentIndex;

    if (currentPageIndex != loadingPlaceholderPageIndex) {
      return;
    }

    final targetPageIndex = _getPageIndexForPostIndex(previousPostCount);
    if (targetPageIndex == currentPageIndex) {
      return;
    }

    _pageController.jumpToPage(targetPageIndex);
    if (mounted) {
      setState(() {
        _currentIndex = targetPageIndex;
      });
    }
    _handleMediaPageChange(targetPageIndex);
  }

  void _startVideoPlayback(int index) {
    // 他の動画と音声をすべて停止してから再生
    _stopAllVideos();
    _stopAllAudios();

    final controller = _videoControllers[index];
    if (controller == null || !controller.value.isInitialized) return;
    _applyDefaultVideoSettings(controller);

    if (!controller.value.isPlaying) {
      controller.play();
    }

    _currentPlayingVideo = index;
    _startSeekBarUpdateTimer();

    if (mounted) {
      setState(() {});
    }
  }

  /// 次のページを事前読み込み（段階4: 動画プレイヤーの事前初期化）
  void _preloadNextPages(int currentIndex) {
    // 現在のインデックスから3つ先までを事前読み込み
    for (int i = currentIndex + 1;
        i <= currentIndex + 3 && i < _posts.length;
        i++) {
      final post = _posts[i];
      if (post.postType == PostType.video && !_initializedVideos.contains(i)) {
        // 動画の事前初期化（段階4）
        _initializeVideoController(i, post);
      }
    }

    // 前後3件以外の動画コントローラーをクリーンアップ
    _cleanupDistantControllers(currentIndex);

    if (kDebugMode && currentIndex % 5 == 0) {
      debugPrint('📄 現在のページ: $currentIndex / ${_posts.length}');
    }
  }

  /// 現在のインデックスから一定範囲外のコントローラーをクリーンアップ（段階4）
  void _cleanupDistantControllers(int currentIndex) {
    final videoControllerIndices = _videoControllers.keys.toList();
    for (final videoIndex in videoControllerIndices) {
      final distance = (videoIndex - currentIndex).abs();
      // 前後3件以外は破棄
      if (distance > 3 && videoIndex != currentIndex) {
        final controller = _videoControllers[videoIndex];
        if (controller != null) {
          controller.removeListener(_onVideoPositionChanged);
          controller.pause();
          controller.dispose();
        }
        _videoControllers.remove(videoIndex);
        _initializedVideos.remove(videoIndex);
      }
    }
  }

  void _scheduleLoadMoreWithGrace() {
    if (_isDisposed || _noMoreContent) return;
    if (_isLoadingMore) {
      if (!_hasQueuedLoadMore) {
        _hasQueuedLoadMore = true;
        if (kDebugMode) {
          debugPrint('🌀 スポットライト読み込みをキューに追加しました');
        }
      }
      return;
    }

    _loadMoreContents();
  }

  void _processQueuedLoadMore() {
    if (_isDisposed ||
        _hasQueuedLoadMore == false ||
        _isLoadingMore ||
        _noMoreContent) {
      return;
    }

    _hasQueuedLoadMore = false;
    if (kDebugMode) {
      debugPrint('🚀 キューから追加の読み込みを開始します');
    }

    Future.microtask(() {
      if (_isDisposed || _isLoadingMore || _noMoreContent) return;
      _loadMoreContents();
    });
  }

  /// 追加コンテンツを読み込む（段階3: 無限スクロール）
  Future<void> _loadMoreContents() async {
    if (_isDisposed || _isLoadingMore || _noMoreContent) {
      if (kDebugMode) {
        debugPrint(
            '📄 _loadMoreContents: スキップ (_isDisposed=$_isDisposed, _isLoadingMore=$_isLoadingMore, _noMoreContent=$_noMoreContent)');
      }
      return;
    }

    _wasShowingLoadingPlaceholderAtLoadStart = _isShowingLoadingPlaceholder;

    if (kDebugMode) {
      debugPrint(
          '📄 _loadMoreContents: 開始 (_hasMorePosts=$_hasMorePosts, posts=${_posts.length})');
    }

    // 読み込み開始時のインデックスを記録（読み込み完了時の自動遷移判定用）
    final loadingStartIndex = _currentIndex;
    double? currentPageValue;
    if (_pageController.hasClients) {
      currentPageValue = _pageController.page;
    }
    final loadingStartPageIndex = currentPageValue?.round() ?? _currentIndex;
    _loadingStartIndex = loadingStartPageIndex;

    final isViewingLoadingPlaceholder = (_pageController.hasClients
            ? (currentPageValue?.round() ?? _currentIndex)
            : _currentIndex) ==
        _posts.length;
    _wasShowingLoadingPlaceholderAtLoadStart =
        isViewingLoadingPlaceholder || _currentIndex >= _posts.length;

    setState(() {
      _isLoadingMore = true;
    });

    if (kDebugMode) {
      debugPrint(
          '📄 読み込み開始時のインデックス: _currentIndex=$_currentIndex, PageController.page=$currentPageValue, loadingStartPageIndex=$loadingStartPageIndex');
    }

    try {
      // 既に取得したコンテンツIDを除外するため、取得済みIDのリストを準備
      // 高頻度スクロール対応：除外IDを10件に制限（20件→10件に減らして、APIレスポンスと429エラーを改善）
      final excludeIds = _getRecentFetchedContentIds(limit: 10);
      final excludeIdsList = excludeIds.toList();

      if (kDebugMode) {
        debugPrint(
            '📄 除外ID数: ${excludeIdsList.length}件 (posts=${_posts.length})');
      }

      // PostServiceから追加の投稿を取得（既に取得したIDを除外）
      List<Post> fetchedPosts = [];

      // 初回は除外IDをそのまま使用して取得を試みる
      try {
        fetchedPosts =
            await PostService.fetchContents(excludeContentIDs: excludeIdsList);

        if (kDebugMode) {
          debugPrint('📄 初回取得: ${fetchedPosts.length}件');
        }
      } on TooManyRequestsException catch (e) {
        // 429エラー時は、待機せずに次回の読み込みを遅延させる（高頻度スクロール対応）
        if (kDebugMode) {
          debugPrint(
              '⚠️ 429エラー（レート制限）: 次回の読み込みを遅延させます（待機時間: ${e.retryAfterSeconds}秒）');
        }

        // 429エラー時は、次回の読み込みを許可するが、すぐには再試行しない
        _clearOldFetchedContentIds(keepRecent: 5); // 取得履歴をさらに削減

        setState(() {
          _isLoadingMore = false;
          // _noMoreContentはtrueにしない（次回の読み込みを許可するため）
          // _hasMorePostsもfalseにしない（次回の読み込みを許可するため）
        });
        _scheduleLoadMoreRetry(delaySeconds: e.retryAfterSeconds ?? 2);
        return; // 429エラー時は待機せずに即座に終了
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ 初回取得エラー: $e');
        }
        // エラー時も次回の読み込みを許可
        _clearOldFetchedContentIds(keepRecent: 5);
        setState(() {
          _isLoadingMore = false;
        });
        _scheduleLoadMoreRetry(delaySeconds: 5);
        return;
      }

      if (_isDisposed) return;

      // 空の結果の場合、すぐに除外IDなしで再試行（高頻度スクロール対応：1回のみ）
      if (fetchedPosts.isEmpty && !_isDisposed) {
        try {
          fetchedPosts = await PostService.fetchContents(excludeContentIDs: []);

          if (kDebugMode) {
            debugPrint('📄 除外IDなしで再取得: ${fetchedPosts.length}件');
          }

          // 除外IDなしでも空の場合は、取得履歴をクリアして次回の読み込みに備える
          if (fetchedPosts.isEmpty) {
            _clearOldFetchedContentIds(keepRecent: 5); // 取得履歴をさらに削減

            setState(() {
              _isLoadingMore = false;
              // _noMoreContentはtrueにしない（次回の読み込みを許可するため）
              // _hasMorePostsもfalseにしない（次回の読み込みを許可するため）
            });

            if (kDebugMode) {
              debugPrint('⚠️ 空の結果: 取得履歴をクリアして、次回の読み込みで再試行します。');
            }
            _scheduleLoadMoreRetry();
            return;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ 除外IDなしでの再取得エラー: $e');
          }

          // エラー時も次回の読み込みを許可
          _clearOldFetchedContentIds(keepRecent: 5);
          setState(() {
            _isLoadingMore = false;
          });
          return;
        }
      }

      if (fetchedPosts.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('📄 取得した投稿数: ${fetchedPosts.length}件');
        }
        // 重複除外処理
        final recentIds = _getRecentFetchedContentIds(limit: 50);
        final uniquePosts = <Post>[];
        for (final post in fetchedPosts) {
          if (!recentIds.contains(post.id)) {
            uniquePosts.add(post);
            _addFetchedContentId(post.id);
          }
        }

        if (uniquePosts.isEmpty) {
          // 新しいコンテンツがない場合は、ランダム取得を試みる
          if (kDebugMode) {
            debugPrint('⚠️ 新しいコンテンツが見つかりませんでした（すべて重複）、ランダム取得を試みます');
          }

          // ランダム投稿を取得して試みる
          try {
            final randomPosts = await PostService.fetchRandomPosts(limit: 5);
            if (randomPosts.isNotEmpty && !_isDisposed) {
              final randomUniquePosts = <Post>[];
              final existingIds = _posts.map((p) => p.id).toSet();
              for (final post in randomPosts) {
                if (!existingIds.contains(post.id) &&
                    !recentIds.contains(post.id)) {
                  randomUniquePosts.add(post);
                  _addFetchedContentId(post.id);
                }
              }

              if (randomUniquePosts.isNotEmpty && !_isDisposed) {
                // 読み込み完了時に、読み込み中のプレースホルダーから新しいコンテンツに自動遷移
                final previousPostCount = _posts.length;

                // PageControllerの現在のページを確認（実際の表示位置を取得）
                double? currentPageValue;
                if (_pageController.hasClients) {
                  currentPageValue = _pageController.page;
                }
                final currentPageIndex =
                    currentPageValue?.round() ?? _currentIndex;

                // 読み込み中のプレースホルダーを表示しているか確認
                final wasViewingLoadingPlaceholder =
                    currentPageIndex == previousPostCount ||
                        _currentIndex == previousPostCount;

                setState(() {
                  _posts.addAll(randomUniquePosts);
                  _isLoadingMore = false;
                  _hasMorePosts = randomUniquePosts.length >= 3;
                });
                _schedulePendingTargetCheck();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showLoadedContentIfOnPlaceholder(previousPostCount);
                });

                if (kDebugMode) {
                  debugPrint(
                      '✅ ランダム投稿を取得しました: ${randomUniquePosts.length}件（合計: ${_posts.length}件）');
                  debugPrint(
                      '📄 読み込み前の投稿数: $previousPostCount, 現在のインデックス: $_currentIndex, PageController.page: $currentPageValue, 実際のページ: $currentPageIndex, 読み込み中プレースホルダー表示中: $wasViewingLoadingPlaceholder');
                }

                // ランダム投稿取得後の自動遷移は行わない（勝手なスクロール防止）

                return;
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ ランダム投稿取得エラー: $e');
            }
          }

          // すべてのコンテンツを読み込み済みとして扱う
          setState(() {
            _hasMorePosts = false;
            _noMoreContent = true;
            _isLoadingMore = false;
          });

          if (kDebugMode) {
            debugPrint('⚠️ すべてのコンテンツを読み込み済みとして扱います');
          }
        } else {
          // 読み込み完了時に、読み込み中のプレースホルダーから新しいコンテンツに自動遷移
          final previousPostCount = _posts.length;

          // 読み込み開始時に読み込み中プレースホルダーが表示されていたかどうかを確認
          // プレースホルダーのインデックスは previousPostCount (_posts.length)
          final previousAdCount = _calculateAdCount(previousPostCount);
          final loadingPlaceholderPageIndex =
              previousPostCount + previousAdCount;
          final wasViewingLoadingPlaceholderAtStart =
              _loadingStartIndex != null &&
                  _loadingStartIndex == loadingPlaceholderPageIndex;

          // PageControllerの現在のページを確認（実際の表示位置を取得）
          double? currentPageValue;
          if (_pageController.hasClients) {
            currentPageValue = _pageController.page;
          }
          final currentPageIndex = currentPageValue?.round() ?? _currentIndex;

          // 現在のページも読み込み中プレースホルダーかどうかを確認
          final isCurrentlyViewingLoadingPlaceholder =
              currentPageIndex == loadingPlaceholderPageIndex ||
                  _currentIndex == loadingPlaceholderPageIndex;

          final shouldAutoNavigate = wasViewingLoadingPlaceholderAtStart ||
              isCurrentlyViewingLoadingPlaceholder;

          // 新しい投稿を追加
          setState(() {
            _posts.addAll(uniquePosts);
            _isLoadingMore = false;
            // 取得できた場合は続きがある可能性があると判断（より積極的に読み込む）
            // ただし、取得件数が少ない場合は、次回の読み込みで終了する可能性が高い
            _hasMorePosts = uniquePosts.length >= 3; // 3件以上取得できた場合は続きがあると判断
          });
          _schedulePendingTargetCheck();

          if (kDebugMode) {
            debugPrint(
                '✅ 追加コンテンツを取得しました: ${uniquePosts.length}件（合計: ${_posts.length}件）');
            debugPrint(
                '📄 状態更新: _hasMorePosts=$_hasMorePosts, _noMoreContent=$_noMoreContent');
            debugPrint(
                '📄 読み込み前の投稿数: $previousPostCount, 読み込み開始時のインデックス: $_loadingStartIndex');
            debugPrint(
                '📄 現在のインデックス: $_currentIndex, PageController.page: $currentPageValue, 実際のページ: $currentPageIndex');
            debugPrint(
                '📄 読み込み開始時に読み込み中プレースホルダー表示: $wasViewingLoadingPlaceholderAtStart');
            debugPrint(
                '📄 現在読み込み中プレースホルダー表示: $isCurrentlyViewingLoadingPlaceholder');
            debugPrint('📄 自動表示判定: shouldAutoNavigate=$shouldAutoNavigate');
          }

          if (uniquePosts.isNotEmpty && !_isDisposed && shouldAutoNavigate) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showLoadedContentIfOnPlaceholder(previousPostCount);
            });
          }
        }
      }
    } on TooManyRequestsException catch (e) {
      // 429エラー時は一時的なエラーとして扱い、次の読み込みを許可する
      if (kDebugMode) {
        debugPrint('⚠️ 429エラー（レート制限）: ${e.message}');
        debugPrint('   - 次回の読み込みで再試行します');
      }

      if (_isDisposed) return;

      setState(() {
        _isLoadingMore = false;
        // 429エラー時は「全てのコンテンツを読み込み済み」と判断しない
        // 一時的なエラーとして扱い、次回の読み込みを許可
        // _noMoreContentは変更しない（trueのままでも次回試行可能にする）
      });
      _scheduleLoadMoreRetry(delaySeconds: e.retryAfterSeconds ?? 2);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 追加コンテンツ取得エラー: $e');
      }

      if (_isDisposed) return;

      setState(() {
        _isLoadingMore = false;
        // エラー時は次の読み込みを試みることを許可
      });
      _scheduleLoadMoreRetry(delaySeconds: 5);
    } finally {
      _processQueuedLoadMore();
      _wasShowingLoadingPlaceholderAtLoadStart = false;
    }
  }

  void _scheduleLoadMoreRetry({int delaySeconds = 2}) {
    _loadMoreRetryTimer?.cancel();
    _loadMoreRetryTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_isDisposed || _isLoadingMore || _noMoreContent) return;
      final currentPageValue = _pageController.hasClients
          ? _pageController.page ?? _currentIndex
          : _currentIndex.toDouble();
      final isNearEnd = _currentIndex >= _posts.length - 1 ||
          currentPageValue >= _posts.length - 0.5;

      if (isNearEnd) {
        _loadMoreContents();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBody(),
          _buildSpotlightAnimationOverlay(),
        ],
      ),
    );
  }

  /// メインのボディを構築
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF6B35),
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'コンテンツがありません',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // itemCountの計算：投稿数 + 広告数 + 読み込み中のプレースホルダー
    // _noMoreContentがfalseの場合は、常に1つ余分に追加して読み込みを試みる
    // (_hasMorePostsがfalseでも、まだ読み込みを試みる必要がある)
    final hasMoreContent = !_noMoreContent || _isLoadingMore;
    final adCount = _calculateAdCount(_posts.length);
    final itemCount = _posts.length + adCount + (hasMoreContent ? 1 : 0);

    if (kDebugMode &&
        (_currentIndex % 5 == 0 || _currentIndex >= _posts.length - 3)) {
      debugPrint(
          '📄 PageView: itemCount=$itemCount, posts=${_posts.length}, hasMoreContent=$hasMoreContent, _hasMorePosts=$_hasMorePosts, _noMoreContent=$_noMoreContent, _isLoadingMore=$_isLoadingMore');
    }

    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        // スクロール開始時に動画・音声を停止・初期化
        _handleScrollStart();
        return false; // 通知を下に伝播させる
      },
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: itemCount,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          // 広告のインデックスかどうかを判定
          final adIndex = _getAdIndex(index);
          if (adIndex != null) {
            // 広告を表示
            return const NativeAdWidget();
          }

          // 投稿のインデックスを計算（広告を考慮）
          final postIndex = _getPostIndex(index);

          // 範囲外のインデックスの場合はプレースホルダーを表示
          if (postIndex < 0 || postIndex >= _posts.length) {
            // 最後のページ（読み込み中または続きがある場合）を表示
            final totalItems = _posts.length + adCount;
            if (index == totalItems && hasMoreContent) {
              return _buildLoadingPlaceholder();
            }
            return _buildOutOfRangePlaceholder();
          }

          final post = _posts[postIndex];
          return _buildPostItem(post, postIndex);
        },
      ),
    );
  }

  /// 範囲外のインデックス用プレースホルダー
  Widget _buildOutOfRangePlaceholder() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          '読み込み中...',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  /// 読み込み中プレースホルダー（段階3: 無限スクロール用）
  Widget _buildLoadingPlaceholder() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFFFF6B35),
            ),
            const SizedBox(height: 16),
            Text(
              '次のコンテンツを読み込み中...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 投稿アイテムを構築（段階4: 動画コンテンツ表示を追加、段階7: 上スワイプジェスチャー対応）
  Widget _buildPostItem(Post post, int index) {
    return GestureDetector(
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // コンテンツ表示（段階4-6）
            _buildPostContent(post, index),

            // 下部コントロール（段階2: 実装完了）
            _buildBottomControls(post),

            // シークバー（段階11: 動画・音声用）
            if ((post.postType == PostType.video &&
                    _currentIndex == index &&
                    _currentVideoPosition != null &&
                    _currentVideoDuration != null) ||
                (post.postType == PostType.audio &&
                    _currentIndex == index &&
                    _currentAudioPosition != null &&
                    _currentAudioDuration != null))
              Positioned(
                left: 0,
                right: 0,
                bottom: 60,
                child: post.postType == PostType.video
                    ? _buildSeekBar(
                        _videoControllers[index],
                        index,
                      )
                    : _buildAudioSeekBar(_audioPlayers[index]!, index),
              ),

            // 右上通報ボタン（段階10: 実装完了）
            Positioned(
              top: 40,
              right: 16,
              child: _buildReportButton(post),
            ),

            // 右側コントロール（段階7: 実装完了）
            Positioned(
              right: 16,
              bottom: 100,
              child: _buildRightBottomControls(post, index),
            ),
          ],
        ),
      ),
    );
  }

  /// 投稿コンテンツを構築（段階4-6: 動画・音声・画像・テキスト対応）
  Widget _buildPostContent(Post post, int index) {
    switch (post.postType) {
      case PostType.video:
        return _buildVideoContent(post, index);
      case PostType.audio:
        return _buildAudioContent(post, index);
      case PostType.image:
        return _buildImageContent(post, index);
      case PostType.text:
        return _buildTextContent(post, index);
    }
  }

  /// 動画コンテンツを構築（段階4）
  Widget _buildVideoContent(Post post, int index) {
    final controller = _videoControllers[index];

    // 動画が初期化されていない場合
    if (controller == null || !_initializedVideos.contains(index)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFFFF6B35),
            ),
            const SizedBox(height: 16),
            Text(
              '動画を読み込み中...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // 動画プレイヤーを表示
    if (!controller.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFFFF6B35),
            ),
            const SizedBox(height: 16),
            Text(
              '動画を初期化中...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // 動画の再生状態を監視してUIを更新（逆スクロール時も正しく表示）
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final isPlaying = value.isPlaying && value.isInitialized;

        return GestureDetector(
          onTap: () {
            // タップで再生/一時停止を切り替え
            if (isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
            // UIを更新
            if (mounted) {
              setState(() {});
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 動画プレイヤー
              Center(
                child: AspectRatio(
                  aspectRatio: _resolveVideoAspectRatio(value),
                  child: VideoPlayer(controller),
                ),
              ),

              // 再生/一時停止ボタン（オーバーレイ）- 再生中は非表示
              if (!isPlaying)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      size: 64,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _resolveVideoAspectRatio(VideoPlayerValue value) {
    final width = value.size.width;
    final height = value.size.height;

    if (width > 0 && height > 0) {
      return width / height;
    }

    if (value.aspectRatio > 0 && value.aspectRatio.isFinite) {
      return value.aspectRatio;
    }

    return 16 / 9;
  }

  /// 音声コンテンツを構築（段階5）
  Widget _buildAudioContent(Post post, int index) {
    final player = _audioPlayers[index];

    // 音声が初期化されていない場合
    if (player == null || !_initializedAudios.contains(index)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFFFF6B35),
            ),
            const SizedBox(height: 16),
            Text(
              '音声を読み込み中...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // 再生状態を監視
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final isPlaying = player.playing;
        final duration = player.duration ?? Duration.zero;
        final position = player.position;

        return GestureDetector(
          onTap: () {
            // タップで再生/一時停止を切り替え
            _toggleAudioPlayback(index);
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [
                  SpotLightColors.getSpotlightColor(2).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 音声視覚化エフェクト
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          SpotLightColors.getSpotlightColor(2)
                              .withOpacity(isPlaying ? 0.6 : 0.3),
                          SpotLightColors.getSpotlightColor(2)
                              .withOpacity(isPlaying ? 0.2 : 0.1),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: SpotLightColors.getSpotlightColor(2)
                              .withOpacity(isPlaying ? 0.5 : 0.2),
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
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 80,
                        color: SpotLightColors.getSpotlightColor(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 再生時間表示
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 音声プレイヤーを初期化（段階5）
  Future<void> _initializeAudioPlayer(int postIndex, Post post) async {
    if (_isDisposed || postIndex < 0 || postIndex >= _posts.length) return;

    // 既に初期化済みの場合はスキップ
    if (_initializedAudios.contains(postIndex)) {
      final player = _audioPlayers[postIndex];
      if (player != null) {
        // 現在表示中の音声を再生
        if (_currentIndex == postIndex && _currentPlayingAudio != postIndex) {
          // 他の動画と音声をすべて停止してから再生
          _stopAllVideos();
          _stopAllAudios();
          _currentPlayingAudio = postIndex;
          if (!player.playing) {
            player.play();
            _startSeekBarUpdateTimerAudio();
          }
        }
      }
      return;
    }

    // 音声のURLを決定
    String? mediaUrl = post.mediaUrl;

    // Post.fromJson で mediaUrl が設定されなかった場合でも、
    // contentPath にCloudFrontの完全URLが入っているケースがあるためフォールバックする
    if ((mediaUrl == null || mediaUrl.isEmpty) && post.contentPath.isNotEmpty) {
      mediaUrl = post.contentPath;
      if (kDebugMode) {
        debugPrint(
            '🎧 音声URLフォールバック: postId=${post.id}, contentPath=${post.contentPath} を使用します');
      }
    }

    if (mediaUrl == null || mediaUrl.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ 音声URLが空です: postId=${post.id}');
      }
      return;
    }

    try {
      final player = AudioPlayer();
      await player.setUrl(mediaUrl);

      if (_isDisposed || !mounted) {
        player.dispose();
        return;
      }

      setState(() {
        _audioPlayers[postIndex] = player;
        _initializedAudios.add(postIndex);
      });

      // 現在表示中の音声を再生
      if (_currentIndex == postIndex) {
        // 他の動画と音声をすべて停止してから再生
        _stopAllVideos();
        _stopAllAudios();
        _currentPlayingAudio = postIndex;
        player.play();
        _startSeekBarUpdateTimerAudio();

        if (kDebugMode) {
          debugPrint('✅ 音声を初期化・再生しました: postId=${post.id}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 音声の初期化に失敗しました: postId=${post.id}, error=$e');
      }
    }
  }

  /// 音声の再生/停止を切り替え（段階5）
  Future<void> _toggleAudioPlayback(int postIndex) async {
    final player = _audioPlayers[postIndex];
    if (player == null) return;

    if (player.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  /// 音声シークバー更新タイマーを開始（段階11で詳細実装）
  void _startSeekBarUpdateTimerAudio() {
    _seekBarUpdateTimerAudio?.cancel();
    _seekBarUpdateTimerAudio =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isDisposed || _currentPlayingAudio == null) {
        timer.cancel();
        return;
      }

      final player = _audioPlayers[_currentPlayingAudio];
      if (player != null) {
        // 段階11でシークバー更新処理を実装
        // setState(() { ... });
      }
    });
  }

  /// 時間をフォーマット（段階5）
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 動画用シークバーを構築（段階11）
  Widget _buildSeekBar(VideoPlayerController? controller, int index) {
    if (controller == null ||
        !controller.value.isInitialized ||
        _currentVideoDuration == null ||
        _currentVideoPosition == null ||
        _currentVideoDuration!.inMilliseconds == 0) {
      return const SizedBox.shrink();
    }

    final progress = _currentVideoPosition!.inMilliseconds /
        _currentVideoDuration!.inMilliseconds;

    return GestureDetector(
      onHorizontalDragStart: (details) {
        _startSeeking(controller);
      },
      onHorizontalDragUpdate: (details) {
        _updateSeeking(details, controller);
      },
      onHorizontalDragEnd: (details) {
        _endSeeking(controller);
      },
      onTapDown: (details) {
        if (controller.value.isInitialized) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) {
            final tapPosition = details.localPosition.dx;
            final width = box.size.width;
            final newPosition = Duration(
                milliseconds: (tapPosition /
                        width *
                        _currentVideoDuration!.inMilliseconds)
                    .round());
            controller.seekTo(newPosition);
            setState(() {
              _currentVideoPosition = newPosition;
            });
          }
        }
      },
      child: Container(
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: [
            // 進捗バー
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: SpotLightColors.getSpotlightColor(0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 音声用シークバーを構築（段階11）
  Widget _buildAudioSeekBar(AudioPlayer player, int index) {
    if (_currentAudioDuration == null ||
        _currentAudioPosition == null ||
        _currentAudioDuration!.inMilliseconds == 0) {
      return const SizedBox.shrink();
    }

    final progress = _currentAudioPosition!.inMilliseconds /
        _currentAudioDuration!.inMilliseconds;

    return GestureDetector(
      onHorizontalDragStart: (details) {
        _startSeekingAudio(player);
      },
      onHorizontalDragUpdate: (details) {
        _updateSeekingAudio(details, player);
      },
      onHorizontalDragEnd: (details) {
        _endSeekingAudio(player);
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && _currentAudioDuration != null) {
          final tapPosition = details.localPosition.dx;
          final width = box.size.width;
          final newPosition = Duration(
              milliseconds:
                  (tapPosition / width * _currentAudioDuration!.inMilliseconds)
                      .round());
          player.seek(newPosition);
          setState(() {
            _currentAudioPosition = newPosition;
          });
        }
      },
      child: Container(
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: [
            // 進捗バー
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: SpotLightColors.getSpotlightColor(2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// シーク開始（段階11）
  void _startSeeking(VideoPlayerController controller) {
    setState(() {
      _isSeeking = true;
    });
    controller.pause();
  }

  /// シーク中（段階11）
  void _updateSeeking(
      DragUpdateDetails details, VideoPlayerController controller) {
    if (!controller.value.isInitialized || _currentVideoDuration == null)
      return;

    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      final delta = details.localPosition.dx -
          (details.globalPosition.dx - details.globalPosition.dx);
      final width = box.size.width;
      final newPosition = Duration(
          milliseconds: ((details.localPosition.dx / width) *
                  _currentVideoDuration!.inMilliseconds)
              .round()
              .clamp(0, _currentVideoDuration!.inMilliseconds));

      setState(() {
        _currentVideoPosition = newPosition;
      });
    }
  }

  /// シーク終了（段階11）
  void _endSeeking(VideoPlayerController controller) {
    if (_currentVideoPosition != null && controller.value.isInitialized) {
      controller.seekTo(_currentVideoPosition!);
      controller.play();
    }
    setState(() {
      _isSeeking = false;
    });
  }

  /// 音声シーク開始（段階11）
  void _startSeekingAudio(AudioPlayer player) {
    setState(() {
      _isSeekingAudio = true;
    });
    player.pause();
  }

  /// 音声シーク中（段階11）
  void _updateSeekingAudio(DragUpdateDetails details, AudioPlayer player) {
    if (_currentAudioDuration == null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      final newPosition = Duration(
          milliseconds: ((details.localPosition.dx / box.size.width) *
                  _currentAudioDuration!.inMilliseconds)
              .round()
              .clamp(0, _currentAudioDuration!.inMilliseconds));

      setState(() {
        _currentAudioPosition = newPosition;
      });
    }
  }

  /// 音声シーク終了（段階11）
  void _endSeekingAudio(AudioPlayer player) {
    if (_currentAudioPosition != null) {
      player.seek(_currentAudioPosition!);
      player.play();
    }
    setState(() {
      _isSeekingAudio = false;
    });
  }

  /// 画像コンテンツを構築（段階6）
  Widget _buildImageContent(Post post, int index) {
    final mediaUrl = post.mediaUrl ?? post.thumbnailUrl;

    if (mediaUrl == null || mediaUrl.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              '画像がありません',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // タップで画像を全画面表示（段階12で実装）
      },
      child: Center(
        child: CachedNetworkImage(
          imageUrl: mediaUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFFFF6B35),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '画像を読み込み中...',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '画像の読み込みに失敗しました',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// テキストコンテンツを構築（段階6）
  Widget _buildTextContent(Post post, int index) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル
            Text(
              post.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            // コンテンツ
            if (post.content != null && post.content!.isNotEmpty)
              Text(
                post.content!,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 18,
                  height: 1.6,
                ),
              ),
            // リンクがある場合
            if (post.link != null && post.link!.isNotEmpty) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  // リンクを開く（段階12で実装）
                  if (kDebugMode) {
                    debugPrint('🔗 リンクを開く: ${post.link}');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        SpotLightColors.getSpotlightColor(0).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SpotLightColors.getSpotlightColor(0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.link,
                        color: SpotLightColors.getSpotlightColor(0),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'リンクを開く',
                        style: TextStyle(
                          color: SpotLightColors.getSpotlightColor(0),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 投稿タイプに応じたアイコンを取得
  IconData _getPostTypeIcon(PostType type) {
    switch (type) {
      case PostType.video:
        return Icons.videocam;
      case PostType.image:
        return Icons.image;
      case PostType.audio:
        return Icons.audiotrack;
      case PostType.text:
        return Icons.text_fields;
    }
  }

  /// 下部コントロール（段階2: 実装完了）
  Widget _buildBottomControls(Post post) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom + 12;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: bottomPadding,
        ),
        child: Container(
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
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 420;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (kDebugMode) {
                          debugPrint('👤 ユーザープロフィール画面に遷移: ${post.username}');
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(
                              userId: post.userId.isEmpty ? '' : post.userId,
                              username: post.username,
                              userIconUrl: post.userIconUrl,
                              userIconPath: post.userIconPath,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: isWide ? 22 : 18,
                            backgroundColor:
                                SpotLightColors.getSpotlightColor(0),
                            child: ClipOval(
                              child: post.userIconUrl != null &&
                                      post.userIconUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: post.userIconUrl!,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 96,
                                      memCacheHeight: 96,
                                      placeholder: (context, url) => Container(
                                        color:
                                            SpotLightColors.getSpotlightColor(
                                                0),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        color:
                                            SpotLightColors.getSpotlightColor(
                                                0),
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color:
                                          SpotLightColors.getSpotlightColor(0),
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        post.username,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getTimeAgo(post.createdAt.toLocal()),
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _ScrollingTitle(
                                  text: post.title,
                                  style: TextStyle(
                                    color: Colors.grey[100],
                                    fontSize: isWide ? 16 : 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 相対時間を取得
  String _getTimeAgo(DateTime dateTime) {
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
  }

  /// 右側コントロールボタンを構築（段階7）
  Widget _buildRightBottomControls(Post post, int index) {
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
          onTap: () => _handleSpotlightButton(post, index),
        ),
        const SizedBox(height: 20),
        // コメントボタン（段階8: 実装完了）
        _buildControlButton(
          icon: Icons.chat_bubble_outline,
          color: Colors.white,
          label: '${post.comments}',
          onTap: () => _handleCommentButton(post),
        ),
        const SizedBox(height: 20),
        // プレイリスト追加ボタン（段階9: 実装完了）
        _buildControlButton(
          icon: Icons.playlist_add,
          color: Colors.white,
          onTap: () => _handlePlaylistButton(post, index),
        ),
        const SizedBox(height: 20),
        // 共有ボタン（段階9: 実装完了）
        _buildControlButton(
          icon: Icons.share,
          color: Colors.white,
          onTap: () => _handleShareButton(post, index),
        ),
      ],
    );
  }

  /// コントロールボタンを構築（段階7）
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
          crossAxisAlignment: CrossAxisAlignment.center,
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
            if (label != null && label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// スポットライトボタンの処理（段階7）
  Future<void> _handleSpotlightButton(Post post, int index) async {
    if (_isSpotlighting) return;

    await _executeSpotlight(post, index);
  }

  /// スポットライト実行（段階7）
  Future<void> _executeSpotlight(Post post, int index) async {
    if (_isSpotlighting || post.id.isEmpty) return;

    setState(() {
      _isSpotlighting = true;
    });

    final isCurrentlySpotlighted = post.isSpotlighted;

    try {
      // バックエンドAPIを呼び出し
      final success = isCurrentlySpotlighted
          ? await PostService.spotlightOff(post.id)
          : await PostService.spotlightOn(post.id);

      if (_isDisposed) return;

      if (success) {
        // 投稿のスポットライト状態を更新
        final postIndex = _posts.indexWhere((p) => p.id == post.id);
        if (postIndex >= 0 && postIndex < _posts.length) {
          setState(() {
            _posts[postIndex] = Post(
              id: post.id,
              userId: post.userId,
              username: post.username,
              userIconPath: post.userIconPath,
              userIconUrl: post.userIconUrl,
              title: post.title,
              content: post.content,
              contentPath: post.contentPath,
              type: post.type,
              mediaUrl: post.mediaUrl,
              thumbnailUrl: post.thumbnailUrl,
              likes: isCurrentlySpotlighted ? post.likes - 1 : post.likes + 1,
              playNum: post.playNum,
              link: post.link,
              comments: post.comments,
              shares: post.shares,
              isSpotlighted: !isCurrentlySpotlighted,
              isText: post.isText,
              nextContentId: post.nextContentId,
              createdAt: post.createdAt,
            );
          });

          if (!isCurrentlySpotlighted) {
            _playSpotlightAnimation();
          }

          if (kDebugMode) {
            debugPrint(
                '✅ スポットライト${!isCurrentlySpotlighted ? "ON" : "OFF"}: postId=${post.id}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ スポットライト処理に失敗しました: postId=${post.id}');
        }
        // エラーメッセージを表示（オプション）
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('スポットライト処理に失敗しました'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ スポットライト処理エラー: $e');
      }
    } finally {
      if (_isDisposed) return;
      setState(() {
        _isSpotlighting = false;
      });
    }
  }

  void _playSpotlightAnimation() {
    if (!mounted) return;
    _spotlightAnimationController.stop();
    _spotlightAnimationController.forward(from: 0);
  }

  Widget _buildSpotlightAnimationOverlay() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _spotlightAnimation,
        builder: (context, child) {
          if (_spotlightAnimationController.isDismissed) {
            return const SizedBox.shrink();
          }
          final t = _spotlightAnimation.value;
          final opacity = (1 - t).clamp(0.0, 1.0);
          return LayoutBuilder(
            builder: (context, constraints) {
              final maxSize =
                  math.max(constraints.maxWidth, constraints.maxHeight) * 1.6;
              return Center(
                child: Opacity(
                  opacity: opacity * 0.6,
                  child: Transform.scale(
                    scale: 0.2 + t * 1.4,
                    child: Container(
                      width: maxSize,
                      height: maxSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// プレイリストボタンの処理（段階9）
  Future<void> _handlePlaylistButton(Post post, int index) async {
    if (kDebugMode) {
      debugPrint('📂 プレイリストボタン: postId=${post.id}');
    }

    try {
      // プレイリスト一覧を取得
      final playlists = await PlaylistService.getPlaylists();

      if (!mounted) return;

      // プレイリスト選択ダイアログを表示
      _showPlaylistDialog(post, playlists);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ プレイリスト取得エラー: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('プレイリストの取得に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// プレイリスト選択ダイアログを表示（段階9）
  void _showPlaylistDialog(Post post, List<dynamic> playlists) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PlaylistDialog(
        post: post,
        playlists: playlists,
        onCreateNew: () {
          Navigator.of(context).pop();
          _showCreatePlaylistDialog(post);
        },
      ),
    );
  }

  /// 新規プレイリスト作成ダイアログを表示（段階9）
  void _showCreatePlaylistDialog(Post post) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
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
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
            filled: true,
            fillColor: Colors.grey[900],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              Navigator.of(context).pop();

              try {
                var playlistId = await PlaylistService.createPlaylist(title);
                if ((playlistId == null || playlistId <= 0) && mounted) {
                  // playlistidが返らなかった／0だった場合、取得して一致するタイトルを探す
                  final refreshed = await PlaylistService.getPlaylists();
                  final matched = refreshed.firstWhere(
                    (item) => item.title.trim() == title && item.playlistid > 0,
                    orElse: () =>
                        Playlist(playlistid: 0, title: '', thumbnailpath: null),
                  );
                  playlistId =
                      matched.playlistid > 0 ? matched.playlistid : null;
                }

                if (playlistId != null && mounted) {
                  final success = await PlaylistService.addContentToPlaylist(
                    playlistId,
                    post.id,
                  );

                  if (mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('プレイリストに追加しました'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('プレイリストへの追加に失敗しました'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('エラーが発生しました: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              '作成',
              style: TextStyle(color: Color(0xFFFF6B35)),
            ),
          ),
        ],
      ),
    );
  }

  /// 共有ボタンの処理（段階9）
  Future<void> _handleShareButton(Post post, int index) async {
    if (kDebugMode) {
      debugPrint('🔗 共有ボタン: postId=${post.id}');
    }

    // 共有オプションを表示
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '共有',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildShareOption(
              icon: Icons.content_copy,
              title: 'リンクをコピー',
              onTap: () {
                Navigator.of(context).pop();
                _copyLinkToClipboard(post);
              },
            ),
            const SizedBox(height: 8),
            _buildShareOption(
              icon: Icons.share,
              title: 'その他の方法で共有',
              onTap: () {
                Navigator.of(context).pop();
                _shareWithSystem(post);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 共有オプションを構築（段階9）
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

  /// アプリ内ディープリンクおよび表示用のWeb URLを生成
  String _buildDeepLink(Post post) {
    return ShareLinkService.buildPostDeepLink(post.id);
  }

  /// リンクをクリップボードにコピー（段階9）
  void _copyLinkToClipboard(Post post) {
    final shareUrl = ShareLinkService.buildPostDeepLink(post.id);

    Clipboard.setData(ClipboardData(text: shareUrl));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('リンクをコピーしました'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// システム共有機能を使用（段階9）
  void _shareWithSystem(Post post) {
    final shareText =
        ShareLinkService.buildPostShareText(post.title, post.id);
    Share.share(
      shareText,
      subject: post.title,
      sharePositionOrigin: _getSharePositionOrigin(),
    );
  }

  Rect _getSharePositionOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final origin = box.localToGlobal(Offset.zero);
      return origin & box.size;
    }
    final size = MediaQuery.of(context).size;
    return Rect.fromCenter(
      center: size.center(Offset.zero),
      width: 1,
      height: 1,
    );
  }

  /// コメントボタンの処理（段階8）
  Future<void> _handleCommentButton(Post post) async {
    if (kDebugMode) {
      debugPrint('💬 コメントボタン: postId=${post.id}');
    }
    if (_isCommentSheetVisible) {
      if (kDebugMode) {
        debugPrint('⚠️ コメントシートは既に開いています');
      }
      return;
    }
    _isCommentSheetVisible = true;

    final commentController = TextEditingController();
    bool isLoading = true;
    bool hasRequestedComments = false;
    bool isSheetOpen = true;
    List<Comment> comments = [];
    int? replyingToCommentId;

    Future<List<Comment>> refreshComments(StateSetter setModalState) async {
      if (!isSheetOpen) {
        return comments;
      }
      try {
        setModalState(() {
          if (isSheetOpen) {
            isLoading = true;
          }
        });
      } catch (e) {
        return comments;
      }

      if (post.id.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ refreshComments: 投稿IDが空です');
        }
        return comments;
      }

      final currentPostIndex = _getActualPostIndex(_currentIndex);
      if (currentPostIndex != null) {
        final currentPost = _posts[currentPostIndex];
        if (currentPost.id != post.id) {
          if (kDebugMode) {
            debugPrint('⚠️ refreshComments: データの不一致を検出');
            debugPrint('  - 期待されるpostId: ${post.id}');
            debugPrint('  - 実際のpostId: ${currentPost.id}');
            debugPrint('  - 期待されるusername: ${post.username}');
            debugPrint('  - 実際のusername: ${currentPost.username}');
          }
          final fetchedComments =
              await CommentService.getComments(currentPost.id);
          if (!mounted || !isSheetOpen) {
            return comments;
          }
          try {
            setModalState(() {
              if (isSheetOpen) {
                comments = fetchedComments;
                isLoading = false;
              }
            });
          } catch (e) {
            return comments;
          }
          return fetchedComments;
        }
      }

      final fetchedComments = await CommentService.getComments(post.id);
      if (!mounted || !isSheetOpen) {
        return comments;
      }
      try {
        setModalState(() {
          if (isSheetOpen) {
            comments = fetchedComments;
            isLoading = false;
          }
        });
      } catch (e) {
        return comments;
      }

      if (kDebugMode) {
        debugPrint('💬 コメント一覧を更新: ${fetchedComments.length}件の親コメント');
        final totalCount = _countAllComments(fetchedComments);
        debugPrint('💬 コメント総数（返信含む）: $totalCount件');
      }

      return fetchedComments;
    }

    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              if (!isSheetOpen) {
                return const SizedBox.shrink();
              }

              if (!hasRequestedComments) {
                hasRequestedComments = true;
                refreshComments(setModalState);
              }

              return DraggableScrollableSheet(
                initialChildSize: 0.7,
                minChildSize: 0.5,
                maxChildSize: 0.9,
                builder: (context, scrollController) {
                  final keyboardHeight =
                      MediaQuery.of(context).viewInsets.bottom;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Container(
                      padding: EdgeInsets.only(
                        top: 20,
                        left: 20,
                        right: 20,
                        bottom: 20 + keyboardHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                onPressed: () async {
                                  FocusScope.of(context).unfocus();
                                  await Future.delayed(
                                      const Duration(milliseconds: 100));
                                  if (mounted) {
                                    isSheetOpen = false;
                                    Navigator.pop(context);
                                  }
                                },
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
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
                                          final comment = comments[index];
                                          return _buildCommentItem(
                                            comment,
                                            replyingToCommentId:
                                                replyingToCommentId,
                                            onReplyPressed: (commentId) {
                                              if (!isSheetOpen) return;
                                              setModalState(() {
                                                if (isSheetOpen) {
                                                  if (replyingToCommentId ==
                                                      commentId) {
                                                    replyingToCommentId = null;
                                                    commentController.clear();
                                                  } else {
                                                    replyingToCommentId =
                                                        commentId;
                                                    commentController.clear();
                                                  }
                                                }
                                              });
                                            },
                                            onReportPressed: (selectedComment) {
                                              _showCommentReportDialog(
                                                selectedComment,
                                                post,
                                              );
                                            },
                                          );
                                        },
                                      ),
                          ),
                          if (replyingToCommentId != null)
                            Builder(
                              builder: (context) {
                                Comment? replyingToComment;
                                void findComment(List<Comment> commentList) {
                                  for (final comment in commentList) {
                                    if (comment.commentID ==
                                        replyingToCommentId) {
                                      replyingToComment = comment;
                                      return;
                                    }
                                    if (comment.replies.isNotEmpty) {
                                      findComment(comment.replies);
                                    }
                                  }
                                }

                                findComment(comments);

                                if (replyingToComment == null) {
                                  return const SizedBox.shrink();
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFFF6B35)
                                          .withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF6B35),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.reply,
                                                  color: Color(0xFFFF6B35),
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  replyingToComment!.username,
                                                  style: const TextStyle(
                                                    color: Color(0xFFFF6B35),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              replyingToComment!.commenttext,
                                              style: TextStyle(
                                                color: Colors.grey[300],
                                                fontSize: 12,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          if (!isSheetOpen) return;
                                          setModalState(() {
                                            if (isSheetOpen) {
                                              replyingToCommentId = null;
                                              commentController.clear();
                                            }
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.grey,
                                          size: 18,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Color(0xFFFF6B35),
                                  child: Icon(Icons.person,
                                      size: 16, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: isSheetOpen
                                      ? TextField(
                                          controller: commentController,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration: InputDecoration(
                                            hintText:
                                                replyingToCommentId != null
                                                    ? '返信を入力...'
                                                    : 'コメントを追加...',
                                            hintStyle: TextStyle(
                                                color: Colors.grey[400]),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey[800],
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  onPressed: () async {
                                    if (!isSheetOpen) return;
                                    final commentText =
                                        commentController.text.trim();
                                    if (commentText.isEmpty) return;

                                    try {
                                      setModalState(() {
                                        if (isSheetOpen) {
                                          isLoading = true;
                                        }
                                      });
                                    } catch (e) {
                                      return;
                                    }

                                    final success =
                                        await CommentService.addComment(
                                      post.id,
                                      commentText,
                                      parentCommentId: replyingToCommentId,
                                    );

                                    if (!isSheetOpen || !mounted) return;

                                    if (success) {
                                      final wasReplying =
                                          replyingToCommentId != null;

                                      commentController.clear();

                                      try {
                                        setModalState(() {
                                          if (isSheetOpen) {
                                            replyingToCommentId = null;
                                          }
                                        });
                                      } catch (e) {
                                        return;
                                      }

                                      if (wasReplying) {
                                        await Future.delayed(
                                            const Duration(milliseconds: 500));
                                      } else {
                                        await Future.delayed(
                                            const Duration(milliseconds: 200));
                                      }

                                      final updatedComments =
                                          await refreshComments(setModalState);
                                      if (!isSheetOpen || !mounted) return;

                                      final updatedTotal =
                                          _countAllComments(updatedComments);

                                      if (kDebugMode) {
                                        debugPrint(
                                            '💬 ${wasReplying ? "返信" : "コメント"}追加後のコメント数: $updatedTotal件');
                                        final currentPostIndex =
                                            _getActualPostIndex(_currentIndex);
                                        if (currentPostIndex != null) {
                                          final currentPost =
                                              _posts[currentPostIndex];
                                          debugPrint(
                                              '💬 現在の投稿のコメント数: ${currentPost.comments}件');
                                          debugPrint(
                                              '💬 現在の投稿ID: ${currentPost.id}');
                                          debugPrint(
                                              '💬 現在の投稿username: ${currentPost.username}');
                                        }
                                        debugPrint(
                                            '💬 更新後のコメント一覧: ${updatedComments.length}件の親コメント');
                                        if (wasReplying) {
                                          debugPrint('💬 返信追加後のコメント一覧を更新しました');
                                        }
                                      }

                                      if (mounted && !_isDisposed) {
                                        final currentPostIndex =
                                            _getActualPostIndex(_currentIndex);
                                        if (currentPostIndex != null) {
                                          final currentPost =
                                              _posts[currentPostIndex];
                                          if (currentPost.id == post.id &&
                                              currentPost.id.isNotEmpty) {
                                            setState(() {
                                              _posts[currentPostIndex] = Post(
                                                id: currentPost.id,
                                                userId: currentPost.userId,
                                                username: currentPost.username,
                                                userIconPath:
                                                    currentPost.userIconPath,
                                                userIconUrl:
                                                    currentPost.userIconUrl,
                                                title: currentPost.title,
                                                content: currentPost.content,
                                                contentPath:
                                                    currentPost.contentPath,
                                                type: currentPost.type,
                                                mediaUrl: currentPost.mediaUrl,
                                                thumbnailUrl:
                                                    currentPost.thumbnailUrl,
                                                likes: currentPost.likes,
                                                playNum: currentPost.playNum,
                                                link: currentPost.link,
                                                comments: updatedTotal,
                                                shares: currentPost.shares,
                                                isSpotlighted:
                                                    currentPost.isSpotlighted,
                                                isText: currentPost.isText,
                                                nextContentId:
                                                    currentPost.nextContentId,
                                                createdAt:
                                                    currentPost.createdAt,
                                              );
                                            });
                                          } else if (kDebugMode) {
                                            debugPrint('⚠️ コメント追加: データの不一致を検出');
                                            debugPrint(
                                                '  - 期待されるpostId: ${post.id}');
                                            debugPrint(
                                                '  - 実際のpostId: ${currentPost.id}');
                                            debugPrint(
                                                '  - 期待されるusername: ${post.username}');
                                            debugPrint(
                                                '  - 実際のusername: ${currentPost.username}');
                                          }
                                        } else if (kDebugMode) {
                                          debugPrint(
                                              '⚠️ コメント追加: 広告などで表示中の投稿が検出できません (ページindex=$_currentIndex, posts=${_posts.length})');
                                        }
                                      }
                                    } else {
                                      try {
                                        setModalState(() {
                                          if (isSheetOpen) {
                                            isLoading = false;
                                          }
                                        });
                                      } catch (e) {
                                        return;
                                      }
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
    } finally {
      isSheetOpen = false;
      _isCommentSheetVisible = false;
      try {
        commentController.dispose();
      } catch (_) {}
    }
  }

  int _countAllComments(List<Comment> commentList) {
    var total = 0;
    for (final comment in commentList) {
      total++; // 親コメントをカウント
      if (comment.replies.isNotEmpty) {
        total += _countAllComments(comment.replies);
      }
    }
    if (kDebugMode) {
      debugPrint('💬 コメント数カウント: 親コメント=${commentList.length}件, 合計=$total件');
    }
    return total;
  }

  /// 通報ボタンを構築（段階10）
  Widget _buildReportButton(Post post) {
    return GestureDetector(
      onTap: () => _showReportDialog(post),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.flag_outlined,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  /// 投稿通報ダイアログを表示（段階10）
  void _showReportDialog(Post post) {
    // 自分の投稿かどうかをチェック
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final postUserId = post.userId;

    if (currentUserId != null &&
        postUserId.isNotEmpty &&
        currentUserId.toString().trim() == postUserId.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('自分の投稿は通報できません'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _ReportDialog(post: post),
    );
  }

  /// コメント通報ダイアログを表示（段階10: _HomeScreenState用）
  void _showCommentReportDialog(Comment comment, Post post) {
    // 自分のコメントかどうかをチェック
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final commentUserId = comment.userId;

    if (currentUserId != null &&
        commentUserId != null &&
        currentUserId.toString().trim() == commentUserId.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('自分のコメントは通報できません'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _CommentReportDialog(
        comment: comment,
        post: post,
      ),
    );
  }
}


/// コメント一覧ヘルパー
Widget _buildCommentItem(
  Comment comment, {
  required int? replyingToCommentId,
  required void Function(int) onReplyPressed,
  required void Function(Comment) onReportPressed,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: SpotLightColors.getSpotlightColor(0),
              child: ClipOval(
                child: comment.userIconUrl != null &&
                        comment.userIconUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: comment.userIconUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: SpotLightColors.getSpotlightColor(0),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: SpotLightColors.getSpotlightColor(0),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      )
                    : Container(
                        color: SpotLightColors.getSpotlightColor(0),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
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
                      ),
                      if (comment.parentcommentID == null)
                        TextButton(
                          onPressed: () {
                            final targetId = comment.commentID;
                            if (targetId != null) {
                              onReplyPressed(targetId);
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(0, 0),
                          ),
                          child: Text(
                            '返信',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
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
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
              color: Colors.grey[900],
              onSelected: (value) {
                if (value == 'report') {
                  onReportPressed(comment);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: Colors.red[400], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '通報',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        if (comment.replies.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Column(
              children: comment.replies.map((reply) {
                return _buildReplyItem(
                  reply,
                  onReportPressed: onReportPressed,
                );
              }).toList(),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildReplyItem(
  Comment reply, {
  required void Function(Comment) onReportPressed,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: SpotLightColors.getSpotlightColor(0),
          child: ClipOval(
            child: reply.userIconUrl != null && reply.userIconUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: reply.userIconUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: SpotLightColors.getSpotlightColor(0),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: SpotLightColors.getSpotlightColor(0),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  )
                : Container(
                    color: SpotLightColors.getSpotlightColor(0),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    reply.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatCommentTime(reply.commenttimestamp),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        color: Colors.grey[400], size: 18),
                    color: Colors.grey[900],
                    onSelected: (value) {
                      if (value == 'report') {
                        onReportPressed(reply);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.flag, color: Colors.red[400], size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              '通報',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                reply.commenttext,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _formatCommentTime(String timestamp) {
  try {
    // タイムスタンプをパース（サーバーがUTC時刻を返す場合、タイムゾーン情報がない場合は'Z'を追加してUTCとして解釈）
    // タイムゾーン情報（Z、+、-の後に数字）がない場合、Zを追加
    final hasTimezone = timestamp.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(timestamp);
    final timestampToParse = hasTimezone ? timestamp : '${timestamp}Z';
    final dateTime = DateTime.parse(timestampToParse).toLocal();
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

/// 投稿通報ダイアログ（段階10）
class _ReportDialog extends StatefulWidget {
  final Post post;

  const _ReportDialog({required this.post});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _reasonController = TextEditingController();
  String _selectedReason = '';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        '投稿を通報',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '通報理由を選択してください',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildReasonOption('不適切なコンテンツ'),
            _buildReasonOption('スパムまたは詐欺'),
            _buildReasonOption('著作権侵害'),
            _buildReasonOption('その他'),
            const SizedBox(height: 16),
            const Text(
              '詳細（任意）',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '詳細な理由を入力してください',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'キャンセル',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        TextButton(
          onPressed: _isSubmitting || _selectedReason.isEmpty
              ? null
              : () async {
                  setState(() {
                    _isSubmitting = true;
                  });

                  final detailText = _reasonController.text.trim();
                  final result = await ReportService.sendReport(
                    type: 'content',
                    reason: _selectedReason,
                    detail: detailText.isNotEmpty ? detailText : null,
                    contentID: widget.post.id,
                    currentUserId: currentUserId?.toString(),
                    postUserId: widget.post.userId,
                  );

                  if (!mounted) return;

                  setState(() {
                    _isSubmitting = false;
                  });

                  if (result.success) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('通報が送信されました'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.errorMessage ?? '通報の送信に失敗しました'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF6B35),
                  ),
                )
              : const Text(
                  '送信',
                  style: TextStyle(color: Color(0xFFFF6B35)),
                ),
        ),
      ],
    );
  }

  Widget _buildReasonOption(String reason) {
    final isSelected = _selectedReason == reason;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReason = reason;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF6B35).withOpacity(0.2)
              : Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[300],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// コメント通報ダイアログ（段階10）
class _CommentReportDialog extends StatefulWidget {
  final Comment comment;
  final Post post;

  const _CommentReportDialog({
    required this.comment,
    required this.post,
  });

  @override
  State<_CommentReportDialog> createState() => _CommentReportDialogState();
}

class _CommentReportDialogState extends State<_CommentReportDialog> {
  final _reasonController = TextEditingController();
  String _selectedReason = '';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        'コメントを通報',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '通報理由を選択してください',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildReasonOption('不適切なコンテンツ'),
            _buildReasonOption('差別的または攻撃的なコメント'),
            _buildReasonOption('スパムまたは詐欺'),
            _buildReasonOption('その他'),
            const SizedBox(height: 16),
            const Text(
              '詳細（任意）',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '詳細な理由を入力してください',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'キャンセル',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        TextButton(
          onPressed: _isSubmitting || _selectedReason.isEmpty
              ? null
              : () async {
                  setState(() {
                    _isSubmitting = true;
                  });

                  final detailText = _reasonController.text.trim();
                  final result = await ReportService.sendReport(
                    type: 'comment',
                    reason: _selectedReason,
                    detail: detailText.isNotEmpty ? detailText : null,
                    contentID: widget.post.id,
                    commentID: widget.comment.commentID,
                    currentUserId: currentUserId?.toString(),
                    commentUserId: widget.comment.userId,
                  );

                  if (!mounted) return;

                  setState(() {
                    _isSubmitting = false;
                  });

                  if (result.success) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('通報が送信されました'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.errorMessage ?? '通報の送信に失敗しました'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF6B35),
                  ),
                )
              : const Text(
                  '送信',
                  style: TextStyle(color: Color(0xFFFF6B35)),
                ),
        ),
      ],
    );
  }

  Widget _buildReasonOption(String reason) {
    final isSelected = _selectedReason == reason;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReason = reason;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF6B35).withOpacity(0.2)
              : Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[300],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// プレイリスト選択ダイアログ（段階9）
class _PlaylistDialog extends StatelessWidget {
  final Post post;
  final List<dynamic> playlists;
  final VoidCallback onCreateNew;

  const _PlaylistDialog({
    required this.post,
    required this.playlists,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'プレイリストに追加',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.playlist_add,
                      size: 48,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'プレイリストがありません',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return ListTile(
                    leading: Icon(
                      Icons.playlist_play,
                      color: SpotLightColors.getSpotlightColor(0),
                    ),
                    title: Text(
                      playlist.title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      try {
                        final success =
                            await PlaylistService.addContentToPlaylist(
                          playlist.playlistid,
                          post.id,
                        );

                        if (context.mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('プレイリストに追加しました'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('プレイリストへの追加に失敗しました'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('エラーが発生しました: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          // 新規作成ボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCreateNew,
              icon: const Icon(Icons.add),
              label: const Text('新しいプレイリストを作成'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SpotLightColors.getSpotlightColor(0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// スクロールタイトル（段階11: 長いタイトルの自動スクロール）
class _ScrollingTitle extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _ScrollingTitle({
    required this.text,
    required this.style,
  });

  @override
  State<_ScrollingTitle> createState() => _ScrollingTitleState();
}

class _ScrollingTitleState extends State<_ScrollingTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.0, 0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    // アニメーション完了後に待機時間を入れてからリセット
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _needsScroll) {
        // 待機時間後にリセットして再開
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _needsScroll) {
            _controller.reset();
            _controller.forward();
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfNeedsScroll();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkIfNeedsScroll() {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox) {
      // 20文字以上の場合のみスクロール可能
      if (widget.text.length < 20) {
        return;
      }

      final availableWidth = renderObject.size.width;

      // テキストの実際の幅を測定（制限なし）
      final textPainter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final textWidth = textPainter.width;

      // テキストの幅が利用可能な幅を超えている場合のみスクロール
      if (textWidth > availableWidth) {
        if (mounted) {
          setState(() {
            _needsScroll = true;
          });
          // 最初の位置で少し待機してからスクロール開始
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _needsScroll) {
              _controller.forward();
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsScroll) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        // テキストの実際の幅を測定
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        final textWidth = textPainter.width;

        // スクロールする距離を計算
        final scrollDistance = textWidth - availableWidth;

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            // アニメーション値（0.0から1.0）を使ってスクロール距離を計算
            final offsetX = -scrollDistance * _animation.value.dx;
            return ClipRect(
              child: SizedBox(
                width: availableWidth,
                child: Stack(
                  children: [
                    Transform.translate(
                      offset: Offset(offsetX, 0),
                      child: Text(
                        widget.text,
                        style: widget.style,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
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
  }
}
