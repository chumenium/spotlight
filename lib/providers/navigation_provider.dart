import 'package:flutter/foundation.dart';

class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setCurrentIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void navigateToHome() {
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
}
