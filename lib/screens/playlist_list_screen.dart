import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../services/playlist_service.dart';
import '../services/share_link_service.dart';
import '../config/app_config.dart';
import '../widgets/robust_network_image.dart';
import '../utils/spotlight_colors.dart';
import '../widgets/blur_app_bar.dart';
import 'playlist_detail_screen.dart';

class PlaylistListScreen extends StatefulWidget {
  const PlaylistListScreen({super.key});

  @override
  State<PlaylistListScreen> createState() => _PlaylistListScreenState();
}

class _PlaylistListScreenState extends State<PlaylistListScreen> {
  List<Playlist> _playlists = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Map<int, String?> _playlistFirstContentThumbnails = {};

  @override
  void initState() {
    super.initState();
    _fetchPlaylists();
  }

  /// プレイリストを取得
  Future<void> _fetchPlaylists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var playlists = await PlaylistService.getPlaylists();
      playlists = await _ensureSpotlightPlaylist(playlists);
      playlists = _sortPlaylists(playlists);

      if (kDebugMode) {
        debugPrint('📝 プレイリスト一覧取得完了: ${playlists.length}件');
      }

      if (mounted) {
        setState(() {
          _playlists = playlists;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ プレイリスト一覧取得エラー: $e');
      }

      if (mounted) {
        setState(() {
          _errorMessage = 'プレイリストの取得に失敗しました';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Playlist>> _ensureSpotlightPlaylist(
      List<Playlist> playlists) async {
    Playlist? spotlight = _findSpotlightPlaylist(playlists);

    if (spotlight == null) {
      final createdId = await PlaylistService.createPlaylist(
          PlaylistService.spotlightPlaylistTitle);
      if (createdId != null) {
        playlists = await PlaylistService.getPlaylists();
        spotlight = _findSpotlightPlaylist(playlists);
      }
    }

    if (spotlight != null) {
      await PlaylistService.syncSpotlightPlaylist(spotlight.playlistid);
    }

    return playlists;
  }

  List<Playlist> _sortPlaylists(List<Playlist> playlists) {
    final spotlight = playlists.where(_isSpotlightPlaylist).toList();
    final others = playlists.where((p) => !_isSpotlightPlaylist(p)).toList();
    return [...spotlight, ...others];
  }

  Playlist? _findSpotlightPlaylist(List<Playlist> playlists) {
    try {
      return playlists.firstWhere(_isSpotlightPlaylist);
    } catch (_) {
      return null;
    }
  }

  bool _isSpotlightPlaylist(Playlist playlist) {
    return playlist.title == PlaylistService.spotlightPlaylistTitle;
  }

  Future<String?> _getFirstContentThumbnail(int playlistId) async {
    if (_playlistFirstContentThumbnails.containsKey(playlistId)) {
      return _playlistFirstContentThumbnails[playlistId];
    }

    try {
      final contentsJson = await PlaylistService.getPlaylistDetail(playlistId);
      if (contentsJson.isEmpty) {
        _playlistFirstContentThumbnails[playlistId] = null;
        return null;
      }

      final firstContent = contentsJson[0];
      final thumbnailpath = firstContent['thumbnailpath']?.toString();
      if (thumbnailpath == null || thumbnailpath.isEmpty) {
        _playlistFirstContentThumbnails[playlistId] = null;
        return null;
      }

      String thumbnailUrl;
      if (thumbnailpath.startsWith('http://') ||
          thumbnailpath.startsWith('https://')) {
        thumbnailUrl = thumbnailpath;
      } else {
        final normalizedPath =
            thumbnailpath.startsWith('/') ? thumbnailpath : '/$thumbnailpath';
        thumbnailUrl = '${AppConfig.backendUrl}$normalizedPath';
      }

      _playlistFirstContentThumbnails[playlistId] = thumbnailUrl;
      return thumbnailUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 再生リストの最初のコンテンツ取得エラー: $e');
      }
      _playlistFirstContentThumbnails[playlistId] = null;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? Colors.white : const Color(0xFF1A1A1A);
    final secondaryTextColor =
        isDark ? Colors.grey[400]! : const Color(0xFF5A5A5A);
    final thumbnailBackgroundColor = isDark
        ? Colors.grey[800]!
        : SpotLightColors.peach.withOpacity(0.2);
    final placeholderIconColor =
        isDark ? Colors.white : const Color(0xFF5A5A5A);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: BlurAppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: const Text('再生リスト'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              // 新しい再生リスト作成
              _showCreatePlaylistDialog(context);
            },
            icon: const Icon(Icons.add),
          ),
          IconButton(
            onPressed: _fetchPlaylists,
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
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
                        onPressed: _fetchPlaylists,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                        ),
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _playlists.isEmpty
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
                            '再生リストがありません',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '右上の+ボタンから新しい再生リストを作成できます',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = _playlists[index];
                        return GestureDetector(
                          onTap: () async {
                            if (kDebugMode) {
                              debugPrint(
                                  '📋 プレイリストをタップ: ID=${playlist.playlistid}, タイトル=${playlist.title}');
                            }
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlaylistDetailScreen(
                                  playlistId: playlist.playlistid,
                                  playlistTitle: playlist.title,
                                ),
                              ),
                            );
                            // 戻ってきた時にプレイリスト一覧を再取得（更新があった可能性があるため）
                            if (result == true || mounted) {
                              if (kDebugMode) {
                                debugPrint(
                                    '📋 [プレイリスト一覧] 詳細画面から戻ってきました。再取得します。');
                              }
                              _fetchPlaylists();
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
                                    child: FutureBuilder<String?>(
                                      future: _getFirstContentThumbnail(
                                          playlist.playlistid),
                                      builder: (context, snapshot) {
                                        final thumbnailUrl = snapshot.data;
                                        if (thumbnailUrl != null &&
                                            thumbnailUrl.isNotEmpty) {
                                          return Stack(
                                            children: [
                                              Positioned.fill(
                                                child: RobustNetworkImage(
                                                  imageUrl: thumbnailUrl,
                                                  fit: BoxFit.cover,
                                                  maxWidth: 320,
                                                  maxHeight: 180,
                                                  placeholder: const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: Color(0xFFFF6B35),
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Center(
                                                child: Icon(
                                                  Icons.playlist_play,
                                                  color: placeholderIconColor,
                                                  size: 32,
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                        return Center(
                                          child: Icon(
                                            Icons.playlist_play,
                                            color: placeholderIconColor,
                                            size: 32,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // タイトルと情報
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        playlist.title,
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
                                        playlist.username?.isNotEmpty == true
                                            ? playlist.username!
                                            : 'ユーザー名なし',
                                        style: TextStyle(
                                          color: secondaryTextColor,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // メニューボタン
                                IconButton(
                                  onPressed: () {
                                    _showPlaylistMenuBottomSheet(
                                        context, playlist, index);
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
                      },
                    ),
    );
  }

  /// プレイリスト作成ダイアログ
  void _showCreatePlaylistDialog(BuildContext context) {
    final titleController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新しい再生リストを作成'),
          content: TextField(
            controller: titleController,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            decoration: InputDecoration(
              hintText: '再生リスト名を入力',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor:
                  isDark ? Colors.grey[800] : SpotLightColors.peach.withOpacity(0.2),
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
                  if (kDebugMode) {
                    debugPrint('✅ プレイリスト作成成功: ID=$playlistId');
                  }
                  // プレイリスト一覧を再取得
                  _fetchPlaylists();
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

  void _showPlaylistMenuBottomSheet(
      BuildContext context, Playlist playlist, int index) {
    final isSpotlight = _isSpotlightPlaylist(playlist);
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuOption(
              icon: Icons.play_arrow,
              title: '再生',
              onTap: () {
                Navigator.pop(context);
                // 再生リストを再生
              },
            ),
            _buildMenuOption(
              icon: Icons.edit,
              title: '編集',
              onTap: () {
                Navigator.pop(context);
                // 再生リストを編集
              },
            ),
            _buildMenuOption(
              icon: Icons.share,
              title: '共有',
              onTap: () {
                Navigator.pop(context);
                final shareText =
                    ShareLinkService.buildPlaylistShareText(playlist);
                Share.share(
                  shareText,
                  subject: playlist.title,
                  sharePositionOrigin: _getSharePositionOrigin(),
                );
              },
            ),
            _buildMenuOption(
              icon: Icons.copy,
              title: '複製',
              onTap: () {
                Navigator.pop(context);
                // 再生リストを複製
              },
            ),
            if (!isSpotlight)
              _buildMenuOption(
                icon: Icons.delete_outline,
                title: '削除',
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmDialog(context, playlist, index);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(
      BuildContext context, Playlist playlist, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('再生リストを削除'),
        content: const Text('この再生リストを削除しますか？この操作は取り消せません。'),
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

              final success =
                  await PlaylistService.deletePlaylist(playlist.playlistid);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('プレイリストを削除しました'),
                    backgroundColor: Colors.green,
                  ),
                );
                // プレイリスト一覧を再取得
                _fetchPlaylists();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('プレイリストの削除に失敗しました。エンドポイントが実装されていない可能性があります。'),
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
