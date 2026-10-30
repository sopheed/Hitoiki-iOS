import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var reminders: ReminderCenter
    @EnvironmentObject private var bridge: PhoneBridge
    var body: some View {
        Form {
            Section {
                HStack(spacing:16) {
                    PotaView().frame(width:75,height:80).accessibilityHidden(true)
                    VStack(alignment:.leading,spacing:6) {
                        Text("ぽたと、あなたのペースで。").font(.headline)
                        Text("見守り方を整えよう。") .font(.subheadline).foregroundStyle(Palette.secondary)
                    }
                }.listRowBackground(Color.clear)
            }
            Section {
                Toggle("飲み会中の通知",isOn:preference(\.remindersEnabled))
                    .onChange(of:store.archive.preferences.remindersEnabled) { _, value in if value { Task { await reminders.request() } } }
                HStack { Text("iPhoneの通知設定"); Spacer(); Text(permissionText).foregroundStyle(Palette.secondary) }
                if reminders.permission == .denied {
                    Button("iPhoneの設定で通知を許可する") { openSettings() }
                    Text("通知を許可しなくても、時間の確認と記録は使えます。")
                        .font(.footnote).foregroundStyle(Palette.secondary)
                } else if reminders.permission == .notDetermined {
                    Button("通知を許可する") { Task { await reminders.request() } }
                }
                Picker("次回からの間隔",selection:preference(\.reminderMinutes)) {
                    Text("30分").tag(30); Text("1時間").tag(60); Text("90分").tag(90)
                }
            } header: { Text("やさしい声かけ") } footer: {
                Text("通知間隔は次の飲み会から適用します。集中モードや消音など、端末の設定によって通知に気づけない場合があります。")
            }
            Section {
                Stepper("次回は\(store.archive.preferences.durationHours)時間くらい",value:preference(\.durationHours),in:1...6)
                Toggle("戻ってきたら、ひといきチェック",isOn:preference(\.returnCheckIn))
                Toggle("記録したら触覚でお知らせ",isOn:preference(\.haptics))
            } header: { Text("自分に合ったペース") } footer: {
                Text("チェックから15分以上経った起動時、またはアプリを30秒以上閉じてから戻ったときに表示します。")
            }
            Section {
                Label(bridge.watchAvailable ? "Apple Watchと連携しています" : "Apple Watchでも、ひといき。",systemImage:"applewatch")
                Text("Watchアプリでは経過時間の確認、お水・お酒の記録、おひらきができます。飲み会の開始はiPhoneから。通信がない時の記録は同期待ちとして残します。")
                    .font(.footnote).foregroundStyle(Palette.secondary)
                Text("通知はiPhone・Watchのロック状態と通知設定に応じて、通常どちらかに届きます。Watch側にも通知を許可してください。")
                    .font(.footnote).foregroundStyle(Palette.secondary)
            } header: { Text("手元から、かんたんに") }
            Section {
                NavigationLink("ひといきについて・使い方") { AboutView() }
                Text("アカウント不要 / 広告なし / アプリから外部送信なし")
                    .font(.caption).foregroundStyle(Palette.secondary)
            } footer: { Text("ひといき 1.0 • MADE WITH A LITTLE CARE") }
        }.navigationTitle("せってい").scrollContentBackground(.hidden).background(Palette.canvas)
            .task { await reminders.refreshPermission() }
    }
    private func preference<Value>(_ path: WritableKeyPath<Preferences,Value>) -> Binding<Value> {
        Binding(get:{ store.archive.preferences[keyPath:path] },set:{ value in var prefs = store.archive.preferences; prefs[keyPath:path] = value; store.updatePreferences(prefs) })
    }
    private var permissionText: String {
        switch reminders.permission { case .authorized,.provisional,.ephemeral: return "許可済み"; case .denied: return "未許可"; default: return "未設定" }
    }
    private func openSettings() { if let url = URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                PotaView().frame(width:140,height:140).frame(maxWidth:.infinity)
                SectionCaption(overline:"HELLO, I'M POTA",title:"ひといきは、自分に戻る時間。")
                paragraph("ぽたの役目", "楽しい飲み会で、時間と帰る予定を思い出すお手伝いをします。お水を飲んだり、少し休んだり。飲むことを責めずに、自分のペースを大切にするためのアプリです。")
                paragraph("チェックについて", "計算・しずく探し・写真は、意識を今に戻すきっかけです。正解しても、酔いがさめたことや判断力が正常なことを意味しません。お水もアルコールの分解を早めません。飲酒後は運転しないでください。")
                paragraph("つらいときは", "無理に飲み続けず、休んで近くの人に声をかけてください。呼びかけに反応しない、呼吸がおかしいときは119へ。飲酒のコントロールに困ることが続く場合は、医療機関や地域の相談窓口へ相談してください。")
                paragraph("データと写真", "記録と写真は端末内に保存します。Watchとの連携にはAppleのWatchConnectivityを使用します。位置情報の取得や、広告・解析サービスへの送信は行いません。端末のバックアップ設定によってはOSのバックアップに含まれます。アプリを削除すると記録も削除されます。必要な記録はCSVで書き出せます（写真は含みません）。")
                paragraph("通知について", "飲み会中は最大60回分と終了予定の通知を予約します。アプリを開くと予約を補充します。終了すると残りの通知を取り消します。通知は端末の設定や電源状態などに左右されます。")
                Text("今日のあなたにも、明日のあなたにも。")
                    .font(.subheadline.bold()).foregroundStyle(Palette.forest).frame(maxWidth:.infinity).padding(.vertical,12)
            }.padding(24)
        }.background(Palette.canvas).navigationTitle("ひといきについて").navigationBarTitleDisplayMode(.inline)
    }
    private func paragraph(_ title: String,_ content: String) -> some View {
        VStack(alignment:.leading,spacing:10) {
            Text(title).font(.headline)
            Text(content).font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(6)
        }
    }
}
