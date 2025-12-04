import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../config/app_config.dart';
import '../models/post.dart';
import '../services/jwt_service.dart';

/// 投稿APIサービス
class PostService {
  // 最近記録された視聴履歴のcontentIDを保存（最新の視聴履歴を確実に取得するため）
  static final List<String> _recentlyRecordedContentIds = [];
  static const int _maxRecentContentIds = 10; // 最大10件まで保持

  /// 最近記録されたcontentIDを追加
  static void _addRecentlyRecordedContentId(String contentId) {
    // 既に存在する場合は削除してから先頭に追加（最新のものを先頭に）
    _recentlyRecordedContentIds.remove(contentId);
    _recentlyRecordedContentIds.insert(0, contentId);

    // 最大件数を超える場合は古いものを削除
    if (_recentlyRecordedContentIds.length > _maxRecentContentIds) {
      _recentlyRecordedContentIds.removeRange(
          _maxRecentContentIds, _recentlyRecordedContentIds.length);
    }
  }

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

      // startIdから昇順で取得（存在する投稿をlimit件取得するまで続ける）
      int currentId = startId;
      int attemptCount = 0;
      final int maxAttempts = limit * 10; // 最大試行回数（limitの10倍まで）

      while (posts.length < limit && attemptCount < maxAttempts) {
        final contentId = currentId;
        final url = '${AppConfig.apiBaseUrl}/content/detail';

        if (kDebugMode) {
          debugPrint(
              '📝 投稿詳細取得[試行${attemptCount + 1}]: contentID=$contentId, URL=$url, 現在の取得数=${posts.length}/$limit');
        }

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwtToken',
          },
          body: jsonEncode({'contentID': contentId}),
        );

        attemptCount++;

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);

          if (kDebugMode) {
            debugPrint(
                '📝 投稿詳細レスポンス[試行$attemptCount]: ${responseData.toString()}');
          }

          if (responseData['status'] == 'success' &&
              responseData['data'] != null) {
            final data = responseData['data'] as Map<String, dynamic>;

            if (kDebugMode) {
              debugPrint('📝 投稿データ[試行$attemptCount] (ID=$contentId):');
              debugPrint('  contentpath: ${data['contentpath']}');
              debugPrint('  thumbnailpath: ${data['thumbnailpath']}');
              debugPrint('  title: ${data['title']}');
              debugPrint('  username: ${data['username']}');
              debugPrint('  iconimgpath: ${data['iconimgpath']}');
              debugPrint('  user_id: ${data['user_id']}');
              debugPrint('  firebase_uid: ${data['firebase_uid']}');
              debugPrint('  全フィールド: ${data.keys.toList()}');
              debugPrint('  comments: ${data['comments']}');
              debugPrint('  commentnum: ${data['commentnum']}');
              debugPrint('  comment_count: ${data['comment_count']}');
            }

            // user_idまたはfirebase_uidが含まれていない場合、警告を出す
            if ((data['user_id'] == null || data['user_id'] == '') &&
                (data['firebase_uid'] == null || data['firebase_uid'] == '')) {
              if (kDebugMode) {
                debugPrint('⚠️ 警告: 投稿データにuser_id/firebase_uidが含まれていません');
                debugPrint('  contentID: $contentId');
                debugPrint('  username: ${data['username']}');
              }
            }

            // コンテンツIDを追加
            data['contentID'] = contentId;

            // データの整合性を確認（バックエンドから返されるデータにusernameやuser_idが含まれているか）
            if (kDebugMode) {
              final hasUsername = data.containsKey('username') &&
                  data['username'] != null &&
                  (data['username'] as String).isNotEmpty;
              final hasUserId = (data.containsKey('user_id') &&
                      data['user_id'] != null &&
                      (data['user_id'] as String).isNotEmpty) ||
                  (data.containsKey('firebase_uid') &&
                      data['firebase_uid'] != null &&
                      (data['firebase_uid'] as String).isNotEmpty);

              if (!hasUsername) {
                debugPrint(
                    '⚠️ [fetchPosts] データ整合性警告[試行$attemptCount]: usernameが含まれていません');
                debugPrint('   - contentID: $contentId');
                debugPrint('   - 利用可能なキー: ${data.keys.toList()}');
              }
              if (!hasUserId) {
                debugPrint(
                    '⚠️ [fetchPosts] データ整合性警告[試行$attemptCount]: user_id/firebase_uidが含まれていません');
                debugPrint('   - contentID: $contentId');
                debugPrint('   - username: ${data['username']}');
                debugPrint('   - 利用可能なキー: ${data.keys.toList()}');
              }
            }

            // Postモデルに変換して追加（backendUrlを渡してメディアURLを生成）
            final post = Post.fromJson(data, backendUrl: AppConfig.backendUrl);

            // 変換後のデータの整合性を確認
            if (kDebugMode) {
              if (post.id.isEmpty) {
                debugPrint('⚠️ [fetchPosts] Post変換後[試行$attemptCount]: IDが空です');
              }
              if (post.username.isEmpty) {
                debugPrint(
                    '⚠️ [fetchPosts] Post変換後[試行$attemptCount]: usernameが空です (postId: ${post.id})');
              }
              if (post.userId.isEmpty) {
                debugPrint(
                    '⚠️ [fetchPosts] Post変換後[試行$attemptCount]: userIdが空です (postId: ${post.id}, username: ${post.username})');
              }
            }

            posts.add(post);

            if (kDebugMode) {
              debugPrint('📝 投稿変換完了[試行$attemptCount] (ID=$contentId):');
              debugPrint('  mediaUrl: ${post.mediaUrl}');
              debugPrint('  thumbnailUrl: ${post.thumbnailUrl}');
              debugPrint('  userIconUrl: ${post.userIconUrl}');
              debugPrint('  type: ${post.type}');
              debugPrint('  username: ${post.username}');
              debugPrint('  userId: ${post.userId}');
            }
          } else {
            // コンテンツが存在しない場合はスキップ
            if (kDebugMode) {
              debugPrint('📝 投稿ID=$contentId は存在しないか取得失敗、スキップ');
            }
          }
        } else {
          if (kDebugMode) {
            debugPrint(
                '📝 投稿ID=$contentId HTTPエラー: ${response.statusCode}、スキップ');
          }
        }

        // 次のIDを試す
        currentId++;
      }

      if (kDebugMode) {
        if (posts.length < limit && attemptCount >= maxAttempts) {
          debugPrint('⚠️ 投稿取得: 最大試行回数に達しました（${posts.length}/$limit件取得）');
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

  /// 視聴履歴を記録する
  static Future<bool> recordPlayHistory(String contentId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 [視聴履歴記録] JWTトークンが取得できません: contentID=$contentId');
        }
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/content/playnum';
      final contentIdInt = int.tryParse(contentId) ?? 0;

      if (contentIdInt == 0) {
        if (kDebugMode) {
          debugPrint('📝 [視聴履歴記録] 無効なcontentID: $contentId');
        }
        return false;
      }

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴記録] 記録開始: contentID=$contentId');
      }

      final response = await http
          .post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'contentID': contentIdInt}),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('📝 [視聴履歴記録] タイムアウト: contentID=$contentId');
          }
          return http.Response('', 408);
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          // 視聴履歴を記録したcontentIDをキャッシュに保存（最新の視聴履歴を確実に取得するため）
          _addRecentlyRecordedContentId(contentId);

          if (kDebugMode) {
            debugPrint('📝 [視聴履歴記録] 記録成功: contentID=$contentId');
          }

          return true;
        } else {
          if (kDebugMode) {
            debugPrint(
                '📝 [視聴履歴記録] APIレスポンスエラー: contentID=$contentId, status=${responseData['status']}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint(
              '📝 [視聴履歴記録] HTTPエラー: contentID=$contentId, statusCode=${response.statusCode}');
          debugPrint('📝 [視聴履歴記録] レスポンス: ${response.body}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('📝 [視聴履歴記録] 例外: contentID=$contentId, error=$e');
        debugPrint('📝 [視聴履歴記録] スタックトレース: $stackTrace');
      }
    }

    return false;
  }

  /// 投稿詳細を取得（視聴履歴を記録しない）
  /// 視聴履歴を記録せずに投稿詳細を取得する場合に使用
  static Future<Post?> fetchPostDetailWithoutRecording(String contentId) async {
    return _fetchPostDetailInternal(contentId, recordHistory: false);
  }

  /// 投稿詳細を取得（視聴履歴を記録しない）
  /// 注意: このメソッドは視聴履歴を記録しません。視聴履歴を記録するには recordPlayHistory() を使用してください。
  static Future<Post?> fetchPostDetail(String contentId) async {
    return _fetchPostDetailInternal(contentId, recordHistory: false);
  }

  /// 投稿詳細を取得（内部実装）
  static Future<Post?> _fetchPostDetailInternal(String contentId,
      {required bool recordHistory}) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 [投稿詳細] JWTトークンが取得できません: contentID=$contentId');
        }
        return null;
      }

      final url = '${AppConfig.apiBaseUrl}/content/detail';
      final contentIdInt = int.tryParse(contentId) ?? 0;

      if (contentIdInt == 0) {
        if (kDebugMode) {
          debugPrint('📝 [投稿詳細] 無効なcontentID: $contentId');
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint('📝 [投稿詳細] 取得開始: contentID=$contentId');
      }

      final response = await http
          .post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'contentID': contentIdInt}),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('📝 [投稿詳細] タイムアウト: contentID=$contentId');
          }
          throw TimeoutException('Request timeout for contentID: $contentId');
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final Map<String, dynamic> data = responseData['data'];
          data['contentID'] = contentId;
          final post = Post.fromJson(data, backendUrl: AppConfig.backendUrl);

          if (kDebugMode) {
            debugPrint(
                '📝 [投稿詳細] 取得成功: contentID=$contentId, タイトル=${post.title}');
          }

          return post;
        } else {
          if (kDebugMode) {
            debugPrint(
                '📝 [投稿詳細] APIレスポンスエラー: contentID=$contentId, status=${responseData['status']}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint(
              '📝 [投稿詳細] HTTPエラー: contentID=$contentId, statusCode=${response.statusCode}');
          debugPrint('📝 [投稿詳細] レスポンス: ${response.body}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('📝 [投稿詳細] 例外: contentID=$contentId, error=$e');
        debugPrint('📝 [投稿詳細] スタックトレース: $stackTrace');
      }
    }

    return null;
  }

  /// 投稿を削除
  ///
  /// データベースから指定された投稿を完全に削除
  /// - contentID: 削除する投稿のID
  static Future<bool> deletePost(String contentId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 [投稿削除] JWTトークンが取得できません');
        }
        return false;
      }

      // API仕様書（API_ENDPOINTS.md 498-507行目）に基づく
      // POST /api/delete/content
      final url = '${AppConfig.apiBaseUrl}/delete/content';
      final contentIdInt = int.tryParse(contentId);

      if (contentIdInt == null || contentIdInt == 0) {
        if (kDebugMode) {
          debugPrint('❌ [投稿削除] contentIDの解析に失敗しました');
          debugPrint('   - contentId (元の値): $contentId');
        }
        return false;
      }

      // API仕様書に基づき、キー名はcontentID（大文字のID）
      final requestBody = {
        'contentID': contentIdInt,
      };

      if (kDebugMode) {
        debugPrint('📝 [投稿削除] ========== API呼び出し ==========');
        debugPrint('📝 [投稿削除] URL: $url');
        debugPrint('📝 [投稿削除] リクエストボディ: ${jsonEncode(requestBody)}');
      }

      // タイムアウトを設定（30秒）
      final response = await http
          .post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('❌ [投稿削除] タイムアウト: 30秒以内にレスポンスがありませんでした');
          }
          throw TimeoutException('投稿削除のリクエストがタイムアウトしました');
        },
      );

      if (kDebugMode) {
        debugPrint('📝 [投稿削除] HTTPステータスコード: ${response.statusCode}');
        debugPrint('📝 [投稿削除] レスポンスボディ: ${response.body}');
      }

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (kDebugMode) {
            debugPrint('📝 [投稿削除] レスポンス（パース後）: ${responseData.toString()}');
          }

          if (responseData['status'] == 'success') {
            if (kDebugMode) {
              debugPrint('✅ [投稿削除] 成功: データベースから削除されました');
            }
            return true;
          } else {
            if (kDebugMode) {
              debugPrint('❌ [投稿削除] APIレスポンスエラー');
              debugPrint('   - status: ${responseData['status']}');
              debugPrint('   - message: ${responseData['message'] ?? 'なし'}');
            }
            return false;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [投稿削除] レスポンスのパースエラー: $e');
          }
          return false;
        }
      } else if (response.statusCode == 404) {
        if (kDebugMode) {
          debugPrint('❌ [投稿削除] エンドポイントが見つかりません (404)');
          debugPrint('   - URL: $url');
          debugPrint('   - このエンドポイントはバックエンドに実装されていない可能性があります');
        }
        return false;
      } else {
        if (kDebugMode) {
          debugPrint('❌ [投稿削除] HTTPエラー: ${response.statusCode}');
          debugPrint('📝 [投稿削除] レスポンス: ${response.body}');
        }
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [投稿削除] 例外: $e');
        debugPrint('📝 [投稿削除] スタックトレース: $stackTrace');

        // ClientExceptionの場合は、エンドポイントが存在しないかCORSエラーの可能性
        if (e.toString().contains('ClientException') ||
            e.toString().contains('Failed to fetch')) {
          debugPrint('⚠️ [投稿削除] エンドポイントが存在しないか、CORSエラーの可能性があります');
          debugPrint(
              '   - バックエンドに /api/delete/content エンドポイントが実装されているか確認してください');
          debugPrint('   - CORS設定が正しく行われているか確認してください');
          debugPrint('   - ネットワーク接続を確認してください');
        }
      }
    }

    return false;
  }

  /// 視聴履歴を取得
  ///
  /// テーブル構造（postgreDBSQL.txt参照）:
  /// - playhistory: userID, playID, contentID
  /// - content: contentID, userID, title, contentpath, link, posttimestamp, spotlightnum, playnum, thumbnailpath
  /// - user: userID, username, iconimgpath
  ///
  /// バックエンドの /api/users/getplayhistory は以下のデータを返す:
  /// - contentID, title, spotlightnum, posttimestamp, playnum, link, thumbnailpath
  /// - 既に playID の降順でソート済み（ORDER BY p.playID DESC）
  ///
  /// 手順:
  /// 1. /api/users/getplayhistory から視聴履歴データを取得
  /// 2. 同じ contentID の重複を排除（最初に見つかったものを残す = 最新の視聴履歴）
  /// 3. 50件までに制限
  /// 4. 各 contentID を使って /api/content/detail から完全なコンテンツ情報を取得
  ///    （username, iconimgpath, contentpath, textflag, spotlightflag を取得するため）
  /// 5. Post オブジェクトに変換して返す
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
        debugPrint('📝 [視聴履歴] ========== 視聴履歴取得開始 ==========');
        debugPrint('📝 [視聴履歴] API呼び出し: $url');
        debugPrint(
            '📝 [視聴履歴] JWTトークン: ${jwtToken.substring(0, 20)}... (先頭20文字)');
        debugPrint('📝 [視聴履歴] バックエンドは WHERE p.userID = %s でフィルタリング');
        debugPrint('📝 [視聴履歴] バックエンドは ORDER BY p.playID DESC で降順ソート');
      }

      // ステップ1: /api/users/getplayhistory から視聴履歴データを取得
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
          debugPrint('📝 [視聴履歴] レスポンス: ${response.body}');
        }
        return [];
      }

      final responseData = jsonDecode(response.body);

      if (responseData['status'] != 'success' || responseData['data'] == null) {
        if (kDebugMode) {
          debugPrint('📝 [視聴履歴] APIレスポンスエラー: ${responseData['status']}');
          debugPrint('📝 [視聴履歴] レスポンスデータ: ${responseData.toString()}');
        }
        return [];
      }

      final List<dynamic> historyJson = responseData['data'] as List;

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] ========== バックエンドレスポンス ==========');
        debugPrint('📝 [視聴履歴] 取得件数: ${historyJson.length}件');
        debugPrint('📝 [視聴履歴] バックエンドは ORDER BY p.playID DESC でソート済み');
        debugPrint('📝 [視聴履歴] → playIDが大きい（新しい）ものが最初に来る');
        if (historyJson.isNotEmpty) {
          if (historyJson[0] is Map) {
            debugPrint(
                '📝 [視聴履歴] 最初の項目のキー: ${(historyJson[0] as Map).keys.toList()}');
            debugPrint('📝 [視聴履歴] 最初の項目（最新の視聴履歴）: ${historyJson[0]}');
          }
          debugPrint(
              '📝 [視聴履歴] 全項目のcontentID（順序）: ${historyJson.map((item) => item is Map ? (item['contentID'] ?? item['contentid'] ?? item['contentId'] ?? 'N/A').toString() : 'N/A').join(", ")}');
          debugPrint('📝 [視聴履歴] → 最初に来るcontentIDが最新の視聴履歴');

          // contentIDの分布を確認
          final contentIdCounts = <String, int>{};
          for (final item in historyJson) {
            if (item is Map) {
              final contentId = (item['contentID'] ??
                      item['contentid'] ??
                      item['contentId'] ??
                      'N/A')
                  .toString();
              contentIdCounts[contentId] =
                  (contentIdCounts[contentId] ?? 0) + 1;
            }
          }
          debugPrint('📝 [視聴履歴] contentIDの分布（視聴回数）:');
          contentIdCounts.forEach((contentId, count) {
            debugPrint('   contentID=$contentId: $count回視聴');
          });
          final uniqueContentIds = contentIdCounts.keys.toSet();
          debugPrint('📝 [視聴履歴] ユニークなcontentID数: ${uniqueContentIds.length}件');
          debugPrint('📝 [視聴履歴] 注意: 同じcontentIDが複数回視聴されている場合、重複排除されます');
          debugPrint(
              '📝 [視聴履歴] 注意: バックエンドのクエリは JOIN content c ON p.contentID = c.contentID でJOINしているため、');
          debugPrint('📝 [視聴履歴]      contentが存在しない視聴履歴は返されません');

          // 最初の5件の詳細を表示
          debugPrint('📝 [視聴履歴] 最初の5件の詳細:');
          for (int i = 0; i < historyJson.length && i < 5; i++) {
            final item = historyJson[i];
            if (item is Map) {
              debugPrint(
                  '   [$i] contentID=${item['contentID']}, title=${item['title']}, posttimestamp=${item['posttimestamp']}');
            }
          }
        } else {
          debugPrint('⚠️ [視聴履歴] バックエンドからデータが返されていません');
          debugPrint('⚠️ [視聴履歴] 考えられる原因:');
          debugPrint('   1. playhistoryテーブルに現在のユーザーのデータが存在しない');
          debugPrint('   2. バックエンドのクエリエラー（WHERE p.userID = %s の条件が一致しない）');
          debugPrint('   3. 認証トークンの問題（JWTトークンに含まれるfirebase_uidが正しくない）');
          debugPrint(
              '   4. JOIN content c ON p.contentID = c.contentID で一致するcontentが存在しない');
        }
        debugPrint('📝 [視聴履歴] ===========================================');
      }

      // ステップ1.5: 最近記録されたcontentIDを確認し、バックエンドから返されるデータに含まれていない場合は直接取得
      final Set<String> backendContentIds = {};
      for (final item in historyJson) {
        if (item is Map) {
          final contentId = (item['contentID'] ??
                  item['contentid'] ??
                  item['contentId'] ??
                  '')
              .toString();
          if (contentId.isNotEmpty) {
            backendContentIds.add(contentId);
          }
        }
      }

      // 最近記録されたcontentIDのうち、バックエンドから返されていないものを取得
      final List<Post> missingPosts = [];
      final List<String> missingContentIds = _recentlyRecordedContentIds
          .where((contentId) => !backendContentIds.contains(contentId))
          .toList();

      if (missingContentIds.isNotEmpty) {
        for (final contentId in missingContentIds) {
          try {
            // 視聴履歴を記録せずに投稿詳細を取得（既に記録済みのため）
            final post = await fetchPostDetailWithoutRecording(contentId);
            if (post != null) {
              missingPosts.add(post);
            }
          } catch (e) {
            // エラーは無視（取得できない場合はスキップ）
          }
        }
      }

      if (historyJson.isEmpty && missingPosts.isEmpty) {
        return [];
      }

      // ステップ2: contentID を抽出し、重複を排除
      // バックエンドは既に playID DESC でソート済みなので、最初に見つかったcontentIDが最新の視聴履歴
      // 順序を保持するため、Listを使用して順番を記録
      // 各contentIDの最初の出現位置（インデックス）を記録して、最新の視聴履歴を保持
      // バックエンドから返されるデータの情報（title, posttimestamp等）も保持
      final Map<String, int> contentIdToFirstIndex = {};
      final List<String> orderedContentIds = [];
      final Map<String, Map<String, dynamic>> contentIdToHistoryData = {};

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] ========== contentID抽出開始 ==========');
        debugPrint('📝 [視聴履歴] バックエンドは既に playID DESC でソート済み');
        debugPrint('📝 [視聴履歴] 最初に見つかったcontentIDが最新の視聴履歴');
      }

      for (int index = 0; index < historyJson.length; index++) {
        final item = historyJson[index];
        if (item is! Map<String, dynamic>) {
          if (kDebugMode) {
            debugPrint('⚠️ [視聴履歴] 無効なアイテム形式[$index]: ${item.runtimeType}');
          }
          continue;
        }

        // contentID を取得（大文字小文字を考慮）
        final contentId = item['contentID']?.toString() ??
            item['contentid']?.toString() ??
            item['contentId']?.toString() ??
            '';

        if (contentId.isEmpty) {
          if (kDebugMode) {
            debugPrint('⚠️ [視聴履歴] contentIDが空[$index]: $item');
          }
          continue;
        }

        // 重複を排除（最初に見つかったものを残す = 最新の視聴履歴）
        // バックエンドは既に playID DESC でソート済みなので、最初に見つかったものが最新
        if (!contentIdToFirstIndex.containsKey(contentId)) {
          contentIdToFirstIndex[contentId] = index;
          orderedContentIds.add(contentId);
          // バックエンドから返されるデータの情報を保持（title, posttimestamp等）
          contentIdToHistoryData[contentId] = Map<String, dynamic>.from(item);
          if (kDebugMode) {
            debugPrint('✅ [視聴履歴] contentID追加[$index]: $contentId (最新の視聴履歴)');
            debugPrint(
                '   📝 保持したデータ: title=${item['title']}, posttimestamp=${item['posttimestamp']}');
          }
        } else {
          if (kDebugMode) {
            final firstIndex = contentIdToFirstIndex[contentId]!;
            debugPrint(
                '⏭️ [視聴履歴] contentID重複スキップ[$index]: $contentId (既に追加済み、最初の出現: $firstIndex)');
          }
        }
      }

      // 順序を保持したまま重複排除されたリスト
      final uniqueContentIds = orderedContentIds;

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] 重複排除後: ${uniqueContentIds.length}件');
        debugPrint(
            '📝 [視聴履歴] 抽出したcontentID（順序保持）: ${uniqueContentIds.join(", ")}');
        debugPrint('📝 [視聴履歴] ===========================================');
      }

      // ステップ3: 50件までに制限
      final limitedContentIds = uniqueContentIds.take(50).toList();

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] 制限後: ${limitedContentIds.length}件');
      }

      // ステップ4: 各 contentID を使って /api/content/detail から完全なコンテンツ情報を取得
      // 並列処理で取得（最大10件ずつ処理してタイムアウトを防ぐ）
      final Map<String, Post> contentMap = {};
      final List<String> failedContentIds = [];

      if (limitedContentIds.isNotEmpty) {
        // 10件ずつバッチ処理
        const batchSize = 10;
        for (int i = 0; i < limitedContentIds.length; i += batchSize) {
          final batch = limitedContentIds.skip(i).take(batchSize).toList();

          if (kDebugMode) {
            debugPrint(
                '📝 [視聴履歴] バッチ処理: ${i + 1}-${i + batch.length} / ${limitedContentIds.length}件');
          }

          final futures = batch.map((contentId) async {
            try {
              final post = await fetchPostDetail(contentId);
              if (post != null) {
                // バックエンドから返されるデータの情報をマージ
                final historyData = contentIdToHistoryData[contentId];
                if (historyData != null) {
                  // バックエンドから返されるデータのtitleとposttimestampを優先
                  // （視聴履歴の順序を正確に反映するため）
                  final mergedData = Map<String, dynamic>.from(historyData);
                  // /api/content/detailから取得したデータで不足している情報を補完
                  mergedData['username'] = post.username;
                  mergedData['iconimgpath'] = post.userIconPath;
                  // contentpathがない場合はlinkを使用（バックエンドが返すlinkは相対パスまたはCloudFront URL）
                  if (mergedData['contentpath'] == null ||
                      (mergedData['contentpath'] as String).isEmpty) {
                    final link = historyData['link'] as String?;
                    if (link != null && link.isNotEmpty) {
                      mergedData['contentpath'] = link;
                    } else {
                      mergedData['contentpath'] = post.contentPath;
                    }
                  }
                  mergedData['textflag'] = post.isText;
                  mergedData['spotlightflag'] = post.isSpotlighted;

                  // Postオブジェクトを再構築（バックエンドのデータを優先）
                  final mergedPost = Post.fromJson(mergedData,
                      backendUrl: AppConfig.backendUrl);

                  if (kDebugMode) {
                    debugPrint('📝 [視聴履歴] データマージ: contentID=$contentId');
                    debugPrint('   バックエンドのtitle: ${historyData['title']}');
                    debugPrint('   マージ後のtitle: ${mergedPost.title}');
                  }

                  return MapEntry(contentId, mergedPost);
                }
                return MapEntry(contentId, post);
              } else {
                if (kDebugMode) {
                  debugPrint('📝 [視聴履歴] コンテンツ取得失敗（null）: contentID=$contentId');
                }
                failedContentIds.add(contentId);
                return null;
              }
            } catch (e, stackTrace) {
              if (kDebugMode) {
                debugPrint(
                    '📝 [視聴履歴] コンテンツ取得エラー: contentID=$contentId, error=$e');
                debugPrint('📝 [視聴履歴] スタックトレース: $stackTrace');
              }
              failedContentIds.add(contentId);
              return null;
            }
          }).toList();

          try {
            final results = await Future.wait(futures, eagerError: false);
            for (final result in results) {
              if (result != null) {
                contentMap[result.key] = result.value;
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('📝 [視聴履歴] バッチ処理エラー: $e');
            }
          }
        }

        if (kDebugMode) {
          debugPrint(
              '📝 [視聴履歴] コンテンツ情報取得完了: ${contentMap.length}件 / ${limitedContentIds.length}件');
          if (failedContentIds.isNotEmpty) {
            debugPrint('📝 [視聴履歴] 取得失敗したcontentID: $failedContentIds');
          }
        }
      }

      // ステップ5: 視聴履歴の順序を保持しながら Post オブジェクトのリストを作成
      List<Post> posts = [];
      for (final contentId in limitedContentIds) {
        final post = contentMap[contentId];

        if (post != null) {
          posts.add(post);
          if (kDebugMode) {
            debugPrint(
                '📝 [視聴履歴] 追加: contentID=$contentId, タイトル=${post.title}');
          }
        } else {
          if (kDebugMode) {
            debugPrint('📝 [視聴履歴] コンテンツ情報が見つかりません: contentID=$contentId');
          }
        }
      }

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] ========== 最終結果 ==========');
        debugPrint('📝 [視聴履歴] バックエンドから取得: ${historyJson.length}件');
        debugPrint('📝 [視聴履歴] 重複排除後: ${uniqueContentIds.length}件');
        debugPrint('📝 [視聴履歴] 制限後（50件まで）: ${limitedContentIds.length}件');
        debugPrint('📝 [視聴履歴] コンテンツ詳細取得成功: ${contentMap.length}件');
        debugPrint('📝 [視聴履歴] 最終的に返す件数: ${posts.length}件');
        debugPrint('📝 [視聴履歴] 失敗件数: ${failedContentIds.length}件');
        if (failedContentIds.isNotEmpty) {
          debugPrint('📝 [視聴履歴] 失敗したcontentID: ${failedContentIds.join(", ")}');
        }
        if (posts.isNotEmpty) {
          debugPrint(
              '📝 [視聴履歴] 最初の項目（最新の視聴履歴）: ID=${posts[0].id}, タイトル=${posts[0].title}, 投稿者=${posts[0].username}');
          if (posts.length > 1) {
            debugPrint(
                '📝 [視聴履歴] 最後の項目: ID=${posts[posts.length - 1].id}, タイトル=${posts[posts.length - 1].title}');
          }
          debugPrint(
              '📝 [視聴履歴] 全項目のID（表示順序）: ${posts.map((p) => p.id).join(", ")}');
          debugPrint(
              '📝 [視聴履歴] 全項目のタイトル: ${posts.map((p) => p.title).join(", ")}');
        } else {
          debugPrint('⚠️ [視聴履歴] 取得したデータが空です');
          debugPrint(
              '📝 [視聴履歴] バックエンドから取得したcontentID: ${limitedContentIds.join(", ")}');
          debugPrint('⚠️ [視聴履歴] 考えられる原因:');
          debugPrint('   1. コンテンツ詳細の取得に失敗した');
          debugPrint('   2. Post.fromJson()の変換に失敗した');
          debugPrint('   3. バックエンドから返されたcontentIDが無効');
        }
        debugPrint('📝 [視聴履歴] ================================');
      }

      // 最近記録されたcontentIDで取得できた投稿を先頭に追加（最新の視聴履歴として）
      if (missingPosts.isNotEmpty) {
        // 重複を排除（既にpostsに含まれているcontentIDは除外）
        final existingIds = posts.map((p) => p.id.toString()).toSet();
        final newPosts = missingPosts
            .where((p) => !existingIds.contains(p.id.toString()))
            .toList();
        posts = [...newPosts, ...posts];
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

  /// 視聴履歴を削除
  ///
  /// データベースから指定された視聴履歴を削除
  /// - contentID: 削除する視聴履歴のコンテンツID
  /// 注意: API仕様ではplayIDが必要ですが、現在のAPIレスポンスにplayIDが含まれていない可能性があります。
  /// バックエンド側でcontentIDからplayIDを取得する実装が必要な場合があります。
  static Future<bool> deletePlayHistory(String contentId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 [視聴履歴削除] JWTトークンが取得できません');
        }
        return false;
      }

      // API仕様書（API_ENDPOINTS.md 430-439行目）に基づく
      // POST /api/delete/playhistory
      // 注意: API仕様ではplayIDが必要ですが、現在のAPIレスポンスにplayIDが含まれていないため、
      // contentIDで削除できると仮定しています。バックエンド側で対応が必要な場合があります。
      final url = '${AppConfig.apiBaseUrl}/delete/playhistory';
      final contentIdInt = int.tryParse(contentId);

      if (contentIdInt == null || contentIdInt == 0) {
        if (kDebugMode) {
          debugPrint('❌ [視聴履歴削除] contentIDの解析に失敗しました');
          debugPrint('   - contentId (元の値): $contentId');
        }
        return false;
      }

      // バックエンドの実装（routes/delete.py 28行目）を確認:
      // playid = data.get("playID")
      // バックエンドは "playID" を期待している
      // しかし、getPlayHistory()のレスポンスにplayIDが含まれていないため、
      // バックエンド側でcontentIDとuserIDから最新のplayIDを取得して削除する必要があります
      // 現時点では、バックエンドがcontentIDを受け取ってplayIDを取得する実装になっていないため、
      // この機能は動作しません
      //
      // 代替案: contentIDを送信して、バックエンド側で対応してもらう必要がありますが、
      // バックエンドは編集しないため、この機能は動作しません
      //
      // 注意: バックエンドを編集できないため、視聴履歴削除機能は現時点では動作しません
      // バックエンド側でcontentIDからplayIDを取得する実装が必要です
      final requestBody = {
        'playID': null, // playIDが取得できないため、nullを送信（バックエンド側でエラーになる）
        'contentID': contentIdInt, // バックエンド側でcontentIDからplayIDを取得して削除する必要がある
      };

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴削除] ========== API呼び出し ==========');
        debugPrint('📝 [視聴履歴削除] URL: $url');
        debugPrint('📝 [視聴履歴削除] リクエストボディ: ${jsonEncode(requestBody)}');
        debugPrint('📝 [視聴履歴削除] ⚠️ 警告: getPlayHistory()のレスポンスにplayIDが含まれていません');
        debugPrint('📝 [視聴履歴削除] ⚠️ 警告: バックエンドはplayIDを期待していますが、contentIDを送信します');
        debugPrint('📝 [視聴履歴削除] ⚠️ 警告: バックエンド側でcontentIDからplayIDを取得する実装が必要です');
        debugPrint('📝 [視聴履歴削除] ⚠️ 警告: バックエンドを編集できないため、この機能は動作しません');
      }

      // タイムアウトを設定（30秒）
      final response = await http
          .post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('❌ [視聴履歴削除] タイムアウト: 30秒以内にレスポンスがありませんでした');
          }
          throw TimeoutException('視聴履歴削除のリクエストがタイムアウトしました');
        },
      );

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴削除] HTTPステータスコード: ${response.statusCode}');
        debugPrint('📝 [視聴履歴削除] レスポンスボディ: ${response.body}');
      }

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (kDebugMode) {
            debugPrint('📝 [視聴履歴削除] レスポンス（パース後）: ${responseData.toString()}');
          }

          if (responseData['status'] == 'success') {
            if (kDebugMode) {
              debugPrint('✅ [視聴履歴削除] 成功: データベースから削除されました');
            }
            return true;
          } else {
            if (kDebugMode) {
              debugPrint('❌ [視聴履歴削除] APIレスポンスエラー');
              debugPrint('   - status: ${responseData['status']}');
              debugPrint('   - message: ${responseData['message'] ?? 'なし'}');
            }
            return false;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [視聴履歴削除] レスポンスのパースエラー: $e');
          }
          return false;
        }
      } else if (response.statusCode == 404) {
        if (kDebugMode) {
          debugPrint('❌ [視聴履歴削除] エンドポイントが見つかりません (404)');
          debugPrint('   - URL: $url');
          debugPrint('   - このエンドポイントはバックエンドに実装されていない可能性があります');
        }
        return false;
      } else {
        if (kDebugMode) {
          debugPrint('❌ [視聴履歴削除] HTTPエラー: ${response.statusCode}');
          debugPrint('📝 [視聴履歴削除] レスポンス: ${response.body}');
        }
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [視聴履歴削除] 例外: $e');
        debugPrint('📝 [視聴履歴削除] スタックトレース: $stackTrace');

        // ClientExceptionの場合は、エンドポイントが存在しないかCORSエラーの可能性
        if (e.toString().contains('ClientException') ||
            e.toString().contains('Failed to fetch')) {
          debugPrint('⚠️ [視聴履歴削除] エンドポイントが存在しないか、CORSエラーの可能性があります');
          debugPrint(
              '   - バックエンドに /api/delete/playhistory エンドポイントが実装されているか確認してください');
          debugPrint('   - CORS設定が正しく行われているか確認してください');
          debugPrint('   - ネットワーク接続を確認してください');
          debugPrint(
              '   - 注意: バックエンドはplayIDを期待していますが、現在のAPIレスポンスにplayIDが含まれていません');
        }
      }
    }

    return false;
  }

  /// 投稿を作成
  /// 戻り値: 成功時はMap<String, dynamic>、失敗時はnull
  /// エラー情報は例外としてスローされる
  static Future<Map<String, dynamic>?> createPost({
    required String type, // video, image, audio, text
    required String title,
    String? text, // テキスト投稿の場合のみ
    String? fileBase64, // 非テキスト投稿の場合のみ（base64）
    String? thumbnailBase64, // 非テキスト投稿の場合のみ（base64）
    String? link,
    String? tag,
  }) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 JWTトークンが取得できません');
        }
        throw Exception('JWTトークンが取得できません');
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

      // linkはオプショナル（nullまたは空の場合はリクエストボディに含めない）
      // バックエンド側でNoneTypeエラーを防ぐため、明示的に含めない
      if (link != null && link.trim().isNotEmpty) {
        body['link'] = link.trim();
      }

      // タグはオプショナル（nullまたは空の場合はリクエストボディに含めない）
      // バックエンド側でNoneTypeエラーを防ぐため、明示的に含めない
      if (tag != null && tag.trim().isNotEmpty) {
        body['tag'] = tag.trim();
      }

      if (kDebugMode) {
        debugPrint('📝 リクエストボディのキー: ${body.keys.toList()}');
        debugPrint(
            '📝 linkの状態: ${link == null ? "null" : (link.isEmpty ? "空文字列" : "値あり: $link")}');
        debugPrint(
            '📝 タグの状態: ${tag == null ? "null" : (tag.isEmpty ? "空文字列" : "値あり: $tag")}');
      }

      if (type == 'text') {
        // テキスト投稿の場合
        if (text != null && text.isNotEmpty) {
          body['text'] = text;
        } else {
          if (kDebugMode) {
            debugPrint('📝 テキスト投稿にはtextが必要です');
          }
          throw Exception('テキスト投稿にはtextが必要です');
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
          throw Exception('非テキスト投稿にはfileとthumbnailが必要です');
        }
      }

      // リクエストボディをJSONエンコード
      // デバッグ: リクエストボディの内容を確認（tagとlinkが含まれていないことを確認）
      if (kDebugMode) {
        debugPrint('📝 リクエストボディ（JSONエンコード前）:');
        debugPrint('   - すべてのキー: ${body.keys.toList()}');
        debugPrint('   - linkフィールドの存在: ${body.containsKey('link')}');
        if (body.containsKey('link')) {
          debugPrint('   - linkの値: ${body['link']}');
        }
        debugPrint('   - tagフィールドの存在: ${body.containsKey('tag')}');
        if (body.containsKey('tag')) {
          debugPrint('   - tagの値: ${body['tag']}');
        }
      }

      final jsonBody = jsonEncode(body);
      final requestBodySize = jsonBody.length;

      if (kDebugMode) {
        debugPrint('📝 リクエストボディサイズ:');
        debugPrint(
            '   - JSON文字列サイズ: ${(requestBodySize / 1024 / 1024).toStringAsFixed(2)} MB');
        if (fileBase64 != null) {
          debugPrint(
              '   - file(base64)サイズ: ${(fileBase64.length / 1024 / 1024).toStringAsFixed(2)} MB');
        }
        if (thumbnailBase64 != null) {
          debugPrint(
              '   - thumbnail(base64)サイズ: ${(thumbnailBase64.length / 1024 / 1024).toStringAsFixed(2)} MB');
        }
        debugPrint(
            '   - その他（type, title, link等）: ${((requestBodySize - (fileBase64?.length ?? 0) - (thumbnailBase64?.length ?? 0)) / 1024).toStringAsFixed(2)} KB');
      }

      // 大きなファイルを送信するためのHTTPクライアント設定
      final client = http.Client();
      try {
        final response = await client
            .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwtToken',
          },
          body: jsonBody,
        )
            .timeout(
          const Duration(minutes: 30), // 大きなファイル用にタイムアウトを30分に延長
          onTimeout: () {
            throw TimeoutException(
              'リクエストがタイムアウトしました（30分）',
              const Duration(minutes: 30),
            );
          },
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);

          if (kDebugMode) {
            debugPrint('📝 投稿作成レスポンス: ${responseData.toString()}');
          }

          if (responseData['status'] == 'success') {
            return responseData['data'];
          } else {
            // サーバーからエラーメッセージが返された場合
            final errorMessage =
                responseData['message'] ?? responseData['error'] ?? '投稿に失敗しました';
            throw Exception(errorMessage);
          }
        } else {
          // HTTPエラーステータスコードの場合
          String errorMessage;
          if (response.statusCode == 413) {
            // より詳細なエラーメッセージ
            errorMessage =
                'ファイルサイズが大きすぎます（HTTP 413: Request Entity Too Large）。リクエストサイズ: ${(requestBodySize / 1024 / 1024).toStringAsFixed(2)}MB';
          } else if (response.statusCode == 400) {
            errorMessage = 'リクエストが不正です（HTTP 400: Bad Request）';
          } else if (response.statusCode == 401) {
            errorMessage = '認証に失敗しました（HTTP 401: Unauthorized）';
          } else if (response.statusCode == 500) {
            errorMessage = 'サーバーエラーが発生しました（HTTP 500: Internal Server Error）';
          } else {
            errorMessage = '投稿に失敗しました（HTTP ${response.statusCode}）';
          }

          if (kDebugMode) {
            debugPrint('📝 投稿作成エラー: ${response.statusCode}');
            debugPrint('📝 エラーメッセージ: $errorMessage');
            debugPrint(
                '📝 リクエストボディサイズ: ${(requestBodySize / 1024 / 1024).toStringAsFixed(2)} MB');
            debugPrint('📝 レスポンスボディ: ${response.body}');
          }

          throw Exception(errorMessage);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 投稿作成例外: $e');
      }
      // 既にExceptionの場合はそのまま再スロー、それ以外はExceptionにラップ
      if (e is Exception) {
        rethrow;
      }
      throw Exception('投稿作成中にエラーが発生しました: $e');
    }
  }

  /// 指定されたユーザーIDの投稿一覧を取得
  static Future<List<Post>> getUserPostsByUserId(String userId) async {
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
        debugPrint('📝 ユーザー投稿取得URL: $url');
        debugPrint('📝 ユーザーID (firebase_uid): $userId');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'firebase_uid': userId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('📝 ユーザー投稿取得レスポンス: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> postsJson = responseData['data'];

          if (kDebugMode) {
            debugPrint('📝 ユーザー投稿数: ${postsJson.length}');
            if (postsJson.isNotEmpty) {
              final firstPost = postsJson.first;
              debugPrint('📝 最初の投稿のuser_id: ${firstPost['user_id']}');
              debugPrint('📝 リクエストしたuserId: $userId');
            }
          }

          final posts = postsJson.map((json) {
            // contentIDをidとして設定
            final contentId = json['contentID']?.toString() ?? '';
            json['id'] = contentId;
            return Post.fromJson(json, backendUrl: AppConfig.backendUrl);
          }).toList();

          // 取得した投稿が指定したユーザーのものか確認
          if (kDebugMode && posts.isNotEmpty) {
            final firstPostUserId = posts.first.userId;
            if (firstPostUserId != userId) {
              debugPrint('⚠️ 警告: 取得した投稿のユーザーIDが一致しません');
              debugPrint('  期待されるuserId: $userId');
              debugPrint('  実際のuserId: $firstPostUserId');
            }
          }

          return posts;
        }
      } else {
        if (kDebugMode) {
          debugPrint('📝 ユーザー投稿取得エラー: ${response.statusCode}');
          debugPrint('レスポンス: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 ユーザー投稿取得例外: $e');
      }
    }

    return [];
  }

  /// /api/content/getcontents APIを使用して5件のコンテンツを取得
  /// 戻り値: 成功時はPostのリスト、失敗時は空のリスト
  static Future<List<Post>> fetchContents() async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 [getcontents] JWTトークンが取得できません');
        }
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/content/getcontents';

      if (kDebugMode) {
        debugPrint('📝 [getcontents] API呼び出し: $url');
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
          debugPrint('📝 [getcontents] レスポンス: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> contentsJson = responseData['data'] as List;

          if (kDebugMode) {
            debugPrint('📝 [getcontents] 取得件数: ${contentsJson.length}件');
          }

          // レスポンスデータをPostオブジェクトに変換
          final List<Post> posts = [];
          for (int i = 0; i < contentsJson.length; i++) {
            final contentJson = contentsJson[i] as Map<String, dynamic>;

            if (kDebugMode) {
              debugPrint(
                  '📝 [getcontents] コンテンツ[$i]のキー: ${contentJson.keys.toList()}');
              debugPrint('📝 [getcontents] コンテンツ[$i]の内容: $contentJson');
            }

            // contentIDがレスポンスに含まれていない場合の警告
            if (!contentJson.containsKey('contentID') &&
                !contentJson.containsKey('contentid') &&
                !contentJson.containsKey('id')) {
              if (kDebugMode) {
                debugPrint('⚠️ [getcontents] ⚠️⚠️⚠️ バックエンドの不具合 ⚠️⚠️⚠️');
                debugPrint(
                    '⚠️ [getcontents] contentID/contentid/idがレスポンスに含まれていません: インデックス $i');
                debugPrint(
                    '⚠️ [getcontents] バックエンドのcontents.pyの/getcontentsエンドポイントで、');
                debugPrint(
                    '⚠️ [getcontents] result.append()に"contentID": row[12]を追加する必要があります');
                debugPrint(
                    '⚠️ [getcontents] 現在のレスポンスキー: ${contentJson.keys.toList()}');
              }
              // バックエンドの不具合のため、このコンテンツはスキップ
              continue;
            }

            // contentID/contentid/idのいずれかを使用
            final contentId = contentJson['contentID']?.toString() ??
                contentJson['contentid']?.toString() ??
                contentJson['id']?.toString() ??
                '';

            if (contentId.isEmpty) {
              if (kDebugMode) {
                debugPrint('⚠️ [getcontents] contentIDが空です: インデックス $i');
              }
              continue;
            }

            // idとして設定（Post.fromJsonで使用される）
            contentJson['id'] = contentId;
            contentJson['contentID'] = contentId; // 念のため両方設定

            // Post.fromJsonを使用してPostオブジェクトに変換
            try {
              // データの整合性を確認（バックエンドから返されるデータにusernameやuser_idが含まれているか）
              if (kDebugMode) {
                final hasUsername = contentJson.containsKey('username') &&
                    contentJson['username'] != null &&
                    (contentJson['username'] as String).isNotEmpty;
                final hasUserId = (contentJson.containsKey('user_id') &&
                        contentJson['user_id'] != null &&
                        (contentJson['user_id'] as String).isNotEmpty) ||
                    (contentJson.containsKey('firebase_uid') &&
                        contentJson['firebase_uid'] != null &&
                        (contentJson['firebase_uid'] as String).isNotEmpty);

                if (!hasUsername) {
                  debugPrint(
                      '⚠️ [getcontents] データ整合性警告[$i]: usernameが含まれていません');
                  debugPrint(
                      '   - contentID: ${contentJson['contentID'] ?? contentJson['id']}');
                  debugPrint('   - 利用可能なキー: ${contentJson.keys.toList()}');
                }
                if (!hasUserId) {
                  debugPrint(
                      '⚠️ [getcontents] データ整合性警告[$i]: user_id/firebase_uidが含まれていません');
                  debugPrint(
                      '   - contentID: ${contentJson['contentID'] ?? contentJson['id']}');
                  debugPrint('   - username: ${contentJson['username']}');
                  debugPrint('   - 利用可能なキー: ${contentJson.keys.toList()}');
                }
              }

              final post =
                  Post.fromJson(contentJson, backendUrl: AppConfig.backendUrl);

              // 変換後のデータの整合性を確認
              if (kDebugMode) {
                if (post.id.isEmpty) {
                  debugPrint('⚠️ [getcontents] Post変換後[$i]: IDが空です');
                }
                if (post.username.isEmpty) {
                  debugPrint(
                      '⚠️ [getcontents] Post変換後[$i]: usernameが空です (postId: ${post.id})');
                }
                if (post.userId.isEmpty) {
                  debugPrint(
                      '⚠️ [getcontents] Post変換後[$i]: userIdが空です (postId: ${post.id}, username: ${post.username})');
                }
                debugPrint(
                    '✅ [getcontents] Post変換成功[$i]: ID=${post.id}, タイトル=${post.title}, username=${post.username}, userId=${post.userId}');
              }

              posts.add(post);
            } catch (e, stackTrace) {
              if (kDebugMode) {
                debugPrint('⚠️ [getcontents] Post変換エラー: $e, インデックス $i');
                debugPrint('⚠️ [getcontents] スタックトレース: $stackTrace');
                debugPrint('⚠️ [getcontents] コンテンツJSON: $contentJson');
              }
            }
          }

          if (kDebugMode) {
            debugPrint('📝 [getcontents] 変換完了: ${posts.length}件');
          }

          return posts;
        } else {
          if (kDebugMode) {
            debugPrint(
                '📝 [getcontents] APIレスポンスエラー: ${responseData['status']}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('📝 [getcontents] HTTPエラー: ${response.statusCode}');
          debugPrint('📝 [getcontents] レスポンス: ${response.body}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('📝 [getcontents] 例外: $e');
        debugPrint('📝 [getcontents] スタックトレース: $stackTrace');
      }
    }

    return [];
  }

  /// /api/content/getcontent APIを使用して1件のコンテンツを取得
  /// 外部画面からホームの特定コンテンツに遷移する際に使用
  /// 戻り値: 成功時はPost、失敗時はnull
  static Future<Post?> fetchContentById(String contentId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 [getcontent] JWTトークンが取得できません: contentID=$contentId');
        }
        return null;
      }

      final url = '${AppConfig.apiBaseUrl}/content/getcontent';
      final contentIdInt = int.tryParse(contentId) ?? 0;

      if (contentIdInt == 0) {
        if (kDebugMode) {
          debugPrint('📝 [getcontent] 無効なcontentID: $contentId');
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint('📝 [getcontent] API呼び出し: $url, contentID=$contentId');
      }

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

        if (kDebugMode) {
          debugPrint('📝 [getcontent] レスポンス: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> contentsJson = responseData['data'] as List;

          if (contentsJson.isEmpty) {
            if (kDebugMode) {
              debugPrint('📝 [getcontent] データが空です: contentID=$contentId');
            }
            return null;
          }

          // 最初の要素を取得（1件のみのはず）
          final contentJson = contentsJson[0] as Map<String, dynamic>;

          // contentIDがレスポンスに含まれていない場合、パラメータのcontentIdを使用
          if (!contentJson.containsKey('contentID')) {
            if (kDebugMode) {
              debugPrint(
                  '⚠️ [getcontent] contentIDがレスポンスに含まれていません。パラメータのcontentIdを使用: $contentId');
            }
            contentJson['contentID'] = contentId;
          }

          // contentIDをidとして設定
          final responseContentId =
              contentJson['contentID']?.toString() ?? contentId;
          contentJson['id'] = responseContentId;

          // Post.fromJsonを使用してPostオブジェクトに変換
          try {
            final post =
                Post.fromJson(contentJson, backendUrl: AppConfig.backendUrl);

            if (kDebugMode) {
              debugPrint(
                  '📝 [getcontent] 取得成功: contentID=$contentId, タイトル=${post.title}');
            }

            return post;
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ [getcontent] Post変換エラー: $e, contentID=$contentId');
            }
            return null;
          }
        } else {
          if (kDebugMode) {
            debugPrint(
                '📝 [getcontent] APIレスポンスエラー: ${responseData['status']}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('📝 [getcontent] HTTPエラー: ${response.statusCode}');
          debugPrint('📝 [getcontent] レスポンス: ${response.body}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('📝 [getcontent] 例外: $e');
        debugPrint('📝 [getcontent] スタックトレース: $stackTrace');
      }
    }

    return null;
  }
}
