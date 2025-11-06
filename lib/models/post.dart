import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// 投稿タイプ
enum PostType {
  video,
  image,
  text,
  audio,
}

String? _buildFullUrl(String? backendUrl, dynamic path) {
  if (path == null) {
    return null;
  }

  final rawPath = path.toString().trim();

  if (rawPath.isEmpty) {
    return null;
  }

  // 既に完全なURLの場合はそのまま返す
  final existingUri = Uri.tryParse(rawPath);
  if (existingUri != null && existingUri.hasScheme && existingUri.host.isNotEmpty) {
    return existingUri.toString();
  }

  if (backendUrl == null || backendUrl.isEmpty) {
    return rawPath;
  }

  final baseUri = Uri.tryParse(backendUrl.trim());
  if (baseUri == null) {
    return rawPath;
  }

  try {
    final targetUri = Uri.parse(rawPath);
    
    // 絶対パス（"/"で始まる）の場合は、ベースURIのパスを保持する
    if (rawPath.startsWith('/')) {
      // ベースURIのパスと結合
      final basePath = baseUri.path.endsWith('/') 
          ? baseUri.path.substring(0, baseUri.path.length - 1) 
          : baseUri.path;
      final fullPath = '$basePath$rawPath';
      final resolvedUri = baseUri.replace(path: fullPath);
      return resolvedUri.toString();
    } else {
      // 相対パスの場合は通常のresolveUriを使用
      final resolvedUri = baseUri.resolveUri(targetUri);
      return resolvedUri.toString();
    }
  } on FormatException {
    return rawPath;
  }
}

/// 投稿モデル
class Post {
  final String id;
  final String userId;
  final String username;
  final String userIconPath;
  final String? userIconUrl; // 完全なアイコンURL
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
    this.userIconUrl,
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

  factory Post.fromJson(Map<String, dynamic> json, {String? backendUrl}) {
    final spotlightnum = json['spotlightnum'] as int? ?? 0;
    final playnum = json['playnum'] as int? ?? 0;
    final spotlightflag = json['spotlightflag'] as bool? ?? false;
    
    // textflagはboolまたはintで来る可能性があるため柔軟に処理
    final textflagValue = json['textflag'];
    final bool isTextFlag;
    if (textflagValue is bool) {
      isTextFlag = textflagValue;
    } else if (textflagValue is int) {
      isTextFlag = textflagValue == 1;
    } else {
      isTextFlag = false;
    }
    
    // contentIDを文字列に変換（intまたはStringで来る可能性があるため）
    final contentId = json['contentID'] ?? json['id'];
    final contentIdStr = contentId?.toString() ?? '';
    
    // nextcontentidを文字列に変換
    final nextContentId = json['nextcontentid'];
    final nextContentIdStr = nextContentId?.toString();
    
    // contentpathから完全なURLを生成
    final contentPath = json['contentpath'] as String? ?? '';
    final mediaUrl = _buildFullUrl(backendUrl, contentPath);

    // thumbnailpathから完全なURLを生成
    final thumbnailPath = json['thumbnailpath'] as String?;
    final thumbnailUrl = _buildFullUrl(backendUrl, thumbnailPath);

    // iconimgpathから完全なアイコンURLを生成
    final iconPath = json['iconimgpath'] as String? ?? '';
    final userIconUrl = _buildFullUrl(backendUrl, iconPath);
    
    // デバッグログ出力
    if (kDebugMode) {
      debugPrint('📦 Post.fromJson:');
      debugPrint('  contentPath: $contentPath');
      debugPrint('  mediaUrl: $mediaUrl');
      debugPrint('  thumbnailPath: $thumbnailPath');
      debugPrint('  thumbnailUrl: $thumbnailUrl');
      debugPrint('  iconPath: $iconPath');
      debugPrint('  userIconUrl: $userIconUrl');
      debugPrint('  backendUrl: $backendUrl');
    }
    
    // typeフィールドがない場合、contentpathから推測
    String postType = json['type'] as String? ?? '';
    if (postType.isEmpty && contentPath.isNotEmpty) {
      if (contentPath.contains('video') || contentPath.endsWith('.mp4') || contentPath.endsWith('.mov')) {
        postType = 'video';
      } else if (contentPath.contains('image') || contentPath.endsWith('.jpg') || contentPath.endsWith('.png')) {
        postType = 'image';
      } else if (contentPath.contains('audio') || contentPath.endsWith('.mp3') || contentPath.endsWith('.wav')) {
        postType = 'audio';
      }
    }
    if (postType.isEmpty) {
      postType = isTextFlag ? 'text' : 'text';
    }
    
    return Post(
      id: contentIdStr,
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      userIconPath: iconPath,
      userIconUrl: userIconUrl,
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      contentPath: contentPath,
      type: postType,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      likes: spotlightnum,
      playNum: playnum,
      link: json['link'] as String?,
      comments: json['comments'] as int? ?? 0,
      shares: json['shares'] as int? ?? 0,
      isSpotlighted: spotlightflag,
      isText: isTextFlag,
      nextContentId: nextContentIdStr,
      createdAt: DateTime.tryParse(json['posttimestamp'] as String? ?? '') ?? DateTime.now(),
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
      userIconUrl: null,
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

