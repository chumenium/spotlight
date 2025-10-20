import 'package:flutter/material.dart';

class User {
  final String id;
  final String email;
  final String username;
  final String? avatarUrl;

  User({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
  });
}

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;

  // ログイン処理（仮実装）
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    // 仮の遅延を追加してAPI呼び出しをシミュレート
    await Future.delayed(const Duration(seconds: 1));

    // 仮データでログイン成功
    if (email.isNotEmpty && password.isNotEmpty) {
      _currentUser = User(
        id: '1',
        email: email,
        username: email.split('@')[0],
        avatarUrl: 'https://via.placeholder.com/150',
      );
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // 新規登録処理（仮実装）
  Future<bool> register(String email, String username, String password) async {
    _isLoading = true;
    notifyListeners();

    // 仮の遅延を追加してAPI呼び出しをシミュレート
    await Future.delayed(const Duration(seconds: 1));

    // 仮データで登録成功
    if (email.isNotEmpty && username.isNotEmpty && password.isNotEmpty) {
      _currentUser = User(
        id: '1',
        email: email,
        username: username,
        avatarUrl: 'https://via.placeholder.com/150',
      );
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Googleログイン処理（仮実装）
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    // 仮の遅延を追加してAPI呼び出しをシミュレート
    await Future.delayed(const Duration(seconds: 1));

    // 仮データでログイン成功
    _currentUser = User(
      id: '1',
      email: 'google.user@gmail.com',
      username: 'GoogleUser',
      avatarUrl: 'https://via.placeholder.com/150',
    );
    _isLoading = false;
    notifyListeners();
    return true;
  }

  // スキップ（ゲストとしてログイン）
  void skipLogin() {
    _currentUser = User(
      id: 'guest',
      email: 'guest@spotlight.app',
      username: 'ゲスト',
      avatarUrl: null,
    );
    notifyListeners();
  }

  // ログアウト
  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}

