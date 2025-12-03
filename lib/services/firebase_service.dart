import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'dart:io' show Platform;
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
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Firebase initialization failed: $e');
        debugPrint('❌ Stack trace: $stackTrace');
        debugPrint('⚠️ Firebase機能は使用できませんが、アプリは起動します');
        
        // エラーの詳細を出力
        if (e.toString().contains('values.xml')) {
          debugPrint('⚠️ values.xmlエラー: google-services.jsonが正しく処理されていない可能性があります');
          debugPrint('⚠️ 解決策: android/app/build.gradle.ktsでgoogle-servicesプラグインが適用されているか確認してください');
        }
        if (e.toString().contains('ApiException')) {
          debugPrint('⚠️ Google Play Servicesエラー: Google Play Servicesが利用できない可能性があります');
        }
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

    // Androidでは明示的にFirebaseOptionsを設定
    // google-services.jsonから読み込む代わりに、直接指定することで
    // values.xmlの生成に依存しないようにする
    // google-services.jsonの内容:
    // - project_id: spotlight-597c4
    // - project_number: 185578323389
    // - mobilesdk_app_id: 1:185578323389:android:b93063934bfd00147ee6d4
    // - api_key: AIzaSyC8Bh32_UvNRGBJ4Cf_HIn1dzA9Eg8cXko
    // - storage_bucket: spotlight-597c4.firebasestorage.app
    if (Platform.isAndroid) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyC8Bh32_UvNRGBJ4Cf_HIn1dzA9Eg8cXko',
        appId: '1:185578323389:android:b93063934bfd00147ee6d4',
        messagingSenderId: '185578323389',
        projectId: 'spotlight-597c4',
        storageBucket: 'spotlight-597c4.firebasestorage.app',
      );
    }

    // iOSではGoogleService-Info.plistから自動的に読み込まれるため、null を返す
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
