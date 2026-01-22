import 'package:flutter/material.dart';
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

// バックグラウンドメッセージハンドラー（トップレベル関数である必要がある）
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 バックグラウンドで通知を受信: ${message.messageId}');
  debugPrint('🔔 通知データ: ${message.data}');
  debugPrint('🔔 通知タイトル: ${message.notification?.title}');
  debugPrint('🔔 通知本文: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    // Firebase初期化（FCMトークン初期化も含む）
    await FirebaseService.instance.initialize();
    debugPrint('✅ Firebase & FCM初期化完了');

    // バックグラウンドメッセージハンドラーを登録
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint('✅ バックグラウンドメッセージハンドラー登録完了');
  } catch (e) {
    debugPrint('❌ Firebase/FCM初期化エラー: $e');
  }

  try {
    // AdMob初期化
    await AdService.initialize();
    debugPrint('✅ AdMob初期化完了');
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
