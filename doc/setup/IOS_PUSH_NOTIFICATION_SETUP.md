# iOSプッシュ通知設定ガイド

## 概要
iOSでプッシュ通知を受信できるようにするための設定手順です。

## 実装済みの内容

### 1. AppDelegate.swift
- `UNUserNotificationCenterDelegate`と`MessagingDelegate`の実装
- プッシュ通知の許可リクエスト
- APNsトークンの取得とFCMへの登録
- フォアグラウンド/バックグラウンドでの通知ハンドリング

### 2. Info.plist
- バックグラウンドモード（`remote-notification`）の設定

### 3. main.dart
- バックグラウンドメッセージハンドラーの登録

## 必要な手動設定

### XcodeでPush Notifications Capabilityを有効化

1. Xcodeでプロジェクトを開く
   ```bash
   open ios/Runner.xcworkspace
   ```

2. プロジェクトナビゲーターで「Runner」を選択

3. 「Signing & Capabilities」タブを開く

4. 「+ Capability」ボタンをクリック

5. 「Push Notifications」を選択して追加

6. 「Background Modes」が表示されていることを確認
   - 表示されていない場合は「+ Capability」から追加
   - 「Remote notifications」にチェックを入れる

### Firebase Consoleでの設定確認

1. [Firebase Console](https://console.firebase.google.com/)にアクセス

2. プロジェクト「spotlight-597c4」を選択

3. プロジェクト設定 > Cloud Messaging タブを開く

4. 「Apple アプリ設定」セクションで以下を確認：
   - APNs認証キーがアップロードされているか
   - またはAPNs証明書が設定されているか

### APNs認証キーの設定（初回のみ）

1. [Apple Developer](https://developer.apple.com/account/resources/authkeys/list)にアクセス

2. 「Keys」セクションで新しいキーを作成
   - Key Name: 「Firebase Push Notifications」など
   - 「Apple Push Notifications service (APNs)」にチェック

3. キーをダウンロード（.p8ファイル）

4. Firebase Console > プロジェクト設定 > Cloud Messaging > Apple アプリ設定
   - 「APNs認証キーをアップロード」をクリック
   - ダウンロードした.p8ファイルをアップロード
   - Key IDとTeam IDを入力

## 動作確認

### 1. 実機でのテスト
- iOS実機にアプリをインストール
- 初回起動時に通知の許可を求められる
- 許可を与える

### 2. FCMトークンの確認
- Xcodeのコンソールで「🔔 FCMトークン取得:」のログを確認
- トークンが表示されれば正常に動作している

### 3. テスト通知の送信
Firebase Console > Cloud Messaging > 「新しいキャンペーン」からテスト通知を送信

## トラブルシューティング

### 通知が来ない場合

1. **通知の許可が確認されていない**
   - 設定 > Spotlight > 通知 で許可されているか確認

2. **APNs認証キーが設定されていない**
   - Firebase ConsoleでAPNs認証キーが設定されているか確認

3. **バンドルIDが一致していない**
   - XcodeのバンドルIDとFirebase ConsoleのバンドルIDが一致しているか確認
   - 現在のバンドルID: `com.spotlight.kcsf`

4. **実機でのテストが必要**
   - iOSシミュレーターではプッシュ通知は受信できません
   - 必ず実機でテストしてください

5. **Provisioning Profileの確認**
   - Push Notifications capabilityが有効なProvisioning Profileを使用しているか確認

## 参考リンク

- [Firebase Cloud Messaging for iOS](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [Apple Push Notification Service](https://developer.apple.com/documentation/usernotifications)

