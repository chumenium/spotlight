import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show PlatformException;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../config/firebase_config.dart';
import '../config/app_config.dart';
import 'auth_config.dart';
import 'auth_service.dart';
import '../services/jwt_service.dart';
import '../services/fcm_service.dart';
import '../services/user_service.dart';
import '../services/firebase_service.dart';

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
  /// ソーシャルログインから取得した表示名、またはバックエンドから取得
  /// プロバイダーが提供しない場合は、メールアドレスから生成されます
  final String username;

  /// バックエンドから取得した本名
  ///
  /// バックエンドの/testエンドポイントから取得したユーザー名
  final String? backendUsername;

  /// プロフィール画像URL
  ///
  /// ソーシャルログインから取得したプロフィール画像のURL
  /// プロバイダーが提供しない場合はnull
  final String? avatarUrl;

  /// バックエンドから取得したアイコンパス
  ///
  /// バックエンドのDBに保存されているアイコンパス
  /// バックエンドで処理されたURLが含まれる場合がある
  final String? iconPath;

  /// 管理者フラグ
  ///
  /// バックエンドから取得した管理者権限フラグ
  /// trueの場合、管理者機能にアクセス可能
  final bool admin;

  User({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
    this.backendUsername,
    this.iconPath,
    this.admin = false,
  });
}

/// 認証状態を管理するProvider
///
/// Firebase Authenticationと連携してユーザーの認証状態を管理します
/// ソーシャルログイン（Google、Apple）専用
///
/// 主な機能:
/// - Google Sign-In
/// - Apple Sign-In（iOS）
/// - 認証状態の監視
/// - ログアウト
class AuthProvider extends ChangeNotifier {
  // ==========================================================================
  // Firebase Authentication インスタンス
  // ==========================================================================

  /// Firebase Authenticationのインスタンス
  /// すべての認証処理はこのインスタンスを通じて行われます
  /// Firebaseが初期化されていない場合はnullを返します
  firebase_auth.FirebaseAuth? get _firebaseAuth {
    // Firebaseが初期化されているか確認
    try {
      // FirebaseServiceが初期化されているか確認
      final firebaseService = FirebaseService.instance;
      if (!firebaseService.isInitialized) {
        return null;
      }

      // Firebaseが初期化されている場合のみ、FirebaseAuthインスタンスを返す
      return firebase_auth.FirebaseAuth.instance;
    } catch (e) {
      // Firebaseが初期化されていない場合、エラーをキャッチしてnullを返す
      return null;
    }
  }

  /// Google Sign-Inのインスタンス
  /// Google認証フローの管理に使用
  /// WebプラットフォームではclientIdのみ、それ以外ではserverClientIdを使用
  final GoogleSignIn _googleSignIn = kIsWeb
      ? GoogleSignIn(
          scopes: AuthConfig.googleScopes,
          // Web用のクライアントID（Webプラットフォームで必須）
          clientId:
              '185578323389-jouqlpvh55a25gt36vuu00i8pa95di3n.apps.googleusercontent.com',
        )
      : GoogleSignIn(
          scopes: AuthConfig.googleScopes,
          // サーバー側認証用のクライアントID（Android/iOS用）
          serverClientId:
              '185578323389-jouqlpvh55a25gt36vuu00i8pa95di3n.apps.googleusercontent.com',
        );

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
  
  /// 直近のログインが新規ユーザーかどうか
  bool _lastLoginWasNewUser = false;

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
  
  /// 直近のログインが新規ユーザーかどうか
  bool get lastLoginWasNewUser => _lastLoginWasNewUser;

  /// Google Sign-Inが利用可能か
  bool get canUseGoogle => FirebaseConfig.enableGoogleSignIn;

  /// Apple Sign-Inが利用可能か
  bool get canUseApple =>
      FirebaseConfig.enableAppleSignIn &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS;

  // ==========================================================================
  // 初期化
  // ==========================================================================

