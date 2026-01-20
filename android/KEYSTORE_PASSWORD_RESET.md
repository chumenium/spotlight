# キーストアパスワードを忘れた場合の対処法

## 📋 概要

キーストアのパスワードを忘れた場合の対処方法を説明します。

## ⚠️ 重要な注意事項

- **キーストアのパスワードは復元できません**
- パスワードがわからない場合、既存のキーストアを使用することはできません
- 既にGoogle Play Consoleにアプリをリリースしている場合、同じキーストアが必要です

## 🔍 パスワードを思い出すための確認事項

### 1. ドキュメントを確認

プロジェクトのドキュメントにパスワードが記載されている可能性があります：

- `android/KEYSTORE_SETUP.md` - トラブルシューティングセクションを確認
- プロジェクトのREADMEやセットアップ手順を確認

### 2. パスワード管理ツールを確認

以下のパスワード管理ツールを確認してください：

- 1Password
- Bitwarden
- LastPass
- ブラウザのパスワードマネージャー
- メモ帳やテキストファイル（安全な場所）

### 3. チームメンバーに確認

- プロジェクトリーダー
- 管理者
- 他の開発メンバー

### 4. key.propertiesファイルを確認

既存の`android/key.properties`ファイルにパスワードが保存されている可能性があります：

```properties
storePassword=パスワードがここに記載されている可能性があります
keyPassword=パスワードがここに記載されている可能性があります
```

**注意**: `key.properties`ファイルは`.gitignore`で除外されているため、ローカル環境でのみ確認できます。

## 📝 記載されているパスワードを試す

ドキュメント（`android/KEYSTORE_SETUP.md`）に以下のパスワードが記載されています：

```
storePassword=kcsf2026
keyPassword=kcsf2026
```

このパスワードを試してください。

### パスワード確認手順

1. `android/key.properties`ファイルを開く（存在しない場合は作成）

2. 以下の内容を設定：

```properties
storePassword=kcsf2026
keyPassword=kcsf2026
keyAlias=spotlight
storeFile=spotlight-release-key.jks
```

3. ビルドを試す：

```bash
cd android
./gradlew signingReport
```

または

```bash
flutter build apk --release
```

4. パスワードが正しい場合、ビルドが成功します
5. パスワードが間違っている場合、エラーが表示されます

## ❌ パスワードがわからない場合の対処

### 既にGoogle Play Consoleにアプリをリリースしている場合

**⚠️ 新しいキーストアを作成することはできません**

- Google Play Consoleにアプリをリリースしている場合、同じキーストアを使用する必要があります
- 新しいキーストアを使用すると、既存のアプリを更新できなくなります
- この場合、パスワードを思い出すか、バックアップからキーストアを復元する必要があります

### まだGoogle Play Consoleにアプリをリリースしていない場合

新しいキーストアを作成することができます：

1. **新しいキーストアを作成**

```bash
cd android/app
keytool -genkey -v -keystore spotlight-release-key-new.jks -keyalg RSA -keysize 2048 -validity 10000 -alias spotlight
```

2. **key.propertiesを更新**

```properties
storePassword=新しいパスワード
keyPassword=新しいパスワード
keyAlias=spotlight
storeFile=spotlight-release-key-new.jks
```

3. **Firebase ConsoleのSHA-1/SHA-256を更新**

新しいキーストアのSHA-1とSHA-256フィンガープリントを取得して、Firebase Consoleに登録してください。

## 🔐 パスワードが見つかった後の対策

パスワードが見つかった後は、以下の対策を推奨します：

1. **パスワード管理ツールに保存**
   - 1Password、Bitwardenなどのパスワード管理ツールに保存
   - チームで安全に共有

2. **バックアップを作成**
   - キーストアファイルのバックアップを作成
   - 安全な場所に保管（暗号化推奨）

3. **ドキュメントを更新**
   - パスワード管理のベストプラクティスをドキュメントに追加
   - チームメンバーとパスワード管理方法を共有

## 📞 サポート

問題が解決しない場合は、以下に連絡してください：

- プロジェクトリーダー
- 管理者
- チームメンバー
