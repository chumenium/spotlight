import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../auth/social_login_screen.dart';
import '../providers/navigation_provider.dart';
import '../services/user_service.dart';

/// プロフィールと設定画面で共有するアカウント削除処理
Future<void> showDeleteAccountConfirmation(BuildContext context) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final isGuest = authProvider.currentUser?.id == 'guest';
  if (isGuest) {
    return; // ゲストには提供しない
  }

  final firstConfirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Text(
        'アカウント削除',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'アカウントを削除すると、以下の情報がすべて削除されます：',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildDeleteInfoItem(context, 'ユーザー名'),
          _buildDeleteInfoItem(context, 'アイコン'),
          _buildDeleteInfoItem(context, 'すべての投稿コンテンツ'),
          const SizedBox(height: 12),
          Text(
            'この操作は取り消せません。',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
            '続ける',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  if (firstConfirmed != true || !context.mounted) {
    return;
  }

  final secondConfirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Text(
        '最終確認',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本当にアカウントを削除しますか？',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'この操作は取り消せません。\nすべてのデータが完全に削除されます。',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
            '削除する',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  if (secondConfirmed != true || !context.mounted) {
    return;
  }

  await _deleteAccount(context, authProvider);
}

Widget _buildDeleteInfoItem(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(left: 8, top: 4),
    child: Row(
      children: [
        Icon(
          Icons.remove,
          size: 16,
          color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
          ),
        ),
      ],
    ),
  );
}

Future<void> _deleteAccount(
    BuildContext context, AuthProvider authProvider) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'アカウントを削除しています...',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    ),
  );

  try {
    final success = await UserService.deleteAccount();

    if (!context.mounted) return;

    Navigator.of(context).pop();

    if (success) {
      await authProvider.logout();

      if (!context.mounted) return;

      final navigationProvider =
          Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.reset();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('アカウントが削除されました'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const SocialLoginScreen(),
        ),
        (route) => false,
      );
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('アカウントの削除に失敗しました。もう一度お試しください。'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  } catch (e) {
    if (!context.mounted) return;

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('エラーが発生しました: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
