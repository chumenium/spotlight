# Google AdMob セットアップガイド

このガイドでは、iOS/AndroidアプリにGoogle AdMob広告を統合する方法を説明します。

## 📋 前提条件

- Googleアカウント
- Flutterプロジェクトがセットアップ済み
- iOS/AndroidアプリがFirebaseに登録済み

## 🚀 セットアップ手順

### 1. AdMobアカウントの作成

1. [Google AdMob](https://admob.google.com/)にアクセス
2. Googleアカウントでログイン
3. 「アプリを開始」をクリックしてAdMobアカウントを作成

### 2. アプリの登録

1. AdMobダッシュボードで「アプリ」→「アプリを追加」をクリック
2. アプリ名とプラットフォーム（iOS/Android）を選択
3. **重要**: パッケージ名（Bundle ID）を正確に入力
   - Android: `com.spotlight.mobile`
   - iOS: `com.spotlight.kcsf`

### 3. 広告ユニットの作成

アプリ登録後、以下の広告ユニットを作成します：

#### バナー広告
- 広告形式: 「バナー」
- 広告サイズ: 「アダプティブ」
- 広告ユニット名: 「バナー広告」

#### インタースティシャル広告
- 広告形式: 「インタースティシャル」
- 広告ユニット名: 「インタースティシャル広告」

#### ネイティブ広告（推奨：Instagramリール形式）
- 広告形式: 「ネイティブ」
- 広告ユニット名: 「ネイティブ広告」
- **重要**: この広告形式は投稿の間に表示され、スワイプでスキップ可能です

#### リワード広告（オプション）
- 広告形式: 「リワード」
- 広告ユニット名: 「リワード広告」

### 4. 広告ユニットIDの取得と設定

1. AdMobダッシュボードで各広告ユニットの「広告ユニットID」をコピー
2. `lib/services/ad_service.dart`を開く
3. 以下の定数を本番用のIDに置き換える：

```dart
// Android用
static const String _productionBannerAdUnitIdAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
static const String _productionInterstitialAdUnitIdAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

// iOS用（必要に応じて）
static const String _productionBannerAdUnitIdIOS = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
static const String _productionInterstitialAdUnitIdIOS = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
```

4. `lib/services/native_ad_manager.dart`を開く
5. ネイティブ広告ユニットIDを本番用のIDに置き換える：

```dart
// Android用
static const String _productionNativeAdUnitIdAndroid = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

// iOS用（必要に応じて）
static const String _productionNativeAdUnitIdIOS = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
```

### 5. Android設定

#### 5.1. AndroidManifest.xmlの更新

`android/app/src/main/AndroidManifest.xml`に以下の権限とメタデータを追加：

```xml
<manifest>
  <!-- インターネットアクセス権限（既に存在する可能性があります） -->
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

  <application>
    <!-- AdMob App ID（AdMobダッシュボードから取得） -->
    <meta-data
      android:name="com.google.android.gms.ads.APPLICATION_ID"
      android:value="ca-app-pub-3940256099942544~3347511713"/>
    <!-- ↑ テスト用ID。本番用IDに置き換えてください -->
  </application>
</manifest>
```

**重要**: `ca-app-pub-3940256099942544~3347511713`はテスト用IDです。
AdMobダッシュボードの「アプリの設定」から実際のApp IDを取得して置き換えてください。

#### 5.2. build.gradleの確認

`android/app/build.gradle`に`google_mobile_ads`の依存関係が追加されているか確認してください（自動的に追加されます）。

### 6. iOS設定

#### 6.1. Info.plistの更新

`ios/Runner/Info.plist`に以下のキーを追加：

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
<!-- ↑ テスト用ID。本番用IDに置き換えてください -->
```

**重要**: `ca-app-pub-3940256099942544~1458002511`はテスト用IDです。
AdMobダッシュボードの「アプリの設定」から実際のApp IDを取得して置き換えてください。

#### 6.2. Podfileの更新（必要な場合）

iOSの依存関係を更新：

```bash
cd ios
pod install
cd ..
```

### 7. main.dartの更新

`lib/main.dart`でAdMobを初期化：

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:spotlight/services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // AdMobの初期化（Firebase初期化の後）
  await AdService.initialize();
  
  runApp(const MyApp());
}
```

## 📱 広告の表示方法

### ネイティブ広告（Instagramリール形式）

ホーム画面で投稿の間に自動的に表示されます。5投稿ごとに広告が挿入され、スワイプでスキップ可能です。

- 広告の間隔は`lib/screens/home_screen.dart`の`_adInterval`定数で変更可能（デフォルト: 5投稿ごと）
- 広告は`lib/widgets/native_ad_widget.dart`で表示されます

### バナー広告

`lib/widgets/banner_ad_widget.dart`を使用してバナー広告を表示します。

### インタースティシャル広告

投稿の間にインタースティシャル広告を表示する場合は、`lib/services/ad_service.dart`の`loadInterstitialAd`メソッドを使用します。

## 🧪 テスト

- **テスト広告**: デバッグモードでは自動的にテスト広告が表示されます
- **本番広告**: Releaseビルドで実際の広告が表示されます

## ⚠️ 重要な注意事項

1. **広告ユニットIDの管理**
   - テスト用IDと本番用IDを混同しないよう注意してください
   - 本番環境では必ず本番用IDを使用してください

2. **広告ポリシー**
   - Google AdMobの広告ポリシーに準拠する必要があります
   - 不適切なコンテンツがあるとアカウント停止の可能性があります

3. **収益化の承認**
   - アプリがストアで公開され、一定のアクティビティがあると収益化が承認されます
   - 初回は数日〜数週間かかる場合があります

## 📚 参考資料

- [Google AdMob公式ドキュメント](https://developers.google.com/admob)
- [Flutter用Google Mobile Ads SDK](https://pub.dev/packages/google_mobile_ads)
- [AdMobポリシー](https://support.google.com/admob/answer/6128543)
