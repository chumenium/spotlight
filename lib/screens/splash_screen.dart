import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_links/app_links.dart';
import '../providers/navigation_provider.dart';
import '../widgets/bottom_navigation_bar.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'create_post_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'playlist_detail_screen.dart';
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
  bool _isExpired = false; // 半年以上経過しているかどうか

  @override
  void initState() {
    super.initState();

    // スプラッシュ画像を事前に読み込む（フルサイズで表示されるように）
    _precacheSplashImage();

    // アプリ起動時に認証状態をチェックしてから画面遷移
    _initializeAndNavigate();
  }

  /// スプラッシュ画像を事前に読み込む
  Future<void> _precacheSplashImage() async {
    try {
      // BuildContextが利用可能になるまで待つ
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          try {
            final imageProvider = AssetImage('assets/splash/splash.png');
            await precacheImage(imageProvider, context);
            if (kDebugMode) {
              debugPrint('✅ スプラッシュ画像を事前読み込みしました');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ スプラッシュ画像の事前読み込みエラー: $e');
            }
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ スプラッシュ画像の事前読み込み初期化エラー: $e');
      }
    }
  }

  /// 認証状態をチェックしてから画面遷移
  Future<void> _initializeAndNavigate() async {
    final startTime = DateTime.now();

    // 認証状態をチェック
    await _checkAuthStateOnStartup();

    // 半年未満でJWTトークンが存在する場合は、Firebase Authenticationのセッション復元を待つ
    if (!_isExpired) {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken != null) {
        // Firebase Authenticationのセッション復元を待つ（最大2秒）
        await _waitForAuthRestore();
      }
    }

    // スプラッシュスクリーンを表示する時間（最小3秒）
    const splashDuration = Duration(seconds: 3);
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < splashDuration) {
      await Future.delayed(splashDuration - elapsed);
    }

    if (mounted) {
      _navigateToNext();
    }
  }

  /// Firebase Authenticationのセッション復元を待つ
  Future<void> _waitForAuthRestore() async {
    try {
      final auth = firebase_auth.FirebaseAuth.instance;

      // 既にcurrentUserが存在する場合は即座に返す
      if (auth.currentUser != null) {
        if (kDebugMode) {
          debugPrint('🔐 Firebase Authenticationのセッションが既に復元されています。');
        }
        return;
      }

      // authStateChanges()の最初のイベントを待つ（最大2秒）
      try {
        await auth.authStateChanges().first.timeout(
              const Duration(seconds: 2),
            );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Firebase Authenticationのセッション復元待機がタイムアウトしました。');
        }
      }

      if (kDebugMode) {
        final currentUser = auth.currentUser;
        if (currentUser != null) {
          debugPrint(
              '🔐 Firebase Authenticationのセッションが復元されました: ${currentUser.uid}');
        } else {
          debugPrint('⚠️ Firebase Authenticationのセッションが復元されませんでした。');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Firebase Authenticationのセッション復元待機エラー: $e');
      }
    }
  }

  /// アプリ起動時に認証状態をチェック
  Future<void> _checkAuthStateOnStartup() async {
    try {
      // 最後の利用日時をチェック
      _isExpired = await JwtService.isLastAccessExpired();

      if (_isExpired) {
        // 半年以上経過している場合は、認証情報をクリア
        if (kDebugMode) {
          debugPrint('🔐 最後の利用から半年以上経過しています。認証情報をクリアします。');
        }

        // JWTトークンとユーザー情報をクリア
        await JwtService.clearAll();

        // Firebase Authenticationのセッションもクリア
        try {
          await firebase_auth.FirebaseAuth.instance.signOut();
          if (kDebugMode) {
            debugPrint('🔐 Firebase Authenticationのセッションをクリアしました。');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Firebase Authenticationのセッションクリアエラー: $e');
          }
        }
      } else {
        // 半年未満の場合は、最後の利用日時を更新
        await JwtService.saveLastAccessTime();

        // FCMトークンを更新（非同期で実行）
        _updateFcmTokenOnStartup();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 認証状態チェックエラー: $e');
      }
      // エラーが発生した場合は、期限切れとみなす
      _isExpired = true;
      await JwtService.clearAll();
    }
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

  void _navigateToNext() async {
    // 半年以上経過している場合は、ログイン画面に遷移
    if (_isExpired) {
      if (kDebugMode) {
        debugPrint('🔐 半年以上経過しているため、ログイン画面に遷移します。');
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SocialLoginScreen()),
      );
      return;
    }

    // 半年未満の場合は、ログイン状態を確認
    // Firebase AuthenticationのcurrentUserとJWTトークンの両方を確認
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final jwtToken = await JwtService.getJwtToken();

    // 両方が存在する場合は、ログイン済みと判定してホーム画面に直接遷移
    if (firebaseUser != null && jwtToken != null) {
      if (kDebugMode) {
        debugPrint('🔐 ログイン状態が維持されているため、ホーム画面に直接遷移します。');
        debugPrint('  - Firebase User: ${firebaseUser.uid}');
        debugPrint('  - JWT Token: 存在');
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
      return;
    }

    // ログイン状態が復元されていない場合は、ログイン画面に遷移
    if (kDebugMode) {
      debugPrint('🔐 ログイン状態が復元されていないため、ログイン画面に遷移します。');
      debugPrint('  - Firebase User: ${firebaseUser?.uid ?? "null"}');
      debugPrint('  - JWT Token: ${jwtToken != null ? "存在" : "null"}');
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SocialLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 画面サイズを取得してフルサイズで表示
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Image.asset(
          'assets/splash/splash.png',
          width: size.width,
          height: size.height,
          fit: BoxFit.cover,
          // 元画像の解像度を維持（cacheWidth/cacheHeightを削除）
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            // 画像が見つからない場合のフォールバック
            return Container(
              width: size.width,
              height: size.height,
              color: const Color(0xFF121212),
              child: const Center(
                child: Text(
                  'SpotLight',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// メイン画面
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    // プッシュ通知のハンドラーを設定
    _setupNotificationHandlers();
    _setupDeepLinkHandlers();
  }

  /// プッシュ通知のハンドラーを設定
  void _setupNotificationHandlers() {
    // アプリがバックグラウンド状態で通知をタップした場合
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('🔔 バックグラウンドから通知をタップ: ${message.messageId}');
        debugPrint('🔔 通知データ: ${message.data}');
      }
      _handleNotificationTap(message);
    });

    // アプリが終了状態から通知をタップして起動した場合
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          debugPrint('🔔 終了状態から通知をタップして起動: ${message.messageId}');
          debugPrint('🔔 通知データ: ${message.data}');
        }
        // 少し遅延させてから処理（MainScreenが完全に構築されてから）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationTap(message);
        });
      }
    });
  }

  void _setupDeepLinkHandlers() {
    _appLinks = AppLinks();
    _appLinks!.getInitialLink().then((uri) {
      if (uri != null) {
        _handleIncomingUri(uri);
      }
    });
    _linkSubscription = _appLinks!.uriLinkStream.listen(
      (uri) {
        _handleIncomingUri(uri);
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('⚠️ ディープリンク受信エラー: $error');
        }
      },
    );
  }

  void _handleIncomingUri(Uri uri) {
    if (!mounted) return;

    if (uri.scheme != 'spotlight') {
      return;
    }

    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);

    if (uri.host == 'content') {
      final contentId =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (contentId == null || contentId.isEmpty) {
        return;
      }
      navigationProvider.navigateToHome(postId: contentId);
      if (kDebugMode) {
        debugPrint('🔗 ディープリンク: contentId=$contentId');
      }
      return;
    }

    if (uri.host == 'playlist') {
      final playlistIdStr =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      final playlistId = int.tryParse(playlistIdStr ?? '');
      if (playlistId == null || playlistId <= 0) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(
              playlistId: playlistId,
              playlistTitle: 'プレイリスト',
            ),
          ),
        );
      });
      if (kDebugMode) {
        debugPrint('🔗 ディープリンク: playlistId=$playlistId');
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    super.dispose();
  }

  /// 通知タップ時の処理
  void _handleNotificationTap(RemoteMessage message) {
    if (!mounted) return;

    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    
    // 通知画面に遷移
    navigationProvider.navigateToNotifications();
    
    if (kDebugMode) {
      debugPrint('✅ 通知画面に遷移しました');
    }
  }

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
