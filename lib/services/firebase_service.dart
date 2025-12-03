import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
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
      final options = _getFirebaseOptions();
      if (options == null) {
        if (kDebugMode) {
          debugPrint(
              '⚠️ FirebaseOptionsがnullのため、google-services.jsonから自動読み込みを試みます');
        }
        // Android/iOSではgoogle-services.jsonから自動読み込み
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(options: options);
      }

      _initialized = true;

      if (kDebugMode) {
        debugPrint('✅ Firebase initialized successfully');
      }

      // FCMトークンの自動初期化（Webではスキップ）
      if (!kIsWeb) {
        await _initializeFcm();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Firebase initialization failed: $e');
        debugPrint('⚠️ Firebase機能は使用できませんが、アプリは起動します');
      }
      // エラーを再スローせず、初期化失敗状態を保持
      // これにより、Firebaseが使用できない場合でもアプリを起動できる
      _initialized = false;
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
    // Webプラットフォームでは明示的にFirebaseOptionsを設定
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyC5pPkP1WWYRaFLspAiq_YMi8IB9KJ-BM4',
        appId: '1:185578323389:web:1f6fd5c7298d28887ee6d4',
        messagingSenderId: '185578323389',
        projectId: 'spotlight-597c4',
        authDomain: 'spotlight-597c4.firebaseapp.com',
        storageBucket: 'spotlight-597c4.firebasestorage.app',
        measurementId: 'G-7VWTB0N3VL', // Firebase Analytics
      );
    }

    // Android/iOSではgoogle-services.json / GoogleService-Info.plist
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
