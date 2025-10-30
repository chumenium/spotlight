# Google Sign-In エラー解決ガイド

## 🚨 現在のエラー

```
ApiException: 10 - sign_in_failed
```

このエラーは、Google Sign-Inの設定に問題があることを示しています。

## 🔧 解決手順

### 1. Firebase Console での設定確認

#### 1.1 Google Sign-In の有効化確認

1. [Firebase Console](https://console.firebase.google.com/) にアクセス
2. プロジェクト「spotlight-597c4」を選択
3. 左メニュー「Authentication」→「Sign-in method」
4. 「Google」プロバイダーが **有効** になっているか確認
5. 無効の場合は有効化し、サポートメールを設定

#### 1.2 SHA-1 フィンガープリントの確認・追加

**現在のSHA-1フィンガープリント:**
```
9D:DC:B4:98:44:0F:F8:D1:27:EF:9A:2E:6C:C8:72:AF:34:D0:80:57
```

**Firebase Console での確認:**
1. Firebase Console → プロジェクト設定（歯車アイコン）
2. 「マイアプリ」セクションで Android アプリを選択
3. 「SHA証明書フィンガープリント」セクションを確認
4. 上記のSHA-1が登録されているか確認
5. **登録されていない場合は追加**

**SHA-1の追加方法:**
1. 「SHA証明書フィンガープリントを追加」をクリック
2. `9DDCB498440FF8D127EF9A2E6CC872AF34D08057` を入力（コロンなし）
3. 「保存」をクリック

### 2. Google Cloud Console での設定確認

#### 2.1 OAuth 2.0 クライアント ID の確認

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. プロジェクト「spotlight-597c4」を選択
3. 「APIとサービス」→「認証情報」
4. OAuth 2.0 クライアント ID を確認

**期待される設定:**
- **アプリケーションの種類**: Android
- **パッケージ名**: `com.example.spotlight`
- **SHA-1証明書フィンガープリント**: `9D:DC:B4:98:44:0F:F8:D1:27:EF:9A:2E:6C:C8:72:AF:34:D0:80:57`

#### 2.2 新しいクライアント ID の作成（必要に応じて）

既存の設定に問題がある場合：

1. 「認証情報を作成」→「OAuth クライアント ID」
2. アプリケーションの種類: **Android**
3. 名前: `SpotLight Android`
4. パッケージ名: `com.example.spotlight`
5. SHA-1証明書フィンガープリント: `9D:DC:B4:98:44:0F:F8:D1:27:EF:9A:2E:6C:C8:72:AF:34:D0:80:57`
6. 「作成」をクリック

### 3. google-services.json の更新

設定変更後は、新しい `google-services.json` をダウンロード：

1. Firebase Console → プロジェクト設定 → Android アプリ
2. 「google-services.json をダウンロード」
3. `android/app/google-services.json` を置き換え

### 4. アプリの再ビルド

設定変更後は必ずアプリを再ビルド：

```bash
flutter clean
flutter pub get
flutter run
```

## 🔍 デバッグ情報の確認

修正されたコードでは、以下のデバッグ情報が表示されます：

```
🔐 [Google] Sign-In開始
🔐 [Google] 設定確認:
  - Firebase Google Sign-In有効: true
  - Google Sign-Inスコープ: [email, profile]
  - パッケージ名: com.example.spotlight
```

## 📋 チェックリスト

- [ ] Firebase Console で Google Sign-In が有効化されている
- [ ] SHA-1フィンガープリントが Firebase Console に登録されている
- [ ] Google Cloud Console で OAuth 2.0 クライアント ID が正しく設定されている
- [ ] パッケージ名 `com.example.spotlight` が一致している
- [ ] 最新の `google-services.json` を使用している
- [ ] アプリを再ビルドした

## 🆘 それでも解決しない場合

### 追加の確認事項

1. **Google Play Services の更新**
   - デバイスの Google Play Services が最新版か確認

2. **デバッグキーと本番キーの違い**
   - 本番リリース時は本番用のSHA-1も追加が必要

3. **Firebase プロジェクトの再作成**
   - 最終手段として新しい Firebase プロジェクトを作成

### ログの確認

エラー発生時は以下のログを確認：

```
🔐 [Google] プラットフォームエラー: sign_in_failed - com.google.android.gms.common.api.ApiException: 10
🔐 [Google] SHA-1フィンガープリントまたはクライアント設定を確認してください
```

## 💡 よくある原因

1. **SHA-1未登録**: 最も一般的な原因
2. **パッケージ名不一致**: `com.example.spotlight` 以外になっている
3. **Google Sign-In無効**: Firebase Console で有効化されていない
4. **古い設定ファイル**: `google-services.json` が古い

この手順に従って設定を確認・修正してください。
