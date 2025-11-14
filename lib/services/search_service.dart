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
          
          // バックエンドの検索結果をPostモデルに変換（Post.fromJsonを使用）
          return items.map((item) {
            // APIレスポンスのフィールド名をPost.fromJsonが期待する形式に変換
            final postData = <String, dynamic>{
              'contentID': item['contentID']?.toString() ?? '',
              'title': item['title'] ?? '',
              'contentpath': item['thumbnailurl'] ?? '', // 検索結果ではthumbnailurlがcontentpath
              'thumbnailpath': item['thumbnailurl'] ?? '',
              'spotlightnum': item['spotlightnum'] ?? 0,
              'playnum': item['playnum'] ?? 0,
              'posttimestamp': item['posttimestamp'] ?? DateTime.now().toIso8601String(),
              'link': item['link'],
              'username': '', // 検索結果には含まれない
              'iconimgpath': '', // 検索結果には含まれない
              'spotlightflag': false,
              'textflag': false,
            };
            
            return Post.fromJson(postData, backendUrl: AppConfig.backendUrl);
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
}

