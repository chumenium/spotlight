import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
      return;
    }

    try {
      final options = _getFirebaseOptions();
      if (options == null) {
        // Android/iOSではgoogle-services.jsonから自動読み込み
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(options: options);
      }

      _initialized = true;

      // FCMトークンの自動初期化（Webではスキップ）
      if (!kIsWeb) {
        await _initializeFcm();
      }
    } catch (e, stackTrace) {
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
      await FcmService.initializeNotifications();
    } catch (e) {
      // ignore
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
  void printDebugInfo() {}
}
