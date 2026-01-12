import 'package:flutter/foundation.dart';
import '../models/post.dart';

class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;
  String? _targetPostId; // ホーム画面で表示する投稿ID
  Post? _targetPost; // ホーム画面で表示する投稿（先行取得用）
  String? _targetPostTitle; // ホーム画面で表示する投稿のタイトル（検証用）
  int _notificationRefreshTrigger = 0; // 通知再読み込み用のトリガー
  int _profileHistoryRefreshTrigger = 0;

  int get currentIndex => _currentIndex;
  String? get targetPostId => _targetPostId;
  Post? get targetPost => _targetPost;
  String? get targetPostTitle => _targetPostTitle;
  int get notificationRefreshTrigger => _notificationRefreshTrigger;
  int get profileHistoryRefreshTrigger => _profileHistoryRefreshTrigger;

  void setCurrentIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void navigateToHome({String? postId, String? postTitle, Post? post}) {
    _targetPostId = postId;
    _targetPost = post;
    _targetPostTitle = postTitle;
    setCurrentIndex(0);
  }

  void navigateToSearch() {
    // 検索画面に遷移するたびに検索履歴を再取得するためのトリガー
    setCurrentIndex(1);
  }

  void navigateToCreatePost() {
    setCurrentIndex(2);
  }

  void navigateToNotifications() {
    // 通知画面に遷移するたびにトリガーを増やして再読み込みを促す
    _notificationRefreshTrigger++;
    setCurrentIndex(3);
    notifyListeners();
  }

  void navigateToProfile() {
    setCurrentIndex(4);
  }

  /// ターゲット投稿IDをクリア
  void clearTargetPostId() {
    _targetPostId = null;
    _targetPost = null;
    _targetPostTitle = null;
    notifyListeners();
  }

  /// ナビゲーション状態をリセット
  void reset() {
    _currentIndex = 0;
    _targetPostId = null;
    _targetPost = null;
    _targetPostTitle = null;
    _profileHistoryRefreshTrigger = 0;
    notifyListeners();
  }

  void notifyProfileHistoryUpdated() {
    _profileHistoryRefreshTrigger++;
    notifyListeners();
  }
}
