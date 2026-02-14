import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
        return null;
      }

      final primaryUrl = '${AppConfig.postApiBaseUrl}/content/add';
      final fallbackUrl = '${AppConfig.backendUrl}/content/add';

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
        if (responseData['status'] == 'success') {
          return responseData['data'];
        }
      }
    } catch (e) {
      // ignore
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
      // ignore
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

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'contentID': int.tryParse(postId) ?? 0}),
      );

      return response.statusCode == 200;
    } catch (e) {
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

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'contentID': int.tryParse(postId) ?? 0}),
      );

      if (response.statusCode == 200) {
        await PlaylistService.removeContentFromSpotlightPlaylist(postId);
        return true;
      }
      return false;
    } catch (e) {
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
        return false;
      }

      final contentIdInt = int.tryParse(contentId);
      if (contentIdInt == null || contentIdInt == 0) {
        return false;
      }

      final hasTitle = title != null;
      final hasTag = tag != null;
      if (!hasTitle && !hasTag) {
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

      final response = await http.patch(
        Uri.parse(primaryUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 404) {
        final retryPatch = await http.patch(
          Uri.parse(fallbackUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwtToken',
          },
          body: jsonEncode(requestBody),
        );

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
      return false;
    }
  }

  /// 視聴履歴を記録する
  static Future<bool> recordPlayHistory(String contentId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/content/playnum';
      final contentIdInt = int.tryParse(contentId) ?? 0;

      if (contentIdInt == 0) {
        return false;
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
          return http.Response('', 408);
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          // 視聴履歴を記録したcontentIDをキャッシュに保存（最新の視聴履歴を確実に取得するため）
          _addRecentlyRecordedContentId(contentId);

          return true;
        }
      }
    } catch (e) {
      // ignore
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
    } catch (e) {
      // ignore
    }

    int attemptCount = 0;
    final int maxAttempts = limit * 5; // 最大試行回数（除外があるため多めに設定）

    while (posts.length < limit && attemptCount < maxAttempts) {
      attemptCount++;

      final post = await fetchRandomPost();

      if (post != null &&
          !fetchedIds.contains(post.id) &&
          !recentPlayHistoryIds.contains(post.id)) {
        // 重複しておらず、直近視聴5件にも含まれていない場合のみ追加
        posts.add(post);
        fetchedIds.add(post.id);
      }

      // 少し待機してから次のリクエストを送信（サーバー負荷軽減）
      if (posts.length < limit && attemptCount < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 100));
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
        return false;
      }

      // API仕様書（API_ENDPOINTS.md 498-507行目）に基づく
      // POST /api/delete/content
      final url = '${AppConfig.apiBaseUrl}/delete/content';
      final contentIdInt = int.tryParse(contentId);

      if (contentIdInt == null || contentIdInt == 0) {
        return false;
      }

      // API仕様書に基づき、キー名はcontentID（大文字のID）
      final requestBody = {
        'contentID': contentIdInt,
      };

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
          throw TimeoutException('投稿削除のリクエストがタイムアウトしました');
        },
      );

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (responseData['status'] == 'success') {
            return true;
          } else {
            return false;
          }
        } catch (e) {
          return false;
        }
      } else if (response.statusCode == 404) {
        return false;
      } else {
        return false;
      }
    } catch (e, stackTrace) {
      // ignore
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
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/users/getplayhistory';

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
        return [];
      }

      final responseData = jsonDecode(response.body);

      if (responseData['status'] != 'success') {
        return [];
      }

      if (responseData['data'] == null) {
        return [];
      }

      final List<dynamic> historyJson = responseData['data'] as List;

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

      for (int index = 0; index < historyJson.length; index++) {
        final item = historyJson[index];
        if (item is! Map<String, dynamic>) {
          continue;
        }

        // contentID を取得（大文字小文字を考慮）
        final contentId = item['contentID']?.toString() ??
            item['contentid']?.toString() ??
            item['contentId']?.toString() ??
            '';

        if (contentId.isEmpty) {
          continue;
        }

        // 重複を排除（最初に見つかったものを残す = 最新の視聴履歴）
        // バックエンドは既に playID DESC でソート済みなので、最初に見つかったものが最新
        if (!contentIdToFirstIndex.containsKey(contentId)) {
          contentIdToFirstIndex[contentId] = index;
          orderedContentIds.add(contentId);
          // バックエンドから返されるデータの情報を保持（title, posttimestamp等）
          contentIdToHistoryData[contentId] = Map<String, dynamic>.from(item);
        }
      }

      // 順序を保持したまま重複排除されたリスト
      final uniqueContentIds = orderedContentIds;

      // ステップ3: コスト削減のため30件までに制限（50件→30件）
      final limitedContentIds = uniqueContentIds.take(30).toList();

      // ステップ4: バックエンドから返されたデータでPostオブジェクトを作成
      final Map<String, Post> contentMap = {};

      if (limitedContentIds.isNotEmpty) {
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
                final post =
                    Post.fromJson(mergedData, backendUrl: AppConfig.backendUrl);
                contentMap[contentId] = post;
              } catch (e, stackTrace) {
                // ignore
              }
            }
          } catch (e) {
            // ignore
          }
        }
      }

      // ステップ5: 視聴履歴の順序を保持しながら Post オブジェクトのリストを作成
      List<Post> posts = [];
      for (final contentId in limitedContentIds) {
        final post = contentMap[contentId];

        if (post != null) {
          posts.add(post);
        }
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
      return [];
    }
  }

  /// 自分自身のアカウントから投稿されたコンテンツ一覧を取得
  static Future<List<Post>> getUserContents() async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/users/getusercontents';

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

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> postsJson = responseData['data'];

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
              // ignore
            }
          }

          return posts;
        }
      }
    } catch (e) {
      // ignore
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
        return false;
      }

      // API仕様書（API_ENDPOINTS.md 430-439行目）に基づく
      // POST /api/delete/playhistory
      final url = '${AppConfig.apiBaseUrl}/delete/playhistory';

      if (playId == null || playId == 0) {
        return false;
      }

      final requestBody = {
        'playID': playId,
      };

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
          throw TimeoutException('視聴履歴削除のリクエストがタイムアウトしました');
        },
      );

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (responseData['status'] == 'success') {
            return true;
          } else {
            return false;
          }
        } catch (e) {
          return false;
        }
      } else if (response.statusCode == 404) {
        return false;
      } else {
        return false;
      }
    } catch (e, stackTrace) {
      // ignore
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
        throw Exception('JWTトークンが取得できません');
      }

      final primaryUrl = '${AppConfig.postApiBaseUrl}/content/add';
      final fallbackUrl = '${AppConfig.backendUrl}/content/add';

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

      if (type == 'text') {
        // テキスト投稿の場合
        if (text != null && text.isNotEmpty) {
          body['text'] = text;
        } else {
          throw Exception('テキスト投稿にはtextが必要です');
        }
      } else {
        // 非テキスト投稿の場合
        if (fileBase64 != null && thumbnailBase64 != null) {
          body['file'] = fileBase64;
          body['thumbnail'] = thumbnailBase64;
        } else {
          throw Exception('非テキスト投稿にはfileとthumbnailが必要です');
        }
      }

      final jsonBody = jsonEncode(body);
      final requestBodySize = jsonBody.length;

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

          throw Exception(errorMessage);
        }
      } finally {
        client.close();
      }
    } catch (e) {
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
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/users/getusercontents';

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

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> postsJson = responseData['data'];

          final posts = postsJson.map((json) {
            // contentIDをidとして設定
            final contentId = json['contentID']?.toString() ?? '';
            json['id'] = contentId;
            return Post.fromJson(json, backendUrl: AppConfig.backendUrl);
          }).toList();

          return posts;
        }
      }
    } catch (e) {
      // ignore
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
        return [];
      }

      // /api/content/getcontents/random - パラメータなしで5件のランダムデータを返す
      // excludeContentIDsパラメータを送信（APIが期待する形式）
      final url = '${AppConfig.apiBaseUrl}/content/getcontents/random';

      // 既に取得したコンテンツIDを除外するためのパラメータ
      final requestBody = <String, dynamic>{
        'excludeContentIDs': excludeContentIDs,
      };

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
          throw TimeoutException('コンテンツ取得のリクエストがタイムアウトしました');
        },
      );

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (responseData['status'] == 'success' &&
              responseData['data'] != null) {
            final List<dynamic> contentsJson = responseData['data'] as List;

            // データが空のリストの場合
            if (contentsJson.isEmpty) {
              return [];
            }

            // レスポンスデータをPostオブジェクトに変換
            final List<Post> posts = [];
            for (int i = 0; i < contentsJson.length; i++) {
              final contentJson = contentsJson[i] as Map<String, dynamic>;

              // contentIDがレスポンスに含まれていない場合の警告
              if (!contentJson.containsKey('contentID') &&
                  !contentJson.containsKey('contentid') &&
                  !contentJson.containsKey('id')) {
                // バックエンドの不具合のため、このコンテンツはスキップ
                continue;
              }

              // contentID/contentid/idのいずれかを使用
              final contentId = contentJson['contentID']?.toString() ??
                  contentJson['contentid']?.toString() ??
                  contentJson['id']?.toString() ??
                  '';

              if (contentId.isEmpty) {
                continue;
              }

              // idとして設定（Post.fromJsonで使用される）
              contentJson['id'] = contentId;
              contentJson['contentID'] = contentId; // 念のため両方設定

              // Post.fromJsonを使用してPostオブジェクトに変換
              try {
                final post = Post.fromJson(contentJson,
                    backendUrl: AppConfig.backendUrl);
                posts.add(post);
              } catch (e, stackTrace) {
                // ignore
              }
            }

            return posts;
          }
        } catch (e) {
          // ignore
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

        // 429エラー時は例外をスローして、呼び出し元で再試行できるようにする
        throw TooManyRequestsException(
            'リクエストが頻繁すぎます。${retryAfterSeconds}秒待ってから再度お試しください。',
            retryAfterSeconds);
      }
    } on TooManyRequestsException {
      // 429エラーは呼び出し元で再試行するため、そのまま再スロー
      rethrow;
    } on TimeoutException catch (e) {
      // ignore
    } on http.ClientException catch (e) {
      // ignore
    } on FormatException catch (e) {
      // ignore
    } catch (e, stackTrace) {
      // ignore
    }

    return [];
  }

  /// /api/content/getcontents/newest APIを使用して5件のコンテンツを取得（新しい順）
  /// 戻り値: 成功時はPostのリスト、失敗時は空のリスト
  static Future<List<Post>> fetchContentsNewest() async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/content/getcontents/newest';

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
          throw TimeoutException('コンテンツ取得のリクエストがタイムアウトしました');
        },
      );

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (responseData['status'] == 'success' &&
              responseData['data'] != null) {
            final List<dynamic> contentsJson = responseData['data'] as List;

            if (contentsJson.isEmpty) {
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
                // ignore
              }
            }

            return posts;
          }
        } catch (e) {
          // ignore
        }
      }
    } catch (e, stackTrace) {
      // ignore
    }

    return [];
  }

  /// /api/content/getcontents/oldest APIを使用して5件のコンテンツを取得（古い順）
  /// 戻り値: 成功時はPostのリスト、失敗時は空のリスト
  static Future<List<Post>> fetchContentsOldest() async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/content/getcontents/oldest';

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
          throw TimeoutException('コンテンツ取得のリクエストがタイムアウトしました');
        },
      );

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (responseData['status'] == 'success' &&
              responseData['data'] != null) {
            final List<dynamic> contentsJson = responseData['data'] as List;

            if (contentsJson.isEmpty) {
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
                // ignore
              }
            }

            return posts;
          }
        } catch (e) {
          // ignore
        }
      }
    } catch (e, stackTrace) {
      // ignore
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
        return null;
      }

      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        return null;
      }

      final url = '${AppConfig.apiBaseUrl}/content/detail';
      final requestBody = {
        'contentID': contentIdInt,
      };

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

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final dynamic data = responseData['data'];
          if (data is Map<String, dynamic>) {
            data['contentID'] = contentId;
            data['id'] = contentId;
            return Post.fromJson(data, backendUrl: AppConfig.backendUrl);
          }
        }
      }

      final posts = await fetchContents(excludeContentIDs: []);
      for (final post in posts) {
        if (post.id == contentId) {
          return post;
        }
      }

      return null;
    } catch (e, stackTrace) {
      // ignore
    }

    return null;
  }
}
