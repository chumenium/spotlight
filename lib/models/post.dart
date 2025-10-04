enum PostType {
  video,
  image,
  text,
  audio,
}

class Post {
  final String id;
  final String userId;
  final String username;
  final String userAvatar;
  final String title;
  final String content;
  final PostType type;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int likes;
  final int comments;
  final int shares;
  final bool isSpotlighted;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.userAvatar,
    required this.title,
    required this.content,
    required this.type,
    this.mediaUrl,
    this.thumbnailUrl,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.isSpotlighted,
    required this.createdAt,
  });

  // サンプルデータ生成用ファクトリ
  factory Post.sample(int index) {
    final types = PostType.values;
    final type = types[index % types.length];
    
    return Post(
      id: 'post_$index',
      userId: 'user_$index',
      username: 'ユーザー${index + 1}',
      userAvatar: 'https://via.placeholder.com/40',
      title: '投稿タイトル ${index + 1}',
      content: 'これは投稿${index + 1}の内容です。',
      type: type,
      mediaUrl: type == PostType.video ? 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4' : null,
      thumbnailUrl: type == PostType.image ? 'https://picsum.photos/400/600?random=$index' : null,
      likes: (index + 1) * 10,
      comments: (index + 1) * 3,
      shares: (index + 1) * 2,
      isSpotlighted: index % 3 == 0,
      createdAt: DateTime.now().subtract(Duration(hours: index)),
    );
  }
}
