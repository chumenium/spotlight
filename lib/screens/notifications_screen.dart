import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification.dart';
import '../utils/spotlight_colors.dart';
import '../providers/navigation_provider.dart';
import 'dart:async';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  List<NotificationItem> notifications = [];
  late TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;
  int _lastRefreshTrigger = -1; // 最後に処理したリフレッシュトリガーの値

  // タブの定義
  final List<String> _tabs = ['すべて', 'スポットライト', 'コメント', 'トレンド', 'システム'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (_isLoading) return; // 既に読み込み中の場合はスキップ

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fetched = await NotificationService.fetchNotifications();

      if (mounted) {
        setState(() {
          notifications = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "通知の取得に失敗しました: $e";
          _isLoading = false;
        });
      }
      debugPrint("通知取得エラー: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NavigationProviderの変更をリッスンして、通知画面が表示されたときに再取得
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, _) {
        final refreshTrigger = navigationProvider.notificationRefreshTrigger;
        final currentIndex = navigationProvider.currentIndex;

        // 通知画面が表示されている場合、かつトリガーが更新された場合に再取得
        if (currentIndex == 3 && refreshTrigger != _lastRefreshTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _lastRefreshTrigger = refreshTrigger;
              });
              _loadNotifications();
            }
          });
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0,
            toolbarHeight: 60,
            leadingWidth: 160,
            leading: SizedBox(
              height: 45,
              width: 160,
              child: RepaintBoundary(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                  cacheWidth: (160 * MediaQuery.of(context).devicePixelRatio).round(),
                  cacheHeight: (45 * MediaQuery.of(context).devicePixelRatio).round(),
                  errorBuilder: (context, error, stackTrace) {
                    // ロゴ画像が見つからない場合は何も表示しない
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.done_all,
                  color: Theme.of(context).appBarTheme.iconTheme?.color ?? 
                         (Theme.of(context).brightness == Brightness.dark 
                             ? Colors.white 
                             : const Color(0xFF1A1A1A)),
                ),
                onPressed: () {
                  setState(() {
                    notifications = notifications
                        .map((n) => NotificationItem(
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
                            ))
                        .toList();
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
              labelColor: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : const Color(0xFF1A1A1A),
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              // 左端の余白を半分に減らす（8px）
              labelPadding: const EdgeInsets.symmetric(horizontal: 13),
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.only(left: 8),
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
      },
    );
  }

  Widget _buildTabContent(String tabName) {
    // ローディング中の場合
    if (_isLoading && notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: SpotLightColors.primaryOrange,
        ),
      );
    }

    // エラーが発生した場合
    if (_errorMessage != null && notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: SpotLightColors.primaryOrange,
              ),
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    List<NotificationItem> filteredNotifications =
        _getFilteredNotifications(tabName);

    if (filteredNotifications.isEmpty) {
      return _buildEmptyState(tabName);
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: SpotLightColors.primaryOrange,
      child: ListView.builder(
        itemCount: filteredNotifications.length,
        itemBuilder: (context, index) {
          final notification = filteredNotifications[index];
          return _buildNotificationItem(notification);
        },
      ),
    );
  }

  List<NotificationItem> _getFilteredNotifications(String tabName) {
    switch (tabName) {
      case 'すべて':
        return notifications;
      case 'スポットライト':
        return notifications
            .where((n) => n.type == NotificationType.spotlight)
            .toList();
      case 'コメント':
        return notifications
            .where((n) =>
                n.type == NotificationType.comment ||
                n.type == NotificationType.reply)
            .toList();
      case 'トレンド':
        return notifications
            .where((n) => n.type == NotificationType.trending)
            .toList();
      case 'システム':
        return notifications
            .where((n) => n.type == NotificationType.system)
            .toList();
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
            ? Theme.of(context).cardColor
            : Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : Colors.white,
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
              backgroundColor: Theme.of(context).cardColor,
            ),
          );
        },
        child: Padding(
          // 左端の余白を半分に減らす（8px）
          padding: const EdgeInsets.only(
            left: 8,
            top: 16,
            right: 16,
            bottom: 16,
          ),
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
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyLarge?.color ?? 
                                     (Theme.of(context).brightness == Brightness.dark 
                                         ? Colors.white 
                                         : const Color(0xFF2C2C2C)),
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
                        color: Theme.of(context).textTheme.bodySmall?.color ?? 
                               (Theme.of(context).brightness == Brightness.dark 
                                   ? Colors.grey[300] 
                                   : Colors.grey[600]),
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
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
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
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
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
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
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
    // 端末のローカル時間から逆算
    final now = DateTime.now().toLocal();
    final localDateTime = dateTime.toLocal();
    final difference = now.difference(localDateTime);

    if (difference.inMinutes < 1) {
      return 'たった今';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      return '${localDateTime.year}/${localDateTime.month}/${localDateTime.day}';
    }
  }
}
