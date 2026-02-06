import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../utils/spotlight_colors.dart';
import '../widgets/blur_app_bar.dart';
import '../widgets/center_popup.dart';

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
      // バックエンドAPIはoffsetパラメータのみを受け取ります
      // statusフィルタリングは画面側で行います（バックエンドがstatusフィールドを返す場合）
      final reports = await AdminService.getReports(
        offset: 0,
      );

      if (reports != null) {
        setState(() {
          _reports = reports;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = '通報情報の取得に失敗しました。APIエンドポイントが実装されていない可能性があります。';
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

  /// 検索フィルタリングされた通報リストを取得
  List<Map<String, dynamic>> get _filteredReports {
    var filtered = _reports;

    // タイプでフィルタリング
    if (_selectedType != 'all') {
      filtered = filtered.where((report) {
        final type = (report['reporttype'] ?? report['type'] ?? '').toString();
        return type == _selectedType;
      }).toList();
    }

    // ステータスでフィルタリング（processflagに基づく）
    if (_selectedStatus != 'all') {
      filtered = filtered.where((report) {
        final processflag = _getProcessFlag(report);
        if (_selectedStatus == 'pending') {
          return processflag != true; // 未処理
        } else if (_selectedStatus == 'resolved') {
          return processflag == true; // 処理済み
        }
        return true;
      }).toList();
    }

    // 検索クエリでフィルタリング
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((report) {
        // バックエンドからreasonとdetailフィールドで送信される
        final reason = (report['reason'] ?? '').toString().toLowerCase();
        final detail = (report['detail'] ?? '').toString().toLowerCase();
        final reporterUsername = (report['username'] ?? '').toString().toLowerCase();
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
    if (reason.isEmpty) {
      return '不明';
    }
    switch (reason.toLowerCase()) {
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

  /// ステータスラベルを取得（processflagに基づく）
  String _getStatusLabel(bool? processflag) {
    if (processflag == true) {
      return '処理済み';
    } else {
      return '未処理';
    }
  }

  /// ステータスカラーを取得（processflagに基づく）
  Color _getStatusColor(bool? processflag) {
    if (processflag == true) {
      return Colors.green;
    } else {
      return Colors.orange;
    }
  }

  /// processflagを取得（様々な形式に対応）
  bool? _getProcessFlag(Map<String, dynamic> report) {
    final processflag = report['processflag'];
    if (processflag == null) return null;
    if (processflag is bool) return processflag;
    if (processflag is String) {
      return processflag.toLowerCase() == 'true';
    }
    return null;
  }

  /// 通報を処理済みにする
  Future<void> _processReport(Map<String, dynamic> report) async {
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

    final success = await AdminService.processReport(
      reportID: reportID,
    );

    if (mounted) {
      if (success) {
        CenterPopup.show(context, '通報を処理済みにしました');
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

  /// 通報を未処理に戻す
  Future<void> _unprocessReport(Map<String, dynamic> report) async {
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
          '通報を未処理に戻しますか？',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'この通報を未処理に戻します。',
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
            child: const Text('未処理に戻す'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await AdminService.unprocessReport(
      reportID: reportID,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('通報を未処理に戻しました'),
            backgroundColor: Colors.orange,
          ),
        );
        _fetchReports();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('通報の未処理化に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 投稿を削除
  Future<void> _deleteContent(Map<String, dynamic> report) async {
    // 通報データからcontentIDを取得（複数のフィールド名を試す）
    final contentID = report['contentID']?.toString() ?? 
                      report['content_id']?.toString() ?? 
                      report['targetID']?.toString() ?? 
                      report['target_id']?.toString() ?? '';
    
    if (contentID.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('投稿IDが取得できませんでした'),
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
          '投稿を削除しますか？',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'この操作は取り消せません。通報された投稿を削除します。',
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
              backgroundColor: Colors.red,
            ),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await AdminService.deleteContent(contentID);

    if (mounted) {
      if (success) {
        CenterPopup.show(context, '投稿を削除しました');
        _fetchReports();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('投稿の削除に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// コメントを削除
  Future<void> _deleteComment(Map<String, dynamic> report) async {
    // 通報データからcontentIDとcommentIDを取得
    // コメント通報の場合、comCTIDがコンテンツID、comCMIDがコメントID
    final contentID = report['comCTID']?.toString() ?? 
                      report['contentID']?.toString() ?? 
                      report['content_id']?.toString() ?? 
                      report['targetID']?.toString() ?? 
                      report['target_id']?.toString() ?? '';
    final commentID = report['comCMID']?.toString() ?? 
                     report['commentID']?.toString() ?? 
                     report['comment_id']?.toString() ?? '';
    
    if (contentID.isEmpty || commentID.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('投稿IDまたはコメントIDが取得できませんでした'),
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
          'コメントを削除しますか？',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'この操作は取り消せません。通報されたコメントを削除します。',
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
              backgroundColor: Colors.red,
            ),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await AdminService.deleteComment(contentID, commentID);

    if (mounted) {
      if (success) {
        CenterPopup.show(context, 'コメントを削除しました');
        _fetchReports();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('コメントの削除に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                  '${_reports.where((r) => _getProcessFlag(r) != true).length}',
                  Icons.pending,
                  Colors.orange,
                ),
                _buildStatCard(
                  '処理済み',
                  '${_reports.where((r) => _getProcessFlag(r) == true).length}',
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
    final type = _getTypeLabel((report['reporttype'] ?? report['type'] ?? '').toString());
    
    // 通報理由を取得（バックエンドからreasonフィールドで送信される）
    final reasonValue = report['reason'];
    final reason = _getReasonLabel(
      reasonValue != null && reasonValue != 'null' 
        ? reasonValue.toString() 
        : ''
    );
    
    // 通報内容詳細を取得（バックエンドからdetailフィールドで送信される、nullの可能性あり）
    final detailValue = report['detail'];
    final detail = detailValue != null && detailValue != 'null' && detailValue.toString().toLowerCase() != 'none'
      ? detailValue.toString()
      : '';
    
    final reporterUsername = (report['username'] ?? '不明').toString();
    final processflag = _getProcessFlag(report);
    final statusColor = _getStatusColor(processflag);
    final isPending = processflag != true;

    return InkWell(
      onTap: () => _showReportDetail(report),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPending
                ? statusColor.withOpacity(0.5)
                : Colors.grey[800]!,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // reportID
            Row(
              children: [
                Icon(
                  Icons.tag,
                  size: 16,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  'ID: $reportID',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 通報の種類
            Row(
              children: [
                Icon(
                  Icons.category,
                  size: 16,
                  color: Colors.blue,
                ),
                const SizedBox(width: 4),
                Text(
                  '種類: $type',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 通報理由（常に表示）
            Row(
              children: [
                Icon(
                  Icons.warning,
                  size: 16,
                  color: Colors.red,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '理由: $reason',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            // 通報内容詳細（ある場合のみ表示）
            if (detail.isNotEmpty && detail != 'null' && detail.toLowerCase() != 'none') ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.description,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '詳細: $detail',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // 通報したユーザー名
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 16,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  '通報者: $reporterUsername',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 通報の詳細を表示
  void _showReportDetail(Map<String, dynamic> report) {
    final reportID = report['reportID']?.toString() ?? '不明';
    final type = _getTypeLabel((report['reporttype'] ?? report['type'] ?? '').toString());
    
    // 通報理由を取得（バックエンドからreasonフィールドで送信される）
    final reasonValue = report['reason'];
    final reason = _getReasonLabel(
      reasonValue != null && reasonValue != 'null' 
        ? reasonValue.toString() 
        : ''
    );
    
    // 通報内容詳細を取得（バックエンドからdetailフィールドで送信される、nullの可能性あり）
    final detailValue = report['detail'];
    final detail = detailValue != null && detailValue != 'null' && detailValue.toString().toLowerCase() != 'none'
      ? detailValue.toString()
      : '';
    
    final processflag = _getProcessFlag(report);
    final statusLabel = _getStatusLabel(processflag);
    final statusColor = _getStatusColor(processflag);
    // 通報日時を取得（バックエンドからreporttimestampフィールドで送信される）
    final timestamp = (report['reporttimestamp'] ?? '').toString();
    final reporterUsername = (report['username'] ?? '不明').toString();
    final targetUsername = (report['targetusername'] ?? '不明').toString();
    final contentID = report['contentID']?.toString() ?? '';
    final comCTID = report['comCTID']?.toString() ?? '';
    final comCMID = report['comCMID']?.toString() ?? '';
    final commenttext = (report['commenttext'] ?? '').toString();
    final title = (report['title'] ?? '').toString();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '通報詳細',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 基本情報
                _buildDetailRow('通報ID', reportID),
                _buildDetailRow('通報の種類', type),
                _buildDetailRow('通報理由', reason),
                _buildDetailRow('通報者', reporterUsername),
                if (targetUsername.isNotEmpty && targetUsername != '不明')
                  _buildDetailRow('対象ユーザー', targetUsername),
                _buildDetailRow('処理状態', statusLabel, statusColor),
                if (timestamp.isNotEmpty)
                  _buildDetailRow('通報日時', timestamp),
                // 通報内容
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '通報内容',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
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
                // コンテンツ情報
                if (contentID.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDetailRow('コンテンツID', contentID),
                  if (title.isNotEmpty)
                    _buildDetailRow('タイトル', title),
                ],
                // コメント情報
                if (comCTID.isNotEmpty || comCMID.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  if (comCTID.isNotEmpty)
                    _buildDetailRow('コメントのコンテンツID', comCTID),
                  if (comCMID.isNotEmpty)
                    _buildDetailRow('コメントID', comCMID),
                  if (commenttext.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'コメント内容',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        commenttext,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                // アクションボタン
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 投稿削除ボタン（通報タイプがcontentの場合）
                    if ((report['reporttype'] ?? report['type'] ?? '').toString() == 'content')
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _deleteContent(report);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('投稿を削除'),
                        ),
                      ),
                    // コメント削除ボタン（通報タイプがcommentの場合）
                    if ((report['reporttype'] ?? report['type'] ?? '').toString() == 'comment')
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _deleteComment(report);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('コメントを削除'),
                        ),
                      ),
                    // 処理状態変更ボタン
                    if (processflag != true)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _processReport(report);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SpotLightColors.primaryOrange,
                        ),
                        child: const Text('処理済みにする'),
                      )
                    else
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _unprocessReport(report);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('未処理に戻す'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 詳細表示用の行を構築
  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

