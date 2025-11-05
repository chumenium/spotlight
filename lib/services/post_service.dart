import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../config/app_config.dart';
import '../models/post.dart';
import '../services/jwt_service.dart';

/// 投稿APIサービス
class PostService {
  /// 最小情報で投稿を作成（type, title, link のみ）
  static Future<Map<String, dynamic>?> createContentMinimal({
    required String type, // "video" | "image" | "audio" | "text"
    required String title,
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
        debugPrint('📝 最小投稿URL: $url');
      }

      final Map<String, dynamic> body = {
        'type': type,
        'title': title,
      };
      if (link != null && link.isNotEmpty) {
        body['link'] = link;
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
          debugPrint('📝 最小投稿レスポンス: ${responseData.toString()}');
        }
        if (responseData['status'] == 'success') {
          return responseData['data'];
        }
      } else {
        if (kDebugMode) {
          debugPrint('📝 最小投稿エラー: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 最小投稿例外: $e');
      }
    }

    return null;
  }
  /// バックエンドから投稿一覧を取得（/api/content/detailを連続呼び出し）
  /// 
  /// 初回はcontentID=0から始めて、nextcontentidを使って連続的に取得します
  static Future<List<Post>> fetchPosts({
    int limit = 20,
  }) async {
    final List<Post> posts = [];
    
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 JWTトークンが取得できません');
        }
        return [];
      }

      // 初回はcontentID=0から開始
      int currentContentId = 0;
      
      if (kDebugMode) {
        debugPrint('📝 投稿取得開始: limit=$limit');
      }

      // 指定された数まで連続的に取得
      for (int i = 0; i < limit; i++) {
        final url = '${AppConfig.apiBaseUrl}/content/detail';
        
        if (kDebugMode) {
          debugPrint('📝 投稿詳細取得[$i]: contentID=$currentContentId, URL=$url');
        }

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwtToken',
          },
          body: jsonEncode({'contentID': currentContentId}),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          
          if (kDebugMode) {
            debugPrint('📝 投稿詳細レスポンス[$i]: ${responseData.toString()}');
          }
          
          if (responseData['status'] == 'success' && responseData['data'] != null) {
            final data = responseData['data'] as Map<String, dynamic>;
            
            if (kDebugMode) {
              debugPrint('📝 投稿データ[$i]:');
              debugPrint('  contentpath: ${data['contentpath']}');
              debugPrint('  thumbnailpath: ${data['thumbnailpath']}');
              debugPrint('  title: ${data['title']}');
              debugPrint('  username: ${data['username']}');
              debugPrint('  iconimgpath: ${data['iconimgpath']}');
            }
            
            // 現在のコンテンツIDを追加
            data['contentID'] = currentContentId;
            
            // Postモデルに変換して追加（backendUrlを渡してメディアURLを生成）
            final post = Post.fromJson(data, backendUrl: AppConfig.backendUrl);
            posts.add(post);
            
            if (kDebugMode) {
              debugPrint('📝 投稿変換完了[$i]:');
              debugPrint('  mediaUrl: ${post.mediaUrl}');
              debugPrint('  thumbnailUrl: ${post.thumbnailUrl}');
              debugPrint('  userIconUrl: ${post.userIconUrl}');
              debugPrint('  type: ${post.type}');
            }
            
            // 次のコンテンツIDを取得
            final nextContentId = data['nextcontentid'] as int?;
            
            if (nextContentId == null || nextContentId == 0) {
              // 次のコンテンツがない場合は終了
              if (kDebugMode) {
                debugPrint('📝 これ以上コンテンツがありません');
              }
              break;
            }
            
            currentContentId = nextContentId;
          } else {
            // エラーの場合は終了
            if (kDebugMode) {
              debugPrint('📝 投稿取得失敗: ${responseData['message'] ?? 'Unknown error'}');
            }
            break;
          }
        } else {
          if (kDebugMode) {
            debugPrint('📝 投稿取得HTTPエラー: ${response.statusCode}');
          }
          break;
        }
      }
      
      if (kDebugMode) {
        debugPrint('📝 投稿取得完了: ${posts.length}件');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 投稿取得例外: $e');
      }
    }

    return posts;
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
          return postsJson.map((json) => Post.fromJson(json, backendUrl: AppConfig.backendUrl)).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 スポットライト投稿取得例外: $e');
      }
    }

    return [];
  }

  /// 投稿をスポットライトONにする
  static Future<bool> spotlightOn(String postId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/content/spotlight/on';
      
      if (kDebugMode) {
        debugPrint('📝 スポットライトON URL: $url, contentID: $postId');
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'contentID': int.tryParse(postId) ?? 0}),
      );

      if (kDebugMode) {
        debugPrint('📝 スポットライトONレスポンス: ${response.statusCode}');
      }

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 スポットライトON例外: $e');
      }
      return false;
    }
  }

  /// 投稿をスポットライトOFFにする
  static Future<bool> spotlightOff(String postId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/content/spotlight/off';
      
      if (kDebugMode) {
        debugPrint('📝 スポットライトOFF URL: $url, contentID: $postId');
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'contentID': int.tryParse(postId) ?? 0}),
      );

      if (kDebugMode) {
        debugPrint('📝 スポットライトOFFレスポンス: ${response.statusCode}');
      }

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 スポットライトOFF例外: $e');
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
        body: jsonEncode({'contentID': int.tryParse(contentId) ?? 0}),
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
          return Post.fromJson(data, backendUrl: AppConfig.backendUrl);
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

