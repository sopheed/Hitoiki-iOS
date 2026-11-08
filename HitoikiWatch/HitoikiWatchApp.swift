import SwiftUI
import WatchKit

@main
struct HitoikiWatchApp: App {
    @StateObject private var store = WatchStore()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            WatchHomeView().environmentObject(store).tint(Color(red:0.62,green:0.86,blue:0.72))
                .onChange(of:phase) { _, value in if value == .active { store.refresh() } }
        }
    }
}
struct WatchHomeView: View {
    @EnvironmentObject private var store: WatchStore
    @State private var confirmEnd = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:14) {
                    if let session = store.session {
                        HStack {
                            VStack(alignment:.leading,spacing:4) {
                                Text("ひといき").font(.headline)
                                Text("しゅりが見守り中").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(); ShuriView().frame(width:48,height:52).accessibilityHidden(true)
                        }
                        Text(session.startedAt,style:.timer).font(.system(size:32,weight:.medium,design:.rounded)).monospacedDigit().frame(maxWidth:.infinity,alignment:.leading)
                        if let plannedEnd = session.plannedEnd {
                            Label("\(plannedEnd.formatted(date:.omitted,time:.shortened)) ごろがおひらき目安",systemImage:"moon").font(.caption2).foregroundStyle(.secondary)
                        } else {
                            Label("おひらき時間は未設定",systemImage:"moon").font(.caption2).foregroundStyle(.secondary)
                        }
                        Button { store.record(.water); WKInterfaceDevice.current().play(.success) } label: {
                            VStack(spacing:5) {
                                Label("お水を飲んだ",systemImage:"drop.fill").font(.headline)
                                Text("\(session.waterCount + store.pendingCount(.water)) 回").font(.caption2)
                            }.frame(maxWidth:.infinity).padding(.vertical,6)
                        }.buttonStyle(.borderedProminent).foregroundStyle(Color(red:0.07,green:0.16,blue:0.13)).disabled(store.ending || store.loadFailed).accessibilityIdentifier("watchWater")
                        Button { store.record(.drink) } label: {
                            Label("お酒を記録  \(session.drinkCount + store.pendingCount(.drink))",systemImage:"wineglass").font(.subheadline)
                        }.disabled(store.ending || store.loadFailed)
                        Button { confirmEnd = true } label: {
                            Label(store.ending ? "おひらきを同期待ち" : "おひらきにする",systemImage:"moon.stars.fill").font(.headline)
                        }.buttonStyle(.borderedProminent).tint(Color(red:0.84,green:0.58,blue:0.39)).disabled(store.ending || store.loadFailed)
                    } else {
                        ShuriView().frame(width:110,height:110)
                        Text("いっしょに、ゆっくりね。").font(.headline).multilineTextAlignment(.center)
                        Text("iPhoneで飲み会をはじめると、ここからお水やお酒を記録できます。")
                            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    if !store.cache.pending.isEmpty {
                        Label("\(store.cache.pending.count)件、iPhoneへ同期待ち",systemImage:"arrow.triangle.2.circlepath").font(.caption2).foregroundStyle(.orange)
                    }
                    if let message = store.message { Text(message).font(.caption2).foregroundStyle(.orange) }
                    if !store.reachable { Text("iPhoneと通信できるときに同期します").font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                    Button("同期する") { store.refresh() }.font(.caption2)
                }.padding(.horizontal,3)
            }.navigationTitle("").containerBackground(Color(red:0.07,green:0.16,blue:0.13).gradient,for:.navigation)
            .confirmationDialog("ここで、おひらきにしますか？",isPresented:$confirmEnd,titleVisibility:.visible) {
                Button("いい区切りにする") { store.record(.end) }
                Button("戻る",role:.cancel) {}
            }
        }
    }
}
