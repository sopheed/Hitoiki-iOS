# ひといき — App Store公開準備キット

2026-11-04作成。現在のアプリに合わせた日本語の登録文、実画面のスクリーンショット、アイコン、公開用Webページ、申告案を揃えています。App Store Connectへの登録・アップロード・審査提出・サイト公開は行っていません。

| 内容 | 場所 |
|---|---|
| コピペする登録文（11項目） | `metadata/ja/` |
| カテゴリ・年齢・プライバシー・輸出・審査情報 | `metadata/answers.md` |
| iPhoneのアップロード用画像 | `screenshots/iphone-large/` と `screenshots/iphone-medium/` |
| 実画面の原本と撮影出典 | `screenshots/raw/` と `reports/capture-*.json` |
| 1024pxのアイコン（既存デザイン） | `icons/` |
| サポート・プライバシー・紹介ページ | `site/` |
| 再生成・検証 | `tools/build_kit.py` |
| 検証結果・SHA-256 | `reports/validation.json` |
| 受け渡し用ZIP | `dist/` |

Watch対応アプリは `screenshots/watch/`、iPad対応アプリは `screenshots/ipad-13/` も使います。`CONTACT-SHEET.jpg` は一覧確認用で、提出画像ではありません。

## 公開前に埋めるもの

共通の `/Users/skyan/Documents/Source/Sopheed/iOS/AppStoreRelease/publisher.json`に、実際の公開URL、問い合わせメール、権利者名、非公開の審査担当者連絡先を設定します。3アプリをまとめて再生成する場合:

```sh
cd /Users/skyan/Documents/Source/Sopheed/iOS
python3 -m pip install 'Pillow>=10,<13'
python3 AppStoreRelease/tools/prepare_all.py
```

このキットだけで作業する場合は `publisher.json` を編集し、`python3 tools/build_kit.py` を実行します。公開先と連絡先が未定なのでURL欄は空です。実在しないドメインを貼らないでください。設定後、`site/` を公開して到達性・連絡先・アプリ内からプライバシー方針を読めることを確認します。

`--strict` は未設定や未確認があれば終了コード2にします。本人確認、権利、署名実機確認、Connectでの宣言を実際に終えてから `publisher.json` の確認フラグを更新してください。`assets=PASS` は審査提出可能・承認済みを意味しません。

## 登録の順番

1. 個人のApple Developerアカウント、Bundle ID、アプリ名の使用可否を確認する。SKU案は `SOPHEED-HITOIKI-IOS`、主要言語は日本語。
2. ConnectでiOSアプリを作成し、`metadata/ja/` の1〜5、7〜9、11を設定する。初回バージョンには「このバージョンの最新情報」は不要。6は更新時のたたき台として同梱。
3. 推奨カテゴリと年齢質問票、App Privacy、コンテンツ権利、輸出関連を `metadata/answers.md` に沿って回答する。本人確認が必要な宣言は本人が確定する。
4. 端末別の画像を番号順でアップロードする。通常はキャプション付きだけを使い、原本と重複して10枚を超えない。
5. 実機確認と署名Archiveを行い、ビルドをConnectに送信する。審査担当者連絡先と10の審査メモを設定する。ログイン情報は不要。
6. 価格・配信国を本人が選ぶ。初回は「日本・無料・手動リリース」を推奨するが、Connectには設定していない。EU配信を選ぶ場合はDSA申告も確認する。
7. 公開Webページ・アプリ内のプライバシー導線・実機動作を再確認し、本人が審査提出する。

## このアプリで確認すること

- Apple Watchは **飲み会をiPhoneで開始してから** 利用。Watchだけで開始できる、という説明にしない。
- 通知は通常iPhoneまたはWatchの一方。常に両方に届くと書かない。
- パズルの成績を酔いの判定に使わない。水で分解が早まる、飲酒後も運転できるなどと書かない。

App Preview動画、カスタムプロダクトページ、検索広告、App内課金用画像は必須ではなく、このキットには含めていません。日本語UIと一致する日本語ローカライズを用意しています。
