import XCTest

@MainActor
final class CustomModeEditingUITests: ScoreboardUITestCase {
    // Each independent case loads a saved configuration, then exercises live
    // controls. The editor and dependency cases below retain actual UI setup.
    func testCountdownWithoutScoring() throws { try exercise(.countdown, .off) }
    func testCountdownWithOnePointButtons() throws { try exercise(.countdown, .one) }
    func testCountdownWithOneAndTwoPointButtons() throws { try exercise(.countdown, .two) }
    func testCountdownWithAllScoreButtons() throws { try exercise(.countdown, .three) }
    func testCountUpWithoutScoring() throws { try exercise(.countUp, .off) }
    func testCountUpWithOnePointButtons() throws { try exercise(.countUp, .one) }
    func testCountUpWithOneAndTwoPointButtons() throws { try exercise(.countUp, .two) }
    func testCountUpWithAllScoreButtons() throws { try exercise(.countUp, .three) }
    func testDisabledClockWithoutScoring() throws { try exercise(.disabled, .off) }
    func testDisabledClockWithOnePointButtons() throws { try exercise(.disabled, .one) }
    func testDisabledClockWithOneAndTwoPointButtons() throws { try exercise(.disabled, .two) }
    func testDisabledClockWithAllScoreButtons() throws { try exercise(.disabled, .three) }
    func testChessClocksWithoutScoring() throws { try exercise(.chess, .off) }
    func testChessClocksWithOnePointButtons() throws { try exercise(.chess, .one) }
    func testChessClocksWithOneAndTwoPointButtons() throws { try exercise(.chess, .two) }
    func testChessClocksWithAllScoreButtons() throws { try exercise(.chess, .three) }

    func testCustomEditorCommitsEveryModuleAndRepeatedTitleEdits() throws {
        let target = try configuration("custom.full-editor")
        try launchFixture("custom.base", setup: true)
        editConfiguration(target)
        returnToBoard()
        exerciseConfiguredEvent(target, editTitle: true)
    }

    func testDependentCustomOptionsResetAndReenableThroughUserControls() throws {
        try launchFixture("custom.base", setup: true)
        for option in ["+1", "+1 +2", "+1 +2 +3"] { choose("Score Buttons", option: option) }
        setToggle("Chess Style Clocks", to: true)
        assertSettingValue("Home Clock", equals: "10:00")
        setToggle("Chess Style Clocks", to: false)
        for mode in ["Disabled", "Count Up", "Countdown"] { choose("Clock Mode", option: mode) }
        setToggle("Track Period Wins", to: true)
        setToggle("Score Tracking", to: false)
        XCTAssertFalse(toggle("Track Period Wins").exists)
        XCTAssertFalse(mainWindow.buttons["settings.picker.Score Buttons"].exists)
        setToggle("Score Tracking", to: true)
        assertToggle("Track Period Wins", equals: false)
        setToggle("Track Period Wins", to: true)
        setToggle("Period Tracking", to: false)
        XCTAssertFalse(settingsField("Period Label").exists)
        setToggle("Period Tracking", to: true)
        assertToggle("Track Period Wins", equals: false)

        reveal(toggle("Possession Arrow"))
        XCTAssertFalse(toggle("Possession Arrow").isEnabled)
        setToggle("Secondary Timer", to: true)
        setToggle("Possession Arrow", to: true)
        choose("Timer Type", option: "Serve Timer")
        reveal(toggle("Possession Arrow"))
        XCTAssertFalse(toggle("Possession Arrow").isEnabled)
        setToggle("Secondary Timer", to: false)
        assertToggle("Possession Arrow", equals: false)
        setToggle("Secondary Timer", to: true)
        assertChoice("Timer Type", equals: "Shot Clock")
        assertToggle("Possession Arrow", equals: false)
        setToggle("Player Tracking", to: true)
        setToggle("Player Fouls", to: true)
        setToggle("Player Cards", to: true)
        setToggle("Player Tracking", to: false)
        XCTAssertFalse(toggle("Player Fouls").exists)
        XCTAssertFalse(toggle("Player Cards").exists)
        let players = mainWindow.buttons["settings.pane.players"]
        reveal(players)
        XCTAssertFalse(players.isEnabled)
        returnToBoard()
        openSettings()
        assertToggle("Score Tracking", equals: true)
        assertToggle("Period Tracking", equals: true)
        assertToggle("Track Period Wins", equals: false)
        assertChoice("Timer Type", equals: "Shot Clock")
        assertToggle("Possession Arrow", equals: false)
        assertToggle("Player Tracking", equals: false)
    }

    private enum ClockStyle: String, Decodable {
        case countdown, countUp, disabled, chess
        var title: String {
            switch self {
            case .countdown: return "Countdown"
            case .countUp: return "Count Up"
            case .disabled: return "Disabled"
            case .chess: return "Chess"
            }
        }
    }

    private enum Scoring: String {
        case off, one, two, three
        var steps: [Int] {
            switch self {
            case .off: return []
            case .one: return [1]
            case .two: return [1, 2]
            case .three: return [1, 2, 3]
            }
        }
        var title: String { steps.isEmpty ? "Off" : steps.map { "+\($0)" }.joined(separator: " ") }
    }

