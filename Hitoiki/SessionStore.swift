import Foundation
import Combine
import UIKit

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var archive = AppArchive()
    @Published var errorMessage: String?
    @Published private(set) var loadFailed = false
    let directory: URL
    private let writer: (Data, URL) throws -> Void
    var onChange: (() -> Void)?
    var active: DrinkingSession? { archive.activeSession }
    var photoDirectory: URL { directory.appendingPathComponent("Photos", isDirectory: true) }

    init(directory: URL? = nil, writer: @escaping (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) {
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("Hitoiki", isDirectory: true)
        self.writer = writer
        reload()
    }

    func reload() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("archive.json")
            var loaded = FileManager.default.fileExists(atPath: url.path) ? try JSONDecoder().decode(AppArchive.self, from: Data(contentsOf: url)) : AppArchive()
            try loaded.validate()
            if loaded.archiveID == nil {
                loaded.archiveID = UUID()
                try writer(JSONEncoder().encode(loaded),url)
            }
            archive = loaded
            loadFailed = false
            errorMessage = nil
            onChange?()
        } catch {
            loadFailed = true
            errorMessage = "記録を読み込めませんでした。元のファイルは保持しています。\n\(error.localizedDescription)"
        }
    }

    @discardableResult
    func transact(_ mutation: (inout AppArchive) throws -> Void) -> Bool {
        guard !loadFailed else { return false }
        do {
            var next = archive
            try mutation(&next)
            next.revision += 1
            try next.validate()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try writer(encoder.encode(next), directory.appendingPathComponent("archive.json"))
            archive = next
            onChange?()
            return true
        } catch {
            errorMessage = "記録を保存できませんでした。空き容量などを確認して、もう一度お試しください。\n\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult func start(hours: Int?, reminder: Int, goal: Int?, occasion: DrinkingOccasion? = nil) -> Bool {
        transact { try $0.start(at: Date(), hours: hours, reminder: reminder, goal: goal, occasion: occasion) }
    }
    @discardableResult func add(kind: EntryKind, detail: String, photo: String? = nil, mood: String? = nil, note: String? = nil, id: UUID = UUID()) -> Bool {
        guard let s = active else { return false }
        let entry = SessionEntry(
            id: id,
            date: max(Date(), s.startedAt),
            kind: kind,
            detail: String(detail.prefix(200)),
            photoName: photo,
            mood: mood.map { String($0.prefix(40)) },
            note: note.map { String($0.prefix(500)) }
        )
        return transact { try $0.add(entry, to: s.id) }
    }

    func savePhoto(_ image: UIImage) throws -> String {
        let name = UUID().uuidString + ".jpg"
        try FileManager.default.createDirectory(at: photoDirectory, withIntermediateDirectories: true)
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, 1280 / max(1, longestSide))
        let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let clean = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = clean.jpegData(compressionQuality: 0.8), let url = photoURL(name) else {
            throw DomainError.invalidData
        }
        try data.write(to: url, options: .atomic)
        return name
    }

    func removePhoto(_ name: String) {
        guard let url = photoURL(name) else { return }
        try? FileManager.default.removeItem(at: url)
    }
    @discardableResult func end(note: String) -> Bool {
        guard let s = active else { return false }
        return transact { try $0.end(s.id, at: Date(), note: note) }
    }
    func undoEntry(_ entryID: UUID) {
        guard let s = active else { return }
        _ = transact { archive in
            guard let index = archive.sessions.firstIndex(where: { $0.id == s.id }) else { return }
            archive.sessions[index].entries.removeAll { $0.id == entryID }
        }
    }
    @discardableResult func delete(_ session: DrinkingSession) -> Bool {
        guard !session.isActive else { return false }
        let success = transact { $0.sessions.removeAll { $0.id == session.id } }
        if success {
            for name in session.entries.compactMap(\.photoName) where AppArchive.isSafePhotoName(name) {
                try? FileManager.default.removeItem(at: photoDirectory.appendingPathComponent(name))
            }
        }
        return success
    }
    func updatePreferences(_ value: Preferences) { transact { $0.preferences = value } }
    func photoURL(_ name: String) -> URL? {
        guard AppArchive.isSafePhotoName(name) else { return nil }
        return photoDirectory.appendingPathComponent(name)
    }
}
