import Foundation
import WatchConnectivity
import Combine

@MainActor
final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var cache = WatchCache()
    @Published var message: String?
    @Published var reachable = false
    @Published private(set) var loadFailed = false
    private var inFlight = false
    private let url = URL.applicationSupportDirectory.appendingPathComponent("HitoikiWatch/cache.json")
    var session: DrinkingSession? { cache.snapshot?.session }
    var ending: Bool { cache.pending.contains { $0.sessionID == session?.id && $0.action == .end } }
    func pendingCount(_ action: WatchAction) -> Int { cache.pending.filter { $0.sessionID == session?.id && $0.action == action }.count }
    override init() {
        super.init()
        do {
            if FileManager.default.fileExists(atPath:url.path) { cache = try JSONDecoder().decode(WatchCache.self,from:Data(contentsOf:url)) }
        } catch { loadFailed = true; message = "記録を読み込めません。アプリを開き直してください。保存済みのファイルは残しています。" }
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
    }
    @discardableResult private func save(_ next: WatchCache) -> Bool {
        guard !loadFailed else { return false }
        do {
            try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
            try JSONEncoder().encode(next).write(to:url,options:.atomic)
            cache = next; return true
        } catch { message = "保存できませんでした。もう一度お試しください。"; return false }
    }
    func record(_ action: WatchAction) {
        guard let session, !ending else { return }
        var next = cache
        next.pending.append(WatchCommand(sessionID:session.id,date:Date(),action:action))
        if save(next) { message = nil; flush() }
    }
    private func accept(_ dictionary: [String:Any]) {
        guard let data = dictionary["snapshot"] as? Data, let snapshot = try? JSONDecoder().decode(WatchSnapshot.self,from:data) else { return }
        var next = cache
        let rejection = next.accept(snapshot)
        if save(next), let rejection { message = rejection }
    }

    func refresh() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        reachable = WCSession.default.isReachable
        accept(WCSession.default.receivedApplicationContext)
        if reachable {
            WCSession.default.sendMessage(["request":true],replyHandler:{ reply in Task { @MainActor in self.accept(reply); self.flush() } },errorHandler:{ _ in })
        }
        flush()
    }
    private func flush() {
        guard !inFlight, let command = cache.pending.first, WCSession.default.activationState == .activated,
              let data = try? JSONEncoder().encode(command) else { return }
        reachable = WCSession.default.isReachable
        if reachable {
            inFlight = true
            WCSession.default.sendMessage(["command":data],replyHandler:{ reply in
                Task { @MainActor in
                    self.inFlight = false
                    self.accept(reply)
                    if reply["retry"] == nil && self.cache.pending.first?.id != command.id { self.flush() }
                }
            },errorHandler:{ _ in Task { @MainActor in self.inFlight = false; self.transfer(command,data:data) } })
        } else { transfer(command,data:data) }
    }
    private func transfer(_ command: WatchCommand,data: Data) {
        let exists = WCSession.default.outstandingUserInfoTransfers.contains { transfer in
            guard let bytes = transfer.userInfo["command"] as? Data, let queued = try? JSONDecoder().decode(WatchCommand.self,from:bytes) else { return false }
            return queued.id == command.id
        }
        if !exists { WCSession.default.transferUserInfo(["command":data]) }
    }
    nonisolated func session(_ session: WCSession,activationDidCompleteWith activationState: WCSessionActivationState,error: Error?) { Task { @MainActor in refresh() } }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) { Task { @MainActor in refresh() } }
    nonisolated func session(_ session: WCSession,didReceiveApplicationContext applicationContext:[String:Any]) { Task { @MainActor in accept(applicationContext); flush() } }
    nonisolated func session(_ session: WCSession,didReceiveUserInfo userInfo:[String:Any]) { Task { @MainActor in accept(userInfo); flush() } }
}
