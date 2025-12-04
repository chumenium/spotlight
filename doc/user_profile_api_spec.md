# ユーザープロフィール画面用API仕様書

このドキュメントでは、`user_profile_screen.dart`で使用するAPIエンドポイントの詳細仕様を説明します。

## 目次
1. [プロフィール情報取得API](#1-プロフィール情報取得api)
2. [ユーザー投稿一覧取得API](#2-ユーザー投稿一覧取得api)

---

## 1. プロフィール情報取得API

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

**注意事項:**
- `firebase_uid`と`username`のどちらか一方を指定する
- `firebase_uid`が指定されている場合は、それを優先的に使用
- `firebase_uid`が空の場合は、`username`で検索を試みる

### レスポンス仕様

#### 成功時（ステータスコード: 200）

```json
{
  "status": "success",
  "data": {
    "firebase_uid": "user_firebase_uid_string",
    "username": "ユーザー名",
    "iconimgpath": "/icon/user_icon.jpg",
    "admin": false
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

#### エラー時（ステータスコード: 400, 404, 500など）

```json
{
  "status": "error",
  "message": "エラーメッセージ"
}
```

**エラーケース:**
- ユーザーが見つからない場合: 404
- パラメータが不正な場合: 400
- サーバーエラーの場合: 500

---

## 2. ユーザー投稿一覧取得API

### エンドポイント
```
POST /api/users/getusercontents
```

### 認証
- **必須**: Bearer Token（JWT）
- **ヘッダー**: `Authorization: Bearer {jwt_token}`

### リクエスト仕様

#### リクエストボディ（JSON）

```json
{
  "firebase_uid": "user_firebase_uid_string"
}
```

**注意事項:**
- `firebase_uid`は必須
- 指定されたユーザーの投稿一覧を取得

### レスポンス仕様

#### 成功時（ステータスコード: 200）

```json
{
  "status": "success",
  "data": [
    {
      "contentID": 123,
      "title": "投稿タイトル",
      "contentpath": "/content/movie/video.mp4",
      "thumbnailpath": "https://d30se1secd7t6t.cloudfront.net/thumbnail/thumb.jpg",
      "username": "ユーザー名",
      "iconimgpath": "/icon/user_icon.jpg",
      "spotlightnum": 10,
      "playnum": 50,
      "posttimestamp": "2025-12-02 12:34:56",
      "spotlightflag": true,
      "textflag": false,
      "commentnum": 5,
      "link": "/data/user/0/.../video.mp4"
    }
  ]
}
```

#### レスポンスフィールド詳細（各投稿オブジェクト）

| フィールド名 | 型 | 必須 | 説明 |
|------------|-----|------|------|
| `contentID` | Integer | 必須 | 投稿の一意なID |
| `title` | String | 必須 | 投稿のタイトル |
| `contentpath` | String | 任意 | メディアコンテンツのパス |
| `thumbnailpath` | String | 任意 | サムネイル画像のパス（完全URLまたは相対パス） |
| `username` | String | 必須 | 投稿者のユーザー名 |
| `iconimgpath` | String | 任意 | 投稿者のアイコンパス |
| `spotlightnum` | Integer | 必須 | スポットライト数（いいね数） |
| `playnum` | Integer | 必須 | 再生回数 |
| `posttimestamp` | String | 必須 | 投稿日時（フォーマット: "YYYY-MM-DD HH:MM:SS"） |
| `spotlightflag` | Boolean | 必須 | スポットライトされているか |
| `textflag` | Boolean | 必須 | テキスト投稿かどうか |
| `commentnum` | Integer | 必須 | コメント数 |
| `link` | String | 任意 | メディアファイルのリンク |

**重要: 投稿オブジェクトに`firebase_uid`または`user_id`を含めることを推奨**

現在の実装では、投稿データに`user_id`や`firebase_uid`が含まれていないため、`Post.fromJson`で`userId`が空文字列になる問題が発生しています。

```json
{
  "contentID": 123,
  "user_id": "user_firebase_uid_string",  // ← これを追加することを推奨
  // または
  "firebase_uid": "user_firebase_uid_string",  // ← これでも可
  // ... その他のフィールド
}
```

#### エラー時（ステータスコード: 400, 404, 500など）

```json
{
  "status": "error",
  "message": "エラーメッセージ"
}
```

**エラーケース:**
- ユーザーが見つからない場合: 404
- `firebase_uid`が指定されていない場合: 400
- サーバーエラーの場合: 500

---

## 実装チェックリスト

### プロフィール情報取得API (`/api/users/getusername`)

- [ ] `firebase_uid`で検索できる
- [ ] `username`で検索できる
- [ ] レスポンスに`firebase_uid`を含める
- [ ] レスポンスに`username`を含める
- [ ] レスポンスに`iconimgpath`を含める
- [ ] レスポンスに`admin`（Boolean）を含める
- [ ] ユーザーが見つからない場合、適切なエラーレスポンスを返す

### ユーザー投稿一覧取得API (`/api/users/getusercontents`)

- [ ] `firebase_uid`で指定されたユーザーの投稿を取得できる
- [ ] 各投稿オブジェクトに`contentID`を含める
- [ ] 各投稿オブジェクトに`title`を含める
- [ ] 各投稿オブジェクトに`username`を含める
- [ ] 各投稿オブジェクトに`thumbnailpath`を含める（任意）
- [ ] 各投稿オブジェクトに`spotlightnum`を含める
- [ ] 各投稿オブジェクトに`firebase_uid`または`user_id`を含める（推奨）
- [ ] 投稿が見つからない場合、空配列を返す

---

## 補足情報

### 現在の問題点

1. **投稿データに`user_id`が含まれていない**
   - ホーム画面の投稿データに`user_id`や`firebase_uid`が含まれていない
   - そのため、`Post.fromJson`で`userId`が空文字列になる
   - 解決策: 投稿詳細API (`/api/content/detail`) のレスポンスに`firebase_uid`または`user_id`を含める

2. **ユーザー名からの検索**
   - 現在の実装では、`userId`が空の場合、`username`で検索を試みる
   - バックエンドAPIが`username`での検索をサポートしている必要がある

### 推奨される改善

1. **投稿データにユーザーIDを含める**
   - `/api/content/detail`のレスポンスに`firebase_uid`または`user_id`を含める
   - `/api/users/getusercontents`のレスポンスにも同様に含める

2. **一貫性のあるフィールド名**
   - `firebase_uid`と`user_id`の両方を使い分けている
   - 統一することを推奨（例: すべて`firebase_uid`を使用）

---

## 実装例（Python/Flask）

```python
# プロフィール情報取得API
@app.route('/api/users/getusername', methods=['POST'])
@jwt_required()
def get_username():
    data = request.get_json()
    firebase_uid = data.get('firebase_uid')
    username = data.get('username')
    
    # firebase_uid または username で検索
    if firebase_uid:
        user = User.query.filter_by(firebase_uid=firebase_uid).first()
    elif username:
        user = User.query.filter_by(username=username).first()
    else:
        return jsonify({
            'status': 'error',
            'message': 'firebase_uidまたはusernameが必要です'
        }), 400
    
    if not user:
        return jsonify({
            'status': 'error',
            'message': 'ユーザーが見つかりません'
        }), 404
    
    return jsonify({
        'status': 'success',
        'data': {
            'firebase_uid': user.firebase_uid,
            'username': user.username,
            'iconimgpath': user.iconimgpath or '',
            'admin': user.admin or False
        }
    }), 200

# ユーザー投稿一覧取得API
@app.route('/api/users/getusercontents', methods=['POST'])
@jwt_required()
def get_user_contents():
    data = request.get_json()
    firebase_uid = data.get('firebase_uid')
    
    if not firebase_uid:
        return jsonify({
            'status': 'error',
            'message': 'firebase_uidが必要です'
        }), 400
    
    user = User.query.filter_by(firebase_uid=firebase_uid).first()
    if not user:
        return jsonify({
            'status': 'error',
            'message': 'ユーザーが見つかりません'
        }), 404
    
    # ユーザーの投稿を取得
    posts = Post.query.filter_by(user_id=user.id).order_by(Post.created_at.desc()).all()
    
    posts_data = []
    for post in posts:
        posts_data.append({
            'contentID': post.id,
            'user_id': user.firebase_uid,  # ← 重要: user_idを含める
            'title': post.title,
            'contentpath': post.contentpath or '',
            'thumbnailpath': post.thumbnailpath or '',
            'username': user.username,
            'iconimgpath': user.iconimgpath or '',
            'spotlightnum': post.spotlightnum or 0,
            'playnum': post.playnum or 0,
            'posttimestamp': post.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'spotlightflag': post.spotlightflag or False,
            'textflag': post.textflag or False,
            'commentnum': post.commentnum or 0,
            'link': post.link or ''
        })
    
    return jsonify({
        'status': 'success',
        'data': posts_data
    }), 200
```

---

以上が、`user_profile_screen.dart`で使用するAPIの詳細仕様です。実装時に参考にしてください。

