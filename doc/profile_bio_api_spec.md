# プロフィール自己紹介文API仕様書

このドキュメントでは、プロフィール設定画面で使用する自己紹介文（bio）関連のAPIエンドポイントの詳細仕様を説明します。

## 目次
1. [自己紹介文取得API](#1-自己紹介文取得api)
2. [自己紹介文更新API](#2-自己紹介文更新api)
3. [データベーススキーマ](#3-データベーススキーマ)

---

## 1. 自己紹介文取得API

### エンドポイント
```
POST /api/users/getusername
```

### 認証
- **必須**: Bearer Token（JWT）
- **ヘッダー**: `Authorization: Bearer {jwt_token}`

### リクエスト仕様

#### リクエストボディ（JSON）

**パターン1: firebase_uidで検索**
```json
{
  "firebase_uid": "user_firebase_uid_string"
}
```

**パターン2: usernameで検索**
```json
{
  "username": "ユーザー名"
}
```

### レスポンス仕様

#### 成功時（ステータスコード: 200）

```json
{
  "status": "success",
  "data": {
    "firebase_uid": "user_firebase_uid_string",
    "username": "ユーザー名",
    "iconimgpath": "/icon/user_icon.jpg",
    "admin": false,
    "bio": "音楽が好きです"
  }
}
```

#### レスポンスフィールド詳細

| フィールド名 | 型 | 必須 | 説明 |
|------------|-----|------|------|
| `firebase_uid` | String | 必須 | Firebase UID（ユーザーの一意な識別子） |
| `username` | String | 必須 | ユーザー名（表示名） |
| `iconimgpath` | String | 任意 | アイコン画像のパス（相対パスまたは完全URL） |
| `admin` | Boolean | 必須 | 管理者フラグ（true: 管理者, false: 一般ユーザー） |
| `bio` | String | 任意 | 自己紹介文（最大200文字、null可） |

---

## 2. 自己紹介文更新API

### エンドポイント
```
POST /api/users/updatebio
```

### 認証
- **必須**: Bearer Token（JWT）
- **ヘッダー**: `Authorization: Bearer {jwt_token}`

### リクエスト仕様

#### リクエストボディ（JSON）

```json
{
  "bio": "音楽が好きです"
}
```

#### リクエストフィールド詳細

| フィールド名 | 型 | 必須 | 説明 |
|------------|-----|------|------|
| `bio` | String | 任意 | 自己紹介文（最大200文字、空文字列可、null可） |

**注意事項:**
- `bio`が空文字列またはnullの場合、自己紹介文を削除（クリア）します
- 最大200文字まで入力可能
- 個人を特定できる情報（性別、都道府県など）は含めないこと

### レスポンス仕様

#### 成功時（ステータスコード: 200）

```json
{
  "status": "success",
  "message": "自己紹介文を更新しました"
}
```

#### エラー時（ステータスコード: 400, 401, 500など）

```json
{
  "status": "error",
  "message": "エラーメッセージ"
}
```

#### エラーケース

| ステータスコード | エラーメッセージ | 説明 |
|----------------|----------------|------|
| 400 | "自己紹介文は200文字以内で入力してください" | 文字数制限超過 |
| 401 | "認証が必要です" | JWTトークンが無効または期限切れ |
| 500 | "サーバーエラーが発生しました" | サーバー側のエラー |

---

## 3. データベーススキーマ

### usersテーブル

既存の`users`テーブルに`bio`カラムを追加する必要があります。

#### 追加するカラム

```sql
ALTER TABLE users ADD COLUMN bio VARCHAR(200) DEFAULT NULL;
```

#### テーブル構造（追加後）

| カラム名 | 型 | NULL許可 | デフォルト値 | 説明 |
|---------|-----|---------|------------|------|
| `id` | INT | NO | AUTO_INCREMENT | プライマリキー |
| `firebase_uid` | VARCHAR(255) | NO | - | Firebase UID（一意制約） |
| `username` | VARCHAR(255) | NO | - | ユーザー名 |
| `iconimgpath` | VARCHAR(500) | YES | NULL | アイコン画像パス |
| `admin` | BOOLEAN | NO | FALSE | 管理者フラグ |
| `bio` | VARCHAR(200) | YES | NULL | 自己紹介文（最大200文字） |
| `created_at` | TIMESTAMP | NO | CURRENT_TIMESTAMP | 作成日時 |
| `updated_at` | TIMESTAMP | NO | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | 更新日時 |

#### インデックス

既存のインデックスに加えて、特に追加のインデックスは不要です。

#### 制約

- `bio`カラムは最大200文字まで
- `bio`はNULL許可（自己紹介文が未設定の場合）
- 個人を特定できる情報は含めないこと（アプリケーション側で制御）

---

## 実装例

### バックエンド実装（Python/Flaskの例）

```python
@app.route('/api/users/updatebio', methods=['POST'])
@require_auth
def update_bio():
    try:
        data = request.get_json()
        bio = data.get('bio', '').strip()
        
        # 文字数チェック
        if len(bio) > 200:
            return jsonify({
                'status': 'error',
                'message': '自己紹介文は200文字以内で入力してください'
            }), 400
        
        # ユーザーIDを取得（JWTから）
        user_id = get_user_id_from_jwt()
        
        # データベースを更新
        cursor = db.cursor()
        cursor.execute(
            'UPDATE users SET bio = %s WHERE firebase_uid = %s',
            (bio if bio else None, user_id)
        )
        db.commit()
        
        return jsonify({
            'status': 'success',
            'message': '自己紹介文を更新しました'
        }), 200
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': 'サーバーエラーが発生しました'
        }), 500
```

### 既存のgetusername APIの修正

既存の`/api/users/getusername`エンドポイントのレスポンスに`bio`フィールドを追加してください。

```python
# 既存のコードに追加
cursor.execute(
    'SELECT firebase_uid, username, iconimgpath, admin, bio FROM users WHERE firebase_uid = %s',
    (user_id,)
)
row = cursor.fetchone()

return jsonify({
    'status': 'success',
    'data': {
        'firebase_uid': row[0],
        'username': row[1],
        'iconimgpath': row[2],
        'admin': row[3],
        'bio': row[4]  # 追加
    }
}), 200
```

---

## 注意事項

1. **プライバシー保護**: 自己紹介文には個人を特定できる情報（性別、都道府県、年齢など）を含めないこと
2. **文字数制限**: 最大200文字まで（データベースのVARCHAR(200)と一致）
3. **NULL許可**: 自己紹介文が未設定の場合はNULLを返す
4. **XSS対策**: 自己紹介文を表示する際は、適切にエスケープ処理を行うこと

