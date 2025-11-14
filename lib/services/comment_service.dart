import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
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
        if (kDebugMode) {
          debugPrint('💬 JWTトークンが取得できません');
        }
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/content/getcomments';
      
      if (kDebugMode) {
        debugPrint('💬 コメント取得URL: $url, contentID: $contentId');
      }

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
        
        if (kDebugMode) {
          debugPrint('💬 コメント取得レスポンス: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final List<dynamic> commentsJson = responseData['data'];
          return commentsJson
              .map((commentJson) => Comment.fromJson(commentJson as Map<String, dynamic>, AppConfig.backendUrl))
              .toList();
        }
      } else {
        if (kDebugMode) {
          debugPrint('💬 コメント取得エラー: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('💬 コメント取得例外: $e');
      }
    }

    return [];
  }

  /// コメントを追加
  static Future<bool> addComment(String contentId, String commentText, {int? parentCommentId}) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('💬 JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/content/addcomment';
      
      if (kDebugMode) {
        debugPrint('💬 コメント追加URL: $url, contentID: $contentId');
      }

      final requestBody = <String, dynamic>{
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
        
        if (kDebugMode) {
          debugPrint('💬 コメント追加レスポンス: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success') {
          return true;
        }
      } else {
        if (kDebugMode) {
          debugPrint('💬 コメント追加エラー: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('💬 コメント追加例外: $e');
      }
    }

    return false;
  }
}

