import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

/// FCM（Firebase Cloud Messaging）トークンの管理を行うサービス
///
/// プッシュ通知用のFCMトークンを取得・保存・管理します
class FcmService {
  static const String _fcmTokenKey = 'fcm_token';
  static FirebaseMessaging? _firebaseMessaging;
  static bool _isInitialized = false;

  /// Firebase Messagingインスタンスを取得
  static FirebaseMessaging get _messaging {
    _firebaseMessaging ??= FirebaseMessaging.instance;
    return _firebaseMessaging!;
  }

  /// FCMトークンを取得
  ///
  /// Firebase Cloud MessagingからFCMトークンを取得します
  ///
  /// 戻り値:
  /// - String: FCMトークン（成功の場合）
  /// - null: 失敗の場合
  static Future<String?> getFcmToken() async {
    // 初期化されていない場合はスキップ
    if (!_isInitialized) {
      return null;
    }

    try {
      // 通知の許可をリクエスト（エラーが発生しても続行）
      try {
        await _messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
      } catch (permissionError) {
        // ignore
      }

      // FCMトークンを取得
      final token = await _messaging.getToken();

      return token;
    } catch (e) {
      return null;
    }
  }

  /// FCMトークンをローカルに保存
  ///
  /// パラメータ:
  /// - token: 保存するFCMトークン
  ///
  /// 戻り値:
  /// - bool: 保存成功の場合true
  static Future<bool> saveFcmToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_fcmTokenKey, token);

      return success;
    } catch (e) {
      return false;
    }
  }

  /// 保存されたFCMトークンを取得
  ///
  /// 戻り値:
  /// - String: FCMトークン（保存されている場合）
  /// - null: トークンが保存されていない場合
  static Future<String?> getSavedFcmToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_fcmTokenKey);

      return token;
    } catch (e) {
      return null;
    }
  }

  /// FCMトークンを削除
  ///
  /// 戻り値:
  /// - bool: 削除成功の場合true
  static Future<bool> clearFcmToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.remove(_fcmTokenKey);

      return success;
    } catch (e) {
      return false;
    }
  }

  /// FCMトークンの更新を監視
  ///
  /// FCMトークンが更新されたときにコールバックを実行します
  ///
  /// パラメータ:
  /// - onTokenRefresh: トークン更新時のコールバック
  static void listenToTokenRefresh(Function(String) onTokenRefresh) {
    _messaging.onTokenRefresh.listen((String token) {
      // 新しいトークンを保存
      saveFcmToken(token);

      // コールバックを実行
      onTokenRefresh(token);
    });
  }

  /// 通知の初期化
  ///
  /// FCMトークンを取得してローカルに保存します
  ///
  /// 戻り値:
  /// - String: FCMトークン（成功の場合）
  /// - null: 失敗の場合
  static Future<String?> initializeNotifications() async {
    try {
      _isInitialized = true;
      final token = await getFcmToken();
      if (token != null) {
        await saveFcmToken(token);

        // トークン更新の監視を開始
        listenToTokenRefresh((newToken) {});
      }

      return token;
    } catch (e) {
      _isInitialized = false;
      return null;
    }
  }

  /// FCMサービスを無効化
  ///
  /// FCMトークンの取得をスキップするように設定します
  static void disableFcm() {
    _isInitialized = false;
  }

  /// FCMトークンをサーバーに送信
  ///
  /// 取得したFCMトークンをバックエンドサーバーに送信して更新します
  ///
  /// パラメータ:
  /// - jwt: JWTトークン（認証用）
  ///
  /// 戻り値:
  /// - bool: 送信成功の場合true
  static Future<bool> updateFcmTokenToServer(String jwt) async {
    try {
      // FCMトークンを取得
      String? token = await getFcmToken();

      if (token == null) {
        return false;
      }

      // バックエンドサーバーにFCMトークンを送信
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/auth/update_token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'token': token}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e, stackTrace) {
      return false;
    }
  }
}
