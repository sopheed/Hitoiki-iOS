# ビルド・撮影・検証

テスト・撮影日: 2026-11-04。個人用IDへの変更後のReleaseビルド確認日: 2026-11-05。Xcode 27.1、DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer。

- 11月5日、個人チーム `TQQM6G5CS8`、iPhone用 `eijirou.Hitoiki`、Watch用 `eijirou.Hitoiki.watchkitapp` に設定を統一しました。バージョンは **1.0・ビルド1** を維持しています。
- iPhone・Watch・テストのXcode設定、Watchの `WKCompanionAppBundleIdentifier`、プロジェクト生成スクリプトを揃えました。生成スクリプトは再実行せず、既存のXcode設定を必要な箇所だけ編集しています。
- `Release`・`generic/platform=iOS`・`CODE_SIGNING_ALLOWED=NO` のビルド: **成功**。同梱Watchもビルドしています。ログは `/tmp/Hitoiki-personal-Release.log`、結果は `release-build.json`。
- 実際のiPhone／Watch成果物で、新しいBundle ID・バージョン・ビルド番号と、WatchのコンパニオンIDがiPhone用IDと一致することを確認しました。
- 両方のRelease実行バイナリに、撮影fixture名・撮影用起動引数が残っていないことを再確認しています。外部frameworkの同梱はありません。
- ユニットテストは11月4日に19成功／19件、失敗0。`logic-tests.json` に結果を保存。今回は機能ソースを変更しておらず、テスト全体は再実行していません。
- 撮影UIテスト `testAppStoreScreenshots` は11月4日にiPhoneで成功。実際のSwiftUI画面に架空の飲み会データを表示しています。撮影出典は `capture-iphone.json`。ID変更前に取得した原本の出典は変更していません。
- iPhone用キャプション画像は大・中型各7枚。WatchはSeries 12 46mm用416×496を2枚。Watchの撮影出典は `capture-watch.json`。画面・機能・素材を変更していないため同じ画像を使用しています。
- 文字数、キーワードUTF-8バイト数、画像寸法、RGB・透過なし、枚数、SHA-256は `validation.json`。
- Connectの新規登録・紹介文・画像の保存確認は `app-store-connect/2026-11-05/RESULT.md`。

署名・実機インストール・カメラ権限・通知到達・Watch同期の実機確認・Archive/Upload・審査提出・ストア承認は今回の確認範囲に含みません。公開URLは未定です。ローカルWebページの表示確認は11月4日の `site-check.json` に記録しています。大きなxcresult本体は/tmpにあり、キットには要約と撮影出典を同梱しています。
