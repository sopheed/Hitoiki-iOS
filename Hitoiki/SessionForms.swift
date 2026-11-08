import SwiftUI
import PhotosUI
import UIKit

struct StartView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var reminders: ReminderCenter
    @Environment(\.dismiss) private var dismiss
    @State private var hours = 2
    @State private var reminder = 60
    @State private var occasion: DrinkingOccasion?
    @State private var usePlannedEnd = false
    @State private var useGoal = false
    @State private var goal = 3
    @State private var starting = false
    var body: some View {
        Form {
            Section {
                HStack(spacing:18) {
                    ShuriView().frame(width:90,height:96).accessibilityHidden(true)
                    VStack(alignment:.leading,spacing:7) {
                        Text("どんな時間を過ごす？").font(.headline)
                        Text("今日はどんな飲み会かな？\nしゅりに教えてね。")
                            .font(.subheadline).foregroundStyle(Palette.secondary)
                    }
                }.listRowBackground(Color.clear)
            }
            Section {
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:9) {
                    ForEach(DrinkingOccasion.allCases) { option in
                        let selected = occasion == option
                        Button { occasion = selected ? nil : option } label: {
                            Label(option.rawValue,systemImage:option.symbol)
                                .font(.caption.weight(.medium)).frame(maxWidth:.infinity,minHeight:46)
                                .background(selected ? Palette.mint : Palette.card,in:RoundedRectangle(cornerRadius:14))
                                .overlay { RoundedRectangle(cornerRadius:14).stroke(selected ? Palette.forest : .clear,lineWidth:1.5) }
                        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("occasion_\(option.id)")
                    }
                }.padding(.vertical,5)
            } header: { Text("今日はどんな飲み会？（選ばなくてもOK）") } footer: {
                Text("忘年会、ひとり飲み、デートなど。選んだ内容は記録帳に残ります。")
            }
            Section {
                Toggle("おひらきの時間も決める（任意）",isOn:$usePlannedEnd)
                if usePlannedEnd {
                    Stepper("あと\(hours)時間くらい",value:$hours,in:1...6)
                    Label(Date().addingTimeInterval(Double(hours)*3600).formatted(date:.omitted,time:.shortened) + " ごろ",systemImage:"moon.stars")
                        .foregroundStyle(Palette.secondary)
                }
            } header: { Text("時間の目安") } footer: {
                Text("時間を決めずに始めても大丈夫。必要なら通知でおひらきの時刻をお知らせします。いつでも自分のタイミングで終了できます。")
            }
            Section("しゅりが声をかける間隔") {
                Picker("通知の間隔",selection:$reminder) {
                    Text("30分").tag(30); Text("1時間").tag(60); Text("90分").tag(90)
                }.pickerStyle(.segmented)
                Text("お水や、ひといきの時間を思い出す通知です。おひらき時刻も決めた場合は、その時間にもお知らせします。")
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
                        if store.start(hours:usePlannedEnd ? hours : nil,reminder:reminder,goal:useGoal ? goal : nil,occasion:occasion) { dismiss() }
                        starting = false
                    }
                } label: { Text(starting ? "準備しています…" : "しゅりと、はじめる").frame(maxWidth:.infinity) }
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
    @State private var detailsEnabled = false
    @State private var mood: DrinkMood?
    @State private var note = ""
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var loadingPhoto = false
    @State private var saving = false
    var completed: (UUID)->Void
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                Text("飲んだら、種類をひとつ選んでね。")
                    .font(.subheadline).foregroundStyle(Palette.secondary)
                Text("記録するたびに、しゅりの様子が変わります。量や酔いの程度を測るものではありません。")
                    .font(.caption).foregroundStyle(Palette.secondary)
                Toggle("写真・気分・メモも残す（任意）",isOn:$detailsEnabled)
                    .tint(Palette.forest)
                    .padding(16).background(Palette.card,in:RoundedRectangle(cornerRadius:18))
                if detailsEnabled {
                    VStack(alignment:.leading,spacing:12) {
                        Text("今の気分").font(.subheadline.bold())
                        LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:9) {
                            ForEach(DrinkMood.allCases) { item in
                                Button { mood = mood == item ? nil : item } label: {
                                    Text(item.rawValue).font(.caption.weight(.medium)).frame(maxWidth:.infinity).padding(.vertical,12)
                                        .background(mood == item ? Palette.mint : Palette.card,in:RoundedRectangle(cornerRadius:14))
                                        .overlay { RoundedRectangle(cornerRadius:14).stroke(mood == item ? Palette.forest : .clear,lineWidth:1.5) }
                                }.buttonStyle(.plain).accessibilityAddTraits(mood == item ? .isSelected : [])
                            }
                        }
                        TextField("ひとことメモ（任意）",text:$note,axis:.vertical).lineLimit(2...4)
                            .padding(14).background(Palette.card,in:RoundedRectangle(cornerRadius:16))
                        if let image {
                            Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:180).clipShape(RoundedRectangle(cornerRadius:16))
                            Button("写真を外す",role:.destructive) { self.image = nil; pickedPhoto = nil }.font(.caption)
                        }
                        PhotosPicker(selection:$pickedPhoto,matching:.images) {
                            Label(loadingPhoto ? "読み込み中…" : (image == nil ? "写真を選ぶ" : "写真を選び直す"),systemImage:"photo")
                        }.disabled(loadingPhoto)
                    }.padding(16).background(Palette.mint.opacity(0.55),in:RoundedRectangle(cornerRadius:20))
                }
                Text("何を飲んだかを1回ずつ残せます。杯数は記録回数で、飲み物の量や濃さは換算しません。")
                    .font(.caption).foregroundStyle(Palette.secondary)
                ForEach(DrinkKind.allCases) { kind in
                    Button { save(kind) } label: {
                        HStack(spacing:14) {
                            Image(systemName:kind.symbol).font(.title3).foregroundStyle(Palette.forest).frame(width:44,height:44).background(Palette.mint,in:RoundedRectangle(cornerRadius:14))
                            Text(kind.rawValue).font(.headline)
                            Spacer()
                            Image(systemName:detailsEnabled ? "arrow.right.circle.fill" : "plus.circle.fill").font(.title3).foregroundStyle(Palette.forest)
                        }.padding(15).background(Palette.card,in:RoundedRectangle(cornerRadius:20))
                    }.buttonStyle(.plain).disabled(saving || loadingPhoto).accessibilityIdentifier("drink_\(kind.id)")
                }
            }
            .padding(22)
        }.background(Palette.canvas)
            .navigationTitle("お酒の記録").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("閉じる") { dismiss() } } }
            .onChange(of:pickedPhoto) { _, item in
                Task { @MainActor in
                    loadingPhoto = true
                    defer { loadingPhoto = false }
                    do {
                        guard let data = try await item?.loadTransferable(type:Data.self), let loaded = UIImage(data:data) else { return }
                        image = loaded
                    } catch { store.errorMessage = "写真を読み込めませんでした。もう一度お試しください。" }
                }
            }
            .interactiveDismissDisabled(saving)
    }

    private func save(_ kind: DrinkKind) {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        var photoName: String?
        do {
            if detailsEnabled, let image { photoName = try store.savePhoto(image) }
            let id = UUID()
            let saved = store.add(kind:.drink,detail:kind.rawValue,photo:photoName,mood:detailsEnabled ? mood?.rawValue : nil,note:detailsEnabled && !note.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? note : nil,id:id)
            if saved { completed(id); dismiss() }
            else if let photoName { store.removePhoto(photoName) }
        } catch { store.errorMessage = "写真を保存できませんでした。\(error.localizedDescription)" }
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
                ShuriView(resting:true).frame(width:170,height:170).padding(.top,12)
                VStack(spacing:9) {
                    Label("いい区切りだね",systemImage:"checkmark.seal.fill").font(.caption.bold()).foregroundStyle(Palette.forest)
                    Text("おひらきにできたね。").font(.system(.title2,design:.rounded,weight:.bold))
                    Text("飲み会を気持ちよく終えるのも、\n明日の自分を大切にする選択だよ。")
                        .font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center).lineSpacing(4)
                }
                if let s = store.active {
                    SoftCard {
                        VStack(alignment:.leading,spacing:15) {
                            if let occasion = s.occasion { Label(occasion.rawValue,systemImage:occasion.symbol).font(.subheadline.bold()).foregroundStyle(Palette.forest) }
                            HStack(spacing:7) {
                                Metric(value:TimeText.duration(s.elapsed()),label:"過ごした時間",symbol:"clock")
                                Metric(value:"\(s.drinkCount)回",label:"お酒の記録",symbol:"wineglass")
                                Metric(value:"\(s.waterCount)回",label:"お水の記録",symbol:"drop")
                            }
                        }
                    }
                }
                VStack(alignment:.leading,spacing:10) {
                    Text("明日の自分へ、ひとこと（任意）").font(.subheadline.bold())
                    TextField("楽しかったこと、今日ここで終えたこと",text:$note,axis:.vertical)
                        .lineLimit(3...6).padding(18).background(Palette.card,in:RoundedRectangle(cornerRadius:20))
                        .accessibilityIdentifier("finishNote")
                }
                Button {
                    if store.end(note:note) { completed(); dismiss() }
                } label: { Label("おひらきにして、記録する",systemImage:"checkmark.seal.fill").frame(maxWidth:.infinity) }
                    .buttonStyle(FilledButton()).accessibilityIdentifier("confirmFinish")
                Text("記録はあとから、しゅりと一緒に振り返れます。")
                    .font(.caption).foregroundStyle(Palette.secondary)
                Text("飲酒後は運転せず、公共交通機関やタクシーなどで帰ろう。")
                    .font(.footnote).foregroundStyle(Palette.secondary)
            }.padding(24)
        }.background(Palette.canvas).navigationTitle("いい区切りを").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("飲み会に戻る") { dismiss() } } }
    }
}
