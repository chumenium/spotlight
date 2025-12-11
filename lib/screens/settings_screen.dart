import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import '../providers/theme_provider.dart';
import '../services/sort_order_service.dart';
import 'profile_edit_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SortOrder _currentSortOrder = SortOrder.random;

  @override
  void initState() {
    super.initState();
    _loadSortOrder();
  }

  Future<void> _loadSortOrder() async {
    final sortOrder = await SortOrderService.getSortOrder();
    if (mounted) {
      setState(() {
        _currentSortOrder = sortOrder;
      });
    }
  }

  Future<void> _updateSortOrder(SortOrder? newValue) async {
    if (newValue != null && newValue != _currentSortOrder) {
      final success = await SortOrderService.setSortOrder(newValue);
      if (success && mounted) {
        setState(() {
          _currentSortOrder = newValue;
        });
      }
    }
  }

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
            icon: Icons.lock_outline,
            title: 'パスワード変更',
            onTap: () {
              // TODO: パスワード変更画面への遷移
            },
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
            icon: Icons.sort_outlined,
            title: '投稿の並び順',
            subtitle: SortOrderService.getSortOrderDisplayName(_currentSortOrder),
            trailing: DropdownButton<SortOrder>(
              value: _currentSortOrder,
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
                  value: SortOrder.random,
                  child: const Text('ランダム'),
                ),
                DropdownMenuItem(
                  value: SortOrder.newest,
                  child: const Text('新しい順'),
                ),
                DropdownMenuItem(
                  value: SortOrder.oldest,
                  child: const Text('古い順'),
                ),
              ],
              onChanged: _updateSortOrder,
            ),
          ),
          _buildSettingsTile(
            context: context,
            icon: Icons.language_outlined,
            title: '言語',
            subtitle: '日本語',
            onTap: () {
              // TODO: 言語選択画面への遷移
            },
          ),
          _buildSettingsTile(
            context: context,
            icon: Icons.storage_outlined,
            title: 'キャッシュをクリア',
            subtitle: 'アプリのキャッシュを削除',
            onTap: () {
              // TODO: キャッシュクリアの実装
            },
          ),

          const SizedBox(height: 24),

          // データ設定セクション
          _buildSectionHeader(context, 'データ'),
          _buildSettingsTile(
            context: context,
            icon: Icons.download_outlined,
            title: 'データのエクスポート',
            subtitle: 'アカウントデータをダウンロード',
            onTap: () {
              // TODO: データエクスポートの実装
            },
          ),
          _buildSettingsTile(
            context: context,
            icon: Icons.delete_outline,
            title: 'アカウント削除',
            subtitle: 'アカウントとすべてのデータを削除',
            titleColor: Colors.red,
            iconColor: Colors.red,
            onTap: () {
              // TODO: アカウント削除の実装
            },
          ),

          const SizedBox(height: 24),

          // 開発者向け設定セクション（デバッグモード時のみ表示）
          if (kDebugMode) ...[
            _buildSectionHeader(context, '開発者向け'),
          ],

          const SizedBox(height: 40),
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
    const platform = MethodChannel('com.example.spotlight/settings');
    
    try {
      if (Platform.isAndroid) {
        // Android: アプリの通知設定画面を開く
        await platform.invokeMethod('openNotificationSettings');
      } else if (Platform.isIOS) {
        // iOS: アプリの設定画面を開く
        await platform.invokeMethod('openAppSettings');
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
}

