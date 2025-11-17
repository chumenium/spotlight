# スプラッシュスクリーン（起動アニメーション）設定

このフォルダにスプラッシュスクリーンの画像を配置してください。

## 必要な画像

- **ファイル名**: `splash.png`
- **サイズ**: 1084x1920px（推奨、縦長）
- **形式**: PNG
- **内容**: アプリ起動時に表示される画像

## 設定方法

1. `splash.png` をこのフォルダに配置
2. 以下のコマンドを実行：
   ```bash
   flutter pub get
   flutter pub run flutter_native_splash:create
   ```

## カスタマイズ

`pubspec.yaml`の`flutter_native_splash`セクションで以下をカスタマイズできます：

- `color`: 背景色（画像がない部分の色）
- `image`: スプラッシュ画像のパス
- `android_12`: Android 12以降用の設定

## 注意事項

- スプラッシュ画像は中央に配置されます
- 背景色は`color`で指定できます
- Android 12以降では、アニメーション付きスプラッシュスクリーンがサポートされます

