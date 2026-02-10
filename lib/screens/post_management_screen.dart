import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../models/post.dart';
import '../utils/spotlight_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/blur_app_bar.dart';


/// 投稿管理画面（管理者用）
class PostManagementScreen extends StatefulWidget {
  const PostManagementScreen({super.key});

  @override
  State<PostManagementScreen> createState() => _PostManagementScreenState();
}

class _PostManagementScreenState extends State<PostManagementScreen> {
  List<Post> _posts = [];
  Map<String, int> _reportCounts = {}; // contentID -> 通報数
  Map<String, bool> _hasReports = {}; // contentID -> 通報があるか
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedType = 'all'; // all, video, image, audio, text
  int _currentOffset = 0; // /api/admin/content2 用のoffset
  static const int _pageSize = 300; // バックエンドのLIMITに合わせる

  @override
  void initState() {
    super.initState();
    _fetchPostsAndReports();
  }

  /// 投稿一覧と通報情報を取得
  Future<void> _fetchPostsAndReports({bool loadMore = false}) async {
    if (loadMore) {
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentOffset = 0;
      });
    }

    try {
      // 投稿一覧を取得（/api/admin/content2）
      final contents = await AdminService.getAllContentsV2(
        offset: loadMore ? _currentOffset : 0,
      );

      if (contents == null) {
        throw Exception('コンテンツの取得に失敗しました');
      }

      final posts = contents
          .map((content) => Post.fromJson(content))
          .toList();

      // 通報一覧を取得
      final reports = await AdminService.getReports(offset: 0);

      if (reports != null) {
        // 通報数をカウント
        final Map<String, int> counts = {};
        final Map<String, bool> hasReports = {};
        
        for (final report in reports) {
          final contentID = report['contentID']?.toString();
          if (contentID != null && contentID.isNotEmpty) {
            counts[contentID] = (counts[contentID] ?? 0) + 1;
            hasReports[contentID] = true;
          }
        }

        setState(() {
          if (loadMore) {
            _posts.addAll(posts);
          } else {
            _posts = posts;
          }
          _reportCounts = counts;
          _hasReports = hasReports;
          _currentOffset = loadMore
              ? _currentOffset + posts.length
              : posts.length;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          if (loadMore) {
            _posts.addAll(posts);
          } else {
            _posts = posts;
          }
          _currentOffset = loadMore
              ? _currentOffset + posts.length
              : posts.length;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'エラーが発生しました: $e';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  /// 投稿を削除
  Future<void> _deletePost(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('投稿を削除'),
        content: Text(
          '投稿「${post.title}」を削除しますか？\nこの操作は取り消せません。',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // ローディング表示
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await AdminService.deleteContent(post.id);

      if (!mounted) return;
      Navigator.of(context).pop(); // ローディングを閉じる

      if (success) {
        // リストから削除
        setState(() {
          _posts.removeWhere((p) => p.id == post.id);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('投稿の削除に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // ローディングを閉じる
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// フィルタリングされた投稿リストを取得
  List<Post> get _filteredPosts {
    var filtered = _posts;

    // タイプでフィルタリング
    if (_selectedType != 'all') {
      filtered = filtered.where((post) {
        switch (_selectedType) {
          case 'video':
            return post.postType == PostType.video;
          case 'image':
            return post.postType == PostType.image;
          case 'audio':
            return post.postType == PostType.audio;
          case 'text':
            return post.postType == PostType.text;
          default:
            return true;
        }
      }).toList();
    }

    // 検索クエリでフィルタリング
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((post) {
        return post.title.toLowerCase().contains(query) ||
            post.username.toLowerCase().contains(query) ||
            post.id.contains(query);
      }).toList();
    }

    return filtered;
  }

  /// 投稿タイプの日本語名を取得
  String _getPostTypeName(PostType type) {
    switch (type) {
      case PostType.video:
        return '動画';
      case PostType.image:
        return '画像';
      case PostType.audio:
        return '音声';
      case PostType.text:
        return 'テキスト';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: BlurAppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '投稿管理',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _fetchPostsAndReports(),
            tooltip: '更新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 検索バーとフィルター
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.cardColor,
            child: Column(
              children: [
                // 検索バー
                TextField(
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: 'タイトル、ユーザー名、IDで検索',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: theme.brightness == Brightness.dark
                        ? const Color(0xFF1E1E1E)
                        : Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // フィルター
                Row(
                  children: [
                    const Text('タイプ:', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('all', 'すべて'),
                            _buildFilterChip('video', '動画'),
                            _buildFilterChip('image', '画像'),
                            _buildFilterChip('audio', '音声'),
                            _buildFilterChip('text', 'テキスト'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 投稿リスト
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64, color: Colors.grey[600]),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.grey[400]),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _fetchPostsAndReports(),
                              child: const Text('再試行'),
                            ),
                          ],
                        ),
                      )
                    : _filteredPosts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 64, color: Colors.grey[600]),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? '検索結果が見つかりませんでした'
                                      : '投稿がありません',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _fetchPostsAndReports(),
                            child: ListView.builder(
                              itemCount: _filteredPosts.length + 1,
                              itemBuilder: (context, index) {
                                if (index == _filteredPosts.length) {
                                  // 最後に「もっと読み込む」ボタンを表示
                                  if (_isLoadingMore) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Center(
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _fetchPostsAndReports(loadMore: true),
                                        child: const Text('もっと読み込む'),
                                      ),
                                    ),
                                  );
                                }

                                final post = _filteredPosts[index];
                                return _buildPostItem(post);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedType = value;
          });
        },
        selectedColor: SpotLightColors.primaryOrange.withValues(alpha: 0.3),
        checkmarkColor: SpotLightColors.primaryOrange,
        labelStyle: TextStyle(
          color: isSelected
              ? SpotLightColors.primaryOrange
              : Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildPostItem(Post post) {
    final theme = Theme.of(context);
    final reportCount = _reportCounts[post.id] ?? 0;
    final hasReport = _hasReports[post.id] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: hasReport
            ? Border.all(color: Colors.red, width: 2)
            : Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: InkWell(
        onTap: () => _showPostDetail(post),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // サムネイル
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: post.thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: post.thumbnailUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[800],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[800],
                        child: Icon(Icons.broken_image,
                            color: Colors.grey[600]),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[800],
                      child: Icon(
                        post.postType == PostType.video
                            ? Icons.videocam
                            : post.postType == PostType.image
                                ? Icons.image
                                : post.postType == PostType.audio
                                    ? Icons.audiotrack
                                    : Icons.text_fields,
                        color: Colors.grey[600],
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // 投稿情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // タイトル
                  Text(
                    post.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // ユーザー名とタイプ
                  Row(
                    children: [
                      Text(
                        post.username,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: SpotLightColors.primaryOrange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getPostTypeName(post.postType),
                          style: const TextStyle(
                            color: SpotLightColors.primaryOrange,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 投稿IDと通報情報
                  Row(
                    children: [
                      Text(
                        'ID: ${post.id}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                      if (hasReport) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.flag,
                                  color: Colors.red, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                '$reportCount件の通報',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 削除ボタン
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deletePost(post),
              tooltip: '削除',
            ),
          ],
        ),
      ),
    );
  }

  /// 投稿詳細を表示
  void _showPostDetail(Post post) {
    final reportCount = _reportCounts[post.id] ?? 0;
    final hasReport = _hasReports[post.id] ?? false;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '投稿詳細',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              // タイトル
              Text(
                'タイトル',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                post.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // 投稿ID
              Text(
                '投稿ID',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                post.id,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              // ユーザー名
              Text(
                '投稿者',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                post.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              // タイプ
              Text(
                'タイプ',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getPostTypeName(post.postType),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              // 通報情報
              if (hasReport) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        '$reportCount件の通報があります',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // メディアURL
              if (post.mediaUrl != null) ...[
                Text(
                  'メディアURL',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  post.mediaUrl!,
                  style: TextStyle(
                    color: Colors.blue[300],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // サムネイルURL
              if (post.thumbnailUrl != null) ...[
                Text(
                  'サムネイルURL',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  post.thumbnailUrl!,
                  style: TextStyle(
                    color: Colors.blue[300],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // アクションボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('閉じる'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deletePost(post);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('削除'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

