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
                    ShuriView(resting:true).frame(width:150,height:150)
                    Text("記録を大切に保管しています").font(.title2.bold())
                    Text("データを読み込めませんでした。元のファイルは残しています。空き容量を確認して再試行してください。").multilineTextAlignment(.center)
                    Button("もう一度読み込む") { store.reload() }.buttonStyle(FilledButton())
                }.padding(28)
            } else {
                TabView(selection:$tab) {
                    NavigationStack {
                        HomeView(sheet:$sheet,onWater:recordWater)
                            .safeAreaInset(edge:.bottom,spacing:0) {
                                AdBannerPlacement(isVisible:sheet == nil && toast == nil)
                            }
                    }.tabItem { Label("いま",systemImage:"drop.fill") }.tag(0)
                    NavigationStack {
                        HistoryView()
                            .safeAreaInset(edge:.bottom,spacing:0) {
                                AdBannerPlacement(isVisible:sheet == nil && toast == nil)
                            }
                    }.tabItem { Label("きろく",systemImage:"book.closed.fill") }.tag(1)
                    NavigationStack { SettingsView() }.tabItem { Label("せってい",systemImage:"slider.horizontal.3") }.tag(2)
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .sheet(item:$sheet) { selection in
            NavigationStack {
                switch selection {
                case .start: StartView()
                case .drink: DrinkView { id in showToast("しゅりに伝えたよ", undo: id) }
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
                    Label(store.active == nil ? "あなたのペースで" : "しゅりが見守り中",systemImage:store.active == nil ? "leaf" : "circle.inset.filled")
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
                Text("お水と、時間と、いまの気持ち。\nしずくの相棒「しゅり」と一緒に。")
                    .font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(5)
            }
            ZStack {
                RoundedRectangle(cornerRadius:38).fill(Palette.mint)
                Circle().fill(Palette.card.opacity(0.45)).frame(width:190,height:190).offset(x:35,y:5)
                Image(systemName:"sparkle").font(.title2).foregroundStyle(Palette.forest.opacity(0.45)).offset(x:-105,y:-68)
                Image(systemName:"leaf").font(.title2).rotationEffect(.degrees(-25)).foregroundStyle(Palette.forest.opacity(0.45)).offset(x:112,y:64)
                ShuriView().frame(width:205,height:205).offset(y:8)
                Text("いっしょに、ゆっくりね。")
                    .font(.caption.weight(.semibold)).padding(.horizontal,14).padding(.vertical,9).background(Palette.card,in:Capsule()).offset(x:65,y:-80)
            }.frame(height:250).accessibilityElement(children:.ignore).accessibilityLabel("しずくのしゅり。いっしょに、ゆっくりね。")
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
            ShuriCompanionStage(session:session)
            Button { sheet = .finish } label: {
                HStack(spacing:14) {
                    Image(systemName:"moon.stars.fill").font(.title2).frame(width:48,height:48)
                        .background(.white.opacity(0.16),in:RoundedRectangle(cornerRadius:15))
                    VStack(alignment:.leading,spacing:3) {
                        Text("おひらきにする").font(.headline)
                        Text("ここで区切るのも、いい選択").font(.caption).foregroundStyle(.white.opacity(0.82))
                    }
                    Spacer()
                    Image(systemName:"arrow.right").font(.subheadline.bold())
                }.foregroundStyle(.white).padding(16).frame(maxWidth:.infinity,alignment:.leading)
                    .background(Color(red:0.17,green:0.39,blue:0.32),in:RoundedRectangle(cornerRadius:24))
            }.buttonStyle(.plain).accessibilityIdentifier("finishSession")
            TimelineView(.periodic(from:.now,by:1)) { timeline in
                VStack(alignment:.leading,spacing:18) {
                    VStack(alignment:.leading,spacing:8) {
                        Text("はじめてから").font(.caption.weight(.semibold)).foregroundStyle(Palette.secondary)
                        Text(TimeText.clock(session.elapsed(at:timeline.date)))
                            .font(.system(size:48,weight:.semibold,design:.rounded)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1).accessibilityIdentifier("elapsedTime")
                        if let plannedEnd = session.plannedEnd {
                            HStack(spacing:8) {
                                Image(systemName:"moon")
                                Text(timeline.date >= plannedEnd ? "おひらきの目安の時間だよ" : "\(plannedEnd.formatted(date:.omitted,time:.shortened)) ごろがおひらき目安")
                            }.font(.subheadline.weight(.medium)).foregroundStyle(timeline.date >= plannedEnd ? Palette.orange : Palette.forest)
                        } else {
                            Label("おひらき時間は未設定。いつでも区切れます。",systemImage:"moon")
                                .font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
                        }
                    }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(Palette.mint,in:RoundedRectangle(cornerRadius:28))
                    if store.archive.preferences.remindersEnabled && reminders.permission == .authorized {
                        Label("次の声かけ \(session.nextReminder(after:timeline.date).formatted(date:.omitted,time:.shortened))",systemImage:"bell").font(.caption).foregroundStyle(Palette.secondary)
                    }
                }
            }
            Text("記録した回数は目安のメモです。量や度数、酔い具合を判定するものではありません。")
                .font(.caption).foregroundStyle(Palette.secondary).lineSpacing(3)
            if reminders.permission == .denied || !store.archive.preferences.remindersEnabled {
                Label("通知はお休み中です。ときどきアプリで時間を確かめてね。",systemImage:"bell.slash").font(.footnote).foregroundStyle(Palette.orange)
            }
            Button { sheet = .drink } label: {
                HStack(spacing:16) {
                    Image(systemName:"wineglass.fill").font(.title2).frame(width:48,height:48).background(.white.opacity(0.45),in:RoundedRectangle(cornerRadius:16))
                    VStack(alignment:.leading,spacing:4) {
                        Text("飲んだら、1杯分を記録").font(.headline)
                        Text("飲みものの種類を選びます · \(session.drinkCount)回記録").font(.caption).foregroundStyle(Palette.secondary)
                    }
                    Spacer(minLength:0)
                    Image(systemName:"plus.circle.fill").font(.title2)
                }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Palette.peach,in:RoundedRectangle(cornerRadius:26))
            }.buttonStyle(.plain).accessibilityIdentifier("addDrink")
            Button(action:onWater) {
                Label("お水を飲んだ",systemImage:"drop.fill")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth:.infinity).padding(.vertical,15)
                    .background(Palette.mint,in:RoundedRectangle(cornerRadius:20))
                    .overlay(alignment:.trailing) { Text("\(session.waterCount)回").font(.caption).foregroundStyle(Palette.secondary).padding(.trailing,18) }
            }.buttonStyle(.plain).accessibilityIdentifier("addWater")
            if let goal = session.drinkGoal, session.drinkCount >= goal {
                Label("自分で決めた\(goal)回の目安に達しました。ひとやすみしよう。",systemImage:"leaf.fill").font(.subheadline).foregroundStyle(Palette.orange)
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
        }
    }
}

