import Foundation

enum EntryKind: String, Codable, CaseIterable {
    case water, drink, checkIn
    var title: String {
        switch self { case .water: return "お水を飲んだ"; case .drink: return "お酒を記録"; case .checkIn: return "ひといきチェック" }
    }
    var symbol: String {
        switch self { case .water: return "drop.fill"; case .drink: return "wineglass.fill"; case .checkIn: return "leaf.fill" }
    }
}

enum DrinkKind: String, Codable, CaseIterable, Identifiable {
    case beer = "ビール", highball = "ハイボール", wine = "ワイン", sake = "日本酒", cocktail = "カクテル", other = "その他"
    var id: String { rawValue }
}

enum CheckInKind: String, Codable, CaseIterable, Identifiable {
    case numbers = "ちょこっと計算", shapes = "しずく探し", photo = "今を一枚"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .numbers: return "plus.forwardslash.minus"; case .shapes: return "drop"; case .photo: return "camera" }
    }
}

struct SessionEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var kind: EntryKind
    var detail: String
    var photoName: String? = nil
}

struct DrinkingSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var startedAt: Date
    var endedAt: Date? = nil
    var plannedEnd: Date
    var reminderMinutes: Int
    var drinkGoal: Int? = nil
    var entries: [SessionEntry] = []
    var note = ""
    var isActive: Bool { endedAt == nil }
    var waterCount: Int { entries.filter { $0.kind == .water }.count }
    var drinkCount: Int { entries.filter { $0.kind == .drink }.count }
    var checkInCount: Int { entries.filter { $0.kind == .checkIn }.count }
    var lastCheckIn: Date { entries.filter { $0.kind == .checkIn }.map(\.date).max() ?? startedAt }
    func elapsed(at date: Date = Date()) -> TimeInterval { max(0, (endedAt ?? date).timeIntervalSince(startedAt)) }
    func checkInIsDue(at now: Date, lastPrompt: Date) -> Bool {
        isActive && now.timeIntervalSince(max(lastCheckIn,lastPrompt)) >= 900
    }
    func nextReminder(after now: Date) -> Date {
        let interval = TimeInterval(reminderMinutes * 60)
        let steps = max(1, floor(now.timeIntervalSince(startedAt) / interval) + 1)
        return startedAt.addingTimeInterval(steps * interval)
    }
}

struct Preferences: Codable, Equatable {
    var reminderMinutes = 60
    var durationHours = 2
    var remindersEnabled = true
    var returnCheckIn = true
    var haptics = true
}

enum WatchAction: String, Codable { case water, drink, end }
struct WatchCommand: Identifiable, Codable, Equatable {
    var id = UUID()
    var sessionID: UUID
    var date: Date
    var action: WatchAction
}
struct CommandReceipt: Codable, Equatable, Identifiable {
    var id: UUID
    var accepted: Bool
    var message: String
}

struct AppArchive: Codable, Equatable {
    var archiveID: UUID? = UUID()
    var schemaVersion = 1
    var revision = 0
    var sessions: [DrinkingSession] = []
    var preferences = Preferences()
    var receipts: [CommandReceipt] = []
    var activeSession: DrinkingSession? { sessions.first { $0.isActive } }

    func validate() throws {
        guard schemaVersion == 1,
              Set(sessions.map(\.id)).count == sessions.count,
              sessions.filter({ $0.isActive }).count <= 1,
              [30, 60, 90].contains(preferences.reminderMinutes),
              (1...6).contains(preferences.durationHours),
              sessions.allSatisfy({ s in
                  [30, 60, 90].contains(s.reminderMinutes) && s.plannedEnd > s.startedAt &&
                  (s.endedAt == nil || s.endedAt! >= s.startedAt) &&
                  (s.drinkGoal == nil || (1...20).contains(s.drinkGoal!)) &&
                  Set(s.entries.map(\.id)).count == s.entries.count &&
                  s.entries.allSatisfy { e in e.date >= s.startedAt && (e.photoName == nil || Self.isSafePhotoName(e.photoName!)) }
              }) else { throw DomainError.invalidData }
    }

    static func isSafePhotoName(_ name: String) -> Bool {
        guard name.hasSuffix(".jpg"), let _ = UUID(uuidString: String(name.dropLast(4))) else { return false }
        return !name.contains("/") && !name.contains("\\")
    }

    mutating func start(at now: Date, hours: Int, reminder: Int, goal: Int?) throws {
        guard activeSession == nil else { throw DomainError.alreadyActive }
        guard (1...6).contains(hours), [30,60,90].contains(reminder), goal == nil || (1...20).contains(goal!) else { throw DomainError.invalidData }
        sessions.insert(DrinkingSession(startedAt: now, plannedEnd: now.addingTimeInterval(Double(hours) * 3600), reminderMinutes: reminder, drinkGoal: goal), at: 0)
    }

