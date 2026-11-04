# 実画面の撮り直し

Xcodeを使用します。下記の `DEVICE_UDID` は `xcrun simctl list devices available` で確認した対象デバイスのIDへ置き換えます。個人データのないSimulatorを使い、Watchのペア接続を使った撮影と同時に実行しないでください。

```sh
cd /Users/skyan/Documents/Source/Sopheed/iOS/Hitoiki-iOS
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Hitoiki.xcodeproj -scheme Hitoiki -destination 'platform=iOS Simulator,id=DEVICE_UDID' -derivedDataPath /tmp/Hitoiki-StoreCapture -resultBundlePath /tmp/Hitoiki-StoreCapture.xcresult -only-testing:HitoikiUITests/HitoikiUITests/testAppStoreScreenshots CODE_SIGNING_ALLOWED=NO
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool export attachments --path /tmp/Hitoiki-StoreCapture.xcresult --output-path /tmp/Hitoiki-StoreCapture-attachments
python3 AppStore/tools/import_captures.py /tmp/Hitoiki-StoreCapture-attachments --xcresult /tmp/Hitoiki-StoreCapture.xcresult
python3 AppStore/tools/build_kit.py
```

上記は未使用の `/tmp` 出力先で実行します。既存のxcresultがある場合は別名を使ってください。iPadを撮る場合はiPadのIDを指定し、importに `--group ipad-13` を追加します（ParkingSpotのみ）。Simulatorの時刻は `xcrun simctl status_bar DEVICE_UDID override --time '9:41' --batteryState charged --batteryLevel 100` で整えられます。

fixtureは `--store-screenshots` と既存のUIテスト用引数を使います。Releaseにはfixture実装が含まれません。Debug用の分離ストレージを使い、既存の個人データを消去しません。ソースを変更したら画像も撮り直してください。

## Watch

46mm Watch Simulatorで撮影した416×496を同じセットで使っています。Debugの `HitoikiWatch` スキームを `platform=watchOS Simulator,id=WATCH_UDID` にビルドしてインストールしたあと:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch WATCH_UDID jp.sopheed.Hitoiki.watchkitapp --store-screenshots -AppleLanguages '(ja)' -AppleLocale ja_JP
# 画面が落ち着いてから、未使用の一時ファイルに撮影
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io WATCH_UDID screenshot /tmp/Hitoiki-watch-active-new.png
```

待機画面は一度アプリを終了し、同じ引数へ `--store-ready` を追加して再起動。画像を `screenshots/raw/watch/` に保存し、アルファのないRGB版を `screenshots/watch/` に置きます。実際の撮影出典は `reports/capture-watch.json`。スクリーンショットfixtureは端末間同期を開始しません。
