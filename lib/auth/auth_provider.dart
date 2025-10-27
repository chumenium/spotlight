import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:twitter_login/twitter_login.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/firebase_config.dart';
import '../config/app_config.dart';
import 'auth_config.dart';
import 'auth_service.dart';
import '../services/jwt_service.dart';
import '../services/fcm_service.dart';

/// アプリ内で使用するユーザーモデル
/// 
/// Firebase Authenticationから取得した情報をアプリ用に整形して保持します
/// 
/// 重要: `id`フィールドにはFirebase UIDが格納されます
/// このIDは以下の特性を持ちます:
/// - すべての認証プロバイダーで一意
/// - 変更されない永続的な識別子
/// - データベースのユーザー識別子として使用
class User {
  /// ユーザーID（Firebase UID）
  /// 
  /// Firebase Authenticationが自動生成した一意のID
  /// データベースでのユーザー識別に使用します
  final String id;

  /// メールアドレス
  /// 
  /// ソーシャルログインから取得したメールアドレス
  /// 注意: Apple Sign-Inの場合、ユーザーがメールを隠すことがあります
  final String email;

  /// ユーザー名（表示名）
  /// 
  /// ソーシャルログインから取得した表示名
  /// プロバイダーが提供しない場合は、メールアドレスから生成されます
  final String username;

  /// プロフィール画像URL
  /// 
  /// ソーシャルログインから取得したプロフィール画像のURL
  /// プロバイダーが提供しない場合はnull
  final String? avatarUrl;

  User({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
  });
}

/// 認証状態を管理するProvider
/// 
/// Firebase Authenticationと連携してユーザーの認証状態を管理します
/// ソーシャルログイン（Google、Apple、Twitter）専用
/// 
/// 主な機能:
/// - Google Sign-In
/// - Apple Sign-In（iOS）
/// - Twitter Sign-In
/// - 認証状態の監視
/// - ログアウト
class AuthProvider extends ChangeNotifier {
  // ==========================================================================
  // Firebase Authentication インスタンス
  // ==========================================================================
  
  /// Firebase Authenticationのインスタンス
  /// すべての認証処理はこのインスタンスを通じて行われます
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  
  /// Google Sign-Inのインスタンス
  /// Google認証フローの管理に使用
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  /// Twitter Sign-Inのインスタンス
  /// Twitter Developer Portalで取得したAPIキーで初期化されます
  TwitterLogin? _twitterLogin;
  
  // ==========================================================================
  // 状態管理
  // ==========================================================================
  
  /// 現在ログインしているユーザー情報
  /// nullの場合は未ログイン状態
  User? _currentUser;

  /// ローディング状態
  /// 認証処理中はtrueになります
  bool _isLoading = false;

  /// エラーメッセージ
  /// 認証エラー発生時にメッセージが格納されます
  String? _errorMessage;

  // ==========================================================================
  // Getter
  // ==========================================================================

  /// 現在のユーザー情報を取得
  User? get currentUser => _currentUser;

  /// ログイン状態を取得
  bool get isLoggedIn => _currentUser != null;

  /// ローディング状態を取得
  bool get isLoading => _isLoading;

  /// エラーメッセージを取得
  String? get errorMessage => _errorMessage;
  
  /// Google Sign-Inが利用可能か
  bool get canUseGoogle => FirebaseConfig.enableGoogleSignIn;

  /// Twitter Sign-Inが利用可能か（X）
  bool get canUseTwitter => FirebaseConfig.enableTwitterSignIn;

  // ==========================================================================
  // 初期化
  // ==========================================================================

