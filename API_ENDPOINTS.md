## API仕様まとめ

このドキュメントは、SpotLightバックエンドAPIの全エンドポイント仕様をまとめたものです。

- **基本URL**: `http://54.150.123.156:5000` (開発環境)
- **認証**: 全てのエンドポイント（`/api/auth/*`を除く）でJWT認証が必要
- **認証ヘッダ**: `Authorization: Bearer <JWTトークン>`
- **リクエスト/レスポンス**: 特記なき限りJSON形式

---

## 認証系（/api/auth）

### 1. POST `/api/auth/firebase`
- **説明**: Firebase認証トークンからJWTトークンを取得
- **認証**: 不要
- **リクエスト(JSON)**:
  ```json
  {
    "firebase_token": "Firebase ID Token"
  }
  ```
- **レスポンス**:
  ```json
  {
    "status": "success",
    "token": "JWTトークン",
    "userID": "firebase_uid"
  }
  ```

### 2. POST `/api/auth/api/update_token`
- **説明**: FCMトークンを更新
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "token": "FCMトークン"
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "トークンを更新しました" }`

---

## コンテンツ系（/api/content）

### 1. POST `/api/content/add`
- **説明**: コンテンツ追加（動画/画像/音声/テキスト）
- **認証**: 必須
- **リクエスト(JSON)**:
  - `type`: `"video"` | `"image"` | `"audio"` | `"text"`
  - `title`: 文字列（必須）
  - `link`: 文字列（任意）
  - `type ≠ "text"` の場合:
    - `file`: base64文字列（コンテンツ本体、必須）
    - `thumbnail`: base64文字列（サムネイル、必須）
  - `type = "text"` の場合:
    - `text`: 本文（必須）
- **レスポンス**:
  ```json
  {
    "status": "success",
    "message": "コンテンツを追加しました。",
    "data": {
      "contentID": 123,
      "contentpath": "https://d30se1secd7t6t.cloudfront.net/movie/username_timestamp.mp4",
      "thumbnailpath": "https://d30se1secd7t6t.cloudfront.net/thumbnail/username_timestamp_thumb.jpg"
    }
  }
  ```
- **注意**: メディアファイル（動画/画像/音声）はS3にアップロードされ、CloudFront URLが返されます

### 2. POST `/api/content/detail`
- **説明**: コンテンツ詳細を取得（S3からランダム取得対応）
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "contentID": 123  // 任意（指定しない場合はS3からランダムに取得）
  }
  ```
  - `contentID`を指定しない場合（空オブジェクト`{}`）: S3バケット内のコンテンツ（movie, picture, audio）からランダムに1件を取得
  - `contentID`を指定した場合: 指定されたIDのコンテンツを取得（後方互換性）
- **レスポンス**:
  ```json
  {
    "status": "success",
    "data": {
      "title": "タイトル",
      "contentpath": "https://d30se1secd7t6t.cloudfront.net/movie/filename.mp4",
      "thumbnailpath": "https://d30se1secd7t6t.cloudfront.net/thumbnail/filename_thumb.jpg",
      "spotlightnum": 10,
      "posttimestamp": "2025-11-21T12:34:56",
      "playnum": 123,
      "link": "https://...",
      "username": "userA",
      "iconimgpath": "/icon/userA_icon.png",
      "spotlightflag": false,
      "textflag": false,
      "nextcontentid": 456
    }
  }
  ```
- **注意**: 
  - `contentpath`と`thumbnailpath`はCloudFront URL形式で返されます
  - `iconimgpath`はバックエンドサーバーの相対パス（`/icon/...`）です

### 3. POST `/api/content/addcomment`
- **説明**: コメント追加（返信は`parentcommentID`を指定）
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "contentID": 123,
    "commenttext": "コメント内容",
    "parentcommentID": 456  // 返信時のみ（任意）
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "コメントを追加しました。" }`

### 4. POST `/api/content/getcomments`
- **説明**: 指定コンテンツのコメント一覧（スレッド構造）
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "contentID": 123
  }
  ```
- **レスポンス**:
  ```json
  {
    "status": "success",
    "data": [
      {
        "commentID": 1,
        "username": "userA",
        "iconimgpath": "/icon/userA_icon.png",
        "commenttimestamp": "2025-11-21 12:00:00",
        "commenttext": "コメント",
        "parentcommentID": null,
        "replies": [
          {
            "commentID": 2,
            "username": "userB",
            "iconimgpath": "/icon/userB_icon.png",
            "commenttimestamp": "2025-11-21 12:05:00",
            "commenttext": "返信",
            "parentcommentID": 1,
            "replies": []
          }
        ]
      }
    ]
  }
  ```

