# S3とCloudFront設定ガイド

このドキュメントでは、EC2内のPostgreSQLからS3への移行と、CloudFrontを利用したコンテンツ配信の設定方法について説明します。

## 概要

### アーキテクチャ変更

**変更前:**
- メディアファイル（画像、動画、サムネイル、アイコン）: EC2サーバーから直接配信
- データベース: EC2内のPostgreSQL

**変更後:**
- メディアファイル: S3に保存 → CloudFront経由で配信
- データベース: EC2内のPostgreSQL（メタデータのみ）
- APIサーバー: EC2（メタデータのCRUD処理）

### メリット

1. **スケーラビリティ**: S3とCloudFrontによる高可用性・高パフォーマンス
2. **コスト削減**: EC2のストレージ容量を削減
3. **CDN配信**: CloudFrontによるグローバルな高速配信
4. **可用性向上**: S3の99.999999999%（11 9's）の耐久性

---

## AWS設定手順

### 1. S3バケットの作成

#### 1.1 バケット作成

1. AWSマネジメントコンソールでS3にアクセス
2. 「バケットを作成」をクリック
3. 以下の設定を行う:

```
バケット名: spotlight-media-[環境名] (例: spotlight-media-production)
AWSリージョン: ap-northeast-1 (東京)
パブリックアクセス: すべてブロック（CloudFront経由でアクセス）
バケットバージョニング: 有効化（推奨）
デフォルトの暗号化: 有効化（SSE-S3）
```

#### 1.2 バケットポリシーの設定

バケットポリシーでCloudFrontからのアクセスのみを許可:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipal",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::spotlight-media-production/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::[アカウントID]:distribution/[ディストリビューションID]"
        }
      }
    }
  ]
}
```

#### 1.3 フォルダ構造

S3バケット内の推奨フォルダ構造:

```
spotlight-media-production/
├── content/
│   ├── movie/          # 動画ファイル
│   ├── image/          # 画像ファイル
│   ├── audio/          # 音声ファイル
│   └── text/           # テキストファイル（必要に応じて）
├── thumbnail/          # サムネイル画像
└── icon/               # ユーザーアイコン
```

---

### 2. CloudFrontディストリビューションの作成

#### 2.1 ディストリビューション作成

1. AWSマネジメントコンソールでCloudFrontにアクセス
2. 「ディストリビューションを作成」をクリック
3. 以下の設定を行う:

**オリジンドメイン:**
- S3バケットを選択（例: `spotlight-media-production.s3.ap-northeast-1.amazonaws.com`）

**オリジンアクセス:**
- 「Origin access control settings (recommended)」を選択
- 新しいOAC（Origin Access Control）を作成

**デフォルトのキャッシュ動作:**
- ビューワープロトコルポリシー: Redirect HTTP to HTTPS
- 許可されたHTTPメソッド: GET, HEAD, OPTIONS
- キャッシュキーとオリジンリクエスト: 簡易設定
- オブジェクトのキャッシュ: カスタマイズ
  - デフォルトTTL: 86400（1日）
  - 最大TTL: 31536000（1年）
  - 最小TTL: 0

**設定:**
- 価格クラス: すべてのエッジロケーション（最適なパフォーマンス）
- 代替ドメイン名（CNAME）: `cdn.spotlight.app`（オプション）
- SSL証明書: AWS Certificate Manager（ACM）で証明書を取得

#### 2.2 オリジンアクセス制御（OAC）の設定

1. CloudFrontコンソールで「Origin access control」を開く
2. 「Create control setting」をクリック
3. 設定:
   - 名前: `spotlight-s3-oac`
   - 署名の動作: Sign requests (recommended)
   - 署名バージョン: v4

#### 2.3 S3バケットポリシーの更新

CloudFrontのOAC用にバケットポリシーを更新:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontOAC",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::spotlight-media-production/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::[アカウントID]:distribution/[ディストリビューションID]"
        }
      }
    }
  ]
}
```

---

### 3. IAMロールの設定（バックエンド用）

EC2のバックエンドサーバーからS3にアクセスするためのIAMロールを作成:

#### 3.1 IAMポリシーの作成

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "arn:aws:s3:::spotlight-media-production/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::spotlight-media-production"
    }
  ]
}
```

#### 3.2 EC2インスタンスにIAMロールをアタッチ

1. EC2コンソールでインスタンスを選択
2. 「アクション」→「セキュリティ」→「IAMロールの変更」
3. 作成したIAMロールを選択

---

## バックエンド側の変更

### 1. ファイルアップロード処理の変更

#### 1.1 AWS SDKのインストール

```bash
npm install @aws-sdk/client-s3
```

#### 1.2 S3アップロード関数の実装例

```javascript
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const fs = require('fs');

const s3Client = new S3Client({
  region: 'ap-northeast-1',
});

async function uploadToS3(fileBuffer, key, contentType) {
  const command = new PutObjectCommand({
    Bucket: 'spotlight-media-production',
    Key: key,
    Body: fileBuffer,
    ContentType: contentType,
    // ACLは不要（CloudFront経由でアクセス）
  });

  await s3Client.send(command);
  
  // CloudFront URLを返す
  return `https://d1234567890.cloudfront.net/${key}`;
}

// 使用例
async function handleFileUpload(base64Data, fileName, fileType) {
  const buffer = Buffer.from(base64Data, 'base64');
  const key = `content/${fileType}/${fileName}`;
  const contentType = getContentType(fileType);
  
  await uploadToS3(buffer, key, contentType);
  
  // データベースにはS3のキー（パス）を保存
  return key; // 例: "content/movie/uid_timestamp.mp4"
}
```

### 2. データベーススキーマの確認

データベースには、S3のキー（パス）のみを保存:

```sql
-- contentテーブル
contentpath VARCHAR(255)  -- 例: "content/movie/uid_timestamp.mp4"
thumbnailpath VARCHAR(255) -- 例: "thumbnail/uid_timestamp_thumb.jpg"

