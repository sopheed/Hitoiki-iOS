#if DEBUG
import Foundation

/// Fictional records used only by isolated App Store screenshot automation.
enum StoreScreenshotFixture {
    static func session(now: Date = Date()) -> DrinkingSession {
        let start = now.addingTimeInterval(-2520)
        return DrinkingSession(startedAt: start, plannedEnd: start.addingTimeInterval(7200), reminderMinutes: 60,
            entries: [SessionEntry(date: start.addingTimeInterval(300), kind: .drink, detail: "ビール"),
                      SessionEntry(date: start.addingTimeInterval(1200), kind: .water, detail: "お水をひとくち"),
                      SessionEntry(date: start.addingTimeInterval(1800), kind: .checkIn, detail: "しずく探し・ゆっくり楽しむ"),
                      SessionEntry(date: start.addingTimeInterval(2400), kind: .water, detail: "お水をひとくち")])
    }
    static func archive() -> AppArchive {
        let now = Date()
        var value = AppArchive()
        value.preferences.returnCheckIn = false
        value.preferences.remindersEnabled = true
        value.sessions = [session(now: now)]
        for (days, note) in [(1, "お水を間にはさめた。ゆっくり話せて、いい時間。"), (4, "早めのおひらき。明日の朝も気持ちよく。"), (7, "友だちとごはん。自分のペースで楽しめた。") ] {
            var item = session(now: now.addingTimeInterval(Double(-days * 86400)))
            item.endedAt = item.startedAt.addingTimeInterval(5400)
            item.note = note
            value.sessions.append(item)
        }
        return value
    }
}
#endif
