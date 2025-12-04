# アプリアイコン設定

このフォルダにアプリアイコンの画像を配置してください。

## 必要な画像

- **ファイル名**: `icon.png`
- **サイズ**: 1024x1024px（推奨）
- **形式**: PNG（透明背景可）
- **内容**: アプリのアイコン画像

## 設定方法

1. `icon.png` をこのフォルダに配置
2. 以下のコマンドを実行：
   ```bash
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```

## 注意事項

- アイコンは正方形の画像を使用してください
- 透明背景を使用する場合は、`pubspec.yaml`の`adaptive_icon_background`で背景色を指定できます
- アイコンは各サイズ（hdpi, mdpi, xhdpi, xxhdpi, xxxhdpi）に自動生成されます

