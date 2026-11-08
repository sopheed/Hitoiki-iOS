import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = String(data:configuration.file.regularFileContents ?? Data(),encoding:.utf8) ?? "" }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents:Data(text.utf8)) }
}

struct HistoryView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var query = ""
    @State private var export = false
    private var sessions: [DrinkingSession] {
        store.archive.sessions.filter { !$0.isActive && (query.isEmpty || $0.note.localizedCaseInsensitiveContains(query) || $0.startedAt.formatted(date:.abbreviated,time:.omitted).localizedCaseInsensitiveContains(query) || ($0.occasion?.rawValue.localizedCaseInsensitiveContains(query) ?? false) || $0.entries.contains { $0.detail.localizedCaseInsensitiveContains(query) || ($0.note?.localizedCaseInsensitiveContains(query) ?? false) || ($0.mood?.localizedCaseInsensitiveContains(query) ?? false) }) }.sorted { $0.startedAt > $1.startedAt }
    }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                SectionCaption(overline:"LITTLE MOMENTS",title:"自分のペースを、見つけよう。")
                Text("できたひといきを振り返って、\n次の楽しい時間につなげよう。")
                    .font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(4)
                if sessions.isEmpty {
                    VStack(spacing:16) {
                        ShuriView(resting:true).frame(width:130,height:130)
                        Text(query.isEmpty ? "まだ、まっさらな記録帳。" : "見つかりませんでした").font(.headline)
                        Text(query.isEmpty ? "飲み会が終わると、ここに記録が並びます。" : "日付やメモの言葉を変えて探してみてね。")
                            .font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth:.infinity).padding(.vertical,30)
                } else {
                    ForEach(sessions) { session in
                        NavigationLink { SessionDetailView(sessionID:session.id) } label: { SessionRow(session:session) }.buttonStyle(.plain).accessibilityIdentifier("history_\(session.id)")
                    }
                }
            }.padding(22)
        }.background(Palette.canvas).navigationTitle("きろく")
        .searchable(text:$query,prompt:"日付・シチュエーション・メモで検索")
        .toolbar { ToolbarItem(placement:.topBarTrailing) {
            Button { export = true } label: { Image(systemName:"square.and.arrow.up") }.accessibilityLabel("記録をCSVで書き出す").disabled(store.archive.sessions.allSatisfy(\.isActive))
        } }
        .fileExporter(isPresented:$export,document:CSVDocument(text:CSVExport.make(store.archive.sessions)),contentType:.commaSeparatedText,defaultFilename:"ひといきの記録") { result in
            if case .failure(let error) = result { store.errorMessage = "書き出せませんでした。\(error.localizedDescription)" }
        }
    }
}

struct SessionRow: View {
    var session: DrinkingSession
    var body: some View {
        SoftCard {
            VStack(alignment:.leading,spacing:16) {
                HStack(spacing:12) {
                    ShuriView(drinkCount:session.drinkCount).frame(width:48,height:50).accessibilityHidden(true)
                    VStack(alignment:.leading,spacing:3) {
                        Text(session.startedAt.formatted(.dateTime.month(.wide).day().weekday(.abbreviated))).font(.headline)
                        Text("しゅりと振り返る").font(.caption).foregroundStyle(Palette.secondary)
                    }
                    Spacer(); Image(systemName:"chevron.right").font(.caption.bold()).foregroundStyle(Palette.secondary)
                }
                HStack(spacing:16) {
                    Label(TimeText.duration(session.elapsed()),systemImage:"clock")
                    Label("\(session.waterCount)回",systemImage:"drop.fill")
                    Label("\(session.drinkCount)回",systemImage:"wineglass")
                }.font(.caption).foregroundStyle(Palette.secondary)
                if let occasion = session.occasion {
                    Label(occasion.rawValue,systemImage:occasion.symbol).font(.caption.weight(.medium)).foregroundStyle(Palette.forest)
                }
                if session.drinkCount > 0 {
                    Text(drinkSummary).font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
                }
                if !session.note.isEmpty { Text(session.note).font(.subheadline).lineLimit(2).foregroundStyle(Palette.secondary) }
            }
        }
    }
    private var drinkSummary: String {
        let counts = Dictionary(grouping:session.entries.filter { $0.kind == .drink },by:\.detail).map { "\($0.key) \($0.value.count)" }.sorted()
        return counts.joined(separator:"・")
    }
}