### 5. POST `/api/content/spotlight/on`
- **説明**: 指定コンテンツにスポットライトON
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "contentID": 123
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "スポットライトをONにしました" }`

### 6. POST `/api/content/spotlight/off`
- **説明**: 指定コンテンツのスポットライトOFF
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "contentID": 123
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "スポットライトをOFFにしました" }`

### 7. POST `/api/content/playnum`
- **説明**: 再生回数を更新
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "contentID": 123
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "再生回数を更新しました" }`

### 8. POST `/api/content/createplaylist`
- **説明**: プレイリスト作成
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "title": "プレイリスト名"
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "プレイリストを作成しました" }`

### 9. POST `/api/content/addcontentplaylist`
- **説明**: プレイリストにコンテンツを追加
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "playlistid": 1,
    "contentid": 123
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "プレイリストにコンテンツを追加しました" }`

### 10. POST `/api/content/getplaylist`
- **説明**: プレイリスト一覧を取得（各プレイリストのサムネイル付）
- **認証**: 必須
- **リクエスト**: なし（空オブジェクト`{}`）
- **レスポンス**:
  ```json
  {
    "status": "success",
    "playlist": [
      {
        "playlistID": 1,
        "title": "プレイリスト名",
        "thumbnailpath": "https://d30se1secd7t6t.cloudfront.net/thumbnail/xxx.jpg"
      }
    ]
  }
  ```

### 11. POST `/api/content/getplaylistdetail`
- **説明**: 指定プレイリストのコンテンツ一覧
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "playlistid": 1
  }
  ```
- **レスポンス**:
  ```json
  {
    "status": "success",
    "data": [
      {
        "contentID": 1,
        "title": "タイトル",
        "spotlightnum": 3,
        "posttimestamp": "2025-11-21 12:00:00",
        "playnum": 100,
        "link": "https://...",
        "thumbnailpath": "https://d30se1secd7t6t.cloudfront.net/thumbnail/xxx.jpg"
      }
    ]
  }
  ```

### 12. POST `/api/content/serch`
- **説明**: コンテンツ検索（スペルは`serch`）
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "word": "検索ワード"
  }
  ```
- **レスポンス**:
  ```json
  {
    "status": "success",
    "message": "N件のコンテンツが見つかりました。",
    "data": [
      {
        "contentID": 1,
        "title": "タイトル",
        "spotlightnum": 2,
        "posttimestamp": "2025-11-21 12:00:00",
        "playnum": 50,
        "link": "https://...",
        "thumbnailurl": "https://d30se1secd7t6t.cloudfront.net/thumbnail/xxx.jpg"
      }
    ]
  }
  ```

---

## ユーザー系（/api/users）

### 1. POST `/api/users/getusername`
- **説明**: ユーザ名とアイコン画像パスを取得
- **認証**: 必須
- **リクエスト**: なし（空オブジェクト`{}`）
- **レスポンス**:
  ```json
  {
    "status": "success",
    "data": {
      "username": "userA",
      "iconimgpath": "/icon/userA_icon.png"
    }
  }
  ```

### 2. POST `/api/users/getsearchhistory`
- **説明**: 検索履歴の取得
- **認証**: 必須
- **リクエスト**: なし（空オブジェクト`{}`）
- **レスポンス**:
  ```json
  {
    "status": "success",
    "data": [
      {
        "serchID": 1,
        "serchword": "キーワード1"
      },
      {
        "serchID": 2,
        "serchword": "キーワード2"
      }
    ]
  }
  ```

### 3. POST `/api/users/notification/enable`
- **説明**: 通知設定ON
- **認証**: 必須
- **リクエスト**: なし（空オブジェクト`{}`）
- **レスポンス**: `{ "status": "success", "message": "通知をONにしました" }`

### 4. POST `/api/users/notification/disable`
- **説明**: 通知設定OFF
- **認証**: 必須
- **リクエスト**: なし（空オブジェクト`{}`）
- **レスポンス**: `{ "status": "success", "message": "通知をOFFにしました" }`

### 5. POST `/api/users/getusercontents`
- **説明**: 自ユーザーの投稿コンテンツ一覧
- **認証**: 必須
- **リクエスト**: なし（空オブジェクト`{}`）
- **レスポンス**:
  ```json
  {
    "status": "success",
    "data": [
      {
        "contentID": 1,
        "title": "タイトル",
        "spotlightnum": 3,
        "posttimestamp": "2025-11-21 12:00:00",
        "playnum": 100,
        "link": "https://...",
        "thumbnailpath": "https://d30se1secd7t6t.cloudfront.net/thumbnail/xxx.jpg"
      }
    ]
  }
  ```

### 6. POST `/api/users/getspotlightcontents`
- **説明**: 自ユーザーがスポットライトしたコンテンツ一覧
- **認証**: 必須
- **リクエスト**: なし（空オブジェクト`{}`）
- **レスポンス**: `data`は配列（項目は上記と同様）

### 7. POST `/api/users/getplayhistory`
- **説明**: 自ユーザーの再生履歴一覧
- **認証**: 必須
- **リクエスト**: なし（空オブジェクト`{}`）
- **レスポンス**: `data`は配列（項目は上記と同様）

### 8. POST `/api/users/profile`
- **説明**: プロフィール表示用のスポットライト数取得
- **認証**: 必須
- **リクエスト**: なし（空オブジェクト`{}`）
- **レスポンス**: `{ "status": "success", "spotlightnum": 123 }`

### 9. POST `/api/users/changeicon`
- **説明**: アイコン画像の変更
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "username": "userA",
    "iconimg": "data:image/png;base64,..."  // 画像のData URL形式（任意）
  }
  ```
  - 画像を送らない場合は`default_icon.jpg`が設定されます
