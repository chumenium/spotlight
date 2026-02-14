import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/comment.dart';
import '../services/jwt_service.dart';

/// コメントAPIサービス
class CommentService {
  /// コメント一覧を取得
  static Future<List<Comment>> getComments(String contentId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/content/getcomments';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'contentID': int.tryParse(contentId) ?? 0}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> commentsJson = responseData['data'];

          return commentsJson
              .map((commentJson) => Comment.fromJson(
                  commentJson as Map<String, dynamic>, AppConfig.backendUrl))
              .toList();
        }
      }
    } catch (e) {
      // ignore
    }

    return [];
  }

  /// コメントを追加
  static Future<bool> addComment(String contentId, String commentText,
      {int? parentCommentId}) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/content/addcomment';

      final parsedContentId = int.tryParse(contentId);

      final requestBody = <String, dynamic>{
        'contentID': parsedContentId ?? contentId,
        'commenttext': commentText,
      };

      if (parentCommentId != null) {
        requestBody['parentcommentID'] = parentCommentId;
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          return true;
        }
      }
    } catch (e) {
      // ignore
    }

    return false;
  }
}
