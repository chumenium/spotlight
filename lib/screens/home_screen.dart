import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../models/post.dart';
import '../utils/spotlight_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  final List<Post> _posts = List.generate(10, (index) => Post.sample(index));
  
  // ジェスチャー関連
  double _swipeOffset = 0.0;
  bool _isSpotlighting = false;
  AnimationController? _ambientAnimationController;
  Animation<double>? _ambientOpacityAnimation;
  
  // ウィジェットの破棄状態を管理
  bool _isDisposed = false;

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
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pageController.dispose();
    _ambientAnimationController?.dispose();
    // ステータスバーを表示に戻す
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 下のレイヤー（常駐の懐中電灯アイコン）
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(_swipeOffset * 0.1, 0),
              child: Transform.rotate(
                angle: _swipeOffset * 0.0005, // 下のレイヤーも軽く回転
                alignment: Alignment.bottomLeft,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        SpotLightColors.getSpotlightColor(0).withOpacity(0.8),
                        SpotLightColors.getSpotlightColor(0).withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.flashlight_on,
                          color: Colors.white,
                          size: 80,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'スポットライト！',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // 全画面投稿表示（ジェスチャー対応）
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              child: Transform.translate(
                offset: Offset(_swipeOffset * 0.3, 0), // スワイプに応じてズレ
                child: Transform.rotate(
                  angle: _swipeOffset * 0.001, // スワイプに応じて左下を中心に回転
                  alignment: Alignment.bottomLeft, // 左下を中心に回転
                  child: PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical, // 縦スクロール
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                        _resetSpotlightState();
                      });
                    },
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      return _buildPostContent(_posts[index]);
                    },
                  ),
                ),
              ),
            ),
          ),
          
          // スポットライトアンビエントライティング
          if (_isSpotlighting && _ambientOpacityAnimation != null)
            AnimatedBuilder(
              animation: _ambientOpacityAnimation!,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.5,
                      colors: [
                        SpotLightColors.getSpotlightColor(0).withOpacity(0.3 * _ambientOpacityAnimation!.value),
                        Colors.transparent,
                      ],
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
            child: _buildRightBottomControls(_posts[_currentIndex]),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent(Post post) {
    switch (post.type) {
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
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // 動画プレイヤー（仮実装）
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
              child: post.thumbnailUrl == null
                  ? const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 80,
                    )
                  : const Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        color: Colors.white,
                        size: 80,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(Post post) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: post.thumbnailUrl != null
          ? Stack(
              children: [
                // メイン画像
                Center(
                  child: AspectRatio(
                    aspectRatio: _getImageAspectRatio(),
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(post.thumbnailUrl!),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                // アンビエントライティング効果
                _buildAmbientLighting(post.thumbnailUrl!),
              ],
            )
          : const Center(
              child: Icon(
                Icons.image,
                color: Colors.white,
                size: 80,
              ),
            ),
    );
  }

  Widget _buildTextContent(Post post) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SpotLightColors.getSpotlightColor(0).withOpacity(0.1),
            SpotLightColors.getSpotlightColor(1).withOpacity(0.1),
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
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
              Text(
                post.content,
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
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.graphic_eq,
              color: Colors.white,
              size: 120,
            ),
            SizedBox(height: 20),
            Text(
              '音声投稿',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
                backgroundImage: NetworkImage(post.userAvatar),
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
                icon: post.isSpotlighted ? Icons.flashlight_on : Icons.flashlight_on_outlined,
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
          label: '${post.shares}',
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

  double _getImageAspectRatio() {
    // 仮のアスペクト比計算（実際は画像のサイズに基づく）
    return 16 / 9;
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
  void _executeSpotlight() {
    final currentPost = _posts[_currentIndex];
    final isCurrentlySpotlighted = currentPost.isSpotlighted;
    
    // 投稿のスポットライト状態を更新
    _posts[_currentIndex] = Post(
      id: currentPost.id,
      userId: currentPost.userId,
      username: currentPost.username,
      userAvatar: currentPost.userAvatar,
      title: currentPost.title,
      content: currentPost.content,
      type: currentPost.type,
      mediaUrl: currentPost.mediaUrl,
      thumbnailUrl: currentPost.thumbnailUrl,
      likes: isCurrentlySpotlighted ? currentPost.likes - 1 : currentPost.likes + 1,
      comments: currentPost.comments,
      shares: currentPost.shares,
      isSpotlighted: !isCurrentlySpotlighted,
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
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFFFF6B35),
                          child: Icon(Icons.person, size: 16, color: Colors.white),
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
                                userAvatar: _posts[_currentIndex].userAvatar,
                                title: _posts[_currentIndex].title,
                                content: _posts[_currentIndex].content,
                                type: _posts[_currentIndex].type,
                                mediaUrl: _posts[_currentIndex].mediaUrl,
                                thumbnailUrl: _posts[_currentIndex].thumbnailUrl,
                                likes: _posts[_currentIndex].likes,
                                comments: _posts[_currentIndex].comments + 1,
                                shares: _posts[_currentIndex].shares,
                                isSpotlighted: _posts[_currentIndex].isSpotlighted,
                                createdAt: _posts[_currentIndex].createdAt,
                              );
                            });
                          },
                          icon: const Icon(Icons.send, color: Color(0xFFFF6B35)),
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
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFFF6B35),
            child: Icon(Icons.person, size: 16, color: Colors.white),
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
                      userAvatar: _posts[_currentIndex].userAvatar,
                      title: _posts[_currentIndex].title,
                      content: _posts[_currentIndex].content,
                      type: _posts[_currentIndex].type,
                      mediaUrl: _posts[_currentIndex].mediaUrl,
                      thumbnailUrl: _posts[_currentIndex].thumbnailUrl,
                      likes: _posts[_currentIndex].likes,
                      comments: _posts[_currentIndex].comments,
                      shares: _posts[_currentIndex].shares + 1,
                      isSpotlighted: _posts[_currentIndex].isSpotlighted,
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
}