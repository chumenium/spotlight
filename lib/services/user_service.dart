import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../config/app_config.dart';
import '../services/jwt_service.dart';

/// ユーザーAPIサービス
class UserService {
  /// アイコン画像を変更（アップロード）
  /// 
  /// パラメータ:
  /// - username: バックエンドで生成された一意で変更不可なusername（必須）
  /// - imageFile: アップロードする画像ファイル
  /// 
  /// リクエスト:
  /// - username: ユーザー名（必須）
  /// - iconimg: base64エンコードした画像データ
  /// 
  /// レスポンス:
  /// - iconimgpath: バックエンドで生成されたアイコンパス（username_icon.png形式）
  /// 
  /// 戻り値:
  /// - String?: アップロード成功時のアイコンパス（iconimgpath）、失敗時はnull
  static Future<String?> uploadIcon(String username, File imageFile) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ JWTトークンが取得できません');
        }
        return null;
      }

      // 画像をbase64にエンコード
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final url = '${AppConfig.backendUrl}/api/users/changeicon';
      
      if (kDebugMode) {
        debugPrint('📤 アイコン変更URL: $url');
        debugPrint('📤 username: $username');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'iconimg': base64Image,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          debugPrint('📥 アイコンアップロードレスポンス: ${responseData.toString()}');
        }
        
        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final iconPath = responseData['data']['iconimgpath'] as String?;
          return iconPath;
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ アイコン変更エラー: ${response.statusCode}');
          debugPrint('レスポンス: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ アイコン変更例外: $e');
      }
    }

    return null;
  }

  /// アイコンを削除
  /// 
  /// パラメータ:
  /// - username: バックエンドで生成された一意で変更不可なusername（必須）
  /// 
  /// リクエスト:
  /// - username: ユーザー名（必須）
  /// - iconimgは送信しない（削除を意味する）
  /// 
  /// レスポンス:
  /// - iconimgpathは空になる、またはデフォルトアイコンのパス
  /// 
  /// 戻り値:
  /// - bool: 削除成功の場合true
  static Future<bool> deleteIcon(String username) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/users/changeicon';
      
      if (kDebugMode) {
        debugPrint('🗑️ アイコン削除URL: $url');
        debugPrint('🗑️ username: $username');
      }

      // 削除時はiconimgを送信しない
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          debugPrint('📥 アイコン削除レスポンス: ${responseData.toString()}');
        }
        
        return responseData['status'] == 'success';
      } else {
        if (kDebugMode) {
          debugPrint('❌ アイコン削除エラー: ${response.statusCode}');
          debugPrint('レスポンス: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ アイコン削除例外: $e');
      }
    }

    return false;
  }

  /// ユーザー情報を再取得
  /// 
  /// アイコン更新後にユーザー情報を再取得してAuthProviderを更新するために使用
  /// 
  /// パラメータ:
  /// - firebaseUid: Firebase UID（ユーザー識別用）
  /// 
  /// 戻り値:
  /// - Map<String, dynamic>?: ユーザー情報（username, iconimgpath）、失敗時はnull
  static Future<Map<String, dynamic>?> refreshUserInfo(String firebaseUid) async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ JWTトークンが取得できません');
        }
        return null;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/users/getusername'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'firebase_uid': firebaseUid,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          debugPrint('📥 ユーザー情報再取得レスポンス: ${responseData.toString()}');
        }
        
        if (responseData['status'] == 'success' && responseData['data'] != null) {
          return responseData['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ユーザー情報再取得例外: $e');
      }
    }

    return null;
  }
}