  AuthProvider() {
    // Firebase Authの状態変化を監視
    // ユーザーがログイン/ログアウトすると自動的に通知されます
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// TwitterLoginインスタンスを取得（遅延初期化）
  TwitterLogin? get _getTwitterLogin {
    if (_twitterLogin == null) {
      try {
        _twitterLogin = TwitterLogin(
          apiKey: AuthConfig.twitterApiKey,
          apiSecretKey: AuthConfig.twitterApiSecretKey,
          redirectURI: AuthConfig.twitterRedirectUri,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Twitter Login初期化エラー: $e');
        }
        return null;
      }
    }
    return _twitterLogin;
  }

  /// 認証状態が変化したときの処理
  /// 
  /// Firebase Authenticationから通知されるユーザー情報を
  /// アプリ用のUserモデルに変換して保存します
  /// 
  /// パラメータ:
  /// - firebaseUser: Firebase Authenticationのユーザー情報
  void _onAuthStateChanged(firebase_auth.User? firebaseUser) {
    if (firebaseUser != null) {
      // Firebase UIDをそのままユーザーIDとして使用
      // このIDは変更されず、すべての認証プロバイダーで一意です
      _currentUser = User(
        id: firebaseUser.uid, // Firebase UID（変更されない一意のID）
        email: firebaseUser.email ?? '',
        username: _extractUsername(firebaseUser),
        avatarUrl: firebaseUser.photoURL,
      );

      if (kDebugMode && AuthConfig.enableAuthDebugLog) {
        debugPrint('🔐 ユーザーログイン: ${firebaseUser.uid}');
        debugPrint('  プロバイダー: ${firebaseUser.providerData.map((e) => e.providerId).join(', ')}');
      }
    } else {
      _currentUser = null;
      if (kDebugMode && AuthConfig.enableAuthDebugLog) {
        debugPrint('🔐 ユーザーログアウト');
      }
    }
    notifyListeners();
  }

  /// Firebase Userからユーザー名を抽出
  /// 
  /// 優先順位:
  /// 1. displayName（プロバイダーが提供した表示名）
  /// 2. メールアドレスの@より前の部分
  /// 3. デフォルト値「ユーザー」
  String _extractUsername(firebase_auth.User firebaseUser) {
    if (firebaseUser.displayName != null && firebaseUser.displayName!.isNotEmpty) {
      return firebaseUser.displayName!;
    }
    
    if (firebaseUser.email != null && firebaseUser.email!.contains('@')) {
      return firebaseUser.email!.split('@')[0];
    }
    
    return 'ユーザー';
  }

  // ==========================================================================
  // Google Sign-In
  // ==========================================================================

  /// Google Sign-Inでログイン
  /// 
  /// Google認証フローを使用してログインします
  /// 
  /// 処理の流れ:
  /// 1. Google Sign-Inダイアログを表示
  /// 2. ユーザーがGoogleアカウントを選択
  /// 3. Google認証情報（accessToken、idToken）を取得
  /// 4. Firebase Authenticationに認証情報を送信
  /// 5. Firebase UIDが自動的に生成される（新規ユーザーの場合）
  /// 6. authStateChangesリスナーが発火し、ユーザー情報が更新される
  /// 
  /// 戻り値:
  /// - true: ログイン成功
  /// - false: ログイン失敗またはキャンセル
  /// 
  /// 取得される情報:
  /// - Firebase UID（自動生成、変更されない一意のID）
  /// - メールアドレス
  /// - 表示名
  /// - プロフィール画像URL
  Future<bool> loginWithGoogle() async {
    // 設定で無効化されている場合はエラー
    if (!FirebaseConfig.enableGoogleSignIn) {
      _errorMessage = 'Googleログインは現在無効になっています';
      return false;
    }

    try {
      // ローディング開始
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (kDebugMode && AuthConfig.enableAuthDebugLog) {
        debugPrint('🔐 [Google] Sign-In開始');
      }

      // STEP 1: Googleサインインフローを開始
      // Google Sign-Inダイアログが表示され、ユーザーがアカウントを選択
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // ユーザーがサインインをキャンセルした場合
        if (kDebugMode && AuthConfig.enableAuthDebugLog) {
          debugPrint('🔐 [Google] ユーザーがキャンセル');
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (kDebugMode && AuthConfig.enableAuthDebugLog) {
        debugPrint('🔐 [Google] 認証情報取得: ${googleUser.email}');
      }

      // STEP 2: Google認証情報（accessToken、idToken）を取得
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // STEP 3: Firebase用の認証情報を作成
      // GoogleのトークンをFirebaseで使用できる形式に変換
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // STEP 4: Firebaseにサインイン
      // この時点でFirebase UIDが自動生成されます（新規ユーザーの場合）
      // 既存ユーザーの場合は、既存のUIDが使用されます
      // authStateChangesリスナーが発火し、_onAuthStateChangedが呼ばれます
      await _firebaseAuth.signInWithCredential(credential);

      if (kDebugMode && AuthConfig.enableAuthDebugLog) {
        debugPrint('🔐 [Google] Sign-In成功');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      // Firebase認証エラー
      _isLoading = false;
      _errorMessage = AuthService.getAuthErrorMessage(e);
      if (kDebugMode) {
        debugPrint('🔐 [Google] Firebaseエラー: ${e.code} - ${e.message}');
      }
      notifyListeners();
      return false;
    } catch (e) {
      // その他のエラー
      _isLoading = false;
      _errorMessage = 'Googleログインに失敗しました';
      if (kDebugMode) {
        debugPrint('🔐 [Google] 予期しないエラー: $e');
      }
      notifyListeners();
      return false;
    }
  }

  // ==========================================================================
  // Twitter Sign-In（X）
  // ==========================================================================

  /// Twitter Sign-Inでログイン（X経由、Firebase Authentication使用）
  /// 
  /// Twitter（X）認証フローを使用してFirebase経由でログインします
  /// 
  /// 処理の流れ:
  /// 1. Twitterサインインフローを開始（ブラウザまたはアプリ内WebViewが開く）
  /// 2. ユーザーがTwitterアカウントでログイン
  /// 3. アプリの権限を許可
  /// 4. Twitter認証情報（accessToken、secret）を取得
  /// 5. **Firebase Authenticationに認証情報を送信** ← Firebase経由
  /// 6. **Firebase UIDが自動的に生成される**（新規ユーザーの場合）
  /// 7. authStateChangesリスナーが発火し、ユーザー情報が更新される
  /// 
  /// 戻り値:
  /// - true: ログイン成功
  /// - false: ログイン失敗またはキャンセル
  /// 
  /// 取得される情報:
  /// - Firebase UID（自動生成、変更されない一意のID）
  /// - ユーザー名
  /// - プロフィール画像URL
  /// - メールアドレス（API設定により取得可能）
  /// 
  /// 注意:
  /// - Twitter Developer PortalでAPI KeyとAPI Secret Keyの設定が必要
  /// - カスタムURLスキーム（spotlight://）の設定が必要
  /// - **すべてFirebase Authentication経由で処理されます**
  Future<bool> loginWithTwitter() async {
    // 設定で無効化されている場合はエラー
    if (!FirebaseConfig.enableTwitterSignIn) {
      _errorMessage = 'Twitter Sign-Inは現在無効になっています';
      return false;
    }

    // TwitterLoginが初期化されていない場合はエラー
    final twitterLogin = _getTwitterLogin;
    if (twitterLogin == null) {
      _errorMessage = 'Twitter Sign-Inの初期化に失敗しました';
      return false;
    }

    try {
      // ローディング開始
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (kDebugMode && AuthConfig.enableAuthDebugLog) {
        debugPrint('🔐 [Twitter] Sign-In開始');
      }

      // STEP 1: Twitterサインインフローを開始
      // ブラウザまたはアプリ内WebViewでTwitterログイン画面が表示されます
      final authResult = await twitterLogin.login();

      if (authResult.status == TwitterLoginStatus.loggedIn) {
        if (kDebugMode && AuthConfig.enableAuthDebugLog) {
          debugPrint('🔐 [Twitter] 認証成功');
        }

        // STEP 2: Twitter認証情報を取得
        final twitterAuthCredential = firebase_auth.TwitterAuthProvider.credential(
          accessToken: authResult.authToken!,
          secret: authResult.authTokenSecret!,
        );

        // STEP 3: Firebase Authenticationにサインイン（Firebase経由）
        // この時点でFirebase UIDが自動生成されます（新規ユーザーの場合）
        // すべての認証処理はFirebase Authentication経由で行われます
        // authStateChangesリスナーが発火し、_onAuthStateChangedが呼ばれます
        await _firebaseAuth.signInWithCredential(twitterAuthCredential);

        if (kDebugMode && AuthConfig.enableAuthDebugLog) {
          debugPrint('🔐 [Twitter] Sign-In成功');
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else if (authResult.status == TwitterLoginStatus.cancelledByUser) {
        // ユーザーがサインインをキャンセルした場合
        if (kDebugMode && AuthConfig.enableAuthDebugLog) {
          debugPrint('🔐 [Twitter] ユーザーがキャンセル');
        }
        _isLoading = false;
        notifyListeners();
        return false;
      } else {
        // その他のエラー
        if (kDebugMode && AuthConfig.enableAuthDebugLog) {
          debugPrint('🔐 [Twitter] ログインエラー: ${authResult.errorMessage}');
        }
        _isLoading = false;
        _errorMessage = authResult.errorMessage ?? 'Twitter Sign-Inに失敗しました';
        notifyListeners();
        return false;
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      // Firebase認証エラー
      _isLoading = false;
      _errorMessage = AuthService.getAuthErrorMessage(e);
      if (kDebugMode) {
        debugPrint('🔐 [Twitter] Firebaseエラー: ${e.code} - ${e.message}');
      }
      notifyListeners();
      return false;
    } catch (e) {
      // その他のエラー
      _isLoading = false;
      _errorMessage = 'Twitter Sign-Inに失敗しました';
      if (kDebugMode) {
        debugPrint('🔐 [Twitter] 予期しないエラー: $e');
      }
      notifyListeners();
      return false;
    }
  }

  // ==========================================================================
  // ゲストログイン（開発用）
  // ==========================================================================

  /// ゲストとしてログイン（開発モードのみ）
  /// 
  /// 認証なしで仮のユーザーとしてログインします
  /// 
  /// 注意:
  /// - 開発・デバッグ用の機能です
  /// - 本番環境では無効化してください（AppConfig.canSkipAuth = false）
  /// - Firebase UIDは生成されません（ゲストIDのみ）
  void skipLogin() {
    if (kDebugMode && AuthConfig.enableAuthDebugLog) {
      debugPrint('🔐 [ゲスト] ログイン（開発モード）');
    }

    // 仮のゲストユーザーを作成
    // Firebase UIDではなく、固定の'guest' IDを使用
    _currentUser = User(
      id: 'guest', // Firebase UIDではない特別なID
      email: 'guest@spotlight.app',
      username: 'ゲスト',
      avatarUrl: null,
    );
    notifyListeners();
  }

  // ==========================================================================
  // ログアウト
  // ==========================================================================

  /// Firebase IDトークンを取得
  /// 
  /// 現在ログイン中のユーザーのFirebase IDトークンを取得します
  /// このトークンをバックエンドに送信してJWTトークンを取得するために使用します
  /// 
  /// 戻り値:
  /// - String: Firebase IDトークン（ログイン済みの場合）
  /// - null: 未ログインまたはトークン取得失敗の場合
  Future<String?> getFirebaseIdToken() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        if (kDebugMode && AuthConfig.enableAuthDebugLog) {
          debugPrint('🔐 Firebase IDトークン取得失敗: ユーザー未ログイン');
        }
        return null;
      }

      final idToken = await user.getIdToken();
      
      if (kDebugMode && AuthConfig.enableAuthDebugLog) {
        debugPrint('🔐 Firebase IDトークン取得成功');
      }
      
      return idToken;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 Firebase IDトークン取得エラー: $e');
      }
      return null;
    }
  }

  /// バックエンドサーバーにJWTトークンとFCMトークンを送信
  /// 
  /// Firebase IDトークンとFCMトークンをバックエンドサーバーに送信します
  /// 
  /// 戻り値:
  /// - Map<String, dynamic>: レスポンスデータ（成功の場合）
  /// - null: 失敗の場合
  Future<Map<String, dynamic>?> sendTokensToBackend() async {
    try {
      // Firebase IDトークンを取得
      final firebaseIdToken = await getFirebaseIdToken();
      if (firebaseIdToken == null) {
        if (kDebugMode) {
          debugPrint('🔐 Firebase IDトークンが取得できません');
        }
        return null;
      }

      // FCMトークンを取得（失敗しても続行）
      final fcmToken = await FcmService.getFcmToken();
      if (fcmToken == null) {
        if (kDebugMode) {
          debugPrint('🔔 FCMトークンが取得できません（モックトークンを使用）');
        }
      }

      if (kDebugMode && AuthConfig.enableAuthDebugLog) {
        debugPrint('🔐 トークン送信開始:');
        debugPrint('  Firebase IDトークン: ${firebaseIdToken.substring(0, 50)}...');
        debugPrint('  FCMトークン: ${fcmToken?.substring(0, 50) ?? 'null'}...');
        debugPrint('  送信先: ${AppConfig.backendUrl}/api/auth/firebase');
      }
      
      // バックエンドサーバーにリクエストを送信
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/auth/firebase'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': firebaseIdToken,
          'token': fcmToken ?? 'mock_fcm_token_123', // FCMトークンが取得できない場合はモックを使用
        }),
      );
      
      if (kDebugMode) {
        debugPrint('🔐 レスポンス受信: ${response.statusCode}');
        debugPrint('🔐 レスポンス内容: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // レスポンス形式を確認（旧形式と新形式に対応）
        String? jwtToken;
        Map<String, dynamic>? userInfo;
        
        if (data['success'] == true && data['data'] != null) {
          // 旧形式: { "success": true, "data": { "jwt": "...", "user": {...} } }
         debugPrint('🔐 旧形式: ${data.toString()}');
         debugPrint('🔐 旧形式: ${data['data']['jwt']['user']['firebase_uid']}');
         debugPrint('🔐 新形式: ${data['jwt']}');
         debugPrint('🔐 新形式: ${data['firebase_uid']}');
         debugPrint('🔐 新形式: ${data['status']}');
         debugPrint('🔐 新形式: ${data.toString()}');

          jwtToken = data['data']['jwt'];
          userInfo = data['data']['user'];
        } else if (data['jwt'] != null) {
          // 新形式: { "jwt": "...", "firebase_uid": "...", "status": "success" }
          jwtToken = data['jwt'];
          userInfo = {
            'firebase_uid': data['firebase_uid'],
            'status': data['status'],
          };
        }
        
        if (jwtToken != null) {
          // JWTトークンとユーザー情報をローカルに保存
          await JwtService.saveJwtToken(jwtToken);
          if (userInfo != null) {
            await JwtService.saveUserInfo(userInfo);
          }
          
          if (kDebugMode && AuthConfig.enableAuthDebugLog) {
            debugPrint('🔐 トークン送信成功:');
            debugPrint('  JWTトークン: ${jwtToken.substring(0, 50)}...');
            if (userInfo != null) {
              debugPrint('  ユーザー情報: ${userInfo.toString()}');
            }
          }
          
          return data;
        } else {
          if (kDebugMode) {
            debugPrint('🔐 サーバーエラー: ${data['error'] ?? '不明なエラー'}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('🔐 HTTPエラー: ${response.statusCode}');
          debugPrint('🔐 エラー内容: ${response.body}');
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 トークン送信エラー: $e');
      }
      return null;
    }
  }

  /// バックエンドからJWTトークンを取得（旧メソッド - 互換性のため残す）
  /// 
  /// Firebase IDトークンをバックエンドに送信してJWTトークンを取得します
  /// 
  /// 戻り値:
  /// - String: JWTトークン（成功の場合）
  /// - null: 失敗の場合
  Future<String?> getJwtTokenFromBackend() async {
    final result = await sendTokensToBackend();
    if (result != null && result['data'] != null) {
      return result['data']['jwt'] as String?;
    }
    return null;
  }

  /// ログアウト
  /// 
  /// すべての認証プロバイダーからサインアウトします
  /// 
  /// 処理の流れ:
  /// 1. ゲストモードかどうかを確認
  /// 2. Firebase Authenticationからサインアウト（ゲストでない場合）
  /// 3. Google Sign-Inからサインアウト
  /// 4. ユーザー情報をクリア
  /// 5. notifyListeners()で画面を更新
  /// 
  /// 注意:
  /// - Twitter Sign-Inはサインアウト処理不要（自動処理）
  /// - ゲストモードの場合はFirebase認証を使わないため、直接クリア
  Future<void> logout() async {
    if (kDebugMode && AuthConfig.enableAuthDebugLog) {
      debugPrint('🔐 ログアウト開始');
    }

    final isGuest = _currentUser?.id == 'guest';

    if (!isGuest) {
      // Firebase Authenticationからサインアウト
      // これによりauthStateChangesリスナーが発火し、_onAuthStateChangedが呼ばれます
      await _firebaseAuth.signOut();

      // Google Sign-Inからサインアウト
      // 次回のログイン時にアカウント選択画面が表示されます
      await _googleSignIn.signOut();

      // Twitter Sign-Inは明示的なサインアウト処理不要
      // Firebase Authenticationのサインアウトで十分です
    }

    // ユーザー情報をクリア
    _currentUser = null;
    
    // JWTトークンとユーザー情報をローカルから削除
    await JwtService.clearAll();

    if (kDebugMode && AuthConfig.enableAuthDebugLog) {
      debugPrint('🔐 ログアウト完了: ゲストモード=${isGuest}');
    }

    // 画面更新を通知
    notifyListeners();
  }
}

