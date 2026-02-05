import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/playlist_service.dart';
import '../widgets/robust_network_image.dart';
import '../providers/navigation_provider.dart';
import '../utils/spotlight_colors.dart';
import '../widgets/center_popup.dart';
import '../widgets/blur_app_bar.dart';

class HistoryListScreen extends StatefulWidget {
  const HistoryListScreen({super.key});

  @override
  State<HistoryListScreen> createState() => _HistoryListScreenState();
}

class _HistoryListScreenState extends State<HistoryListScreen> {
  List<Post> _historyPosts = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 前回の再取得時刻を記録（頻繁な再取得を防ぐ）
  DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 画面が表示されるたびにデータを再取得
    // ただし、1秒以内の再取得はスキップ（頻繁な再取得を防ぐ）
    final now = DateTime.now();
    if (_lastFetchTime == null ||
        now.difference(_lastFetchTime!).inSeconds >= 1) {
      _lastFetchTime = now;
      // 少し遅延させてから再取得（画面遷移のアニメーション完了後）
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _fetchHistory();
        }
      });
    }
  }

  /// 視聴履歴を取得
  Future<void> _fetchHistory() async {
    if (kDebugMode) {
      debugPrint('📝 [画面] ========== 視聴履歴取得開始 ==========');
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kDebugMode) {
        debugPrint('📝 [画面] PostService.getPlayHistory()を呼び出します');
      }

      final posts = await PostService.getPlayHistory();

      if (kDebugMode) {
        debugPrint('📝 [画面] ========== PostServiceから取得完了 ==========');
        debugPrint('📝 [画面] 取得件数: ${posts.length}件');
        if (posts.isNotEmpty) {
          debugPrint('📝 [画面] 視聴履歴の最初の項目:');
          debugPrint('   - ID: ${posts[0].id}');
          debugPrint('   - タイトル: ${posts[0].title}');
          debugPrint('   - 投稿者: ${posts[0].username}');
          debugPrint('   - タイプ: ${posts[0].postType}');
          debugPrint('   - 作成日時: ${posts[0].createdAt}');
          debugPrint('   - playNum: ${posts[0].playNum}');
          debugPrint('   - thumbnailUrl: ${posts[0].thumbnailUrl}');
          debugPrint('   - userIconUrl: ${posts[0].userIconUrl}');

          // すべての項目のタイトルと投稿者を確認
          debugPrint('📝 [画面] 視聴履歴の全項目:');
          for (int i = 0; i < posts.length; i++) {
            final post = posts[i];
            debugPrint(
                '   [$i] ID=${post.id}, タイトル="${post.title}", 投稿者="${post.username}", playNum=${post.playNum}');
          }
        } else {
          debugPrint('⚠️ [画面] 視聴履歴が空です');
        }
        debugPrint('📝 [画面] ===========================================');
      }

      if (mounted) {
        setState(() {
          final previousCount = _historyPosts.length;
          _historyPosts = posts;
          _isLoading = false;

          if (kDebugMode) {
            debugPrint('📝 [画面] ========== 状態更新完了 ==========');
            debugPrint('📝 [画面] 前回の件数: $previousCount件');
            debugPrint('📝 [画面] 今回の件数: ${_historyPosts.length}件');
            debugPrint('📝 [画面] リストに格納: ${_historyPosts.length}件');
            if (_historyPosts.isNotEmpty) {
              debugPrint('📝 [画面] 最初の項目ID: ${_historyPosts[0].id}');
              debugPrint(
                  '📝 [画面] 最後の項目ID: ${_historyPosts[_historyPosts.length - 1].id}');
            }
            debugPrint('📝 [画面] ===========================================');
          }
        });
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [画面] Widgetがマウントされていません。状態を更新しません。');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [画面] ========== 視聴履歴取得エラー ==========');
        debugPrint('❌ [画面] エラー: $e');
        debugPrint('❌ [画面] スタックトレース: $stackTrace');
        debugPrint('❌ [画面] ===========================================');
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
    dateTime = dateTime.toLocal();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? Colors.white : const Color(0xFF1A1A1A);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: BlurAppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
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
                        style: TextStyle(
                          color: primaryTextColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? Colors.white : const Color(0xFF1A1A1A);
    final secondaryTextColor =
        isDark ? Colors.grey[400]! : const Color(0xFF5A5A5A);
    final placeholderIconColor =
        isDark ? Colors.white : const Color(0xFF5A5A5A);
    final thumbnailBackgroundColor = isDark
        ? Colors.grey[800]!
        : SpotLightColors.peach.withOpacity(0.2);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        try {
          final postId = post.id.toString();
          if (postId.isNotEmpty) {
            final navigationProvider =
                Provider.of<NavigationProvider>(context, listen: false);

            // ホーム画面に遷移して対象のコンテンツを表示
            navigationProvider.navigateToHome(
                postId: postId, postTitle: post.title);

            // 現在の画面を閉じてホーム画面に戻る
            Navigator.of(context).popUntil((route) => route.isFirst);

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
                color: thumbnailBackgroundColor,
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
                              color: placeholderIconColor,
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
                    style: TextStyle(
                      color: primaryTextColor,
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
                      color: secondaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${post.playNum}回視聴',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatRelativeTime(post.createdAt.toLocal()),
                        style: TextStyle(
                          color: secondaryTextColor,
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
                _handlePlaylistAdd(post);
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
              icon: Icons.delete_outline,
              title: '視聴履歴を削除',
              onTap: () {
                Navigator.pop(context);
                _showDeleteHistoryDialog(post, index);
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
      leading: Icon(icon, size: 24),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<void> _handlePlaylistAdd(Post post) async {
    if (kDebugMode) {
      debugPrint('📂 [再生履歴] 再生リスト追加: postId=${post.id}');
    }

    try {
      final playlists = await PlaylistService.getPlaylists();
      if (!mounted) return;
      _showPlaylistDialog(post, playlists);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [再生履歴] プレイリスト取得エラー: $e');
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

  void _showPlaylistDialog(Post post, List<dynamic> playlists) {
    showModalBottomSheet(
      context: context,
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

  void _showCreatePlaylistDialog(Post post) {
    final titleController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新しいプレイリストを作成'),
        content: TextField(
          controller: titleController,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          decoration: InputDecoration(
            hintText: 'プレイリスト名を入力',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFFF6B35)),
            ),
            filled: true,
            fillColor:
                isDark ? Colors.grey[900] : SpotLightColors.peach.withOpacity(0.2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              Navigator.of(context).pop();

              try {
                var playlistId = await PlaylistService.createPlaylist(title);
                if ((playlistId == null || playlistId <= 0) && mounted) {
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
                      CenterPopup.show(context, 'プレイリストに追加しました');
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

  void _showDeleteHistoryDialog(Post post, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('視聴履歴を削除'),
        content: const Text('この視聴履歴を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '削除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true || !mounted) return;
      final playId = post.playId;
      if (playId == null || playId == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('視聴履歴のIDが取得できませんでした'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final success = await PostService.deletePlayHistory(playId: playId);
      if (!mounted) return;
      if (success) {
        setState(() {
          _historyPosts.removeWhere((item) => item.id == post.id);
        });
        CenterPopup.show(context, '視聴履歴を削除しました');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('視聴履歴の削除に失敗しました'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }
}

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? Colors.white : const Color(0xFF1A1A1A);
    final secondaryTextColor =
        isDark ? Colors.grey[400]! : const Color(0xFF5A5A5A);
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'プレイリストに追加',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: primaryTextColor),
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
                        color: secondaryTextColor,
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
                      style: TextStyle(color: primaryTextColor),
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
                              CenterPopup.show(
                                  context, 'プレイリストに追加しました');
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
