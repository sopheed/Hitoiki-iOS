# App Store Connect 回答案 — ひといき

ソースコードと実画面を確認した2026-11-04時点の案です。Connectに自動送信しません。アカウント・法的地位・素材権利・地域ごとの選択は申請者が確定します。

## App情報

| 欄 | 値・案 |
|---|---|
| プラットフォーム | iOS（同梱Watchアプリは同じAppレコードで提出） |
| 名前 | ひといき（使用可否はConnectで確認） |
| 主要言語 | 日本語 (ja) |
| Bundle ID | `jp.sopheed.Hitoiki` |
| Watch Bundle ID | `jp.sopheed.Hitoiki.watchkitapp` |
| バージョン / ビルド | 1.0 / 1（現在のXcode設定） |
| 最低OS | iOS 17.0 / watchOS 10.0 |
| デバイス | iPhone / Apple Watch |
| 第1カテゴリ案 | ライフスタイル (Lifestyle) |
| 第2カテゴリ案 | ヘルスケア／フィットネス (Health & Fitness) |
| 価格・公開地域・公開方式 | 日本・無料・手動リリースを初回案に。本人が選択 |
| アプリ内課金 / 購読 | なし |
| アカウント・ログイン / 削除URL | アカウント機能なし。ログイン必須「いいえ」。アカウント削除URLは対象外 |
| App Clip / Game Center | なし |
| App Preview動画 / マーケティングURL | 任意。動画なし。Web紹介ページは用意 |
| アクセシビリティ表示 | 対応を断定するラベルは未申告。VoiceOver等を実機で一式確認してから選択 |

## 年齢レーティング

対象は成人。飲酒の記録が中核機能なので「Alcohol, Tobacco, or Drug Use or References」は **Frequent（頻繁）** を選ぶ案です。現行Appleグローバル値は、この回答で **18+** に相当します。日本の飲酒可能年齢20歳と、Appleの年齢表示18+を同一視しません。説明文にも成人向けの用途を明記しています。国・OSで異なる値はConnectの計算結果を確認します。

「Health or Wellness Topics」は **あり**（水分や休憩などセルフケアの声かけ）。「Medical or Treatment Information」は **Infrequent** を推奨します。「ひといきについて」に119・医療機関への相談という健康上の案内が含まれるためです。診断・治療の提供、酔い・運転可否の判定、HealthKit利用はありません。規制対象の医療機器は「いいえ」の案です。

ペアレンタルコントロール、暴力、武器、恐怖、暴言、コンテストはありません。飲酒を促進・競わせるアプリとして紹介しません。

| 項目 | 回答案と根拠 |
|---|---|
| 年齢確認 / Age Assurance | なし。年齢の推定・公的証明書・Declared Age Range APIを実装していない |
| 無制限Webアクセス | なし。任意URLを閲覧するブラウザーはない |
| ユーザー生成コンテンツ | 広く配信するUGCはなし。個人のメモ・写真・名前など端末内の入力とは区別する |
| ソーシャルメディア | なし。公開フィード・反応・拡散がない |
| メッセージ / チャット | なし。他ユーザーとの通信がない |
| 広告 | なし |
| 性的表現・ヌード | なし |
| 賭博・模擬賭博・ルートボックス | なし。金銭や交換可能な通貨の賭け、有料のランダム報酬がない |


回答によるレーティング計算結果・地域別表示を確認します。古いOS向け年齢表示とは値が異なる場合があります。任意の年齢引き上げも、質問票の正確な回答を省略する理由にはしません。

## App Privacy（収集ラベル）

**App Privacy 回答案:「いいえ、このAppからデータを収集しません」**。飲酒・水分・気持ち・メモ・写真はローカル保存。WatchConnectivityはペアリングした利用者の端末間の状態同期に使用し、運営者の収集先はありません。

写真は縮小・JPEG化してメタデータを引き継がず保存。カメラは写真チェックを選んだときだけ要求し、写真ピッカーも選べます。CSVは利用者が選んだ保存先・共有先に書き出します。写真はCSVに含みません。位置情報・マイクは取得しません。

