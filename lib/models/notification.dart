enum NotificationType {
  spotlight, // 自分の投稿へのスポットライト
  comment, // 自分の投稿へのコメント
  reply, // 自分のコメントへの返信
  trending, // トレンド
  system, // その他アプリからの通知
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String? username;
  final String? userAvatar;
  final String? postId;
  final String? postTitle;
  final String? thumbnailUrl;
  final DateTime createdAt;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.username,
    this.userAvatar,
    this.postId,
    this.postTitle,
    this.thumbnailUrl,
    required this.createdAt,
    this.isRead = false,
  });

  // サンプルデータ生成用ファクトリ
  static List<NotificationItem> getSampleNotifications() {
    return [
      // スポットライト通知
      NotificationItem(
        id: 'notif_1',
        type: NotificationType.spotlight,
        title: 'スポットライトされました',
        message: '田中太郎さんがあなたの投稿をスポットライトしました',
        username: '田中太郎',
        userAvatar: null, // プレースホルダー画像は使用しない
        postId: 'post_1',
        postTitle: '今日の夕焼けがきれい',
        thumbnailUrl: 'https://picsum.photos/80/80?random=1',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false,
      ),
      NotificationItem(
        id: 'notif_2',
        type: NotificationType.spotlight,
        title: 'スポットライトされました',
        message: '佐藤花子さんがあなたの投稿をスポットライトしました',
        username: '佐藤花子',
        userAvatar: null, // プレースホルダー画像は使用しない
        postId: 'post_2',
        postTitle: '新しいレシピに挑戦してみた',
        thumbnailUrl: 'https://picsum.photos/80/80?random=2',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),

      // コメント通知
      NotificationItem(
        id: 'notif_3',
        type: NotificationType.comment,
        title: '新しいコメント',
        message: '山田一郎さん: 素晴らしい投稿ですね!',
        username: '山田一郎',
        userAvatar: null, // プレースホルダー画像は使用しない
        postId: 'post_3',
        postTitle: '週末の旅行記',
        thumbnailUrl: 'https://picsum.photos/80/80?random=3',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        isRead: false,
      ),
      NotificationItem(
        id: 'notif_4',
        type: NotificationType.comment,
        title: '新しいコメント',
        message: '鈴木次郎さん: とても参考になります!',
        username: '鈴木次郎',
        userAvatar: null, // プレースホルダー画像は使用しない
        postId: 'post_4',
        postTitle: 'プログラミング学習のコツ',
        thumbnailUrl: 'https://picsum.photos/80/80?random=4',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        isRead: true,
      ),

      // 返信通知
      NotificationItem(
        id: 'notif_5',
        type: NotificationType.reply,
        title: 'コメントへの返信',
        message: '高橋三郎さん: そうなんですよ!詳しく説明しますね',
        username: '高橋三郎',
        userAvatar: null, // プレースホルダー画像は使用しない
        postId: 'post_5',
        postTitle: 'おすすめのカフェについて',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        isRead: true,
      ),
      NotificationItem(
        id: 'notif_6',
        type: NotificationType.reply,
        title: 'コメントへの返信',
        message: '伊藤四郎さん: ありがとうございます!参考にします',
        username: '伊藤四郎',
        userAvatar: null, // プレースホルダー画像は使用しない
        postId: 'post_6',
        postTitle: '最新ガジェットレビュー',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        isRead: true,
      ),

      // トレンド通知
      NotificationItem(
        id: 'notif_7',
        type: NotificationType.trending,
        title: 'トレンド入り',
        message: 'あなたの投稿「桜の季節がやってきた」がトレンド入りしました🔥',
        postId: 'post_7',
        postTitle: '桜の季節がやってきた',
        thumbnailUrl: 'https://picsum.photos/80/80?random=7',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        isRead: false,
      ),
      NotificationItem(
        id: 'notif_8',
        type: NotificationType.trending,
        title: '人気急上昇中',
        message: 'あなたの投稿「おすすめの映画ベスト10」が急上昇中です📈',
        postId: 'post_8',
        postTitle: 'おすすめの映画ベスト10',
        thumbnailUrl: 'https://picsum.photos/80/80?random=8',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),

      // システム通知
      NotificationItem(
        id: 'notif_9',
        type: NotificationType.system,
        title: '新機能のお知らせ',
        message: 'Spotlightに新しいフィルター機能が追加されました✨',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        isRead: true,
      ),
      NotificationItem(
        id: 'notif_10',
        type: NotificationType.system,
        title: 'メンテナンスのお知らせ',
        message: '明日の深夜2:00-4:00にメンテナンスを実施します',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        isRead: true,
      ),
      NotificationItem(
        id: 'notif_11',
        type: NotificationType.system,
        title: 'おめでとうございます🎉',
        message: 'フォロワーが100人を突破しました!',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        isRead: true,
      ),
    ];
  }
}

