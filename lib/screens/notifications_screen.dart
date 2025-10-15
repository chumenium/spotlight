import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../utils/spotlight_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<NotificationItem> notifications;

  @override
  void initState() {
    super.initState();
    notifications = NotificationItem.getSampleNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '通知',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: SpotLightColors.primaryOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.white),
            onPressed: () {
              setState(() {
                notifications = notifications.map((n) => NotificationItem(
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  message: n.message,
                  username: n.username,
                  userAvatar: n.userAvatar,
                  postId: n.postId,
                  postTitle: n.postTitle,
                  thumbnailUrl: n.thumbnailUrl,
                  createdAt: n.createdAt,
                  isRead: true,
                )).toList();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('すべて既読にしました'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'すべて既読にする',
          ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '通知はありません',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationItem(notification);
              },
            ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    return Container(
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : SpotLightColors.primaryOrange.withOpacity(0.05),
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFFEEEEEE),
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildLeadingWidget(notification),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: SpotLightColors.primaryOrange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (notification.postTitle != null) ...[
              const SizedBox(height: 4),
              Text(
                '投稿: ${notification.postTitle}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _formatTime(notification.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: notification.thumbnailUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  notification.thumbnailUrl!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, color: Colors.grey),
                    );
                  },
                ),
              )
            : null,
        onTap: () {
          setState(() {
            final index = notifications.indexOf(notification);
            notifications[index] = NotificationItem(
              id: notification.id,
              type: notification.type,
              title: notification.title,
              message: notification.message,
              username: notification.username,
              userAvatar: notification.userAvatar,
              postId: notification.postId,
              postTitle: notification.postTitle,
              thumbnailUrl: notification.thumbnailUrl,
              createdAt: notification.createdAt,
              isRead: true,
            );
          });
          // ここで詳細画面へ遷移する処理を追加できます
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${notification.title}をタップしました'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeadingWidget(NotificationItem notification) {
    switch (notification.type) {
      case NotificationType.spotlight:
        return Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: notification.userAvatar != null
                  ? NetworkImage(notification.userAvatar!)
                  : null,
              backgroundColor: Colors.grey[300],
              child: notification.userAvatar == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: SpotLightColors.primaryOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );

      case NotificationType.comment:
        return Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: notification.userAvatar != null
                  ? NetworkImage(notification.userAvatar!)
                  : null,
              backgroundColor: Colors.grey[300],
              child: notification.userAvatar == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.comment,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );

      case NotificationType.reply:
        return Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: notification.userAvatar != null
                  ? NetworkImage(notification.userAvatar!)
                  : null,
              backgroundColor: Colors.grey[300],
              child: notification.userAvatar == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.reply,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );

      case NotificationType.trending:
        return CircleAvatar(
          radius: 24,
          backgroundColor: SpotLightColors.warmRed,
          child: const Icon(
            Icons.trending_up,
            color: Colors.white,
          ),
        );

      case NotificationType.system:
        return CircleAvatar(
          radius: 24,
          backgroundColor: Colors.purple,
          child: const Icon(
            Icons.info_outline,
            color: Colors.white,
          ),
        );
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'たった今';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
    }
  }
}
