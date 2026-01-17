import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../services/user_service.dart';
import '../utils/spotlight_colors.dart';

/// ブロックしたユーザー一覧画面
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  final Set<String> _unblockingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    if (!_isRefreshing) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final users = await UserService.getBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blockedUsers = users ?? [];
        _errorMessage = users == null ? '取得に失敗しました' : null;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ブロック一覧取得エラー: $e');
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = 'エラーが発生しました';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _unblock(String userId) async {
    setState(() {
      _unblockingIds.add(userId);
    });

    final success = await UserService.unblockUser(userId);
    if (!mounted) return;

    setState(() {
      _unblockingIds.remove(userId);
      if (success) {
        _blockedUsers.removeWhere(
            (item) => item['userID']?.toString() == userId.toString());
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'ブロックを解除しました' : 'ブロック解除に失敗しました'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ブロックしたユーザー'),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: _isLoading
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
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchBlockedUsers,
                        child: const Text('再読み込み'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: SpotLightColors.primaryOrange,
                  onRefresh: () async {
                    setState(() {
                      _isRefreshing = true;
                    });
                    await _fetchBlockedUsers();
                  },
                  child: _blockedUsers.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                'ブロックしているユーザーはいません',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _blockedUsers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = _blockedUsers[index];
                            final userId = user['userID']?.toString() ?? '';
                            final username = user['username']?.toString() ?? '';
                            final isProcessing = _unblockingIds.contains(userId);

                            return ListTile(
                              title: Text(
                                username.isNotEmpty ? username : 'ユーザー名不明',
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: TextButton(
                                onPressed: isProcessing
                                    ? null
                                    : () => _unblock(userId),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                child: isProcessing
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('ブロック解除'),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
