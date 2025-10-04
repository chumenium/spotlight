# SpotLight API仕様書

このドキュメントでは、SpotLightアプリのAPI仕様について説明します。

## API概要

### ベースURL
```
https://api.spotlight.app/v1
```

### 認証方式
- **Bearer Token**: JWT形式のアクセストークン
- **ヘッダー**: `Authorization: Bearer {token}`

### レスポンス形式
```json
{
  "success": true,
  "data": {},
  "message": "Success",
  "timestamp": "2023-12-01T00:00:00Z"
}
```

### エラーレスポンス
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": {}
  },
  "timestamp": "2023-12-01T00:00:00Z"
}
```

## 認証API

### ユーザー登録
```http
POST /auth/register
```

**リクエスト:**
```json
{
  "nickname": "ユーザー名",
  "email": "user@example.com",
  "password": "password123"
}
```

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "user_123",
      "nickname": "ユーザー名",
      "email": "user@example.com",
      "profileImageUrl": null,
      "createdAt": "2023-12-01T00:00:00Z"
    },
    "token": "jwt_token_here"
  }
}
```

### ログイン
```http
POST /auth/login
```

**リクエスト:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "user_123",
      "nickname": "ユーザー名",
      "email": "user@example.com",
      "profileImageUrl": "https://example.com/avatar.jpg",
      "followersCount": 100,
      "followingCount": 50,
      "postsCount": 25
    },
    "token": "jwt_token_here"
  }
}
```

## 投稿API

### 投稿一覧取得
```http
GET /posts?page=1&limit=20&type=all
```

**クエリパラメータ:**
- `page`: ページ番号（デフォルト: 1）
- `limit`: 取得件数（デフォルト: 20）
- `type`: 投稿タイプ（all, video, image, text, audio）

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "posts": [
      {
        "id": "post_123",
        "userId": "user_123",
        "username": "ユーザー名",
        "userAvatar": "https://example.com/avatar.jpg",
        "title": "投稿タイトル",
        "content": "投稿内容",
        "type": "video",
        "mediaUrl": "https://example.com/video.mp4",
        "thumbnailUrl": "https://example.com/thumbnail.jpg",
        "likes": 150,
        "comments": 25,
        "shares": 10,
        "isSpotlighted": false,
        "createdAt": "2023-12-01T00:00:00Z"
      }
    ],
    "pagination": {
      "currentPage": 1,
      "totalPages": 10,
      "totalItems": 200,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

### 投稿作成
```http
POST /posts
```

**リクエスト:**
```json
{
  "title": "投稿タイトル",
  "content": "投稿内容",
  "type": "text",
  "mediaUrl": null,
  "thumbnailUrl": null
}
```

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "post": {
      "id": "post_456",
      "userId": "user_123",
      "username": "ユーザー名",
      "userAvatar": "https://example.com/avatar.jpg",
      "title": "投稿タイトル",
      "content": "投稿内容",
      "type": "text",
      "mediaUrl": null,
      "thumbnailUrl": null,
      "likes": 0,
      "comments": 0,
      "shares": 0,
      "isSpotlighted": false,
      "createdAt": "2023-12-01T00:00:00Z"
    }
  }
}
```

### 投稿詳細取得
```http
GET /posts/{postId}
```

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "post": {
      "id": "post_123",
      "userId": "user_123",
      "username": "ユーザー名",
      "userAvatar": "https://example.com/avatar.jpg",
      "title": "投稿タイトル",
      "content": "投稿内容",
      "type": "video",
      "mediaUrl": "https://example.com/video.mp4",
      "thumbnailUrl": "https://example.com/thumbnail.jpg",
      "likes": 150,
      "comments": 25,
      "shares": 10,
      "isSpotlighted": false,
      "createdAt": "2023-12-01T00:00:00Z"
    }
  }
}
```

## スポットライトAPI

### スポットライト実行
```http
POST /posts/{postId}/spotlight
```

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "post": {
      "id": "post_123",
      "isSpotlighted": true,
      "likes": 151
    }
  }
}
```

### スポットライト解除
```http
DELETE /posts/{postId}/spotlight
```

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "post": {
      "id": "post_123",
      "isSpotlighted": false,
      "likes": 150
    }
  }
}
```

## コメントAPI

### コメント一覧取得
```http
GET /posts/{postId}/comments?page=1&limit=20
```

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "comments": [
      {
        "id": "comment_123",
        "postId": "post_123",
        "userId": "user_456",
        "username": "コメント者",
        "userAvatar": "https://example.com/avatar2.jpg",
        "content": "コメント内容",
        "likes": 5,
        "createdAt": "2023-12-01T00:00:00Z"
      }
    ],
    "pagination": {
      "currentPage": 1,
      "totalPages": 5,
      "totalItems": 100,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

### コメント作成
```http
POST /posts/{postId}/comments
```

**リクエスト:**
```json
{
  "content": "コメント内容"
}
```

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "comment": {
      "id": "comment_456",
      "postId": "post_123",
      "userId": "user_123",
      "username": "ユーザー名",
      "userAvatar": "https://example.com/avatar.jpg",
      "content": "コメント内容",
      "likes": 0,
      "createdAt": "2023-12-01T00:00:00Z"
    }
  }
}
```