-- userテーブル
iconimgpath VARCHAR(255)  -- 例: "icon/username_icon.png"
```

### 3. APIレスポンスの変更

APIレスポンスは変更不要（パスのみを返す）:

```json
{
  "status": "success",
  "data": {
    "contentID": 123,
    "contentpath": "content/movie/uid_timestamp.mp4",
    "thumbnailpath": "thumbnail/uid_timestamp_thumb.jpg"
  }
}
```

フロントエンド側でCloudFront URLと結合して完全なURLを生成します。

---

## Flutterアプリ側の設定

### 1. 設定ファイルの更新

`lib/config/app_config.dart`にCloudFront URLを設定:

```dart
// CloudFrontのURL（S3コンテンツ配信用）
static String get cloudFrontUrl {
  if (isDevelopment) {
    return 'https://d1234567890.cloudfront.net'; // 開発環境
  } else {
    return 'https://d1234567890.cloudfront.net'; // 本番環境
  }
}
```

**重要**: `d1234567890.cloudfront.net`を実際のCloudFrontディストリビューションのドメイン名に置き換えてください。

### 2. メディアURLの生成

`lib/models/post.dart`で、メディアファイルのURL生成にCloudFront URLを使用:

```dart
// メディアファイルはCloudFront経由で配信
final mediaUrl = _buildFullUrl(AppConfig.mediaBaseUrl, contentPath);
final thumbnailUrl = _buildFullUrl(AppConfig.mediaBaseUrl, thumbnailPath);
final userIconUrl = _buildFullUrl(AppConfig.mediaBaseUrl, iconPath);
```

### 3. 動作確認

1. アプリを起動
2. 投稿一覧を表示
3. メディアファイル（画像、動画）がCloudFront経由で読み込まれることを確認
4. ブラウザの開発者ツールで、リクエストURLがCloudFrontドメインになっていることを確認

---

## 移行手順

### 1. 既存データの移行

#### 1.1 EC2からS3へのファイル移行

```bash
# AWS CLIを使用してファイルを移行
aws s3 sync /path/to/ec2/media s3://spotlight-media-production/ \
  --exclude "*.log" \
  --exclude "*.tmp"
```

#### 1.2 データベースの更新

既存のファイルパスが相対パスの場合、そのまま使用可能。
絶対パス（`http://...`）の場合は、S3キーに変換する必要があります。

```sql
-- 例: 絶対パスを相対パスに変換
UPDATE content 
SET contentpath = REPLACE(contentpath, 'http://54.150.123.156:5000/', '')
WHERE contentpath LIKE 'http://%';
```

### 2. 段階的移行

1. **フェーズ1**: 新規アップロードをS3に保存（既存ファイルはEC2から配信）
2. **フェーズ2**: 既存ファイルをS3に移行
3. **フェーズ3**: すべてのファイルをCloudFront経由で配信

---

## トラブルシューティング

### 問題1: CloudFrontから403エラー

**原因**: S3バケットポリシーまたはOACの設定が不適切

**解決策**:
1. CloudFrontのOAC設定を確認
2. S3バケットポリシーでCloudFrontのARNを許可
3. バケットのパブリックアクセスをブロック（CloudFront経由のみ）

### 問題2: 画像が表示されない

**原因**: CloudFront URLが正しく設定されていない

**解決策**:
1. `AppConfig.cloudFrontUrl`が正しいか確認
2. ブラウザの開発者ツールでネットワークタブを確認
3. CloudFrontディストリビューションのステータスが「Deployed」になっているか確認

### 問題3: キャッシュが更新されない

**原因**: CloudFrontのキャッシュTTL設定

**解決策**:
1. CloudFrontでキャッシュ無効化を実行
2. 開発環境では最小TTLを0に設定
3. バージョニングを使用（ファイル名にタイムスタンプを含める）

---

## コスト最適化

### 1. CloudFrontの価格クラス

- **すべてのエッジロケーション**: 最高パフォーマンス、高コスト
- **北米・ヨーロッパ・アジア**: バランス型（推奨）
- **北米・ヨーロッパのみ**: 低コスト

### 2. S3のストレージクラス

- **Standard**: 頻繁にアクセスされるファイル
- **Standard-IA**: アクセス頻度が低いファイル
- **Glacier**: アーカイブファイル

### 3. CloudFrontのキャッシュ設定

適切なTTL設定でS3へのリクエストを削減:
- 画像・サムネイル: 1日〜1週間
- 動画: 1週間〜1ヶ月

---

## セキュリティ考慮事項

1. **S3バケットのパブリックアクセスをブロック**: CloudFront経由のみでアクセス
2. **CloudFrontの署名付きURL**: 機密コンテンツには署名付きURLを使用
3. **HTTPS必須**: CloudFrontでHTTPSを強制
4. **CORS設定**: 必要に応じてCORSを設定

---

## 参考リンク

- [AWS S3 ドキュメント](https://docs.aws.amazon.com/s3/)
- [AWS CloudFront ドキュメント](https://docs.aws.amazon.com/cloudfront/)
- [AWS SDK for JavaScript v3](https://docs.aws.amazon.com/sdk-for-javascript/v3/)

---

**最終更新**: 2025年1月
**作成者**: SpotLight開発チーム

