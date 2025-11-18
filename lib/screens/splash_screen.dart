import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
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

/// アニメーション付きスプラッシュスクリーン
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // フェードアニメーション用のコントローラー
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    // アニメーション開始
    _controller.forward();
    
    // スプラッシュスクリーンを表示する時間（ミリ秒）
    // アニメーションの長さに合わせて調整してください
    const splashDuration = Duration(seconds: 3);
    
    Future.delayed(splashDuration, () {
      if (mounted) {
        _navigateToNext();
      }
    });
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // アプリの背景色に合わせる
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottieアニメーションを表示
              // ファイル名: assets/splash/splash_animation.json
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.width * 0.8,
                child: Lottie.asset(
                  'assets/splash/splash_animation.json',
                  fit: BoxFit.contain,
                  repeat: true, // ループ再生
                  // repeat: false, // 1回のみ再生する場合はこちら
                ),
              ),
              // オプション: アプリ名やロゴを追加
              // const SizedBox(height: 32),
              // Text(
              //   'SpotLight',
              //   style: TextStyle(
              //     fontSize: 32,
              //     fontWeight: FontWeight.bold,
              //     color: Colors.white,
              //   ),
              // ),
            ],
          ),
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
              navigationProvider.setCurrentIndex(index);
            },
          ),
        );
      },
    );
  }
}

