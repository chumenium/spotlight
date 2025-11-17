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
  /// contentID=1から昇順で取得します
  static Future<List<Post>> fetchPosts({
    int limit = 20,
    int startId = 1,
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

      if (kDebugMode) {
        debugPrint('📝 投稿取得開始: startId=$startId, limit=$limit');
      }

      // startIdから昇順で取得
      for (int i = 0; i < limit; i++) {
        final contentId = startId + i;
        final url = '${AppConfig.apiBaseUrl}/content/detail';

        if (kDebugMode) {
          debugPrint('📝 投稿詳細取得[$i]: contentID=$contentId, URL=$url');
        }

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwtToken',
          },
          body: jsonEncode({'contentID': contentId}),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);

          if (kDebugMode) {
            debugPrint('📝 投稿詳細レスポンス[$i]: ${responseData.toString()}');
          }

          if (responseData['status'] == 'success' &&
              responseData['data'] != null) {
            final data = responseData['data'] as Map<String, dynamic>;

            if (kDebugMode) {
              debugPrint('📝 投稿データ[$i] (ID=$contentId):');
              debugPrint('  contentpath: ${data['contentpath']}');
              debugPrint('  thumbnailpath: ${data['thumbnailpath']}');
              debugPrint('  title: ${data['title']}');
              debugPrint('  username: ${data['username']}');
              debugPrint('  iconimgpath: ${data['iconimgpath']}');
            }

            // コンテンツIDを追加
            data['contentID'] = contentId;

            // Postモデルに変換して追加（backendUrlを渡してメディアURLを生成）
            final post = Post.fromJson(data, backendUrl: AppConfig.backendUrl);
            posts.add(post);

            if (kDebugMode) {
              debugPrint('📝 投稿変換完了[$i] (ID=$contentId):');
              debugPrint('  mediaUrl: ${post.mediaUrl}');
              debugPrint('  thumbnailUrl: ${post.thumbnailUrl}');
              debugPrint('  userIconUrl: ${post.userIconUrl}');
              debugPrint('  type: ${post.type}');
            }
          } else {
            // コンテンツが存在しない場合はスキップ
            if (kDebugMode) {
              debugPrint('📝 投稿ID=$contentId は存在しないか取得失敗、スキップ');
            }
            // 次のIDを試す（終了しない）
          }
        } else {
          if (kDebugMode) {
            debugPrint(
                '📝 投稿ID=$contentId HTTPエラー: ${response.statusCode}、スキップ');
          }
          // 次のIDを試す（終了しない）
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

      final url =
          '${AppConfig.apiBaseUrl}/posts/spotlighted?page=$page&limit=$limit';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> postsJson = responseData['data'];
          return postsJson
              .map((json) =>
                  Post.fromJson(json, backendUrl: AppConfig.backendUrl))
              .toList();
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

  /// 投稿詳細を取得（視聴履歴を記録する）
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
      final contentIdInt = int.tryParse(contentId) ?? 0;

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'contentID': contentIdInt}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final Map<String, dynamic> data = responseData['data'];
          data['contentID'] = contentId;
          return Post.fromJson(data, backendUrl: AppConfig.backendUrl);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 投稿詳細取得例外: $e');
      }
    }

    return null;
  }

  /// 視聴履歴を取得
  ///
  /// ER図に基づくテーブル構造:
  /// - playhistory: userID, playID, contentID のみ
  /// - content: contentID, userID, title, contentpath, link, posttimestamp, spotlightnum
  /// - user: userID, username, iconimagpath
  ///
  /// 重複排除ロジック:
  /// - 同じ contentID が複数ある場合、playID が最大のもの（最新の視聴履歴）だけを残す
  /// - 直近50件までに制限
  /// - playID の降順でソート（最新が先頭）
  ///
  /// 手順:
  /// 1. /api/users/getplayhistory から playhistory のデータを取得
  /// 2. 同じ contentID の重複を排除（最新の playID だけを残す）
  /// 3. playID の降順でソート
  /// 4. 50件までに制限
  /// 5. 各 contentID を使って /api/content/detail からコンテンツ情報を取得
  /// 6. Post オブジェクトに変換して返す
  static Future<List<Post>> getPlayHistory() async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 [視聴履歴] JWTトークンが取得できません');
        }
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/users/getplayhistory';

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] API呼び出し: $url');
      }

      // ステップ1: playhistory テーブルからデータを取得
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({}),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('📝 [視聴履歴] APIエラー: ${response.statusCode}');
        }
        return [];
      }

      final responseData = jsonDecode(response.body);

      if (responseData['status'] != 'success' || responseData['data'] == null) {
        if (kDebugMode) {
          debugPrint('📝 [視聴履歴] APIレスポンスエラー: ${responseData['status']}');
        }
        return [];
      }

      final List<dynamic> historyJson = responseData['data'] as List;

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] playhistory取得: ${historyJson.length}件');
        if (historyJson.isNotEmpty && historyJson[0] is Map) {
          debugPrint(
              '📝 [視聴履歴] 最初の項目のキー: ${(historyJson[0] as Map).keys.toList()}');
        }
      }

      if (historyJson.isEmpty) {
        return [];
      }

      // ステップ2: 各履歴項目を解析
      final List<Map<String, dynamic>> historyItems = [];

      for (final item in historyJson) {
        if (item is! Map<String, dynamic>) continue;

        // contentID を取得（大文字小文字を考慮）
        final contentId = item['contentID']?.toString() ??
            item['contentid']?.toString() ??
            item['contentId']?.toString() ??
            '';

        if (contentId.isEmpty) continue;

        // playID を取得（数値として扱う）
        final playIdStr = item['playID']?.toString() ??
            item['playid']?.toString() ??
            item['playId']?.toString() ??
            '0';
        final playId = int.tryParse(playIdStr) ?? 0;

        historyItems.add({
          'contentId': contentId,
          'playId': playId,
        });
      }

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] 履歴項目解析完了: ${historyItems.length}件');
      }

      // ステップ3: 同じ contentID の重複を排除（最新の playID だけを残す）
      final Map<String, Map<String, dynamic>> uniqueHistory = {};

      for (final item in historyItems) {
        final contentId = item['contentId'] as String;
        final playId = item['playId'] as int;

        if (!uniqueHistory.containsKey(contentId)) {
          // 初めて見つかった contentID
          uniqueHistory[contentId] = item;
        } else {
          // 既に存在する contentID の場合、playID が大きい方（新しい方）を残す
          final existingPlayId = uniqueHistory[contentId]!['playId'] as int;
          if (playId > existingPlayId) {
            uniqueHistory[contentId] = item;
          }
        }
      }

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] 重複排除後: ${uniqueHistory.length}件');
      }

      // ステップ4: playID の降順でソート（最新が先頭）
      final sortedHistory = uniqueHistory.values.toList()
        ..sort((a, b) => (b['playId'] as int).compareTo(a['playId'] as int));

      // ステップ5: 50件までに制限
      final limitedHistory = sortedHistory.take(50).toList();

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] ソート・制限後: ${limitedHistory.length}件');
      }

      // ステップ6: 各 contentID を収集
      final Set<String> contentIds = {};
      for (final item in limitedHistory) {
        contentIds.add(item['contentId'] as String);
      }

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] 取得対象のcontentID: ${contentIds.length}件');
      }

      // ステップ7: 各 contentID を使ってコンテンツ情報を取得（並列処理）
      final Map<String, Post> contentMap = {};

      if (contentIds.isNotEmpty) {
        final futures = contentIds.map((contentId) async {
          try {
            final post = await fetchPostDetail(contentId);
            if (post != null) {
              return MapEntry(contentId, post);
            }
            return null;
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                  '📝 [視聴履歴] コンテンツ取得エラー: contentID=$contentId, error=$e');
            }
            return null;
          }
        }).toList();

        final results = await Future.wait(futures);
        for (final result in results) {
          if (result != null) {
            contentMap[result.key] = result.value;
          }
        }

        if (kDebugMode) {
          debugPrint(
              '📝 [視聴履歴] コンテンツ情報取得完了: ${contentMap.length}件 / ${contentIds.length}件');
        }
      }

      // ステップ8: 視聴履歴の順序を保持しながら Post オブジェクトのリストを作成
      final List<Post> posts = [];
      for (final item in limitedHistory) {
        final contentId = item['contentId'] as String;
        final post = contentMap[contentId];

        if (post != null) {
          posts.add(post);
        } else {
          if (kDebugMode) {
            debugPrint('📝 [視聴履歴] コンテンツ情報が見つかりません: contentID=$contentId');
          }
        }
      }

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] 最終結果: ${posts.length}件');
        if (posts.isNotEmpty) {
          debugPrint(
              '📝 [視聴履歴] 最初の項目: ID=${posts[0].id}, タイトル=${posts[0].title}, 投稿者=${posts[0].username}');
          debugPrint(
              '📝 [視聴履歴] 最後の項目: ID=${posts[posts.length - 1].id}, タイトル=${posts[posts.length - 1].title}');
        }
      }

      return posts;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] 例外: $e');
        debugPrint('📝 [視聴履歴] スタックトレース: $stackTrace');
      }
      return [];
    }
  }

  /// 自分自身のアカウントから投稿されたコンテンツ一覧を取得
  static Future<List<Post>> getUserContents() async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 JWTトークンが取得できません');
        }
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/users/getusercontents';

      if (kDebugMode) {
        debugPrint('📝 自分の投稿取得URL: $url');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('📝 自分の投稿取得レスポンス: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> postsJson = responseData['data'];

          if (kDebugMode) {
            debugPrint('📝 自分の投稿数: ${postsJson.length}');
          }

          return postsJson.map((json) {
            // contentIDをidとして設定
            final contentId = json['contentID']?.toString() ?? '';
            json['id'] = contentId;
            return Post.fromJson(json, backendUrl: AppConfig.backendUrl);
          }).toList();
        }
      } else {
        if (kDebugMode) {
          debugPrint('📝 自分の投稿取得エラー: ${response.statusCode}');
          debugPrint('レスポンス: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 自分の投稿取得例外: $e');
      }
    }

    return [];
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
