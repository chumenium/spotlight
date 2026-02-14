import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/admin_service.dart';
import '../config/app_config.dart';
import '../utils/spotlight_colors.dart';
import 'user_detail_screen.dart';
import '../widgets/blur_app_bar.dart';

/// ユーザー管理画面
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  /// ユーザー一覧を取得
  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await AdminService.getAllUsers();

      if (users != null) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'ユーザー情報の取得に失敗しました';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'エラーが発生しました: $e';
        _isLoading = false;
      });
    }
  }

  /// 検索フィルタリングされたユーザーリストを取得
  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _users;
    }

    final query = _searchQuery.toLowerCase();
    return _users.where((user) {
      final username = (user['username'] ?? '').toString().toLowerCase();
      final userID = (user['userID'] ?? '').toString().toLowerCase();
      return username.contains(query) || userID.contains(query);
    }).toList();
  }

  /// アイコンURLを生成
  String _getIconUrl(Map<String, dynamic> user) {
    final iconPath = user['iconimgpath']?.toString() ?? '';
    
    if (iconPath.isEmpty) {
      return '${AppConfig.backendUrl}/icon/default_icon.png';
    }

    if (iconPath.startsWith('http://') || iconPath.startsWith('https://')) {
      return iconPath;
    }

    if (iconPath.startsWith('/icon/')) {
      return '${AppConfig.backendUrl}$iconPath';
    }

    return '${AppConfig.backendUrl}/icon/$iconPath';
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
          'ユーザー管理',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchUsers,
            tooltip: '更新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 検索バー
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ユーザー名またはIDで検索',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // 統計情報
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  '総ユーザー数',
                  '${_users.length}',
                  Icons.people,
                ),
                _buildStatCard(
                  '管理者',
                  '${_users.where((u) => u['admin'] == true).length}',
                  Icons.admin_panel_settings,
                ),
              ],
            ),
          ),

          // ユーザーリスト
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: SpotLightColors.primaryOrange,
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[400],
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchUsers,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SpotLightColors.primaryOrange,
                              ),
                              child: const Text('再試行'),
                            ),
                          ],
                        ),
                      )
                    : _filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  color: Colors.grey[600],
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'ユーザーが見つかりません'
                                      : '検索結果が見つかりません',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchUsers,
                            color: SpotLightColors.primaryOrange,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
                                return _buildUserCard(user);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// 統計カードを構築
  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: SpotLightColors.primaryOrange, size: 24),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ユーザーカードを構築
  Widget _buildUserCard(Map<String, dynamic> user) {
    final username = user['username']?.toString() ?? '不明';
    final userID = user['userID']?.toString() ?? '';
    final isAdmin = user['admin'] == true;
    final spotlightnum = user['spotlightnum'] ?? 0;
    final reportnum = user['reportnum'] ?? 0;
    final reportednum = user['reportednum'] ?? 0;
    final iconUrl = _getIconUrl(user);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAdmin
              ? SpotLightColors.primaryOrange.withOpacity(0.5)
              : Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: SpotLightColors.primaryOrange,
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: iconUrl,
              fit: BoxFit.cover,
              width: 56,
              height: 56,
              httpHeaders: const {
                'Accept': 'image/webp,image/avif,image/*,*/*;q=0.8',
                'User-Agent': 'Flutter-Spotlight/1.0',
              },
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (context, url) => Container(
                color: SpotLightColors.primaryOrange,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: SpotLightColors.primaryOrange,
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SpotLightColors.primaryOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '管理者',
                  style: TextStyle(
                    color: SpotLightColors.primaryOrange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'ID: $userID',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoChip(
                  Icons.star,
                  '$spotlightnum',
                  Colors.amber,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.report,
                  '$reportnum',
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.warning,
                  '$reportednum',
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey[600],
        ),
        onTap: () async {
          // ユーザー詳細画面に遷移
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UserDetailScreen(user: user),
            ),
          );
          
          // 詳細画面から戻ってきた場合、ユーザー一覧を更新
          if (result == true) {
            _fetchUsers();
          }
        },
      ),
    );
  }

  /// 情報チップを構築
  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

