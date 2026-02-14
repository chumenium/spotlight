import 'dart:async';

/// アイコン更新イベント
class IconUpdateEvent {
  final String username;
  final String? iconPath; // nullの場合はデフォルトアイコン
  final DateTime timestamp;

  IconUpdateEvent({
    required this.username,
    this.iconPath,
  }) : timestamp = DateTime.now();
}

/// アイコン更新通知サービス
/// 
/// プロフィール画面でアイコンを変更した時に、
/// ホーム画面など他の画面に通知するためのサービス
class IconUpdateService {
  // シングルトンパターン
  static final IconUpdateService _instance = IconUpdateService._internal();
  factory IconUpdateService() => _instance;
  IconUpdateService._internal();

  // イベントストリーム
  final _controller = StreamController<IconUpdateEvent>.broadcast();

  /// アイコン更新イベントのストリーム
  Stream<IconUpdateEvent> get onIconUpdate => _controller.stream;

  /// アイコン更新を通知
  /// 
  /// プロフィール画面でアイコン変更後に呼び出す
  void notifyIconUpdate(String username, {String? iconPath}) {
    _controller.add(IconUpdateEvent(
      username: username,
      iconPath: iconPath,
    ));
  }

  /// リソースを解放
  void dispose() {
    _controller.close();
  }
}

