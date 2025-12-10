# APNs認証キー設定の詳細手順

## 概要
iOSでプッシュ通知を送信するために、Firebase ConsoleにAPNs認証キーを設定する必要があります。

## 前提条件
- Apple Developerアカウントにログインできること
- Firebase Consoleにアクセスできること
- プロジェクトのバンドルID: `com.spotlight.kcsf`
- FirebaseプロジェクトID: `spotlight-597c4`

## ステップ1: Apple DeveloperでAPNs認証キーを作成

### 1-1. Apple Developerにログイン
1. [Apple Developer](https://developer.apple.com/account/)にアクセス
2. Apple IDでログイン

### 1-2. 認証キーを作成
1. 左メニューから「Certificates, Identifiers & Profiles」をクリック
2. 左サイドバーで「Keys」を選択
3. 右上の「+」ボタンをクリック

### 1-3. キーの設定
1. **Key Name**（キー名）を入力
   - 例: `Firebase Push Notifications` または `Spotlight APNs Key`
   - わかりやすい名前を付けてください

2. **「Apple Push Notifications service (APNs)」**にチェックを入れる
   - これが最も重要です
   - 他のサービスは不要です（チェックを外してもOK）

3. 「Continue」をクリック

4. 確認画面で「Register」をクリック

### 1-4. キーをダウンロード
1. 作成したキーの詳細ページが表示されます
2. **重要**: 「Download」ボタンをクリックして`.p8`ファイルをダウンロード
   - ⚠️ **このファイルは一度しかダウンロードできません**
   - 安全な場所に保存してください
   - ファイル名は `AuthKey_XXXXXXXXXX.p8` の形式です

3. **Key ID**をメモする
   - 例: `ABC123DEF4`
   - 後でFirebase Consoleに入力します

4. **Team ID**を確認
   - ページ上部の右上に表示されています
   - 例: `XYZ9ABCDE1`
   - これも後でFirebase Consoleに入力します

## ステップ2: Firebase ConsoleでAPNs認証キーをアップロード

### 2-1. Firebase Consoleにアクセス
1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. プロジェクト「**spotlight-597c4**」を選択

### 2-2. プロジェクト設定を開く
1. 左上の⚙️（歯車）アイコンをクリック
2. 「プロジェクトの設定」を選択

### 2-3. Cloud Messagingタブを開く
1. 上部のタブから「**Cloud Messaging**」をクリック

### 2-4. Apple アプリ設定を確認
1. 「**Apple アプリ設定**」セクションを探す
2. iOSアプリ（バンドルID: `com.spotlight.kcsf`）が表示されていることを確認

### 2-5. APNs認証キーをアップロード
1. 「**APNs認証キーをアップロード**」ボタンをクリック
   - または「APNs認証キー」セクションの「アップロード」リンク

2. 以下の情報を入力：
   - **Key ID**: ステップ1-4でメモしたKey ID
     - 例: `ABC123DEF4`
   - **Team ID**: ステップ1-4で確認したTeam ID
     - 例: `XYZ9ABCDE1`
   - **.p8ファイル**: ステップ1-4でダウンロードした`.p8`ファイルを選択
     - 「ファイルを選択」またはドラッグ&ドロップ

3. 「アップロード」をクリック

### 2-6. 確認
1. アップロードが成功すると、以下のように表示されます：
   - ✅ 「APNs認証キーが正常にアップロードされました」
   - Key IDが表示される
   - アップロード日時が表示される

2. エラーが表示された場合：
   - Key IDとTeam IDが正しいか確認
   - .p8ファイルが正しくダウンロードされているか確認
   - ファイルが破損していないか確認

## ステップ3: 動作確認

### 3-1. アプリを再ビルド
1. Xcodeでプロジェクトをクリーンビルド
   ```bash
   cd ios
   flutter clean
   flutter pub get
   cd ..
   flutter build ios
   ```

### 3-2. 実機でテスト
1. iOS実機にアプリをインストール
2. 初回起動時に通知の許可を求められる
3. 「許可」を選択

### 3-3. FCMトークンを確認
1. Xcodeのコンソールで以下のログを確認：
   ```
   🔔 APNsデバイストークン取得成功
   🔔 FCMトークン取得: [長いトークン文字列]
   ```

### 3-4. テスト通知を送信
1. Firebase Console > Cloud Messaging > 「新しいキャンペーン」
2. 「テストメッセージ」を選択
3. FCMトークンを入力（Xcodeコンソールからコピー）
4. 通知を送信
5. 実機で通知が表示されることを確認

## トラブルシューティング

### APNs認証キーがアップロードできない場合

**エラー: "Invalid key"**
- .p8ファイルが正しくダウンロードされているか確認
- ファイルが破損していないか確認
- 再度Apple Developerからキーを作成し直す（新しいKey IDが必要）

**エラー: "Key ID not found"**
- Key IDが正しく入力されているか確認
- Apple Developerで作成したKey IDと一致しているか確認

**エラー: "Team ID mismatch"**
- Team IDが正しく入力されているか確認
- Apple DeveloperアカウントのTeam IDと一致しているか確認

### 通知が来ない場合

1. **APNs認証キーが設定されているか確認**
   - Firebase Console > Cloud Messaging > Apple アプリ設定
   - APNs認証キーが表示されているか確認

2. **バンドルIDが一致しているか確認**
   - XcodeのバンドルID: `com.spotlight.kcsf`
   - Firebase ConsoleのバンドルIDと一致しているか確認

3. **Provisioning Profileを確認**
   - Xcode > Signing & Capabilities
   - Push Notifications capabilityが有効なProfileを使用しているか確認

4. **実機でテストしているか確認**
   - iOSシミュレーターではプッシュ通知は受信できません
   - 必ず実機でテストしてください

## 重要な注意事項

1. **.p8ファイルの管理**
   - .p8ファイルは一度しかダウンロードできません
   - 安全な場所にバックアップを保存してください
   - チームで共有する場合は、安全な方法で共有してください

2. **Key IDとTeam IDの記録**
   - Key IDとTeam IDは後で必要になる可能性があります
   - 安全な場所にメモしておいてください

3. **複数のアプリがある場合**
   - 1つのAPNs認証キーで複数のiOSアプリに使用できます
   - 同じApple Developerアカウントのアプリであれば、同じキーを使用できます

## 参考リンク

- [Apple Developer - Keys](https://developer.apple.com/account/resources/authkeys/list)
- [Firebase Console - Cloud Messaging](https://console.firebase.google.com/project/spotlight-597c4/settings/cloudmessaging)
- [Firebase公式ドキュメント - APNs認証キーの設定](https://firebase.google.com/docs/cloud-messaging/ios/certificates)