    private struct Fixture: Decodable {
        let eventName: String
        let period: Int
        let guestClockSeconds: Int?
        let customSportConfig: Configuration
    }

    /// Expectations come from the same editable JSON input as the launch
    /// fixture. Observations still come from the app's rendered UI.
    private struct Configuration: Decodable {
        let title: String
        let usesChessClocks: Bool
        let mainClockMode: ClockStyle
        let defaultClockSeconds: Int
        let defaultShotClockSeconds: Int
        let isScoreEnabled: Bool
        let scoreStepPreset: String
        let isPeriodEnabled: Bool
        let periodTitle: String
        let periodShortTitle: String
        let isPeriodWinTrackingEnabled: Bool
        let isShotClockEnabled: Bool
        let shotClockMode: String
        let isPossessionEnabled: Bool
        let isPlayerTrackingEnabled: Bool
        let usesCenterPlayerStrip: Bool
        let isPlayerFoulsEnabled: Bool
        let isPlayerCardsEnabled: Bool
        let isSubstitutionTrackingEnabled: Bool
        let isPauseTrackingEnabled: Bool
        let isTeamFoulsEnabled: Bool
        let isPenaltyTimerEnabled: Bool
        var clock: ClockStyle { usesChessClocks ? .chess : mainClockMode }
        var scoring: Scoring {
            guard isScoreEnabled else { return .off }
            switch scoreStepPreset {
            case "one": return .one
            case "oneTwo": return .two
            default: return .three
            }
        }
        var name: String { title }
        var period: Bool { isPeriodEnabled }
        var periodWins: Bool { isPeriodWinTrackingEnabled }
        var secondary: Int { isShotClockEnabled ? (shotClockMode == "serve" ? 2 : 1) : 0 }
        var players: Bool { isPlayerTrackingEnabled }
        var centerPlayers: Bool { usesCenterPlayerStrip }
        var playerFouls: Bool { isPlayerFoulsEnabled }
        var playerCards: Bool { isPlayerCardsEnabled }
        var substitutions: Bool { isSubstitutionTrackingEnabled }
        var pauses: Bool { isPauseTrackingEnabled }
        var teamFouls: Bool { isTeamFoulsEnabled }
        var penalties: Bool { isPenaltyTimerEnabled }
    }

    private func configuration(_ name: String) throws -> Fixture {
        try JSONDecoder().decode(Fixture.self, from: JSONSerialization.data(withJSONObject: fixture(name)))
    }

    private func exercise(_ clockStyle: ClockStyle, _ scoring: Scoring) throws {
        let name = "custom.\(clockStyle.rawValue).\(scoring.rawValue)"
        let prepared = try configuration(name)
        try launchFixture(name)
        exerciseConfiguredEvent(prepared)
    }

    private func editConfiguration(_ target: Fixture) {
        let config = target.customSportConfig
        let clockStyle = config.clock
        let scoring = config.scoring
        enter(config.name, in: settingsField("Custom Title"))
        setToggle("Score Tracking", to: scoring != .off)
        if scoring != .off { choose("Score Buttons", option: scoring.title) }
        setToggle("Chess Style Clocks", to: clockStyle == .chess)
        if clockStyle == .chess {
            step("Guest Clock", by: 1)
        } else {
            choose("Clock Mode", option: clockStyle.title)
            if clockStyle != .disabled { choose("Clock Preset", option: "\(config.defaultClockSeconds / 60):00") }
        }
        setToggle("Period Tracking", to: config.period)
        if config.period {
            step("Starting Period", by: target.period - 1)
            enter(config.periodTitle, in: settingsField("Period Label"))
            enter(config.periodShortTitle, in: settingsField("Short Label"))
            if scoring != .off { setToggle("Track Period Wins", to: config.periodWins) }
        }
        setToggle("Secondary Timer", to: config.secondary != 0)
        if config.secondary != 0 {
            choose("Timer Type", option: config.secondary == 1 ? "Shot Clock" : "Serve Timer")
            choose(config.secondary == 1 ? "Shot Preset" : "Serve Preset", option: "\(config.defaultShotClockSeconds)")
            if config.secondary == 1 { setToggle("Possession Arrow", to: true) }
        }
        setToggle("Player Tracking", to: config.players)
        if config.players {
            setToggle("Soccer Style Player Display", to: config.centerPlayers)
            setToggle("Player Fouls", to: config.playerFouls)
            setToggle("Player Cards", to: config.playerCards)
        }
        setToggle("Substitutions", to: config.substitutions)
        setToggle("Pauses", to: config.pauses)
        setToggle("Team Fouls", to: config.teamFouls)
        setToggle("Penalty Timers", to: config.penalties)
    }

