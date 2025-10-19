# 🏗️ SpotLight バックエンド アーキテクチャ

このドキュメントでは、SpotLightバックエンドの構造と設計思想について説明します。

## 📁 ディレクトリ構造

```
backend/
│
├── app.py                      # メインアプリケーション
│   ├── Flaskアプリケーションのファクトリー
│   ├── Blueprintの登録
│   ├── エラーハンドラー
│   └── サーバー起動処理
│
├── config/                     # 設定管理
│   ├── __init__.py
│   └── settings.py             # 環境変数、設定クラス
│
├── routes/                     # APIエンドポイント
│   ├── __init__.py
│   ├── auth.py                 # 認証関連（登録、ログイン、Google認証）
│   ├── posts.py                # 投稿関連（CRUD、スポットライト）
│   ├── comments.py             # コメント関連（取得、作成）
│   ├── search.py               # 検索関連（検索実行、候補取得）
│   ├── users.py                # ユーザー関連（プロフィール）
│   └── notifications.py        # 通知関連（一覧、既読）
│
├── models/                     # データモデル（DB担当が実装）
│   └── __init__.py
│
├── utils/                      # ユーティリティ
│   ├── __init__.py
│   └── auth.py                 # JWT認証、デコレーター
│
├── venv/                       # 仮想環境（Gitで管理しない）
│
├── requirements.txt            # 依存パッケージ
├── env.example                 # 環境変数サンプル
├── .env                        # 環境変数（Gitで管理しない）
├── .gitignore                  # Git除外設定
├── README.md                   # プロジェクト説明
├── SETUP_GUIDE.md             # セットアップガイド
└── ARCHITECTURE.md            # このファイル
```

## 🎯 設計思想

### 1. モジュール化
- 機能ごとにファイルを分割
- 再利用可能なコンポーネント
- 保守性の向上

### 2. 責務の分離
- **routes/**: HTTPリクエスト/レスポンス処理
- **models/**: データ構造とDB操作（DB担当）
- **utils/**: 共通機能（認証、バリデーションなど）
- **config/**: 設定管理

### 3. Blueprint パターン
Flaskの Blueprint を使用して、APIエンドポイントを機能ごとに分割：

```python
# routes/auth.py
auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')

@auth_bp.route('/register', methods=['POST'])
def register():
    # 登録処理
    pass
```

### 4. デコレーターパターン
認証が必要なエンドポイントには `@jwt_required` デコレーターを使用：

```python
@posts_bp.route('', methods=['POST'])
@jwt_required
def create_post():
    user = request.user  # デコレーターが設定
    # 投稿作成処理
    pass
```

## 🔄 リクエストフロー

```
クライアント
    ↓
    ↓ HTTPリクエスト
    ↓
[Flask CORS ミドルウェア]
    ↓
[JWT認証デコレーター] ← 認証が必要な場合
    ↓
[Blueprint ルート関数]
    ↓
[バリデーション]
    ↓
[データベース処理] ← DB担当メンバーが実装
    ↓
[レスポンス生成]
    ↓
    ↓ HTTPレスポンス
    ↓
クライアント
```

## 📡 APIレスポンス形式

### 成功レスポンス
```json
{
  "success": true,
  "data": {
    // 実際のデータ
  }
}
```

### エラーレスポンス
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "エラーメッセージ"
  }
}
```

## 🔐 認証フロー

### JWT認証

```
1. ユーザー登録/ログイン
   ↓
2. サーバーがJWTトークン発行
   ↓
3. クライアントがトークンを保存
   ↓
4. 以降のリクエストにトークンを含める
   Header: Authorization: Bearer <token>
   ↓
5. サーバーがトークンを検証
   ↓
6. 認証成功 → リクエスト処理
   認証失敗 → 401エラー
```

### Google認証フロー

```
1. クライアントがGoogle認証を実行
   ↓
2. Google ID トークンを取得
   ↓
3. サーバーにID トークンを送信
   ↓
4. サーバーがトークンを検証
   ↓
5. ユーザー情報を取得/作成
   ↓
6. JWTトークンを発行
```

## 🗄️ データベース連携（DB担当メンバー向け）

### 実装場所

各ルートファイルに `# TODO: DB担当メンバーが〜を実装` というコメントがあります。

例：`routes/posts.py`
```python
@posts_bp.route('', methods=['GET'])
def get_posts():
    page = request.args.get('page', 1, type=int)
    limit = request.args.get('limit', 20, type=int)
    
    # TODO: DB担当メンバーが投稿取得処理を実装
    # ここにデータベースクエリを追加
    # 例:
    # from models import Post
    # posts = Post.query.paginate(page=page, per_page=limit)
    
    # 現在はモックデータを返す
    mock_posts = [...]
    return jsonify({'success': True, 'data': {'posts': mock_posts}})
```

### 推奨する実装パターン

1. **models/ にモデル定義を作成**
```python
# models/post.py
class Post:
    def __init__(self, ...):
        pass
    
    @staticmethod
    def get_all(page, limit):
        # データベースクエリ
        pass
```

2. **routes/ でモデルを使用**
```python
# routes/posts.py
from models.post import Post

@posts_bp.route('', methods=['GET'])
def get_posts():
    posts = Post.get_all(page, limit)
    return jsonify({'success': True, 'data': {'posts': posts}})
```

## 🔧 環境設定

### 開発環境
- `DEBUG=True`
- モックデータを使用
- CORS制限なし

### 本番環境
- `DEBUG=False`
- 実際のデータベース接続
- CORS制限あり（指定ドメインのみ）
- HTTPS必須
- Gunicorn + Nginx

## 📊 パフォーマンス考慮事項

### 現在の実装
- シンプルなFlask開発サーバー
- モックデータ（高速）

### 本番環境での最適化
1. **Gunicorn**: 複数ワーカープロセス
2. **データベース接続プール**: 接続の再利用
3. **キャッシュ**: Redis等を使用
4. **CDN**: 静的ファイルの配信
5. **ロードバランサー**: 負荷分散

## 🔒 セキュリティ対策

### 実装済み
- ✅ JWT認証
- ✅ CORS設定
- ✅ 環境変数での機密情報管理
- ✅ パスワードハッシュ化（bcrypt）

### 本番環境で必要
- 🔲 HTTPS強制
- 🔲 レート制限
- 🔲 SQLインジェクション対策（ORM使用）
- 🔲 XSS対策
- 🔲 CSRF対策

## 🧪 テスト戦略

### 単体テスト
```bash
# 各関数のテスト
pytest tests/test_auth.py
```

### 統合テスト
```bash
# APIエンドポイントのテスト
pytest tests/test_api.py
```

### E2Eテスト
```bash
# フロントエンドとの連携テスト
```

## 📈 今後の拡張

### Phase 2
- ファイルアップロード機能
- 画像・動画処理
- リアルタイム通知（WebSocket）

### Phase 3
- マイクロサービス化
- Docker化
- Kubernetes デプロイ

## 🤝 チーム開発フロー

```
1. Issue/タスクの作成
   ↓
2. ブランチの作成（feature/xxx）
   ↓
3. 実装・コミット
   ↓
4. プルリクエスト
   ↓
5. コードレビュー
   ↓
6. マージ（develop ブランチ）
   ↓
7. デプロイ（本番環境）
```

## 📚 参考資料

- [Flask公式ドキュメント](https://flask.palletsprojects.com/)
- [JWT.io](https://jwt.io/)
- [Python PEP 8](https://pep8.org/)
- [RESTful API設計ガイド](https://restfulapi.net/)

---

**作成日**: 2024年1月  
**バージョン**: 1.0.0  
**最終更新**: 2024年1月

