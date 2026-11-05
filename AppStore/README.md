# ひといき - 飲み会の見守りタイマー — App Store公開準備キット

更新日: 2026-11-05。日本語の登録文・画像・アイコン・公開用Webページ・申告案をまとめています。

| 項目 | 現在の設定 |
|---|---|
| App ID | `6830956191` |
| Bundle ID | `eijirou.Hitoiki` |
| SKU | `eijirou.Hitoiki.iOS` |
| Team | `TQQM6G5CS8` |
| ローカルのバージョン / ビルド | 1.0 / 1 |

[App Store Connectの編集画面](https://appstoreconnect.apple.com/apps/6830956191/distribution/ios/version/inflight)。日本語の説明文・カテゴリ・審査メモと画像16枚を保存済みです。詳しい確認結果は [RESULT.md](reports/app-store-connect/2026-11-05/RESULT.md)。この更新では年齢・収集ラベル・権利・価格などの未確定の申告は変更していません。

Connectには審査用ビルドがまだありません。署名済みビルドのアップロードと選択は利用者が別Macで行います。

## 公開サポートページ

3アプリの紹介・お問い合わせ・プライバシーを**1ページ**にまとめました。

- 紹介: https://sopheed.com/apps/
- サポート: https://sopheed.com/apps/#support
- プライバシーポリシー: https://sopheed.com/apps/#privacy
- 問い合わせ: service@sopheed.com
- 運営者・著作権: Shunji Kyan（既存ストア表記と同じ）

3アプリのサポート・マーケティング・プライバシーURLはApp Store Connectに保存・再読込確認済みです。利用者による公開後、HTMLとアイコン3枚をHTTPS・HTTP 200で取得し、準備ファイルとの一致とPC・iPhone幅の表示を確認しました。ドメインとメールは利用者が指定した公開先で、Bundle ID・SKUは個人用の命名を維持しています。

このキットの `site/index.html` と `site/assets/` でも同じ1ページを公開できます。共通のアップロード用ZIPと配置手順は `AppStoreRelease/WEBSITE-UPLOAD.md` です。

## ファイルと再生成

| 内容 | 場所 |
|---|---|
| 日本語の登録文・URL | `metadata/ja/` |
| 申告案と根拠 | `metadata/answers.md` |
| アップロード用画像 | `screenshots/`（`raw/` と一覧画像は提出用ではありません） |
| 1024pxアイコン | `icons/` |
| 共通Webページ・画像 | `site/` |
| 文字数・画像・SHA-256の確認 | `reports/validation.json` |
| ストア保存確認 | `reports/app-store-connect/2026-11-05/` |
| 受け渡し用ZIP | `dist/` |

単独で再生成する場合は `publisher.json` を編集し、`python3 tools/build_kit.py --skip-images` を実行します。共通ページの公開内容は `site-content.json` と `site-assets/` にも同梱しています。3アプリをまとめて再生成する場合は、iOSワークスペースのルートで `python3 AppStoreRelease/tools/prepare_all.py --skip-images` を実行します。

## 審査提出前

公開ページの到達性は確認済みです。アプリ内からのプライバシー案内、実機と署名、素材権利、残る申告と配信条件を確認してから審査へ進みます。`assets=PASS` は画像・文字数・ファイルの検証結果です。`--strict` は未設定・未確認が残る場合も失敗にします。

アプリ本体のソースは今回変更していません。既存の署名なしRelease確認を、署名・実機・アップロードの成功とは区別しています。アイコンは署名済みビルドの送信後にストアへ反映されます。認証情報・秘密鍵はキットに含めません。