struct SessionDetailView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    var sessionID: UUID
    @State private var deleting = false
    @State private var editing = false
    @State private var note = ""
    private var session: DrinkingSession? { store.archive.sessions.first { $0.id == sessionID } }
    var body: some View {
        ScrollView {
            if let s = session {
                VStack(alignment:.leading,spacing:24) {
                    SectionCaption(overline:s.startedAt.formatted(.dateTime.year().month().day()),title:"\(s.startedAt.formatted(date:.omitted,time:.shortened)) 〜 \(s.endedAt?.formatted(date:.omitted,time:.shortened) ?? "")")
                    if let occasion = s.occasion {
                        Label(occasion.rawValue,systemImage:occasion.symbol).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.forest)
                    }
                    SoftCard { HStack {
                        Metric(value:TimeText.duration(s.elapsed()),label:"過ごした時間",symbol:"clock")
                        Metric(value:"\(s.waterCount)回",label:"お水の記録",symbol:"drop")
                        Metric(value:"\(s.drinkCount)回",label:"飲んだ記録",symbol:"wineglass")
                    } }
                    Text("回数は記録した杯の数です。量やアルコール濃度は換算していません。")
                        .font(.caption).foregroundStyle(Palette.secondary)
                    ShuriRecapSection(session:s)
                    SoftCard {
                        VStack(alignment:.leading,spacing:12) {
                            HStack { Text("ひとことメモ").font(.headline); Spacer(); Button("編集") { note = s.note; editing = true } }
                            Text(s.note.isEmpty ? "メモを残して、次の自分へ。" : s.note).font(.subheadline).foregroundStyle(Palette.secondary)
                        }
                    }
                    SectionCaption(overline:"TIMELINE",title:"この日のひといき")
                    if s.entries.isEmpty { Text("この日は時間だけを記録しました。").font(.subheadline).foregroundStyle(Palette.secondary) }
                    ForEach(s.entries.sorted { $0.date < $1.date }) { entry in
                        HStack(alignment:.top,spacing:16) {
                            Image(systemName:entry.kind.symbol).foregroundStyle(Palette.forest).frame(width:38,height:38).background(Palette.mint,in:Circle())
                            VStack(alignment:.leading,spacing:8) {
                                Text(entry.detail).font(.subheadline.weight(.medium))
                                Text(entry.date.formatted(date:.omitted,time:.shortened)).font(.caption).foregroundStyle(Palette.secondary)
                                if let mood = entry.mood { Text("気分：\(mood)").font(.caption).foregroundStyle(Palette.forest) }
                                if let note = entry.note, !note.isEmpty { Text(note).font(.subheadline).foregroundStyle(Palette.secondary) }
                                if let name = entry.photoName, let url = store.photoURL(name), let image = UIImage(contentsOfFile:url.path) {
                                    Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:220).clipShape(RoundedRectangle(cornerRadius:18)).accessibilityLabel(entry.kind == .drink ? "飲んだものの写真" : "チェックで記録した写真")
                                }
                            }
                            Spacer(minLength:0)
                        }
                    }
                    Text("チェック \(s.checkInCount)回。自分に気づく時間を残せたね。")
                        .font(.footnote).foregroundStyle(Palette.secondary).padding(.top,8)
                }.padding(22)
            }
        }.background(Palette.canvas).navigationTitle("飲み会の記録").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement:.topBarTrailing) { Button(role:.destructive) { deleting = true } label: { Image(systemName:"trash") }.accessibilityLabel("この記録を削除") } }
        .confirmationDialog("この記録を削除しますか？",isPresented:$deleting,titleVisibility:.visible) {
            Button("記録と写真を削除",role:.destructive) { if let session, store.delete(session) { dismiss() } }
        } message: { Text("この飲み会の記録と写真を削除します。取り消せません。") }
        .sheet(isPresented:$editing) {
            NavigationStack {
                Form { TextField("ひとことメモ",text:$note,axis:.vertical).lineLimit(5...12) }
                    .navigationTitle("メモを編集").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement:.cancellationAction) { Button("キャンセル") { editing = false } }
                        ToolbarItem(placement:.confirmationAction) { Button("保存") {
                            if store.transact({ archive in if let index = archive.sessions.firstIndex(where:{ $0.id == sessionID }) { archive.sessions[index].note = String(note.prefix(2000)) } }) { editing = false }
                        } }
                    }
            }
        }
    }
}

