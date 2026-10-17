import XCTest

/// Regression sources are mapped to commits in docs/ui-testing.md.
@MainActor
final class EventWorkflowUITests: ScoreboardUITestCase {
    func testOperatorSetsUpEventScoresAndRunsClock() {
        launch("setup")
        tap(app.buttons["settings.sport.basketball"])
        enter("Saturday Final", in: app.textFields["field.settings-plain-text-entry-Event Name-"])
        enter("Falcons", in: app.textFields["field.settings-text-entry-Home Team-"])
        enter("Tigers", in: app.textFields["field.settings-text-entry-Guest Team-"])
        returnToBoard()
        addScore(2)
        addScore(3, side: "guest")
        waitUntil("Scores must apply to the selected teams") { self.text(self.score()) == "2" && self.text(self.score("guest")) == "3" }
        XCTAssertTrue(app.staticTexts["FALCONS"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["TIGERS"].firstMatch.exists)
        let initialClock = text(clock)
        tap(action("Start Game Clock"))
        waitUntil("The real game timer must advance") { self.text(self.clock) != initialClock }
        tap(action("Pause Game Clock"))
        XCTAssertTrue(action("Start Game Clock").isEnabled)
    }

    // 43cdfb1: opening/canceling Settings must not stop a running timer or reload the match.
    func testSettingsWarningAndUneditedReturnPreserveRunningEvent() {
        launch()
        addScore(3)
        tap(action("Start Game Clock"))
        tap(app.buttons["Settings"].firstMatch)
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["Open Settings While Timers Are Running?"].exists)
        tapAlertAction("Cancel")
        waitUntil("Cancel dismisses the running-clock warning") { !alert.exists }
        XCTAssertTrue(action("Pause Game Clock").exists)
        let before = text(clock)
        openSettings()
        returnToBoard()
        XCTAssertTrue(action("Pause Game Clock").exists)
        XCTAssertEqual(text(score()), "3")
        waitUntil("Returning from Settings must keep the clock running") { self.text(self.clock) != before }
    }

    // 4a8c137: an official pause stops play; ending it leaves play stopped.
    func testOfficialPauseLeavesPlayStoppedUntilOperatorRestarts() {
        launch()
        tap(action("Start Game Clock"))
        tap(app.buttons["live.officialPause"].firstMatch)
        tap(app.buttons["Indefinite Official Pause"].firstMatch)
        XCTAssertTrue(action("Start Game Clock").waitForExistence(timeout: 5))
        XCTAssertFalse(action("Start Game Clock").isEnabled)
        tap(action("Stop Pause"))
        XCTAssertTrue(action("Start Game Clock").isEnabled)
        tap(action("Start Game Clock"))
        XCTAssertTrue(action("Pause Game Clock").waitForExistence(timeout: 5))
    }

    // 2e8729b/57b98ea: dynamic percent text and deep Debate/Custom view trees
    // must survive opening settings, committing changes, and returning to play.
    func testDebateAndCustomSetupPreservePercentNames() {
        launch("setup")
        let eventName = "Final 100% %@ Round"
        for sport in ["debate", "custom"] {
            tap(app.buttons["settings.sport.\(sport)"])
            enter(eventName, in: app.textFields["field.settings-plain-text-entry-Event Name-"])
            tap(app.buttons.matching(NSPredicate(format: "label IN %@", ["Go to Control Board", "Back to Live Board"])).firstMatch)
            XCTAssertTrue(app.buttons["Settings"].firstMatch.waitForExistence(timeout: 8))
            openSettings()
            let eventField = app.textFields["field.settings-plain-text-entry-Event Name-"]
            reveal(eventField)
            XCTAssertEqual(text(eventField).lowercased(), eventName.lowercased())
            mainWindow.scrollViews.element(boundBy: mainWindow.scrollViews.count - 1).swipeDown()
        }
    }

}
