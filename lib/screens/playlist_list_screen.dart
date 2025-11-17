import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../services/playlist_service.dart';
import '../config/app_config.dart';
import '../widgets/robust_network_image.dart';

class PlaylistListScreen extends StatefulWidget {
  const PlaylistListScreen({super.key});

  @override
  State<PlaylistListScreen> createState() => _PlaylistListScreenState();
}

class _PlaylistListScreenState extends State<PlaylistListScreen> {
  List<Playlist> _playlists = [];
  bool _isLoading = true;
  String? _errorMessage;

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
      final playlists = await PlaylistService.getPlaylists();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
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
                        style: const TextStyle(
                          color: Colors.white,
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
                        return Container(
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
                                  child: playlist.thumbnailpath != null &&
                                          playlist.thumbnailpath!.isNotEmpty
                                      ? RobustNetworkImage(
                                          imageUrl:
                                              '${AppConfig.backendUrl}${playlist.thumbnailpath}',
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
                                            const Center(
                                              child: Icon(
                                                Icons.playlist_play,
                                                color: Colors.white,
                                                size: 32,
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
                                      playlist.title,
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
                        );
                      },
                    ),
    );
  }

  /// プレイリスト作成ダイアログ
  void _showCreatePlaylistDialog(BuildContext context) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            '新しい再生リストを作成',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '再生リスト名を入力',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[800],
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
                // 再生リストを共有
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
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          '再生リストを削除',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'この再生リストを削除しますか？この操作は取り消せません。',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 削除処理
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
