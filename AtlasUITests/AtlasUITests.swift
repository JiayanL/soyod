import XCTest

nonisolated final class AtlasUITests: XCTestCase {

    private func makeApp(sampleData: Bool = true,
                         resetOnboarding: Bool = false,
                         route: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AtlasUITest", "YES",
                                "-AtlasNow", "2026-10-01T15:30:00",
                                "-AtlasDenyPermissions", "YES"]
        if sampleData { app.launchArguments += ["-AtlasSampleData", "YES"] }
        if resetOnboarding { app.launchArguments += ["-AtlasResetOnboarding", "YES"] }
        if let route { app.launchArguments += ["-AtlasScreen", route] }
        return app
    }

    private func waitFor(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Set ATLAS_UI_SLOW=1 to pace the tests for video capture.
    private var slow: Bool { ProcessInfo.processInfo.environment["ATLAS_UI_SLOW"] == "1" }
    private func pace(_ seconds: UInt32 = 1) { if slow { sleep(seconds) } }

    /// Regression test for the off-main UIColor SIGTRAP: cycling tabs must
    /// never crash and each screen's hero element must render.
    @MainActor
    func testTabSwitchingDoesNotCrash() throws {
        let app = makeApp()
        app.launch()
        let tabs: [(String, String)] = [
            ("Fuel", "caloriesHero"), ("Train", "startWorkout"),
            ("Sleep", "logSleep"), ("Progress", "goalHero"), ("Coach", "gamePlan"),
        ]
        for _ in 0..<3 {
            for (tab, marker) in tabs {
                let button = app.tabBars.buttons[tab]
                XCTAssertTrue(waitFor(button), "tab \(tab) missing")
                pace()
                button.tap()
                pace()
                XCTAssertEqual(app.state, .runningForeground)
                XCTAssertTrue(waitFor(app.descendants(matching: .any)[marker], timeout: 8),
                              "\(marker) missing after tapping \(tab)")
            }
        }
    }

    @MainActor
    func testOnboardingCustomGoal() throws {
        let app = makeApp(sampleData: false, resetOnboarding: true)
        app.launch()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(waitFor(any["onbStart"], timeout: 10))
        pace()
        any["onbStart"].tap()

        // Goal: pick custom.
        XCTAssertTrue(waitFor(any["goal-custom"]))
        pace()
        any["goal-custom"].tap()
        pace()
        any["onbContinue"].tap()

        // Baseline: title + numbers.
        pace()
        let title = any["customTitle"]
        XCTAssertTrue(waitFor(title))
        title.tap()
        title.typeText("Run a sub-20 5K")
        pace()
        let baseline = any["baseline"]
        baseline.tap()
        baseline.typeText("24")
        pace()
        let target = any["target"]
        target.tap()
        target.typeText("19")
        XCTAssertTrue(waitFor(any["onbContinue"]))
        pace()
        any["onbContinue"].tap()

        // About → Fuel → Connect → Plan reveal.
        for _ in 0..<3 {
            XCTAssertTrue(waitFor(any["onbContinue"]))
            pace()
            any["onbContinue"].tap()
        }
        XCTAssertTrue(waitFor(any["onbFinish"], timeout: 10))
        pace()
        any["onbFinish"].tap()

        XCTAssertTrue(app.tabBars.buttons["Coach"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testChatNobuReturnsActionCards() throws {
        let app = makeApp(route: "coach")
        app.launch()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(waitFor(any["talkToAtlas"], timeout: 10))
        any["talkToAtlas"].tap()

        let field = app.textFields["Message Atlas"]
        XCTAssertTrue(waitFor(field, timeout: 10))
        pace()
        field.tap()
        field.typeText("I have dinner at Nobu at 7:30 tonight")
        pace()
        app.buttons["Send"].firstMatch.tap()

        // Reply must mention the reservation time and show an action card.
        let reply = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS '7:30' OR label CONTAINS '19:30'"))
            .firstMatch
        // The configured engine can take >10s on a cold model; give headroom.
        XCTAssertTrue(reply.waitForExistence(timeout: 20), "no reply containing 7:30")
        let card = any.matching(NSPredicate(format: "identifier BEGINSWITH 'actionCard-'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "no action card")
    }

    @MainActor
    func testLogStrengthWorkoutShowsSummary() throws {
        let app = makeApp(route: "train")
        app.launch()
        let any = app.descendants(matching: .any)
        XCTAssertTrue(waitFor(any["startWorkout"], timeout: 10))
        any["startWorkout"].tap()

        pace()
        XCTAssertTrue(waitFor(any["setCheck"], timeout: 10))
        any["setCheck"].firstMatch.tap()
        pace()
        XCTAssertTrue(waitFor(any["finishWorkout"]))
        any["finishWorkout"].firstMatch.tap()

        XCTAssertTrue(any["summaryDone"].waitForExistence(timeout: 10), "workout summary missing")
        XCTAssertEqual(app.state, .runningForeground)
    }
}
