import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:cached_network_image/cached_network_image.dart';
import '../services/admin_service.dart';
import '../config/app_config.dart';
import '../utils/spotlight_colors.dart';

/// ユーザー詳細画面（管理者用）
class UserDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserDetailScreen({
    super.key,
    required this.user,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool _isLoading = false;
  bool _isAdmin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.user['admin'] == true;
  }

  /// 管理者権限を有効化
  Future<void> _enableAdmin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await AdminService.enableAdmin(widget.user['userID']);
      
      if (success) {
        setState(() {
          _isAdmin = true;
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.user['username']}を管理者に変更しました'),
              backgroundColor: SpotLightColors.primaryOrange,
            ),
          );
          Navigator.of(context).pop(true); // 更新フラグを返す
        }
      } else {
        setState(() {
          _errorMessage = '管理者権限の有効化に失敗しました';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者権限有効化エラー: $e');
      }
      setState(() {
        _errorMessage = 'エラーが発生しました: $e';
        _isLoading = false;
      });
    }
  }

  /// 管理者権限を無効化
  Future<void> _disableAdmin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await AdminService.disableAdmin(widget.user['userID']);
      
      if (success) {
        setState(() {
          _isAdmin = false;
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.user['username']}を一般ユーザーに変更しました'),
              backgroundColor: SpotLightColors.primaryOrange,
            ),
          );
          Navigator.of(context).pop(true); // 更新フラグを返す
        }
      } else {
        setState(() {
          _errorMessage = '管理者権限の無効化に失敗しました';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者権限無効化エラー: $e');
      }
      setState(() {
        _errorMessage = 'エラーが発生しました: $e';
        _isLoading = false;
      });
    }
  }

  /// アイコンURLを生成
  String _getIconUrl() {
    final iconPath = widget.user['iconimgpath']?.toString() ?? '';
    
    if (iconPath.isEmpty) {
      return '${AppConfig.backendUrl}/icon/default_icon.jpg';
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
    final username = widget.user['username']?.toString() ?? '不明';
    final userID = widget.user['userID']?.toString() ?? '';
    final spotlightnum = widget.user['spotlightnum'] ?? 0;
    final reportnum = widget.user['reportnum'] ?? 0;
    final reportednum = widget.user['reportednum'] ?? 0;
    final iconUrl = _getIconUrl();

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'ユーザー詳細',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: SpotLightColors.primaryOrange,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // エラーメッセージ
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red[900]?.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[700]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[400]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red[300]),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // プロフィールヘッダー
                  _buildProfileHeader(username, iconUrl),

                  const SizedBox(height: 24),

                  // 基本情報
                  _buildSectionTitle('基本情報'),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'ユーザーID',
                    userID,
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    'ユーザー名',
                    username,
                    Icons.badge_outlined,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoCard(
                    '管理者権限',
                    _isAdmin ? '管理者' : '一般ユーザー',
                    _isAdmin ? Icons.admin_panel_settings : Icons.person,
                    valueColor: _isAdmin ? SpotLightColors.primaryOrange : Colors.grey,
                  ),

                  const SizedBox(height: 24),

                  // 統計情報
                  _buildSectionTitle('統計情報'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'スポットライト',
                          '$spotlightnum',
                          Icons.star,
                          Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          '通報した数',
                          '$reportnum',
                          Icons.report,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    '通報された数',
                    '$reportednum',
                    Icons.warning,
                    Colors.red,
                    fullWidth: true,
                  ),

                  const SizedBox(height: 24),

                  // 管理者操作
                  if (!_isAdmin)
                    _buildActionButton(
                      '管理者権限を付与',
                      Icons.admin_panel_settings,
                      SpotLightColors.primaryOrange,
                      _enableAdmin,
                    )
                  else
                    _buildActionButton(
                      '管理者権限を解除',
                      Icons.person_remove,
                      Colors.red,
                      _disableAdmin,
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  /// プロフィールヘッダーを構築
  Widget _buildProfileHeader(String username, String iconUrl) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAdmin
              ? SpotLightColors.primaryOrange.withOpacity(0.5)
              : Colors.grey[800]!,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // アイコン
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SpotLightColors.primaryOrange,
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: iconUrl,
                fit: BoxFit.cover,
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
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // ユーザー名と管理者バッジ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: SpotLightColors.primaryOrange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '管理者',
                          style: TextStyle(
                            color: SpotLightColors.primaryOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: ${widget.user['userID']}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// セクションタイトルを構築
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// 情報カードを構築
  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: SpotLightColors.primaryOrange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 統計カードを構築
  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// アクションボタンを構築
  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

