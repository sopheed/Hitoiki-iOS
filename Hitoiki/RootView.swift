import SwiftUI
import UIKit

enum AppSheet: String, Identifiable {
    case start, drink, checkIn, finish
    var id: String { rawValue }
}

struct RootView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var reminders: ReminderCenter
    @Environment(\.scenePhase) private var phase
    @State private var sheet: AppSheet?
    @State private var tab = 0
    @State private var lastPrompt = Date.distantPast
    @State private var backgroundDate: Date?
    @State private var checkedLaunch = false
    @State private var toast: String?
    @State private var undoID: UUID?
    @State private var toastTask: Task<Void,Never>?

    var body: some View {
        Group {
            if store.loadFailed {
                VStack(spacing:24) {
                    PotaView(resting:true).frame(width:150,height:150)
                    Text("記録を大切に保管しています").font(.title2.bold())
                    Text("データを読み込めませんでした。元のファイルは残しています。空き容量を確認して再試行してください。").multilineTextAlignment(.center)
                    Button("もう一度読み込む") { store.reload() }.buttonStyle(FilledButton())
                }.padding(28)
            } else {
                TabView(selection:$tab) {
                    NavigationStack { HomeView(sheet:$sheet,onWater:recordWater) }.tabItem { Label("いま",systemImage:"drop.fill") }.tag(0)
                    NavigationStack { HistoryView() }.tabItem { Label("きろく",systemImage:"book.closed.fill") }.tag(1)
                    NavigationStack { SettingsView() }.tabItem { Label("せってい",systemImage:"slider.horizontal.3") }.tag(2)
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .sheet(item:$sheet) { selection in
            NavigationStack {
                switch selection {
                case .start: StartView()
                case .drink: DrinkView { showToast("お酒を記録しました") }
                case .checkIn: CheckInView { showToast("ひといき、できたね。") }
                case .finish: FinishView { tab = 1; showToast("今日の記録を残しました") }
                }
            }.tint(Palette.forest).presentationDragIndicator(.visible)
        }
        .overlay(alignment:.bottom) {
            if let toast {
                WaterToast(text:toast,undo:undoID.map { id in { store.undoEntry(id); self.toast = nil; undoID = nil } })
                    .padding(.bottom,85).transition(.opacity).accessibilityIdentifier("toast")
            }
        }
        .alert("お知らせ",isPresented:Binding(get:{ store.errorMessage != nil },set:{ if !$0 { store.errorMessage = nil } })) {
            Button("閉じる",role:.cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .task {
            guard !checkedLaunch else { return }
            checkedLaunch = true
            if store.archive.preferences.returnCheckIn, let session = store.active,
               session.checkInIsDue(at:Date(),lastPrompt:lastPrompt), sheet == nil {
                lastPrompt = Date(); sheet = .checkIn
            }
        }
        .onChange(of:reminders.openCheckIn) { _, shouldOpen in
            if shouldOpen, store.active != nil { tab = 0; sheet = .checkIn; lastPrompt = Date() }
            reminders.openCheckIn = false
        }
        .onChange(of:phase) { _, value in
            if value == .background { backgroundDate = Date() }
            guard value == .active, let backgroundDate, Date().timeIntervalSince(backgroundDate) > 30,
                  store.archive.preferences.returnCheckIn, let session = store.active,
                  session.checkInIsDue(at:Date(),lastPrompt:lastPrompt), sheet == nil else { return }
            lastPrompt = Date(); sheet = .checkIn; tab = 0
        }
        .onChange(of:store.active?.id) { _, _ in if store.active == nil && sheet != .finish { sheet = nil } }
    }
    private func recordWater() {
        let id = UUID()
        guard store.add(kind:.water,detail:"お水をひとくち",id:id) else { return }
        if store.archive.preferences.haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        showToast("お水を記録。いいひといき。",undo:id)
    }
    private func showToast(_ message: String, undo: UUID? = nil) {
        toastTask?.cancel()
        toast = message; undoID = undo
        toastTask = Task { try? await Task.sleep(for:.seconds(5)); if !Task.isCancelled { toast = nil; undoID = nil } }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var reminders: ReminderCenter
    @Binding var sheet: AppSheet?
    var onWater: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                HStack(alignment:.center) {
                    VStack(alignment:.leading,spacing:4) {
                        Text("HITOIKI").font(.system(.caption2,design:.rounded,weight:.heavy)).tracking(3).foregroundStyle(Palette.secondary)
                        Text("ひといき").font(.system(.title2,design:.rounded,weight:.bold))
                    }
                    Spacer()
                    Label(store.active == nil ? "あなたのペースで" : "ぽたが見守り中",systemImage:store.active == nil ? "leaf" : "circle.inset.filled")
                        .font(.caption.weight(.semibold)).padding(.horizontal,12).padding(.vertical,9).background(Palette.mint,in:Capsule())
                }.padding(.top,8)
                if let session = store.active { active(session) } else { idle }
                if let issue = reminders.issue {
                    Label(issue,systemImage:"bell.slash").font(.footnote).foregroundStyle(Palette.orange)
                }
                Text("楽しい時間に、ちいさな余白を。")
                    .font(.footnote).foregroundStyle(Palette.secondary).frame(maxWidth:.infinity).padding(.vertical,6)
            }.padding(.horizontal,22).padding(.bottom,24)
        }.background(Palette.canvas).toolbar(.hidden,for:.navigationBar)
    }
    private var idle: some View {
        Group {
            VStack(alignment:.leading,spacing:8) {
                Text("楽しい夜に、\nひといきの余白を。").font(.system(size:34,weight:.bold,design:.rounded)).lineSpacing(4).fixedSize(horizontal:false,vertical:true)
                Text("お水と、時間と、いまの気持ち。\nしずくの「ぽた」がそっと見守ります。")
                    .font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(5)
            }
            ZStack {
                RoundedRectangle(cornerRadius:38).fill(Palette.mint)
                Circle().fill(Palette.card.opacity(0.45)).frame(width:190,height:190).offset(x:35,y:5)
                Image(systemName:"sparkle").font(.title2).foregroundStyle(Palette.forest.opacity(0.45)).offset(x:-105,y:-68)
                Image(systemName:"leaf").font(.title2).rotationEffect(.degrees(-25)).foregroundStyle(Palette.forest.opacity(0.45)).offset(x:112,y:64)
                PotaView().frame(width:205,height:205).offset(y:8)
                Text("いっしょに、ゆっくりね。")
                    .font(.caption.weight(.semibold)).padding(.horizontal,14).padding(.vertical,9).background(Palette.card,in:Capsule()).offset(x:65,y:-80)
            }.frame(height:250).accessibilityElement(children:.ignore).accessibilityLabel("しずくのぽた。いっしょに、ゆっくりね。")
            Button { sheet = .start } label: { Label("飲み会をはじめる",systemImage:"play.fill") }.buttonStyle(FilledButton()).accessibilityIdentifier("startSession")
            HStack(alignment:.top,spacing:14) {
                Image(systemName:"bell.badge").font(.title3).padding(13).background(Palette.peach,in:RoundedRectangle(cornerRadius:16))
                VStack(alignment:.leading,spacing:5) {
                    Text("1時間ごとに、ひといき。").font(.subheadline.bold())
                    Text("通知をきっかけにお水を飲んで、帰る予定も思い出そう。間隔は変更できます。")
                        .font(.footnote).foregroundStyle(Palette.secondary).lineSpacing(3)
                }
            }
            let recent = store.archive.sessions.filter { !$0.isActive && $0.startedAt > Calendar.current.date(byAdding:.day,value:-7,to:Date())! }
            if !recent.isEmpty {
                SoftCard {
                    VStack(alignment:.leading,spacing:18) {
                        SectionCaption(overline:"THIS WEEK",title:"この7日間のひといき")
                        HStack {
                            Metric(value:"\(recent.count)回",label:"飲み会の記録",symbol:"moon.stars")
                            Metric(value:"\(recent.reduce(0) { $0 + $1.waterCount })回",label:"お水の記録",symbol:"drop")
                        }
                    }
                }
            }
        }
    }
    private func active(_ session: DrinkingSession) -> some View {
        Group {
            TimelineView(.periodic(from:.now,by:1)) { timeline in
                VStack(alignment:.leading,spacing:18) {
                    HStack(alignment:.top) {
                        VStack(alignment:.leading,spacing:7) {
                            Text("楽しい時間にも、\nひと呼吸。").font(.system(.title,design:.rounded,weight:.bold))
                            Text("\(session.startedAt.formatted(date:.omitted,time:.shortened)) から見守っています")
                                .font(.caption).foregroundStyle(Palette.secondary)
                        }
                        Spacer(minLength:4)
                        PotaView().frame(width:95,height:105).accessibilityHidden(true)
                    }
                    VStack(alignment:.leading,spacing:8) {
                        Text("はじめてから").font(.caption.weight(.semibold)).foregroundStyle(Palette.secondary)
                        Text(TimeText.clock(session.elapsed(at:timeline.date)))
                            .font(.system(size:48,weight:.semibold,design:.rounded)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1).accessibilityIdentifier("elapsedTime")
                        HStack(spacing:8) {
                            Image(systemName:"moon")
                            Text(timeline.date >= session.plannedEnd ? "そろそろ帰る予定の時間だよ" : "\(session.plannedEnd.formatted(date:.omitted,time:.shortened)) におひらき予定")
                        }.font(.subheadline.weight(.medium)).foregroundStyle(timeline.date >= session.plannedEnd ? Palette.orange : Palette.forest)
                    }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(Palette.mint,in:RoundedRectangle(cornerRadius:28))
                    if store.archive.preferences.remindersEnabled && reminders.permission == .authorized {
                        Label("次の声かけ \(session.nextReminder(after:timeline.date).formatted(date:.omitted,time:.shortened))",systemImage:"bell").font(.caption).foregroundStyle(Palette.secondary)
                    }
                }
            }
            if reminders.permission == .denied || !store.archive.preferences.remindersEnabled {
                Label("通知はお休み中です。ときどきアプリで時間を確かめてね。",systemImage:"bell.slash").font(.footnote).foregroundStyle(Palette.orange)
            }
            HStack(spacing:12) {
                quickAction(title:"お水を飲んだ",count:session.waterCount,symbol:"drop.fill",color:Palette.mint,action:onWater).accessibilityIdentifier("addWater")
                quickAction(title:"お酒を記録",count:session.drinkCount,symbol:"wineglass.fill",color:Palette.peach) { sheet = .drink }.accessibilityIdentifier("addDrink")
            }
            if let goal = session.drinkGoal, session.drinkCount >= goal {
                Label("自分で決めた\(goal)杯になりました。次はお水にしようか。",systemImage:"leaf.fill").font(.subheadline).foregroundStyle(Palette.orange)
            }
            SoftCard {
                VStack(alignment:.leading,spacing:15) {
                    HStack { SectionCaption(overline:"TAKE A BREATH",title:"いまの自分に、気づく時間。") }
                    Text("かんたんな遊びや写真で、ちょっとだけ気分を切り替えよう。")
                        .font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(4)
                    Button { sheet = .checkIn } label: { Label("ひといきチェック",systemImage:"leaf") }.buttonStyle(FilledButton(secondary:true)).accessibilityIdentifier("openCheckIn")
                    if let last = session.entries.last(where:{ $0.kind == .checkIn }) {
                        Text("前のひといき \(last.date.formatted(date:.omitted,time:.shortened))").font(.caption).foregroundStyle(Palette.secondary)
                    }
                }
            }
            Button { sheet = .finish } label: {
                Label("今日はここまで・飲み会を終了",systemImage:"moon.zzz").font(.subheadline.bold()).frame(maxWidth:.infinity).padding(.vertical,16)
            }.accessibilityIdentifier("finishSession")
        }
    }
    private func quickAction(title: String,count: Int,symbol: String,color: Color,action: @escaping ()->Void) -> some View {
        Button(action:action) {
            VStack(alignment:.leading,spacing:12) {
                HStack { Image(systemName:symbol).font(.title2); Spacer(); Image(systemName:"plus.circle.fill").font(.title3) }
                Text(title).font(.subheadline.bold())
                Text("\(count) 回の記録").font(.caption).foregroundStyle(Palette.secondary).accessibilityIdentifier(symbol == "drop.fill" ? "waterCount" : "drinkCount")
            }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(color,in:RoundedRectangle(cornerRadius:25))
        }.buttonStyle(.plain)
    }
}
