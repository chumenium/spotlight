import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../utils/spotlight_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> 
    with SingleTickerProviderStateMixin {
  late List<NotificationItem> notifications;
  late TabController _tabController;
  
  // タブの定義
  final List<String> _tabs = ['すべて', 'スポットライト', 'コメント', 'トレンド', 'システム'];

  @override
  void initState() {
    super.initState();
    notifications = NotificationItem.getSampleNotifications();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          '通知',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: SpotLightColors.primaryOrange,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) {
          return _buildTabContent(tab);
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(String tabName) {
    List<NotificationItem> filteredNotifications = _getFilteredNotifications(tabName);
    
    if (filteredNotifications.isEmpty) {
      return _buildEmptyState(tabName);
    }
    
    return ListView.builder(
      itemCount: filteredNotifications.length,
      itemBuilder: (context, index) {
        final notification = filteredNotifications[index];
        return _buildNotificationItem(notification);
      },
    );
  }

  List<NotificationItem> _getFilteredNotifications(String tabName) {
    switch (tabName) {
      case 'すべて':
        return notifications;
      case 'スポットライト':
        return notifications.where((n) => n.type == NotificationType.spotlight).toList();
      case 'コメント':
        return notifications.where((n) => 
          n.type == NotificationType.comment || n.type == NotificationType.reply).toList();
      case 'トレンド':
        return notifications.where((n) => n.type == NotificationType.trending).toList();
      case 'システム':
        return notifications.where((n) => n.type == NotificationType.system).toList();
      default:
        return notifications;
    }
  }

  Widget _buildEmptyState(String tabName) {
    String message;
    IconData icon;
    
    switch (tabName) {
      case 'すべて':
        message = '通知はありません';
        icon = Icons.notifications_none;
        break;
      case 'スポットライト':
        message = 'スポットライト通知はありません';
        icon = Icons.auto_awesome;
        break;
      case 'コメント':
        message = 'コメント通知はありません';
        icon = Icons.comment;
        break;
      case 'トレンド':
        message = 'トレンド通知はありません';
        icon = Icons.trending_up;
        break;
      case 'システム':
        message = 'システム通知はありません';
        icon = Icons.info_outline;
        break;
      default:
        message = '通知はありません';
        icon = Icons.notifications_none;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    return Container(
      decoration: BoxDecoration(
        color: notification.isRead 
            ? const Color(0xFF1E1E1E)
            : const Color(0xFF2A2A2A),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[800]!,
            width: 0.5,
          ),
        ),
      ),
      child: InkWell(
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${notification.title}をタップしました'),
              duration: const Duration(seconds: 1),
              backgroundColor: const Color(0xFF2A2A2A),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左側のアイコン
              _buildLeadingWidget(notification),
              const SizedBox(width: 12),
              
              // 中央のコンテンツ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // タイトル
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
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
                    const SizedBox(height: 4),
                    
                    // メッセージ
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[300],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // 投稿タイトル（ある場合）
                    if (notification.postTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.postTitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    // 時刻
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(notification.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 右側のサムネイル（ある場合）
              if (notification.thumbnailUrl != null) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    notification.thumbnailUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[800],
                        child: const Icon(Icons.image, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingWidget(NotificationItem notification) {
    switch (notification.type) {
      case NotificationType.spotlight:
        return Stack(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: notification.userAvatar != null
                  ? NetworkImage(notification.userAvatar!)
                  : null,
              backgroundColor: Colors.grey[700],
              child: notification.userAvatar == null
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: SpotLightColors.primaryOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E1E1E), width: 2),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 10,
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
              radius: 20,
              backgroundImage: notification.userAvatar != null
                  ? NetworkImage(notification.userAvatar!)
                  : null,
              backgroundColor: Colors.grey[700],
              child: notification.userAvatar == null
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E1E1E), width: 2),
                ),
                child: const Icon(
                  Icons.comment,
                  size: 10,
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
              radius: 20,
              backgroundImage: notification.userAvatar != null
                  ? NetworkImage(notification.userAvatar!)
                  : null,
              backgroundColor: Colors.grey[700],
              child: notification.userAvatar == null
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E1E1E), width: 2),
                ),
                child: const Icon(
                  Icons.reply,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );

      case NotificationType.trending:
        return CircleAvatar(
          radius: 20,
          backgroundColor: SpotLightColors.warmRed,
          child: const Icon(
            Icons.trending_up,
            color: Colors.white,
            size: 20,
          ),
        );

      case NotificationType.system:
        return CircleAvatar(
          radius: 20,
          backgroundColor: Colors.purple,
          child: const Icon(
            Icons.info_outline,
            color: Colors.white,
            size: 20,
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
