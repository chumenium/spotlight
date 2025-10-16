# Spotlight バックエンド API

このディレクトリには、SpotlightアプリケーションのPythonバックエンドAPIが含まれています。

## 技術スタック

- **Flask**: Webフレームワーク
- **SQLAlchemy**: ORM（Object-Relational Mapping）
- **SQLite**: データベース（開発用）
- **Flask-CORS**: クロスオリジンリクエストの処理

## セットアップ

### 1. 仮想環境の作成とアクティベート

```bash
# 仮想環境の作成
python -m venv venv

# Windowsでのアクティベート
venv\Scripts\activate

# macOS/Linuxでのアクティベート
source venv/bin/activate
```

### 2. 依存関係のインストール

```bash
pip install -r requirements.txt
```

### 3. アプリケーションの起動

```bash
python app.py
```

サーバーは `http://localhost:5000` で起動します。

## API エンドポイント

### 投稿関連

- `GET /api/posts` - すべての投稿を取得
- `GET /api/posts/<id>` - 特定の投稿を取得
- `POST /api/posts` - 新しい投稿を作成
- `PUT /api/posts/<id>` - 投稿を更新
- `DELETE /api/posts/<id>` - 投稿を削除

### 検索履歴関連

- `GET /api/search-history?user_id=<user_id>` - ユーザーの検索履歴を取得
- `POST /api/search-history` - 検索履歴を追加
- `DELETE /api/search-history/<id>` - 検索履歴を削除

### その他

- `GET /api/health` - ヘルスチェック

## データベースモデル

### Post（投稿）
- `id`: 主キー
- `title`: タイトル
- `content`: コンテンツ
- `author`: 作成者
- `created_at`: 作成日時
- `updated_at`: 更新日時

### SearchHistory（検索履歴）
- `id`: 主キー
- `query`: 検索クエリ
- `user_id`: ユーザーID
- `created_at`: 作成日時

## 使用例

### 投稿の作成

```bash
curl -X POST http://localhost:5000/api/posts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "テスト投稿",
    "content": "これはテスト投稿です",
    "author": "テストユーザー"
  }'
```

### 投稿の取得

```bash
curl http://localhost:5000/api/posts
```

### 検索履歴の追加

```bash
curl -X POST http://localhost:5000/api/search-history \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Flutter チュートリアル",
    "user_id": "user123"
  }'
```

## 開発時の注意事項

- データベースファイル（`spotlight.db`）は自動的に作成されます
- 開発モードでは `debug=True` で実行されます
- CORSが有効になっているため、フロントエンドからのリクエストが可能です

## 本番環境への展開

本番環境では以下の変更を推奨します：

1. `debug=False` に設定
2. より堅牢なデータベース（PostgreSQL、MySQL等）を使用
3. 環境変数でシークレットキーを管理
4. HTTPSの使用
5. 適切なログ設定