根拠: `Hitoiki/SessionStore.swift`（JSONと写真）、`Hitoiki/CheckInView.swift`（CameraCaptureを含む）（権限と保存）、`Hitoiki/PhoneBridge.swift`・`HitoikiWatch/WatchStore.swift`（端末間同期）、`Hitoiki/PrivacyInfo.xcprivacy`。実際のファイル名は `reports/SOURCE-AUDIT.md` も参照。

Appleの定義では、運営者や第三者がリアルタイムのリクエスト処理に必要な期間を超えてアクセスできる形で、データを端末外へ送信することが「収集」です。端末内の保存、権限の使用、プライバシーマニフェストと、App Storeの収集ラベルは別に確認します。

- トラッキング: しない。ATT要求なし。
- 運営者の収集、広告・解析SDK、会員登録、アプリ内課金: なし。
- AppleによるOS・バックアップ・サービスの処理と、運営者による収集を区別する。
- サポートメールで本人が提供するメールアドレス等は返信・調査にのみ使う。任意開示の例外条件を満たすかは、公開する問い合わせ方法を確定して確認する。
- サポートサイトに解析・広告・フォーム・追加Cookieを入れたり、サーバー側ログを運営利用したりする場合は、サイトの方針も更新する。


プライバシーポリシーURLは `11_privacy_policy_url.txt`。利用者がブラウザーで閲覧できるHTTPSページとして公開します。アプリ内にも容易にアクセスできる方針が必要です。現状の設定/説明画面のデータ説明を含め、公開先確定後に導線と運営者・問い合わせ先の整合を確認してください。

## 暗号化・輸出

標準OS通信・Appleのフレームワークに依存し、独自暗号や独自VPNを実装していないため、非免除暗号は「なし」の案です。`ITSAppUsesNonExemptEncryption = NO` は「免除対象外の暗号化を使わない」の意味で、HTTPS・OS暗号化を含め「暗号化を一切しない」の意味ではありません。Connectの質問文に沿って回答し、将来通信SDKや暗号機能を追加した場合は再評価します。

ParkingSpotはAppleサービスの通信を利用するため、質問が「暗号化を使用するか」であればOSの暗号化を考慮します。生成した申告文だけを理由に輸出手続きの全義務が免除されるとは断定しません。

## コンテンツ権利・アカウント・DSA

素材・アイコン・文章・写真の作成元と利用条件を確認し、必要な権利があることを本人が宣言します。撮影データは架空の記録です。Appleの地図のロゴや著作権表示は画面をそのまま撮影して残しています。

- Apple Watchは **飲み会をiPhoneで開始してから** 利用。Watchだけで開始できる、という説明にしない。
- 通知は通常iPhoneまたはWatchの一方。常に両方に届くと書かない。
- パズルの成績を酔いの判定に使わない。水で分解が早まる、飲酒後も運転できるなどと書かない。

DSAの事業者/非事業者は、個人開発・無料であることだけでは決めません。実際の商業活動・収益・目的に基づいて本人が回答します。EUで配信する事業者には表示する住所・電話・メール等の確認があります。EU配信を選ばない場合も、Connectの案内に従って必要な回答をします。

## 審査情報

- 名前、電話番号、メール: `publisher.json` の `review_contact` に本人が設定。サイト用の連絡先とは別。
- サインイン必須: いいえ。デモアカウント不要。
- 審査メモ: `metadata/ja/10_review_notes.txt`。審査員向けの英語で、画面上の日本語も記載。
- 添付: 追加の説明資料は必須でないため未添付。必要に応じて実機の操作動画等を本人が用意。

## Apple一次資料

- Apple スクリーンショット仕様: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- App情報: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
- バージョン情報・文字数: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
- 年齢レーティング: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/
- App Privacy: https://developer.apple.com/app-store/app-privacy-details/
- 審査ガイドライン: https://developer.apple.com/app-store/review/guidelines/
- 輸出コンプライアンス: https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/
- DSA: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/
