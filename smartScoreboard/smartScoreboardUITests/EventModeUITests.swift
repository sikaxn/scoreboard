import XCTest

@MainActor
final class EventModeUITests: ScoreboardUITestCase {
    func testSimpleEventEditsScoringAndClock() throws {
        try exerciseEvent("simple", steps: [1], opening: "10:00")
    }

    func testBasketballEventEditsScoringPeriodAndClock() throws {
        try exerciseEvent("basketball", steps: [1, 2, 3], opening: "12:00", period: "Period")
    }

    func testSoccerEventEditsScoringHalfAndClock() throws {
        try exerciseEvent("soccer", steps: [1], opening: "45:00", period: "Half")
    }

    func testHockeyEventEditsScoringPeriodAndClock() throws {
        try exerciseEvent("hockey", steps: [1], opening: "20:00", period: "Period")
    }

    func testVolleyballBestOfThreeWithMatchTimer() throws { try exerciseVolleyball(bestOf: 3, timer: true) }
    func testVolleyballBestOfThreeWithoutMatchTimer() throws { try exerciseVolleyball(bestOf: 3, timer: false) }
    func testVolleyballBestOfFiveWithMatchTimer() throws { try exerciseVolleyball(bestOf: 5, timer: true) }
    func testVolleyballBestOfFiveWithoutMatchTimer() throws { try exerciseVolleyball(bestOf: 5, timer: false) }

    func testChessBulletWithUnequalOpeningClocks() throws { try exerciseChess("Bullet", minutes: 1) }
    func testChessBlitzWithUnequalOpeningClocks() throws { try exerciseChess("Blitz", minutes: 5) }
    func testChessRapidWithUnequalOpeningClocks() throws { try exerciseChess("Rapid", minutes: 10) }
    func testChessClassicalWithUnequalOpeningClocks() throws { try exerciseChess("Classical", minutes: 30) }

    func testSwitchingThroughEveryModeFromSimple() throws {
        try exerciseModeChanges(["simple", "basketball", "volleyball", "soccer", "hockey", "chess", "debate", "custom", "simple"])
    }

    func testSwitchingThroughEveryModeFromCustomInReverseOrder() throws {
        try exerciseModeChanges(["custom", "debate", "chess", "hockey", "soccer", "volleyball", "basketball", "simple", "custom"])
    }

    private func exerciseEvent(_ sport: String, steps: [Int], opening: String, period: String? = nil) throws {
        // Identity and starting state are unrelated to the operation under
        // test. The second edit below still runs through the actual UI.
        try launchFixture("event.\(sport)")
        XCTAssertEqual(text(clock), opening)
        exerciseScores(steps: steps)
        exerciseSharedClock()
        if let period {
            XCTAssertEqual(text(metric(period)), "2")
            tap(action("Next \(period)"))
            XCTAssertEqual(text(metric(period)), "3")
            tap(action("Prev Period"))
            respondToConfirmation("Previous \(period)")
            XCTAssertEqual(text(metric(period)), "2")
        }
        let total = steps.reduce(0, +)
        tap(action("Zero Scores"))
        respondToConfirmation("Cancel")
        assertScores(home: total, guest: total - 1)
        tap(action("Zero Scores"))
        respondToConfirmation("Zero Scores")
        assertScores(home: 0, guest: 0)

        openSettings()
        assertField("Event Name", equals: "\(sport) Final 100% %@", plain: true)
        assertField("Home Team", equals: "Home 100%")
        assertField("Guest Team", equals: "Guest %@")
        enter("Edited \(sport) Final %@", in: settingsField("Event Name", plain: true))
        enter("Edited Home", in: settingsField("Home Team"))
        if let period { assertSettingValue("Starting \(period)", equals: "2") }
        returnToBoard()
        addScore(steps.last!)
        assertScores(home: steps.last!, guest: 0)
        openSettings()
        assertField("Event Name", equals: "Edited \(sport) Final %@", plain: true)
        assertField("Home Team", equals: "Edited Home")
    }

