import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../config/app_config.dart';
import '../services/jwt_service.dart';

/// プレイリストモデル
class Playlist {
  final int playlistid;
  final String title;
  final String? thumbnailpath;

  Playlist({
    required this.playlistid,
    required this.title,
    this.thumbnailpath,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      playlistid: int.tryParse(json['playlistid']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      thumbnailpath: json['thumbnailpath']?.toString(),
    );
  }
}

/// プレイリストAPIサービス
class PlaylistService {
  /// プレイリスト一覧を取得
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
          debugPrint('📋 プレイリスト取得レスポンス: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success' && responseData['playlist'] != null) {
          final List<dynamic> playlistsJson = responseData['playlist'];
          return playlistsJson
              .map((playlistJson) => Playlist.fromJson(playlistJson as Map<String, dynamic>))
              .toList();
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

  /// プレイリストにコンテンツを追加
  static Future<bool> addContentToPlaylist(int playlistId, String contentId) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('📋 JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/content/addcontentplaylist';
      
      if (kDebugMode) {
        debugPrint('📋 プレイリスト追加URL: $url, playlistid: $playlistId, contentid: $contentId');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'playlistid': playlistId,
          'contentid': int.tryParse(contentId) ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          debugPrint('📋 プレイリスト追加レスポンス: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success') {
          return true;
        }
      } else {
        if (kDebugMode) {
          debugPrint('📋 プレイリスト追加エラー: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📋 プレイリスト追加例外: $e');
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
          debugPrint('📋 プレイリスト作成レスポンス: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success') {
          // プレイリストIDを返す（APIレスポンスに含まれている場合）
          return responseData['playlistid'] as int?;
        }
      } else {
        if (kDebugMode) {
          debugPrint('📋 プレイリスト作成エラー: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📋 プレイリスト作成例外: $e');
      }
    }

    return null;
  }
}

