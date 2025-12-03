# キーストア設定手順（開発メンバー向け）

## 📋 概要

実機テストを行うために、すべての開発メンバーが同じリリース用キーストアを使用する必要があります。
これにより、すべての端末で同じフィンガープリントを使用してGoogleログインが動作します。

## 🔐 セキュリティ上の注意

- **キーストアファイルとパスワードは機密情報です**
- Gitリポジトリには含めません（`.gitignore`で除外されています）
- 安全な方法で共有してください（暗号化、セキュアな共有サービスなど）

## 🚀 セットアップ手順

### 1. キーストアファイルの取得

プロジェクトリーダーまたは管理者から、以下のファイルを安全な方法で受け取ってください：
- `android/app/spotlight-release-key.jks` - リリース用キーストアファイル
- キーストアのパスワード情報

### 2. キーストアファイルの配置

受け取ったキーストアファイルを以下の場所に配置してください：

```
android/app/spotlight-release-key.jks
```

### 3. key.propertiesファイルの作成

`android/key.properties.example`をコピーして`key.properties`を作成：

```bash
cd android
cp key.properties.example key.properties
```

### 4. key.propertiesの編集

`android/key.properties`を開いて、実際のパスワードを設定してください：

```properties
# キーストアのパスワード（プロジェクトリーダーから受け取ったパスワード）
storePassword=実際のパスワード

# キーのパスワード（通常はキーストアのパスワードと同じ）
keyPassword=実際のパスワード

# キーエイリアス名
keyAlias=spotlight

# キーストアファイルのパス
storeFile=spotlight-release-key.jks
```

### 5. 動作確認

設定が正しいか確認するため、以下のコマンドを実行してください：

```bash
cd android
./gradlew signingReport
```

出力で、リリース用キーストアのSHA-1が表示されることを確認してください：

**重要**: `signingReport`の出力では、`Variant: release`と表示されていても、`Config: debug`と表示される場合があります。
これは、デバッグビルドでもリリース用キーストアを使用する設定のためです。

正しく設定されている場合の出力例：

```
Variant: release
Config: debug  ← これは正常です（デバッグビルドでもリリース用キーストアを使用）
Store: [キーストアファイルのパス（spotlight-release-key.jks）]
Alias: spotlight
SHA1: 0E:4C:83:FC:B5:6E:DE:C5:A8:B5:B0:4A:E8:C3:D9:39:BB:0C:84:93
```

**確認ポイント**:
- `Store:`に`spotlight-release-key.jks`のパスが表示されている
- `Alias:`が`spotlight`になっている
- `SHA1:`が`0E:4C:83:FC:B5:6E:DE:C5:A8:B5:B0:4A:E8:C3:D9:39:BB:0C:84:93`になっている

もし`Store:`に`debug.keystore`が表示されている場合は、キーストアファイルが正しく読み込まれていません。
`key.properties`の設定とキーストアファイルの配置を確認してください。

### 6. ビルドとテスト

```bash
# デバッグビルド
flutter build apk --debug

# リリースビルド
flutter build apk --release
```

## ✅ 確認事項

- [ ] キーストアファイルが`android/app/spotlight-release-key.jks`に配置されている
- [ ] `android/key.properties`ファイルが作成されている
- [ ] `key.properties`に正しいパスワードが設定されている
- [ ] `signingReport`でリリース用キーストアのSHA-1が表示される
- [ ] ビルドが正常に完了する
- [ ] 実機でGoogleログインが動作する

## 🔧 トラブルシューティング

### エラー: キーストアファイルが見つかりません

- キーストアファイルが`android/app/`ディレクトリに配置されているか確認してください
- `key.properties`の`storeFile`パスが正しいか確認してください

### エラー: パスワードが間違っています

- `key.properties`のパスワードが正しいか確認してください
- キーストアファイルのパスワードと一致しているか確認してください

### デバッグキーストアが使用されている

- `key.properties`ファイルが存在するか確認してください
- `signingReport`の出力で、リリース用キーストアが使用されているか確認してください

## 📞 サポート

問題が解決しない場合は、プロジェクトリーダーまたは管理者に連絡してください。

