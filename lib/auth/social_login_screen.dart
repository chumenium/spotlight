import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'auth_provider.dart';
import '../utils/spotlight_colors.dart';
import '../config/app_config.dart';
import '../providers/navigation_provider.dart';

/// ソーシャルログイン専用画面
/// Google、Twitter（X）でのログインをサポート
/// すべてFirebase Authentication経由で処理されます
class SocialLoginScreen extends StatefulWidget {
  const SocialLoginScreen({super.key});

  @override
  State<SocialLoginScreen> createState() => _SocialLoginScreenState();
}

class _SocialLoginScreenState extends State<SocialLoginScreen> {
  Future<void> _handleGoogleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await authProvider.loginWithGoogle();

    if (success && mounted) {
      // NavigationProviderをリセット（main.dartで自動的にMainScreenに遷移）
      final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.reset();
    } else if (mounted && authProvider.errorMessage != null) {
      _showErrorSnackBar(authProvider.errorMessage!);
    }
  }


  Future<void> _handleTwitterLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await authProvider.loginWithTwitter();

    if (success && mounted) {
      // NavigationProviderをリセット（main.dartで自動的にMainScreenに遷移）
      final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.reset();
    } else if (mounted && authProvider.errorMessage != null) {
      _showErrorSnackBar(authProvider.errorMessage!);
    }
  }

  void _handleSkip() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.skipLogin();
    
    // NavigationProviderをリセット（main.dartで自動的にMainScreenに遷移）
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    navigationProvider.reset();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                
                // ロゴ
                Icon(
                  Icons.flashlight_on,
                  size: 100,
                  color: SpotLightColors.primaryOrange,
                ),
                const SizedBox(height: 24),
                
                // アプリ名
                const Text(
                  'SpotLight',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'あなたの輝きを世界へ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 80),
                
                // ログインメッセージ
                Text(
                  'ログインして始めましょう',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[300],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Googleログインボタン
                if (authProvider.canUseGoogle)
                  _SocialLoginButton(
                    onPressed: authProvider.isLoading ? null : _handleGoogleLogin,
                    icon: SvgPicture.asset(
                      'assets/images/google_logo.svg',
                      width: 24,
                      height: 24,
                    ),
                    label: 'Googleでログイン',
                    backgroundColor: Colors.white,
                    textColor: Colors.black87,
                  ),
                
                if (authProvider.canUseGoogle) const SizedBox(height: 16),
                
                // Twitterログインボタン（X）
                if (authProvider.canUseTwitter)
                  _SocialLoginButton(
                    onPressed: authProvider.isLoading ? null : _handleTwitterLogin,
                    icon: const Icon(
                      Icons.tag,  // Xアイコンの代わり（カスタムアイコン推奨）
                      color: Colors.white,
                      size: 24,
                    ),
                    label: 'X（Twitter）でログイン',
                    backgroundColor: Colors.black,  // Xのブランドカラー
                    textColor: Colors.white,
                  ),
                
                const SizedBox(height: 32),
                
                // ローディングインジケーター
                if (authProvider.isLoading)
                  Center(
                    child: CircularProgressIndicator(
                      color: SpotLightColors.primaryOrange,
                    ),
                  ),
                
                const SizedBox(height: 40),
                
                // 利用規約
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text.rich(
                    TextSpan(
                      text: 'ログインすることで、',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                      children: [
                        TextSpan(
                          text: '利用規約',
                          style: TextStyle(
                            color: SpotLightColors.primaryOrange,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: 'と'),
                        TextSpan(
                          text: 'プライバシーポリシー',
                          style: TextStyle(
                            color: SpotLightColors.primaryOrange,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: 'に同意したものとみなされます'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // 開発モードのみ表示：スキップボタン
                if (AppConfig.canSkipAuth) ...[
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _handleSkip,
                    child: Text(
                      '⚠️ スキップ（開発モード）',
                      style: TextStyle(
                        color: Colors.yellow[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ソーシャルログインボタンウィジェット
class _SocialLoginButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _SocialLoginButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: onPressed == null ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

