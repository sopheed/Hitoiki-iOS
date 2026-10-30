import Foundation
import WatchConnectivity
import Combine

@MainActor
final class PhoneBridge: NSObject, WCSessionDelegate, ObservableObject {
    @Published var watchAvailable = false
    private weak var store: SessionStore?
    init(store: SessionStore) {
        self.store = store
        super.init()
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
    }
    func publish() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated, let store else { return }
        watchAvailable = WCSession.default.isPaired && WCSession.default.isWatchAppInstalled
        guard watchAvailable else { return }
        let snapshot = WatchSnapshot(revision:store.archive.revision,session:store.active,receipts:Array(store.archive.receipts.suffix(256)),updatedAt:Date(),archiveID:store.archive.archiveID)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        do { try WCSession.default.updateApplicationContext(["snapshot":data]) }
        catch { /* A subsequent activation/reachability change retries the latest snapshot. */ }
    }
    private func receive(_ dictionary: [String:Any]) -> [String:Any] {
        guard let store, !store.loadFailed else { return ["retry":true] }
        var receipt: CommandReceipt?
        if let data = dictionary["command"] as? Data, let command = try? JSONDecoder().decode(WatchCommand.self,from:data) {
            guard store.transact({ receipt = $0.apply(command,now:Date()) }) else { return ["retry":true] }
        }
        publish()
        let snapshot = WatchSnapshot(revision:store.archive.revision,session:store.active,receipts:receipt.map { [$0] } ?? [],updatedAt:Date(),archiveID:store.archive.archiveID)
        return ["snapshot": (try? JSONEncoder().encode(snapshot)) ?? Data()]
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { Task { @MainActor in publish() } }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) { Task { @MainActor in publish() } }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) { Task { @MainActor in publish() } }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String:Any], replyHandler: @escaping ([String:Any])->Void) {
        Task { @MainActor in replyHandler(receive(message)) }
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String:Any]) {
        Task { @MainActor in
            let reply = receive(userInfo)
            if let data = reply["snapshot"] as? Data { session.transferUserInfo(["snapshot":data]) }
        }
    }
}
