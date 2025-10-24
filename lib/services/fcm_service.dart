import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      if (kDebugMode) {
        debugPrint('🔔 FCMサービスが初期化されていません（スキップ）');
      }
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
        if (kDebugMode) {
          debugPrint('🔔 通知許可リクエストエラー（続行）: $permissionError');
        }
      }
      
      // FCMトークンを取得
      final token = await _messaging.getToken();
      
      if (kDebugMode) {
        debugPrint('🔔 FCMトークン取得: ${token != null ? '成功' : '失敗'}');
        if (token != null) {
          debugPrint('🔔 FCMトークン: $token');
        }
      }
      
      return token;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔔 FCMトークン取得エラー: $e');
      }
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
      
      if (kDebugMode) {
        debugPrint('🔔 FCMトークン保存: ${success ? '成功' : '失敗'}');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔔 FCMトークン保存エラー: $e');
      }
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
      
      if (kDebugMode) {
        debugPrint('🔔 保存されたFCMトークン取得: ${token != null ? '成功' : 'なし'}');
      }
      
      return token;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔔 保存されたFCMトークン取得エラー: $e');
      }
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
      
      if (kDebugMode) {
        debugPrint('🔔 FCMトークン削除: ${success ? '成功' : '失敗'}');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔔 FCMトークン削除エラー: $e');
      }
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
      if (kDebugMode) {
        debugPrint('🔔 FCMトークン更新: $token');
      }
      
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
        listenToTokenRefresh((newToken) {
          if (kDebugMode) {
            debugPrint('🔔 FCMトークンが更新されました: $newToken');
          }
        });
      }
      
      return token;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔔 通知初期化エラー: $e');
      }
      _isInitialized = false;
      return null;
    }
  }
  
  /// FCMサービスを無効化
  /// 
  /// FCMトークンの取得をスキップするように設定します
  static void disableFcm() {
    _isInitialized = false;
    if (kDebugMode) {
      debugPrint('🔔 FCMサービスを無効化しました');
    }
  }
}
