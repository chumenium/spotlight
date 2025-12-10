# Google Cloud Console 設定ガイド

## 🚨 現在の状況

- ✅ `google-services.json` にSHA-1フィンガープリントが正しく設定済み
- ✅ Firebase Console でGoogle Sign-Inが有効化済み
- ❌ **ApiException: 10** エラーが継続

## 🔧 Google Cloud Console での詳細設定

### 1. Google Cloud Console にアクセス

1. [Google Cloud Console](https://console.cloud.google.com/) を開く
2. プロジェクト「spotlight-597c4」を選択
3. 左メニュー「APIとサービス」→「認証情報」をクリック

### 2. 現在のOAuth 2.0 クライアント ID を確認

#### 期待される設定:

**Android クライアント:**
- **名前**: Android client 1 (または類似)
- **アプリケーションの種類**: Android
- **パッケージ名**: `com.example.spotlight`
- **SHA-1証明書フィンガープリント**: `9D:DC:B4:98:44:0F:F8:D1:27:EF:9A:2E:6C:C8:72:AF:34:D0:80:57`

**Web クライアント:**
- **名前**: Web client 1 (または類似)
- **アプリケーションの種類**: ウェブ アプリケーション
- **クライアント ID**: `185578323389-jouqlpvh55a25gt36vuu00i8pa95di3n.apps.googleusercontent.com`

### 3. 新しいAndroid OAuth クライアントを作成

既存の設定に問題がある場合、新しいクライアントを作成:

1. **「認証情報を作成」** → **「OAuth クライアント ID」**
2. **アプリケーションの種類**: **Android** を選択
3. **名前**: `SpotLight Android Debug`
4. **パッケージ名**: `com.example.spotlight`
5. **SHA-1証明書フィンガープリント**: `9D:DC:B4:98:44:0F:F8:D1:27:EF:9A:2E:6C:C8:72:AF:34:D0:80:57`
6. **「作成」** をクリック

### 4. Web OAuth クライアントの確認・作成

1. **「認証情報を作成」** → **「OAuth クライアント ID」**
2. **アプリケーションの種類**: **ウェブ アプリケーション** を選択
3. **名前**: `SpotLight Web Client`
4. **承認済みの JavaScript 生成元**: (空でOK)
5. **承認済みのリダイレクト URI**: (空でOK)
6. **「作成」** をクリック

### 5. Firebase Console での再設定

新しいクライアントIDを作成した場合:

1. [Firebase Console](https://console.firebase.google.com/) → プロジェクト「spotlight-597c4」
2. **Authentication** → **Sign-in method** → **Google**
3. **「編集」** をクリック
4. **Web SDK 設定** で新しいWebクライアントIDを選択
5. **「保存」** をクリック

### 6. google-services.json の再ダウンロード

1. Firebase Console → **プロジェクト設定** → **Android アプリ**
2. **「google-services.json をダウンロード」**
3. `android/app/google-services.json` を置き換え

## 🔍 デバッグ情報の確認

修正されたコードでは以下の情報が表示されます:

```
🔐 [Google] 設定確認:
  - Firebase Google Sign-In有効: true
  - Google Sign-Inスコープ: [email, profile]
  - パッケージ名: com.example.spotlight
  - AuthDebugLog有効: true
  - 既存のGoogle Sign-Inユーザー: なし
  - WebクライアントID: 185578323389-jouqlpvh55a25gt36vuu00i8pa95di3n.apps.googleusercontent.com
  - Google Play Services利用可能: false
```

## 🚨 よくある問題と解決策

### 問題1: Google Play Services が古い

**症状**: `Google Play Services利用可能: false`

**解決策**:
1. デバイスの設定 → アプリ → Google Play Services
2. 「更新」または「有効化」
3. デバイスを再起動

### 問題2: OAuth クライアント設定の不一致

**症状**: SHA-1は正しいが ApiException: 10 が継続

**解決策**:
1. Google Cloud Console で既存のAndroidクライアントを削除
2. 新しいAndroidクライアントを作成
3. Firebase Console でGoogle Sign-Inを再設定

### 問題3: パッケージ名の不一致

**症状**: 設定は正しく見えるが認証に失敗

**解決策**:
1. `android/app/build.gradle.kts` でパッケージ名を確認
2. Google Cloud Console の設定と完全一致させる

## 📋 完全なチェックリスト

- [ ] Google Cloud Console でプロジェクト「spotlight-597c4」を確認
- [ ] Android OAuth クライアントが存在し、正しいパッケージ名とSHA-1が設定されている
- [ ] Web OAuth クライアントが存在する
- [ ] Firebase Console でGoogle Sign-Inが有効で、正しいWebクライアントIDが設定されている
- [ ] 最新の google-services.json をダウンロード・配置
- [ ] Google Play Services が最新版
- [ ] アプリを完全に再ビルド (`flutter clean && flutter run`)

## 🆘 最終手段

上記すべてを試してもエラーが解消されない場合:

### 新しいFirebaseプロジェクトの作成

1. **新しいFirebaseプロジェクト作成**
2. **Google Sign-In設定**
3. **SHA-1フィンガープリント登録**
4. **新しい google-services.json 取得**
5. **アプリ設定の更新**

この手順により、設定の問題を根本的に解決できます。
