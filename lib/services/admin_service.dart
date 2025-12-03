import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../config/app_config.dart';
import '../services/jwt_service.dart';

/// 管理者用APIサービス
class AdminService {
  /// 全ユーザーデータを取得
  ///
  /// パラメータ:
  /// - offset: 取得開始位置（デフォルト: 0、300件ずつ取得）
  ///
  /// 戻り値:
  /// - List<Map<String, dynamic>>?: ユーザーデータのリスト、失敗時はnull
  static Future<List<Map<String, dynamic>>?> getAllUsers({int offset = 0}) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: JWTトークンが取得できません');
        }
        return null;
      }

      // 管理者APIエンドポイント: /api/admin/getuser
      // バックエンドの実装に合わせて /admin/getuser を使用
      final url = '${AppConfig.apiBaseUrl}/admin/getuser';

      if (kDebugMode) {
        debugPrint('👤 管理者API: 全ユーザー取得URL: $url');
        debugPrint('👤 管理者API: offset: $offset');
      }

      // リクエストボディにoffsetを指定（API仕様に合わせる）
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'offset': offset}),
      );

      if (kDebugMode) {
        debugPrint('👤 管理者API: レスポンス statusCode=${response.statusCode}');
        debugPrint('👤 管理者API: レスポンス本文: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('👤 管理者API: レスポンスデータ: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success' &&
            responseData['userdatas'] != null) {
          final List<dynamic> userdatas = responseData['userdatas'];
          if (kDebugMode) {
            debugPrint('✅ 管理者API: ${userdatas.length}件のユーザーデータを取得');
          }
          return userdatas
              .map((user) => user as Map<String, dynamic>)
              .toList();
        } else {
          if (kDebugMode) {
            debugPrint('❌ 管理者API: レスポンス形式が不正');
            debugPrint('  status: ${responseData['status']}');
            debugPrint('  message: ${responseData['message'] ?? 'なし'}');
            debugPrint('  userdatas存在: ${responseData['userdatas'] != null}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エラー statusCode=${response.statusCode}');
          debugPrint('  レスポンス本文: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者API: 例外: $e');
      }
    }

    return null;
  }

  /// 管理者権限を有効化
  ///
  /// パラメータ:
  /// - userID: 管理者にしたいユーザーのuserID
  ///
  /// 戻り値:
  /// - bool: 成功時true、失敗時false
  static Future<bool> enableAdmin(String userID) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/admin/enableadmin';

      if (kDebugMode) {
        debugPrint('👤 管理者API: 管理者権限有効化URL: $url');
        debugPrint('👤 管理者API: userID: $userID');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'userID': userID}),
      );

      if (kDebugMode) {
        debugPrint('👤 管理者API: レスポンス statusCode=${response.statusCode}');
        debugPrint('👤 管理者API: レスポンス本文: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          if (kDebugMode) {
            debugPrint('✅ 管理者API: 管理者権限を有効化しました');
          }
          return true;
        } else {
          if (kDebugMode) {
            debugPrint('❌ 管理者API: ${responseData['message'] ?? 'エラー'}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エラー statusCode=${response.statusCode}');
          debugPrint('  レスポンス本文: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者API: 例外: $e');
      }
    }

    return false;
  }

  /// 管理者権限を無効化
  ///
  /// パラメータ:
  /// - userID: 一般ユーザーにしたいユーザーのuserID
  ///
  /// 戻り値:
  /// - bool: 成功時true、失敗時false
  static Future<bool> disableAdmin(String userID) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.apiBaseUrl}/admin/disableadmin';

      if (kDebugMode) {
        debugPrint('👤 管理者API: 管理者権限無効化URL: $url');
        debugPrint('👤 管理者API: userID: $userID');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'userID': userID}),
      );

      if (kDebugMode) {
        debugPrint('👤 管理者API: レスポンス statusCode=${response.statusCode}');
        debugPrint('👤 管理者API: レスポンス本文: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          if (kDebugMode) {
            debugPrint('✅ 管理者API: 管理者権限を無効化しました');
          }
          return true;
        } else {
          if (kDebugMode) {
            debugPrint('❌ 管理者API: ${responseData['message'] ?? 'エラー'}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エラー statusCode=${response.statusCode}');
          debugPrint('  レスポンス本文: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者API: 例外: $e');
      }
    }

    return false;
  }
}

