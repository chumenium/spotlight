import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/icon_update_service.dart';
import '../config/app_config.dart';
import '../utils/spotlight_colors.dart';
import '../widgets/robust_network_image.dart';

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
  static const int _batchLoadCount = 2; // 追加読み込み件数

  // ジェスチャー関連
  double _swipeOffset = 0.0;
  bool _isSpotlighting = false;
  AnimationController? _ambientAnimationController;
  Animation<double>? _ambientOpacityAnimation;

  // 動画プレイヤー関連
  final Map<int, VideoPlayerController?> _videoControllers = {};
  int? _currentPlayingVideo;
  final Set<int> _initializedVideos = {};

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
  static const Duration _updateInterval = Duration(seconds: 30); // 30秒ごとに更新（頻度を下げる）
  final Set<String> _fetchedContentIds = {}; // 取得済みのコンテンツID
  
  // ウィジェットの破棄状態を管理
  bool _isDisposed = false;

  // 画像事前読み込み管理（読み込み済みのインデックスを記録）
  final Set<int> _preloadedImages = {};

  // リソース解放範囲（現在のページから±3ページ以外は解放）
  static const int _resourceReleaseRange = 3;

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

  /// バックエンドから投稿を取得（初回読み込み）
  Future<void> _fetchPosts() async {
    try {
      if (kDebugMode) {
        debugPrint('📝 投稿取得を開始（初回: $_initialLoadCount件）...');
      }
      
      final posts = await PostService.fetchPosts(limit: _initialLoadCount);
      
      if (!_isDisposed && mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
          _errorMessage = posts.isEmpty ? '投稿がありません' : null;
          
          // 読み込んだ件数が要求した件数より少ない場合は、これ以上投稿がない
          _hasMorePosts = posts.length >= _initialLoadCount;
          
          // 取得済みコンテンツIDを記録
          _fetchedContentIds.clear();
          for (final post in posts) {
            _fetchedContentIds.add(post.id);
          }
        });
        
        // 投稿が取得できたら初期表示時に現在のページがメディアの場合は自動再生を開始
        if (_posts.isNotEmpty) {
          _handleMediaPageChange(_currentIndex);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 投稿取得エラー: $e');
      }
      
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '投稿の取得に失敗しました';
        });
      }
    }
  }
  
  /// 追加の投稿を読み込む（遅延読み込み）
  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts || _posts.isEmpty) return;
    
    _isLoadingMore = true;
    
    try {
      // 最後の投稿のnextContentIdを使用
      final lastPost = _posts.last;
      if (lastPost.nextContentId == null) {
        // nextContentIdがnullの場合は、これ以上投稿がない
        setState(() {
          _hasMorePosts = false;
        });
        _isLoadingMore = false;
        return;
      }
      
      if (kDebugMode) {
        debugPrint('📝 追加読み込み開始: $_batchLoadCount件');
      }
      
      // 次のコンテンツIDから追加読み込み
      final morePosts = await PostService.fetchPosts(limit: _batchLoadCount);
      
      if (!_isDisposed && mounted && morePosts.isNotEmpty) {
        setState(() {
          _posts.addAll(morePosts);
          
          // 取得済みコンテンツIDを記録
          for (final post in morePosts) {
            _fetchedContentIds.add(post.id);
          }
          
          // 読み込んだ件数が要求した件数より少ない場合は、これ以上投稿がない
          _hasMorePosts = morePosts.length >= _batchLoadCount;
        });
        
        if (kDebugMode) {
          debugPrint('📝 追加読み込み完了: ${morePosts.length}件（合計: ${_posts.length}件）');
        }
      } else {
        setState(() {
          _hasMorePosts = false;
        });
      }
    } catch (e) {
      // エラーは無視（サイレント）
    } finally {
      _isLoadingMore = false;
    }
  }
  
  /// 手動で投稿を更新（プルリフレッシュ）
  Future<void> _refreshPosts() async {
    if (_isUpdating) return;
    
    _isUpdating = true;
    
    try {
      // 初回読み込みと同じ件数を取得
      final posts = await PostService.fetchPosts(limit: _initialLoadCount);
      
      if (!_isDisposed && mounted && posts.isNotEmpty) {
        setState(() {
          _posts = posts;
          _errorMessage = null;
          _hasMorePosts = posts.length >= _initialLoadCount;
          
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
                              onPressed: _fetchPosts,
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
                                      setState(() {
                                        _currentIndex = index;
                                        _resetSpotlightState();
                                        _handleMediaPageChange(index);
                                      });
                                      
                                      // 遅延読み込み: 残り2件以下になったら追加読み込み
                                      if (_hasMorePosts && index >= _posts.length - 2) {
                                        _loadMorePosts();
                                      }
                                    },
                                    itemCount: _hasMorePosts ? _posts.length + 1 : _posts.length,
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
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  image: post.thumbnailUrl != null
                      ? DecorationImage(
                          image: NetworkImage(post.thumbnailUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    if (post.thumbnailUrl == null)
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
                      const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // タップで一時停止/再生
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (controller != null && controller.value.isInitialized) {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                } else if (postIndex == _currentIndex &&
                    post.postType == PostType.video) {
                  // 初期化されていない場合は初期化を開始
                  _initializeVideoController(postIndex);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(Post post) {
    // 画像URLを取得（mediaUrl優先、なければthumbnailUrl）
    final imageUrl = post.mediaUrl ?? post.thumbnailUrl;

    if (kDebugMode) {
      debugPrint('🖼️ 画像URL: $imageUrl');
      debugPrint('📁 contentPath: ${post.contentPath}');
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: imageUrl != null
          ? Stack(
              children: [
                // メイン画像（Flutterの最適化された読み込みを使用）
                Center(
                  child: RobustNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFFFF6B35),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '画像を読み込み中...',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // アンビエントライティング効果
                if (imageUrl.isNotEmpty) _buildAmbientLighting(imageUrl),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.image,
                    color: Colors.white38,
                    size: 80,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '画像URLが設定されていません\ncontentPath: ${post.contentPath}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38),
                  ),
                ],
              ),
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

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            SpotLightColors.getSpotlightColor(2).withOpacity(0.3),
            Colors.black,
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => _toggleAudioPlayback(postIndex),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 音声視覚化エフェクト
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isPlaying ? 160 : 120,
                height: isPlaying ? 160 : 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SpotLightColors.getSpotlightColor(2)
                      .withOpacity(isPlaying ? 0.3 : 0.1),
                  border: Border.all(
                    color:
                        SpotLightColors.getSpotlightColor(2).withOpacity(0.8),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: isPlaying ? 80 : 60,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                '音声投稿',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              // 再生進捗
              if (player != null)
                Container(
                  width: 250,
                  child: StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = player.duration ?? Duration.zero;

                      return Column(
                        children: [
                          Slider(
                            value: duration.inMilliseconds > 0
                                ? position.inMilliseconds /
                                    duration.inMilliseconds
                                : 0.0,
                            onChanged: (value) {
                              if (duration.inMilliseconds > 0) {
                                final newPosition = Duration(
                                  milliseconds:
                                      (value * duration.inMilliseconds).round(),
                                );
                                player.seek(newPosition);
                              }
                            },
                            activeColor: SpotLightColors.getSpotlightColor(2),
                            inactiveColor: Colors.grey[600],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              // 音声初期化中のローディング表示
              if (postIndex == _currentIndex &&
                  post.postType == PostType.audio &&
                  !_initializedAudios.contains(postIndex))
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF6B35),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientLighting(String imageUrl) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.3),
            ],
          ),
        ),
      ),
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
              CircleAvatar(
                radius: 20,
                backgroundColor: SpotLightColors.getSpotlightColor(0),
                child: ClipOval(
                  key: ValueKey(
                      '${post.username}_${_iconCacheKeys[post.username] ?? 0}'),
                  child: RobustNetworkImage(
                    imageUrl: post.userIconUrl ?? '${AppConfig.backendUrl}/icon/default_icon.jpg',
                    fit: BoxFit.cover,
                    maxWidth: 80,
                    maxHeight: 80,
                    placeholder: Container(),
                    errorWidget: Container(),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
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
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // コメント一覧
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: 10, // 仮のコメント数
                        itemBuilder: (context, index) {
                          return _buildCommentItem(index);
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
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'コメントを追加...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
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
                            onPressed: () {
                              // コメント送信
                              setState(() {
                                _posts[_currentIndex] = Post(
                                  id: _posts[_currentIndex].id,
                                  userId: _posts[_currentIndex].userId,
                                  username: _posts[_currentIndex].username,
                                  userIconPath:
                                      _posts[_currentIndex].userIconPath,
                                  userIconUrl:
                                      _posts[_currentIndex].userIconUrl,
                                  title: _posts[_currentIndex].title,
                                  content: _posts[_currentIndex].content,
                                  contentPath:
                                      _posts[_currentIndex].contentPath,
                                  type: _posts[_currentIndex].type,
                                  mediaUrl: _posts[_currentIndex].mediaUrl,
                                  thumbnailUrl:
                                      _posts[_currentIndex].thumbnailUrl,
                                  likes: _posts[_currentIndex].likes,
                                  playNum: _posts[_currentIndex].playNum,
                                  link: _posts[_currentIndex].link,
                                  comments: _posts[_currentIndex].comments + 1,
                                  shares: _posts[_currentIndex].shares,
                                  isSpotlighted:
                                      _posts[_currentIndex].isSpotlighted,
                                  isText: _posts[_currentIndex].isText,
                                  nextContentId:
                                      _posts[_currentIndex].nextContentId,
                                  createdAt: _posts[_currentIndex].createdAt,
                                );
                              });
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
  }

  Widget _buildCommentItem(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFFF6B35),
            child: const Icon(Icons.person, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ユーザー${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${index + 1}時間前',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'これはコメント${index + 1}の内容です。とても面白い投稿ですね！',
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
                      onPressed: () {},
                      icon:
                          const Icon(Icons.reply, color: Colors.grey, size: 16),
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
    final newPost = _posts[newIndex];

    // 前の動画を停止
    if (_currentPlayingVideo != null) {
      final prevController = _videoControllers[_currentPlayingVideo];
      if (prevController != null && prevController.value.isInitialized) {
        prevController.pause();
      }
      _currentPlayingVideo = null;
    }

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
            }
          }
        });
      } else {
        // 既に初期化済みの場合は即座に再生
        final player = _audioPlayers[newIndex];
        if (player != null) {
          player.setLoopMode(LoopMode.one);
          player.play();
        }
      }
    } else if (newPost.postType == PostType.image) {
      // 新しいページが画像投稿の場合、画像を事前読み込み
      _preloadImagesAround(newIndex);

      // 遠く離れたコンテンツのリソースを解放
      _releaseDistantResources(newIndex);
    }
  }

  /// 現在のページ周辺の画像を事前読み込み（前後2ページまで）
  void _preloadImagesAround(int currentIndex) {
    // 読み込み範囲: 現在のページ ±2ページ
    const preloadRange = 2;

    for (int i = currentIndex - preloadRange;
        i <= currentIndex + preloadRange;
        i++) {
      if (i >= 0 && i < _posts.length && !_preloadedImages.contains(i)) {
        final post = _posts[i];
        if (post.postType == PostType.image) {
          _preloadImage(i);
        }
      }
    }
  }

  /// 遠く離れたコンテンツのリソースを解放
  void _releaseDistantResources(int currentIndex) {
    // 現在のページから±_resourceReleaseRange以外の画像キャッシュを解放
    final imagesToRelease = <int>[];

    for (final index in _preloadedImages) {
      if ((index < currentIndex - _resourceReleaseRange) ||
          (index > currentIndex + _resourceReleaseRange)) {
        imagesToRelease.add(index);
      }
    }

    for (final index in imagesToRelease) {
      if (index < _posts.length) {
        final post = _posts[index];
        if (post.postType == PostType.image) {
          final imageUrl = post.mediaUrl ?? post.thumbnailUrl;
          if (imageUrl != null) {
            try {
              final imageProvider = NetworkImage(imageUrl);
              imageProvider.evict();
              _preloadedImages.remove(index);

              if (kDebugMode) {
                debugPrint('🗑️ 遠く離れた画像キャッシュを解放: $imageUrl');
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('⚠️ キャッシュ解放エラー: $e');
              }
            }
          }
        }
      }
    }
  }

  /// 画像の事前読み込み（プリキャッシュ、最適化されたサイズで）
  Future<void> _preloadImage(int postIndex) async {
    if (postIndex < 0 || postIndex >= _posts.length) return;
    if (_preloadedImages.contains(postIndex)) return; // 既に読み込み済み

    final post = _posts[postIndex];
    if (post.postType != PostType.image) return;

    final imageUrl = post.mediaUrl ?? post.thumbnailUrl;
    if (imageUrl == null || imageUrl.isEmpty) return;

    try {
      // ディスプレイサイズに基づいて最適化されたサイズで読み込み
      final mediaQuery = MediaQuery.of(context);
      final screenSize = mediaQuery.size;
      final devicePixelRatio = mediaQuery.devicePixelRatio;

      // ディスプレイサイズの1.5倍（Retina対応）を上限として使用
      final cacheWidth =
          (screenSize.width * devicePixelRatio * 1.5).round().clamp(360, 2160);
      final cacheHeight =
          (screenSize.height * devicePixelRatio * 1.5).round().clamp(640, 3840);

      // Image.networkのキャッシュを事前に読み込む（WebP/AVIFを優先）
      final imageProvider = NetworkImage(
        imageUrl,
        headers: {
          'Accept': 'image/webp,image/avif,image/*, */*;q=0.8', // WebP/AVIFを優先
          'User-Agent': 'Flutter-Spotlight/1.0',
        },
      );

      // 最適化されたサイズで画像をキャッシュに事前読み込み
      await precacheImage(
        imageProvider,
        context,
        size: Size(cacheWidth.toDouble(), cacheHeight.toDouble()),
      );

      _preloadedImages.add(postIndex);

      if (kDebugMode) {
        debugPrint('✅ 画像事前読み込み完了: $imageUrl (${cacheWidth}x${cacheHeight})');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 画像事前読み込みエラー: $e');
      }
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
      }
    } catch (e) {
      print('音声の再生に失敗: $e');
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
