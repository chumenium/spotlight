import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/jwt_service.dart';

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
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/content/getplaylist';

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

        if (responseData['status'] == 'success' &&
            responseData['playlist'] != null) {
          final List<dynamic> playlistsJson = responseData['playlist'];

          final playlists = playlistsJson
              .map((playlistJson) =>
                  Playlist.fromJson(playlistJson as Map<String, dynamic>))
              .toList();

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

          return uniquePlaylistsList;
        }
      }
    } catch (e) {
      // ignore
    }

    return [];
  }

  /// スポットライト済みコンテンツ一覧を取得
  /// POST /api/users/getspotlightcontents
  static Future<List<Map<String, dynamic>>> getSpotlightContents() async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        return [];
      }

      final url = '${AppConfig.apiBaseUrl}/users/getspotlightcontents';

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
      }
    } catch (e) {
      // ignore
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
      // ignore
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
      // ignore
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
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/content/addcontentplaylist';
      final contentIdInt = int.tryParse(contentId);

      if (contentIdInt == null || contentIdInt == 0) {
        return false;
      }

      if (playlistId <= 0) {
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

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(requestBody),
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
      } else {
        return false;
      }
    } catch (e, stackTrace) {
      // ignore
    }

    return false;
  }

  /// プレイリストを作成
  static Future<int?> createPlaylist(String title) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        return null;
      }

      final url = '${AppConfig.apiBaseUrl}/content/createplaylist';

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

        if (responseData['status'] == 'success') {
          // プレイリストIDを取得（複数の可能性のあるキーを確認）
          final playlistId = responseData['playlistid'] ??
              responseData['playlistID'] ??
              responseData['playlistId'] ??
              responseData['id'];

          if (playlistId != null) {
            final playlistIdInt = int.tryParse(playlistId.toString());
            if (playlistIdInt != null && playlistIdInt > 0) {
              return playlistIdInt;
            }
          } else {
            // playlistidがレスポンスに含まれていない場合でも、statusがsuccessなら作成は成功している
            // オートインクリメントで追加されるため、レスポンスに含まれなくても問題ない
            // 成功を示す特殊な値（0）を返す（playlistidが取得できない場合）
            // 呼び出し側で、0の場合は成功として扱い、プレイリスト一覧を再取得するなどで対応
            return 0;
          }
        }
      }
    } catch (e) {
      // ignore
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
        return [];
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

        // statusを確認（大文字小文字を考慮）
        final status = responseData['status']?.toString().toLowerCase();

        if (status == 'success') {
          // API仕様書によると、dataは直接リスト形式
          // { "status": "success", "data": [...] }
          final data = responseData['data'];

          // API仕様書に準拠: dataは直接リスト
          if (data != null && data is List) {
            final contentsJson = data;

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
                    } else if (map.containsKey('contentid') &&
                        map['contentid'] is int) {
                      map['contentid'] = map['contentid'].toString();
                    } else if (map.containsKey('contentId') &&
                        map['contentId'] is int) {
                      map['contentId'] = map['contentId'].toString();
                    }

                    return map;
                  } else {
                    return <String, dynamic>{};
                  }
                })
                .where((map) => map.isNotEmpty)
                .toList();

            return result;
          }
        }
      }
    } catch (e, stackTrace) {
      // ignore
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
        return false;
      }

      // API仕様書（API_ENDPOINTS.md 441-451行目）に基づく
      // POST /api/delete/playlistdetail
      final url = '${AppConfig.apiBaseUrl}/delete/playlistdetail';
      final contentIdInt = int.tryParse(contentId);

      if (contentIdInt == null || contentIdInt == 0) {
        return false;
      }

      if (playlistId <= 0) {
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
          throw TimeoutException('プレイリスト削除のリクエストがタイムアウトしました');
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

  /// プレイリストを削除
  ///
  /// データベースから指定されたプレイリストを完全に削除
  /// - playlistId: 削除するプレイリストのID
  static Future<bool> deletePlaylist(int playlistId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        return false;
      }

      // API仕様書（API_ENDPOINTS.md 453-462行目）に基づく
      // POST /api/delete/playlist
      final url = '${AppConfig.apiBaseUrl}/delete/playlist';

      if (playlistId <= 0) {
        return false;
      }

      // バックエンドの実装を確認:
      // バックエンドは "playlistID"（大文字のID）を期待している
      // API仕様書では小文字と記載されているが、実際のバックエンド実装では大文字が必要
      final requestBody = {
        'playlistID': playlistId, // バックエンドは "playlistID"（大文字）を期待
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
          throw TimeoutException('プレイリスト削除のリクエストがタイムアウトしました');
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
}
