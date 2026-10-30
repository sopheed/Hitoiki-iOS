import Foundation
import UserNotifications
import Combine

@MainActor
final class ReminderCenter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var permission: UNAuthorizationStatus = .notDetermined
    @Published var pendingCount = 0
    @Published var issue: String?
    @Published var openCheckIn = false
    private let center = UNUserNotificationCenter.current()
    weak var store: SessionStore?
    private var work: Task<Void, Never>?
    private var generation = 0

    override init() {
        super.init()
        center.delegate = self
        let water = UNNotificationAction(identifier: "water", title: "お水を飲んだ", options: [])
        let check = UNNotificationAction(identifier: "check", title: "ひといきチェック", options: .foreground)
        center.setNotificationCategories([UNNotificationCategory(identifier: "HITOIKI", actions: [water, check], intentIdentifiers: [], options: [])])
    }
    func refreshPermission() async { permission = await center.notificationSettings().authorizationStatus }
    func request() async {
        do { _ = try await center.requestAuthorization(options: [.alert, .sound, .badge]); issue = nil }
        catch { issue = "通知を設定できませんでした。\(error.localizedDescription)" }
        await refreshPermission()
        reconcile()
    }
    func reconcile() {
        generation += 1
        guard work == nil else { return }
        work = Task {
            var finishedGeneration = -1
            while finishedGeneration != generation {
                finishedGeneration = generation
                await synchronize(generation:finishedGeneration)
            }
            work = nil
        }
    }
    private func synchronize(generation expected: Int) async {
            await refreshPermission()
            guard generation == expected, let archive = store?.archive else { return }
            let existing = await center.pendingNotificationRequests()
            guard generation == expected else { return }
            center.removePendingNotificationRequests(withIdentifiers: existing.filter { $0.identifier.hasPrefix("hitoiki.") }.map(\.identifier))
            let delivered = await center.deliveredNotifications()
            guard generation == expected else { return }
            let activeID = archive.activeSession?.id.uuidString
            center.removeDeliveredNotifications(withIdentifiers: delivered.filter { $0.request.identifier.hasPrefix("hitoiki.") && $0.request.content.userInfo["sessionID"] as? String != activeID }.map { $0.request.identifier })
            guard [.authorized, .provisional, .ephemeral].contains(permission), let plan = ReminderPlan.make(archive: archive, now: Date()) else { pendingCount = 0; return }
            do {
                // iOS keeps at most 64 pending requests. Reserve room for the finishing reminder.
                for offset in 0..<60 {
                    guard generation == expected else { return }
                    let date = plan.nextDate.addingTimeInterval(Double(offset) * plan.interval)
                    let content = UNMutableNotificationContent()
                    content.title = "ぽたと、ひといき。"
                    content.body = offset % 2 == 0 ? "お水をひとくち。今の時間と、帰る予定を思い出そう。" : "楽しい時間にも、ちいさな休憩を。今の気持ちを確かめよう。"
                    content.sound = .default
                    content.categoryIdentifier = "HITOIKI"
                    content.userInfo = ["sessionID":plan.sessionID.uuidString]
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
                    try await center.add(UNNotificationRequest(identifier:"hitoiki.\(plan.sessionID).\(Int(date.timeIntervalSince1970))",content:content,trigger:trigger))
                }
                guard generation == expected else { return }
                if let finish = plan.finishDate {
                    let content = UNMutableNotificationContent()
                    content.title = "そろそろ、帰る支度を。"
                    content.body = "決めていた終了予定の時間です。今日はここまでにしようか。"
                    content.sound = .default
                    content.categoryIdentifier = "HITOIKI"
                    content.userInfo = ["sessionID":plan.sessionID.uuidString]
                    try await center.add(UNNotificationRequest(identifier:"hitoiki.finish.\(plan.sessionID)",content:content,trigger:UNTimeIntervalNotificationTrigger(timeInterval:max(1,finish.timeIntervalSinceNow),repeats:false)))
                }
                guard generation == expected else { return }
                pendingCount = (await center.pendingNotificationRequests()).filter { $0.identifier.hasPrefix("hitoiki.") }.count
                issue = nil
            } catch { issue = "通知を予約できませんでした。アプリを開き直すと再試行します。" }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            defer { completionHandler() }
            guard let store, let raw = response.notification.request.content.userInfo["sessionID"] as? String, let id = UUID(uuidString: raw), store.active?.id == id else { return }
            if response.actionIdentifier == "water" {
                // Stable action ID prevents a duplicated response from adding two glasses.
                let name = response.notification.request.identifier
                let bytes = Array(name.utf8)
                var hash: UInt64 = 14695981039346656037
                for byte in bytes { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
                let text = String(format:"00000000-0000-4000-8000-%012llx",hash & 0xffffffffffff)
                _ = store.add(kind:.water,detail:"通知からお水",id:UUID(uuidString:text)!)
            } else { openCheckIn = true }
        }
    }
}
