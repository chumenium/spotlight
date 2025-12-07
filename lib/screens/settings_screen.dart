import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import '../utils/spotlight_colors.dart';
import 'profile_edit_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          '設定',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 通知設定セクション
          _buildSectionHeader('通知'),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: 'プッシュ通知',
            subtitle: '新着投稿やお知らせを受け取る',
            onTap: () async {
              await _openNotificationSettings(context);
            },
          ),
          

          const SizedBox(height: 24),

          // アカウント設定セクション
          _buildSectionHeader('アカウント'),
          _buildSettingsTile(
            icon: Icons.person_outline,
            title: 'プロフィール編集',
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileEditScreen(),
                ),
              );
              // 保存成功時は何か処理が必要な場合に使用
              if (result == true) {
                // プロフィール情報を再取得する場合はここで処理
              }
            },
          ),
          _buildSettingsTile(
            icon: Icons.lock_outline,
            title: 'パスワード変更',
            onTap: () {
              // TODO: パスワード変更画面への遷移
            },
          ),

          const SizedBox(height: 24),

          // アプリ設定セクション
          _buildSectionHeader('アプリ'),
          _buildSettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'ダークモード',
            subtitle: '常にダークモードで表示',
            trailing: Switch(
              value: true,
              onChanged: (value) {
                // TODO: ダークモード設定の実装
              },
              activeColor: SpotLightColors.primaryOrange,
            ),
          ),
          _buildSettingsTile(
            icon: Icons.language_outlined,
            title: '言語',
            subtitle: '日本語',
            onTap: () {
              // TODO: 言語選択画面への遷移
            },
          ),
          _buildSettingsTile(
            icon: Icons.storage_outlined,
            title: 'キャッシュをクリア',
            subtitle: 'アプリのキャッシュを削除',
            onTap: () {
              // TODO: キャッシュクリアの実装
            },
          ),

          const SizedBox(height: 24),

          // データ設定セクション
          _buildSectionHeader('データ'),
          _buildSettingsTile(
            icon: Icons.download_outlined,
            title: 'データのエクスポート',
            subtitle: 'アカウントデータをダウンロード',
            onTap: () {
              // TODO: データエクスポートの実装
            },
          ),
          _buildSettingsTile(
            icon: Icons.delete_outline,
            title: 'アカウント削除',
            subtitle: 'アカウントとすべてのデータを削除',
            titleColor: Colors.red,
            iconColor: Colors.red,
            onTap: () {
              // TODO: アカウント削除の実装
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? Colors.grey[400],
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                ),
              )
            : null,
        trailing: trailing ??
            (onTap != null
                ? Icon(
                    Icons.chevron_right,
                    color: Colors.grey[600],
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

