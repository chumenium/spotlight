import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/bottom_navigation_bar.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'create_post_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import '../auth/social_login_screen.dart';
import '../services/fcm_service.dart';
import '../services/jwt_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// 静止画スプラッシュスクリーン
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // アプリ起動時にFCMトークンを更新
    _updateFcmTokenOnStartup();

    // スプラッシュスクリーンを表示する時間
    const splashDuration = Duration(seconds: 3);

    Future.delayed(splashDuration, () {
      if (mounted) {
        _navigateToNext();
      }
    });
  }

  /// アプリ起動時にFCMトークンをサーバーに送信
  Future<void> _updateFcmTokenOnStartup() async {
    try {
      // JWTトークンを取得
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('🔔 アプリ起動時: JWTトークンが取得できません。FCMトークン更新をスキップします。');
        }
        return;
      }

      // FCMトークンをサーバーに送信
      await FcmService.updateFcmTokenToServer(jwtToken);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ アプリ起動時のFCMトークン更新エラー: $e');
      }
    }
  }

  void _navigateToNext() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // ログイン状態に応じて画面を切り替え
    if (authProvider.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SocialLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SizedBox.expand(
        child: Image.asset(
          'assets/splash/splash.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 画像が見つからない場合のフォールバック
            return const Center(
              child: Text(
                'SpotLight',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// メイン画面（既存のMainScreenをそのまま使用）
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, _) {
        return Scaffold(
          body: IndexedStack(
            index: navigationProvider.currentIndex,
            children: const [
              HomeScreen(),
              SearchScreen(),
              SizedBox.shrink(), // CreatePostScreenは別途モーダルで表示
              NotificationsScreen(),
              ProfileScreen(),
            ],
          ),
          bottomNavigationBar: CustomBottomNavigationBar(
            currentIndex: navigationProvider.currentIndex,
            onTap: (index) {
              if (index == 2) {
                // プラスボタンの場合はモーダルで表示
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const CreatePostModal(),
                );
                // 現在のインデックスを変更しない
                return;
              }
              // 通知ボタンの場合はnavigateToNotifications()を呼ぶ
              if (index == 3) {
                navigationProvider.navigateToNotifications();
              } else {
                navigationProvider.setCurrentIndex(index);
              }
            },
          ),
        );
      },
    );
  }
}
