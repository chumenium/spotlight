import 'package:flutter/foundation.dart';

class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;
  String? _targetPostId; // ホーム画面で表示する投稿ID
  String? _targetPostTitle; // ホーム画面で表示する投稿のタイトル（検証用）

  int get currentIndex => _currentIndex;
  String? get targetPostId => _targetPostId;
  String? get targetPostTitle => _targetPostTitle;

  void setCurrentIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void navigateToHome({String? postId, String? postTitle}) {
    _targetPostId = postId;
    _targetPostTitle = postTitle;
    setCurrentIndex(0);
  }

  void navigateToSearch() {
    setCurrentIndex(1);
  }

  void navigateToCreatePost() {
    setCurrentIndex(2);
  }

  void navigateToNotifications() {
    setCurrentIndex(3);
  }

  void navigateToProfile() {
    setCurrentIndex(4);
  }

  /// ターゲット投稿IDをクリア
  void clearTargetPostId() {
    _targetPostId = null;
    _targetPostTitle = null;
    notifyListeners();
  }

  /// ナビゲーション状態をリセット
  void reset() {
    _currentIndex = 0;
    _targetPostId = null;
    _targetPostTitle = null;
    notifyListeners();
  }
}