private struct ShuriRecapSection: View {
    var session: DrinkingSession
    @State private var shareImage: UIImage?
    @State private var sharing = false

    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            SectionCaption(overline:"A LITTLE RECAP",title:"しゅりと、あの日を振り返る。")
            ShuriRecapCard(session:session)
            Text("カードには日付・飲み物の種類と回数・お水の回数・過ごした時間を表示します。シチュエーション・写真・気分・メモは含みません。")
                .font(.caption).foregroundStyle(Palette.secondary).lineSpacing(3)
            Button(action:prepareShare) {
                Label("このカードを保存・共有",systemImage:"square.and.arrow.up")
                    .frame(maxWidth:.infinity).padding(.vertical,15)
            }.buttonStyle(FilledButton(secondary:true))
        }
        .sheet(isPresented:$sharing) {
            if let shareImage { ShareActivitySheet(items:[shareImage]) }
        }
    }

    private func prepareShare() {
        let renderer = ImageRenderer(content:ShuriRecapCard(session:session))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }
        shareImage = image
        sharing = true
    }
}

private struct ShuriRecapCard: View {
    var session: DrinkingSession
    private var drinks: String {
        let counts = Dictionary(grouping:session.entries.filter { $0.kind == .drink },by:\.detail)
            .map { "\($0.key) \($0.value.count)" }.sorted()
        return counts.isEmpty ? "飲んだ種類の記録なし" : counts.joined(separator:" ・ ")
    }
    var body: some View {
        VStack(spacing:12) {
            Text("HITOIKI").font(.caption2.weight(.heavy)).tracking(3).foregroundStyle(Palette.forest)
            Text("あの日のひといき").font(.system(.title3,design:.rounded,weight:.bold))
            ShuriView(resting:true,drinkCount:session.drinkCount).frame(width:120,height:125)
            Text(session.startedAt.formatted(.dateTime.year().month(.wide).day().weekday(.wide)))
                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondary)
            Text("お酒の記録 \(session.drinkCount)回")
                .font(.system(.title2,design:.rounded,weight:.bold)).foregroundStyle(Palette.forest)
            Text(drinks).font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
            HStack(spacing:24) {
                Label("お水 \(session.waterCount)回",systemImage:"drop.fill")
                Label("\(TimeText.duration(session.elapsed()))",systemImage:"clock")
            }.font(.caption).foregroundStyle(Palette.secondary)
            Text("今日も、自分のペースで。").font(.subheadline.bold()).foregroundStyle(Palette.forest).padding(.top,4)
        }
        .padding(22).frame(width:320,height:410)
        .background(Palette.mint,in:RoundedRectangle(cornerRadius:30))
        .overlay { RoundedRectangle(cornerRadius:30).stroke(Palette.forest.opacity(0.12),lineWidth:1) }
        .accessibilityElement(children:.combine)
    }
}

private struct ShareActivitySheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context:Context) -> UIActivityViewController {
        UIActivityViewController(activityItems:items,applicationActivities:nil)
    }
    func updateUIViewController(_ controller:UIActivityViewController,context:Context) {}
}
