# Git ブランチ分岐の解決方法

## 問題
ローカルブランチとリモートブランチが分岐している状態です。

## 解決方法の選択肢

### 1. マージ（推奨）- 両方の変更を保持
ローカルとリモートの両方の変更を統合します。

```bash
# マージ戦略を設定（一度だけ）
git config pull.rebase false

# または、このコマンドのみで実行
git pull origin main --no-rebase
```

### 2. リベース - 履歴を一直線に
ローカルの変更をリモートの変更の上に再適用します。

```bash
# リベース戦略を設定（一度だけ）
git config pull.rebase true

# または、このコマンドのみで実行
git pull origin main --rebase
```

### 3. Fast-forward のみ - 安全な更新
リモートがローカルより先に進んでいる場合のみ更新します。

```bash
# Fast-forward のみを設定（一度だけ）
git config pull.ff only

# または、このコマンドのみで実行
git pull origin main --ff-only
```

## 推奨手順

### ステップ1: 現在の状態を確認

```bash
# ローカルの変更を確認
git status

# コミット履歴を確認
git log --oneline --graph --all -10

# リモートとの差分を確認
git fetch origin
git log HEAD..origin/main --oneline  # リモートにあってローカルにないコミット
git log origin/main..HEAD --oneline  # ローカルにあってリモートにないコミット
```

### ステップ2: ローカルの変更を保存（必要に応じて）

```bash
# 未コミットの変更がある場合
git stash

# または、コミットする
git add .
git commit -m "作業中の変更を保存"
```

### ステップ3: マージで解決（推奨）

```bash
# マージ戦略でpull
git pull origin main --no-rebase

# コンフリクトが発生した場合
# 1. コンフリクトファイルを編集
# 2. git add <解決したファイル>
# 3. git commit
```

### ステップ4: リモートにプッシュ

```bash
git push origin main
```

## 注意事項

- **マージ**: 両方の変更を保持するため、履歴が分岐しますが安全です
- **リベース**: 履歴が一直線になりますが、既にプッシュしたコミットを書き換える場合は注意が必要です
- **Fast-forward**: ローカルの変更がある場合は失敗します

## 緊急時の対処法

もしローカルの変更を破棄してリモートに合わせたい場合：

```bash
# ⚠️ 注意: ローカルの変更が失われます
git fetch origin
git reset --hard origin/main
```

