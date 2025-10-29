import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../config/app_config.dart';
import '../models/post.dart';
import '../services/jwt_service.dart';

/// 投稿APIサービス
class PostService {
  /// バックエンドから投稿一覧を取得
  static Future<List<Post>> fetchPosts({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 JWTトークンが取得できません');
        }
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/posts?page=$page&limit=$limit';
      
      if (kDebugMode) {
        debugPrint('📝 投稿取得URL: $url');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          debugPrint('📝 投稿レスポンス: ${responseData.toString()}');
        }
        
        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final List<dynamic> postsJson = responseData['data'];
          return postsJson.map((json) => Post.fromJson(json)).toList();
        }
      } else {
        if (kDebugMode) {
          debugPrint('📝 投稿取得エラー: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 投稿取得例外: $e');
      }
    }

    return [];
  }

  /// スポットライトした投稿を一覧取得
  static Future<List<Post>> fetchSpotlightedPosts({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/posts/spotlighted?page=$page&limit=$limit';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final List<dynamic> postsJson = responseData['data'];
          return postsJson.map((json) => Post.fromJson(json)).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 スポットライト投稿取得例外: $e');
      }
    }

    return [];
  }

  /// 投稿をスポットライトする
  static Future<bool> spotlightPost(String postId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/posts/$postId/spotlight';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 スポットライト例外: $e');
      }
      return false;
    }
  }

  /// 投稿詳細を取得
  static Future<Post?> fetchPostDetail(String contentId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 JWTトークンが取得できません');
        }
        return null;
      }

      final url = '${AppConfig.apiBaseUrl}/content/detail';
      
      if (kDebugMode) {
        debugPrint('📝 投稿詳細取得URL: $url');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'contentid': contentId}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          debugPrint('📝 投稿詳細レスポンス: ${responseData.toString()}');
        }
        
        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final Map<String, dynamic> data = responseData['data'];
          // IDを追加してPostモデルに変換
          data['id'] = contentId;
          return Post.fromJson(data);
        }
      } else {
        if (kDebugMode) {
          debugPrint('📝 投稿詳細取得エラー: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 投稿詳細取得例外: $e');
      }
    }

    return null;
  }

  /// 投稿を作成
  static Future<Map<String, dynamic>?> createPost({
    required String type, // video, image, audio, text
    required String title,
    String? text, // テキスト投稿の場合のみ
    String? fileBase64, // 非テキスト投稿の場合のみ（base64）
    String? thumbnailBase64, // 非テキスト投稿の場合のみ（base64）
    String? link,
  }) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 JWTトークンが取得できません');
        }
        return null;
      }

      final url = '${AppConfig.apiBaseUrl}/content/add';
      
      if (kDebugMode) {
        debugPrint('📝 投稿作成URL: $url');
      }

      // リクエストボディ作成
      Map<String, dynamic> body = {
        'type': type,
        'title': title,
      };

      if (link != null && link.isNotEmpty) {
        body['link'] = link;
      }

      if (type == 'text') {
        // テキスト投稿の場合
        if (text != null && text.isNotEmpty) {
          body['text'] = text;
        } else {
          if (kDebugMode) {
            debugPrint('📝 テキスト投稿にはtextが必要です');
          }
          return null;
        }
      } else {
        // 非テキスト投稿の場合
        if (fileBase64 != null && thumbnailBase64 != null) {
          body['file'] = fileBase64;
          body['thumbnail'] = thumbnailBase64;
        } else {
          if (kDebugMode) {
            debugPrint('📝 非テキスト投稿にはfileとthumbnailが必要です');
          }
          return null;
        }
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          debugPrint('📝 投稿作成レスポンス: ${responseData.toString()}');
        }
        
        if (responseData['status'] == 'success') {
          return responseData['data'];
        }
      } else {
        if (kDebugMode) {
          debugPrint('📝 投稿作成エラー: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 投稿作成例外: $e');
      }
    }

    return null;
  }
}

