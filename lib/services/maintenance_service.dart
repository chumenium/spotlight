import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// メンテナンスモードを管理するサービス
class MaintenanceService {
  static const String _maintenanceModeKey = 'maintenance_mode_enabled';
  static const String _maintenanceMessageKey = 'maintenance_message';
  
  // Firebase Remote Configのキー
  static const String _remoteConfigMaintenanceKey = 'maintenance_mode_enabled';
  static const String _remoteConfigMessageKey = 'maintenance_message';
  
  static FirebaseRemoteConfig? _remoteConfig;
  static bool _remoteConfigInitialized = false;

  /// Firebase Remote Configを初期化
  static Future<void> _initializeRemoteConfig() async {
    if (_remoteConfigInitialized && _remoteConfig != null) {
      return;
    }
    
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      
      // デフォルト値を設定
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 1),
      ));
      
      await _remoteConfig!.setDefaults({
        _remoteConfigMaintenanceKey: false,
        _remoteConfigMessageKey: '現在メンテナンス中です。\nしばらくお待ちください。',
      });
      
      // リモート設定を取得（キャッシュがあれば即座に返す）
      try {
        await _remoteConfig!.fetchAndActivate();
      } catch (e) {
        // ネットワークエラーでもキャッシュを使用
        if (kDebugMode) {
          debugPrint('⚠️ Remote Config取得エラー（キャッシュを使用）: $e');
        }
      }
      
      _remoteConfigInitialized = true;
      
      if (kDebugMode) {
        debugPrint('✅ Firebase Remote Config初期化完了');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Firebase Remote Config初期化エラー: $e');
      }
      // Remote Configが使えない場合はローカルのみを使用
    }
  }

  /// メンテナンスモードが有効かどうかを取得（Remote Config + ローカルの両方をチェック）
  static Future<bool> isMaintenanceModeEnabled() async {
    // Remote Configを初期化
    await _initializeRemoteConfig();
    
    // まずRemote Configをチェック（全ユーザー共通）
    try {
      if (_remoteConfig != null && _remoteConfigInitialized) {
        final remoteEnabled = _remoteConfig!.getBool(_remoteConfigMaintenanceKey);
        if (remoteEnabled) {
          if (kDebugMode) {
            debugPrint('🔧 Remote Config: メンテナンスモードが有効です（全ユーザー共通）');
          }
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Remote Config取得エラー: $e');
      }
    }
    
    // Remote Configが無効または取得できない場合は、ローカル設定をチェック（開発者向け）
    try {
      final prefs = await SharedPreferences.getInstance();
      final localEnabled = prefs.getBool(_maintenanceModeKey) ?? false;
      if (localEnabled) {
        if (kDebugMode) {
          debugPrint('🔧 ローカル設定: メンテナンスモードが有効です（このデバイスのみ）');
        }
      }
      return localEnabled;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ メンテナンスモード状態取得エラー: $e');
      }
      return false;
    }
  }

  /// メンテナンスモードを有効化
  static Future<bool> enableMaintenanceMode({String? message}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_maintenanceModeKey, true);
      if (message != null) {
        await prefs.setString(_maintenanceMessageKey, message);
      }
      if (kDebugMode) {
        debugPrint('✅ メンテナンスモードを有効化しました');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ メンテナンスモード有効化エラー: $e');
      }
      return false;
    }
  }

  /// メンテナンスモードを無効化
  static Future<bool> disableMaintenanceMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_maintenanceModeKey, false);
      await prefs.remove(_maintenanceMessageKey);
      if (kDebugMode) {
        debugPrint('✅ メンテナンスモードを無効化しました');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ メンテナンスモード無効化エラー: $e');
      }
      return false;
    }
  }

  /// メンテナンスメッセージを取得（Remote Config優先、なければローカル）
  static Future<String> getMaintenanceMessage() async {
    // Remote Configを初期化
    await _initializeRemoteConfig();
    
    // まずRemote Configから取得
    try {
      if (_remoteConfig != null && _remoteConfigInitialized) {
        final remoteMessage = _remoteConfig!.getString(_remoteConfigMessageKey);
        if (remoteMessage.isNotEmpty && remoteMessage != '現在メンテナンス中です。\nしばらくお待ちください。') {
          return remoteMessage;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Remote Configメッセージ取得エラー: $e');
      }
    }
    
    // Remote Configがない場合は、ローカル設定をチェック
    try {
      final prefs = await SharedPreferences.getInstance();
      final localMessage = prefs.getString(_maintenanceMessageKey);
      if (localMessage != null && localMessage.isNotEmpty) {
        return localMessage;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ メンテナンスメッセージ取得エラー: $e');
      }
    }
    
    return '現在メンテナンス中です。\nしばらくお待ちください。';
  }
  
  /// Remote Configを強制的に再取得（開発者向け）
  static Future<void> refreshRemoteConfig() async {
    try {
      await _initializeRemoteConfig();
      if (_remoteConfig != null) {
        await _remoteConfig!.fetchAndActivate();
        if (kDebugMode) {
          debugPrint('✅ Remote Configを再取得しました');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Remote Config再取得エラー: $e');
      }
    }
  }

  /// メンテナンスメッセージを設定
  static Future<bool> setMaintenanceMessage(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_maintenanceMessageKey, message);
      if (kDebugMode) {
        debugPrint('✅ メンテナンスメッセージを設定しました: $message');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ メンテナンスメッセージ設定エラー: $e');
      }
      return false;
    }
  }

  /// メンテナンスモードをトグル（有効/無効を切り替え）
  static Future<bool> toggleMaintenanceMode({String? message}) async {
    final isEnabled = await isMaintenanceModeEnabled();
    if (isEnabled) {
      return await disableMaintenanceMode();
    } else {
      return await enableMaintenanceMode(message: message);
    }
  }
}

