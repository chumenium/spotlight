import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../config/app_config.dart';
import '../models/post.dart';
import '../services/jwt_service.dart';
import '../services/playlist_service.dart';

/// 429 Too Many Requests エラー用の例外クラス
class TooManyRequestsException implements Exception {
  final String message;
  final int retryAfterSeconds;

  TooManyRequestsException(this.message, this.retryAfterSeconds);

  @override
  String toString() => message;
}

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
        // if (kDebugMode) {
        //   debugPrint('📝 JWTトークンが取得できません');
        // }
        return null;
      }
      if (kDebugMode) {
        debugPrint('📝 JWTトークン: $jwtToken');
      }

      final primaryUrl = '${AppConfig.postApiBaseUrl}/content/add';
      final fallbackUrl = '${AppConfig.backendUrl}/content/add';
      // if (kDebugMode) {
      //   debugPrint('📝 最小投稿URL: $url');ƒƒ
      // }

      final Map<String, dynamic> body = {
        'type': type,
        'title': title,
      };
      if (link != null && link.isNotEmpty) {
        body['link'] = link;
      }

      final response = await http.post(
        Uri.parse(primaryUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 403 || response.statusCode == 404) {
        final fallback = await http.post(
          Uri.parse(fallbackUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwtToken',
          },
          body: jsonEncode(body),
        );
        if (fallback.statusCode == 200) {
          final responseData = jsonDecode(fallback.body);
          if (responseData['status'] == 'success') {
            return responseData['data'];
          }
        }
      } else if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // if (kDebugMode) {
        //   debugPrint('📝 最小投稿レスポンス: ${responseData.toString()}');
        // }
        if (responseData['status'] == 'success') {
          return responseData['data'];
        }
      }
      // else {
      //   if (kDebugMode) {
      //     debugPrint('📝 最小投稿エラー: ${response.statusCode}');
      //   }
      // }
    } catch (e) {
      // if (kDebugMode) {
      //   debugPrint('📝 最小投稿例外: $e');
      // }
    }

    return null;
  }

  /// バックエンドから投稿一覧を取得（非推奨: コスト削減のためfetchContents()を使用してください）
  ///
  /// 注意: このメソッドは非効率です。代わりにfetchContents()、fetchContentsNewest()、fetchContentsOldest()を使用してください。
  /// contentID=1から昇順で取得します（最大試行回数を大幅に削減）
  static Future<List<Post>> fetchPosts({
    int limit = 20,
    int startId = 1,
  }) async {
    // コスト削減のため、一括取得APIを使用
    // startIdパラメータは無視され、ランダム取得として動作します
    // if (kDebugMode) {
    //   debugPrint('⚠️ [fetchPosts] 非推奨メソッドが呼び出されました。fetchContents()の使用を推奨します');
    // }

    // 一括取得APIを使用（コスト削減）
    return await fetchContents();
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
      // if (kDebugMode) {
      //   debugPrint('📝 スポットライト投稿取得例外: $e');
      // }
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

      // if (kDebugMode) {
      //   debugPrint('📝 スポットライトON URL: $url, contentID: $postId');
      // }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'contentID': int.tryParse(postId) ?? 0}),
      );

      // if (kDebugMode) {
      //   debugPrint('📝 スポットライトONレスポンス: ${response.statusCode}');
      // }

      return response.statusCode == 200;
    } catch (e) {
      // if (kDebugMode) {
      //   debugPrint('📝 スポットライトON例外: $e');
      // }
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

      // if (kDebugMode) {
      //   debugPrint('📝 スポットライトOFF URL: $url, contentID: $postId');
      // }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'contentID': int.tryParse(postId) ?? 0}),
      );

      // if (kDebugMode) {
      //   debugPrint('📝 スポットライトOFFレスポンス: ${response.statusCode}');
      // }

      if (response.statusCode == 200) {
        await PlaylistService.removeContentFromSpotlightPlaylist(postId);
        return true;
      }
      return false;
    } catch (e) {
      // if (kDebugMode) {
      //   debugPrint('📝 スポットライトOFF例外: $e');
      // }
      return false;
    }
  }

  /// 投稿のタイトル・タグを編集
  ///
  /// - contentID: 編集対象の投稿ID
  /// - title: 新しいタイトル（省略可）
  /// - tag: 新しいタグ（省略可、空文字で削除）
  static Future<bool> editContent({
    required String contentId,
    String? title,
    String? tag,
  }) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📝 [投稿編集] JWTトークンが取得できません');
        }
        return false;
      }

      final contentIdInt = int.tryParse(contentId);
      if (contentIdInt == null || contentIdInt == 0) {
        if (kDebugMode) {
          debugPrint('📝 [投稿編集] contentIDが無効です: $contentId');
        }
        return false;
      }

      final hasTitle = title != null;
      final hasTag = tag != null;
      if (!hasTitle && !hasTag) {
        if (kDebugMode) {
          debugPrint('📝 [投稿編集] title または tag が必要です');
        }
        return false;
      }

      final primaryUrl = '${AppConfig.apiBaseUrl}/content/edit';
      final fallbackUrl = '${AppConfig.backendUrl}/content/edit';
      final requestBody = <String, dynamic>{
        'contentID': contentIdInt,
      };
      if (hasTitle) {
        requestBody['title'] = title;
      }
      if (hasTag) {
        requestBody['tag'] = tag;
      }

      if (kDebugMode) {
        debugPrint('📝 [投稿編集] URL: $primaryUrl');
        debugPrint('📝 [投稿編集] body: ${jsonEncode(requestBody)}');
      }

      final response = await http.patch(
        Uri.parse(primaryUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(requestBody),
      );

      if (kDebugMode) {
        debugPrint('📝 [投稿編集] statusCode: ${response.statusCode}');
        debugPrint('📝 [投稿編集] body: ${response.body}');
      }

      if (response.statusCode == 404) {
        final retryPatch = await http.patch(
          Uri.parse(fallbackUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwtToken',
          },
          body: jsonEncode(requestBody),
        );

        if (kDebugMode) {
          debugPrint('📝 [投稿編集] PATCH fallback URL: $fallbackUrl');
          debugPrint(
              '📝 [投稿編集] PATCH fallback statusCode: ${retryPatch.statusCode}');
          debugPrint('📝 [投稿編集] PATCH fallback body: ${retryPatch.body}');
        }

        if (retryPatch.statusCode == 200) {
          final responseData = jsonDecode(retryPatch.body);
          return responseData['status'] == 'success';
        }

        final fallback = await http.put(
          Uri.parse(primaryUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwtToken',
          },
          body: jsonEncode(requestBody),
        );

        if (kDebugMode) {
          debugPrint('📝 [投稿編集] PUT statusCode: ${fallback.statusCode}');
          debugPrint('📝 [投稿編集] PUT body: ${fallback.body}');
        }

        if (fallback.statusCode == 200) {
          final responseData = jsonDecode(fallback.body);
          return responseData['status'] == 'success';
        }

        final fallbackPut = await http.put(
          Uri.parse(fallbackUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwtToken',
          },
          body: jsonEncode(requestBody),
        );

        if (kDebugMode) {
          debugPrint('📝 [投稿編集] PUT fallback URL: $fallbackUrl');
          debugPrint(
              '📝 [投稿編集] PUT fallback statusCode: ${fallbackPut.statusCode}');
          debugPrint('📝 [投稿編集] PUT fallback body: ${fallbackPut.body}');
        }

        if (fallbackPut.statusCode == 200) {
          final responseData = jsonDecode(fallbackPut.body);
          return responseData['status'] == 'success';
        }
      } else if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['status'] == 'success';
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 [投稿編集] 例外: $e');
      }
      return false;
    }
  }

  /// 視聴履歴を記録する
  static Future<bool> recordPlayHistory(String contentId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        // if (kDebugMode) {
        //   debugPrint('📝 [視聴履歴記録] JWTトークンが取得できません: contentID=$contentId');
        // }
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/content/playnum';
      final contentIdInt = int.tryParse(contentId) ?? 0;

      if (contentIdInt == 0) {
        // if (kDebugMode) {
        //   debugPrint('📝 [視聴履歴記録] 無効なcontentID: $contentId');
        // }
        return false;
      }

      // if (kDebugMode) {
      //   debugPrint('📝 [視聴履歴記録] 記録開始: contentID=$contentId');
      // }

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
          // if (kDebugMode) {
          //   debugPrint('📝 [視聴履歴記録] タイムアウト: contentID=$contentId');
          // }
          return http.Response('', 408);
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          // 視聴履歴を記録したcontentIDをキャッシュに保存（最新の視聴履歴を確実に取得するため）
          _addRecentlyRecordedContentId(contentId);

          // if (kDebugMode) {
          //   debugPrint('📝 [視聴履歴記録] 記録成功: contentID=$contentId');
          // }

          return true;
        }
        // else {
        //   if (kDebugMode) {
        //     debugPrint(
        //         '📝 [視聴履歴記録] APIレスポンスエラー: contentID=$contentId, status=${responseData['status']}');
        //   }
        // }
      }
      // else {
      //   if (kDebugMode) {
      //     debugPrint(
      //         '📝 [視聴履歴記録] HTTPエラー: contentID=$contentId, statusCode=${response.statusCode}');
      //     debugPrint('📝 [視聴履歴記録] レスポンス: ${response.body}');
      //   }
      // }
    } catch (e) {
      // if (kDebugMode) {
      //   debugPrint('📝 [視聴履歴記録] 例外: contentID=$contentId, error=$e');
      //   debugPrint('📝 [視聴履歴記録] スタックトレース: $e');
      // }
    }

    return false;
  }

  /// 投稿詳細を取得（視聴履歴を記録しない）
  /// 視聴履歴を記録せずに投稿詳細を取得する場合に使用
  static Future<Post?> fetchPostDetailWithoutRecording(String contentId) async {
    // /api/content/getcontent を使用して1件のコンテンツを取得
    return _fetchPostDetailInternal(contentId, recordHistory: false);
  }

  /// 投稿詳細を取得（視聴履歴を記録しない）
  /// 注意: このメソッドは視聴履歴を記録しません。視聴履歴を記録するには recordPlayHistory() を使用してください。
  static Future<Post?> fetchPostDetail(String contentId) async {
    // /api/content/getcontent を使用して1件のコンテンツを取得
    return _fetchPostDetailInternal(contentId, recordHistory: false);
  }

  /// ランダムな投稿を取得
  /// /api/content/getcontents APIで取得した候補から1件を返す
  /// 戻り値: 成功時はPost、失敗時はnull
  static Future<Post?> fetchRandomPost() async {
    try {
      final posts = await fetchContents();
      if (posts.isEmpty) {
        return null;
      }
      // バックエンド側でランダム5件を返しているため、ここではそのうち先頭1件を利用
      return posts.first;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 [ランダム取得] 例外: error=$e');
      }
      return null;
    }
  }

  /// 投稿詳細を取得（内部実装）
  static Future<Post?> _fetchPostDetailInternal(String contentId,
      {required bool recordHistory}) async {
    // 現在は recordHistory フラグは使用せず、/api/content/getcontent を叩く fetchContentById に委譲
    return fetchContentById(contentId);
  }

  /// 複数のランダムな投稿を取得
  /// /api/content/getcontents APIで取得した候補をもとにランダム取得
  /// 戻り値: 成功時はPostのリスト、失敗時は空のリスト
  /// - limit: 取得する件数（デフォルト: 5件）
  /// 注意: 直近で視聴した5件は除外されます
  static Future<List<Post>> fetchRandomPosts({int limit = 5}) async {
    final List<Post> posts = [];
    final Set<String> fetchedIds = {}; // 重複を避けるため

    // 直近で視聴した50件のIDを取得（ランダム選択から除外するため）
    // 【重要】直近表示コンテンツが再選択されるのを防ぐため、除外範囲を拡大
    final Set<String> recentPlayHistoryIds = {};
    try {
      final playHistory = await getPlayHistory();
      // 直近50件のIDを取得（視聴履歴は既に最新順でソート済み）
      final recentHistory = playHistory.take(50).toList();
      for (final historyPost in recentHistory) {
        recentPlayHistoryIds.add(historyPost.id);
      }

      // if (kDebugMode) {
      //   debugPrint('🎲 [ランダム取得複数] 直近視聴50件を除外: ${recentPlayHistoryIds.length}件');
      // }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ランダム取得複数] 視聴履歴取得エラー（除外なしで続行）: $e');
      }
    }

    if (kDebugMode) {
      debugPrint(
          '🎲 [ランダム取得複数] 取得開始: limit=$limit, 除外ID数=${recentPlayHistoryIds.length}');
    }

    int attemptCount = 0;
    final int maxAttempts = limit * 5; // 最大試行回数（除外があるため多めに設定）

    while (posts.length < limit && attemptCount < maxAttempts) {
      attemptCount++;

      if (kDebugMode) {
        debugPrint(
            '🎲 [ランダム取得複数] 試行$attemptCount: 現在の取得数=${posts.length}/$limit');
      }

      final post = await fetchRandomPost();

      if (post != null &&
          !fetchedIds.contains(post.id) &&
          !recentPlayHistoryIds.contains(post.id)) {
        // 重複しておらず、直近視聴5件にも含まれていない場合のみ追加
        posts.add(post);
        fetchedIds.add(post.id);

        if (kDebugMode) {
          debugPrint(
              '🎲 [ランダム取得複数] 取得成功: contentID=${post.id}, タイトル=${post.title}');
        }
      } else if (post != null) {
        if (kDebugMode) {
          if (fetchedIds.contains(post.id)) {
            debugPrint('🎲 [ランダム取得複数] 重複スキップ: contentID=${post.id}');
          } else if (recentPlayHistoryIds.contains(post.id)) {
            debugPrint('🎲 [ランダム取得複数] 直近視聴50件のため除外: contentID=${post.id}');
          }
        }
      }

      // 少し待機してから次のリクエストを送信（サーバー負荷軽減）
      if (posts.length < limit && attemptCount < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (kDebugMode) {
      debugPrint('🎲 [ランダム取得複数] 取得完了: ${posts.length}件（試行回数: $attemptCount）');
      if (posts.length < limit) {
        debugPrint('⚠️ [ランダム取得複数] 要求件数に達しませんでした（除外IDの影響の可能性）');
      }
    }

    return posts;
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
  /// 4. 各 contentID に対応する履歴データを使って完全なコンテンツ情報を構築
  ///    （username, iconimgpath, contentpath, textflag, spotlightflag などを使用）
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

      if (responseData['status'] != 'success') {
        if (kDebugMode) {
          debugPrint('❌ [視聴履歴] APIレスポンスエラー: status=${responseData['status']}');
          debugPrint('❌ [視聴履歴] レスポンスデータ: ${responseData.toString()}');
        }
        return [];
      }

      if (responseData['data'] == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [視聴履歴] APIレスポンスのdataがnullです');
          debugPrint('⚠️ [視聴履歴] レスポンスデータ: ${responseData.toString()}');
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

      // ステップ3: コスト削減のため30件までに制限（50件→30件）
      final limitedContentIds = uniqueContentIds.take(30).toList();

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴] 制限後: ${limitedContentIds.length}件');
      }

      // ステップ4: バックエンドから返されたデータでPostオブジェクトを作成
      final Map<String, Post> contentMap = {};

      if (limitedContentIds.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('📝 [視聴履歴] バックエンドから返されたデータでPostオブジェクトを作成');
        }

        for (final contentId in limitedContentIds) {
          try {
            final historyData = contentIdToHistoryData[contentId];
            if (historyData != null) {
              // バックエンドから返されたデータにcontentIDを追加
              final mergedData = Map<String, dynamic>.from(historyData);
              mergedData['contentID'] = contentId;
              final playIdValue = mergedData['playID'] ??
                  mergedData['playId'] ??
                  mergedData['playid'];
              if (playIdValue != null) {
                mergedData['playID'] = playIdValue;
              }

              // Postオブジェクトに変換
              try {
                if (kDebugMode) {
                  debugPrint('📝 [視聴履歴] Post変換開始: contentID=$contentId');
                  debugPrint(
                      '📝 [視聴履歴] mergedDataのキー: ${mergedData.keys.toList()}');
                }
                final post =
                    Post.fromJson(mergedData, backendUrl: AppConfig.backendUrl);
                contentMap[contentId] = post;
                if (kDebugMode) {
                  debugPrint(
                      '✅ [視聴履歴] Post変換成功: contentID=$contentId, title=${post.title}, username=${post.username}');
                }
              } catch (e, stackTrace) {
                if (kDebugMode) {
                  debugPrint(
                      '❌ [視聴履歴] Post変換エラー: contentID=$contentId, error=$e');
                  debugPrint('❌ [視聴履歴] スタックトレース: $stackTrace');
                  debugPrint('❌ [視聴履歴] mergedData: $mergedData');
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ [視聴履歴] 処理エラー: contentID=$contentId, error=$e');
            }
          }
        }

        if (kDebugMode) {
          debugPrint(
              '📝 [視聴履歴] コンテンツ情報取得完了: ${contentMap.length}件 / ${limitedContentIds.length}件');
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

          // バックエンドから返されたデータでPostオブジェクトを作成
          final List<Post> posts = [];

          for (final json in postsJson) {
            final contentId = json['contentID']?.toString() ?? '';
            if (contentId.isEmpty) continue;

            try {
              // contentIDをidとして設定
              final postData = Map<String, dynamic>.from(json);
              postData['id'] = contentId;

              final post =
                  Post.fromJson(postData, backendUrl: AppConfig.backendUrl);
              posts.add(post);
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                    '⚠️ [自分の投稿] Post変換エラー: contentID=$contentId, error=$e');
              }
            }
          }

          return posts;
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
  /// - playID: 削除する視聴履歴のID
  static Future<bool> deletePlayHistory({required int? playId}) async {
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
      final url = '${AppConfig.apiBaseUrl}/delete/playhistory';

      if (playId == null || playId == 0) {
        if (kDebugMode) {
          debugPrint('❌ [視聴履歴削除] playIDが取得できません');
        }
        return false;
      }

      final requestBody = {
        'playID': playId,
      };

      if (kDebugMode) {
        debugPrint('📝 [視聴履歴削除] ========== API呼び出し ==========');
        debugPrint('📝 [視聴履歴削除] URL: $url');
        debugPrint('📝 [視聴履歴削除] リクエストボディ: ${jsonEncode(requestBody)}');
        debugPrint('📝 [視聴履歴削除] playID: $playId');
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
    String? orientation,
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
      if (kDebugMode) {
        debugPrint('📝 JWTトークン: $jwtToken');
      }

      final primaryUrl = '${AppConfig.postApiBaseUrl}/content/add';
      final fallbackUrl = '${AppConfig.backendUrl}/content/add';

      if (kDebugMode) {
        debugPrint('📝 投稿作成URL: $primaryUrl');
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

      if (orientation != null && orientation.trim().isNotEmpty) {
        body['orientation'] = orientation.trim();
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
        var response = await client
            .post(
          Uri.parse(primaryUrl),
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

        if (response.statusCode == 403 || response.statusCode == 404) {
          response = await client
              .post(
            Uri.parse(fallbackUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwtToken',
            },
            body: jsonBody,
          )
              .timeout(
            const Duration(minutes: 30),
            onTimeout: () {
              throw TimeoutException(
                'リクエストがタイムアウトしました（30分）',
                const Duration(minutes: 30),
              );
            },
          );
        }

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

  /// /api/content/getcontents APIを使用して5件のランダムコンテンツを取得
  /// パラメータなしでリクエストしてランダムで5件のデータを返す
  /// [excludeContentIDs] 除外するコンテンツIDのリスト（オプション）
  /// 戻り値: 成功時はPostのリスト、失敗時は空のリスト
  static Future<List<Post>> fetchContents(
      {List<String> excludeContentIDs = const []}) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ [getcontents] JWTトークンが取得できません');
          debugPrint('❌ [getcontents] 認証が必要です。ログインしてください。');
        }
        return [];
      }

      // /api/content/getcontents/random - パラメータなしで5件のランダムデータを返す
      // excludeContentIDsパラメータを送信（APIが期待する形式）
      final url = '${AppConfig.apiBaseUrl}/content/getcontents/random';

      // 既に取得したコンテンツIDを除外するためのパラメータ
      final requestBody = <String, dynamic>{
        'excludeContentIDs': excludeContentIDs,
      };

      if (kDebugMode) {
        debugPrint('📝 [getcontents] API呼び出し開始: $url');
        debugPrint('📝 [getcontents] JWTトークン: ${jwtToken.substring(0, 20)}...');
        debugPrint('📝 [getcontents] リクエストボディ: $requestBody');
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
            debugPrint('❌ [getcontents] タイムアウト: 30秒以内にレスポンスがありませんでした');
            debugPrint('❌ [getcontents] URL: $url');
          }
          throw TimeoutException('コンテンツ取得のリクエストがタイムアウトしました');
        },
      );

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (kDebugMode) {
            debugPrint('📝 [getcontents] レスポンス受信: statusCode=200');
            debugPrint(
                '📝 [getcontents] レスポンスステータス: ${responseData['status']}');
          }

          if (responseData['status'] == 'success' &&
              responseData['data'] != null) {
            final List<dynamic> contentsJson = responseData['data'] as List;

            if (kDebugMode) {
              debugPrint('📝 [getcontents] 取得件数: ${contentsJson.length}件');
            }

            // データが空のリストの場合
            if (contentsJson.isEmpty) {
              if (kDebugMode) {
                debugPrint('⚠️ [getcontents] レスポンスデータが空です');
              }
              return [];
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

                final post = Post.fromJson(contentJson,
                    backendUrl: AppConfig.backendUrl);

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
              if (posts.isEmpty) {
                debugPrint('⚠️ [getcontents] 変換後の投稿が0件です。データ変換エラーの可能性があります。');
              }
            }

            return posts;
          } else {
            if (kDebugMode) {
              debugPrint('❌ [getcontents] APIレスポンスエラー:');
              debugPrint('   - status: ${responseData['status']}');
              debugPrint(
                  '   - message: ${responseData['message'] ?? responseData['error'] ?? 'なし'}');
              debugPrint('   - data: ${responseData['data']}');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [getcontents] レスポンスJSON解析エラー: $e');
            debugPrint('❌ [getcontents] レスポンスボディ: ${response.body}');
          }
        }
      } else if (response.statusCode == 429) {
        // 429 Too Many Requests - レート制限エラー
        // レスポンスから待機時間を取得（Retry-Afterヘッダーがある場合）
        int retryAfterSeconds = 2; // デフォルトは2秒
        final retryAfterHeader = response.headers['retry-after'];
        if (retryAfterHeader != null) {
          try {
            retryAfterSeconds = int.parse(retryAfterHeader);
          } catch (e) {
            // パースエラー時はデフォルト値を使用
          }
        }

        if (kDebugMode) {
          debugPrint('⚠️ [getcontents] レート制限エラー (429):');
          debugPrint('   - メッセージ: リクエストが頻繁すぎます。しばらく待ってから再度お試しください。');
          debugPrint('   - 待機時間: ${retryAfterSeconds}秒');
        }

        // 429エラー時は例外をスローして、呼び出し元で再試行できるようにする
        throw TooManyRequestsException(
            'リクエストが頻繁すぎます。${retryAfterSeconds}秒待ってから再度お試しください。',
            retryAfterSeconds);
      } else {
        if (kDebugMode) {
          debugPrint('❌ [getcontents] HTTPエラー:');
          debugPrint('   - ステータスコード: ${response.statusCode}');
          debugPrint('   - レスポンス: ${response.body}');
        }

        // 401 Unauthorizedの場合は認証エラー
        if (response.statusCode == 401) {
          if (kDebugMode) {
            debugPrint('❌ [getcontents] 認証エラー: JWTトークンが無効です');
          }
        }
        // 500 Internal Server Errorの場合はサーバーエラー
        else if (response.statusCode >= 500) {
          if (kDebugMode) {
            debugPrint('❌ [getcontents] サーバーエラー: バックエンドサーバーでエラーが発生しています');
          }
        }
      }
    } on TooManyRequestsException {
      // 429エラーは呼び出し元で再試行するため、そのまま再スロー
      rethrow;
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [getcontents] タイムアウトエラー: $e');
        debugPrint('❌ [getcontents] ネットワーク接続がタイムアウトしました');
      }
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [getcontents] ネットワーク接続エラー: $e');
        debugPrint('❌ [getcontents] インターネット接続を確認してください');
        debugPrint(
            '❌ [getcontents] URL: ${AppConfig.apiBaseUrl}/content/getcontents');
        debugPrint('❌ [getcontents] 考えられる原因:');
        debugPrint('   1. インターネット接続の問題');
        debugPrint('   2. CORS設定の問題（Webブラウザの場合）');
        debugPrint('   3. サーバーがダウンしている');
        debugPrint('   4. ファイアウォールまたはプロキシの設定');
      }
    } on FormatException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [getcontents] データ形式エラー: $e');
        debugPrint('❌ [getcontents] サーバーからのレスポンス形式が正しくありません');
        debugPrint('❌ [getcontents] エラーメッセージ: ${e.message}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [getcontents] 予期しないエラー: $e');
        debugPrint('❌ [getcontents] エラータイプ: ${e.runtimeType}');
        debugPrint('❌ [getcontents] スタックトレース: $stackTrace');
      }
    }

    return [];
  }

  /// /api/content/getcontents/newest APIを使用して5件のコンテンツを取得（新しい順）
  /// 戻り値: 成功時はPostのリスト、失敗時は空のリスト
  static Future<List<Post>> fetchContentsNewest() async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ [getcontents/newest] JWTトークンが取得できません');
          debugPrint('❌ [getcontents/newest] 認証が必要です。ログインしてください。');
        }
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/content/getcontents/newest';

      if (kDebugMode) {
        debugPrint('📝 [getcontents/newest] API呼び出し開始: $url');
        debugPrint(
            '📝 [getcontents/newest] JWTトークン: ${jwtToken.substring(0, 20)}...');
      }

      final response = await http
          .post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({}),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('❌ [getcontents/newest] タイムアウト: 30秒以内にレスポンスがありませんでした');
            debugPrint('❌ [getcontents/newest] URL: $url');
          }
          throw TimeoutException('コンテンツ取得のリクエストがタイムアウトしました');
        },
      );

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (kDebugMode) {
            debugPrint('📝 [getcontents/newest] レスポンス受信: statusCode=200');
            debugPrint(
                '📝 [getcontents/newest] レスポンスステータス: ${responseData['status']}');
          }

          if (responseData['status'] == 'success' &&
              responseData['data'] != null) {
            final List<dynamic> contentsJson = responseData['data'] as List;

            if (kDebugMode) {
              debugPrint(
                  '📝 [getcontents/newest] 取得件数: ${contentsJson.length}件');
            }

            if (contentsJson.isEmpty) {
              if (kDebugMode) {
                debugPrint('⚠️ [getcontents/newest] レスポンスデータが空です');
              }
              return [];
            }

            final List<Post> posts = [];
            for (int i = 0; i < contentsJson.length; i++) {
              final contentJson = contentsJson[i] as Map<String, dynamic>;

              final contentId = contentJson['contentID']?.toString() ??
                  contentJson['contentid']?.toString() ??
                  contentJson['id']?.toString() ??
                  '';

              if (contentId.isEmpty) {
                continue;
              }

              contentJson['id'] = contentId;
              contentJson['contentID'] = contentId;

              try {
                final post = Post.fromJson(contentJson,
                    backendUrl: AppConfig.backendUrl);
                posts.add(post);
              } catch (e) {
                if (kDebugMode) {
                  debugPrint(
                      '⚠️ [getcontents/newest] Post変換エラー: $e, インデックス $i');
                }
              }
            }

            if (kDebugMode) {
              debugPrint('📝 [getcontents/newest] 変換完了: ${posts.length}件');
            }

            return posts;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [getcontents/newest] レスポンスJSON解析エラー: $e');
            debugPrint('❌ [getcontents/newest] レスポンスボディ: ${response.body}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ [getcontents/newest] HTTPエラー: ${response.statusCode}');
          debugPrint('❌ [getcontents/newest] レスポンス: ${response.body}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [getcontents/newest] 予期しないエラー: $e');
        debugPrint('❌ [getcontents/newest] スタックトレース: $stackTrace');
      }
    }

    return [];
  }

  /// /api/content/getcontents/oldest APIを使用して5件のコンテンツを取得（古い順）
  /// 戻り値: 成功時はPostのリスト、失敗時は空のリスト
  static Future<List<Post>> fetchContentsOldest() async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ [getcontents/oldest] JWTトークンが取得できません');
          debugPrint('❌ [getcontents/oldest] 認証が必要です。ログインしてください。');
        }
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/content/getcontents/oldest';

      if (kDebugMode) {
        debugPrint('📝 [getcontents/oldest] API呼び出し開始: $url');
        debugPrint(
            '📝 [getcontents/oldest] JWTトークン: ${jwtToken.substring(0, 20)}...');
      }

      final response = await http
          .post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({}),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('❌ [getcontents/oldest] タイムアウト: 30秒以内にレスポンスがありませんでした');
            debugPrint('❌ [getcontents/oldest] URL: $url');
          }
          throw TimeoutException('コンテンツ取得のリクエストがタイムアウトしました');
        },
      );

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (kDebugMode) {
            debugPrint('📝 [getcontents/oldest] レスポンス受信: statusCode=200');
            debugPrint(
                '📝 [getcontents/oldest] レスポンスステータス: ${responseData['status']}');
          }

          if (responseData['status'] == 'success' &&
              responseData['data'] != null) {
            final List<dynamic> contentsJson = responseData['data'] as List;

            if (kDebugMode) {
              debugPrint(
                  '📝 [getcontents/oldest] 取得件数: ${contentsJson.length}件');
            }

            if (contentsJson.isEmpty) {
              if (kDebugMode) {
                debugPrint('⚠️ [getcontents/oldest] レスポンスデータが空です');
              }
              return [];
            }

            final List<Post> posts = [];
            for (int i = 0; i < contentsJson.length; i++) {
              final contentJson = contentsJson[i] as Map<String, dynamic>;

              final contentId = contentJson['contentID']?.toString() ??
                  contentJson['contentid']?.toString() ??
                  contentJson['id']?.toString() ??
                  '';

              if (contentId.isEmpty) {
                continue;
              }

              contentJson['id'] = contentId;
              contentJson['contentID'] = contentId;

              try {
                final post = Post.fromJson(contentJson,
                    backendUrl: AppConfig.backendUrl);
                posts.add(post);
              } catch (e) {
                if (kDebugMode) {
                  debugPrint(
                      '⚠️ [getcontents/oldest] Post変換エラー: $e, インデックス $i');
                }
              }
            }

            if (kDebugMode) {
              debugPrint('📝 [getcontents/oldest] 変換完了: ${posts.length}件');
            }

            return posts;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [getcontents/oldest] レスポンスJSON解析エラー: $e');
            debugPrint('❌ [getcontents/oldest] レスポンスボディ: ${response.body}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ [getcontents/oldest] HTTPエラー: ${response.statusCode}');
          debugPrint('❌ [getcontents/oldest] レスポンス: ${response.body}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [getcontents/oldest] 予期しないエラー: $e');
        debugPrint('❌ [getcontents/oldest] スタックトレース: $stackTrace');
      }
    }

    return [];
  }

  /// /api/content/getcontents/random から候補を取得して該当IDを探す
  /// 注意: ランダム取得のため見つからない可能性があります
  /// 戻り値: 成功時はPost、失敗時はnull
  static Future<Post?> fetchContentById(String contentId) async {
    try {
      final contentIdInt = int.tryParse(contentId) ?? 0;

      if (contentIdInt == 0) {
        if (kDebugMode) {
          debugPrint('📝 [getcontent] 無効なcontentID: $contentId');
        }
        return null;
      }

      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ [getcontent] JWTトークンが取得できません');
        }
        return null;
      }

      final url = '${AppConfig.apiBaseUrl}/content/detail';
      final requestBody = {
        'contentID': contentIdInt,
      };

      if (kDebugMode) {
        debugPrint('📝 [getcontent] API呼び出し開始: $url');
        debugPrint('📝 [getcontent] リクエストボディ: $requestBody');
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
          debugPrint('📝 [getcontent] レスポンス: $responseData');
        }

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final dynamic data = responseData['data'];
          if (data is Map<String, dynamic>) {
            data['contentID'] = contentId;
            data['id'] = contentId;
            return Post.fromJson(data, backendUrl: AppConfig.backendUrl);
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ [getcontent] HTTPエラー: ${response.statusCode}');
          debugPrint('❌ [getcontent] レスポンス: ${response.body}');
        }
      }

      if (kDebugMode) {
        debugPrint('⚠️ [getcontent] /getcontentで取得できなかったため、ランダム取得にフォールバックします');
      }

      final posts = await fetchContents(excludeContentIDs: []);
      for (final post in posts) {
        if (post.id == contentId) {
          return post;
        }
      }

      if (kDebugMode) {
        debugPrint('⚠️ [getcontent] 該当IDが見つかりません: contentID=$contentId');
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('📝 [getcontent] 例外: $e');
        debugPrint('📝 [getcontent] スタックトレース: $stackTrace');
      }
    }

    return null;
  }
}
