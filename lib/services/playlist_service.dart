import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../config/app_config.dart';
import '../services/jwt_service.dart';
import '../auth/auth_service.dart';

/// プレイリストモデル
class Playlist {
  final int playlistid;
  final String title;
  final String? thumbnailpath;
  final String? username;
  final String? iconimgpath;

  Playlist({
    required this.playlistid,
    required this.title,
    this.thumbnailpath,
    this.username,
    this.iconimgpath,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    // playlistidを取得（複数の可能性のあるキーを確認）
    final playlistIdValue = json['playlistid'] ??
        json['playlistID'] ??
        json['playlistId'] ??
        json['id'];

    final playlistId = playlistIdValue != null
        ? (int.tryParse(playlistIdValue.toString()) ?? 0)
        : 0;

    if (kDebugMode && playlistId == 0) {
      debugPrint('⚠️ [Playlist.fromJson] playlistidが0です');
      debugPrint('   - json keys: ${json.keys.toList()}');
      debugPrint('   - playlistid value: $playlistIdValue');
      debugPrint('   - json: ${json.toString()}');
    }

    return Playlist(
      playlistid: playlistId,
      title: json['title']?.toString() ?? '',
      thumbnailpath: json['thumbnailpath']?.toString(),
      username: json['username']?.toString(),
      iconimgpath: json['iconimgpath']?.toString(),
    );
  }
}

/// プレイリストAPIサービス
class PlaylistService {
  static const String spotlightPlaylistTitle = 'スポットライト';

  /// プレイリスト一覧を取得
  /// API仕様書（API_ENDPOINTS.md 126-133行目）に準拠
  /// - リクエスト: なし（リクエストボディ不要）
  /// - 認証: JWTトークン必須（ヘッダーに含める）
  /// - レスポンス: { "status": "success", "playlist": [...] }
  static Future<List<Playlist>> getPlaylists() async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📋 JWTトークンが取得できません');
        }
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/content/getplaylist';

      if (kDebugMode) {
        debugPrint('📋 プレイリスト取得URL: $url');
        debugPrint('📋 [プレイリスト取得] API仕様書に準拠: リクエストボディなし');
      }

