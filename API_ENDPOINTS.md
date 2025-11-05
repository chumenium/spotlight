## API仕様まとめ（contents.py / users.py）

このドキュメントは `routes/contents.py` および `routes/users.py` のエンドポイント仕様を1つに集約したものです。

- 基本URL: アプリのベースURL + 各エンドポイント
- 全てのエンドポイントは JWT 認証が必要です（`Authorization: Bearer <token>` ヘッダ）。
- リクエスト/レスポンスは特記なき限り JSON です。

---

### コンテンツ系（/api/content）

1. POST `/api/content/add`
   - 説明: コンテンツ追加（動画/画像/音声/テキスト）
   - 認証: 必須
   - リクエスト(JSON):
     - `type`: "video" | "image" | "audio" | "text"
     - `title`: 文字列
     - `link`: 文字列（任意）
     - type ≠ "text" の場合:
       - `file`: base64文字列（コンテンツ本体）
       - `thumbnail`: base64文字列（サムネイル）
     - type = "text" の場合:
       - `text`: 本文
   - レスポンス例:
     ```json
     {
       "status": "success",
       "message": "コンテンツを追加しました。",
       "data": {
         "contentID": 123,
         "contentpath": "content/movie/uid_timestamp.mp4",
         "thumbnailpath": "content/thumbnail/uid_timestamp_thumb.jpg"
       }
     }
     ```

2. POST `/api/content/addcomment`
   - 説明: コメント追加（返信は `parentcommentID` を指定）
   - 認証: 必須
   - リクエスト(JSON):
     - `commenttext`: 文字列（必須）
     - `parentcommentID`: 数値（返信時のみ）
   - レスポンス:
     ```json
     { "status": "success", "message": "コメントを追加しました。" }
     ```

3. POST `/api/content/detail`
   - 説明: 再生用の次コンテンツを取得し、再生履歴を記録
   - 認証: 必須
   - リクエスト(JSON):
     - `contentID`: 数値（現在のコンテンツID）
   - レスポンス例:
     ```json
     {
       "status": "success",
       "data": {
         "title": "タイトル",
         "contentpath": "content/movie/xxx.mp4",  
         "spotlightnum": 10,
         "posttimestamp": "2025-01-01T12:34:56",
         "playnum": 123,
         "link": "https://...",
         "username": "userA",
         "iconimgpath": "icon/userA_icon.jpg",
         "spotlightflag": true,
         "textflag": false,
         "nextcontentid": 456
       }
     }
     ```

4. POST `/api/content/spotlight/on`
   - 説明: 指定コンテンツにスポットライトON
   - 認証: 必須
   - リクエスト(JSON):
     - `contentID`: 数値
   - レスポンス: `{ "status": "success", "message": "スポットライトをONにしました" }`

5. POST `/api/content/spotlight/off`
   - 説明: 指定コンテンツのスポットライトOFF
   - 認証: 必須
   - リクエスト(JSON):
     - `contentID`: 数値
   - レスポンス: `{ "status": "success", "message": "スポットライトをOFFにしました" }`

6. POST `/api/content/getcomments`
   - 説明: 指定コンテンツのコメント一覧（スレッド構造）
   - 認証: 必須
   - リクエスト(JSON):
     - `contentID`: 数値（必須）
   - レスポンス例:
     ```json
     {
       "status": "success",
       "data": [
         {
           "commentID": 1,
           "username": "userA",
           "iconimgpath": "icon/userA_icon.jpg",
           "commenttimestamp": "2025-01-01 12:00:00",
           "commenttext": "コメント",
           "parentcommentID": null,
           "replies": [ { /* 返信 */ } ]
         }
       ]
     }
     ```

7. POST `/api/content/createplaylist`
   - 説明: プレイリスト作成
   - 認証: 必須
   - リクエスト(JSON):
     - `title`: 文字列
   - レスポンス: `{ "status": "success", "message": "プレイリストを作成しました" }`

8. POST `/api/content/addcontentplaylist`
   - 説明: プレイリストにコンテンツを追加
   - 認証: 必須
   - リクエスト(JSON):
     - `playlistid`: 数値
     - `contentid`: 数値
   - レスポンス: `{ "status": "success", "message": "プレイリストにコンテンツを追加しました" }`

9. POST `/api/content/getplaylist`
   - 説明: プレイリスト一覧を取得（各プレイリストのサムネイル付）
   - 認証: 必須
   - リクエスト: なし
   - レスポンス例:
     ```json
     { "status": "success", "playlist": [ { /* プレイリスト */ } ] }
     ```

