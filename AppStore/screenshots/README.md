# スクリーンショット

- `iphone-large/`: 1320×2868 RGB PNG。Dynamic Islandの大画面用（従来6.9インチ枠など）。
- `iphone-medium/`: 1206×2622 RGB PNG。現行仕様のDynamic Island中画面用。
- `ipad-13/`: ParkingSpotのみ。2064×2752 RGB PNG。13インチiPad用。
- `watch/`: Watch対応アプリのみ。416×496 RGB PNG。46mm Series 12で撮影。同じアプリ内でサイズを統一。
- `raw/`: 原本。個人データではなく、Debug専用の分離ストレージに架空の記録を入れ、実際のSwiftUI画面を撮影。
- `CONTACT-SHEET.jpg`: iPhone大画面セットの一覧。提出には使わない。

アップロードは各フォルダ内の番号順です。1サイズにつき最大10枚。原本とキャプション付きの両方を同じ枠に入れる必要はありません。

iPhoneの2種類のキャンバスは、同じ実画面を縦横比を維持して全面収録し、画像内の見出しを再配置しています。画面の捏造・コントロールの描き直し・フレームを超える切り抜きはしていません。Watch画像は実画面のままです。iPadはiPad Simulatorで別撮影しています。

現在のApple仕様は画面サイズ名の表記が更新されています。画像をConnectの対応するピクセルサイズの枠へ割り当て、必須枠の充足を最終確認してください。Appleの実画面仕様: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

撮影結果と元のテスト結果への出典は `reports/capture-*.json`、画像の寸法とSHA-256は `reports/validation.json`。撮り直し手順は `tools/CAPTURE.md`。
