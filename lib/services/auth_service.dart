import 'package:firebase_auth/firebase_auth.dart';
import '../config/firebase_config.dart';

/// 認証関連のユーティリティ機能を提供
/// 
/// Firebase Authenticationとの連携をサポートするヘルパークラス
/// ソーシャルログイン専用（Google、Apple、Twitter）
class AuthService {
  // コンストラクタを私有化（ユーティリティクラスのため）
  AuthService._();

  // ==========================================================================
  // Firebase Auth エラーハンドリング
  // ==========================================================================

  /// FirebaseAuthExceptionを日本語メッセージに変換
  /// 
  /// ソーシャルログインで発生する可能性のあるエラーを
  /// ユーザーフレンドリーな日本語メッセージに変換します
  /// 
  /// 使用例:
  /// ```dart
  /// try {
  ///   await FirebaseAuth.instance.signInWithCredential(credential);
  /// } on FirebaseAuthException catch (e) {
  ///   final message = AuthService.getAuthErrorMessage(e);
  ///   showError(message);
  /// }
  /// ```
  static String getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      // ソーシャルログイン共通エラー
      case 'user-disabled':
        return 'このアカウントは無効化されています';
      case 'operation-not-allowed':
        return 'この認証方法は現在無効になっています';
      case 'too-many-requests':
        return 'ログイン試行回数が多すぎます。しばらく待ってから再度お試しください';
      
      // Google Sign-In エラー
      case 'account-exists-with-different-credential':
        return 'このメールアドレスは別の認証方法で既に使用されています';
      case 'invalid-credential':
        return '認証情報が無効です。もう一度お試しください';
      case 'user-cancelled':
        return 'ログインがキャンセルされました';
      
      // ネットワーク関連エラー
      case 'network-request-failed':
        return FirebaseConfig.networkErrorMessage;
      
      // その他のエラー
      default:
        return e.message ?? FirebaseConfig.unknownErrorMessage;
    }
  }

  // ==========================================================================
  // Firebase Auth 状態確認
  // ==========================================================================

  /// 現在ログイン中かチェック
  /// 
  /// Firebase Authenticationのログイン状態を確認します
  /// 
  /// 戻り値:
  /// - true: ログイン済み
  /// - false: 未ログイン
  static bool isLoggedIn() {
    return FirebaseAuth.instance.currentUser != null;
  }

  /// 現在のユーザーID（Firebase UID）を取得
  /// 
  /// Firebase Authenticationが生成した一意のユーザーIDを取得します
  /// このUIDは変更されず、すべての認証プロバイダーで一意です
  /// 
  /// 戻り値:
  /// - String: Firebase UID（ログイン済みの場合）
  /// - null: 未ログインの場合
  /// 
  /// 注意:
  /// このUIDをデータベースのユーザー識別子として使用してください
  static String? getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  /// 現在のユーザーのメールアドレスを取得
  /// 
  /// ソーシャルログインで取得したメールアドレスを返します
  /// 
  /// 戻り値:
  /// - String: メールアドレス（プロバイダーが提供している場合）
  /// - null: メールアドレスが利用できない場合
  /// 
  /// 注意:
  /// - Apple Sign-Inの場合、ユーザーがメールを隠すことを選択できます
  /// - Twitterの場合、メールアドレスが提供されないことがあります
  static String? getCurrentUserEmail() {
    return FirebaseAuth.instance.currentUser?.email;
  }

  /// 現在のユーザーの表示名を取得
  /// 
  /// ソーシャルログインで取得した表示名を返します
  /// 
  /// 戻り値:
  /// - String: 表示名（プロバイダーが提供している場合）
  /// - null: 表示名が利用できない場合
  static String? getCurrentUserDisplayName() {
    return FirebaseAuth.instance.currentUser?.displayName;
  }

  /// 現在のユーザーのプロフィール画像URLを取得
  /// 
  /// ソーシャルログインで取得したプロフィール画像URLを返します
  /// 
  /// 戻り値:
  /// - String: プロフィール画像URL（プロバイダーが提供している場合）
  /// - null: プロフィール画像が利用できない場合
  static String? getCurrentUserPhotoURL() {
    return FirebaseAuth.instance.currentUser?.photoURL;
  }

  /// 使用している認証プロバイダーのリストを取得
  /// 
  /// 現在のユーザーがどの認証プロバイダーを使用しているかを返します
  /// 
  /// 戻り値:
  /// - List<String>: プロバイダーIDのリスト（例: ['google.com', 'apple.com']）
  /// - 空のリスト: 未ログインの場合
  static List<String> getProviderIds() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    return user.providerData.map((info) => info.providerId).toList();
  }

  /// 特定のプロバイダーでログインしているか確認
  /// 
  /// パラメータ:
  /// - providerId: プロバイダーID（'google.com', 'apple.com', 'twitter.com'）
  /// 
  /// 戻り値:
  /// - true: 指定したプロバイダーでログインしている
  /// - false: 指定したプロバイダーでログインしていない
  static bool isSignedInWithProvider(String providerId) {
    return getProviderIds().contains(providerId);
  }
}

