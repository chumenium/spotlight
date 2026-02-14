import 'dart:convert';
import 'package:http/http.dart' as http;
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
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/users/getsearchhistory';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final List<dynamic> historyJson = responseData['data'];
          // API仕様: 検索履歴は文字列の配列
          return historyJson.map((item) {
            return SearchHistory.fromJson(item);
          }).toList();
        }
      }
    } catch (e) {
      // ignore
    }

    return [];
  }

  /// 検索クエリを実行
  static Future<List<Post>> searchPosts(String query) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/content/serch';

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

          // バックエンドの検索結果をPostモデルに変換（Post.fromJsonを使用）
          return uniqueItems.values.map((item) {
            // contentIDを取得（数値または文字列）
            final contentId = item['contentID'];
            final contentIdStr = contentId?.toString() ?? '';

            // APIレスポンスのフィールド名をPost.fromJsonが期待する形式に変換
            final postData = <String, dynamic>{
              'contentID': contentIdStr,
              'title': item['title'] ?? '',
              'contentpath': '',
              'thumbnailpath': item['thumbnailurl'] ?? '',
              'spotlightnum': item['spotlightnum'] ?? 0,
              'playnum': item['playnum'] ?? 0,
              'posttimestamp': item['posttimestamp'] ?? DateTime.now().toIso8601String(),
              'link': item['link'],
              'username': item['username'] ?? '',
              'iconimgpath': item['iconimgpath'] ?? '',
              'spotlightflag': false,
              'textflag': false,
            };
            
            final post = Post.fromJson(postData, backendUrl: AppConfig.backendUrl);

            return post;
          }).toList();
        }
      }
    } catch (e) {
      // ignore
    }

    return [];
  }

  /// 検索履歴を削除
  static Future<bool> deleteSearchHistory(String searchId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/delete/searchhistory';

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