## 検索API

### 検索実行
```http
GET /search?q={query}&type=all&page=1&limit=20
```

**クエリパラメータ:**
- `q`: 検索クエリ
- `type`: 検索タイプ（all, posts, users）
- `page`: ページ番号
- `limit`: 取得件数

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "results": {
      "posts": [
        {
          "id": "post_123",
          "title": "検索結果の投稿",
          "content": "投稿内容",
          "type": "text",
          "username": "投稿者名",
          "createdAt": "2023-12-01T00:00:00Z"
        }
      ],
      "users": [
        {
          "id": "user_456",
          "nickname": "検索結果のユーザー",
          "profileImageUrl": "https://example.com/avatar.jpg",
          "followersCount": 50
        }
      ]
    },
    "pagination": {
      "currentPage": 1,
      "totalPages": 3,
      "totalItems": 50,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

### 検索候補取得
```http
GET /search/suggestions?q={query}
```

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "suggestions": [
      {
        "query": "Flutter開発",
        "type": "trending",
        "count": 150
      },
      {
        "query": "Flutter アニメーション",
        "type": "suggestion",
        "count": 25
      }
    ]
  }
}
```

## ユーザーAPI

### プロフィール取得
```http
GET /users/{userId}
```

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "user_123",
      "nickname": "ユーザー名",
      "email": "user@example.com",
      "profileImageUrl": "https://example.com/avatar.jpg",
      "bio": "自己紹介文",
      "followersCount": 100,
      "followingCount": 50,
      "postsCount": 25,
      "badges": [
        {
          "id": "badge_1",
          "name": "初投稿者",
          "icon": "https://example.com/badge1.png",
          "earnedAt": "2023-12-01T00:00:00Z"
        }
      ],
      "createdAt": "2023-12-01T00:00:00Z"
    }
  }
}
```

### プロフィール更新
```http
PUT /users/{userId}
```

**リクエスト:**
```json
{
  "nickname": "新しいユーザー名",
  "bio": "新しい自己紹介文"
}
```

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "user_123",
      "nickname": "新しいユーザー名",
      "bio": "新しい自己紹介文",
      "updatedAt": "2023-12-01T00:00:00Z"
    }
  }
}
```

## 通知API

### 通知一覧取得
```http
GET /notifications?page=1&limit=20
```

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "notifications": [
      {
        "id": "notification_123",
        "type": "like",
        "title": "いいね通知",
        "content": "あなたの投稿にいいねがつきました",
        "postId": "post_123",
        "userId": "user_456",
        "username": "いいねしたユーザー",
        "isRead": false,
        "createdAt": "2023-12-01T00:00:00Z"
      }
    ],
    "pagination": {
      "currentPage": 1,
      "totalPages": 5,
      "totalItems": 100,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

### 通知既読
```http
PUT /notifications/{notificationId}/read
```

**レスポンス:**
```json
{
  "success": true,
  "data": {
    "notification": {
      "id": "notification_123",
      "isRead": true,
      "readAt": "2023-12-01T00:00:00Z"
    }
  }
}
```

## エラーコード

### HTTPステータスコード
- **200**: 成功
- **201**: 作成成功
- **400**: リクエストエラー
- **401**: 認証エラー
- **403**: 権限エラー
- **404**: リソースが見つからない
- **500**: サーバーエラー

### エラーコード一覧
- **VALIDATION_ERROR**: 入力データの検証エラー
- **AUTHENTICATION_ERROR**: 認証エラー
- **AUTHORIZATION_ERROR**: 権限エラー
- **RESOURCE_NOT_FOUND**: リソースが見つからない
- **RATE_LIMIT_EXCEEDED**: レート制限超過
- **SERVER_ERROR**: サーバー内部エラー

## レート制限

### 制限値
- **認証API**: 10回/分
- **投稿API**: 30回/分
- **検索API**: 60回/分
- **その他**: 100回/分

### レスポンスヘッダー
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
```

## バージョニング

### APIバージョン
- **v1**: 現在のバージョン
- **v2**: 将来のバージョン（予定）

### 非推奨機能
- 旧バージョンのAPIは6ヶ月間サポート
- 非推奨警告をヘッダーで通知

## セキュリティ

### HTTPS必須
- すべてのAPI通信はHTTPS必須
- HTTP通信は自動的にHTTPSにリダイレクト

### 認証トークン
- JWT形式のアクセストークン
- 有効期限: 24時間
- リフレッシュトークン: 30日間

### 入力検証
- サーバーサイドでの厳密な入力検証
- SQLインジェクション対策
- XSS対策
