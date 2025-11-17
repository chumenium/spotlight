import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../widgets/robust_network_image.dart';
import '../providers/navigation_provider.dart';
import '../utils/spotlight_colors.dart';

class HistoryListScreen extends StatefulWidget {
  const HistoryListScreen({super.key});

  @override
  State<HistoryListScreen> createState() => _HistoryListScreenState();
}

class _HistoryListScreenState extends State<HistoryListScreen> {
  List<Post> _historyPosts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  /// 視聴履歴を取得
  Future<void> _fetchHistory() async {
    if (kDebugMode) {
      debugPrint('📝 [画面] 視聴履歴取得開始');
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final posts = await PostService.getPlayHistory();

      if (kDebugMode) {
        debugPrint('📝 [画面] 視聴履歴取得完了: ${posts.length}件');
        if (posts.isNotEmpty) {
          for (int i = 0; i < posts.length && i < 3; i++) {
            final post = posts[i];
            debugPrint(
                '📝 [画面] 項目[$i]: ID=${post.id}, タイトル="${post.title}", 投稿者="${post.username}", playNum=${post.playNum}');
          }
        }
      }

      if (mounted) {
        setState(() {
          _historyPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [画面] 視聴履歴取得エラー: $e');
        debugPrint('スタックトレース: $stackTrace');
      }

      if (mounted) {
        setState(() {
          _errorMessage = '視聴履歴の取得に失敗しました';
          _isLoading = false;
        });
      }
    }
  }

  /// 日付を相対時間に変換（例: "3日前"）
  String _formatRelativeTime(DateTime dateTime) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        title: const Text('視聴履歴'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchHistory,
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red[300],
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                        ),
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _historyPosts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            color: Colors.grey[600],
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '視聴履歴がありません',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'コンテンツを視聴すると\nここに表示されます',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchHistory,
                      color: const Color(0xFFFF6B35),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _historyPosts.length,
                        itemBuilder: (context, index) {
                          final post = _historyPosts[index];
                          return _buildHistoryItem(context, post, index);
                        },
                      ),
                    ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, Post post, int index) {
    return GestureDetector(
      onTap: () {
        try {
          final postId = post.id.toString();
          if (postId.isNotEmpty) {
            final navigationProvider =
                Provider.of<NavigationProvider>(context, listen: false);
            navigationProvider.navigateToHome(postId: postId);

            if (kDebugMode) {
              debugPrint('📱 [画面] 投稿をタップ: ID=$postId, タイトル=${post.title}');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [画面] タップエラー: $e');
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            // サムネイル
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 160,
                height: 90,
                color: Colors.grey[800],
                child: post.thumbnailUrl != null &&
                        post.thumbnailUrl!.isNotEmpty
                    ? RobustNetworkImage(
                        imageUrl: post.thumbnailUrl!,
                        fit: BoxFit.cover,
                        maxWidth: 320,
                        maxHeight: 180,
                        placeholder: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF6B35),
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : Stack(
                        children: [
                          Center(
                            child: Icon(
                              post.postType == PostType.video
                                  ? Icons.play_circle_outline
                                  : post.postType == PostType.image
                                      ? Icons.image_outlined
                                      : post.postType == PostType.audio
                                          ? Icons.audiotrack_outlined
                                          : Icons.text_fields_outlined,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          if (post.isSpotlighted)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color:
                                      SpotLightColors.getSpotlightColor(index),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: SpotLightColors.getSpotlightColor(
                                              index)
                                          .withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // タイトルと情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title.isNotEmpty ? post.title : 'タイトルなし',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.username.isNotEmpty ? post.username : 'ユーザー名なし',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${post.playNum}回視聴',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatRelativeTime(post.createdAt),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // メニューボタン
            IconButton(
              onPressed: () {
                _showMenuBottomSheet(context, post, index);
              },
              icon: const Icon(
                Icons.more_vert,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenuBottomSheet(BuildContext context, Post post, int index) {
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
          children: [
            _buildMenuOption(
              icon: Icons.playlist_add,
              title: '再生リストに追加',
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _buildMenuOption(
              icon: Icons.share,
              title: '共有',
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _buildMenuOption(
              icon: Icons.remove_circle_outline,
              title: '履歴から削除',
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.white,
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
