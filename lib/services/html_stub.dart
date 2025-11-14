// スタブファイル: モバイルプラットフォーム用
// dart:html の FileReader のスタブ実装

/// Webプラットフォームでのみ利用可能なFileReaderのスタブ
/// モバイルプラットフォームでは使用されない
class FileReader {
  // スタブ実装（実際には使用されない）
  dynamic get result => null;

  Stream<dynamic> get onLoadEnd => const Stream.empty();

  void readAsArrayBuffer(dynamic file) {
    throw UnsupportedError('FileReader is only available on web platform');
  }
}