private struct ShuriCompanionStage: View {
    var session: DrinkingSession
    private var latestDrink: SessionEntry? { session.entries.last { $0.kind == .drink } }
    private var headline: String {
        switch session.drinkCount {
        case 0: return "こんばんは、しゅりだよ。"
        case 1: return "記録ありがとう。"
        case 2: return "しゅりと、ひとやすみ。"
        default: return "今日はここで、ひといき。"
        }
    }
    private var message: String {
            guard let latestDrink else {
            if let occasion = session.occasion { return "\(occasion.rawValue)なんだね。帰りたい時間を大切に、あなたのペースで過ごそう。" }
            return "帰りたい時間を大切に、あなたのペースで過ごそう。"
        }
        if session.drinkCount >= 3 { return "\(latestDrink.detail)を記録したね。これ以上は飲まずに休もう。近くの人にも声をかけてね。" }
        if session.drinkCount == 2 { return "\(latestDrink.detail)を記録したね。次はお水を飲んで、少し座ろう。" }
        return "\(latestDrink.detail)を記録したね。次の一杯の前に、お水や休憩もどう？"
    }
    var body: some View {
        VStack(spacing:8) {
            HStack {
                Label(session.occasion?.rawValue ?? "今日のひといき",systemImage:session.occasion?.symbol ?? "sparkle")
                    .font(.caption2.weight(.heavy)).lineLimit(1)
                Spacer()
                Text("\(session.drinkCount)回記録").font(.caption.weight(.semibold))
            }.foregroundStyle(Palette.forest)
            ShuriView(drinkCount:session.drinkCount).frame(width:170,height:170).accessibilityHidden(true)
                .padding(.vertical,2)
            Text(headline).font(.system(.title3,design:.rounded,weight:.bold)).multilineTextAlignment(.center)
            Text(message).font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center).lineSpacing(4)
                .frame(maxWidth:.infinity).padding(.horizontal,17).padding(.vertical,13)
                .background(Palette.card,in:RoundedRectangle(cornerRadius:18))
            Text("しゅりの表情は記録回数に合わせた演出です。酔い具合の判定ではありません。")
                .font(.caption2).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
        }
        .padding(18).frame(maxWidth:.infinity)
        .background(Palette.mint,in:RoundedRectangle(cornerRadius:30))
        .accessibilityElement(children:.combine)
    }
}
