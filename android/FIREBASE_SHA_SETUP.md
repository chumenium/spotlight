# Firebase SHA-1/SHA-256 フィンガープリント登録手順

## 📋 概要

Firebase Consoleに**リリース用キーストア**（`spotlight-release-key.jks`）のSHA-1とSHA-256フィンガープリントを登録することで、すべての環境（開発/本番）でGoogleログインが動作します。

## 🔑 重要なポイント

- **リリース用キーストアのフィンガープリントを登録してください**
- これにより、開発環境でも本番環境でも同じフィンガープリントを使用できます
- キーストアを変更しない限り、フィンガープリントは変わりません

## 📝 手順

### 1. SHA-1/SHA-256フィンガープリントの取得

#### Windowsの場合

```powershell
cd android/app
keytool -list -v -keystore spotlight-release-key.jks -alias spotlight
```

パスワードを入力すると、以下のような出力が表示されます：

```
証明書のフィンガープリント:
     SHA1: AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD
     SHA256: 11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00
```

#### macOS/Linuxの場合

```bash
cd android/app
keytool -list -v -keystore spotlight-release-key.jks -alias spotlight
```

### 2. Firebase Consoleでの登録

1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. プロジェクトを選択
3. 左メニューから「プロジェクトの設定」をクリック
4. 「マイアプリ」セクションで、Androidアプリを選択（または新規追加）
5. 「SHA証明書フィンガープリント」セクションまでスクロール
6. 「フィンガープリントを追加」ボタンをクリック
7. 取得したSHA-1とSHA-256をそれぞれ登録
   - SHA-1: `AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD`（例）
   - SHA-256: `11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00`（例）

### 3. google-services.jsonの更新

Firebase Consoleでフィンガープリントを登録した後、`google-services.json`をダウンロードして更新してください：

1. Firebase Consoleの「プロジェクトの設定」→「マイアプリ」→ Androidアプリ
2. `google-services.json`をダウンロード
3. `android/app/google-services.json`を置き換え

## ✅ 確認事項

- [ ] リリース用キーストア（`spotlight-release-key.jks`）のSHA-1を取得した
- [ ] リリース用キーストア（`spotlight-release-key.jks`）のSHA-256を取得した
- [ ] Firebase ConsoleにSHA-1を登録した
- [ ] Firebase ConsoleにSHA-256を登録した
- [ ] `google-services.json`を更新した

## 🔐 セキュリティ上の注意

- **キーストアファイル（.jks）は機密情報です**
- Gitリポジトリには含めないでください（`.gitignore`で除外されています）
- フィンガープリントは公開情報ですが、キーストアファイル自体は厳重に管理してください

## 🎯 なぜリリース用キーストアを使用するのか？

- **統一されたフィンガープリント**: すべての環境（開発/本番）で同じフィンガープリントを使用
- **環境に依存しない**: 開発環境が変わっても、同じキーストアを使用するため、Firebase設定を変更する必要がない
- **永続的**: キーストアを変更しない限り、フィンガープリントは変わりません
