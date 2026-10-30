import SwiftUI

struct StartView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var reminders: ReminderCenter
    @Environment(\.dismiss) private var dismiss
    @State private var hours = 2
    @State private var reminder = 60
    @State private var useGoal = false
    @State private var goal = 3
    @State private var starting = false
    var body: some View {
        Form {
            Section {
                HStack(spacing:18) {
                    PotaView().frame(width:80,height:90).accessibilityHidden(true)
                    VStack(alignment:.leading,spacing:7) {
                        Text("今日のペースを決めよう").font(.headline)
                        Text("帰る時間を先に決めると、\nあとで自分にやさしくなれるよ。")
                            .font(.subheadline).foregroundStyle(Palette.secondary)
                    }
                }.listRowBackground(Color.clear)
            }
            Section("おひらきの目安") {
                Stepper("\(hours)時間くらい",value:$hours,in:1...6)
                Label(Date().addingTimeInterval(Double(hours)*3600).formatted(date:.omitted,time:.shortened) + " ごろ",systemImage:"moon.stars").foregroundStyle(Palette.secondary)
            }
            Section("ぽたが声をかける間隔") {
                Picker("通知の間隔",selection:$reminder) {
                    Text("30分").tag(30); Text("1時間").tag(60); Text("90分").tag(90)
                }.pickerStyle(.segmented)
                Text("お水・時間・帰る予定を思い出す通知です。終了予定にもお知らせします。")
                    .font(.footnote).foregroundStyle(Palette.secondary)
            }
            Section {
                Toggle("自分で杯数の目安を決める",isOn:$useGoal)
                if useGoal { Stepper("今日は\(goal)杯まで",value:$goal,in:1...20) }
            } footer: { Text("杯数は自分のための目安です。安全な飲酒量や、酔いの程度を示すものではありません。") }
            Section {
                Button {
                    starting = true
                    Task { @MainActor in
                        if store.archive.preferences.remindersEnabled { await reminders.request() }
                        if store.start(hours:hours,reminder:reminder,goal:useGoal ? goal : nil) { dismiss() }
                        starting = false
                    }
                } label: { Text(starting ? "準備しています…" : "ぽたと、はじめる").frame(maxWidth:.infinity) }
                    .buttonStyle(FilledButton()).disabled(starting).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                    .accessibilityIdentifier("confirmStart")
            } footer: { Text("記録はこのiPhoneに保存します。途中で閉じても時間は続きます。") }
        }
        .scrollContentBackground(.hidden).background(Palette.canvas)
        .navigationTitle("飲み会をはじめる").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement:.cancellationAction) { Button("閉じる") { dismiss() }.disabled(starting) } }
        .onAppear { hours = store.archive.preferences.durationHours; reminder = store.archive.preferences.reminderMinutes }
        .interactiveDismissDisabled(starting)
    }
}

struct DrinkView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    var completed: ()->Void
    var body: some View {
        List {
            Section {
                Text("飲んだものを、そっとメモ。\n量や濃さはさまざまなので、回数の記録です。")
                    .font(.subheadline).foregroundStyle(Palette.secondary).listRowBackground(Color.clear)
            }
            Section("1杯を記録") {
                ForEach(DrinkKind.allCases) { kind in
                    Button {
                        if store.add(kind:.drink,detail:kind.rawValue) { completed(); dismiss() }
                    } label: { HStack { Text(kind.rawValue); Spacer(); Image(systemName:"plus.circle") } }
                    .accessibilityIdentifier("drink_\(kind.id)")
                }
            }
        }.scrollContentBackground(.hidden).background(Palette.canvas)
            .navigationTitle("お酒の記録").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("閉じる") { dismiss() } } }
    }
}

struct FinishView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    var completed: ()->Void
    var body: some View {
        ScrollView {
            VStack(spacing:24) {
                PotaView(resting:true).frame(width:140,height:140).padding(.top,12)
                Text("今日も、おつかれさま。").font(.system(.title2,design:.rounded,weight:.bold))
                Text("ここまでの時間を大切に残そう。\n帰り道も、ゆっくりね。")
                    .font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center).lineSpacing(4)
                if let s = store.active {
                    SoftCard { HStack {
                        Metric(value:TimeText.duration(s.elapsed()),label:"過ごした時間",symbol:"clock")
                        Metric(value:"\(s.waterCount)回",label:"お水の記録",symbol:"drop")
                    } }
                }
                VStack(alignment:.leading,spacing:10) {
                    Text("ひとことメモ（任意）").font(.subheadline.bold())
                    TextField("楽しかったこと、次に覚えておきたいこと",text:$note,axis:.vertical)
                        .lineLimit(3...6).padding(18).background(Palette.card,in:RoundedRectangle(cornerRadius:20))
                        .accessibilityIdentifier("finishNote")
                }
                Button {
                    if store.end(note:note) { completed(); dismiss() }
                } label: { Label("記録して、おひらき",systemImage:"checkmark") }.buttonStyle(FilledButton()).accessibilityIdentifier("confirmFinish")
                Text("飲酒後は運転せず、公共交通機関やタクシーなどで帰ろう。")
                    .font(.footnote).foregroundStyle(Palette.secondary)
            }.padding(24)
        }.background(Palette.canvas).navigationTitle("今日はここまで").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("戻る") { dismiss() } } }
    }
}