  AuthProvider() {
    // Firebase Authの状態変化を監視
    // ユーザーがログイン/ログアウトすると自動的に通知されます
    final auth = _firebaseAuth;
    if (auth != null) {
      auth.authStateChanges().listen(_onAuthStateChanged);
    }
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
        admin: false, // 初期値はfalse、APIから取得後に更新される
      );

      // バックエンドからユーザー情報とJWTトークンを取得（非同期処理、awaitなし）
      // ログイン時は強制更新（キャッシュを無視）
      _fetchUserInfoAndTokens(firebaseUser.uid, forceRefresh: true).then((_) {
        // ログイン成功後、最後の利用日時を更新
        JwtService.saveLastAccessTime();
        // ログイン成功後、FCMトークンをサーバーに送信
        _updateFcmTokenAfterLogin();
      });
    } else {
      _currentUser = null;
    }
    notifyListeners();
  }

  /// ログイン後にFCMトークンをサーバーに送信
  Future<void> _updateFcmTokenAfterLogin() async {
    try {
      // JWTトークンを取得（ログイン後なので取得できるはず）
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return;
      }

      // 少し待ってからFCMトークンを送信（JWTトークンの取得を確実にするため）
      await Future.delayed(const Duration(milliseconds: 500));

      // FCMトークンをサーバーに送信
      await FcmService.updateFcmTokenToServer(jwtToken);
    } catch (e) {
      // ignore
    }
  }

  /// Firebase Userからユーザー名を抽出
  ///
  /// 優先順位:
  /// 1. displayName（プロバイダーが提供した表示名）
  /// 2. メールアドレスの@より前の部分
  /// 3. デフォルト値「ユーザー」
  String _extractUsername(firebase_auth.User firebaseUser) {
    if (firebaseUser.displayName != null &&
        firebaseUser.displayName!.isNotEmpty) {
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
      _lastLoginWasNewUser = false;
      notifyListeners();

      // Google Play Servicesの状態を事前にチェック
      // エミュレータでGoogle Play Servicesが利用できない場合、エラーを早期に検出
      try {
        // isSignedIn()はGoogle Play Servicesの可用性をチェックするために使用
        // ただし、これはサインイン状態をチェックするメソッドなので、
        // 実際の可用性チェックには別の方法が必要
        await _googleSignIn.signInSilently();
      } catch (e) {
        // Google Play Servicesが利用できない場合のエラーハンドリング
        // エラーを続行して、実際のsignIn()でエラーをキャッチする
      }

      // STEP 1: Googleサインインフローを開始
      // Google Sign-Inダイアログが表示され、ユーザーがアカウントを選択
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // ユーザーがサインインをキャンセルした場合
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // STEP 2: Google認証情報（accessToken、idToken）を取得
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // STEP 3: Firebase用の認証情報を作成
      // GoogleのトークンをFirebaseで使用できる形式に変換
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // STEP 4: Firebaseにサインイン
      final auth = _firebaseAuth;
      if (auth == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // この時点でFirebase UIDが自動生成されます（新規ユーザーの場合）
      // 既存ユーザーの場合は、既存のUIDが使用されます
      // authStateChangesリスナーが発火し、_onAuthStateChangedが呼ばれます
      final userCredential = await auth.signInWithCredential(credential);
      _lastLoginWasNewUser =
          userCredential.additionalUserInfo?.isNewUser ?? false;

      _isLoading = false;
      notifyListeners();
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      // Firebase認証エラー
      _isLoading = false;
      _errorMessage = AuthService.getAuthErrorMessage(e);
      notifyListeners();
      return false;
    } on PlatformException catch (e) {
      // Google Sign-In プラットフォームエラー
      _isLoading = false;
      String errorMessage = 'Googleログインに失敗しました';

      // エラーコード別の詳細メッセージ
      switch (e.code) {
        case 'sign_in_failed':
          // Google Play Services の状態を再確認
          try {
            await _googleSignIn.isSignedIn();
          } catch (gpsError) {
            // ignore
          }

          errorMessage =
              'Google Play Servicesが利用できません。\n'
              'エミュレータを使用している場合:\n'
              '1. Google Play Services対応のエミュレータを使用しているか確認してください\n'
              '2. エミュレータの設定でGoogle Play Servicesが有効になっているか確認してください\n'
              '3. エミュレータを再起動してください\n\n'
              '実機を使用している場合:\n'
              '1. 設定アプリ → アプリ → Google Play Services → 更新\n'
              '2. Google Play ストアからGoogle Play Servicesを更新\n'
              '3. デバイスを再起動';
          break;
        case 'network_error':
          errorMessage = 'ネットワークエラーが発生しました。接続を確認してください。';
          break;
        case 'sign_in_canceled':
          errorMessage = 'ログインがキャンセルされました。';
          break;
        default:
          errorMessage = 'Googleログインでエラーが発生しました: ${e.message ?? e.code}';
      }

      _errorMessage = errorMessage;
      notifyListeners();
      return false;
    } catch (e) {
      // その他のエラー
      _isLoading = false;

      // People APIエラーの検出
      final errorString = e.toString();
      if (errorString.contains('People API') ||
          errorString.contains('SERVICE_DISABLED')) {
          _errorMessage = 'Google People APIが有効になっていません。\n'
            'Firebase ConsoleでPeople APIを有効にしてください:\n'
            'https://console.developers.google.com/apis/api/people.googleapis.com/overview?project=185578323389';
      } else {
        _errorMessage = 'Googleログインに失敗しました';
      }

      notifyListeners();
      return false;
    }
  }

  // ==========================================================================
  // Apple Sign-In
  // ==========================================================================

  /// Apple Sign-Inでログイン
  ///
  /// Apple認証フローを使用してログインします（iOSのみ）
  ///
  /// 処理の流れ:
  /// 1. Apple Sign-Inダイアログを表示
  /// 2. ユーザーがApple IDで認証
  /// 3. Apple認証情報（identityToken）を取得
  /// 4. Firebase Authenticationに認証情報を送信
  ///
  /// 戻り値:
  /// - true: ログイン成功
  /// - false: ログイン失敗またはキャンセル
  Future<bool> loginWithApple() async {
    if (!canUseApple) {
      _errorMessage = 'Appleログインは現在利用できません';
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      _lastLoginWasNewUser = false;
      notifyListeners();

      final rawNonce = _generateNonce();
      final hashedNonce = _sha256(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: _appleScopesFromConfig(),
        nonce: hashedNonce,
      );

      final auth = _firebaseAuth;
      if (auth == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        _isLoading = false;
        _errorMessage = 'Appleログインに失敗しました';
        notifyListeners();
        return false;
      }

      final oauthCredential = firebase_auth.OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
        accessToken: credential.authorizationCode,
      );

      final userCredential = await auth.signInWithCredential(oauthCredential);
      _lastLoginWasNewUser =
          userCredential.additionalUserInfo?.isNewUser ?? false;

      final nameParts = <String>[];
      if (credential.givenName != null &&
          credential.givenName!.trim().isNotEmpty) {
        nameParts.add(credential.givenName!.trim());
      }
      if (credential.familyName != null &&
          credential.familyName!.trim().isNotEmpty) {
        nameParts.add(credential.familyName!.trim());
      }
      final displayName = nameParts.join(' ').trim();
      if (displayName.isNotEmpty) {
        await userCredential.user?.updateDisplayName(displayName);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      _isLoading = false;
      if (e.code == AuthorizationErrorCode.canceled) {
        _errorMessage = 'ログインがキャンセルされました';
      } else {
        _errorMessage = 'Appleログインに失敗しました';
      }
      notifyListeners();
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = AuthService.getAuthErrorMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Appleログインに失敗しました';
      notifyListeners();
      return false;
    }
  }

  List<AppleIDAuthorizationScopes> _appleScopesFromConfig() {
    final scopes = <AppleIDAuthorizationScopes>[];
    for (final scope in AuthConfig.appleScopes) {
      switch (scope) {
        case 'email':
          scopes.add(AppleIDAuthorizationScopes.email);
          break;
        case 'fullName':
          scopes.add(AppleIDAuthorizationScopes.fullName);
          break;
      }
    }
    return scopes.isEmpty ? [AppleIDAuthorizationScopes.email] : scopes;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
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
    // 仮のゲストユーザーを作成
    // Firebase UIDではなく、固定の'guest' IDを使用
    _currentUser = User(
      id: 'guest', // Firebase UIDではない特別なID
      email: 'guest@spotlight.app',
      username: 'ゲスト',
      avatarUrl: null,
      admin: false,
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
    final auth = _firebaseAuth;
    if (auth == null) {
      return null;
    }

    try {
      final user = auth.currentUser;
      if (user == null) {
        return null;
      }

      final idToken = await user.getIdToken();

      return idToken;
    } catch (e) {
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
        return null;
      }

      // FCMトークンを取得（失敗しても続行）
      final fcmToken = await FcmService.getFcmToken();

      // バックエンドサーバーにリクエストを送信
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/auth/firebase'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': firebaseIdToken,
          'token': fcmToken ?? 'mock_fcm_token_123', // FCMトークンが取得できない場合はモックを使用
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // レスポンス形式を確認（旧形式と新形式に対応）
        String? jwtToken;
        Map<String, dynamic>? userInfo;

        if (data['success'] == true && data['data'] != null) {
          // 旧形式: { "success": true, "data": { "jwt": "...", "user": {...} } }
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

          return data;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// バックエンドからユーザー情報とJWTトークンを取得
  ///
  /// 1. JWTトークンを取得して保存
  /// 2. ユーザー名とアイコンパスを取得してユーザー情報を更新（キャッシュ機能付き）
  ///
  /// パラメータ:
  /// - uid: Firebase UID
  /// - forceRefresh: trueの場合、キャッシュを無視して強制的に再取得（ログイン時のみ使用）
  Future<void> _fetchUserInfoAndTokens(String uid,
      {bool forceRefresh = false}) async {
    try {
      // 1. JWTトークンを取得
      await sendTokensToBackend();

      // 2. ユーザー名とアイコンパスを取得（キャッシュ機能を使用）
      // ログイン時は強制更新、それ以外はキャッシュを使用（1時間に1回）
      final data =
          await UserService.refreshUserInfo(uid, forceRefresh: forceRefresh);

      if (data != null) {
        final username = data['username'] as String?;
        final iconPath = data['iconimgpath'] as String?;
        final admin = data['admin'] as bool? ?? false;

        // ユーザー情報を更新
        // usernameがnullでも、既存のユーザー情報を保持しつつadmin情報だけ更新する
        if (_currentUser != null) {
          // iconPathが存在する場合は、serverURLと結合して完全なURLにする
          // iconPathはバックエンドでusername_icon.png形式で生成される
          // またはCloudFront URLがそのまま返ってくる場合もある
          String? fullIconUrl;
          // iconPathがnullでも空文字列でもない場合のみ処理
          if (iconPath != null && iconPath.trim().isNotEmpty) {
            // 完全なURL（http://またはhttps://で始まる）の場合はそのまま使用
            if (iconPath.startsWith('http://') ||
                iconPath.startsWith('https://')) {
              fullIconUrl = iconPath;
            } else {
              // 相対パスの場合はbackendUrlと結合
              fullIconUrl = '${AppConfig.backendUrl}$iconPath';
            }
          }

          // iconPathが空文字列の場合はnullに変換（既存のアイコンを保持するため）
          final finalIconPath = (iconPath != null && iconPath.trim().isNotEmpty)
              ? iconPath
              : _currentUser!.iconPath;

          _currentUser = User(
            id: _currentUser!.id,
            email: _currentUser!.email,
            username: _currentUser!.username,
            avatarUrl: fullIconUrl ?? _currentUser!.avatarUrl,
            backendUsername: username ?? _currentUser!.backendUsername,
            iconPath: finalIconPath,
            admin: admin,
          );

          notifyListeners();
        }
      }
    } catch (e) {
      // ignore
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
  /// - ゲストモードの場合はFirebase認証を使わないため、直接クリア
  Future<void> logout() async {
    final isGuest = _currentUser?.id == 'guest';

    if (!isGuest) {
      final auth = _firebaseAuth;
      if (auth != null) {
        // Firebase Authenticationからサインアウト
        // これによりauthStateChangesリスナーが発火し、_onAuthStateChangedが呼ばれます
        await auth.signOut();
      } else {
        // FirebaseAuthが初期化されていない場合は手動で状態をクリア
        _currentUser = null;
        notifyListeners();
        return;
      }

      // Google Sign-Inからサインアウト
      // 次回のログイン時にアカウント選択画面が表示されます
      await _googleSignIn.signOut();
    }

    // ユーザー情報をクリア
    _currentUser = null;

    // JWTトークンとユーザー情報をローカルから削除
    await JwtService.clearAll();

    // 画面更新を通知
    notifyListeners();
  }

  /// アイコンURLにキャッシュキーを追加（1時間に1回の読み込み制限）
  /// 同じURLを使用することで、CachedNetworkImageのキャッシュが効く
  String? _addIconCacheKey(String? iconUrl) {
    if (iconUrl == null || iconUrl.isEmpty) {
      return null;
    }

    // 既にキャッシュキーが含まれている場合はそのまま返す
    if (iconUrl.contains('?cache=')) {
      return iconUrl;
    }

    // 1時間ごとに更新されるキャッシュキーを生成（同じ時間帯は同じキー）
    final now = DateTime.now();
    final cacheKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}';

    // URLにキャッシュキーを追加
    final separator = iconUrl.contains('?') ? '&' : '?';
    return '$iconUrl${separator}cache=$cacheKey';
  }

  /// ユーザー情報を更新
  ///
  /// アイコン更新後にユーザー情報を再取得して更新するために使用
  ///
  /// パラメータ:
  /// - username: バックエンドで生成された一意で変更不可なusername（nullの場合は現在の値を維持）
  /// - iconPath: アイコンパス（iconimgpath、nullの場合は現在の値を維持）
  /// - admin: 管理者フラグ（nullの場合は現在の値を維持）
  ///
  /// 注意:
  /// - iconPathはバックエンドのiconimgpathフィールドに対応
  /// - 空文字列の場合はアイコンを削除
  /// - idはFirebase UIDで変更不可
  /// - backendUsernameはバックエンドで生成された一意で変更不可なusername
  Future<void> updateUserInfo({String? username, String? iconPath, bool? admin}) async {
    if (_currentUser == null) return;

    try {
      String? fullIconUrl;
      String? finalIconPath;

      if (iconPath != null) {
        if (iconPath.isEmpty) {
          // 空文字列の場合はdefault_icon.pngを設定（S3のdefault_icon.pngを使用）
          finalIconPath = '/icon/default_icon.png';
          final baseIconUrl = '${AppConfig.cloudFrontUrl}/spotlight-contents/icon/default_icon.png';
          fullIconUrl = _addIconCacheKey(baseIconUrl);
        } else {
          // iconPathの形式を確認
          finalIconPath = iconPath;
          String baseIconUrl;

          // default_icon.pngの場合はS3のCloudFront URLを使用
          if (iconPath == 'default_icon.png' || 
              iconPath == '/icon/default_icon.png' ||
              iconPath.endsWith('/default_icon.png')) {
            baseIconUrl = '${AppConfig.cloudFrontUrl}/spotlight-contents/icon/default_icon.png';
          }
          // 完全なURL（http://またはhttps://で始まる）の場合はそのまま使用
          else if (iconPath.startsWith('http://') ||
              iconPath.startsWith('https://')) {
            baseIconUrl = iconPath;
          }
          // 相対パスの場合はbackendUrlを追加
          else {
            baseIconUrl = '${AppConfig.backendUrl}$iconPath';
          }

          fullIconUrl = _addIconCacheKey(baseIconUrl);
        }
      } else if (_currentUser!.iconPath != null &&
          _currentUser!.iconPath!.isNotEmpty) {
        finalIconPath = _currentUser!.iconPath;
        String baseIconUrl;

        // default_icon.pngの場合はS3のCloudFront URLを使用
        if (_currentUser!.iconPath == 'default_icon.png' || 
            _currentUser!.iconPath == '/icon/default_icon.png' ||
            _currentUser!.iconPath!.endsWith('/default_icon.png')) {
          baseIconUrl = '${AppConfig.cloudFrontUrl}/spotlight-contents/icon/default_icon.png';
        }
        // 完全なURL（http://またはhttps://で始まる）の場合はそのまま使用
        else if (_currentUser!.iconPath!.startsWith('http://') ||
            _currentUser!.iconPath!.startsWith('https://')) {
          baseIconUrl = _currentUser!.iconPath!;
        }
        // 相対パスの場合はbackendUrlを追加
        else {
          baseIconUrl = '${AppConfig.backendUrl}${_currentUser!.iconPath}';
        }

        fullIconUrl = _addIconCacheKey(baseIconUrl);
      } else {
        // iconPathがnullまたは空の場合はdefault_icon.pngを設定（S3のdefault_icon.pngを使用）
        finalIconPath = '/icon/default_icon.png';
        final baseIconUrl = '${AppConfig.cloudFrontUrl}/spotlight-contents/icon/default_icon.png';
        fullIconUrl = _addIconCacheKey(baseIconUrl);
      }

      _currentUser = User(
        id: _currentUser!.id, // Firebase UID（変更不可）
        email: _currentUser!.email,
        username: _currentUser!.username,
        avatarUrl: fullIconUrl ?? _currentUser!.avatarUrl,
        backendUsername: username ??
            _currentUser!.backendUsername, // バックエンドで生成された一意で変更不可なusername
        iconPath: finalIconPath, // iconimgpath
        admin: admin ?? _currentUser!.admin, // 管理者フラグを更新または保持
      );

      notifyListeners();
    } catch (e) {
      // ignore
    }
  }

  /// バックエンドから最新のユーザー情報を再取得して更新
  ///
  /// アイコン変更後などに呼び出して、最新のユーザー情報（iconimgpath含む）をバックエンドから取得して反映
  ///
  /// 注意:
  /// - iconimgpathはバックエンドでusername_icon.png形式で生成される
  /// - 取得したiconimgpathから完全なアイコンURL（${backendUrl}${iconimgpath}）を生成
  ///
  /// 戻り値:
  /// - bool: 更新成功の場合true
  Future<bool> refreshUserInfoFromBackend({bool forceRefresh = false}) async {
    if (_currentUser == null) return false;

    try {
      final userInfo = await UserService.refreshUserInfo(_currentUser!.id,
          forceRefresh: forceRefresh);

      if (userInfo != null) {
        final username = userInfo['username'] as String?;
        final iconPath =
            userInfo['iconimgpath'] as String?; // バックエンドで生成（完全なURLまたは相対パス）
        final admin = userInfo['admin'] as bool? ?? _currentUser!.admin; // 管理者フラグを取得

        // admin情報も含めて更新
        await updateUserInfo(username: username, iconPath: iconPath, admin: admin);
        return true;
      }
    } catch (e) {
      // ignore
    }

    return false;
  }
}
