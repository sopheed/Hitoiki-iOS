import XCTest

final class HitoikiUITests: XCTestCase {
    func testBannerDoesNotCoverNavigationOrSessionEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest", "--reset", "--ad-layout-preview"]
        app.launch()
        let banner = app.staticTexts["テスト広告・レイアウト確認用"]
        XCTAssertTrue(banner.waitForExistence(timeout:10))
        XCTAssertLessThanOrEqual(banner.frame.maxY,app.tabBars.firstMatch.frame.minY)
        tap(app.buttons["startSession"],in:app)
        XCTAssertTrue(app.navigationBars["飲み会をはじめる"].waitForExistence(timeout:5))
        XCTAssertFalse(banner.exists)
        app.buttons["閉じる"].tap()
        app.tabBars.buttons["せってい"].tap()
        XCTAssertFalse(banner.exists)
    }
    private func launch(reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest"] + (reset ? ["--reset"] : [])
        app.launch()
        return app
    }
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            if element.exists && element.isHittable { element.tap(); return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists,"Missing element: \(element)")
        if element.exists { element.tap() }
    }
    private func start(_ app: XCUIApplication) {
        app.buttons["startSession"].tap()
        tap(app.buttons["confirmStart"],in:app)
        let springboard = XCUIApplication(bundleIdentifier:"com.apple.springboard")
        let allow = springboard.buttons["許可"]
        if allow.waitForExistence(timeout:3) { allow.tap() }
        else if springboard.buttons["Allow"].exists { springboard.buttons["Allow"].tap() }
        XCTAssertTrue(app.staticTexts["elapsedTime"].waitForExistence(timeout:10))
    }
    func testSessionCheckInHistoryAndPersistence() {
        let app = launch(); start(app)
        tap(app.buttons["addWater"],in:app)
        XCTAssertTrue(app.staticTexts["waterCount"].label.contains("1"))
        tap(app.buttons["addDrink"],in:app)
        app.buttons["drink_ビール"].tap()
        tap(app.buttons["openCheckIn"],in:app)
        app.buttons["check_しずく探し"].tap()
        tap(app.buttons["shape_target"],in:app)
        tap(app.buttons["saveCheckIn"],in:app)
        tap(app.buttons["finishSession"],in:app)
        tap(app.buttons["confirmFinish"],in:app)
        XCTAssertTrue(app.navigationBars["きろく"].waitForExistence(timeout:5))
        app.terminate()
        let restored = launch(reset:false)
        restored.tabBars.buttons["きろく"].tap()
        XCTAssertTrue(restored.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'history_'")).firstMatch.waitForExistence(timeout:5))
        let shot = XCTAttachment(screenshot:restored.screenshot()); shot.name = "記録帳"; shot.lifetime = .keepAlways; add(shot)
    }
    func testMathAndSettings() {
        let app = launch(); start(app)
        tap(app.buttons["openCheckIn"],in:app)
        app.buttons["check_ちょこっと計算"].tap()
        let question = app.staticTexts["mathQuestion"].label
        let numbers = question.components(separatedBy:CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        XCTAssertEqual(numbers.count,2)
        if numbers.count == 2 { app.buttons["answer_\(numbers[0]+numbers[1])"].tap() }
        tap(app.buttons["saveCheckIn"],in:app)
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "見守り画面"; shot.lifetime = .keepAlways; add(shot)
        app.tabBars.buttons["せってい"].tap()
        XCTAssertTrue(app.switches["飲み会中の通知"].waitForExistence(timeout:5))
        tap(app.buttons["ひといきについて・使い方"],in:app)
        XCTAssertTrue(app.staticTexts["ぽたの役目"].waitForExistence(timeout:5))
    }
    func testAppStoreScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest", "--reset", "--store-screenshots", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.staticTexts["elapsedTime"].waitForExistence(timeout: 10))
        app.tabBars.buttons["せってい"].tap()
        if app.buttons["通知を許可する"].waitForExistence(timeout: 2) {
            app.buttons["通知を許可する"].tap()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            if springboard.buttons["許可"].waitForExistence(timeout: 3) { springboard.buttons["許可"].tap() }
            else if springboard.buttons["Allow"].exists { springboard.buttons["Allow"].tap() }
        }
        app.tabBars.buttons["いま"].tap()
        captureStore(app, "01-active")
        tap(app.buttons["openCheckIn"], in: app)
        captureStore(app, "02-check-in")
        app.buttons["check_ちょこっと計算"].tap()
        captureStore(app, "03-math")
        app.buttons["閉じる"].tap()
        app.tabBars.buttons["きろく"].tap()
        captureStore(app, "04-history")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history_' ")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        captureStore(app, "05-detail")
        app.terminate()
        let welcome = launch()
        captureStore(welcome, "06-welcome")
        welcome.buttons["startSession"].tap()
        captureStore(welcome, "07-plan")
    }
    private func captureStore(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 1.5)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "store-" + name
        shot.lifetime = .keepAlways; add(shot)
    }
    func testWelcomeLayout() {
        let app = launch()
        XCTAssertTrue(app.buttons["startSession"].waitForExistence(timeout:5))
        let shot = XCTAttachment(screenshot:app.screenshot()); shot.name = "ホーム"; shot.lifetime = .keepAlways; add(shot)
    }
    func testHistoryDetailEditSearchAndDeletion() {
        let app = launch(); start(app)
        tap(app.buttons["addWater"],in:app)
        tap(app.buttons["finishSession"],in:app)
        tap(app.buttons["confirmFinish"],in:app)
        let row = app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'history_'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout:5)); row.tap()
        app.buttons["編集"].tap()
        let field = app.textViews.firstMatch
        if field.waitForExistence(timeout:2) { field.tap(); field.typeText("次はお水を先に") }
        else { let input = app.textFields.firstMatch; input.tap(); input.typeText("次はお水を先に") }
        app.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["次はお水を先に"].waitForExistence(timeout:5))
        app.navigationBars.buttons.firstMatch.tap()
        let search = app.searchFields.firstMatch
        if !search.isHittable { app.swipeDown() }
        search.tap(); search.typeText("次はお水")
        XCTAssertTrue(row.waitForExistence(timeout:5)); row.tap()
        app.buttons["この記録を削除"].tap()
        app.buttons["記録と写真を削除"].tap()
        XCTAssertTrue(app.staticTexts["見つかりませんでした"].waitForExistence(timeout:5))
    }

}
