import SwiftUI
import PhotosUI
import UIKit

struct CheckInView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var kind: CheckInKind?
    @State private var solved = false
    @State private var feedback = ""
    @State private var mood = "いい感じ"
    @State private var a = Int.random(in:3...9)
    @State private var b = Int.random(in:2...8)
    @State private var choices: [Int] = []
    @State private var target = Int.random(in:0...8)
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var cameraDenied = false
    @State private var loadingPhoto = false
    @State private var saving = false
    var completed: ()->Void
    private let moods = ["いい感じ", "お水にする", "少し休む", "そろそろ帰る"]

    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                HStack(spacing:16) {
                    PotaView().frame(width:85,height:90).accessibilityHidden(true)
                    VStack(alignment:.leading,spacing:8) {
                        Text("いま、どんな気分？").font(.system(.title2,design:.rounded,weight:.bold))
                        Text("肩の力をぬいて、ひと呼吸。\n好きなチェックをひとつどうぞ。")
                            .font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(3)
                    }
                }
                if kind == nil {
                    ForEach(CheckInKind.allCases) { option in
                        Button {
                            kind = option; solved = false; feedback = ""; choices = [a+b,a+b+2,a+b-1].shuffled()
                        } label: {
                            HStack(spacing:16) {
                                Image(systemName:option.symbol).font(.title2).frame(width:50,height:50).background(Palette.mint,in:RoundedRectangle(cornerRadius:16))
                                VStack(alignment:.leading,spacing:4) {
                                    Text(option.rawValue).font(.headline)
                                    Text(subtitle(option)).font(.caption).foregroundStyle(Palette.secondary)
                                }
                                Spacer(minLength:0); Image(systemName:"chevron.right").font(.caption.bold())
                            }.padding(18).background(Palette.card,in:RoundedRectangle(cornerRadius:24))
                        }.buttonStyle(.plain).accessibilityIdentifier("check_\(option.id)")
                    }
                } else {
                    challenge
                    if !feedback.isEmpty { Text(feedback).font(.subheadline).foregroundStyle(Palette.forest).accessibilityIdentifier("checkFeedback") }
                    if solved {
                        VStack(alignment:.leading,spacing:14) {
                            Label("ひといき、できたね。",systemImage:"checkmark.circle.fill").font(.headline).foregroundStyle(Palette.forest)
                            Text("このあとは、どうしよう？").font(.subheadline.bold())
                            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:10) {
                                ForEach(moods,id:\.self) { item in
                                    Button { mood = item } label: {
                                        Text(item).font(.subheadline.weight(.medium)).frame(maxWidth:.infinity).padding(.vertical,14)
                                            .background(mood == item ? Palette.mint : Palette.card,in:RoundedRectangle(cornerRadius:17))
                                            .overlay { RoundedRectangle(cornerRadius:17).stroke(mood == item ? Palette.forest : .clear,lineWidth:1.5) }
                                    }.buttonStyle(.plain).accessibilityAddTraits(mood == item ? .isSelected : [])
                                }
                            }
                            Button { save() } label: { Text(saving ? "保存しています…" : "今の気持ちを記録") }.buttonStyle(FilledButton()).disabled(saving).accessibilityIdentifier("saveCheckIn")
                        }
                    }
                    Button("ほかのチェックにする") { kind = nil; solved = false; image = nil; pickedPhoto = nil; feedback = "" }.frame(maxWidth:.infinity).font(.subheadline)
                }
                Text("チェックは気持ちを切り替える遊びです。酔いの程度や、運転できるかを判定するものではありません。")
                    .font(.caption).foregroundStyle(Palette.secondary).lineSpacing(4)
            }.padding(24)
        }.background(Palette.canvas).navigationTitle("ひといきチェック").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement:.cancellationAction) { Button("閉じる") { dismiss() }.disabled(saving) } }
        .sheet(isPresented:$showCamera) { CameraCapture(image:$image).ignoresSafeArea() }
        .onChange(of:image) { _, value in if value != nil { solved = true; feedback = "いまの景色を覚えておこう。" } }
        .onChange(of:pickedPhoto) { _, item in
            Task { @MainActor in
                loadingPhoto = true
                defer { loadingPhoto = false }
                do {
                    guard let data = try await item?.loadTransferable(type:Data.self), let decoded = UIImage(data:data) else { feedback = "写真を読み込めませんでした。別の写真を選んでください。"; return }
                    image = decoded
                } catch { feedback = "写真を読み込めませんでした。もう一度お試しください。" }
            }
        }
        .alert("カメラを使えません",isPresented:$cameraDenied) {
            Button("設定を開く") { if let url = URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            Button("閉じる",role:.cancel) {}
        } message: { Text("設定でカメラを許可するか、写真を選ぶ・ほかのチェックを使ってください。") }
        .interactiveDismissDisabled(saving)
    }
    @ViewBuilder private var challenge: some View {
        switch kind {
        case .numbers:
            SoftCard {
                VStack(spacing:22) {
                    Text("ゆっくり、計算してみよう").font(.subheadline).foregroundStyle(Palette.secondary)
                    Text("\(a) + \(b) = ?").font(.system(size:42,weight:.bold,design:.rounded)).minimumScaleFactor(0.6).accessibilityIdentifier("mathQuestion")
                    HStack(spacing:12) {
                        ForEach(choices,id:\.self) { value in
                            Button {
                                if value == a+b { solved = true; feedback = "そうだね。ひと呼吸できたかな？" }
                                else { feedback = "急がなくて大丈夫。もう一度、ゆっくり。" }
                            } label: {
                                Text("\(value)").font(.system(.title2,design:.rounded,weight:.bold)).frame(maxWidth:.infinity).padding(.vertical,18).background(Palette.mint,in:RoundedRectangle(cornerRadius:18))
                            }.buttonStyle(.plain).disabled(solved).accessibilityIdentifier("answer_\(value)")
                        }
                    }
                }.frame(maxWidth:.infinity)
            }
        case .shapes:
            SoftCard {
                VStack(spacing:20) {
                    Label("しずくをひとつ、見つけてね",systemImage:"drop.fill").font(.headline)
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:3),spacing:12) {
                        ForEach(0..<9) { index in
                            Button {
                                if index == target { solved = true; feedback = "見つけたね。お水もひとくち、どう？" }
                                else { feedback = "ゆっくり見てみよう。しずくはどこかな？" }
                            } label: {
                                Image(systemName:index == target ? "drop.fill" : ["leaf.fill","moon.fill","sparkle"][index % 3])
                                    .font(.system(size:30)).frame(maxWidth:.infinity).frame(height:65).background(Palette.mint,in:RoundedRectangle(cornerRadius:18))
                            }.buttonStyle(.plain).disabled(solved).accessibilityLabel(index == target ? "しずく" : "ほかの形").accessibilityIdentifier("shape_\(index == target ? "target" : String(index))")
                        }
                    }
                }
            }
        case .photo:
            VStack(spacing:16) {
                if let image { Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:270).clipShape(RoundedRectangle(cornerRadius:24)) }
                else {
                    Image(systemName:"camera.macro").font(.system(size:54)).foregroundStyle(Palette.forest).frame(maxWidth:.infinity).frame(height:130).background(Palette.mint,in:RoundedRectangle(cornerRadius:24))
                    Text("お水や目の前の景色を一枚。\nまわりの人が写るときは声をかけてね。")
                        .font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { openCamera() } label: { Label("写真を撮る",systemImage:"camera") }.buttonStyle(FilledButton(secondary:true))
                }
                PhotosPicker(selection:$pickedPhoto,matching:.images) { Label(loadingPhoto ? "読み込み中…" : "写真を選ぶ",systemImage:"photo") }.disabled(loadingPhoto)
                Text("写真はこのアプリ内に保存します。外部への送信はありません。")
                    .font(.caption).foregroundStyle(Palette.secondary)
            }
        case nil: EmptyView()
        }
    }
    private func subtitle(_ kind: CheckInKind) -> String {
        switch kind { case .numbers: return "数字にちょっと集中"; case .shapes: return "9つの形からしずくを探す"; case .photo: return "写真でこの瞬間をメモ" }
    }
    private func openCamera() {
        Task { @MainActor in
            let status = AVCaptureDevice.authorizationStatus(for:.video)
            if status == .authorized { showCamera = true }
            else if status == .notDetermined { if await AVCaptureDevice.requestAccess(for:.video) { showCamera = true } else { cameraDenied = true } }
            else { cameraDenied = true }
        }
    }
    private func save() {
        guard let kind, solved, !saving else { return }
        saving = true
        defer { saving = false }
        var name: String?
        do {
            if let image, kind == .photo {
                name = UUID().uuidString + ".jpg"
                try FileManager.default.createDirectory(at:store.photoDirectory,withIntermediateDirectories:true)
                let longest = max(image.size.width,image.size.height)
                let scale = min(1,1280/max(1,longest))
                let size = CGSize(width:max(1,image.size.width*scale),height:max(1,image.size.height*scale))
                let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                let clean = UIGraphicsImageRenderer(size:size,format:format).image { context in
                    UIColor.white.setFill(); context.fill(CGRect(origin:.zero,size:size)); image.draw(in:CGRect(origin:.zero,size:size))
                }
                guard let data = clean.jpegData(compressionQuality:0.8), let url = store.photoURL(name!) else { throw DomainError.invalidData }
                try data.write(to:url,options:.atomic)
            }
            if store.add(kind:.checkIn,detail:"\(kind.rawValue)・\(mood)",photo:name) { completed(); dismiss() }
            else if let name, let url = store.photoURL(name) { try? FileManager.default.removeItem(at:url) }
        } catch { store.errorMessage = "写真を保存できませんでした。\(error.localizedDescription)" }
    }
}

import AVFoundation
struct CameraCapture: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController,context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCapture
        init(_ parent: CameraCapture) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController,didFinishPickingMediaWithInfo info:[UIImagePickerController.InfoKey:Any]) { parent.image = info[.originalImage] as? UIImage; parent.dismiss() }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
