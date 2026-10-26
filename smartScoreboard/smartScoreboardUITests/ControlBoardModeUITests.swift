import XCTest

@MainActor
final class ControlBoardModeUITests: ScoreboardUITestCase {
    private let basketballModules = ["matchTimer", "shotClock", "scores", "roster", "substitutions", "pauses"]

    private func openModePicker() {
        let button = app.buttons["controlBoard.chooseMode"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        tap(button)
        XCTAssertTrue(app.buttons["controlBoard.mode.full"].waitForExistence(timeout: 5))
        let picker = app.otherElements["controlBoard.modePicker"].firstMatch
        let header = app.otherElements["controlBoard.modePicker.header"].firstMatch
        XCTAssertTrue(picker.exists && header.exists)
        XCTAssertLessThan(header.frame.minY - picker.frame.minY, 40, "The picker header must stay at the top")
        XCTAssertTrue(app.buttons["controlBoard.done"].isHittable)
    }

    private func finishModePicker() {
        XCTAssertTrue(app.buttons["controlBoard.done"].isHittable, "Done must stay visible while the options scroll")
        tap(app.buttons["controlBoard.done"])
        waitUntil("Mode picker must close") { !self.app.buttons["controlBoard.done"].exists }
    }

    private func selectMode(_ mode: String) {
        openModePicker()
        tap(app.buttons["controlBoard.mode.\(mode)"])
        finishModePicker()
    }

    private func setModule(_ module: String, enabled: Bool) {
        setPickerToggle("controlBoard.module.\(module)", enabled: enabled)
    }

    private func setPickerToggle(_ identifier: String, enabled: Bool) {
        let control = app.switches[identifier].firstMatch
        reveal(control)
        if text(control) != (enabled ? "1" : "0") {
            let thumb = control.switches.firstMatch
            tap(thumb.exists ? thumb : control, anchor: control)
        }
        waitUntil("The module toggle must update") { self.text(control) == (enabled ? "1" : "0") }
    }

    func testShotStationKeepsPrimaryClockRunningAndHidesScoring() {
        launch()
        tap(action("Start Game Clock"))
        let primaryBefore = text(clock)
        selectMode("shotClock")
        XCTAssertTrue(mainWindow.otherElements["controlBoard.summary"].exists)
        XCTAssertTrue(mainWindow.otherElements["controlBoard.panel.shotClock"].exists)
        XCTAssertFalse(action("+1").exists)
        XCTAssertFalse(action("Pause Game Clock").exists)
        tap(action("Start Shot Clock"))
        let secondary = mainWindow.staticTexts["live.shotClock"]
        let secondaryBefore = text(secondary)
        waitUntil("Dedicated shot controls must drive the real countdown") { self.text(secondary) != secondaryBefore }
        tap(action("Shot Pause"))
        selectMode("full")
        XCTAssertTrue(action("Pause Game Clock").exists)
        XCTAssertNotEqual(text(clock), primaryBefore)
        XCTAssertEqual(text(score()), "0", "Switching stations must not change the score")
        tap(action("Pause Game Clock"))
    }

    func testCustomModulesCanBeReorderedAndScopedToOneTeam() {
        launch()
        openModePicker()
        tap(app.buttons["controlBoard.mode.custom"])
        for module in basketballModules where module != "scores" && module != "shotClock" {
            setModule(module, enabled: false)
        }
        let teams = app.descendants(matching: .any).matching(identifier: "controlBoard.teams").firstMatch
        tap(teams)
        let home = app.buttons["Home Team"].firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        tap(app.buttons["controlBoard.moveUp.scores"])
        tap(app.buttons["controlBoard.moveUp.scores"])
        XCTAssertFalse(app.buttons["controlBoard.moveUp.scores"].isEnabled)
        finishModePicker()
        let homeControls = mainWindow.otherElements["station.scores.home"]
        reveal(homeControls)
        tap(homeControls.buttons["action.+1"], anchor: homeControls)
        XCTAssertEqual(text(mainWindow.staticTexts["station.score.home"]), "1")
        XCTAssertFalse(mainWindow.otherElements["station.scores.guest"].exists)
        XCTAssertFalse(mainWindow.otherElements["controlBoard.panel.pauses"].exists)
        XCTAssertFalse(mainWindow.otherElements["live.officialPause"].exists)
        XCTAssertFalse(action("Start Game Clock").exists)
        selectMode("full")
        XCTAssertEqual(text(score("home")), "1")
        XCTAssertEqual(text(score("guest")), "0")
        selectMode("custom")
        XCTAssertFalse(mainWindow.otherElements["station.scores.guest"].exists)
        XCTAssertTrue(mainWindow.otherElements["station.scores.home"].exists)
    }

    func testModePreferencesAreSeparateForEachSport() {
        launch()
        selectMode("shotClock")
        openSettings()
        tap(mainWindow.buttons["settings.sport.soccer"])
        returnToBoard()
        XCTAssertEqual(text(app.buttons["controlBoard.chooseMode"].firstMatch), "Full Control Board")
        openModePicker()
        XCTAssertFalse(app.buttons["controlBoard.mode.shotClock"].exists)
        tap(app.buttons["controlBoard.mode.scoring"])
        finishModePicker()
        openSettings()
        tap(mainWindow.buttons["settings.sport.basketball"])
        returnToBoard()
        XCTAssertEqual(text(app.buttons["controlBoard.chooseMode"].firstMatch), "Shot / Serve Controller")
    }

    func testRosterStationEditsIdentityWithoutScoringControls() {
        launch()
        openSettings()
        tap(mainWindow.buttons["settings.pane.players"])
        setToggle("Enable Player/Foul Tracking", to: true)
        returnToBoard()
        selectMode("roster")
        let field = mainWindow.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "field.station-player-name-home-")).firstMatch
        reveal(field)
        enter("STATION PLAYER", in: field)
        selectMode("full")
        selectMode("roster")
        let saved = mainWindow.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "field.station-player-name-home-")).firstMatch
        reveal(saved)
        XCTAssertEqual(text(saved), "STATION PLAYER")
        XCTAssertFalse(action("+1").exists)
        XCTAssertFalse(action("Start Game Clock").exists)
    }

    func testAnEmptyCustomStationStillOffersTheModeSelector() {
        launch()
        openModePicker()
        tap(app.buttons["controlBoard.mode.custom"])
        for module in basketballModules { setModule(module, enabled: false) }
        finishModePicker()
        XCTAssertTrue(mainWindow.staticTexts["controlBoard.empty"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["controlBoard.chooseMode"].isHittable)
        selectMode("full")
        XCTAssertTrue(action("+1").exists)
    }

    func testRosterColumnsAndSummaryOptionKeepDisplayControlSeparate() {
        launch()
        openSettings()
        tap(mainWindow.buttons["settings.pane.players"])
        setToggle("Enable Player/Foul Tracking", to: true)
        returnToBoard()
        selectMode("roster")
        let home = mainWindow.otherElements["station.team.home"]
        let guest = mainWindow.otherElements["station.team.guest"]
        XCTAssertTrue(home.exists && guest.exists)
        XCTAssertEqual(home.frame.minY, guest.frame.minY, accuracy: 2, "Both rosters should start in columns")
        XCTAssertLessThanOrEqual(home.frame.maxX, guest.frame.minX)
        XCTAssertTrue(mainWindow.otherElements["controlBoard.summary"].exists)

        openModePicker()
        XCTAssertFalse(app.buttons["controlBoard.mode.display"].exists)
        setPickerToggle("controlBoard.showsSummary", enabled: false)
        finishModePicker()
        XCTAssertFalse(mainWindow.otherElements["controlBoard.summary"].exists)
        XCTAssertEqual(home.frame.minY, guest.frame.minY, accuracy: 2)
        selectMode("full")
        XCTAssertFalse(mainWindow.otherElements["controlBoard.summary"].exists)
        openModePicker()
        setPickerToggle("controlBoard.showsSummary", enabled: true)
        finishModePicker()
        XCTAssertTrue(mainWindow.otherElements["controlBoard.summary"].exists)
        tap(app.buttons["Display Control"].firstMatch)
        XCTAssertTrue(app.buttons["action.Back to Game"].exists || app.buttons["Back to Game"].exists)
    }

    func testMergedViewKeepsStationColumnsAndRunningClocks() {
        launch()
        tap(action("Start Game Clock"))
        selectMode("shotClock")
        openModePicker()
        setPickerToggle("controlBoard.mergedView", enabled: true)
        finishModePicker()
        XCTAssertTrue(mainWindow.staticTexts["public.clock"].exists)
        XCTAssertTrue(mainWindow.otherElements["controlBoard.summary"].exists)
        let home = mainWindow.otherElements["station.team.home"]
        let guest = mainWindow.otherElements["station.team.guest"]
        XCTAssertEqual(home.frame.minY, guest.frame.minY, accuracy: 2)
        XCTAssertLessThanOrEqual(home.frame.maxX, guest.frame.minX)
        let before = text(mainWindow.staticTexts["public.clock"])
        tap(action("Start Shot Clock"))
        waitUntil("The merged scoreboard must retain its running match clock") {
            self.text(self.mainWindow.staticTexts["public.clock"]) != before
        }
        tap(action("Shot Pause"))
        openModePicker()
        setPickerToggle("controlBoard.showsSummary", enabled: false)
        finishModePicker()
        XCTAssertFalse(mainWindow.otherElements["controlBoard.summary"].exists)
        XCTAssertTrue(mainWindow.staticTexts["public.clock"].exists)
        selectMode("full")
        XCTAssertTrue(action("Pause Game Clock").exists)
        XCTAssertFalse(mainWindow.otherElements["controlBoard.summary"].exists)
        tap(action("Pause Game Clock"))
    }

    func testHockeyPenaltySelectionUsesTheSharedSheetStyle() {
        launch("hockey")
        selectMode("penalties")
        let home = mainWindow.otherElements["station.penalties.home"]
        tap(home.buttons["action.Add 2:00"], anchor: home)
        let picker = app.otherElements["penalty.playerPicker"]
        let header = app.otherElements["penalty.playerPicker.header"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5) && header.exists)
        XCTAssertLessThan(header.frame.minY - picker.frame.minY, 40)
        XCTAssertTrue(app.buttons["penalty.cancel"].isHittable)
        tap(app.buttons["penalty.cancel"])
        XCTAssertFalse(home.buttons["action.Pause"].exists)
        tap(home.buttons["action.Add 2:00"], anchor: home)
        let player = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "penalty.player.")).firstMatch
        tap(player)
        waitUntil("Selecting a player must close the penalty picker") { !picker.exists }
        XCTAssertTrue(home.buttons["action.Pause"].exists)
        tap(home.buttons["action.Pause"], anchor: home)
    }
}
