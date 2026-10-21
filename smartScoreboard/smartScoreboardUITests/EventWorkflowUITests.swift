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
        checkOfficialPause(scenario: "basketball", startTitle: "Start Game Clock", runningTitle: "Pause Game Clock")
    }

    func testOfficialPauseInChessClockCardLeavesPlayStopped() {
        checkOfficialPause(scenario: "chess", startTitle: "Start Active Clock", runningTitle: "Pause Active Clock")
    }

    func testOfficialPauseInDebateClockCardLeavesPlayStopped() {
        checkOfficialPause(scenario: "debate", startTitle: "Start Segment Timer", runningTitle: "Pause Segment Timer")
    }

    func testOfficialPauseSharesAddedTimeRow() {
        checkOfficialPause(scenario: "soccer", startTitle: "Start Game Clock", runningTitle: "Pause Game Clock")
    }

    private func checkOfficialPause(scenario: String, startTitle: String, runningTitle: String) {
        launch(scenario)
        let clockCard = mainWindow.otherElements["live.gameControls"].firstMatch
        XCTAssertTrue(clockCard.waitForExistence(timeout: 5))
        let start = clockCard.buttons["action.\(startTitle)"]
        tap(start, anchor: clockCard)
        let adjustmentRow = clockCard.otherElements["live.clockAdjustmentRow"]
        let officialPause = adjustmentRow.buttons["live.officialPause"]
        reveal(officialPause, anchor: clockCard)
        XCTAssertEqual(mainWindow.buttons.matching(identifier: "live.officialPause").count, 1)
        XCTAssertTrue(clockCard.frame.contains(officialPause.frame), "Official Pause must be inside the clock card")
        if scenario == "soccer" {
            let addedTime = adjustmentRow.otherElements["live.addedTime"]
            XCTAssertTrue(addedTime.staticTexts["Added Time"].exists)
            XCTAssertEqual(addedTime.frame.midY, officialPause.frame.midY, accuracy: 1, "Official Pause must share the Added Time row")
            XCTAssertLessThanOrEqual(addedTime.frame.maxX, officialPause.frame.minX)
            tap(addedTime.buttons["Set"], anchor: adjustmentRow)
            tapMenuAction("+3 min")
            XCTAssertTrue(addedTime.staticTexts["+3 min"].exists)
        }
        tap(officialPause, anchor: clockCard)
        tapMenuAction("Indefinite Official Pause")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertFalse(start.isEnabled)
        let stopPause = clockCard.buttons["action.Stop Pause"]
        reveal(stopPause, anchor: clockCard)
        XCTAssertTrue(clockCard.frame.contains(stopPause.frame), "The active pause controls must stay inside the clock card")
        tap(stopPause, anchor: clockCard)
        XCTAssertTrue(start.isEnabled)
        tap(start, anchor: clockCard)
        XCTAssertTrue(clockCard.buttons["action.\(runningTitle)"].waitForExistence(timeout: 5))
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
