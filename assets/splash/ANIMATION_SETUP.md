# スプラッシュアニメーション設定ガイド

## アニメーションファイルの形式とファイル名

### 推奨形式: Lottieアニメーション（JSON形式）

- **ファイル名**: `splash_animation.json`
- **配置場所**: `assets/splash/splash_animation.json`
- **形式**: JSON（Lottie形式）
- **取得方法**:
  1. After Effectsでアニメーションを作成
  2. [Bodymovin](https://github.com/airbnb/lottie-web)プラグインを使用してJSON形式でエクスポート
  3. または、[LottieFiles](https://lottiefiles.com/)から無料のアニメーションをダウンロード

### 代替形式: GIFアニメーション

GIFを使用する場合は、`splash_screen.dart`を修正する必要があります。

- **ファイル名**: `splash_animation.gif`
- **配置場所**: `assets/splash/splash_animation.gif`

## ファイルの配置手順

1. Lottieアニメーションファイル（JSON形式）を用意
2. ファイル名を `splash_animation.json` にリネーム
3. `assets/splash/` フォルダに配置
4. アプリを再ビルドして実行

## カスタマイズ方法

### アニメーションの表示時間を変更

`splash_screen.dart`の以下の部分を編集：

```dart
const splashDuration = Duration(seconds: 3); // 3秒を変更
```

### ループ再生の設定

`splash_screen.dart`の以下の部分を編集：

```dart
Lottie.asset(
  'assets/splash/splash_animation.json',
  fit: BoxFit.contain,
  repeat: true,  // true: ループ再生、false: 1回のみ
),
```

### アニメーションサイズの調整

`splash_screen.dart`の以下の部分を編集：

```dart
SizedBox(
  width: MediaQuery.of(context).size.width * 0.8,  // 幅の80%
  height: MediaQuery.of(context).size.width * 0.8, // 高さの80%
  child: Lottie.asset(...),
),
```

## 注意事項

- Lottieファイルは軽量で高品質なアニメーションが可能です
- ファイルサイズが大きすぎると起動が遅くなる可能性があります
- アニメーションの長さは2-4秒程度が推奨されます
- 背景色はアプリのテーマに合わせて設定されています（`Color(0xFF121212)`）

