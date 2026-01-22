import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import '../auth/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/account_deletion_helper.dart';
import '../services/post_service.dart';
import '../services/search_service.dart';
import 'profile_edit_screen.dart';
import 'tutorial_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: theme.appBarTheme.foregroundColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '設定',
          style: TextStyle(
            color: theme.appBarTheme.foregroundColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 通知設定セクション
          _buildSectionHeader(context, '通知'),
          _buildSettingsTile(
            context: context,
            icon: Icons.notifications_outlined,
            title: 'プッシュ通知',
            subtitle: '新着投稿やお知らせを受け取る',
            onTap: () async {
              await _openNotificationSettings(context);
            },
          ),

          const SizedBox(height: 24),

          // アカウント設定セクション
          _buildSectionHeader(context, 'アカウント'),
          _buildSettingsTile(
            context: context,
            icon: Icons.person_outline,
            title: 'プロフィール編集',
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileEditScreen(),
                ),
              );
              // 保存成功時は設定画面からもtrueを返す
              if (result == true && context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
          ),
          _buildSettingsTile(
            context: context,
            icon: Icons.delete_forever_outlined,
            title: '自分の投稿をすべて削除',
            subtitle: '投稿コンテンツをすべて削除します',
            onTap: () => _confirmDeleteAllPosts(context),
          ),
          _buildSettingsTile(
            context: context,
            icon: Icons.manage_search_outlined,
            title: '検索履歴をすべて削除',
            subtitle: '検索履歴をすべて削除します',
            onTap: () => _confirmDeleteAllSearchHistory(context),
          ),

          const SizedBox(height: 24),

          // アプリ設定セクション
          _buildSectionHeader(context, 'アプリ'),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              String getThemeSubtitle() {
                switch (themeProvider.themeMode) {
                  case AppThemeMode.light:
                    return 'ライト';
                  case AppThemeMode.dark:
                    return 'ダーク';
                  case AppThemeMode.system:
                    return '端末の設定';
                }
              }

              return _buildSettingsTile(
                context: context,
                icon: Icons.palette_outlined,
                title: 'アプリテーマ',
                subtitle: getThemeSubtitle(),
                trailing: DropdownButton<AppThemeMode>(
                  value: themeProvider.themeMode,
                  underline: const SizedBox(),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[700],
                  ),
                  dropdownColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1E1E)
                      : Colors.white,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontSize: 14,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: AppThemeMode.light,
                      child: const Text('ライト'),
                    ),
                    DropdownMenuItem(
                      value: AppThemeMode.dark,
                      child: const Text('ダーク'),
                    ),
                    DropdownMenuItem(
                      value: AppThemeMode.system,
                      child: const Text('端末の設定'),
                    ),
                  ],
                  onChanged: (AppThemeMode? newValue) {
                    if (newValue != null) {
                      themeProvider.setThemeMode(newValue);
                    }
                  },
                ),
              );
            },
          ),
          _buildSettingsTile(
            context: context,
            icon: Icons.school_outlined,
            title: 'チュートリアル',
            subtitle: '操作方法と機能を確認する',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TutorialScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // データ設定セクション
          _buildSectionHeader(context, 'データ'),
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final isGuest = authProvider.currentUser?.id == 'guest';
              if (isGuest) {
                return const SizedBox.shrink();
              }
              return _buildSettingsTile(
                context: context,
                icon: Icons.delete_outline,
                title: 'アカウント削除',
                subtitle: 'アカウントとすべてのデータを削除',
                titleColor: Colors.red,
                iconColor: Colors.red,
                onTap: () async {
                  await showDeleteAccountConfirmation(context);
                },
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          color: theme.brightness == Brightness.dark
              ? Colors.grey[400]
              : Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFFFF5E6), // ライトテーマ用の温かみのあるカード背景
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? (isDark ? Colors.grey[400] : Colors.grey[700]),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? (isDark ? Colors.white : Colors.black),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontSize: 13,
                ),
              )
            : null,
        trailing: trailing ??
            (onTap != null
                ? Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                    size: 20,
                  )
                : null),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  /// 端末の通知設定画面を開く
  static Future<void> _openNotificationSettings(BuildContext context) async {
    const platform = MethodChannel('com.spotlight.mobile/settings');

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Android/iOS: アプリの通知設定画面を開く
        await platform.invokeMethod('openNotificationSettings');
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        final errorMessage = e.code == 'MissingPluginException'
            ? 'アプリを完全に再起動してください（ホットリロードでは反映されません）'
            : '設定画面を開けませんでした: ${e.message ?? e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('設定画面を開けませんでした: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAllPosts(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          '全ての投稿を削除',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '投稿コンテンツをすべて削除します。\nこの操作は取り消せません。',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '削除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    _showProcessingDialog(context, '削除中...');

    bool hasFailure = false;
    int deletedCount = 0;
    try {
      final posts = await PostService.getUserContents();
      if (posts.isEmpty) {
        _closeProcessingDialog(context);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('削除対象の投稿がありません'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      for (final post in posts) {
        final success = await PostService.deletePost(post.id.toString());
        if (success) {
          deletedCount++;
        } else {
          hasFailure = true;
        }
      }
    } catch (e) {
      hasFailure = true;
      if (kDebugMode) {
        debugPrint('❌ 投稿全削除エラー: $e');
      }
    } finally {
      _closeProcessingDialog(context);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasFailure
              ? '一部の投稿削除に失敗しました（削除済み: $deletedCount件）'
              : '投稿を削除しました（$deletedCount件）',
        ),
        backgroundColor: hasFailure ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmDeleteAllSearchHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          '検索履歴を全て削除',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '検索履歴をすべて削除します。\nこの操作は取り消せません。',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              '削除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    _showProcessingDialog(context, '削除中...');

    bool hasFailure = false;
    int deletedCount = 0;
    try {
      final histories = await SearchService.fetchSearchHistory();
      if (histories.isEmpty) {
        _closeProcessingDialog(context);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('削除対象の検索履歴がありません'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      for (final history in histories) {
        final success = await SearchService.deleteSearchHistory(history.id);
        if (success) {
          deletedCount++;
        } else {
          hasFailure = true;
        }
      }
    } catch (e) {
      hasFailure = true;
      if (kDebugMode) {
        debugPrint('❌ 検索履歴全削除エラー: $e');
      }
    } finally {
      _closeProcessingDialog(context);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasFailure
              ? '一部の検索履歴削除に失敗しました（削除済み: $deletedCount件）'
              : '検索履歴を削除しました（$deletedCount件）',
        ),
        backgroundColor: hasFailure ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showProcessingDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF6B35),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _closeProcessingDialog(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