- **レスポンス**:
  ```json
  {
    "status": "success",
    "message": "アイコンを変更しました。",
    "iconimgpath": "/icon/userA_timestamp_icon.png"
  }
  ```
- **注意**: アイコンはバックエンドサーバーに保存され、S3にはアップロードされません

### 10. POST `/api/users/notification`
- **説明**: 通知一覧を取得
- **認証**: 必須
- **リクエスト**: なし（空オブジェクト`{}`）
- **レスポンス**:
  ```json
  {
    "status": "success",
    "data": [
      {
        "notificationID": 1,
        "notificationtitle": "タイトル",
        "notificationtext": "本文",
        "notificationtimestamp": "2025-11-21 12:00:00",
        "isread": false
      }
    ]
  }
  ```

### 11. POST `/api/users/unloadednum`
- **説明**: 未読通知数を取得
- **認証**: 必須
- **リクエスト**: なし（空オブジェクト`{}`）
- **レスポンス**: `{ "status": "success", "unloadednum": 5 }`

---

## 削除系（/api/delete）

### 1. POST `/api/delete/playhistory`
- **説明**: 再生履歴を削除
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "playID": 123
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "再生履歴を削除しました" }`

### 2. POST `/api/delete/playlistdetail`
- **説明**: プレイリストからコンテンツを削除
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "playlistid": 1,
    "contentid": 123
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "プレイリストからコンテンツを削除しました" }`

### 3. POST `/api/delete/playlist`
- **説明**: プレイリストを削除
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "playlistid": 1
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "プレイリストを削除しました" }`

### 4. POST `/api/delete/searchhistory`
- **説明**: 検索履歴を削除
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "serchID": 123
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "検索履歴を削除しました" }`

### 5. POST `/api/delete/notification`
- **説明**: 通知を削除
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "notificationID": 123
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "通知を削除しました" }`

### 6. POST `/api/delete/comment`
- **説明**: コメントを削除
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "contentID": 123,
    "commentID": 456
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "コメントを削除しました" }`

### 7. POST `/api/delete/content`
- **説明**: コンテンツを削除
- **認証**: 必須
- **リクエスト(JSON)**:
  ```json
  {
    "contentID": 123
  }
  ```
- **レスポンス**: `{ "status": "success", "message": "コンテンツを削除しました" }`

---

## 共通事項

### 認証
- すべてのエンドポイント（`/api/auth/*`を除く）でJWT認証が必要です
- ヘッダ例: `Authorization: Bearer <JWTトークン>`
- 認証エラーの場合: HTTP 401 Unauthorized

### URL形式
- **メディアファイル（コンテンツ・サムネイル）**: CloudFront URL
  - 形式: `https://d30se1secd7t6t.cloudfront.net/{folder}/{filename}`
  - フォルダ: `movie`, `picture`, `audio`, `thumbnail`
- **アイコン**: バックエンドサーバー
  - 形式: `http://54.150.123.156:5000/icon/{filename}`

### エラーレスポンス
- 主に `{ "status": "error", "message": "エラーメッセージ" }` 形式
- HTTPステータスコード: 400 (Bad Request), 404 (Not Found), 500 (Internal Server Error)

### 日付時刻フォーマット
- `posttimestamp`, `commenttimestamp`, `notificationtimestamp`: ISO 8601形式または `YYYY-MM-DD HH:MM:SS` 形式

### S3 & CloudFront
- メディアファイル（動画、画像、音声、サムネイル）はS3にアップロードされ、CloudFront経由で配信されます
- アイコンはバックエンドサーバーに保存され、直接配信されます
- `/api/content/detail`で`contentID`を指定しない場合、S3バケット内のコンテンツからランダムに1件を取得します

---

## 更新履歴

- **2025-11-21**: 
  - `/api/content/detail`にS3ランダム取得機能を追加
  - CloudFront URL対応を反映
  - アイコンの配信方法を明確化
