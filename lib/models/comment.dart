import '../config/app_config.dart';

/// コメントモデル
class Comment {
  final int commentID;
  final String username;
  final String? iconimgpath;
  final String commenttimestamp;
  final String commenttext;
  final int? parentcommentID;
  final List<Comment> replies;
  final String? userId; // コメントを投稿したユーザーID（通報用）

  Comment({
    required this.commentID,
    required this.username,
    this.iconimgpath,
    required this.commenttimestamp,
    required this.commenttext,
    this.parentcommentID,
    this.replies = const [],
    this.userId,
  });

  factory Comment.fromJson(Map<String, dynamic> json, String backendUrl) {
    final replies = json['replies'] != null
        ? (json['replies'] as List)
            .map((reply) =>
                Comment.fromJson(reply as Map<String, dynamic>, backendUrl))
            .toList()
        : <Comment>[];

    return Comment(
      commentID: int.tryParse(json['commentID']?.toString() ?? '0') ?? 0,
      username: json['username']?.toString() ?? '',
      iconimgpath: json['iconimgpath']?.toString(),
      commenttimestamp: json['commenttimestamp']?.toString() ?? '',
      commenttext: json['commenttext']?.toString() ?? '',
      parentcommentID: json['parentcommentID'] != null
          ? int.tryParse(json['parentcommentID'].toString())
          : null,
      replies: replies,
      userId: () {
        // 複数のフィールド名を試行（バックエンドの実装に応じて）
        final userId = json['user_id']?.toString() ??
            json['userId']?.toString() ??
            json['uid']?.toString() ??
            json['firebase_uid']?.toString();

        // デバッグログ（開発時のみ）
        if (userId == null || userId.isEmpty) {
          // デバッグモードで利用可能なフィールドを確認
          // print('⚠️ コメントにuser_idが含まれていません: ${json.keys.toList()}');
        }

        return userId?.trim().isEmpty == true ? null : userId?.trim();
      }(),
    );
  }

  String? get userIconUrl {
    if (iconimgpath == null || iconimgpath!.isEmpty) {
      return null;
    }
    // 絶対パスの場合はそのまま返す
    if (iconimgpath!.startsWith('http://') ||
        iconimgpath!.startsWith('https://')) {
      return iconimgpath;
    }
    // 相対パスの場合はbackendUrlと結合
    // AppConfigから取得（HTTPSを使用）
    final backendUrl = AppConfig.backendUrl;
    if (iconimgpath!.startsWith('/')) {
      return '$backendUrl$iconimgpath';
    }
    return '$backendUrl/icon/$iconimgpath';
  }
}
