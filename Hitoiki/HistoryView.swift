import SwiftUI
import UniformTypeIdentifiers

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
        store.archive.sessions.filter { !$0.isActive && (query.isEmpty || $0.note.localizedCaseInsensitiveContains(query) || $0.startedAt.formatted(date:.abbreviated,time:.omitted).localizedCaseInsensitiveContains(query) || $0.entries.contains { $0.detail.localizedCaseInsensitiveContains(query) }) }.sorted { $0.startedAt > $1.startedAt }
    }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                SectionCaption(overline:"LITTLE MOMENTS",title:"自分のペースを、見つけよう。")
                Text("できたひといきを振り返って、\n次の楽しい時間につなげよう。")
                    .font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(4)
                if sessions.isEmpty {
                    VStack(spacing:16) {
                        PotaView(resting:true).frame(width:130,height:130)
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
        .searchable(text:$query,prompt:"日付・メモ・飲んだもので検索")
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
                HStack {
                    Text(session.startedAt.formatted(.dateTime.month(.wide).day().weekday(.abbreviated))).font(.headline)
                    Spacer(); Image(systemName:"chevron.right").font(.caption.bold()).foregroundStyle(Palette.secondary)
                }
                HStack(spacing:16) {
                    Label(TimeText.duration(session.elapsed()),systemImage:"clock")
                    Label("\(session.waterCount)回",systemImage:"drop.fill")
                    Label("\(session.drinkCount)回",systemImage:"wineglass")
                }.font(.caption).foregroundStyle(Palette.secondary)
                if !session.note.isEmpty { Text(session.note).font(.subheadline).lineLimit(2).foregroundStyle(Palette.secondary) }
            }
        }
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
                    SoftCard { HStack {
                        Metric(value:TimeText.duration(s.elapsed()),label:"過ごした時間",symbol:"clock")
                        Metric(value:"\(s.waterCount)回",label:"お水の記録",symbol:"drop")
                        Metric(value:"\(s.drinkCount)回",label:"お酒の記録",symbol:"wineglass")
                    } }
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
                                if let name = entry.photoName, let url = store.photoURL(name), let image = UIImage(contentsOfFile:url.path) {
                                    Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:220).clipShape(RoundedRectangle(cornerRadius:18)).accessibilityLabel("チェックで記録した写真")
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