    private func exerciseVolleyball(bestOf: Int, timer: Bool) throws {
        try launchFixture("event.volleyball", setup: true)
        choose("Match Format", option: "Best of \(bestOf)")
        setToggle("Enable Match Timer", to: timer)
        returnToBoard()
        exerciseScores(steps: [1])
        if timer { exerciseSharedClock(countsUp: true) }
        else { XCTAssertFalse(action("Start Game Clock").exists) }

        // A nonstandard result requires the real confirmation; cancel and undo
        // must retain the scores and return to the correct period.
        tap(action("Home Wins Period"))
        respondToConfirmation("Cancel")
        assertScores(home: 1, guest: 0)
        tap(action("Home Wins Period"))
        respondToConfirmation("Award Period")
        assertScores(home: 0, guest: 0)
        XCTAssertEqual(text(metric("Periods")), "1-0")
        XCTAssertEqual(text(metric("Period")), "2")
        addScore(side: "guest")
        tap(action("Guest Wins Period"))
        respondToConfirmation("Award Period")
        XCTAssertEqual(text(metric("Periods")), "1-1")
        tap(action("Undo & Return"))
        respondToConfirmation("Undo & Return")
        assertScores(home: 0, guest: 1)
        XCTAssertEqual(text(metric("Period")), "2")
        XCTAssertEqual(text(metric("Periods")), "1-0")
        openSettings()
        assertChoice("Match Format", equals: "Best of \(bestOf)")
        assertToggle("Enable Match Timer", equals: timer)
        assertField("Event Name", equals: "volleyball Final 100% %@", plain: true)
    }

    private func exerciseChess(_ preset: String, minutes: Int) throws {
        try launchFixture("event.chess", setup: true)
        choose("Preset", option: preset)
        step("Guest Clock", by: 1)
        assertSettingValue("Home Clock", equals: "\(String(format: "%02d", minutes)):00")
        assertSettingValue("Guest Clock", equals: "\(String(format: "%02d", minutes + 1)):00")
        returnToBoard()
        XCTAssertFalse(sideAction("+1").exists)
        XCTAssertEqual(clockSeconds(text(sideClock("home"))), minutes * 60)
        XCTAssertEqual(clockSeconds(text(sideClock("guest"))), (minutes + 1) * 60)
        exerciseSideClocks()
        tap(action("Reset Clocks"))
        respondToConfirmation("Cancel")
        XCTAssertLessThan(clockSeconds(text(sideClock("guest"))), (minutes + 1) * 60)
        tap(action("Reset Clocks"))
        respondToConfirmation("Reset Clocks")
        XCTAssertEqual(clockSeconds(text(sideClock("home"))), minutes * 60)
        // Reset Clocks uses the configured shared preset for both sides;
        // the unequal guest value above is a runtime/setup adjustment.
        XCTAssertEqual(clockSeconds(text(sideClock("guest"))), minutes * 60)
        openSettings()
        assertChoice("Preset", equals: preset)
        assertField("Home Team", equals: "Home 100%")
        assertField("Guest Team", equals: "Guest %@")
        returnToBoard()
        XCTAssertEqual(clockSeconds(text(sideClock("guest"))), minutes * 60)
    }

    private func exerciseModeChanges(_ modes: [String]) throws {
        try launchFixture(modes[0] == "custom" ? "custom.base" : "event.simple", setup: true)
        enter("One Event 100% %@", in: settingsField("Event Name", plain: true))
        for mode in modes {
            XCTContext.runActivity(named: "Switch to \(mode) and reopen settings") { _ in
                tap(mainWindow.buttons["settings.sport.\(mode)"])
                returnToBoard()
                let start = mode == "debate" ? "Start Segment Timer"
                    : mode == "chess" ? "Start Active Clock" : "Start Game Clock"
                reveal(action(start))
                XCTAssertTrue(action(start).isEnabled)
                openSettings()
                assertField("Event Name", equals: "One Event 100% %@", plain: true)
                assertField("Home Team", equals: "Home 100%")
                assertField("Guest Team", equals: "Guest %@")
            }
        }
    }
}
