import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// JWTトークンの管理を行うサービス
/// 
/// Firebase IDトークンをバックエンドに送信してJWTトークンを取得し、
/// ローカルストレージに保存・管理します
class JwtService {
  static const String _jwtTokenKey = 'jwt_token';
  static const String _userInfoKey = 'user_info';
  
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
      
      if (kDebugMode) {
        debugPrint('🔐 JWTトークン取得: ${token != null ? '成功' : 'なし'}');
      }
      
      return token;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 JWTトークン取得エラー: $e');
      }
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
      
      if (kDebugMode) {
        debugPrint('🔐 JWTトークン保存: ${success ? '成功' : '失敗'}');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 JWTトークン保存エラー: $e');
      }
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
      
      if (kDebugMode) {
        debugPrint('🔐 ユーザー情報保存: ${success ? '成功' : '失敗'}');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 ユーザー情報保存エラー: $e');
      }
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
        
        if (kDebugMode) {
          debugPrint('🔐 ユーザー情報取得: 成功');
        }
        
        return userInfo;
      }
      
      if (kDebugMode) {
        debugPrint('🔐 ユーザー情報取得: なし');
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 ユーザー情報取得エラー: $e');
      }
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
      
      if (kDebugMode) {
        debugPrint('🔐 JWTトークン削除: ${success ? '成功' : '失敗'}');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 JWTトークン削除エラー: $e');
      }
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
      
      if (kDebugMode) {
        debugPrint('🔐 ユーザー情報削除: ${success ? '成功' : '失敗'}');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 ユーザー情報削除エラー: $e');
      }
      return false;
    }
  }
  
  /// すべての認証情報をクリア
  /// 
  /// JWTトークンとユーザー情報をすべて削除します
  /// 
  /// 戻り値:
  /// - bool: すべての削除が成功した場合true
  static Future<bool> clearAll() async {
    try {
      final tokenCleared = await clearJwtToken();
      final userInfoCleared = await clearUserInfo();
      
      final success = tokenCleared && userInfoCleared;
      
      if (kDebugMode) {
        debugPrint('🔐 認証情報クリア: ${success ? '成功' : '失敗'}');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 認証情報クリアエラー: $e');
      }
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
}