10. POST `/api/content/getplaylistdetail`
    - 説明: 指定プレイリストのコンテンツ一覧
    - 認証: 必須
    - リクエスト(JSON):
      - `playlistid`: 数値
    - レスポンス例:
      ```json
      {
        "status": "success",
        "data": [
          {
            "contentID": 1,
            "title": "タイトル",
            "spotlightnum": 3,
            "posttimestamp": "2025-01-01 12:00:00",
            "playnum": 100,
            "link": "https://...",
            "thumbnailpath": "content/thumbnail/xxx.jpg"
          }
        ]
      }
      ```

11. POST `/api/content/serch`
    - 説明: コンテンツ検索（スペルは `serch`）
    - 認証: 必須
    - リクエスト(JSON):
      - `word`: 文字列（検索ワード）
    - レスポンス例:
      ```json
      {
        "status": "success",
        "message": "N件のコンテンツが見つかりました。",
        "data": [
          {
            "contentID": 1,
            "title": "タイトル",
            "spotlightnum": 2,
            "posttimestamp": "2025-01-01 12:00:00",
            "playnum": 50,
            "link": "https://...",
            "thumbnailurl": "content/thumbnail/xxx.jpg"
          }
        ]
      }
      ```

---

### ユーザー系（/api/users）

1. POST `/api/users/getusername`
   - 説明: ユーザ名とアイコン画像パスを取得
   - 認証: 必須
   - リクエスト: なし
   - レスポンス:
     ```json
     {
       "status": "success",
       "data": { "username": "userA", "iconimgpath": "icon/userA_icon.jpg" }
     }
     ```

2. POST `/api/users/getsearchhistory`
   - 説明: 検索履歴の取得
   - 認証: 必須
   - リクエスト: なし
   - レスポンス:
     ```json
     { "status": "success", "data": ["キーワード1", "キーワード2"] }
     ```

3. POST `/api/users/notification/enable`
   - 説明: 通知設定ON
   - 認証: 必須
   - リクエスト: なし
   - レスポンス: `{ "status": "success", "message": "通知をONにしました" }`

4. POST `/api/users/notification/disable`
   - 説明: 通知設定OFF
   - 認証: 必須
   - リクエスト: なし
   - レスポンス: `{ "status": "success", "message": "通知をOFFにしました" }`

5. POST `/api/users/getusercontents`
   - 説明: 自ユーザーの投稿コンテンツ一覧
   - 認証: 必須
   - リクエスト: なし
   - レスポンス: `data` は配列（各要素に `contentID`, `title`, `spotlightnum`, `posttimestamp`, `playnum`, `link`, `thumbnailpath`）

6. POST `/api/users/getspotlightcontents`
   - 説明: 自ユーザーがスポットライトしたコンテンツ一覧
   - 認証: 必須
   - リクエスト: なし
   - レスポンス: `data` は配列（項目は上記と同様）

7. POST `/api/users/getplayhistory`
   - 説明: 自ユーザーの再生履歴一覧
   - 認証: 必須
   - リクエスト: なし
   - レスポンス: `data` は配列（項目は上記と同様）

8. POST `/api/users/profile`
   - 説明: プロフィール表示用のスポットライト数取得
   - 認証: 必須
   - リクエスト: なし
   - レスポンス: `{ "status": "success", "spotlightnum": 数値 }`

9. POST `/api/users/changeicon`
   - 説明: アイコン画像の変更
   - 認証: 必須
   - リクエスト: フォーム（`Content-Type: application/x-www-form-urlencoded` 相当）
     - `username`: 文字列
     - `iconimg`: 画像のData URL形式（例: `data:image/png;base64,....`）
       - 画像を送らない場合は `default_icon.jpg` が設定されます
   - レスポンス:
     ```json
     {
       "status": "success",
       "message": "アイコンを変更しました。",
       "iconimgpath": "icon/username_icon.png"
     }
     ```

---

### 共通事項

- 認証: すべてのエンドポイントで JWT が必要です。
  - ヘッダ例: `Authorization: Bearer <JWTトークン>`
- 日付時刻: `posttimestamp` や `commenttimestamp` は API 内でフォーマット済み。
- エラーレスポンス: 主に `{ "status": "error", "message": "..." }` 形式、HTTP 400 が多いです。


