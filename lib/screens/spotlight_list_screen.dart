import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import '../utils/spotlight_colors.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../widgets/robust_network_image.dart';
import '../providers/navigation_provider.dart';
import '../services/playlist_service.dart';
import '../services/share_link_service.dart';

class SpotlightListScreen extends StatefulWidget {
  const SpotlightListScreen({super.key});

  @override
  State<SpotlightListScreen> createState() => _SpotlightListScreenState();
}

class _SpotlightListScreenState extends State<SpotlightListScreen> {
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isLoadingDialogShown = false;

  @override
  void initState() {
    super.initState();
    _fetchUserContents();
  }

  /// 自分の投稿を取得
  Future<void> _fetchUserContents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final posts = await PostService.getUserContents();

      if (kDebugMode) {
        debugPrint('📝 自分の投稿取得完了: ${posts.length}件');
      }

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 自分の投稿取得エラー: $e');
      }

      if (mounted) {
        setState(() {
          _errorMessage = '投稿の取得に失敗しました';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? Colors.white : const Color(0xFF1A1A1A);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: const Text('自分の投稿'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchUserContents,
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
                        onPressed: _fetchUserContents,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                        ),
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_outlined,
                            color: Colors.grey[600],
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '投稿がありません',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '新しい投稿を作成してみましょう',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchUserContents,
                      color: const Color(0xFFFF6B35),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          return _buildPostItem(context, post, index);
                        },
                      ),
                    ),
    );
  }

  Widget _buildPostItem(BuildContext context, Post post, int index) {
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
        // 投稿をタップしたらホーム画面に遷移してその投稿を表示
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
              debugPrint('📱 投稿をタップ: ID=$postId, タイトル=${post.title}');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ 投稿タップエラー: $e');
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
                child: post.thumbnailUrl != null
                    ? RobustNetworkImage(
                        imageUrl: post.thumbnailUrl!,
                        fit: BoxFit.cover,
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
                          // スポットライトアイコン
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
                    post.title,
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (post.isSpotlighted) ...[
                        Icon(
                          Icons.star,
                          color: SpotLightColors.getSpotlightColor(index),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.likes}スポットライト',
                          style: TextStyle(
                            color: SpotLightColors.getSpotlightColor(index),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${post.playNum}回再生',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRelativeTime(post.createdAt.toLocal()),
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // メニューボタン
            IconButton(
              onPressed: () {
                _showPostMenuBottomSheet(context, post, index);
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

  void _showPostMenuBottomSheet(BuildContext context, Post post, int index) {
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
                _handleShareButton(post);
              },
            ),
            _buildMenuOption(
              icon: Icons.edit,
              title: '編集',
              onTap: () {
                Navigator.pop(context);
                _showEditPostDialog(post, index);
              },
            ),
            _buildMenuOption(
              icon: Icons.delete_outline,
              title: '投稿を削除',
              onTap: () {
                Navigator.pop(context);
                _showDeletePostDialog(context, post, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeletePostDialog(BuildContext context, Post post, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投稿を削除'),
        content: const Text('この投稿を削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // ローディング表示
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('削除中...'),
                    duration: Duration(seconds: 1),
                    backgroundColor: Colors.orange,
                  ),
                );
              }

              final success = await PostService.deletePost(post.id.toString());
              if (success && mounted) {
                // 削除が成功したら、リストを再取得して実際に削除されたかを確認
                await _fetchUserContents();

                // 再取得後、投稿がまだ存在するか確認
                final stillExists = _posts.any((p) => p.id == post.id);
                if (stillExists) {
                  // 削除APIは成功したが、実際には削除されていない（外部キー制約など）
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '投稿の削除に失敗しました。この投稿は他のデータ（通報など）と関連付けられているため削除できません。'),
                        duration: Duration(seconds: 5),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  // 削除が成功した
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('投稿を削除しました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('投稿の削除に失敗しました。エンドポイントが実装されていない可能性があります。'),
                    duration: Duration(seconds: 4),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              '削除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditPostDialog(Post post, int index) async {
    final titleController = TextEditingController(text: post.title);
    final tagController = TextEditingController();
    bool clearTag = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('投稿を編集'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'タイトル',
                      hintText: 'タイトルを入力',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagController,
                    decoration: const InputDecoration(
                      labelText: 'タグ',
                      hintText: '変更する場合のみ入力（例: タグ1 タグ2）',
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: clearTag,
                    onChanged: (value) {
                      setState(() {
                        clearTag = value ?? false;
                      });
                    },
                    title: const Text('タグを空にする'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () async {
                  final titleText = titleController.text.trim();
                  final tagText = tagController.text.trim();
                  final hasTitle = titleText.isNotEmpty;
                  final hasTag = clearTag || tagText.isNotEmpty;

                  if (!hasTitle && !hasTag) {
                    Navigator.pop(context);
                    _showSafeSnackBar('タイトルまたはタグを入力してください',
                        backgroundColor: Colors.red);
                    return;
                  }

                  if (hasTitle &&
                      titleText == post.title &&
                      !hasTag) {
                    Navigator.pop(context);
                    _showSafeSnackBar('変更内容がありません',
                        backgroundColor: Colors.orange);
                    return;
                  }

                  Navigator.pop(context);
                  _showLoadingDialog();

                  final success = await PostService.editContent(
                    contentId: post.id,
                    title: hasTitle ? titleText : null,
                    tag: clearTag ? '' : (tagText.isNotEmpty ? tagText : null),
                  );

                  if (!mounted) return;
                  _closeLoadingDialog();

                  if (success) {
                    await _showCompletionDialog();
                    if (mounted) {
                      await _fetchUserContents();
                    }
                  } else {
                    _showSafeSnackBar('投稿の更新に失敗しました',
                        backgroundColor: Colors.red);
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSafeSnackBar(String message,
      {Color? backgroundColor, Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }

  void _showLoadingDialog() {
    if (!mounted || _isLoadingDialogShown) return;
    _isLoadingDialogShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  void _closeLoadingDialog() {
    if (!mounted || !_isLoadingDialogShown) return;
    _isLoadingDialogShown = false;
    Navigator.of(context).pop();
  }

  Future<void> _showCompletionDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完了'),
        content: const Text('投稿を更新しました'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShareButton(Post post) async {
    if (kDebugMode) {
      debugPrint('🔗 [自分の投稿] 共有ボタン: postId=${post.id}');
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '共有',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
      ),
      onTap: onTap,
    );
  }

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

  Future<void> _handlePlaylistAdd(Post post) async {
    if (kDebugMode) {
      debugPrint('📂 [自分の投稿] 再生リスト追加: postId=${post.id}');
    }

    try {
      final playlists = await PlaylistService.getPlaylists();
      if (!mounted) return;
      _showPlaylistDialog(post, playlists);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [自分の投稿] プレイリスト取得エラー: $e');
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

  void _showRemoveSpotlightDialog(BuildContext context, Post post, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('スポットライトを解除'),
        content: const Text('この投稿のスポットライトを解除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await PostService.spotlightOff(post.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('スポットライトを解除しました'),
                    backgroundColor: Colors.green,
                  ),
                );
                _fetchUserContents();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('スポットライトの解除に失敗しました'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              '解除',
              style: TextStyle(color: Color(0xFFFF6B35)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSpotlightDialog(BuildContext context, Post post, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('スポットライトを付ける'),
        content: const Text('この投稿にスポットライトを付けますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await PostService.spotlightOn(post.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('スポットライトを付けました'),
                    backgroundColor: Colors.green,
                  ),
                );
                _fetchUserContents();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('スポットライトの付与に失敗しました'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              '付ける',
              style: TextStyle(color: Color(0xFFFF6B35)),
            ),
          ),
        ],
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
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
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
                                backgroundColor: Colors.red),
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
