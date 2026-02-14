# データベースマイグレーション: bioカラム追加

## 問題の確認

PostgreSQLで`users`テーブルが見つからない場合、以下の可能性があります：

1. テーブル名が大文字小文字で異なる（例: `Users`, `USERS`）
2. スキーマが異なる（例: `public.users`）
3. テーブル名が実際には異なる（例: `user`, `user_accounts`）

## 解決方法

### 1. 既存のテーブル名を確認

```sql
-- すべてのテーブル一覧を表示
\dt

-- または
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public';
```

### 2. テーブル名が確認できたら、適切なSQLを実行

#### パターン1: テーブル名が`users`（小文字）の場合

```sql
ALTER TABLE users ADD COLUMN bio VARCHAR(200) DEFAULT NULL;
```

#### パターン2: テーブル名が`Users`（大文字）の場合

```sql
ALTER TABLE "Users" ADD COLUMN bio VARCHAR(200) DEFAULT NULL;
```

#### パターン3: テーブル名が`user`（単数形）の場合

```sql
ALTER TABLE "user" ADD COLUMN bio VARCHAR(200) DEFAULT NULL;
```

#### パターン4: スキーマが異なる場合

```sql
ALTER TABLE public.users ADD COLUMN bio VARCHAR(200) DEFAULT NULL;
-- または
ALTER TABLE your_schema.users ADD COLUMN bio VARCHAR(200) DEFAULT NULL;
```

### 3. 既にbioカラムが存在するか確認

```sql
-- usersテーブルのカラム一覧を表示
\d users

-- または
SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'bio';
```

### 4. カラムが既に存在する場合

既に`bio`カラムが存在する場合は、以下のエラーが出ます：

```
ERROR: column "bio" of relation "users" already exists
```

この場合は、何もする必要はありません。

### 5. カラムの型を変更する場合（既存のbioカラムがある場合）

```sql
-- 既存のbioカラムの型を変更
ALTER TABLE users ALTER COLUMN bio TYPE VARCHAR(200);

-- NULL許可を確認
ALTER TABLE users ALTER COLUMN bio DROP NOT NULL;
```

## 推奨される手順

1. まず、既存のテーブル構造を確認
2. テーブル名を正確に特定
3. 適切なSQLを実行
4. カラムが正しく追加されたことを確認

## 確認用SQL

```sql
-- テーブル一覧
\dt

-- usersテーブルの構造確認
\d users

-- bioカラムの確認
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'bio';
```

## 注意事項

- PostgreSQLでは、引用符で囲まないテーブル名は自動的に小文字に変換されます
- 引用符で囲むと大文字小文字が保持されます
- スキーマを明示的に指定する場合は、`schema_name.table_name`の形式を使用します

