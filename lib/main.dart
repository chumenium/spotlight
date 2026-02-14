import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrintSynchronously;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/navigation_provider.dart';
import 'providers/theme_provider.dart' show ThemeProvider, AppThemeMode;
import 'auth/auth_provider.dart';
import 'services/firebase_service.dart';
import 'services/ad_service.dart';
import 'screens/splash_screen.dart';
import 'utils/route_observer.dart';
import 'config/app_config.dart';

/// ログフィルタリング付きdebugPrint
/// verboseLog=false の場合、エラー(❌)と警告(⚠️)のみ表示
/// URLは自動除去し、簡潔に出力
void _filteredDebugPrint(String? message, {int? wrapWidth}) {
  if (message == null || !kDebugMode) return;

  // 詳細ログモードなら全部出す
  if (AppConfig.verboseLog) {
    debugPrintSynchronously(message, wrapWidth: wrapWidth);
    return;
  }

  // エラー・警告のみ通す
  if (!message.contains('❌') && !message.contains('⚠️')) return;

  // URLを除去して簡潔に
  final filtered = message.replaceAll(RegExp(r'https?://\S+'), '').trim();
  if (filtered.isEmpty) return;

  debugPrintSynchronously(filtered, wrapWidth: wrapWidth);
}

// バックグラウンドメッセージハンドラー（トップレベル関数である必要がある）
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // バックグラウンド通知受信（詳細ログはverboseLog時のみ）
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // debugPrintをフィルタリング版に置き換え
  debugPrint = _filteredDebugPrint;

  // ステータスバーを表示（全画面で有効）
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top],
  );

  // ステータスバーのスタイルを設定（ライトテーマ用）
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  try {
    await FirebaseService.instance.initialize();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('❌ Firebase/FCM初期化エラー: $e');
  }

  try {
    await AdService.initialize();
  } catch (e) {
    debugPrint('❌ AdMob初期化エラー: $e');
  }

  runApp(const SpotLightApp());
}

class SpotLightApp extends StatelessWidget {
  const SpotLightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
        ChangeNotifierProvider(create: (context) => AuthProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  themeProvider.themeMode == AppThemeMode.light
                      ? Brightness.dark
                      : Brightness.light,
              statusBarBrightness: themeProvider.themeMode == AppThemeMode.light
                  ? Brightness.light
                  : Brightness.dark,
            ),
            child: MaterialApp(
              title: 'SpotLight',
              theme: themeProvider.getLightTheme(),
              darkTheme: themeProvider.getDarkTheme(),
              themeMode: themeProvider.getMaterialThemeMode(),
              navigatorObservers: [routeObserver],
              home: const SplashScreen(), // スプラッシュスクリーンを最初に表示
            ),
          );
        },
      ),
    );
  }
}
