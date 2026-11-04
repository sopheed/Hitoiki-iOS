# ビルド・撮影・検証

実施日: 2026-11-04。Xcode 27.1、DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer。

- ユニットテスト: 19成功 / 19件、失敗0、スキップ0。通知許可後の最終実行を `logic-tests.json` に保存。最初の実行でスキップされた通知予約・到達・取消テストも再確認しました。
- 撮影UIテスト `testAppStoreScreenshots`: iPhoneで成功。ParkingSpotはiPadでも成功。iPadで上部タブを扱うよう撮影操作を調整した後の最終結果を採用。
- iPhone原本: 実際のアプリ画面に架空のデータを表示。個人の記録、写真、位置履歴を使用していない。出典は `capture-iphone.json`。
- Watch対応アプリはSeries 12 46mmで撮影。iPadはParkingSpotのみ13インチで別撮影。各撮影出典は `capture-*.json`。
- キャプション付き画像は全面の縦横比を維持して合成。画像内に地図の権利表記がある場合はそのまま保持。
- `Release`・`generic/platform=iOS`・`CODE_SIGNING_ALLOWED=NO` のビルド: **成功**。Watch対応アプリでは同梱Watchも確認。
- ReleaseのiOS/Watch実行バイナリに撮影fixture名・起動引数が残っていないこと: **確認済み**。
- 外部frameworkの同梱なし。ParkingSpotは広告フレームワーク/リソース/識別子と既知広告クラス名が残っていないことを確認。`release-build.json` にビルド情報とリンク先ライブラリを記録。
- 文字数、キーワードUTF-8バイト数、画像寸法、RGB・透過なし、必須デバイス枚数、アセットSHA-256: `validation.json`。

署名・実機インストール・実機での通知到達/Watch同期の再確認・Archive/Upload・公開URLのHTTP到達確認・審査提出・ストア承認は今回の検証に含みません。ローカルWebページのブラウザー表示確認は `site-check.json` に記録します。テスト結果のスクリーンショット以外の大きなxcresult本体は/tmpにあり、キットには要約と撮影出典を同梱しています。
