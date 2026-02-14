import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import 'auth_provider.dart';
import '../utils/spotlight_colors.dart';
import '../providers/navigation_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/tutorial_screen.dart';

/// ソーシャルログイン専用画面
/// Google/Appleでのログインをサポート
/// すべてFirebase Authentication経由で処理されます
class SocialLoginScreen extends StatefulWidget {
  const SocialLoginScreen({super.key});

  @override
  State<SocialLoginScreen> createState() => _SocialLoginScreenState();
}

class _SocialLoginScreenState extends State<SocialLoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _sparkleController;
  late AnimationController _shineController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _sparkleAnimation;
  late Animation<double> _shineAnimation;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();

    // ロゴアニメーション（スケール + 回転）
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );
    _logoRotationAnimation = Tween<double>(begin: -0.2, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOut,
      ),
    );

    // フェードインアニメーション
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeIn,
      ),
    );

    // スライドインアニメーション
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );

    // パルスアニメーション（ロゴの光る効果）
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // キラキラアニメーション
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sparkleController,
        curve: Curves.linear,
      ),
    );

    // シャインアニメーション（光る効果）
    _shineController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();
    _shineAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _shineController,
        curve: Curves.linear,
      ),
    );

    // アニメーション開始
    _logoController.forward();
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });

    // ログイン済みの場合は自動的にホーム画面にリダイレクト
    _checkLoginState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _sparkleController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  /// ログイン状態をチェックして、ログイン済みの場合はホーム画面にリダイレクト
  Future<void> _checkLoginState() async {
    // 少し待機してFirebase Authenticationのセッション復元を待つ
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // ログイン済みの場合はホーム画面にリダイレクト
    if (authProvider.isLoggedIn) {
      // NavigationProviderをリセット
      final navigationProvider =
          Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.reset();
      // MainScreenに遷移
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }
  Future<void> _handleGoogleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.loginWithGoogle();

    if (success && mounted) {
      // NavigationProviderをリセット
      final navigationProvider =
          Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.reset();
      if (authProvider.lastLoginWasNewUser) {
        // 新規登録時のみチュートリアルに遷移
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const TutorialScreen(nextScreen: MainScreen()),
          ),
        );
      } else {
        // 既存アカウントは直接ホームへ
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } else if (mounted && authProvider.errorMessage != null) {
      _showErrorSnackBar(authProvider.errorMessage!);
    }
  }

  Future<void> _handleAppleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.loginWithApple();

    if (!mounted) {
      return;
    }

    if (success) {
      final navigationProvider =
          Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.reset();
      if (authProvider.lastLoginWasNewUser) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const TutorialScreen(nextScreen: MainScreen()),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } else if (authProvider.errorMessage != null) {
      _showErrorSnackBar(authProvider.errorMessage!);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Google新規登録もloginWithGoogleを使用（Firebase側で自動的に新規/既存を判定）
    final success = await authProvider.loginWithGoogle();

    if (success && mounted) {
      // NavigationProviderをリセット
      final navigationProvider =
          Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.reset();
      if (authProvider.lastLoginWasNewUser) {
        // 新規登録時のみチュートリアルに遷移
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const TutorialScreen(nextScreen: MainScreen()),
          ),
        );
        // 新規登録成功のメッセージを表示
        _showSuccessSnackBar('アカウントが作成されました！');
      } else {
        // 既存アカウントは直接ホームへ
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } else if (mounted && authProvider.errorMessage != null) {
      _showErrorSnackBar(authProvider.errorMessage!);
    }
  }

  Future<void> _handleAppleSignUp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.loginWithApple();

    if (!mounted) {
      return;
    }

    if (success) {
      final navigationProvider =
          Provider.of<NavigationProvider>(context, listen: false);
      navigationProvider.reset();
      if (authProvider.lastLoginWasNewUser) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const TutorialScreen(nextScreen: MainScreen()),
          ),
        );
        _showSuccessSnackBar('アカウントが作成されました！');
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } else if (authProvider.errorMessage != null) {
      _showErrorSnackBar(authProvider.errorMessage!);
    }
  }

  void _showErrorSnackBar(String message) {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (!mounted ||
        _scaffoldMessenger == null ||
        !_scaffoldMessenger!.mounted ||
        (lifecycleState != null &&
            lifecycleState != AppLifecycleState.resumed)) {
      return;
    }
    _scaffoldMessenger!.showSnackBar(
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

  void _showSuccessSnackBar(String message) {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (!mounted ||
        _scaffoldMessenger == null ||
        !_scaffoldMessenger!.mounted ||
        (lifecycleState != null &&
            lifecycleState != AppLifecycleState.resumed)) {
      return;
    }
    _scaffoldMessenger!.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF121212),
              const Color(0xFF1A1A1A),
              const Color(0xFF0F0F0F),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 背景の光るエフェクト（強化版）
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return AnimatedBuilder(
                      animation: _sparkleController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _GlowPainter(
                            pulseValue: _pulseAnimation.value,
                            sparkleValue: _sparkleAnimation.value,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // メインコンテンツ
              Column(
                children: [
                  // 上部スクロール可能エリア
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ロゴ（キラキラアニメーション付き）
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: ScaleTransition(
                                scale: _logoScaleAnimation,
                                child: RotationTransition(
                                  turns: _logoRotationAnimation,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // キラキラパーティクル
                                      AnimatedBuilder(
                                        animation: _sparkleController,
                                        builder: (context, child) {
                                          return AnimatedBuilder(
                                            animation: _pulseController,
                                            builder: (context, child) {
                                              return CustomPaint(
                                                size: const Size(200, 200),
                                                painter: _SparklePainter(
                                                  sparkleValue: _sparkleAnimation.value,
                                                  pulseValue: _pulseAnimation.value,
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      // ロゴ本体
                                      AnimatedBuilder(
                                        animation: Listenable.merge([
                                          _pulseController,
                                          _shineController,
                                        ]),
                                        builder: (context, child) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: SpotLightColors.primaryOrange
                                                      .withOpacity(0.5 * _pulseAnimation.value),
                                                  blurRadius: 50 * _pulseAnimation.value,
                                                  spreadRadius: 20 * _pulseAnimation.value,
                                                ),
                                                BoxShadow(
                                                  color: SpotLightColors.lightOrange
                                                      .withOpacity(0.3 * _pulseAnimation.value),
                                                  blurRadius: 80 * _pulseAnimation.value,
                                                  spreadRadius: 30 * _pulseAnimation.value,
                                                ),
                                              ],
                                            ),
                                            child: ShaderMask(
                                              shaderCallback: (bounds) {
                                                return LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    SpotLightColors.primaryOrange,
                                                    SpotLightColors.lightOrange,
                                                    SpotLightColors.goldenYellow,
                                                    SpotLightColors.primaryOrange,
                                                  ],
                                                  stops: [
                                                    0.0,
                                                    0.3 + (_shineAnimation.value * 0.2).clamp(0.0, 0.3),
                                                    0.6 + (_shineAnimation.value * 0.2).clamp(0.0, 0.3),
                                                    1.0,
                                                  ],
                                                ).createShader(bounds);
                                              },
                                              child: Icon(
                                                Icons.flashlight_on,
                                                size: 100 * _pulseAnimation.value,
                                                color: Colors.white,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // アプリ名
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: ShaderMask(
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        SpotLightColors.primaryOrange,
                                        SpotLightColors.goldenYellow,
                                        SpotLightColors.lightOrange,
                                        SpotLightColors.primaryOrange,
                                      ],
                                    ).createShader(bounds);
                                  },
                                  child: const Text(
                                    'Spotlight',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 10,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                              const SizedBox(height: 16),
                              
                              // サブタイトル（フェードイン）
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: Text(
                                    'あなたの輝きを世界へ',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[400],
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // 下部固定エリア
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ログインセクション
                        Column(
                          children: [
                            Text(
                              'ログイン',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[300],
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Googleログインボタン
                            if (authProvider.canUseGoogle)
                              _SocialLoginButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : _handleGoogleLogin,
                                icon: SvgPicture.asset(
                                  'assets/images/google_logo.svg',
                                  width: 24,
                                  height: 24,
                                ),
                                label: 'Googleでログイン',
                                backgroundColor: Colors.white,
                                textColor: Colors.black87,
                              ),
                            if (authProvider.canUseApple) ...[
                              const SizedBox(height: 12),
                              _SocialLoginButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : _handleAppleLogin,
                                icon: const Icon(
                                  Icons.apple,
                                  size: 26,
                                  color: Colors.white,
                                ),
                                label: 'Appleでログイン',
                                backgroundColor: Colors.black,
                                textColor: Colors.white,
                              ),
                            ],
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // 区切り線
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.grey[600]!,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'または',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey[600]!,
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // 新規登録セクション
                        Column(
                          children: [
                            Text(
                              'アカウント新規登録',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[300],
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Google新規登録ボタン
                            if (authProvider.canUseGoogle)
                              _SocialLoginButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : _handleGoogleSignUp,
                                icon: SvgPicture.asset(
                                  'assets/images/google_logo.svg',
                                  width: 24,
                                  height: 24,
                                ),
                                label: 'Googleでアカウント作成',
                                backgroundColor: SpotLightColors.primaryOrange,
                                textColor: Colors.white,
                                isGradient: true,
                              ),
                            if (authProvider.canUseApple) ...[
                              const SizedBox(height: 12),
                              _SocialLoginButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : _handleAppleSignUp,
                                icon: const Icon(
                                  Icons.apple,
                                  size: 26,
                                  color: Colors.white,
                                ),
                                label: 'Appleでアカウント作成',
                                backgroundColor: Colors.black,
                                textColor: Colors.white,
                              ),
                            ],
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // ローディングインジケーター
                        if (authProvider.isLoading)
                          Center(
                            child: CircularProgressIndicator(
                              color: SpotLightColors.primaryOrange,
                              strokeWidth: 3,
                            ),
                          ),
                        
                        const SizedBox(height: 24),
                        
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
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ソーシャルログインボタンウィジェット
class _SocialLoginButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final bool isGradient;

  const _SocialLoginButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.isGradient = false,
  });

  @override
  State<_SocialLoginButton> createState() => _SocialLoginButtonState();
}

class _SocialLoginButtonState extends State<_SocialLoginButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _tapController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _tapController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _tapController.reverse();
  }

  void _handleTapCancel() {
    _tapController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? _handleTapDown : null,
      onTapUp: widget.onPressed != null ? _handleTapUp : null,
      onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: widget.isGradient
                ? LinearGradient(
                    colors: [
                      SpotLightColors.primaryOrange,
                      SpotLightColors.lightOrange,
                    ],
                  )
                : null,
            color: widget.isGradient ? null : widget.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.onPressed != null
                ? [
                    BoxShadow(
                      color: widget.isGradient
                          ? SpotLightColors.primaryOrange.withOpacity(0.3)
                          : widget.backgroundColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    widget.icon,
                    const SizedBox(width: 16),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 背景の光るエフェクト用のカスタムペインター（強化版）
class _GlowPainter extends CustomPainter {
  final double pulseValue;
  final double sparkleValue;

  _GlowPainter({
    required this.pulseValue,
    this.sparkleValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 左上の光（激しく強化）
    final gradient1 = RadialGradient(
      colors: [
        SpotLightColors.primaryOrange.withOpacity(0.5 * pulseValue),
        SpotLightColors.lightOrange.withOpacity(0.4 * pulseValue),
        SpotLightColors.goldenYellow.withOpacity(0.3 * pulseValue),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    );
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.2),
      size.width * 0.7 * pulseValue,
      Paint()..shader = gradient1.createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.2, size.height * 0.2),
          radius: size.width * 0.7 * pulseValue,
        ),
      ),
    );

    // 右下の光（激しく強化）
    final gradient2 = RadialGradient(
      colors: [
        SpotLightColors.lightOrange.withOpacity(0.45 * pulseValue),
        SpotLightColors.goldenYellow.withOpacity(0.35 * pulseValue),
        SpotLightColors.primaryOrange.withOpacity(0.25 * pulseValue),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.8),
      size.width * 0.8 * pulseValue,
      Paint()..shader = gradient2.createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.8, size.height * 0.8),
          radius: size.width * 0.8 * pulseValue,
        ),
      ),
    );

    // 中央上部の追加の光（激しく強化、キラキラ効果）
    final sparkleIntensity = 0.5 + math.sin(sparkleValue * math.pi * 2) * 0.5;
    final gradient3 = RadialGradient(
      colors: [
        SpotLightColors.goldenYellow.withOpacity(0.4 * pulseValue * sparkleIntensity),
        SpotLightColors.primaryOrange.withOpacity(0.35 * pulseValue * sparkleIntensity),
        SpotLightColors.lightOrange.withOpacity(0.25 * pulseValue * sparkleIntensity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 0.7, 1.0],
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.3),
      size.width * 0.6 * pulseValue,
      Paint()..shader = gradient3.createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.3),
          radius: size.width * 0.6 * pulseValue,
        ),
      ),
    );

    // 追加のフレアエフェクト（中央左）
    final gradient4 = RadialGradient(
      colors: [
        SpotLightColors.primaryOrange.withOpacity(0.3 * pulseValue * (0.7 + math.sin(sparkleValue * math.pi * 3) * 0.3)),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.5),
      size.width * 0.5 * pulseValue,
      Paint()..shader = gradient4.createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.15, size.height * 0.5),
          radius: size.width * 0.5 * pulseValue,
        ),
      ),
    );

    // 追加のフレアエフェクト（中央右）
    final gradient5 = RadialGradient(
      colors: [
        SpotLightColors.goldenYellow.withOpacity(0.3 * pulseValue * (0.7 + math.cos(sparkleValue * math.pi * 3) * 0.3)),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.5),
      size.width * 0.5 * pulseValue,
      Paint()..shader = gradient5.createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * 0.5),
          radius: size.width * 0.5 * pulseValue,
        ),
      ),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.sparkleValue != sparkleValue;
  }
}

