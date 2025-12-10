# Androidアプリ アイコン・スプラッシュスクリーン設定ガイド

## 概要

このガイドでは、Androidアプリのアイコンと起動時のスプラッシュスクリーン（起動アニメーション）を設定する方法を説明します。

## 必要な画像ファイル

### 1. アプリアイコン
- **場所**: `assets/icon/icon.png`
- **サイズ**: 1024x1024px（推奨）
- **形式**: PNG（透明背景可）
- **内容**: アプリのアイコン画像

### 2. スプラッシュスクリーン
- **場所**: `assets/splash/splash.png`
- **サイズ**: 1084x1920px（推奨、縦長）
- **形式**: PNG
- **内容**: アプリ起動時に表示される画像

## 設定手順

### ステップ1: 画像ファイルを配置

1. アプリアイコン画像を `assets/icon/icon.png` に配置
2. スプラッシュスクリーン画像を `assets/splash/splash.png` に配置

### ステップ2: アイコンの生成

以下のコマンドを実行して、各サイズのアイコンを自動生成します：

```bash
flutter pub run flutter_launcher_icons
```

このコマンドにより、以下のサイズのアイコンが自動生成されます：
- mipmap-mdpi (48x48px)
- mipmap-hdpi (72x72px)
- mipmap-xhdpi (96x96px)
- mipmap-xxhdpi (144x144px)
- mipmap-xxxhdpi (192x192px)

### ステップ3: スプラッシュスクリーンの生成

以下のコマンドを実行して、スプラッシュスクリーンを設定します：

```bash
flutter pub run flutter_native_splash:create
```

このコマンドにより、以下のファイルが自動生成・更新されます：
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `android/app/src/main/res/values/styles.xml`

### ステップ4: アプリを再ビルド

設定を反映するために、アプリを再ビルドします：

```bash
flutter clean
flutter build apk --release
```

または、直接実行：

```bash
flutter run
```

## カスタマイズ

### アイコンのカスタマイズ

`pubspec.yaml`の`flutter_launcher_icons`セクションで以下を変更できます：

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/icon.png"
  adaptive_icon_background: "#FFFFFF"  # アダプティブアイコンの背景色
  adaptive_icon_foreground: "assets/icon/icon.png"
```

### スプラッシュスクリーンのカスタマイズ

`pubspec.yaml`の`flutter_native_splash`セクションで以下を変更できます：

```yaml
flutter_native_splash:
  color: "#FFFFFF"  # 背景色
  image: "assets/splash/splash.png"
  android: true
  ios: false
  android_12:
    image: "assets/splash/splash.png"
    color: "#FFFFFF"
```

## トラブルシューティング

### アイコンが表示されない場合

1. `flutter clean` を実行
2. `flutter pub get` を実行
3. `flutter pub run flutter_launcher_icons` を再実行
4. アプリを再ビルド

### スプラッシュスクリーンが表示されない場合

1. `flutter clean` を実行
2. `flutter pub get` を実行
3. `flutter pub run flutter_native_splash:create` を再実行
4. アプリを再ビルド

### 画像サイズのエラー

- アイコンは正方形（1:1）の画像を使用してください
- スプラッシュスクリーンは縦長（9:16）の画像を使用してください
- 画像の解像度が低い場合は、高解像度の画像を使用してください

## 注意事項

- アイコンとスプラッシュスクリーンの画像を変更した場合は、必ず上記のコマンドを再実行してください
- `flutter clean` を実行した後は、アイコンとスプラッシュスクリーンの再生成が必要です
- Android 12以降では、アニメーション付きスプラッシュスクリーンがサポートされます

