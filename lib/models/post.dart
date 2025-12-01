import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../config/app_config.dart';

/// 投稿タイプ
enum PostType {
  video,
  image,
  text,
  audio,
}

/// アイコンURLにキャッシュキーを追加（1時間に1回の読み込み制限）
/// 同じURLを使用することで、CachedNetworkImageのキャッシュが効く
String? _addIconCacheKey(String? iconUrl) {
  if (iconUrl == null || iconUrl.isEmpty) {
    return null;
  }

  // 既にキャッシュキーが含まれている場合はそのまま返す
  if (iconUrl.contains('?cache=')) {
    return iconUrl;
  }

  // 1時間ごとに更新されるキャッシュキーを生成（同じ時間帯は同じキー）
  final now = DateTime.now();
  final cacheKey =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}';

  // URLにキャッシュキーを追加
  final separator = iconUrl.contains('?') ? '&' : '?';
  return '$iconUrl${separator}cache=$cacheKey';
}

/// パスをCloudFront URLに正規化（バックエンドのnormalize_content_url相当）
/// /content/movie/filename.mp4 -> https://d30se1secd7t6t.cloudfront.net/movie/filename.mp4
String? _normalizeContentUrl(String? path) {
  if (path == null || path.isEmpty) {
    return null;
  }

  final rawPath = path.trim();

  if (rawPath.isEmpty) {
    return null;
  }

  // 既に完全なURL（CloudFront URLまたはS3 URL）の場合はそのまま返す
  if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
    return rawPath;
  }

  // /content/movie/filename.mp4 のような形式を CloudFront URL に変換
  if (rawPath.startsWith('/content/')) {
    // /content/movie/filename.mp4 -> movie/filename.mp4
    final pathWithoutContent = rawPath.replaceFirst('/content/', '');
    final parts = pathWithoutContent.split('/');
    if (parts.length >= 2) {
      final folder = parts[0]; // movie, picture, audio, thumbnail
      final filename = parts.sublist(1).join('/');
      return '${AppConfig.cloudFrontUrl}/$folder/$filename';
    }
  }

  // その他の形式の場合はそのまま返す
  return rawPath;
}

String? _buildFullUrl(String? baseUrl, dynamic path) {
  if (path == null) {
    return null;
  }

  final rawPath = path.toString().trim();

  if (rawPath.isEmpty) {
    return null;
  }

  // 既に完全なURLの場合はそのまま返す
  final existingUri = Uri.tryParse(rawPath);
  if (existingUri != null &&
      existingUri.hasScheme &&
      existingUri.host.isNotEmpty) {
    return existingUri.toString();
  }

  if (baseUrl == null || baseUrl.isEmpty) {
    return rawPath;
  }

  final baseUri = Uri.tryParse(baseUrl.trim());
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

      if (kDebugMode) {
        debugPrint(
            '🔗 URL結合（絶対パス）: baseUrl=$baseUrl, rawPath=$rawPath, result=${resolvedUri.toString()}');
      }

      return resolvedUri.toString();
    } else {
      // 相対パスの場合は通常のresolveUriを使用
      final resolvedUri = baseUri.resolveUri(targetUri);

      if (kDebugMode) {
        debugPrint(
            '🔗 URL結合（相対パス）: baseUrl=$baseUrl, rawPath=$rawPath, result=${resolvedUri.toString()}');
      }

      return resolvedUri.toString();
    }
  } on FormatException catch (e) {
    if (kDebugMode) {
      debugPrint('❌ URL解析エラー: $e, rawPath=$rawPath');
    }
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

    // メディアファイルはCloudFront経由で配信（S3から）
    // contentpathから完全なURLを生成（CloudFront URLを使用）
    // バックエンドが返すパス形式（/content/movie/filename.mp4など）をCloudFront URLに変換
    final contentPath = json['contentpath'] as String? ?? '';
    final normalizedContentPath = _normalizeContentUrl(contentPath);
    final mediaUrl = normalizedContentPath ??
        _buildFullUrl(AppConfig.mediaBaseUrl, contentPath);

    // thumbnailpathから完全なURLを生成（CloudFront URLを使用）
    final thumbnailPath = json['thumbnailpath'] as String?;
    final normalizedThumbnailPath = _normalizeContentUrl(thumbnailPath);
    final thumbnailUrl = normalizedThumbnailPath ??
        _buildFullUrl(AppConfig.mediaBaseUrl, thumbnailPath);

    // iconimgpathから完全なアイコンURLを生成（バックエンドサーバーから配信）
    // アイコンURLにキャッシュキーを追加して、1時間以内は同じURLを使用（AWS使用量削減）
    final iconPath = json['iconimgpath'] as String? ?? '';
    final baseIconUrl = _buildFullUrl(AppConfig.backendUrl, iconPath);
    final userIconUrl = _addIconCacheKey(baseIconUrl);

    // デバッグログ出力
    if (kDebugMode) {
      debugPrint('📦 Post.fromJson:');
      debugPrint('  contentPath: $contentPath');
      debugPrint('  mediaUrl: $mediaUrl (CloudFront経由)');
      debugPrint('  thumbnailPath: $thumbnailPath');
      debugPrint('  thumbnailUrl: $thumbnailUrl (CloudFront経由)');
      debugPrint('  iconPath: $iconPath');
      debugPrint('  userIconUrl: $userIconUrl (バックエンドサーバー経由)');
      debugPrint('  mediaBaseUrl: ${AppConfig.mediaBaseUrl}');
      debugPrint('  backendUrl: ${AppConfig.backendUrl}');
    }

    // typeフィールドがない場合、contentpathから推測
    String postType = json['type'] as String? ?? '';
    if (postType.isEmpty && contentPath.isNotEmpty) {
      // CloudFront URLのパスから推測（/movie/, /picture/, /audio/）
      if (contentPath.contains('/movie/') ||
          contentPath.contains('video') ||
          contentPath.endsWith('.mp4') ||
          contentPath.endsWith('.mov')) {
        postType = 'video';
      } else if (contentPath.contains('/picture/') ||
          contentPath.contains('image') ||
          contentPath.endsWith('.jpg') ||
          contentPath.endsWith('.png') ||
          contentPath.endsWith('.jpeg')) {
        postType = 'image';
      } else if (contentPath.contains('/audio/') ||
          contentPath.contains('audio') ||
          contentPath.endsWith('.mp3') ||
          contentPath.endsWith('.wav') ||
          contentPath.endsWith('.m4a')) {
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
      createdAt: () {
        final timestampStr = json['posttimestamp'] as String? ?? '';
        if (timestampStr.isEmpty) {
          return DateTime.now();
        }
        // バックエンドから来るデータはUTCとして扱う
        // タイムゾーン情報がない場合は、'Z'を追加してUTCとして明示的にパース
        final hasTimezone = timestampStr.endsWith('Z') || 
            timestampStr.contains('+') || 
            (timestampStr.length > 10 && timestampStr[10] == '-' && timestampStr.contains('T'));
        final normalizedTimestamp = hasTimezone ? timestampStr : '${timestampStr}Z';
        final parsed = DateTime.tryParse(normalizedTimestamp);
        // UTCとして解釈されたDateTimeを返す（表示時に.toLocal()でローカルタイムに変換）
        return parsed ?? DateTime.now();
      }(),
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
