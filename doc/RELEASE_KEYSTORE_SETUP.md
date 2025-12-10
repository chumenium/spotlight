# 本番リリース用証明書の設定手順

## 🎯 概要

開発時は各PCで異なるデバッグ証明書を使用しますが、本番リリース用の統一された証明書（キーストア）を作成することで、すべてのPCで同じ証明書を共有できます。

## 🔑 リリース用キーストアの作成

### 1. キーストアファイルの生成

以下のコマンドでリリース用キーストアを作成します：

```bash
keytool -genkey -v -keystore spotlight-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias spotlight
```

### 2. 入力項目

コマンド実行時に以下の情報を入力してください：

```
キーストアのパスワードを入力してください: [強力なパスワードを設定]
新規パスワードを再入力してください: [同じパスワードを再入力]

姓名を入力してください: SpotLight App
組織単位名を入力してください: Development Team
組織名を入力してください: SpotLight
都市名または地域名を入力してください: Tokyo
都道府県名または州名を入力してください: Tokyo
この単位に該当する2文字の国コードを入力してください: JP

CN=SpotLight App, OU=Development Team, O=SpotLight, L=Tokyo, ST=Tokyo, C=JP でよろしいですか? [いいえ]: y

<spotlight>のキー・パスワードを入力してください (キーストアのパスワードと同じ場合はRETURNを押してください): [Enterキーを押す]
```

### 3. 生成されるファイル

- `spotlight-release-key.jks` - リリース用キーストアファイル

## 🔧 Android設定の更新

### 1. キーストアファイルの配置

```bash
# キーストアファイルをandroidフォルダに移動
mv spotlight-release-key.jks android/app/
```

### 2. key.propertiesファイルの作成

`android/key.properties`ファイルを作成：

```properties
storePassword=あなたが設定したキーストアパスワード
keyPassword=あなたが設定したキーパスワード
keyAlias=spotlight
storeFile=spotlight-release-key.jks
```

### 3. build.gradleの更新

`android/app/build.gradle`を編集：

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // 既存の設定...

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
        debug {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            // 既存の設定...
        }
        debug {
            signingConfig signingConfigs.debug
            // 既存の設定...
        }
    }
}
```

## 🔐 SHA-1証明書の取得

### 1. リリース用SHA-1の取得

```bash
cd android
./gradlew signingReport
```

### 2. 出力例

```
Variant: release
Config: release
Store: C:\path\to\spotlight-release-key.jks
Alias: spotlight
MD5: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
SHA1: AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00:AA:BB:CC:DD  ← この値をコピー
SHA-256: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
Valid until: 2051年XX月XX日
```

## 🔥 Firebase Consoleの設定

### 1. SHA-1証明書の追加

1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. プロジェクト「spotlight-597c4」を選択
3. 左メニューから「プロジェクトの設定」をクリック
4. 「全般」タブ → 「マイアプリ」セクション
5. Androidアプリ「com.example.spotlight」の設定アイコンをクリック
6. 「SHA証明書フィンガープリント」で「証明書を追加」
7. **リリース用SHA-1証明書**を追加

### 2. 証明書の管理

Firebase Consoleに以下の証明書が登録されます：

- **デバッグ用**: `9ddcb498440ff8d127ef9a2e6cc872af34d08057` （開発時用）
- **リリース用**: `[新しく取得したリリース用SHA-1]` （本番・共有用）

## 📁 ファイル共有の設定

### 1. .gitignoreの更新

機密情報を保護するため、`.gitignore`に追加：

```gitignore
# キーストア関連（機密情報）
android/key.properties
android/app/spotlight-release-key.jks

# または、暗号化して共有する場合
# android/key.properties.encrypted
# android/app/spotlight-release-key.jks.encrypted
```

### 2. チーム共有方法

#### 方法A: セキュアな共有（推奨）

1. **キーストアファイルを暗号化**
2. **パスワードを別途安全に共有**（1Password、Bitwarden等）
3. **各開発者が復号化して使用**

#### 方法B: 環境変数での管理

```bash
# 各開発者の環境で設定
export SPOTLIGHT_STORE_PASSWORD="your_keystore_password"
export SPOTLIGHT_KEY_PASSWORD="your_key_password"
```

`key.properties`を環境変数対応に：

```properties
storePassword=${SPOTLIGHT_STORE_PASSWORD}
keyPassword=${SPOTLIGHT_KEY_PASSWORD}
keyAlias=spotlight
storeFile=spotlight-release-key.jks
```

## 🚀 ビルドとテスト

### 1. リリースビルドの作成

```bash
flutter clean
flutter pub get
flutter build apk --release
```

### 2. デバッグビルドでのテスト

```bash
flutter build apk --debug
```

### 3. 証明書の確認

```bash
# APKファイルの証明書を確認
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

## ✅ 動作確認

### 1. Google認証のテスト

1. リリースビルドしたAPKをインストール
2. 「Googleでログイン」をタップ
3. 正常にログインできることを確認

### 2. すべてのPCでの確認

各開発PCで：

1. 同じキーストアファイルを使用
2. 同じkey.propertiesを設定
3. ビルド・テストを実行
4. Google認証が動作することを確認

## 🔒 セキュリティのベストプラクティス

### 1. キーストアの保護

- **バックアップを複数箇所に保存**
- **パスワードを安全に管理**
- **アクセス権限を制限**

### 2. 本番環境での注意

- **リリース用証明書は絶対に紛失しない**
- **Google Play Storeでは同じ証明書が必要**
- **証明書を変更すると新しいアプリとして扱われる**

## 📋 チェックリスト

- [ ] リリース用キーストアを作成
- [ ] key.propertiesファイルを設定
- [ ] build.gradleを更新
- [ ] SHA-1証明書を取得
- [ ] Firebase ConsoleにSHA-1を追加
- [ ] .gitignoreを更新
- [ ] チームでキーストアを共有
- [ ] 各PCでビルドテスト
- [ ] Google認証の動作確認

これで、すべてのPCで統一された証明書を使用してGoogle認証が動作するようになります！
