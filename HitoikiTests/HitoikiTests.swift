import XCTest
import UserNotifications
@testable import Hitoiki

final class HitoikiTests: XCTestCase {
    private let now = Date(timeIntervalSince1970:1_800_000_000)
    private func activeArchive() throws -> AppArchive {
        var archive = AppArchive(); try archive.start(at:now,hours:2,reminder:60,goal:3); return archive
    }
    func testOnlyOneActiveSession() throws {
        var archive = try activeArchive()
        XCTAssertThrowsError(try archive.start(at:now,hours:2,reminder:60,goal:nil))
        XCTAssertEqual(archive.sessions.count,1)
        try archive.end(archive.activeSession!.id,at:now.addingTimeInterval(3600),note:"おひらき")
        try archive.start(at:now.addingTimeInterval(7200),hours:1,reminder:30,goal:nil)
        XCTAssertEqual(archive.sessions.count,2)
        try archive.validate()
    }
    func testElapsedUsesDatesAndClampsClockReversal() throws {
        var session = try XCTUnwrap(try activeArchive().activeSession)
        XCTAssertEqual(session.elapsed(at:now.addingTimeInterval(5401)),5401)
        XCTAssertEqual(session.elapsed(at:now.addingTimeInterval(-10)),0)
        session.endedAt = now.addingTimeInterval(1800)
        XCTAssertEqual(session.elapsed(at:now.addingTimeInterval(9000)),1800)
    }
    func testHourlyPlanAlignsToStartAndStopsAfterEnd() throws {
        var archive = try activeArchive()
        let plan = try XCTUnwrap(ReminderPlan.make(archive:archive,now:now.addingTimeInterval(3700)))
        XCTAssertEqual(plan.nextDate,now.addingTimeInterval(7200))
        XCTAssertEqual(plan.interval,3600)
        try archive.end(archive.activeSession!.id,at:now.addingTimeInterval(4000),note:"")
        XCTAssertNil(ReminderPlan.make(archive:archive,now:now))
    }
    func testDisabledRemindersAndPastFinishingTime() throws {
        var archive = try activeArchive()
        XCTAssertNil(try XCTUnwrap(ReminderPlan.make(archive:archive,now:now.addingTimeInterval(8000))).finishDate)
        archive.preferences.remindersEnabled = false
        XCTAssertNil(ReminderPlan.make(archive:archive,now:now))
    }
    func testEntryCountsAndNoLateWrites() throws {
        var archive = try activeArchive(); let id = archive.activeSession!.id
        let water = SessionEntry(date:now,kind:.water,detail:"お水")
        try archive.add(water,to:id); try archive.add(water,to:id)
        try archive.add(SessionEntry(date:now,kind:.drink,detail:"ビール"),to:id)
        try archive.add(SessionEntry(date:now,kind:.checkIn,detail:"少し休む"),to:id)
        XCTAssertEqual(archive.activeSession!.waterCount,1)
        XCTAssertEqual(archive.activeSession!.drinkCount,1)
        XCTAssertEqual(archive.activeSession!.checkInCount,1)
        try archive.end(id,at:now,note:"")
        XCTAssertThrowsError(try archive.add(water,to:id))
    }
    func testWatchCommandsAreIdempotentAndPersistReceipts() throws {
        var archive = try activeArchive()
        let command = WatchCommand(sessionID:archive.activeSession!.id,date:now,action:.water)
        XCTAssertTrue(archive.apply(command,now:now).accepted)
        var restored = try JSONDecoder().decode(AppArchive.self,from:JSONEncoder().encode(archive))
        XCTAssertTrue(restored.apply(command,now:now).accepted)
        XCTAssertEqual(restored.activeSession!.waterCount,1)
        XCTAssertEqual(restored.receipts.count,1)
    }
    func testStaleWatchCannotChangeAnotherSession() throws {
        var archive = try activeArchive(); let old = archive.activeSession!.id
        try archive.end(old,at:now,note:""); try archive.start(at:now,hours:1,reminder:30,goal:nil)
        let receipt = archive.apply(WatchCommand(sessionID:old,date:now,action:.end),now:now)
        XCTAssertFalse(receipt.accepted)
        XCTAssertNotNil(archive.activeSession)
        XCTAssertEqual(archive.activeSession!.entries.count,0)
    }
    func testWatchFutureDateClampedAndEndStopsPlan() throws {
        var archive = try activeArchive(); let id = archive.activeSession!.id
        _ = archive.apply(WatchCommand(sessionID:id,date:now.addingTimeInterval(30000),action:.drink),now:now)
        XCTAssertEqual(archive.activeSession!.entries.first!.date,now)
        _ = archive.apply(WatchCommand(sessionID:id,date:now,action:.end),now:now)
        XCTAssertNil(archive.activeSession)
        XCTAssertNil(ReminderPlan.make(archive:archive,now:now))
        XCTAssertFalse(archive.apply(WatchCommand(sessionID:id,date:now,action:.water),now:now).accepted)
    }
    func testCSVQuotesNotesAndPreservesNewlines() throws {
        var archive = try activeArchive(); try archive.end(archive.activeSession!.id,at:now,note:"お水, \"ひといき\"\nまたね")
        let csv = CSVExport.make(archive.sessions)
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}")); XCTAssertTrue(csv.contains("\"お水, \"\"ひといき\"\"\nまたね\""))
    }
    func testInvalidArchiveAndPhotoTraversalRejected() throws {
        var archive = try activeArchive()
        archive.sessions.append(archive.sessions[0])
        XCTAssertThrowsError(try archive.validate())
        XCTAssertFalse(AppArchive.isSafePhotoName("../archive.json"))
        XCTAssertFalse(AppArchive.isSafePhotoName("/tmp/photo.jpg"))
        XCTAssertTrue(AppArchive.isSafePhotoName(UUID().uuidString+".jpg"))
    }
    @MainActor func testAtomicStorageRoundTripAndDeletion() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let store = SessionStore(directory:dir)
        XCTAssertTrue(store.start(hours:2,reminder:60,goal:nil))
        XCTAssertTrue(store.add(kind:.water,detail:"お水"))
        let restored = SessionStore(directory:dir)
        XCTAssertEqual(restored.active?.waterCount,1)
        XCTAssertTrue(restored.end(note:"メモ"))
        XCTAssertTrue(restored.delete(restored.archive.sessions[0]))
        XCTAssertTrue(SessionStore(directory:dir).archive.sessions.isEmpty)
    }
    @MainActor func testFailedSaveRollsBackPublishedState() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let store = SessionStore(directory:dir,writer:{ _,_ in throw CocoaError(.fileWriteOutOfSpace) })
        XCTAssertFalse(store.start(hours:2,reminder:60,goal:nil))
        XCTAssertNil(store.active); XCTAssertNotNil(store.errorMessage)
    }
    @MainActor func testCorruptionIsPreservedAndCannotBeOverwritten() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:dir) }
        let url = dir.appendingPathComponent("archive.json"); let broken = Data("{broken".utf8)
        try broken.write(to:url)
        let store = SessionStore(directory:dir)
        XCTAssertTrue(store.loadFailed); XCTAssertFalse(store.start(hours:2,reminder:60,goal:nil))
        XCTAssertEqual(try Data(contentsOf:url),broken)
    }
    @MainActor func testUndoRemovesOnlySelectedEntry() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let store = SessionStore(directory:dir); _ = store.start(hours:2,reminder:60,goal:nil)
        let id = UUID(); _ = store.add(kind:.water,detail:"お水",id:id); _ = store.add(kind:.drink,detail:"ビール")
        store.undoEntry(id)
        XCTAssertEqual(store.active?.waterCount,0); XCTAssertEqual(store.active?.drinkCount,1)
    }
    @MainActor func testSystemReminderReservationDeliveryAndCancellation() async throws {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized else { throw XCTSkip("通知許可後のシミュレータ・実機で実行してください") }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let store = SessionStore(directory:dir)
        let reminders = ReminderCenter(); reminders.store = store
        store.onChange = { reminders.reconcile() }
        // Use a genuine hourly plan whose first hour arrives shortly, without changing production intervals.
        XCTAssertTrue(store.transact { archive in try archive.start(at:Date().addingTimeInterval(-3590),hours:2,reminder:60,goal:nil) })
        let id = store.active!.id.uuidString
        var requests: [UNNotificationRequest] = []
        for _ in 0..<60 {
            requests = await center.pendingNotificationRequests()
            if requests.filter({ $0.content.userInfo["sessionID"] as? String == id }).count == 61 { break }
            try await Task.sleep(for:.milliseconds(100))
        }
        XCTAssertEqual(requests.filter { $0.content.userInfo["sessionID"] as? String == id }.count,61)
        let sortedDates = requests.filter { !$0.identifier.hasPrefix("hitoiki.finish") }.compactMap { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() }.sorted()
        XCTAssertEqual(sortedDates.count,60)
        if sortedDates.count > 1 { XCTAssertEqual(sortedDates[1].timeIntervalSince(sortedDates[0]),3600,accuracy:1) }
        var delivered = false
        for _ in 0..<150 {
            delivered = await center.deliveredNotifications().contains { $0.request.content.userInfo["sessionID"] as? String == id }
            if delivered { break }
            try await Task.sleep(for:.milliseconds(100))
        }
        XCTAssertTrue(delivered,"OS should deliver the local hourly reminder")
        XCTAssertTrue(store.end(note:"notification integration test"))
        for _ in 0..<60 {
            requests = await center.pendingNotificationRequests()
            if requests.filter({ $0.identifier.hasPrefix("hitoiki.") }).isEmpty { break }
            try await Task.sleep(for:.milliseconds(100))
        }
        XCTAssertTrue(requests.filter { $0.identifier.hasPrefix("hitoiki.") }.isEmpty)
        let remainingDelivered = await center.deliveredNotifications()
        XCTAssertTrue(remainingDelivered.filter { $0.request.content.userInfo["sessionID"] as? String == id }.isEmpty)
    }

    func testCheckInPromptsAfterFifteenMinutesAndRespectsRecentPrompt() throws {
        var session = try XCTUnwrap(try activeArchive().activeSession)
        XCTAssertFalse(session.checkInIsDue(at:now.addingTimeInterval(899),lastPrompt:.distantPast))
        XCTAssertTrue(session.checkInIsDue(at:now.addingTimeInterval(900),lastPrompt:.distantPast))
        XCTAssertFalse(session.checkInIsDue(at:now.addingTimeInterval(950),lastPrompt:now.addingTimeInterval(900)))
        session.entries.append(SessionEntry(date:now.addingTimeInterval(900),kind:.checkIn,detail:"休憩"))
        XCTAssertFalse(session.checkInIsDue(at:now.addingTimeInterval(1000),lastPrompt:.distantPast))
        session.endedAt = now.addingTimeInterval(1000)
        XCTAssertFalse(session.checkInIsDue(at:now.addingTimeInterval(9999),lastPrompt:.distantPast))
    }

    func testWatchCacheRejectsOldSnapshotsAndAcceptsNewArchive() throws {
        let id = UUID()
        let current = WatchSnapshot(revision:10,session:try activeArchive().activeSession,receipts:[],updatedAt:now,archiveID:id)
        var cache = WatchCache(snapshot:current)
        _ = cache.accept(WatchSnapshot(revision:9,session:nil,receipts:[],updatedAt:now.addingTimeInterval(1),archiveID:id))
        XCTAssertNotNil(cache.snapshot?.session)
        _ = cache.accept(WatchSnapshot(revision:0,session:nil,receipts:[],updatedAt:now.addingTimeInterval(2),archiveID:UUID()))
        XCTAssertNil(cache.snapshot?.session)
        let newID = cache.snapshot?.archiveID
        _ = cache.accept(WatchSnapshot(revision:0,session:nil,receipts:[],updatedAt:now,archiveID:newID))
        XCTAssertEqual(cache.snapshot?.updatedAt,now.addingTimeInterval(2))
        _ = cache.accept(current)
        XCTAssertNil(cache.snapshot?.session,"Delayed snapshots from the prior archive must not restore stale state")
    }
    func testWatchDurableQueueAcceptsReceiptFromOlderSnapshot() throws {
        let command = WatchCommand(sessionID:UUID(),date:now,action:.water)
        let archiveID = UUID()
        var cache = WatchCache(snapshot:WatchSnapshot(revision:10,session:nil,receipts:[],updatedAt:now,archiveID:archiveID),pending:[command])
        cache = try JSONDecoder().decode(WatchCache.self,from:JSONEncoder().encode(cache))
        XCTAssertEqual(cache.pending.first?.id,command.id)
        let receipt = CommandReceipt(id:command.id,accepted:true,message:"記録しました")
        _ = cache.accept(WatchSnapshot(revision:9,session:nil,receipts:[receipt],updatedAt:now,archiveID:archiveID))
        XCTAssertTrue(cache.pending.isEmpty)
        XCTAssertEqual(cache.snapshot?.revision,10)
    }
    @MainActor func testExistingArchiveGetsStableIdentity() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:dir) }
        var archive = try activeArchive(); archive.archiveID = nil
        try JSONEncoder().encode(archive).write(to:dir.appendingPathComponent("archive.json"))
        let store = SessionStore(directory:dir)
        XCTAssertNotNil(store.archive.archiveID)
        XCTAssertEqual(store.archive.archiveID,SessionStore(directory:dir).archive.archiveID)
        XCTAssertEqual(store.active?.id,archive.activeSession?.id)
    }

}
