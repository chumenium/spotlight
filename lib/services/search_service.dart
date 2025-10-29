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
          return historyJson.map((json) => SearchHistory.fromJson(json)).toList();
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
          
          // バックエンドの検索結果をPostモデルに変換
          return items.map((item) {
            return Post(
              id: item['contentID'] as String,
              userId: '', // 検索結果には含まれない
              username: '', // 検索結果には含まれない
              userIconPath: '',
              title: item['title'] as String? ?? '',
              content: null,
              contentPath: '',
              type: 'video', // デフォルトとしてvideoを設定
              mediaUrl: item['link'] as String?,
              thumbnailUrl: item['thumbnailurl'] as String?,
              likes: item['spotlightnum'] as int? ?? 0,
              playNum: item['playnum'] as int? ?? 0,
              link: item['link'] as String?,
              comments: 0,
              shares: 0,
              isSpotlighted: false,
              isText: false,
              nextContentId: null,
              createdAt: DateTime.parse(item['posttimestamp'] as String),
            );
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

