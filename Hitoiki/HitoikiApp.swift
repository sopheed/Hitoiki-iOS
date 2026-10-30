import SwiftUI

@main
struct HitoikiApp: App {
    @StateObject private var store: SessionStore
    @StateObject private var reminders: ReminderCenter
    @StateObject private var bridge: PhoneBridge
    @Environment(\.scenePhase) private var scenePhase
    init() {
        var directory: URL? = nil
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest") {
            let testDirectory = URL.applicationSupportDirectory.appendingPathComponent("HitoikiUITests")
            if ProcessInfo.processInfo.arguments.contains("--reset") { try? FileManager.default.removeItem(at:testDirectory) }
            directory = testDirectory
        }
        #endif
        let store = SessionStore(directory:directory)
        let reminders = ReminderCenter()
        let bridge = PhoneBridge(store:store)
        reminders.store = store
        store.onChange = { [weak reminders, weak bridge] in reminders?.reconcile(); bridge?.publish() }
        _store = StateObject(wrappedValue:store)
        _reminders = StateObject(wrappedValue:reminders)
        _bridge = StateObject(wrappedValue:bridge)
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(reminders).environmentObject(bridge)
                .tint(Palette.forest).preferredColorScheme(nil)
                .task { reminders.reconcile(); bridge.publish() }
                .onChange(of:scenePhase) { _, phase in
                    if phase == .active { reminders.reconcile(); bridge.publish() }
                }
        }
    }
}
