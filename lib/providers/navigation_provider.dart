import 'package:flutter/foundation.dart';

class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;
  String? _targetPostId; // ホーム画面で表示する投稿ID

  int get currentIndex => _currentIndex;
  String? get targetPostId => _targetPostId;

  void setCurrentIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void navigateToHome({String? postId}) {
    _targetPostId = postId;
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
    notifyListeners();
  }

  /// ナビゲーション状態をリセット
  void reset() {
    _currentIndex = 0;
    _targetPostId = null;
    notifyListeners();
  }
}
