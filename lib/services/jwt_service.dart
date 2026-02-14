import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// JWTトークンの管理を行うサービス
///
/// Firebase IDトークンをバックエンドに送信してJWTトークンを取得し、
/// ローカルストレージに保存・管理します
class JwtService {
  static const String _jwtTokenKey = 'jwt_token';
  static const String _userInfoKey = 'user_info';
  static const String _lastAccessTimeKey = 'last_access_time';

  /// JWTトークンを取得
  ///
  /// ローカルストレージからJWTトークンを取得します
  ///
  /// 戻り値:
  /// - String: JWTトークン（保存されている場合）
  /// - null: トークンが保存されていない場合
  static Future<String?> getJwtToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_jwtTokenKey);

      return token;
    } catch (e) {
      return null;
    }
  }

  /// JWTトークンを保存
  ///
  /// ローカルストレージにJWTトークンを保存します
  ///
  /// パラメータ:
  /// - token: 保存するJWTトークン
  ///
  /// 戻り値:
  /// - bool: 保存成功の場合true
  static Future<bool> saveJwtToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_jwtTokenKey, token);

      return success;
    } catch (e) {
      return false;
    }
  }

  /// ユーザー情報を保存
  ///
  /// ローカルストレージにユーザー情報を保存します
  ///
  /// パラメータ:
  /// - userInfo: 保存するユーザー情報
  ///
  /// 戻り値:
  /// - bool: 保存成功の場合true
  static Future<bool> saveUserInfo(Map<String, dynamic> userInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfoJson = jsonEncode(userInfo);
      final success = await prefs.setString(_userInfoKey, userInfoJson);

      return success;
    } catch (e) {
      return false;
    }
  }

  /// ユーザー情報を取得
  ///
  /// ローカルストレージからユーザー情報を取得します
  ///
  /// 戻り値:
  /// - Map<String, dynamic>: ユーザー情報（保存されている場合）
  /// - null: ユーザー情報が保存されていない場合
  static Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfoJson = prefs.getString(_userInfoKey);

      if (userInfoJson != null) {
        final userInfo = jsonDecode(userInfoJson) as Map<String, dynamic>;

        return userInfo;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// JWTトークンを削除
  ///
  /// ローカルストレージからJWTトークンを削除します
  ///
  /// 戻り値:
  /// - bool: 削除成功の場合true
  static Future<bool> clearJwtToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.remove(_jwtTokenKey);

      return success;
    } catch (e) {
      return false;
    }
  }

  /// ユーザー情報を削除
  ///
  /// ローカルストレージからユーザー情報を削除します
  ///
  /// 戻り値:
  /// - bool: 削除成功の場合true
  static Future<bool> clearUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.remove(_userInfoKey);

      return success;
    } catch (e) {
      return false;
    }
  }

  /// すべての認証情報をクリア
  ///
  /// JWTトークン、ユーザー情報、最後の利用日時をすべて削除します
  ///
  /// 戻り値:
  /// - bool: すべての削除が成功した場合true
  static Future<bool> clearAll() async {
    try {
      final tokenCleared = await clearJwtToken();
      final userInfoCleared = await clearUserInfo();
      final lastAccessCleared = await clearLastAccessTime();

      final success = tokenCleared && userInfoCleared && lastAccessCleared;

      return success;
    } catch (e) {
      return false;
    }
  }

  /// JWTトークンが有効かチェック
  ///
  /// ローカルストレージにJWTトークンが保存されているかチェックします
  ///
  /// 戻り値:
  /// - bool: JWTトークンが保存されている場合true
  static Future<bool> hasValidToken() async {
    final token = await getJwtToken();
    return token != null && token.isNotEmpty;
  }

  /// 最後の利用日時を保存
  ///
  /// アプリの利用日時を保存します
  ///
  /// 戻り値:
  /// - bool: 保存成功の場合true
  static Future<bool> saveLastAccessTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toIso8601String();
      final success = await prefs.setString(_lastAccessTimeKey, now);

      return success;
    } catch (e) {
      return false;
    }
  }

  /// 最後の利用日時を取得
  ///
  /// ローカルストレージから最後の利用日時を取得します
  ///
  /// 戻り値:
  /// - DateTime?: 最後の利用日時（保存されている場合）
  /// - null: 利用日時が保存されていない場合
  static Future<DateTime?> getLastAccessTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeString = prefs.getString(_lastAccessTimeKey);

      if (timeString != null) {
        final time = DateTime.parse(timeString);

        return time;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 最後の利用日時を削除
  ///
  /// ローカルストレージから最後の利用日時を削除します
  ///
  /// 戻り値:
  /// - bool: 削除成功の場合true
  static Future<bool> clearLastAccessTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.remove(_lastAccessTimeKey);

      return success;
    } catch (e) {
      return false;
    }
  }

  /// 最後の利用から半年以上経過しているかチェック
  ///
  /// 最後の利用日時から半年（180日）以上経過しているかチェックします
  ///
  /// 戻り値:
  /// - bool: 半年以上経過している場合true、それ以外はfalse
  static Future<bool> isLastAccessExpired() async {
    try {
      final lastAccessTime = await getLastAccessTime();

      if (lastAccessTime == null) {
        // 利用日時が保存されていない場合は、期限切れとみなす
        return true;
      }

      final now = DateTime.now();
      final difference = now.difference(lastAccessTime);
      const sixMonths = Duration(days: 180); // 半年 = 180日

      final isExpired = difference >= sixMonths;

      return isExpired;
    } catch (e) {
      // エラーが発生した場合は、安全のため期限切れとみなす
      return true;
    }
  }
}
