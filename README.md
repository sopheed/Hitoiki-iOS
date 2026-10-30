# ひといき — Hitoiki

楽しい飲み会で時間を忘れず、自分のペースを思い出すためのiPhone / Apple Watchアプリです。しずくの相棒「ぽた」が、お水・休憩・帰る予定をやさしく促します。

## 起動

1. `Hitoiki.xcodeproj` をXcodeで開きます。
2. Scheme `Hitoiki`、iPhoneシミュレータまたは実機を選んで実行します。
3. 実機では `Hitoiki` と `HitoikiWatch` の **Signing & Capabilities → Team** を自分のチームに設定してください。Bundle IDも必要に応じて両方変更します。Watchの `Configuration/HitoikiWatch-Info.plist` にある `WKCompanionAppBundleIdentifier` をiPhoneのBundle IDと揃えてください。
4. Watchはペアリングした端末にインストールして、Scheme `HitoikiWatch` で起動できます。飲み会の開始はiPhoneからです。

外部パッケージ、サーバー、APIキーは不要です。iOS 17 / watchOS 10以降に対応し、この環境ではXcode 27.1で検証しています。署名チームは指定していません。

## できること

- 終了予定（1〜6時間）、通知間隔（30 / 60 / 90分、初期値1時間）、任意の杯数の目安を決めて飲み会を開始
- 日時に基づく経過時間。バックグラウンド・再起動後も継続
- お水のワンタップ記録と直後の取り消し、お酒の種類別記録
- 時間・お水・帰る予定のローカル通知、終了予定の通知
- 通知のアクションからお水の記録、またはチェック画面へ移動
- 計算・しずく探し・カメラ / 選択した写真でのチェックと、その時の気持ちの記録
- 前のチェックから15分以上経過した起動時、またはアプリを30秒以上閉じて戻った時のチェック表示（設定で無効化可能）
- 飲み会の終了、メモ、記録帳と写真付きタイムライン、メモの編集、検索、削除
- 完了した飲み会をCSV出力（写真は含みません）
- Apple Watchの経過時間・終了予定、お水 / お酒の記録、終了操作
- ライト / ダークモード、Dynamic Type、VoiceOverのラベル、触覚設定
- オリジナルキャラクターとライト / ダークのiPhoneアイコン、Watchアイコン

## 設計上の約束

チェックは「意識を今に戻す遊び」です。酔いのスコア、血中アルコール濃度、安全な飲酒量、運転可否は表示しません。お水や正解でアルコールが分解されたと誤解しないよう案内しています。飲酒後は運転せず、必要なら周囲の人や医療機関に頼ることを案内します。

- 通知は1回の飲み会につき最大60回分と終了予定を予約し、アプリを開くと補充します（1時間間隔で約60時間先まで）。終了後は予約・表示済み通知を取り消します。集中モード・通知許可・電源・OS状態等の影響を受けます。
- 通知はiPhone側で予約します。Watchへの通知はOSのミラーリングに従い、重複するWatch独自通知は予約しません。実機のiPhone / Watch双方の設定で確認してください。
- 杯数は容量や濃度を揃えていない記録回数です。安全な上限を提案する機能ではありません。
- Watchで通信できない時は記録を端末内のキューに保存し「同期待ち」と表示します。iPhoneがコマンドを保存した後に確認を返し、キューから取り除きます。コマンドIDを永続化し再送の二重追加を防ぎます。終了済みの飲み会への遅延コマンドは追加せず、Watchに案内を出します。
- Watchはコンパニオンアプリです。単独の新規開始・iCloud同期・HealthKit連携はありません。

## 保存とプライバシー

iPhoneのApplication Support内 `Hitoiki/archive.json` に日時・設定・記録を保存し、写真は `Hitoiki/Photos/` のJPEGです。アカウント、広告、位置情報、ネットワークAPI、解析SDKはありません。Watchとの同期にはWatchConnectivityを使います。

JSONは変更を検証して原子的に保存してから画面に反映します。書き込みに失敗した変更は反映せず、エラーを表示します。読み込み不能のファイルを空データで上書きしません。写真は長辺1280px以下に再描画してJPEG化し、元写真のメタデータは引き継ぎません。フォトライブラリはPhotosPicker経由で選択した画像だけを読み込みます。

端末バックアップに含まれる可能性があります。アプリ削除で端末内の記録も削除されます。記録削除時には対応する写真も削除します。CSVを書き出す場合はユーザーが保存先を選択します。

## 構成

- `Shared/` — Codableモデル、入力検証、通知計画、Watch通信モデル、時間表示、CSV、SwiftUIのぽた
- `Hitoiki/` — iPhone画面、JSON保存、通知、写真、WatchConnectivity
- `HitoikiWatch/` — Watch画面と永続送信キュー
- `HitoikiTests/` — 状態遷移、保存失敗、破損保護、再送、CSV、OS通知のテスト
- `HitoikiUITests/` — 開始・記録・チェック・終了・履歴・検索・編集・削除の操作テスト
- `Tools/generate_project.py` — Xcodeプロジェクト / 共有Schemeの再生成（Python標準ライブラリ）
- `Tools/make_icon.py` — オリジナルアイコンの再生成（Pillow）
- `Documentation/VALIDATION.md` — 確認結果と実機確認事項

通常のソース追加はXcodeのフォルダ同期で自動認識します。プロジェクトを手動で変更した後に生成スクリプトを実行すると、その変更が置き換わる点に注意してください。

## テスト

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Hitoiki.xcodeproj -scheme Hitoiki \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO test
```

通知のOS結合テストは通知許可済みの端末で実行します。未許可の場合はスキップします。UIテストが開始時に通知を許可した後、再実行すると配信まで検証できます。実際の1時間間隔を保ち、開始日時を約1時間前にしたテスト用記録を使います。

UIテストの `--uitest` はDebugだけで有効な隔離保存先を使い、`--reset` はそのテスト用保存先だけを初期化します。通常の記録を削除しません。Releaseでは両引数を無視します。
