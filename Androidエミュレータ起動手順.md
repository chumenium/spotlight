# Androidエミュレータ起動手順

## 🚀 クイックスタート（2つの方法）

### 方法1: Android Studioで起動（推奨・簡単）

1. **Android Studioを起動**
2. 右上の「Device Manager」アイコンをクリック
3. エミュレータを選択して「▶️」ボタンをクリック

もしエミュレータがない場合：
1. Device Manager → 「Create Device」
2. 好きなデバイスを選択（例: Pixel 7）
3. システムイメージをダウンロード（推奨: 最新版）
4. 「Finish」→ エミュレータが作成される

---

### 方法2: コマンドラインで起動

#### ステップ1: 利用可能なエミュレータを確認

```bash
flutter emulators
```

**出力例**:
```
2 available emulators:

Pixel_7_API_34        • Pixel 7 API 34       • Google • android
Pixel_5_API_30        • Pixel 5 API 30       • Google • android
```

#### ステップ2: エミュレータを起動

```bash
flutter emulators --launch Pixel_7_API_34
```

または

```bash
emulator -avd Pixel_7_API_34
```

#### ステップ3: アプリを実行

エミュレータが起動したら：

```bash
flutter run
```

デバイス一覧が表示されたら、Androidエミュレータを選択：
```
[1]: Pixel 7 API 34 (android)  # ← これを選択
```

---

## 🎯 最も簡単な方法

### VSCode / Cursorを使用している場合

1. 右下の「No Device」をクリック
2. 「Start Android Emulator」を選択
3. エミュレータを選択
4. 自動的に起動

その後、F5キーまたは「Run」→「Start Debugging」でアプリが起動

---

## 🔧 エミュレータがない場合

### Android Studioでエミュレータを作成

1. **Android Studio を起動**
2. **More Actions** → **Virtual Device Manager**
3. **Create Device** をクリック
4. デバイスを選択（推奨: Pixel 7 または Pixel 5）
5. システムイメージを選択（推奨: 最新の Android 13 以上）
6. **Download** をクリック（初回のみ）
7. **Next** → **Finish**

---

## ⚡ トラブルシューティング

### エミュレータが起動しない

**原因1: Intel HAXM または AMD Hyper-Vが無効**

**解決策（Windows）**:
```bash
# 1. BIOS設定で仮想化を有効化
# 2. Windowsの機能でHyper-Vを有効化
```

**原因2: メモリ不足**

**解決策**: エミュレータの設定でRAMを減らす（2GB程度）

### `flutter emulators`でエミュレータが表示されない

**解決策**:
```bash
# Android SDKのパスを確認
flutter doctor -v

# Android Studioで新しいエミュレータを作成
```

---

## 📱 推奨エミュレータ設定

### 開発用に最適な設定
- **デバイス**: Pixel 7
- **API Level**: 34 (Android 14) または 33 (Android 13)
- **RAM**: 2GB
- **内部ストレージ**: 4GB

---

## 🚀 実行コマンドまとめ

```bash
# 1. エミュレータ一覧確認
flutter emulators

# 2. エミュレータ起動
flutter emulators --launch Pixel_7_API_34

# 3. アプリ実行
flutter run

# または、全部まとめて
flutter run  # エミュレータが起動していれば自動的に選択される
```

---

## ⚡ 最速手順

### すぐに試したい場合

```bash
# ターミナルで実行
flutter run
```

デバイス選択が表示されたら：
```
[1]: Pixel 7 API 34 (android)
[2]: Windows (windows)
Please choose one: 1  # ← Androidを選択
```

エミュレータが起動していない場合は、Android Studioで起動してから再度`flutter run`

---

## 🎯 次のステップ

エミュレータが起動したら：

1. **アプリが自動的にインストール・起動**される
2. **ソーシャルログイン画面**が表示される
3. **Googleログイン**と**Twitterログイン**ボタンが表示される
4. ボタンをタップしてテスト！

---

## 💡 Tips

### エミュレータの起動を速くする

1. Android Studioの設定 → Emulator
2. 「Boot option」→「Cold boot」を「Quick boot」に変更
3. スナップショット保存を有効化

### 実機で試す場合

1. AndroidデバイスをUSBで接続
2. 開発者オプションを有効化
3. USBデバッグを有効化
4. `flutter run`で実機が選択される

実機の方が動作が速くて快適です！

