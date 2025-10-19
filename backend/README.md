# SpotLight バックエンド API

このディレクトリには、SpotLightアプリケーションのFlaskバックエンドAPIが含まれています。

## 📁 プロジェクト構造

```
backend/
├── app.py                 # メインアプリケーションファイル
├── requirements.txt       # Python依存パッケージ
├── env.example           # 環境変数のサンプル
├── .gitignore            # Git除外設定
├── config/               # 設定ファイル
│   ├── __init__.py
│   └── settings.py       # アプリケーション設定
├── routes/               # APIエンドポイント
│   ├── __init__.py
│   ├── auth.py          # 認証関連
│   ├── posts.py         # 投稿関連
│   ├── comments.py      # コメント関連
│   ├── search.py        # 検索関連
│   ├── users.py         # ユーザー関連
│   └── notifications.py # 通知関連
├── models/              # データモデル（DB担当が実装）
│   └── __init__.py
└── utils/               # ユーティリティ
    ├── __init__.py
    └── auth.py          # 認証ユーティリティ
```

## 🚀 セットアップ手順

### 1. リポジトリのクローン（または最新版の取得）

```bash
git clone <repository-url>
cd spotlight/backend

# または既にクローン済みの場合
git pull origin main
```

### 2. 仮想環境の作成とアクティベート

```bash
# 仮想環境の作成
python3 -m venv venv

# macOS/Linuxでのアクティベート
source venv/bin/activate

# Windowsでのアクティベート
venv\Scripts\activate
```

### 3. 依存パッケージのインストール

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

**注意**: PostgreSQL関連のパッケージ（psycopg2-binary）は、DB担当メンバーがPostgreSQLをセットアップした後にインストールしてください。

```bash
# PostgreSQLセットアップ後に実行
pip install psycopg2-binary==2.9.9
```

### 4. 環境変数の設定

```bash
# サンプルファイルをコピー
cp env.example .env

# .envファイルを編集（必要に応じて値を変更）
# 特にSECRET_KEYとJWT_SECRETは必ず変更してください
```

### 5. サーバーの起動

```bash
# 開発サーバーを起動
python app.py
```

サーバーは `http://localhost:5000` で起動します。

## 📝 API エンドポイント

### ヘルスチェック
- `GET /api/health` - サーバーの稼働確認

### 認証 API
- `POST /api/auth/register` - ユーザー登録
- `POST /api/auth/login` - ログイン
- `POST /api/auth/google` - Google認証

### 投稿 API
- `GET /api/posts` - 投稿一覧取得
- `POST /api/posts` - 投稿作成（認証必須）
- `GET /api/posts/<post_id>` - 投稿詳細取得
- `POST /api/posts/<post_id>/spotlight` - スポットライト実行（認証必須）
- `DELETE /api/posts/<post_id>/spotlight` - スポットライト解除（認証必須）

### コメント API
- `GET /api/posts/<post_id>/comments` - コメント一覧取得
- `POST /api/posts/<post_id>/comments` - コメント作成（認証必須）

### 検索 API
- `GET /api/search?q=<query>` - 検索実行
- `GET /api/search/suggestions?q=<query>` - 検索候補取得

### ユーザー API
- `GET /api/users/<user_id>` - プロフィール取得
- `PUT /api/users/<user_id>` - プロフィール更新（認証必須）

### 通知 API
- `GET /api/notifications` - 通知一覧取得（認証必須）
- `PUT /api/notifications/<notification_id>/read` - 通知既読（認証必須）

詳細なAPI仕様については、`/docs/API仕様書.md` を参照してください。

## 🔧 開発時の注意事項

### 現在の実装状態

✅ **実装済み**
- Flaskアプリケーションの基盤
- API エンドポイントの構造
- JWT認証の仕組み
- モックデータでのレスポンス

⚠️ **未実装（DB担当メンバーが担当）**
- データベース接続処理
- SQLクエリの実装
- 実際のデータの永続化

### モックデータについて

現在、すべてのエンドポイントはモックデータを返します。DB担当メンバーがデータベース処理を実装するまでは、APIの動作確認のみ可能です。

### データベース処理の追加方法（DB担当メンバー向け）

各エンドポイントには `# TODO: DB担当メンバーが〜を実装` というコメントがあります。このコメントの下に、データベース処理を追加してください。

例：
```python
# routes/posts.py
@posts_bp.route('', methods=['GET'])
def get_posts():
    # TODO: DB担当メンバーが投稿取得処理を実装
    # ここにデータベースクエリを追加
    posts = db.query("SELECT * FROM posts")
    
    # モックデータ → 実際のデータに置き換え
    return jsonify({'success': True, 'data': {'posts': posts}})
```

## 🧪 テスト

```bash
# テストの実行（test_app.pyは旧版のため更新予定）
python -m pytest test_app.py
```

## 📦 依存パッケージ

- **Flask 3.0.0**: Webフレームワーク
- **Flask-CORS 4.0.0**: CORS対応
- **PyJWT 2.8.0**: JWT認証
- **google-auth 2.25.2**: Google認証
- **bcrypt 4.1.2**: パスワードハッシュ化
- **python-dotenv 1.0.0**: 環境変数管理
- **requests 2.31.0**: HTTPリクエスト

## 🔐 セキュリティ

### 本番環境での設定

1. **環境変数の変更**
   - `SECRET_KEY`: 強力なランダム文字列に変更
   - `JWT_SECRET`: 強力なランダム文字列に変更
   - `DEBUG=False` に設定

2. **HTTPS の使用**
   - 本番環境では必ずHTTPS通信を使用
   - SSL証明書の設定（Let's Encrypt推奨）

3. **Gunicorn + Nginx の使用**
   - Flask開発サーバーではなく、Gunicornを使用
   - Nginxをリバースプロキシとして設定

## 🚢 本番デプロイ

### Linuxサーバーでの起動手順

1. **必要なパッケージのインストール**
```bash
sudo apt update
sudo apt install python3 python3-pip python3-venv nginx postgresql
```

2. **プロジェクトのデプロイ**
```bash
cd /var/www/spotlight/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install gunicorn
```

3. **Gunicornでの起動**
```bash
gunicorn --bind 0.0.0.0:5000 --workers 4 app:app
```

4. **systemdサービスとして登録**
```bash
# /etc/systemd/system/spotlight.service を作成
sudo systemctl enable spotlight
sudo systemctl start spotlight
```

詳細なデプロイ手順は、別途デプロイドキュメントを参照してください。

## 🤝 チーム開発

### 担当分担

- **バックエンド担当**: APIロジック、認証、エンドポイント実装
- **DB担当**: データベース設計、SQL実装、データ永続化
- **フロントエンド担当**: Flutter アプリ、API連携

### ブランチ戦略

```
main           # 本番環境
├─ develop     # 開発環境
   ├─ feature/auth      # 認証機能
   ├─ feature/posts     # 投稿機能
   └─ feature/database  # DB実装
```

## 🐛 トラブルシューティング

### よくある問題

**Q: `ModuleNotFoundError: No module named 'flask'`**
A: 仮想環境がアクティベートされているか確認し、`pip install -r requirements.txt` を実行してください。

**Q: `pg_config executable not found`**
A: PostgreSQLがインストールされていません。DB担当メンバーがセットアップするまで、psycopg2-binaryは不要です。

**Q: `Address already in use`**
A: ポート5000が既に使用されています。`.env` ファイルで `PORT` を変更してください。

## 📞 サポート

質問や問題がある場合は、チームチャットまたはIssueで報告してください。

---

**最終更新**: 2024年1月
**バージョン**: 1.0.0