    private func exerciseConfiguredEvent(_ prepared: Fixture, editTitle: Bool = false) {
        let config = prepared.customSportConfig
        let clockStyle = config.clock
        let scoring = config.scoring
        if scoring != .off { exerciseScores(steps: scoring.steps) }
        else { XCTAssertFalse(sideAction("+1").exists) }
        switch clockStyle {
        case .countdown, .countUp:
            XCTAssertEqual(clockSeconds(text(clock)), config.defaultClockSeconds)
            exerciseSharedClock(countsUp: clockStyle == .countUp)
        case .disabled:
            XCTAssertFalse(action("Start Game Clock").exists)
            XCTAssertFalse(action("Start Active Clock").exists)
        case .chess:
            XCTAssertEqual(clockSeconds(text(sideClock("home"))), config.defaultClockSeconds)
            XCTAssertEqual(clockSeconds(text(sideClock("guest"))), prepared.guestClockSeconds ?? config.defaultClockSeconds)
            exerciseSideClocks()
        }
        if config.period {
            XCTAssertEqual(text(metric(config.periodTitle)), "\(prepared.period)")
            if config.periodWins {
                tap(action("Home Wins Period"))
                respondToConfirmation("Award Period")
                assertScores(home: 0, guest: 0)
                XCTAssertEqual(text(metric("Periods")), "1-0")
            } else {
                tap(action("Next \(config.periodTitle)"))
            }
            XCTAssertEqual(text(metric(config.periodTitle)), "\(prepared.period + 1)")
        }
        if config.secondary != 0 { exerciseSecondaryTimer(config.secondary, seconds: config.defaultShotClockSeconds) }
        if config.teamFouls {
            tapSide("Foul +")
            XCTAssertTrue(controls().staticTexts["Team Fouls 1"].exists)
            tapSide("Foul -")
            XCTAssertTrue(controls().staticTexts["Team Fouls 0"].exists)
        }

        openSettings()
        assertConfiguration(prepared, period: prepared.period + 1)
        if editTitle { enter("\(config.name) EDITED", in: settingsField("Custom Title")) }
        returnToBoard()
        if scoring != .off {
            let expected = config.periodWins ? 0 : scoring.steps.reduce(0, +)
            assertScores(home: expected, guest: config.periodWins ? 0 : expected - 1)
        }
        if editTitle {
            openSettings()
            assertField("Custom Title", equals: "\(config.name) EDITED")
        }
    }

    private func assertConfiguration(_ prepared: Fixture, period: Int) {
        let config = prepared.customSportConfig
        assertField("Event Name", equals: prepared.eventName, plain: true)
        assertField("Custom Title", equals: config.name)
        assertToggle("Score Tracking", equals: config.scoring != .off)
        if config.scoring != .off { assertChoice("Score Buttons", equals: config.scoring.title) }
        assertToggle("Chess Style Clocks", equals: config.clock == .chess)
        if config.clock != .chess { assertChoice("Clock Mode", equals: config.clock.title) }
        assertToggle("Period Tracking", equals: config.period)
        if config.period {
            assertSettingValue("Starting Period", equals: "\(period)")
            assertField("Period Label", equals: config.periodTitle)
            assertField("Short Label", equals: config.periodShortTitle)
            if config.scoring != .off { assertToggle("Track Period Wins", equals: config.periodWins) }
        }
        assertToggle("Secondary Timer", equals: config.secondary != 0)
        if config.secondary != 0 {
            assertChoice("Timer Type", equals: config.secondary == 1 ? "Shot Clock" : "Serve Timer")
        }
        assertToggle("Possession Arrow", equals: config.isPossessionEnabled)
        assertToggle("Player Tracking", equals: config.players)
        if config.players {
            assertToggle("Soccer Style Player Display", equals: config.centerPlayers)
            assertToggle("Player Fouls", equals: config.playerFouls)
            assertToggle("Player Cards", equals: config.playerCards)
        }
        assertToggle("Substitutions", equals: config.substitutions)
        assertToggle("Pauses", equals: config.pauses)
        assertToggle("Team Fouls", equals: config.teamFouls)
        assertToggle("Penalty Timers", equals: config.penalties)
    }

    private func exerciseSecondaryTimer(_ mode: Int, seconds: Int) {
        let title = mode == 1 ? "Shot" : "Serve"
        let timer = metric(title)
        reveal(timer)
        XCTAssertEqual(text(timer), "\(seconds).0", "The configured secondary timer must load")
        tapSide(mode == 1 ? "Shot 14" : "Serve Here")
        let activePreset = mode == 1 ? 14 : seconds
        waitUntil("The custom \(title.lowercased()) timer must advance") {
            guard timer.exists, let remaining = Double(self.text(timer)) else { return false }
            return remaining < Double(activePreset)
        }
        if mode == 1 {
            // This same button becomes Reset if the short clock expires while
            // scrolling. Either action leaves it ready for the reset below.
            let pauseOrReset = mainWindow.buttons.matching(NSPredicate(
                format: "identifier IN %@", ["action.Shot Pause", "action.Shot Reset"])).firstMatch
            tap(pauseOrReset)
        }
        // Serve Reset stops the clock itself. Searching for its transient Pause
        // label can otherwise outlast an eight-second serve timer.
        tap(action("\(title) Reset"))
        XCTAssertEqual(text(timer), "\(activePreset).0")
        tap(action("\(title) +1"))
        XCTAssertEqual(text(timer), "\(activePreset + 1).0")
    }
}