/// ロゴ周りのキラキラパーティクル用のカスタムペインター
class _SparklePainter extends CustomPainter {
  final double sparkleValue;
  final double pulseValue;

  _SparklePainter({
    required this.sparkleValue,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 80.0 * pulseValue;
    
    // キラキラパーティクルを描画
    for (int i = 0; i < 20; i++) {
      final angle = (i * math.pi * 2 / 20) + (sparkleValue * math.pi * 2);
      final distance = radius + (math.sin(sparkleValue * math.pi * 2 + i) * 20);
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      
      final sparkleSize = 3.0 + (math.sin(sparkleValue * math.pi * 4 + i) * 2);
      final opacity = (0.3 + math.sin(sparkleValue * math.pi * 2 + i * 0.5) * 0.7).clamp(0.0, 1.0);
      
      final paint = Paint()
        ..color = SpotLightColors.goldenYellow.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      
      // 星型を描画
      _drawStar(canvas, Offset(x, y), sparkleSize, paint);
      
      // 追加の小さなキラキラ
      if (i % 3 == 0) {
        final smallPaint = Paint()
          ..color = SpotLightColors.primaryOrange.withOpacity(opacity * 0.6)
          ..style = PaintingStyle.fill;
        _drawStar(canvas, Offset(x, y), sparkleSize * 0.5, smallPaint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final outerRadius = size;
    final innerRadius = size * 0.4;
    
    for (int i = 0; i < 5; i++) {
      final angle = (i * math.pi * 2 / 5) - (math.pi / 2);
      final outerX = center.dx + math.cos(angle) * outerRadius;
      final outerY = center.dy + math.sin(angle) * outerRadius;
      
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      
      final innerAngle = angle + (math.pi / 5);
      final innerX = center.dx + math.cos(innerAngle) * innerRadius;
      final innerY = center.dy + math.sin(innerAngle) * innerRadius;
      path.lineTo(innerX, innerY);
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) {
    return oldDelegate.sparkleValue != sparkleValue ||
        oldDelegate.pulseValue != pulseValue;
  }
}

