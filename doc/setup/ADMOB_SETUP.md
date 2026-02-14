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

アプリ登録後、「**広告ユニットを追加**」から作成します。  
画面の流れ: **① 広告フォーマットを選択する** → **② 広告ユニットを設定** → 作成完了後に広告ユニットIDが発行されます。

#### ネイティブ広告（本アプリで使用・推奨）

- **① 広告フォーマットを選択する** で **「ネイティブアドバンス」** を選び「選択」をクリック  
  - 説明: 「アプリのデザインに合わせてカスタマイズできる広告フォーマットです。アプリのコンテンツに溶け込む形で表示されます。」
- **② 広告ユニットを設定** で広告ユニット名（例: 「ネイティブ広告」）を入力して作成
- ホームの投稿の間に表示され、スワイプでスキップ可能（Instagramリール形式に近い）

#### その他の広告（将来用）

| 広告形式 | ①で選ぶ名称 | 用途 |
|----------|--------------|------|
| バナー | バナー | 画面上部など（未使用） |
| インタースティシャル | インタースティシャル | 全画面（未使用） |
| リワード | リワード | 視聴で報酬（未使用） |

### 4. 広告ユニットIDの取得と設定

#### 4.1. 広告ユニットIDの取得方法

1. [AdMob](https://admob.google.com/)にログイン
2. 左メニュー「**アプリ**」→ 対象アプリ（Android / iOS）をクリック
3. 「**広告ユニット**」タブを開く
4. 一覧から目的の広告ユニットを選択（または「**広告ユニットを追加**」で新規作成）
5. 広告ユニットの詳細画面で「**広告ユニットID**」を表示
   - 形式: `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX`
   - 右側のコピーアイコンでクリップボードにコピー

**取得するIDの種類（本アプリで使用）:**

| 広告形式 | 用途 | 設定する定数名（ad_config.dart） |
|-----------|------|----------------------------------|
| ネイティブアドバンス | ホームの投稿の間 | `productionNativeAdUnitIdAndroid` / `productionNativeAdUnitIdIOS` |

※ バナー・インタースティシャル・リワードは現在未使用。将来的に使う場合のみ設定。

#### 4.2. 設定ファイルへの反映

**すべての広告ユニットIDは `lib/config/ad_config.dart` で一元管理します。**

1. `lib/config/ad_config.dart` を開く
2. 本番用の定数を、AdMobでコピーしたIDに置き換える：

```dart
// Android用（本アプリではネイティブ広告のみ使用）
static const String productionNativeAdUnitIdAndroid = 'ca-app-pub-XXXX/YYYY';  // ← ここに貼り付け

// iOS用
static const String productionNativeAdUnitIdIOS = 'ca-app-pub-XXXX/YYYY';  // ← ここに貼り付け
```

3. 保存すると、`AdService`・`NativeAdManager` が自動的にこのIDを参照します（コード変更不要）

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
