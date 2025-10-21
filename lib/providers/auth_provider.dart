import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:twitter_login/twitter_login.dart';
import 'dart:io' show Platform;
import '../config/firebase_config.dart';
import '../config/auth_config.dart';
import '../services/auth_service.dart';

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
  late final TwitterLogin _twitterLogin;
  
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

  /// Apple Sign-Inが利用可能か（iOSのみ）
  bool get canUseApple => FirebaseConfig.enableAppleSignIn && Platform.isIOS;

  /// Twitter Sign-Inが利用可能か
  bool get canUseTwitter => FirebaseConfig.enableTwitterSignIn;

  // ==========================================================================
  // 初期化
  // ==========================================================================

  AuthProvider() {
    // Twitter認証の初期化
    // AuthConfigから設定を読み込みます
    _twitterLogin = TwitterLogin(
      apiKey: AuthConfig.twitterApiKey,
      apiSecretKey: AuthConfig.twitterApiSecretKey,
      redirectURI: AuthConfig.twitterRedirectUri,
    );
    
    // Firebase Authの状態変化を監視
    // ユーザーがログイン/ログアウトすると自動的に通知されます
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
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
  // Apple Sign-In
  // ==========================================================================

  /// Apple Sign-Inでログイン（iOSのみ）
  /// 
  /// Apple認証フローを使用してログインします
  /// 
  /// 処理の流れ:
  /// 1. Apple Sign-Inダイアログを表示
  /// 2. Face ID/Touch ID/パスワードで認証
  /// 3. Apple認証情報（identityToken、authorizationCode）を取得
  /// 4. Firebase Authenticationに認証情報を送信
  /// 5. Firebase UIDが自動的に生成される（新規ユーザーの場合）
  /// 6. 初回ログイン時のみ、名前を取得してFirebaseに保存
  /// 7. authStateChangesリスナーが発火し、ユーザー情報が更新される
  /// 
  /// 戻り値:
  /// - true: ログイン成功
  /// - false: ログイン失敗またはキャンセル
  /// 
  /// 取得される情報:
  /// - Firebase UID（自動生成、変更されない一意のID）
  /// - メールアドレス（ユーザーが隠すことも可能）
  /// - 名前（初回ログイン時のみ）
  /// 
  /// 注意:
  /// - iOSでのみ利用可能
  /// - App Store申請時、他のソーシャルログインがある場合は必須
  /// - ユーザーがメールアドレスを隠すことを選択できる
  Future<bool> loginWithApple() async {
    // 設定で無効化されている場合はエラー
    if (!FirebaseConfig.enableAppleSignIn) {
      _errorMessage = 'Apple Sign-Inは現在無効になっています';
      return false;
    }

    // iOSでない場合はエラー
    if (!Platform.isIOS) {
      _errorMessage = 'Apple Sign-InはiOSでのみ利用可能です';
      return false;
    }

    try {
      // ローディング開始
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (kDebugMode && AuthConfig.enableAuthDebugLog) {
        debugPrint('🔐 [Apple] Sign-In開始');
      }

      // STEP 1: Apple認証情報を取得
      // Face ID/Touch ID/パスワードでの認証が求められます
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,     // メールアドレスを要求
          AppleIDAuthorizationScopes.fullName,  // 名前を要求（初回のみ提供）
        ],
      );

      if (kDebugMode && AuthConfig.enableAuthDebugLog) {
        debugPrint('🔐 [Apple] 認証情報取得完了');
      }

      // STEP 2: Firebaseの認証情報を作成
      // Apple IDのトークンをFirebaseで使用できる形式に変換
      final oauthCredential = firebase_auth.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // STEP 3: Firebaseにサインイン
      // この時点でFirebase UIDが自動生成されます（新規ユーザーの場合）
      final userCredential = await _firebaseAuth.signInWithCredential(oauthCredential);

      // STEP 4: 初回ログイン時、Apple から取得した名前をFirebaseに保存
      // 注意: Appleは名前を初回ログイン時のみ提供します
      // 2回目以降のログインでは名前が提供されないため、初回に保存が重要です
      if (appleCredential.givenName != null && appleCredential.familyName != null) {
        final displayName = '${appleCredential.familyName} ${appleCredential.givenName}';
        await userCredential.user?.updateDisplayName(displayName);
        if (kDebugMode && AuthConfig.enableAuthDebugLog) {
          debugPrint('🔐 [Apple] 表示名を更新: $displayName');
        }
      }

      if (kDebugMode && AuthConfig.enableAuthDebugLog) {
        debugPrint('🔐 [Apple] Sign-In成功');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      // Firebase認証エラー
      _isLoading = false;
      _errorMessage = AuthService.getAuthErrorMessage(e);
      if (kDebugMode) {
        debugPrint('🔐 [Apple] Firebaseエラー: ${e.code} - ${e.message}');
      }
      notifyListeners();
      return false;
    } catch (e) {
      // その他のエラー
      _isLoading = false;
      _errorMessage = 'Apple Sign-Inに失敗しました';
      if (kDebugMode) {
        debugPrint('🔐 [Apple] 予期しないエラー: $e');
      }
      notifyListeners();
      return false;
    }
  }

  // ==========================================================================
  // Twitter Sign-In
  // ==========================================================================

  /// Twitter Sign-Inでログイン
  /// 
  /// Twitter認証フローを使用してログインします
  /// 
  /// 処理の流れ:
  /// 1. Twitterサインインフローを開始（ブラウザまたはアプリ内WebViewが開く）
  /// 2. ユーザーがTwitterアカウントでログイン
  /// 3. アプリの権限を許可
  /// 4. Twitter認証情報（accessToken、secret）を取得
  /// 5. Firebase Authenticationに認証情報を送信
  /// 6. Firebase UIDが自動的に生成される（新規ユーザーの場合）
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
  Future<bool> loginWithTwitter() async {
    // 設定で無効化されている場合はエラー
    if (!FirebaseConfig.enableTwitterSignIn) {
      _errorMessage = 'Twitter Sign-Inは現在無効になっています';
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
      final authResult = await _twitterLogin.login();

      if (authResult.status == TwitterLoginStatus.loggedIn) {
        if (kDebugMode && AuthConfig.enableAuthDebugLog) {
          debugPrint('🔐 [Twitter] 認証成功');
        }

        // STEP 2: Twitter認証情報を取得
        final twitterAuthCredential = firebase_auth.TwitterAuthProvider.credential(
          accessToken: authResult.authToken!,
          secret: authResult.authTokenSecret!,
        );

        // STEP 3: Firebaseにサインイン
        // この時点でFirebase UIDが自動生成されます（新規ユーザーの場合）
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

  /// ログアウト
  /// 
  /// すべての認証プロバイダーからサインアウトします
  /// 
  /// 処理の流れ:
  /// 1. Firebase Authenticationからサインアウト
  /// 2. Google Sign-Inからサインアウト
  /// 3. ユーザー情報をクリア
  /// 4. authStateChangesリスナーが発火し、ユーザー情報がnullに更新される
  /// 
  /// 注意:
  /// - Twitter Sign-Inはサインアウト処理不要（自動処理）
  Future<void> logout() async {
    if (kDebugMode && AuthConfig.enableAuthDebugLog) {
      debugPrint('🔐 ログアウト開始');
    }

    // Firebase Authenticationからサインアウト
    // これによりauthStateChangesリスナーが発火し、_onAuthStateChangedが呼ばれます
    await _firebaseAuth.signOut();

    // Google Sign-Inからサインアウト
    // 次回のログイン時にアカウント選択画面が表示されます
    await _googleSignIn.signOut();

    // Twitter Sign-Inは明示的なサインアウト処理不要
    // Firebase Authenticationのサインアウトで十分です

    // ユーザー情報をクリア（念のため）
    _currentUser = null;

    if (kDebugMode && AuthConfig.enableAuthDebugLog) {
      debugPrint('🔐 ログアウト完了');
    }

    notifyListeners();
  }
}

