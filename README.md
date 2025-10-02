# SpotLight

隠れた才能発見プラットフォーム

## プロジェクト概要

SpotLightは、日常の中の小さな成果や才能を気軽に投稿・共有し、ユーザー同士で承認（いいね/コメント/バッジ）するSNS型アプリです。

## 技術スタック

- **フレームワーク**: Flutter
- **言語**: Dart
- **状態管理**: Provider
- **ルーティング**: GoRouter
- **HTTP通信**: Dio
- **画像処理**: image_picker, cached_network_image
- **ローカルストレージ**: shared_preferences

## プロジェクト構造

```
lib/
├── main.dart              # アプリのエントリーポイント
├── models/                # データモデル
├── providers/             # 状態管理（Provider）
├── screens/               # 画面
├── widgets/               # 再利用可能なウィジェット
├── services/              # API通信・外部サービス
└── utils/                 # ユーティリティ関数

assets/
├── images/                # 画像ファイル
├── icons/                 # アイコンファイル
└── fonts/                 # フォントファイル
```

## 開発環境

- Flutter SDK: >=3.0.0
- Dart SDK: >=3.0.0

## セットアップ

1. Flutter SDKをインストール
2. 依存関係をインストール:
   ```bash
   flutter pub get
   ```
3. アプリを実行:
   ```bash
   flutter run
   ```

## 機能概要

- ユーザー認証（ログイン/新規登録）
- 投稿機能（テキスト・画像）
- いいね・コメント機能
- バッジシステム
- タイムライン表示
- プロフィール管理
- 通知機能

## 開発状況

現在、プロジェクトの基盤構築中です。
