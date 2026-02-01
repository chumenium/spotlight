import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/playlist_service.dart';
import '../widgets/robust_network_image.dart';
import '../providers/navigation_provider.dart';
import '../utils/spotlight_colors.dart';
import '../config/app_config.dart';
import '../services/share_link_service.dart';
import '../widgets/blur_app_bar.dart';

/// プレイリスト詳細画面
/// API仕様書（API_ENDPOINTS.md 135-156行目）に基づいて実装
class PlaylistDetailScreen extends StatefulWidget {
  final int playlistId;
  final String playlistTitle;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistTitle,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<Post> _contents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPlaylistContents();
  }

  /// プレイリストのコンテンツを取得
  /// API仕様書に基づいて実装
  Future<void> _fetchPlaylistContents() async {
    if (kDebugMode) {
      debugPrint('📋 [プレイリスト詳細] ========== コンテンツ取得開始 ==========');
      debugPrint('📋 [プレイリスト詳細] playlistId: ${widget.playlistId}');
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      if (widget.playlistTitle == PlaylistService.spotlightPlaylistTitle) {
        await PlaylistService.syncSpotlightPlaylist(widget.playlistId);
      }

      // API仕様書に基づいて、getplaylistdetailを呼び出す
      // レスポンス: { "status": "success", "data": [...] }
      // 各データ項目: contentID, title, spotlightnum, posttimestamp, playnum, link, thumbnailpath
      final contentsJson =
          await PlaylistService.getPlaylistDetail(widget.playlistId);

      if (kDebugMode) {
        debugPrint('📋 [プレイリスト詳細] API取得完了: ${contentsJson.length}件');
        if (contentsJson.isNotEmpty) {
          debugPrint('📋 [プレイリスト詳細] 最初の項目: ${contentsJson[0]}');
        }
      }

      if (contentsJson.isEmpty) {
        if (mounted) {
          setState(() {
            _contents = [];
            _isLoading = false;
          });
        }
        if (kDebugMode) {
          debugPrint('📋 [プレイリスト詳細] コンテンツが空です');
        }
        return;
      }

      // バックエンドから返されたデータでPostオブジェクトを作成
      final List<Post> posts = [];

      for (final item in contentsJson) {
        try {
          final contentId = item['contentID']?.toString() ?? '';
          if (contentId.isEmpty) continue;

          // linkをcontentpathとして使用
          final link = item['link']?.toString();
          final postData = Map<String, dynamic>.from(item);
          postData['contentID'] = contentId;
          if (link != null && link.isNotEmpty) {
            postData['contentpath'] = link;
          }

          // Post.fromJsonを使用（S3（CloudFront）のURLを正しく処理）
          final post =
              Post.fromJson(postData, backendUrl: AppConfig.backendUrl);
          posts.add(post);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [プレイリスト詳細] Post作成エラー: $e');
            debugPrint('   - 項目: $item');
          }
        }
      }

      if (kDebugMode) {
        debugPrint(
            '📋 [プレイリスト詳細] Post作成完了: ${posts.length}件 / ${contentsJson.length}件');
        if (posts.isNotEmpty) {
          debugPrint(
              '📋 [プレイリスト詳細] 最初のPost: ID=${posts[0].id}, タイトル=${posts[0].title}');
        }
      }

      if (mounted) {
        setState(() {
          _contents = posts;
          _isLoading = false;
        });
        if (kDebugMode) {
          debugPrint('📋 [プレイリスト詳細] 状態更新完了: ${_contents.length}件');
        }
      }

      if (posts.isNotEmpty) {
        final enrichedPosts = await _enrichPlaylistContents(posts);
        if (mounted) {
          setState(() {
            _contents = enrichedPosts;
          });
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [プレイリスト詳細] エラー: $e');
        debugPrint('❌ [プレイリスト詳細] スタックトレース: $stackTrace');
      }

      if (mounted) {
        setState(() {
          _errorMessage = 'プレイリストの取得に失敗しました';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Post>> _enrichPlaylistContents(List<Post> posts) async {
    if (posts.isEmpty) return posts;

    if (kDebugMode) {
      debugPrint('📋 [プレイリスト詳細] ユーザー情報補完: ${posts.length}件のコンテンツを取得します');
    }

    final futures = posts.map((post) => PostService.fetchContentById(post.id));
    final details = await Future.wait<Post?>(futures);

    final enriched = <Post>[];
    for (var i = 0; i < posts.length; i++) {
      final original = posts[i];
      final detail = details[i];
      if (detail == null) {
        enriched.add(original);
        continue;
      }
      enriched.add(_mergePostKeepingThumbnail(original, detail));
    }

    if (kDebugMode) {
      final enrichedCount =
          enriched.where((post) => post.userId.isNotEmpty).length;
      debugPrint(
          '📋 [プレイリスト詳細] 補完結果: ${enrichedCount}/${posts.length}件でuserIdを取得');
    }

    return enriched;
  }

  Post _mergePostKeepingThumbnail(Post original, Post detail) {
    final thumbnailUrl =
        detail.thumbnailUrl != null && detail.thumbnailUrl!.isNotEmpty
            ? detail.thumbnailUrl
            : original.thumbnailUrl;
    final mediaUrl = detail.mediaUrl != null && detail.mediaUrl!.isNotEmpty
        ? detail.mediaUrl
        : original.mediaUrl;

    return Post(
      id: detail.id,
      userId: detail.userId,
      username: detail.username,
      userIconPath: detail.userIconPath,
      userIconUrl: detail.userIconUrl ?? original.userIconUrl,
      title: detail.title,
      content: detail.content ?? original.content,
      contentPath:
          detail.contentPath.isNotEmpty ? detail.contentPath : original.contentPath,
      type: detail.type,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      likes: detail.likes,
      playNum: detail.playNum,
      link: detail.link ?? original.link,
      comments: detail.comments,
      shares: detail.shares,
      isSpotlighted: detail.isSpotlighted,
      isText: detail.isText,
      nextContentId: detail.nextContentId ?? original.nextContentId,
      createdAt: detail.createdAt,
    );
  }

  /// 日付を相対時間に変換
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
        title: Text(widget.playlistTitle),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchPlaylistContents,
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
                        onPressed: _fetchPlaylistContents,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                        ),
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _contents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.playlist_play,
                            color: Colors.grey[600],
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'このプレイリストにはコンテンツがありません',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'コンテンツを追加すると\nここに表示されます',
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
                      onRefresh: _fetchPlaylistContents,
                      color: const Color(0xFFFF6B35),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _contents.length,
                        itemBuilder: (context, index) {
                          final post = _contents[index];
                          return _buildContentItem(context, post, index);
                        },
                      ),
                    ),
    );
  }

  Widget _buildContentItem(BuildContext context, Post post, int index) {
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
      onTap: () {
        try {
          final postId = post.id.toString();
          if (postId.isNotEmpty) {
            final navigationProvider =
                Provider.of<NavigationProvider>(context, listen: false);

            // ホーム画面に遷移して対象のコンテンツを表示
            navigationProvider.navigateToHome(
                postId: postId, postTitle: _getSafeTitle(post.title));

            // 現在の画面を閉じてホーム画面に戻る
            Navigator.of(context).popUntil((route) => route.isFirst);

            if (kDebugMode) {
              debugPrint(
                  '📱 [プレイリスト詳細] 投稿をタップ: ID=$postId, タイトル=${_getSafeTitle(post.title)}');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [プレイリスト詳細] タップエラー: $e');
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
                child: _hasValidThumbnail(post.thumbnailUrl)
                    ? RobustNetworkImage(
                        imageUrl: post.thumbnailUrl ?? '',
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
                    _getSafeTitle(post.title),
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

  /// サムネイルURLが有効かチェック
  bool _hasValidThumbnail(String? thumbnailUrl) {
    return thumbnailUrl != null && thumbnailUrl.isNotEmpty;
  }

  /// タイトルを安全に取得
  String _getSafeTitle(String? title) {
    if (title == null || title.isEmpty) {
      return 'タイトルなし';
    }
    return title;
  }

  void _showMenuBottomSheet(BuildContext context, Post post, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuOption(
              icon: Icons.remove_circle_outline,
              title: 'プレイリストから削除',
              onTap: () {
                Navigator.pop(context);
                _showRemoveFromPlaylistDialog(context, post, index);
              },        
            ),
            _buildMenuOption(
              icon: Icons.share,
              title: '共有',
              onTap: () {
                Navigator.pop(context);
                final shareText =
                    ShareLinkService.buildPostShareText(post.title, post.id);
                Share.share(
                  shareText,
                  subject: post.title,
                  sharePositionOrigin: _getSharePositionOrigin(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveFromPlaylistDialog(
      BuildContext context, Post post, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('プレイリストから削除'),
        content: const Text('このコンテンツをプレイリストから削除しますか？'),
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

              final success = await PlaylistService.removeContentFromPlaylist(
                widget.playlistId,
                post.id.toString(),
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('プレイリストから削除しました'),
                    backgroundColor: Colors.green,
                  ),
                );
                _fetchPlaylistContents();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('削除に失敗しました。エンドポイントが実装されていない可能性があります。'),
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
}
