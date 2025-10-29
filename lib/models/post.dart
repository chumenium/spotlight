/// 投稿タイプ
enum PostType {
  video,
  image,
  text,
  audio,
}

/// 投稿モデル
class Post {
  final String id;
  final String userId;
  final String username;
  final String userIconPath;
  final String title;
  final String? content;
  final String contentPath; // メディアコンテンツのパス
  final String type; // video, image, text, audio
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int likes; // spotlightnum
  final int playNum;
  final String? link;
  final int comments;
  final int shares;
  final bool isSpotlighted; // spotlightflag
  final bool isText; // textflag
  final String? nextContentId;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.userIconPath,
    required this.title,
    this.content,
    required this.contentPath,
    required this.type,
    this.mediaUrl,
    this.thumbnailUrl,
    required this.likes,
    this.playNum = 0,
    this.link,
    this.comments = 0,
    this.shares = 0,
    required this.isSpotlighted,
    this.isText = false,
    this.nextContentId,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final spotlightnum = json['spotlightnum'] as int? ?? 0;
    final playnum = json['playnum'] as int? ?? 0;
    final spotlightflag = json['spotlightflag'] as bool? ?? false;
    final textflag = json['textflag'] as int? ?? 0;
    
    return Post(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      userIconPath: json['iconimgpath'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      contentPath: json['contentpath'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      likes: spotlightnum,
      playNum: playnum,
      link: json['link'] as String?,
      comments: json['comments'] as int? ?? 0,
      shares: json['shares'] as int? ?? 0,
      isSpotlighted: spotlightflag,
      isText: textflag == 1,
      nextContentId: json['nextcontentid'] as String?,
      createdAt: DateTime.parse(json['posttimestamp'] as String),
    );
  }

  /// PostTypeを返すメソッド
  PostType get postType {
    switch (type.toLowerCase()) {
      case 'video':
        return PostType.video;
      case 'image':
        return PostType.image;
      case 'text':
        return PostType.text;
      case 'audio':
        return PostType.audio;
      default:
        return PostType.text;
    }
  }

  // サンプルデータ用（テスト・開発用）
  factory Post.sample(int index) {
    final types = ['video', 'image', 'text', 'audio'];
    final usernames = [
      'ユーザー1',
      'ユーザー2',
      'ユーザー3',
      'ユーザー4',
      'ユーザー5',
    ];
    
    return Post(
      id: 'post_$index',
      userId: 'user_${index % 5}',
      username: usernames[index % usernames.length],
      userIconPath: '',
      title: 'サンプル投稿 $index',
      content: 'これはサンプル投稿の内容です。',
      contentPath: '',
      type: types[index % types.length],
      mediaUrl: null,
      thumbnailUrl: null,
      likes: index * 10,
      playNum: index * 5,
      link: null,
      comments: index * 3,
      shares: index * 2,
      isSpotlighted: index % 3 == 0,
      isText: index % 4 == 2,
      nextContentId: 'post_${index + 1}',
      createdAt: DateTime.now().subtract(Duration(hours: index)),
    );
  }
}