      // API仕様書によると、リクエストボディは不要
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        // bodyパラメータを省略（リクエストボディなし）
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('📋 プレイリスト取得レスポンス: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success' &&
            responseData['playlist'] != null) {
          final List<dynamic> playlistsJson = responseData['playlist'];

          if (kDebugMode) {
            debugPrint('📋 [プレイリスト取得] 取得件数: ${playlistsJson.length}件');
            if (playlistsJson.isNotEmpty) {
              debugPrint('📋 [プレイリスト取得] 最初の項目: ${playlistsJson[0]}');
            }
          }

          final playlists = playlistsJson
              .map((playlistJson) =>
                  Playlist.fromJson(playlistJson as Map<String, dynamic>))
              .toList();

          if (kDebugMode) {
            debugPrint('📋 [プレイリスト取得] 変換完了: ${playlists.length}件（重複排除前）');
            for (int i = 0; i < playlists.length; i++) {
              final p = playlists[i];
              debugPrint(
                  '   [$i] playlistid=${p.playlistid}, title=${p.title}');
            }
          }

          // 同一playlistidで重複を排除（最新のものを残す）
          final Map<int, Playlist> uniquePlaylists = {};
          for (final playlist in playlists) {
            if (playlist.playlistid > 0) {
              // 既に存在する場合は、thumbnailpathが存在する方を優先
              if (!uniquePlaylists.containsKey(playlist.playlistid) ||
                  (playlist.thumbnailpath != null &&
                      playlist.thumbnailpath!.isNotEmpty &&
                      (uniquePlaylists[playlist.playlistid]?.thumbnailpath ==
                              null ||
                          uniquePlaylists[playlist.playlistid]!
                              .thumbnailpath!
                              .isEmpty))) {
                uniquePlaylists[playlist.playlistid] = playlist;
              }
            }
          }

          final uniquePlaylistsList = uniquePlaylists.values.toList();

          if (kDebugMode) {
            debugPrint(
                '📋 [プレイリスト取得] 重複排除完了: ${uniquePlaylistsList.length}件（重複排除後）');
            for (int i = 0; i < uniquePlaylistsList.length; i++) {
              final p = uniquePlaylistsList[i];
              debugPrint(
                  '   [$i] playlistid=${p.playlistid}, title=${p.title}');
            }
          }

          return uniquePlaylistsList;
        }
      } else {
        if (kDebugMode) {
          debugPrint('📋 プレイリスト取得エラー: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📋 プレイリスト取得例外: $e');
      }
    }

    return [];
  }

  /// スポットライト済みコンテンツ一覧を取得
  /// POST /api/users/getspotlightcontents
  static Future<List<Map<String, dynamic>>> getSpotlightContents() async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📋 [スポットライト一覧] JWTトークンが取得できません');
        }
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/users/getspotlightcontents';

      if (kDebugMode) {
        debugPrint('📋 [スポットライト一覧] URL: $url');
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
        if (responseData['status'] == 'success' &&
            responseData['data'] is List) {
          final List<dynamic> data = responseData['data'];
          return data
              .map((item) => item as Map<String, dynamic>)
              .toList();
        }
        if (kDebugMode) {
          debugPrint(
              '⚠️ [スポットライト一覧] status=${responseData['status']}');
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ [スポットライト一覧] HTTPエラー: ${response.statusCode}');
          debugPrint('📋 [スポットライト一覧] レスポンス: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [スポットライト一覧] 例外: $e');
      }
    }

    return [];
  }

  /// スポットライト再生リストに未登録のコンテンツを追加
  static Future<void> syncSpotlightPlaylist(int playlistId) async {
    try {
      final spotlightContents = await getSpotlightContents();
      final spotlightIds = <String>{};
      for (final item in spotlightContents) {
        final id = item['contentID']?.toString();
        if (id != null && id.isNotEmpty) {
          spotlightIds.add(id);
        }
      }

      final playlistContents = await getPlaylistDetail(playlistId);
      final playlistIds = <String>{};
      for (final item in playlistContents) {
        final id = item['contentID']?.toString();
        if (id != null && id.isNotEmpty) {
          playlistIds.add(id);
        }
      }

      for (final id in playlistIds) {
        if (!spotlightIds.contains(id)) {
          await removeContentFromPlaylist(playlistId, id);
        }
      }

      for (final id in spotlightIds) {
        if (!playlistIds.contains(id)) {
          await addContentToPlaylist(playlistId, id);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [スポットライト同期] 例外: $e');
      }
    }
  }

  static Future<bool> removeContentFromSpotlightPlaylist(
      String contentId) async {
    try {
      final playlists = await getPlaylists();
      final spotlight = playlists
          .where((p) => p.title == spotlightPlaylistTitle)
          .toList();
      if (spotlight.isEmpty) return false;
      return removeContentFromPlaylist(spotlight.first.playlistid, contentId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [スポットライト削除] 例外: $e');
      }
    }
    return false;
  }

  /// プレイリストにコンテンツを追加
  ///
  /// playlistdetailテーブルに以下の情報を追加:
  /// - userID: JWTトークンから取得（バックエンド側で処理）
  /// - playlistID: 指定されたプレイリストID
  /// - contentID: 指定されたコンテンツID
  ///
  /// 注意: バックエンドはJWTトークンからuserIDを取得してplaylistdetailテーブルに追加します
  static Future<bool> addContentToPlaylist(
      int playlistId, String contentId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📋 [プレイリスト追加] JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/content/addcontentplaylist';
      final contentIdInt = int.tryParse(contentId);

      if (contentIdInt == null || contentIdInt == 0) {
        if (kDebugMode) {
          debugPrint('❌ [プレイリスト追加] contentIDの解析に失敗しました');
          debugPrint('   - contentId (元の値): $contentId');
          debugPrint('   - contentIdInt: $contentIdInt');
        }
        return false;
      }

      if (playlistId <= 0) {
        if (kDebugMode) {
          debugPrint('❌ [プレイリスト追加] playlistIDが無効です: $playlistId');
        }
        return false;
      }

      // バックエンドの実装を確認:
      // バックエンドの実装（520-521行目）:
      //   playlistid = data.get("playlistID")
      //   contentid = data.get("contentID")
      // バックエンドは "playlistID" と "contentID"（大文字）を期待している
      final requestBody = {
        'playlistID': playlistId, // バックエンドは "playlistID"（大文字）を期待
        'contentID': contentIdInt, // バックエンドは "contentID"（大文字）を期待
      };

      if (kDebugMode) {
        debugPrint('📋 [プレイリスト追加] ========== API呼び出し ==========');
        debugPrint('📋 [プレイリスト追加] URL: $url');
        debugPrint('📋 [プレイリスト追加] リクエストボディ: ${jsonEncode(requestBody)}');
        debugPrint(
            '📋 [プレイリスト追加] 実際のplaylistid: $playlistId (type: ${playlistId.runtimeType})');
        debugPrint(
            '📋 [プレイリスト追加] 実際のcontentid: $contentIdInt (type: ${contentIdInt.runtimeType})');
        debugPrint(
            '📋 [プレイリスト追加] contentId (元の値): $contentId (type: ${contentId.runtimeType})');
        debugPrint('📋 [プレイリスト追加] userID: JWTトークンから取得（バックエンド側で処理）');
        debugPrint('📋 [プレイリスト追加] バックエンドは "playlistID" と "contentID"（大文字）を期待');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(requestBody),
      );

      if (kDebugMode) {
        debugPrint('📋 [プレイリスト追加] HTTPステータスコード: ${response.statusCode}');
        debugPrint('📋 [プレイリスト追加] レスポンスボディ: ${response.body}');
      }

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (kDebugMode) {
            debugPrint('📋 [プレイリスト追加] レスポンス（パース後）: ${responseData.toString()}');
            debugPrint('📋 [プレイリスト追加] status: ${responseData['status']}');
            debugPrint(
                '📋 [プレイリスト追加] message: ${responseData['message'] ?? 'なし'}');
          }

          if (responseData['status'] == 'success') {
            if (kDebugMode) {
              debugPrint('✅ [プレイリスト追加] 成功: playlistdetailテーブルに追加されました');
              debugPrint('   - userID: JWTトークンから取得（バックエンド側で処理）');
              debugPrint('   - playlistID: $playlistId');
              debugPrint('   - contentID: $contentIdInt');
            }
            return true;
          } else {
            if (kDebugMode) {
              debugPrint('❌ [プレイリスト追加] APIレスポンスエラー');
              debugPrint('   - status: ${responseData['status']}');
              debugPrint('   - message: ${responseData['message'] ?? 'なし'}');
              debugPrint('   - レスポンス全体: ${responseData.toString()}');
            }
            return false;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [プレイリスト追加] レスポンスのパースエラー: $e');
            debugPrint('📋 [プレイリスト追加] レスポンスボディ（生）: ${response.body}');
          }
          return false;
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ [プレイリスト追加] HTTPエラー: ${response.statusCode}');
          debugPrint('📋 [プレイリスト追加] レスポンス: ${response.body}');
        }
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [プレイリスト追加] 例外: $e');
        debugPrint('📋 [プレイリスト追加] スタックトレース: $stackTrace');
      }
    }

    return false;
  }

  /// プレイリストを作成
  static Future<int?> createPlaylist(String title) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📋 JWTトークンが取得できません');
        }
        return null;
      }

      final url = '${AppConfig.apiBaseUrl}/content/createplaylist';

      if (kDebugMode) {
        debugPrint('📋 プレイリスト作成URL: $url, title: $title');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'title': title}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('📋 [プレイリスト作成] レスポンス: ${responseData.toString()}');
          debugPrint('📋 [プレイリスト作成] レスポンスのキー: ${responseData.keys.toList()}');
        }

        if (responseData['status'] == 'success') {
          // プレイリストIDを取得（複数の可能性のあるキーを確認）
          final playlistId = responseData['playlistid'] ??
              responseData['playlistID'] ??
              responseData['playlistId'] ??
              responseData['id'];

          if (kDebugMode) {
            debugPrint('📋 [プレイリスト作成] 取得したplaylistid: $playlistId');
            debugPrint(
                '📋 [プレイリスト作成] playlistid type: ${playlistId.runtimeType}');
          }

          if (playlistId != null) {
            final playlistIdInt = int.tryParse(playlistId.toString());
            if (playlistIdInt != null && playlistIdInt > 0) {
              if (kDebugMode) {
                debugPrint('✅ [プレイリスト作成] 成功: playlistid=$playlistIdInt');
              }
              return playlistIdInt;
            } else {
              if (kDebugMode) {
                debugPrint('⚠️ [プレイリスト作成] playlistidが無効です: $playlistIdInt');
              }
            }
          } else {
            // playlistidがレスポンスに含まれていない場合でも、statusがsuccessなら作成は成功している
            // オートインクリメントで追加されるため、レスポンスに含まれなくても問題ない
            if (kDebugMode) {
              debugPrint(
                  '✅ [プレイリスト作成] 成功（playlistidはレスポンスに含まれていませんが、作成は成功しています）');
              debugPrint('   レスポンス全体: ${responseData.toString()}');
              debugPrint('   オートインクリメントで追加されるため、playlistidは後で取得できます');
            }
            // 成功を示す特殊な値（0）を返す（playlistidが取得できない場合）
            // 呼び出し側で、0の場合は成功として扱い、プレイリスト一覧を再取得するなどで対応
            return 0;
          }
        } else {
          if (kDebugMode) {
            debugPrint(
                '⚠️ [プレイリスト作成] APIレスポンスエラー: status=${responseData['status']}');
            debugPrint('   - message: ${responseData['message'] ?? 'なし'}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [プレイリスト作成] HTTPエラー: ${response.statusCode}');
          debugPrint('📋 [プレイリスト作成] レスポンス: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📋 プレイリスト作成例外: $e');
      }
    }

    return null;
  }

  /// JWTトークンのペイロードをデコード（デバッグ用）
  static Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }
      final payload = parts[1];
      // Base64URLデコード
      String normalized = base64.normalize(payload);
      // パディングを追加
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final decoded = utf8.decode(base64.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [プレイリスト詳細] JWTデコードエラー: $e');
      }
      return null;
    }
  }

  /// プレイリストの詳細（コンテンツ一覧）を取得
  /// API仕様書（API_ENDPOINTS.md 135-156行目）に完全準拠
  /// - リクエスト(JSON): playlistid: 数値
  /// - 認証: JWTトークン必須（ヘッダーに含める）
  /// - レスポンス: { "status": "success", "data": [...] }
  ///   - 各データ項目: contentID, title, spotlightnum, posttimestamp, playnum, link, thumbnailpath
  static Future<List<Map<String, dynamic>>> getPlaylistDetail(
      int playlistId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📋 [プレイリスト詳細] JWTトークンが取得できません');
        }
        return [];
      }

      // 現在のユーザーIDを取得（Firebase UID）
      final currentUserId = AuthService.getCurrentUserId();

      // JWTトークンのペイロードをデコード（デバッグ用）
      String? decodedUserId;
      if (kDebugMode) {
        final payload = _decodeJwtPayload(jwtToken);
        if (payload != null) {
          decodedUserId = payload['firebase_uid'] as String? ??
              payload['userID'] as String? ??
              payload['userId'] as String?;
          if (kDebugMode) {
            debugPrint('📋 [プレイリスト詳細] ========== JWTペイロード解析 ==========');
            debugPrint('   - firebase_uid: ${payload['firebase_uid']}');
            debugPrint('   - userID: ${payload['userID']}');
            debugPrint('   - userId: ${payload['userId']}');
            debugPrint('   - 全キー: ${payload.keys.toList()}');
            debugPrint('   - デコードされたuserID: $decodedUserId');
            debugPrint('   - 現在のFirebase UID: $currentUserId');
            debugPrint('   - 一致: ${decodedUserId == currentUserId}');
            debugPrint(
                '📋 [プレイリスト詳細] ===========================================');
          }
        } else {
          if (kDebugMode) {
            debugPrint('⚠️ [プレイリスト詳細] JWTペイロードのデコードに失敗しました');
          }
        }
      }

      final url = '${AppConfig.apiBaseUrl}/content/getplaylistdetail';

      // リクエストボディを作成
      // API仕様書（API_ENDPOINTS.md 135-156行目）に完全準拠
      // - リクエスト(JSON): playlistid: 数値
      // - バックエンドがJWTトークンからuserIDを取得することを期待している
      // - バックエンドの仕様を変えないように、playlistid（数値）のみを送信
      final requestBody = <String, dynamic>{
        'playlistid': playlistId, // 数値として送信（API仕様書通り）
      };

      // userIDはJWTトークンから取得することを期待しているため、リクエストボディには含めない
      // ただし、バックエンドが対応していない場合に備えて、デバッグ用にログに記録
      final userIdToSend = decodedUserId ?? currentUserId;

      if (kDebugMode) {
        debugPrint('📋 [プレイリスト詳細] ========== APIリクエスト ==========');
        debugPrint('📋 [プレイリスト詳細] URL: $url');
        debugPrint(
            '📋 [プレイリスト詳細] playlistid: $playlistId (型: ${playlistId.runtimeType})');
        debugPrint('📋 [プレイリスト詳細] リクエストボディ: ${jsonEncode(requestBody)}');
        debugPrint(
            '📋 [プレイリスト詳細] JWTトークン: ${jwtToken.substring(0, jwtToken.length > 50 ? 50 : jwtToken.length)}...');
        if (currentUserId != null) {
          debugPrint('📋 [プレイリスト詳細] 現在のFirebase UID: $currentUserId');
        }
        if (decodedUserId != null) {
          debugPrint('📋 [プレイリスト詳細] JWTから取得したuserID: $decodedUserId');
        }
        if (userIdToSend != null) {
          debugPrint('📋 [プレイリスト詳細] バックエンドがJWTから取得すべきuserID: $userIdToSend');
          debugPrint('   （API仕様書によると、userIDはリクエストボディに含めず、JWTトークンから取得）');
        }
        debugPrint('📋 [プレイリスト詳細] ===========================================');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(requestBody),
      );

      if (kDebugMode) {
        debugPrint('📋 [プレイリスト詳細] ========== HTTPレスポンス ==========');
        debugPrint('📋 [プレイリスト詳細] ステータスコード: ${response.statusCode}');
        debugPrint('📋 [プレイリスト詳細] レスポンスボディ（生）: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('📋 [プレイリスト詳細] ========== パース後 ==========');
          debugPrint('📋 [プレイリスト詳細] レスポンス全体: ${responseData.toString()}');
          debugPrint('📋 [プレイリスト詳細] レスポンスの型: ${responseData.runtimeType}');
          if (responseData is Map) {
            debugPrint('📋 [プレイリスト詳細] レスポンスのキー: ${responseData.keys.toList()}');
            debugPrint('📋 [プレイリスト詳細] status: ${responseData['status']}');
            debugPrint('📋 [プレイリスト詳細] data: ${responseData['data']}');
            debugPrint(
                '📋 [プレイリスト詳細] dataの型: ${responseData['data']?.runtimeType}');
          }
        }

        // statusを確認（大文字小文字を考慮）
        final status = responseData['status']?.toString().toLowerCase();

        if (kDebugMode) {
          debugPrint('📋 [プレイリスト詳細] ========== レスポンス解析 ==========');
          debugPrint('📋 [プレイリスト詳細] status: $status (期待値: success)');
          debugPrint('📋 [プレイリスト詳細] レスポンスの全キー: ${responseData.keys.toList()}');
        }

        if (status == 'success') {
          // API仕様書によると、dataは直接リスト形式
          // { "status": "success", "data": [...] }
          final data = responseData['data'];

          if (kDebugMode) {
            debugPrint('📋 [プレイリスト詳細] dataの型: ${data.runtimeType}');
            debugPrint('📋 [プレイリスト詳細] dataの値: $data');
          }

          // API仕様書に準拠: dataは直接リスト
          if (data != null && data is List) {
            final contentsJson = data;

            if (kDebugMode) {
              debugPrint('✅ [プレイリスト詳細] dataはリストです: ${contentsJson.length}件');
              if (contentsJson.isEmpty) {
                debugPrint('⚠️ [プレイリスト詳細] ⚠️⚠️⚠️ dataが空のリストです ⚠️⚠️⚠️');
                debugPrint(
                    '   - これは、バックエンドがplaylistdetailテーブルからデータを取得できていない可能性があります');
                debugPrint('   - 確認事項:');
                debugPrint('     1. JWTトークンからuserIDが正しく取得できているか');
                debugPrint('     2. playlistid=$playlistId が正しく送信されているか');
                debugPrint(
                    '     3. バックエンドのクエリが正しいか（WHERE userID = ? AND playlistID = ?）');
              } else {
                debugPrint('📋 [プレイリスト詳細] 最初の項目: ${contentsJson[0]}');
                if (contentsJson[0] is Map) {
                  debugPrint(
                      '📋 [プレイリスト詳細] 最初の項目のキー: ${(contentsJson[0] as Map).keys.toList()}');
                }
              }
            }

            // API仕様書に準拠: 各データ項目は以下のキーを持つ
            // contentID, title, spotlightnum, posttimestamp, playnum, link, thumbnailpath
            final result = contentsJson
                .map((contentJson) {
                  if (contentJson is Map) {
                    final map = Map<String, dynamic>.from(contentJson);

                    // contentIDが数値の場合は文字列に変換（一貫性のため）
                    if (map.containsKey('contentID') &&
                        map['contentID'] is int) {
                      map['contentID'] = map['contentID'].toString();
                      if (kDebugMode) {
                        debugPrint(
                            '📋 [プレイリスト詳細] contentIDを数値から文字列に変換: ${map['contentID']}');
                      }
                    } else if (map.containsKey('contentid') &&
                        map['contentid'] is int) {
                      map['contentid'] = map['contentid'].toString();
                      if (kDebugMode) {
                        debugPrint(
                            '📋 [プレイリスト詳細] contentidを数値から文字列に変換: ${map['contentid']}');
                      }
                    } else if (map.containsKey('contentId') &&
                        map['contentId'] is int) {
                      map['contentId'] = map['contentId'].toString();
                      if (kDebugMode) {
                        debugPrint(
                            '📋 [プレイリスト詳細] contentIdを数値から文字列に変換: ${map['contentId']}');
                      }
                    }

                    return map;
                  } else {
                    if (kDebugMode) {
                      debugPrint(
                          '⚠️ [プレイリスト詳細] コンテンツ項目がMapではありません: ${contentJson.runtimeType}');
                    }
                    return <String, dynamic>{};
                  }
                })
                .where((map) => map.isNotEmpty)
                .toList();

            if (kDebugMode) {
              debugPrint('📋 [プレイリスト詳細] 変換後の結果: ${result.length}件');
              if (result.isNotEmpty) {
                final first = result[0];
                debugPrint('📋 [プレイリスト詳細] 最初の項目（変換後）:');
                debugPrint('   - 全キー: ${first.keys.toList()}');
                final contentId = first['contentID'] ??
                    first['contentid'] ??
                    first['contentId'];
                debugPrint(
                    '   - contentID: $contentId (型: ${contentId?.runtimeType})');
              }
            }

            return result;
          } else {
            if (kDebugMode) {
              debugPrint('⚠️ [プレイリスト詳細] dataがnullです');
            }
          }
        } else {
          if (kDebugMode) {
            debugPrint(
                '⚠️ [プレイリスト詳細] APIレスポンスエラー: status=$status (期待値: success)');
            debugPrint('   - 実際のstatus: ${responseData['status']}');
            debugPrint('   - message: ${responseData['message'] ?? 'なし'}');
            debugPrint('   - レスポンス全体: ${responseData.toString()}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [プレイリスト詳細] HTTPエラー: ${response.statusCode}');
          debugPrint('📋 [プレイリスト詳細] レスポンス: ${response.body}');
        }
      }

      // 空の配列が返された場合の詳細な警告
      if (kDebugMode) {
        debugPrint('⚠️ [プレイリスト詳細] ⚠️⚠️⚠️ 重要な警告 ⚠️⚠️⚠️');
        debugPrint('   バックエンドが空の配列を返していますが、データベースにはデータが存在するはずです。');
        debugPrint('   送信したパラメータ:');
        debugPrint('     - playlistid: $playlistId');
        debugPrint('     - userID: $userIdToSend');
        debugPrint('   データベースの確認:');
        debugPrint(
            '     SELECT * FROM playlistdetail WHERE userID = \'$userIdToSend\' AND playlistID = $playlistId;');
        debugPrint('   バックエンドの確認事項:');
        debugPrint('     1. リクエストボディからplaylistidを正しく取得できているか');
        debugPrint('     2. リクエストボディまたはJWTトークンからuserIDを正しく取得できているか');
        debugPrint('     3. SQLクエリが正しく実行されているか');
        debugPrint('     4. クエリ結果が正しくJSONに変換されているか');
        debugPrint('⚠️ [プレイリスト詳細] ⚠️⚠️⚠️ 警告終了 ⚠️⚠️⚠️');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('📋 [プレイリスト詳細] 例外: $e');
        debugPrint('📋 [プレイリスト詳細] スタックトレース: $stackTrace');
      }
    }

    return [];
  }

  /// プレイリストからコンテンツを削除
  ///
  /// playlistdetailテーブルから指定されたコンテンツを削除
  /// - playlistID: 指定されたプレイリストID
  /// - contentID: 指定されたコンテンツID
  static Future<bool> removeContentFromPlaylist(
      int playlistId, String contentId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📋 [プレイリスト削除] JWTトークンが取得できません');
        }
        return false;
      }

      // API仕様書（API_ENDPOINTS.md 441-451行目）に基づく
      // POST /api/delete/playlistdetail
      final url = '${AppConfig.apiBaseUrl}/delete/playlistdetail';
      final contentIdInt = int.tryParse(contentId);

      if (contentIdInt == null || contentIdInt == 0) {
        if (kDebugMode) {
          debugPrint('❌ [プレイリスト削除] contentIDの解析に失敗しました');
          debugPrint('   - contentId (元の値): $contentId');
        }
        return false;
      }

      if (playlistId <= 0) {
        if (kDebugMode) {
          debugPrint('❌ [プレイリスト削除] playlistIDが無効です: $playlistId');
        }
        return false;
      }

      // バックエンドの実装（routes/delete.py 53-54行目）を確認:
      // playlistid = data.get("playlistID")
      // contentid = data.get("contentID")
      // バックエンドは "playlistID" と "contentID"（大文字）を期待している
      final requestBody = {
        'playlistID': playlistId, // バックエンドは "playlistID"（大文字）を期待
        'contentID': contentIdInt, // バックエンドは "contentID"（大文字）を期待
      };

      if (kDebugMode) {
        debugPrint('📋 [プレイリスト削除] ========== API呼び出し ==========');
        debugPrint('📋 [プレイリスト削除] URL: $url');
        debugPrint('📋 [プレイリスト削除] リクエストボディ: ${jsonEncode(requestBody)}');
        debugPrint('📋 [プレイリスト削除] バックエンドは "playlistID" と "contentID"（大文字）を期待');
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
            debugPrint('❌ [プレイリスト削除] タイムアウト: 30秒以内にレスポンスがありませんでした');
          }
          throw TimeoutException('プレイリスト削除のリクエストがタイムアウトしました');
        },
      );

      if (kDebugMode) {
        debugPrint('📋 [プレイリスト削除] HTTPステータスコード: ${response.statusCode}');
        debugPrint('📋 [プレイリスト削除] レスポンスボディ: ${response.body}');
      }

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (kDebugMode) {
            debugPrint('📋 [プレイリスト削除] レスポンス（パース後）: ${responseData.toString()}');
          }

          if (responseData['status'] == 'success') {
            if (kDebugMode) {
              debugPrint('✅ [プレイリスト削除] 成功: playlistdetailテーブルから削除されました');
            }
            return true;
          } else {
            if (kDebugMode) {
              debugPrint('❌ [プレイリスト削除] APIレスポンスエラー');
              debugPrint('   - status: ${responseData['status']}');
              debugPrint('   - message: ${responseData['message'] ?? 'なし'}');
            }
            return false;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [プレイリスト削除] レスポンスのパースエラー: $e');
          }
          return false;
        }
      } else if (response.statusCode == 404) {
        if (kDebugMode) {
          debugPrint('❌ [プレイリスト削除] エンドポイントが見つかりません (404)');
          debugPrint('   - URL: $url');
          debugPrint('   - このエンドポイントはバックエンドに実装されていない可能性があります');
        }
        return false;
      } else {
        if (kDebugMode) {
          debugPrint('❌ [プレイリスト削除] HTTPエラー: ${response.statusCode}');
          debugPrint('📋 [プレイリスト削除] レスポンス: ${response.body}');
        }
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [プレイリスト削除] 例外: $e');
        debugPrint('📋 [プレイリスト削除] スタックトレース: $stackTrace');

        // ClientExceptionの場合は、エンドポイントが存在しないかCORSエラーの可能性
        if (e.toString().contains('ClientException') ||
            e.toString().contains('Failed to fetch')) {
          debugPrint('⚠️ [プレイリスト削除] エンドポイントが存在しないか、CORSエラーの可能性があります');
          debugPrint(
              '   - バックエンドに /api/delete/playlistdetail エンドポイントが実装されているか確認してください');
          debugPrint('   - CORS設定が正しく行われているか確認してください');
          debugPrint('   - ネットワーク接続を確認してください');
        }
      }
    }

    return false;
  }

  /// プレイリストを削除
  ///
  /// データベースから指定されたプレイリストを完全に削除
  /// - playlistId: 削除するプレイリストのID
  static Future<bool> deletePlaylist(int playlistId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📋 [プレイリスト削除] JWTトークンが取得できません');
        }
        return false;
      }

      // API仕様書（API_ENDPOINTS.md 453-462行目）に基づく
      // POST /api/delete/playlist
      final url = '${AppConfig.apiBaseUrl}/delete/playlist';

      if (playlistId <= 0) {
        if (kDebugMode) {
          debugPrint('❌ [プレイリスト削除] playlistIDが無効です: $playlistId');
        }
        return false;
      }

      // バックエンドの実装を確認:
      // バックエンドは "playlistID"（大文字のID）を期待している
      // API仕様書では小文字と記載されているが、実際のバックエンド実装では大文字が必要
      final requestBody = {
        'playlistID': playlistId, // バックエンドは "playlistID"（大文字）を期待
      };

      if (kDebugMode) {
        debugPrint('📋 [プレイリスト削除] ========== API呼び出し ==========');
        debugPrint('📋 [プレイリスト削除] URL: $url');
        debugPrint('📋 [プレイリスト削除] リクエストボディ: ${jsonEncode(requestBody)}');
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
            debugPrint('❌ [プレイリスト削除] タイムアウト: 30秒以内にレスポンスがありませんでした');
          }
          throw TimeoutException('プレイリスト削除のリクエストがタイムアウトしました');
        },
      );

      if (kDebugMode) {
        debugPrint('📋 [プレイリスト削除] HTTPステータスコード: ${response.statusCode}');
        debugPrint('📋 [プレイリスト削除] レスポンスボディ: ${response.body}');
      }

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (kDebugMode) {
            debugPrint('📋 [プレイリスト削除] レスポンス（パース後）: ${responseData.toString()}');
          }

          if (responseData['status'] == 'success') {
            if (kDebugMode) {
              debugPrint('✅ [プレイリスト削除] 成功: データベースから削除されました');
            }
            return true;
          } else {
            if (kDebugMode) {
              debugPrint('❌ [プレイリスト削除] APIレスポンスエラー');
              debugPrint('   - status: ${responseData['status']}');
              debugPrint('   - message: ${responseData['message'] ?? 'なし'}');
            }
            return false;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [プレイリスト削除] レスポンスのパースエラー: $e');
          }
          return false;
        }
      } else if (response.statusCode == 404) {
        if (kDebugMode) {
          debugPrint('❌ [プレイリスト削除] エンドポイントが見つかりません (404)');
          debugPrint('   - URL: $url');
          debugPrint('   - このエンドポイントはバックエンドに実装されていない可能性があります');
        }
        return false;
      } else {
        if (kDebugMode) {
          debugPrint('❌ [プレイリスト削除] HTTPエラー: ${response.statusCode}');
          debugPrint('📋 [プレイリスト削除] レスポンス: ${response.body}');
        }
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [プレイリスト削除] 例外: $e');
        debugPrint('📋 [プレイリスト削除] スタックトレース: $stackTrace');

        // ClientExceptionの場合は、エンドポイントが存在しないかCORSエラーの可能性
        if (e.toString().contains('ClientException') ||
            e.toString().contains('Failed to fetch')) {
          debugPrint('⚠️ [プレイリスト削除] エンドポイントが存在しないか、CORSエラーの可能性があります');
          debugPrint(
              '   - バックエンドに /api/delete/playlist エンドポイントが実装されているか確認してください');
          debugPrint('   - CORS設定が正しく行われているか確認してください');
          debugPrint('   - ネットワーク接続を確認してください');
        }
      }
    }

    return false;
  }
}
