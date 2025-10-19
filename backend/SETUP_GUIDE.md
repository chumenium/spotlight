# 🚀 バックエンド セットアップガイド（チームメンバー向け）

このガイドでは、SpotLightバックエンドの環境構築手順を簡単に説明します。

## ⏱️ 所要時間
約5〜10分

## 📋 前提条件

以下がインストールされていることを確認してください：
- Python 3.9以上（推奨: 3.13）
- Git
- ターミナル（コマンドライン）の基本操作ができる

## 🎯 セットアップ手順（3ステップ）

### ステップ1: プロジェクトを取得

```bash
# 既にクローンしている場合
cd spotlight/backend
git pull

# まだクローンしていない場合
git clone <repository-url>
cd spotlight/backend
```

### ステップ2: 仮想環境を作成してパッケージをインストール

```bash
# 仮想環境を作成
python3 -m venv venv

# 仮想環境をアクティベート
# macOS/Linux:
source venv/bin/activate

# Windows:
# venv\Scripts\activate

# パッケージをインストール
pip install --upgrade pip
pip install -r requirements.txt
```

### ステップ3: 環境変数を設定

```bash
# サンプルファイルをコピー
cp env.example .env

# .envファイルを編集（必要に応じて）
# 初回はそのままでOKです
```

## ✅ 動作確認

サーバーを起動してみましょう：

```bash
python app.py
```

以下のような表示が出れば成功です：

```
============================================================
SpotLight API Server Starting...
============================================================
Environment: development
Host: 0.0.0.0
Port: 5000
Debug: True
============================================================

Available endpoints:
  - GET  /
  - GET  /api/health
  - POST /api/auth/register
  ...
============================================================
```

ブラウザで `http://localhost:5000/api/health` を開いて、正常なレスポンスが返ってくれば完了です！

## 🎓 次のステップ

### バックエンド担当の方
- `routes/` ディレクトリ内のファイルを確認
- 各エンドポイントのロジックを実装
- API仕様書（`/docs/API仕様書.md`）を参照

### DB担当の方
- `models/` ディレクトリにモデル定義を追加
- 各ルートファイルの `# TODO: DB担当メンバー〜` を検索
- データベース処理を実装

### フロントエンド担当の方
- `http://localhost:5000` でAPIサーバーを起動
- Flutter アプリからAPI呼び出しをテスト
- API仕様書を参照して連携

## 🐛 トラブルシューティング

### Q: `python3: command not found`
**A:** Pythonがインストールされていません。[Python公式サイト](https://www.python.org/)からインストールしてください。

### Q: `ModuleNotFoundError: No module named 'flask'`
**A:** 仮想環境がアクティベートされていないか、パッケージがインストールされていません。

```bash
# 仮想環境を再度アクティベート
source venv/bin/activate

# パッケージを再インストール
pip install -r requirements.txt
```

### Q: `Address already in use`
**A:** ポート5000が既に使用されています。`.env` ファイルで別のポートを指定してください：

```bash
PORT=5001
```

### Q: PostgreSQL関連のエラー
**A:** `psycopg2-binary` は現在コメントアウトされています。DB担当メンバーがPostgreSQLをセットアップするまで無視してOKです。

## 📞 ヘルプ

わからないことがあれば、チームチャットで質問してください！

---
**Happy Coding! 🎉**

