import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:cached_network_image/cached_network_image.dart';
import '../services/admin_service.dart';
import '../config/app_config.dart';
import '../utils/spotlight_colors.dart';

/// 通報管理画面
class ReportManagementScreen extends StatefulWidget {
  const ReportManagementScreen({super.key});

  @override
  State<ReportManagementScreen> createState() => _ReportManagementScreenState();
}

class _ReportManagementScreenState extends State<ReportManagementScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedStatus = 'all'; // all, pending, resolved
  String _selectedType = 'all'; // all, user, content, comment

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  /// 通報一覧を取得
  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reports = await AdminService.getReports(
        status: _selectedStatus,
      );

      if (reports != null) {
        setState(() {
          _reports = reports;
          _isLoading = false;
          // 空のリストが返された場合、API未実装の可能性を考慮
          // ただし、通常の空の状態と区別するため、404エラーの場合は特別な処理が必要
          // 現時点では、nullが返された場合のみエラーとする
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = '通報情報の取得に失敗しました。APIエンドポイントが実装されていない可能性があります。';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 通報取得エラー: $e');
      }
      setState(() {
        _errorMessage = 'エラーが発生しました: $e';
        _isLoading = false;
      });
    }
  }

  /// 検索フィルタリングされた通報リストを取得
  List<Map<String, dynamic>> get _filteredReports {
    var filtered = _reports;

    // タイプでフィルタリング
    if (_selectedType != 'all') {
      filtered = filtered.where((report) {
        final type = (report['type'] ?? '').toString();
        return type == _selectedType;
      }).toList();
    }

    // 検索クエリでフィルタリング
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((report) {
        final reason = (report['reason'] ?? '').toString().toLowerCase();
        final detail = (report['detail'] ?? '').toString().toLowerCase();
        final reporterUsername = (report['reporter_username'] ?? '').toString().toLowerCase();
        final reportID = (report['reportID'] ?? '').toString().toLowerCase();
        return reason.contains(query) ||
            detail.contains(query) ||
            reporterUsername.contains(query) ||
            reportID.contains(query);
      }).toList();
    }

    // 日時でソート（新しい順）
    filtered.sort((a, b) {
      final aTime = (a['reporttimestamp'] ?? '').toString();
      final bTime = (b['reporttimestamp'] ?? '').toString();
      return bTime.compareTo(aTime);
    });

    return filtered;
  }

  /// アイコンURLを生成
  String _getIconUrl(Map<String, dynamic> report) {
    final iconPath = report['reporter_iconimgpath']?.toString() ?? '';
    
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

  /// 通報タイプの表示名を取得
  String _getTypeLabel(String type) {
    switch (type) {
      case 'user':
        return 'ユーザー';
      case 'content':
        return '投稿';
      case 'comment':
        return 'コメント';
      default:
        return '不明';
    }
  }

  /// 通報理由の表示名を取得
  String _getReasonLabel(String reason) {
    switch (reason) {
      case 'spam':
        return 'スパム';
      case 'harassment':
        return 'ハラスメント';
      case 'inappropriate':
        return '不適切な内容';
      case 'violence':
        return '暴力的な内容';
      case 'copyright':
        return '著作権侵害';
      case 'other':
        return 'その他';
      default:
        return reason;
    }
  }

  /// ステータスラベルを取得
  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return '未処理';
      case 'resolved':
        return '処理済み';
      case 'rejected':
        return '却下';
      default:
        return '不明';
    }
  }

  /// ステータスカラーを取得
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  /// 通報を処理済みにする
  Future<void> _resolveReport(Map<String, dynamic> report) async {
    final reportID = report['reportID']?.toString() ?? '';
    if (reportID.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('通報IDが取得できませんでした'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          '通報を処理済みにしますか？',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'この通報を処理済みとしてマークします。',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SpotLightColors.primaryOrange,
            ),
            child: const Text('処理済みにする'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await AdminService.resolveReport(
      reportID: reportID,
      action: 'resolve',
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('通報を処理済みにしました'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchReports();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('通報の処理に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '通報管理',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchReports,
            tooltip: '更新',
          ),
        ],
      ),
      body: Column(
        children: [
          // フィルタと検索バー
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: Column(
              children: [
                // ステータスフィルタ
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterChip(
                        'すべて',
                        'all',
                        _selectedStatus,
                        (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                          _fetchReports();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterChip(
                        '未処理',
                        'pending',
                        _selectedStatus,
                        (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                          _fetchReports();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterChip(
                        '処理済み',
                        'resolved',
                        _selectedStatus,
                        (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                          _fetchReports();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // タイプフィルタ
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterChip(
                        'すべて',
                        'all',
                        _selectedType,
                        (value) {
                          setState(() {
                            _selectedType = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterChip(
                        'ユーザー',
                        'user',
                        _selectedType,
                        (value) {
                          setState(() {
                            _selectedType = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterChip(
                        '投稿',
                        'content',
                        _selectedType,
                        (value) {
                          setState(() {
                            _selectedType = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterChip(
                        'コメント',
                        'comment',
                        _selectedType,
                        (value) {
                          setState(() {
                            _selectedType = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 検索バー
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '通報理由、詳細、通報者で検索',
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
              ],
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
                  '総通報数',
                  '${_reports.length}',
                  Icons.report_problem,
                ),
                _buildStatCard(
                  '未処理',
                  '${_reports.where((r) => (r['status'] ?? '').toString() == 'pending').length}',
                  Icons.pending,
                  Colors.orange,
                ),
                _buildStatCard(
                  '処理済み',
                  '${_reports.where((r) => (r['status'] ?? '').toString() == 'resolved').length}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ],
            ),
          ),

          // 通報リスト
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
                              onPressed: _fetchReports,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SpotLightColors.primaryOrange,
                              ),
                              child: const Text('再試行'),
                            ),
                          ],
                        ),
                      )
                    : _errorMessage != null && _errorMessage!.contains('API')
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.api_outlined,
                                  color: Colors.orange[400],
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
                                const SizedBox(height: 8),
                                Text(
                                  'バックエンドAPIの実装をお待ちください',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : _filteredReports.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      color: Colors.grey[600],
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isEmpty
                                          ? '通報がありません'
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
                            onRefresh: _fetchReports,
                            color: SpotLightColors.primaryOrange,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredReports.length,
                              itemBuilder: (context, index) {
                                final report = _filteredReports[index];
                                return _buildReportCard(report);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// フィルターチップを構築
  Widget _buildFilterChip(
    String label,
    String value,
    String selectedValue,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = value == selectedValue;
    return InkWell(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? SpotLightColors.primaryOrange.withOpacity(0.2)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? SpotLightColors.primaryOrange
                : Colors.grey[800]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? SpotLightColors.primaryOrange
                : Colors.grey[400],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// 統計カードを構築
  Widget _buildStatCard(
    String label,
    String value,
    IconData icon, [
    Color? iconColor,
  ]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: iconColor ?? SpotLightColors.primaryOrange,
            size: 24,
          ),
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

  /// 通報カードを構築
  Widget _buildReportCard(Map<String, dynamic> report) {
    final reportID = report['reportID']?.toString() ?? '不明';
    final type = _getTypeLabel((report['type'] ?? '').toString());
    final reason = _getReasonLabel((report['reason'] ?? '').toString());
    final detail = (report['detail'] ?? '').toString();
    final status = (report['status'] ?? 'pending').toString();
    final timestamp = (report['reporttimestamp'] ?? '').toString();
    final reporterUsername = (report['reporter_username'] ?? '不明').toString();
    final iconUrl = _getIconUrl(report);
    final isPending = status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending
              ? Colors.orange.withOpacity(0.5)
              : Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー部分
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: SpotLightColors.primaryOrange,
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: iconUrl,
                  fit: BoxFit.cover,
                  width: 48,
                  height: 48,
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
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    reporterUsername,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
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
                  'ID: $reportID',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                if (timestamp.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timestamp,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 通報内容部分
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.category,
                      type,
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.warning,
                      reason,
                      Colors.red,
                    ),
                  ],
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      detail,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),

          // アクションボタン
          if (isPending)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => _resolveReport(report),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpotLightColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      '処理済みにする',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 情報チップを構築
  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

