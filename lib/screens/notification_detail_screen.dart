import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification.dart';
import '../utils/spotlight_colors.dart';
import '../widgets/blur_app_bar.dart';
import '../providers/navigation_provider.dart';

class NotificationDetailScreen extends StatelessWidget {
  final NotificationItem notification;

  const NotificationDetailScreen({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor =
        theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black);
    final secondaryTextColor =
        theme.textTheme.bodySmall?.color ?? (isDark ? Colors.grey[300] : Colors.grey[600]);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: BlurAppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: const Text('通知詳細'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                notification.message,
                style: TextStyle(
                  fontSize: 16,
                  color: primaryTextColor,
                  height: 1.5,
                ),
              ),
              if (notification.postTitle != null) ...[
                const SizedBox(height: 16),
                Text(
                  notification.postTitle!,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _formatTime(notification.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
              ),
              if (notification.thumbnailUrl != null) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    if (notification.postId == null) return;
                    final navigationProvider =
                        Provider.of<NavigationProvider>(context, listen: false);
                    navigationProvider.navigateToHome(
                      postId: notification.postId,
                      postTitle: notification.postTitle,
                      commentId: notification.commentID,
                      shouldOpenComments:
                          notification.type == NotificationType.comment ||
                              notification.type == NotificationType.reply,
                    );
                    Navigator.of(context).pop();
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: double.infinity,
                      child: Image.network(
                        notification.thumbnailUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 180,
                            color: Colors.grey[800],
                            child: const Icon(Icons.image, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    dateTime = dateTime.toLocal();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}日前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分前';
    } else {
      return 'たった今';
    }
  }
}
