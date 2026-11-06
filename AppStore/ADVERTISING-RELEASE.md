# 広告対応版のリリース

更新: 2026-11-06。Hitoikiのバナー実装とAdMob広告枠の設定を用意しました。アップロードは別Macから行います。

- 設定元: `../Configuration/Advertising.xcconfig`
- アプリID: `ca-app-pub-5120539001782748~7843047484`
- バナーID: `ca-app-pub-5120539001782748/7874837074`
- DebugはGoogleのテストIDを使います。
- 公開App Storeページへのリンク済み。app-ads.txtのAdMob検証は確認エラーが残っています。

Releaseビルド、設定テスト、広告配置UIテストが成功。`reports/advertising/2026-11-06/` に結果を保存しています。実広告受信は未確認です。このMacのシミュレータではUMPがTLSエラーになり、枠を閉じる動作を確認しました。

次回提出前に、共通のプライバシーページ更新、実機でのAdMob同意画面、App Storeプライバシー申告、署名済み実機でのテスト広告を確認します。詳細と手順は [共通の広告対応ガイド](../../AppStoreRelease/ADVERTISING.md) を参照してください。配布用ソースZIPでは共通ガイドを `AppStoreRelease/ADVERTISING.md` に同梱します。

共通プライバシーページとapp-ads.txtの公開・内容一致は確認済みです。ParkingSpot・ひといき向け欧州同意メッセージもAdMobで公開済みです。
