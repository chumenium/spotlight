import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../config/app_config.dart';
import '../models/search_history.dart';
import '../models/post.dart';
import '../services/jwt_service.dart';

/// 検索履歴APIサービス
class SearchService {
  /// バックエンドから検索履歴を取得
  static Future<List<SearchHistory>> fetchSearchHistory() async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('🔍 JWTトークンが取得できません');
        }
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/users/getsearchhistory';
      
      if (kDebugMode) {
        debugPrint('🔍 検索履歴取得URL: $url');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          debugPrint('🔍 検索履歴レスポンス: ${responseData.toString()}');
        }
        
        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final List<dynamic> historyJson = responseData['data'];
          // API仕様: 検索履歴は文字列の配列
          return historyJson.map((item) {
            return SearchHistory.fromJson(item);
          }).toList();
        }
      } else {
        if (kDebugMode) {
          debugPrint('🔍 検索履歴取得エラー: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔍 検索履歴取得例外: $e');
      }
    }

    return [];
  }

  /// 検索クエリを実行
  static Future<List<Post>> searchPosts(String query) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('🔍 JWTトークンが取得できません');
        }
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/content/serch';
      
      if (kDebugMode) {
        debugPrint('🔍 検索URL: $url');
        debugPrint('🔍 検索キーワード: $query');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'word': query}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          debugPrint('🔍 検索レスポンス: ${responseData.toString()}');
        }
        
        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final List<dynamic> items = responseData['data'];
          
          // 重複を防ぐためにcontentIDでマップを作成
          final Map<String, dynamic> uniqueItems = {};
          for (final item in items) {
            final contentId = item['contentID']?.toString() ?? '';
            if (contentId.isNotEmpty && !uniqueItems.containsKey(contentId)) {
              uniqueItems[contentId] = item;
            }
          }
          
          if (kDebugMode) {
            debugPrint('🔍 検索結果: 総数=${items.length}, 重複除去後=${uniqueItems.length}');
          }
          
          // バックエンドの検索結果をPostモデルに変換（Post.fromJsonを使用）
          return uniqueItems.values.map((item) {
            // contentIDを取得（数値または文字列）
            final contentId = item['contentID'];
            final contentIdStr = contentId?.toString() ?? '';
            
            if (kDebugMode && contentIdStr.isEmpty) {
              debugPrint('⚠️ 検索結果にcontentIDがありません: $item');
            }
            
            // APIレスポンスのフィールド名をPost.fromJsonが期待する形式に変換
            // 検索結果にはthumbnailurlしか含まれないため、contentpathは空にする
            // 実際のコンテンツはPostService.fetchPostDetailで取得する
            final postData = <String, dynamic>{
              'contentID': contentIdStr, // 文字列として設定
              'title': item['title'] ?? '',
              'contentpath': '', // 検索結果には含まれないため空にする
              'thumbnailpath': item['thumbnailurl'] ?? '', // 検索結果ではthumbnailurlがthumbnailpath
              'spotlightnum': item['spotlightnum'] ?? 0,
              'playnum': item['playnum'] ?? 0,
              'posttimestamp': item['posttimestamp'] ?? DateTime.now().toIso8601String(),
              'link': item['link'],
              'username': '', // 検索結果には含まれない
              'iconimgpath': '', // 検索結果には含まれない
              'spotlightflag': false,
              'textflag': false,
            };
            
            final post = Post.fromJson(postData, backendUrl: AppConfig.backendUrl);
            
            if (kDebugMode) {
              debugPrint('🔍 検索結果からPost作成: contentID=$contentIdStr, post.id=${post.id}');
              debugPrint('  - title: ${post.title}');
              debugPrint('  - thumbnailUrl: ${post.thumbnailUrl}');
              debugPrint('  - mediaUrl: ${post.mediaUrl}');
              debugPrint('  - contentPath: ${post.contentPath}');
            }
            
            return post;
          }).toList();
        }
      } else {
        if (kDebugMode) {
          debugPrint('🔍 検索エラー: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔍 検索例外: $e');
      }
    }

    return [];
  }

  /// 検索履歴を削除
  static Future<bool> deleteSearchHistory(String searchId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('🔍 JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/delete/searchhistory';
      
      if (kDebugMode) {
        debugPrint('🔍 検索履歴削除URL: $url');
        debugPrint('🔍 削除する検索履歴ID: $searchId');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'serchID': searchId}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          debugPrint('🔍 検索履歴削除レスポンス: ${responseData.toString()}');
        }
        
        if (responseData['status'] == 'success') {
          if (kDebugMode) {
            debugPrint('✅ 検索履歴削除成功: serchID=$searchId');
          }
          return true;
        } else {
          if (kDebugMode) {
            debugPrint('❌ 検索履歴削除エラー: ${responseData['message'] ?? '不明なエラー'}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ 検索履歴削除HTTPエラー: ${response.statusCode}');
          debugPrint('❌ レスポンス: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 検索履歴削除例外: $e');
      }
    }

    return false;
  }
}

