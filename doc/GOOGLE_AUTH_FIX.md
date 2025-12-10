# Google認証問題の修正手順

## 🔍 問題の原因

**Google新規登録・ログインが他のPCでできない問題**は、SHA-1証明書フィンガープリントの設定不足が原因です。

現在のFirebase設定には開発用PCのSHA-1証明書のみが登録されているため、他のPCでビルドしたAPKでは認証が失敗します。

## 🛠️ 修正手順

### 1. 各PCでSHA-1証明書を取得

各開発PCで以下のコマンドを実行してSHA-1証明書を取得してください：

```bash
cd android
./gradlew signingReport
```

### 2. 出力例

以下のような出力が表示されます：

```
> Task :app:signingReport

Variant: debug
Config: debug
Store: C:\Users\[ユーザー名]\.android\debug.keystore
Alias: AndroidDebugKey
MD5: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
SHA1: 9D:DC:B4:98:44:0F:F8:D1:27:EF:9A:2E:6C:C8:72:AF:34:D0:80:57  ← この値をコピー
SHA-256: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
Valid until: 2054年XX月XX日
```

**SHA1の値**をコピーしてください。

### 3. Firebase Consoleに追加

1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. プロジェクト「spotlight-597c4」を選択
3. 左メニューから「プロジェクトの設定」（歯車アイコン）をクリック
4. 「全般」タブの下部「マイアプリ」セクションを確認
5. Androidアプリ「com.example.spotlight」の設定アイコンをクリック
6. 「SHA証明書フィンガープリント」セクションで「証明書を追加」をクリック
7. 取得したSHA-1証明書を貼り付けて「保存」

### 4. 現在登録されているSHA-1

現在Firebase Consoleに登録されているSHA-1証明書：
```
9ddcb498440ff8d127ef9a2e6cc872af34d08057
```

### 5. 複数のSHA-1証明書を追加

各開発PCで取得したSHA-1証明書をすべて追加してください：

- PC1のSHA-1: `9ddcb498440ff8d127ef9a2e6cc872af34d08057` （既に登録済み）
- PC2のSHA-1: `[新しく取得したSHA-1を追加]`
- PC3のSHA-1: `[新しく取得したSHA-1を追加]`

## 🔄 設定反映

SHA-1証明書を追加した後：

1. Firebase Consoleで「保存」をクリック
2. 設定が反映されるまで数分待機
3. アプリを再ビルドしてテスト

```bash
flutter clean
flutter pub get
flutter build apk --debug
```

## ✅ 確認方法

修正後、各PCで以下を確認してください：

1. アプリを起動
2. 「Googleでログイン」をタップ
3. Googleアカウント選択画面が表示される
4. ログインが成功する

## 📝 注意事項

- **デバッグ用証明書**: 開発時は各PCのデバッグ用証明書が必要
- **リリース用証明書**: 本番リリース時は統一されたリリース用証明書を使用
- **証明書の有効期限**: デバッグ証明書は通常30年間有効

## 🐛 トラブルシューティング

### エラー: `PlatformException(sign_in_failed)`

**原因**: SHA-1証明書が未登録または不正

**解決策**:
1. 上記手順でSHA-1証明書を正しく取得
2. Firebase Consoleに正確に追加
3. アプリを再ビルド

### エラー: `Google Play Services not available`

**原因**: Google Play Servicesの問題

**解決策**:
1. デバイスのGoogle Play Servicesを更新
2. Google Play Storeアプリを最新版に更新
3. デバイスを再起動

## 📋 チェックリスト

- [ ] 各PCでSHA-1証明書を取得
- [ ] Firebase ConsoleにSHA-1証明書を追加
- [ ] 設定を保存
- [ ] アプリを再ビルド
- [ ] 各PCでGoogle認証をテスト
- [ ] ログイン成功を確認

これで、すべてのPCでGoogle認証が動作するようになります！
