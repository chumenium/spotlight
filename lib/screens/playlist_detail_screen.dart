import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../services/playlist_service.dart';
import '../widgets/robust_network_image.dart';
import '../providers/navigation_provider.dart';
import '../utils/spotlight_colors.dart';
import '../config/app_config.dart';

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

      // API仕様書のレスポンスから直接Postオブジェクトを作成
      // レスポンスには既に必要な情報が含まれているため、追加のAPI呼び出しは不要
      final List<Post> posts = [];
      for (final item in contentsJson) {
        try {
          final post = _createPostFromApiResponse(item);
          if (post != null) {
            posts.add(post);
          }
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

  /// APIレスポンスからPostオブジェクトを作成
  /// API仕様書のレスポンス形式に基づく:
  /// {
  ///   "contentID": 1,
  ///   "title": "タイトル",
  ///   "spotlightnum": 3,
  ///   "posttimestamp": "2025-01-01 12:00:00",
  ///   "playnum": 100,
  ///   "link": "https://...",
  ///   "thumbnailpath": "content/thumbnail/xxx.jpg"
  /// }
  Post? _createPostFromApiResponse(Map<String, dynamic> item) {
    try {
      // contentIDを取得（複数のキー名に対応）
      final contentIdValue = item['contentID'] ??
          item['contentid'] ??
          item['contentId'] ??
          item['content_id'] ??
          item['ContentID'] ??
          item['ContentId'];

      if (contentIdValue == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [プレイリスト詳細] contentIDが見つかりません: $item');
        }
        return null;
      }

      final contentId = contentIdValue.toString();

      // titleを取得
      final title = item['title']?.toString() ?? 'タイトルなし';

      // spotlightnumを取得
      final spotlightnum = _parseInt(item['spotlightnum']) ?? 0;

      // posttimestampを取得してDateTimeに変換
      DateTime createdAt;
      try {
        final timestampStr = item['posttimestamp']?.toString();
        if (timestampStr != null && timestampStr.isNotEmpty) {
          // ISO 8601形式または "YYYY-MM-DD HH:MM:SS" 形式をパース
          createdAt = DateTime.tryParse(timestampStr) ??
              _parseDateTime(timestampStr) ??
              DateTime.now();
        } else {
          createdAt = DateTime.now();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [プレイリスト詳細] 日時パースエラー: $e');
        }
        createdAt = DateTime.now();
      }

      // playnumを取得
      final playnum = _parseInt(item['playnum']) ?? 0;

      // linkを取得
      final link = item['link']?.toString();

      // thumbnailpathを取得して完全なURLに変換
      final thumbnailpath = item['thumbnailpath']?.toString();
      String? thumbnailUrl;
      if (thumbnailpath != null && thumbnailpath.isNotEmpty) {
        thumbnailUrl = _buildFullUrl(AppConfig.backendUrl, thumbnailpath);
      }

      // PostTypeを決定（linkまたはthumbnailpathから推測）
      PostType postType = PostType.video; // デフォルト
      if (link != null && link.isNotEmpty) {
        final lowerLink = link.toLowerCase();
        if (lowerLink.contains('.mp4') ||
            lowerLink.contains('.mov') ||
            lowerLink.contains('.avi')) {
          postType = PostType.video;
        } else if (lowerLink.contains('.jpg') ||
            lowerLink.contains('.jpeg') ||
            lowerLink.contains('.png')) {
          postType = PostType.image;
        } else if (lowerLink.contains('.mp3') ||
            lowerLink.contains('.wav') ||
            lowerLink.contains('.m4a')) {
          postType = PostType.audio;
        }
      }

      // Postオブジェクトを作成
      // API仕様書には含まれていない情報はデフォルト値を使用
      return Post(
        id: contentId,
        userId: '', // API仕様書に含まれていない
        username: '', // API仕様書に含まれていない
        userIconPath: '', // API仕様書に含まれていない
        title: title,
        content: null, // API仕様書に含まれていない
        contentPath: link ?? '', // linkをcontentPathとして使用
        type: postType.name,
        mediaUrl:
            link != null ? _buildFullUrl(AppConfig.backendUrl, link) : null,
        thumbnailUrl: thumbnailUrl,
        likes: spotlightnum,
        playNum: playnum,
        link: link,
        comments: 0, // API仕様書に含まれていない
        shares: 0, // API仕様書に含まれていない
        isSpotlighted: spotlightnum > 0,
        isText: postType == PostType.text,
        nextContentId: null, // API仕様書に含まれていない
        createdAt: createdAt,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [プレイリスト詳細] Post作成エラー: $e');
        debugPrint('   - 項目: $item');
      }
      return null;
    }
  }

  /// 数値を安全にパース
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  /// 日時文字列をパース（"YYYY-MM-DD HH:MM:SS"形式）
  DateTime? _parseDateTime(String dateTimeStr) {
    try {
      // "2025-01-01 12:00:00" 形式をパース
      final parts = dateTimeStr.split(' ');
      if (parts.length == 2) {
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        if (dateParts.length == 3 && timeParts.length >= 2) {
          final year = int.tryParse(dateParts[0]) ?? 0;
          final month = int.tryParse(dateParts[1]) ?? 1;
          final day = int.tryParse(dateParts[2]) ?? 1;
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = int.tryParse(timeParts[1]) ?? 0;
          final second =
              timeParts.length >= 3 ? (int.tryParse(timeParts[2]) ?? 0) : 0;
          return DateTime(year, month, day, hour, minute, second);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [プレイリスト詳細] 日時パースエラー: $e, dateTimeStr=$dateTimeStr');
      }
    }
    return null;
  }

  /// URLを構築
  String? _buildFullUrl(String? backendUrl, String? path) {
    if (path == null || path.isEmpty) return null;
    if (backendUrl == null || backendUrl.isEmpty) return path;

    // 既に完全なURLの場合はそのまま返す
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    // 絶対パスの場合
    if (path.startsWith('/')) {
      final baseUri = Uri.parse(backendUrl);
      return baseUri.replace(path: path).toString();
    }

    // 相対パスの場合
    final baseUri = Uri.parse(backendUrl);
    return baseUri.resolve(path).toString();
  }

  /// 日付を相対時間に変換
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
                        style: const TextStyle(
                          color: Colors.white,
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
    return GestureDetector(
      onTap: () {
        try {
          final postId = post.id.toString();
          if (postId.isNotEmpty) {
            final navigationProvider =
                Provider.of<NavigationProvider>(context, listen: false);
            navigationProvider.navigateToHome(postId: postId);

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
                color: Colors.grey[800],
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
                    _getSafeTitle(post.title),
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
              icon: Icons.remove_circle_outline,
              title: 'プレイリストから削除',
              onTap: () {
                Navigator.pop(context);
                if (kDebugMode) {
                  debugPrint('📋 [プレイリスト詳細] プレイリストから削除: contentID=${post.id}');
                }
              },
            ),
            _buildMenuOption(
              icon: Icons.share,
              title: '共有',
              onTap: () {
                Navigator.pop(context);
                // 共有機能（将来実装）
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