    mutating func add(_ entry: SessionEntry, to sessionID: UUID) throws {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID && $0.isActive }) else { throw DomainError.noActiveSession }
        guard entry.date >= sessions[index].startedAt else { throw DomainError.invalidData }
        guard !sessions[index].entries.contains(where: { $0.id == entry.id }) else { return }
        sessions[index].entries.append(entry)
    }

    mutating func end(_ sessionID: UUID, at now: Date, note: String) throws {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID && $0.isActive }) else { throw DomainError.noActiveSession }
        sessions[index].endedAt = max(now, sessions[index].entries.map(\.date).max() ?? sessions[index].startedAt)
        sessions[index].note = String(note.prefix(2000))
    }

    mutating func apply(_ command: WatchCommand, now: Date) -> CommandReceipt {
        if let old = receipts.first(where: { $0.id == command.id }) { return old }
        let receipt: CommandReceipt
        if let session = activeSession, session.id == command.sessionID {
            let date = min(now, max(session.startedAt, command.date))
            switch command.action {
            case .water, .drink:
                let kind: EntryKind = command.action == .water ? .water : .drink
                try? add(SessionEntry(id: command.id, date: date, kind: kind, detail: command.action == .water ? "Watchからお水" : "Watchから1杯"), to: session.id)
            case .end: try? end(session.id, at: now, note: "")
            }
            receipt = CommandReceipt(id: command.id, accepted: true, message: "記録しました")
        } else {
            receipt = CommandReceipt(id: command.id, accepted: false, message: "この飲み会は終了しています。記録は追加されませんでした。")
        }
        receipts.append(receipt)
        return receipt
    }
}

enum DomainError: LocalizedError {
    case invalidData, alreadyActive, noActiveSession
    var errorDescription: String? {
        switch self {
        case .invalidData: return "保存データを読み込めません。元のデータはそのまま残しています。"
        case .alreadyActive: return "すでに見守り中です。いまの飲み会を終了してから始めてください。"
        case .noActiveSession: return "この飲み会は終了しています。画面を開き直してください。"
        }
    }
}

struct WatchSnapshot: Codable, Equatable {
    var revision: Int
    var session: DrinkingSession?
    var receipts: [CommandReceipt]
    var updatedAt: Date
    var archiveID: UUID? = nil
}

struct WatchCache: Codable {
    var snapshot: WatchSnapshot? = nil
    var pending: [WatchCommand] = []
    mutating func accept(_ incoming: WatchSnapshot) -> String? {
        let rejection = incoming.receipts.first { receipt in !receipt.accepted && pending.contains { $0.id == receipt.id } }
        let ids = Set(incoming.receipts.map(\.id))
        pending.removeAll { ids.contains($0.id) }
        if let old = snapshot {
            if incoming.archiveID == old.archiveID {
                if incoming.revision >= old.revision {
                    var latest = incoming
                    latest.updatedAt = max(old.updatedAt,incoming.updatedAt)
                    snapshot = latest
                }
            } else if incoming.updatedAt >= old.updatedAt { snapshot = incoming }
        } else { snapshot = incoming }
        return rejection?.message
    }
}

enum TimeText {
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds)) / 60
        return minutes >= 60 ? "\(minutes / 60)時間\(minutes % 60)分" : "\(minutes)分"
    }
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%02d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
    }
}

struct ReminderPlan: Equatable {
    var sessionID: UUID
    var interval: TimeInterval
    var nextDate: Date
    var finishDate: Date?
    static func make(archive: AppArchive, now: Date) -> ReminderPlan? {
        guard archive.preferences.remindersEnabled, let s = archive.activeSession else { return nil }
        return ReminderPlan(sessionID: s.id, interval: Double(s.reminderMinutes * 60), nextDate: s.nextReminder(after: now), finishDate: s.plannedEnd > now ? s.plannedEnd : nil)
    }
}

enum CSVExport {
    static func field(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
    static func make(_ sessions: [DrinkingSession]) -> String {
        let formatter = ISO8601DateFormatter()
        var rows = ["開始,終了,経過分,お酒の記録回数,お水の記録回数,チェック回数,メモ"]
        for s in sessions.filter({ !$0.isActive }) {
            rows.append([formatter.string(from: s.startedAt), s.endedAt.map(formatter.string) ?? "", String(Int(s.elapsed() / 60)), String(s.drinkCount), String(s.waterCount), String(s.checkInCount), s.note].map(field).joined(separator: ","))
        }
        return "\u{FEFF}" + rows.joined(separator: "\r\n")
    }
}
