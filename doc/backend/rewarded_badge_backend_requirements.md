# リワード広告バッジ機能 バックエンド/DB実装ガイド

## 目的
- ユーザーごとにリワード広告視聴回数を保持
- 視聴回数に応じて広告バッジを解放
- 現在のクライアント実装は **iOSのみ**
- フロントエンドAPI:
  - `POST /api/users/getrewardadcount`
  - `POST /api/users/incrementrewardadcount`

## バッジ解放条件
- 1, 3, 5, 10, 25, 50, 100 回

## DB変更

### 1) users テーブルにカラム追加（最小構成）
```sql
ALTER TABLE user
ADD COLUMN reward_ad_count INT NOT NULL DEFAULT 0,
ADD COLUMN reward_ad_updated_at TIMESTAMP NULL;
```

### 2) 監査ログ（推奨）
```sql
CREATE TABLE reward_ad_view_logs (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  ad_unit_id VARCHAR(128) NOT NULL,
  reward_item VARCHAR(64) NOT NULL DEFAULT 'badge_num',
  reward_amount INT NOT NULL DEFAULT 1,
  idempotency_key VARCHAR(128) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_reward_ad_view_logs_user_created (user_id, created_at),
  UNIQUE KEY uq_reward_ad_idempotency (idempotency_key)
);
```

## API仕様

### `POST /api/users/getrewardadcount`
- 認証: JWT必須
- レスポンス例:
```json
{
  "status": "success",
  "count": 12
}
```

### `POST /api/users/incrementrewardadcount`
- 認証: JWT必須
- リクエスト例:
```json
{
  "increment": 1
}
```
- レスポンス例:
```json
{
  "status": "success",
  "count": 13
}
```

## 不正対策（重要）
- **クライアント単独で加算しない**
- 理想は **Server-Side Verification (SSV)** を使う
  - AdMobのリワードコールバックをサーバーで検証して加算
  - `idempotency_key` で重複加算を防止
- 最低限:
  - 連続加算レート制限
  - 1リクエスト1加算固定
  - 監査ログ記録

## ロジック
- バッジはDBに持たず、閾値ベースで動的判定でも可
- 将来の運用を考えるなら `badge_master` / `user_badges` テーブル化を推奨

## フロント連携メモ
- 現在フロントは以下を呼び出す:
  - `getrewardadcount` で初期値取得
  - リワード視聴完了時に `incrementrewardadcount`
- フロントは `count` または `data.count` のどちらでも読める実装済み

