import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'fcm_service.dart';

/// Firebase初期化と設定を管理するサービスクラス
class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();
  
  FirebaseService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Firebaseを初期化
  /// 
  /// アプリ起動時に一度だけ呼び出す必要があります。
  /// main()関数から呼び出してください。
  /// FCMトークンの初期化も含まれます。
  Future<void> initialize() async {
    if (_initialized) {
      if (kDebugMode) {
        debugPrint('Firebase already initialized');
      }
      return;
    }

    try {
      await Firebase.initializeApp(
        options: _getFirebaseOptions(),
      );
      
      _initialized = true;
      
      if (kDebugMode) {
        debugPrint('✅ Firebase initialized successfully');
      }

      // FCMトークンの自動初期化
      await _initializeFcm();
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Firebase initialization failed: $e');
      }
      rethrow;
    }
  }

  /// FCMトークンを初期化
  /// 
  /// Firebase初期化後に自動的に呼び出されます。
  Future<void> _initializeFcm() async {
    try {
      final fcmToken = await FcmService.initializeNotifications();
      if (fcmToken != null) {
        if (kDebugMode) {
          debugPrint('✅ FCMトークン初期化完了');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ FCMトークン初期化をスキップ（通知機能は利用できません）');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ FCM初期化エラー（続行）: $e');
      }
    }
  }

  /// プラットフォーム別のFirebaseオプションを取得
  /// 
  /// Firebase CLIで自動生成される場合は、
  /// firebase_options.dart をインポートして使用してください。
  FirebaseOptions? _getFirebaseOptions() {
    // Firebase CLIを使用する場合は、以下のように実装：
    // return DefaultFirebaseOptions.currentPlatform;
    
    // 手動設定の場合は、google-services.json / GoogleService-Info.plist
    // から自動的に読み込まれるため、null を返す
    return null;
  }

  /// Firebase関連のデバッグ情報を出力
  void printDebugInfo() {
    if (!kDebugMode) return;

    debugPrint('=== Firebase Debug Info ===');
    debugPrint('Initialized: $_initialized');
    
    if (_initialized) {
      final app = Firebase.app();
      debugPrint('App Name: ${app.name}');
      debugPrint('Options: ${app.options}');
    }
    debugPrint('=========================');
  }
}

