import XCTest

/// Copied into an isolated project by record_demo_video.py. Never added to the release target.
@MainActor
final class DemoVideoUITests: ScoreboardUITestCase {
    private var recording = false

    private func host(_ endpoint: String, _ values: [String: String] = [:]) throws -> [String: Any] {
        var url = URLComponents(string: "http://127.0.0.1:18765/\(endpoint)")!
        url.queryItems = values.map { URLQueryItem(name: $0.key, value: $0.value) }
        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var response: Data?
        nonisolated(unsafe) var problem: Error?
        URLSession.shared.dataTask(with: url.url!) { data, _, error in
            response = data; problem = error; done.signal()
        }.resume()
        guard done.wait(timeout: .now() + 55) == .success else { throw NSError(domain: "DemoHostTimeout", code: 1) }
        if let problem { throw problem }
        let result = try JSONSerialization.jsonObject(with: response ?? Data()) as! [String: Any]
        if let error = result["error"] { XCTFail("Capture host: \(error)") }
        return result
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        executionTimeAllowance = 600
        app.launchEnvironment["SCOREBOARD_DEMO_CAPTURE"] = "1"
        app.launchEnvironment["SCOREBOARD_UI_TEST_CONFIGURATION"] = "{\"sport\":\"basketball\",\"eventName\":\"Community Cup Final\",\"homeTeamName\":\"North\",\"guestTeamName\":\"South\",\"clockSeconds\":480,\"period\":2}"
    }

    override func tearDownWithError() throws {
        if recording { _ = try? host("end", ["passed": (testRun?.totalFailureCount ?? 0) == 0 ? "true" : "false"]) }
        try super.tearDownWithError()
    }

    private func begin(_ id: String) throws {
        _ = try host("begin", ["id": id]); recording = true
        Thread.sleep(forTimeInterval: 1)
        try mark("opening")
    }
    private func mark(_ name: String) throws {
        Thread.sleep(forTimeInterval: 0.7)
        var values=["name":name]
        if clock.exists { values["operatorClock"]=text(clock) }
        _ = try host("mark", values)
    }
    private func finish() throws {
        try mark("ending"); Thread.sleep(forTimeInterval: 1.5)
        _ = try host("end", ["passed": "true"]); recording = false
    }
    @discardableResult private func pairReceiver(record: Bool = false, control: Bool = false) throws -> String {
        let info = try host(control ? "control-receiver" : "receiver")
        _ = try XCTUnwrap(info["code"] as? String)
        let receiverID = try XCTUnwrap(info["displayID"] as? String)
        if record { try begin("07-remote-display-control") }
        openIntegration("remoteDisplay")
        setToggle("Enable Remote Display / Control Pairing", to: true)
        let field = mainWindow.textFields["remote.code.\(receiverID)"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20), "Second simulator must advertise its real receiver")
        reveal(field)
        if record { try mark("pairing-code") }
        let row = mainWindow.otherElements["remote.peer.\(receiverID)"].firstMatch
        // Codes rotate in the actual receiver; fetch just before entry, after navigation.
        for _ in 0..<5 {
            let current = try host(control ? "control-status" : "status")
            if current["homeScore"] != nil { break }
            let code = try XCTUnwrap(current["code"] as? String)
            enter(code, in: field, submit: false)
            let after = try host(control ? "control-status" : "status")
            if (after["code"] as? String) != code { continue }
            let pair = row.buttons["Pair"].firstMatch
            DemoTouch.record(pair, window: mainWindow)
            pair.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            var paired=false
            for _ in 0..<48 {
                let status=try host(control ? "control-status" : "status")
                if status["homeScore"] != nil { paired=true; break }
                Thread.sleep(forTimeInterval: 0.25)
            }
            if paired { break }
        }
        XCTAssertTrue(row.buttons["Disconnect"].waitForExistence(timeout: 20))
        if record { try mark("paired") }
        returnToBoard()
        dismissKeyboard()
        return receiverID
    }
    private func pane(_ name: String) { tap(mainWindow.buttons["settings.pane.\(name)"]) }
    private func dismissKeyboard() {
        let button = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'hide keyboard' OR label CONTAINS[c] 'dismiss keyboard'")).firstMatch
        if button.exists { button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
    }
    private func menuItem(_ label: String) {
        let item = app.buttons[label].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        DemoTouch.record(item, window: mainWindow)
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    private func mode(_ name: String) {
        tap(app.buttons["controlBoard.chooseMode"].firstMatch)
        tap(app.buttons["controlBoard.mode.\(name)"])
        tap(app.buttons["controlBoard.done"])
    }
    private func syncedScore(_ value: Int) throws {
        var observed = -1
        for _ in 0..<30 {
            let data = try host("status")
            observed = data["homeScore"] as? Int ?? -1
            if observed == value { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertEqual(observed, value, "Real receiver must show the operator's score")
    }

    func test01Result() throws {
        launch(); try pairReceiver(); try begin("01-result")
        addScore(2); try syncedScore(44); try mark("score-updates-both-devices")
        tap(action("Start Game Clock")); Thread.sleep(forTimeInterval: 2)
        tapSide("Shot 24", side: "guest"); try mark("clock-and-possession")
        tap(action("Pause Game Clock")); try finish()
    }

    func test02Setup() throws {
        launch(); try begin("02-game-setup"); openSettings(); pane("game")
        tap(mainWindow.buttons["settings.sport.basketball"])
        enter("Community Cup Final", in: settingsField("Event Name", plain: true))
        enter("North", in: settingsField("Home Team")); enter("South", in: settingsField("Guest Team"))
        try mark("names-and-clock"); returnToBoard(); try finish()
    }

    func test03LiveControls() throws {
        launch(); try pairReceiver(); try begin("03-live-controls")
        addScore(2); addScore(3, side: "guest"); try syncedScore(44); try mark("score")
        tap(action("Start Game Clock")); Thread.sleep(forTimeInterval: 2)
        tapSide("Shot 24"); try mark("shot-clock")
        tap(action("Pause Game Clock")); tapSide("Shot 14", side: "guest")
        let next = mainWindow.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'action.Next '")).firstMatch
        tap(next); if app.alerts.firstMatch.exists { tapAlertAction(next.label) }
        try mark("next-period")
        try finish()
    }

    func test04AudienceViews() throws {
        launch(); try pairReceiver(); try begin("04-audience-views")
        tap(mainWindow.buttons["Display Control"].firstMatch)
        try mark("display-control")
        for title in ["Scoreboard", "Player View", "Team View", "Event Logo", "Black Screen", "Scoreboard"] {
            tap(mainWindow.buttons[title].firstMatch); try mark(title.lowercased().replacingOccurrences(of: " ", with: "-"))
        }
        tap(mainWindow.buttons.matching(NSPredicate(format: "label == 'Back to Game'")).firstMatch)
        try finish()
    }

    func test05PlayersAndStations() throws {
        launch(); try pairReceiver(); try begin("05-players-and-stations")
        openSettings(); pane("players")
        setToggle("Enable Player/Foul Tracking", to: true)
        let name = mainWindow.textFields.matching(NSPredicate(format: "identifier BEGINSWITH 'field.player-name-home-'")).firstMatch
        enter("Alex Morgan", in: name); try mark("roster-and-lineup"); returnToBoard()
        tap(mainWindow.buttons["Open Players"].firstMatch)
        tap(action("+")); try mark("player-foul")
        tap(action("Bench")); try mark("lineup-change")
        let back = mainWindow.buttons["Back to Game"].firstMatch
        if back.exists { tap(back) }
        mode("roster"); try mark("roster-station")
        mode("shotClock"); tap(action("Start Shot Clock")); try mark("shot-clock-station")
        tap(action("Shot Pause")); mode("full"); try finish()
    }

    func test06Sports() throws {
        launch(); try begin("06-sports")
        openSettings(); try mark("sport-choices")
        for sport in ["soccer", "hockey", "chess", "debate", "custom"] {
            tap(mainWindow.buttons["settings.sport.\(sport)"]); try mark("\(sport)-setup")
            returnToBoard()
            if sport == "soccer" {
                tap(mainWindow.buttons["Open Players"].firstMatch)
                tap(action("Y"))
            } else if sport == "hockey" {
                tap(sideAction("Add 2:00"))
                let player = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'penalty.player.'")).firstMatch
                if player.waitForExistence(timeout: 3) { tap(player) }
            } else if sport == "chess" {
                tap(action("Start Active Clock")); Thread.sleep(forTimeInterval: 1)
                tap(action("Switch Turn")); tap(action("Pause Active Clock"))
            } else if sport == "debate" {
                // Capture the real segment/prep controls without skipping through speeches.
            }
            try mark("\(sport)-controls")
            if sport == "hockey", sideAction("Pause").exists { tap(sideAction("Pause")) }
            openSettings(); pane("game")
        }
        for (title, name) in [("Score Tracking", "custom-score-clock"), ("Secondary Timer", "custom-period-timer"),
                              ("Player Tracking", "custom-possession-players"), ("Team Fouls", "custom-team-counters")] {
            reveal(toggle(title)); try mark(name)
        }
        try finish()
    }

    func test07RemoteDisplayAndControl() throws {
        launch(); try pairReceiver(record: true)
        addScore(3); try syncedScore(45); try mark("remote-score-updates")
        let controlID = try pairReceiver(control: true)
        openSettings(); pane("integration"); tap(mainWindow.buttons["settings.integration.remoteDisplay"])
        let row=mainWindow.otherElements["remote.peer.\(controlID)"].firstMatch
        setToggle("Allow This Device to Control", to: true, in: row); try mark("per-device-control-permission")
        _ = try host("remote-action")
        try mark("paired-ipad-controls-the-game")
        returnToBoard(); try finish()
    }

    func test08Livestream() throws {
        launch(); try begin("08-livestream-tools")
        openIntegration("webAPI")
        let webToggle=toggle("Enable HTTP 5516 and WebSocket 5517")
        reveal(webToggle)
        let webThumb=webToggle.switches.firstMatch
        tap(webThumb.exists ? webThumb : webToggle)
        XCTAssertTrue(app.buttons["Agree"].firstMatch.waitForExistence(timeout: 15))
        tap(app.buttons["Agree"].firstMatch)
        assertToggle("Enable HTTP 5516 and WebSocket 5517", equals: true)
        try mark("web-api")
        // The host records real bundled pages against this running app's HTTP service.
        _ = try host("web")
        pane("integration"); tap(mainWindow.buttons["settings.integration.bitfocusCompanion"])
        let companion=toggle("Show Companion")
        reveal(companion)
        let companionThumb=companion.switches.firstMatch
        tap(companionThumb.exists ? companionThumb : companion)
        XCTAssertTrue(app.buttons["Agree"].firstMatch.waitForExistence(timeout: 15))
        tap(app.buttons["Agree"].firstMatch)
        assertToggle("Show Companion", equals: true)
        let group = mainWindow.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Timer Start'")).firstMatch
        tap(group)
        let location = mainWindow.textFields["field.companion-location-basketball-gameClockStarted"].firstMatch
        enter("1:0:1", in: location)
        try mark("companion-event-mapping"); try finish()
    }

    func test09AppearanceAndSound() throws {
        launch(); try pairReceiver(); try begin("09-appearance-sound")
        openSettings(); pane("theme"); try mark("themes")
        let classic = mainWindow.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Default'")).firstMatch
        tap(classic); try mark("theme-changed")
        setToggle("Show Date/Time", to: true); try mark("date-and-time")
        pane("display"); try mark("logos")
        setToggle("Turn Game Clock Red", to: true)
        try mark("clock-warnings")
        pane("sound"); setToggle("Sound", to: true)
        tap(mainWindow.buttons["Available Sounds"].firstMatch)
        tap(mainWindow.buttons["Test: Classic Buzzer"].firstMatch)
        try mark("sound-preview"); try finish()
    }

    func test10LibraryAndLogs() throws {
        launch(); addScore(2); tap(action("Start Game Clock")); Thread.sleep(forTimeInterval: 1); tap(action("Pause Game Clock"))
        try begin("10-library-logs"); openSettings(); pane("files"); try mark("library-backup-restore")
        tap(mainWindow.buttons["Duplicate Current Setup"].firstMatch); try mark("saved-game")
        pane("logs"); try mark("game-logs")
        let session = mainWindow.buttons.matching(NSPredicate(format: "label CONTAINS 'Community Cup'")).firstMatch
        if session.exists { tap(session); try mark("log-detail-export") }
        tap(mainWindow.buttons["Export"].firstMatch); try mark("log-export-options")
        mainWindow.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.2)).tap()
        returnToBoard(); try finish()
    }
}

/// Run only on the second simulator, after the owner grants control.
@MainActor
final class DemoReceiverUITests: XCTestCase {
    func testAuthorizedRemoteScoring() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.activate()
        let controls = app.otherElements["live.controls.home"].firstMatch
        XCTAssertTrue(controls.waitForExistence(timeout: 20))
        let score = app.staticTexts["live.score.home"].firstMatch
        XCTAssertEqual(score.label, "45")
        let button = controls.buttons["action.+1"].firstMatch
        XCTAssertTrue(button.isHittable)
        DemoTouch.record(button, window: app.windows.firstMatch, device: "controller")
        button.tap()
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in score.label == "46" }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 15), .completed)
    }
}

@MainActor
enum DemoTouch {
    static func record(_ element: XCUIElement, window: XCUIElement, device: String = "operator", at point: CGPoint? = nil) {
        guard element.exists else { return }
        let frame = window.frame
        let position = point ?? CGPoint(x: element.frame.midX, y: element.frame.midY)
        var url = URLComponents(string: "http://127.0.0.1:18765/touch")!
        url.queryItems = [URLQueryItem(name: "x", value: String((position.x-frame.minX)/frame.width)),
                          URLQueryItem(name: "y", value: String((position.y-frame.minY)/frame.height)),
                          URLQueryItem(name: "device", value: device),
                          URLQueryItem(name: "label", value: element.label)]
        // Fire before the actual touch; the coordinator timestamps it on receipt.
        let ready = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: url.url!) { _, _, _ in ready.signal() }.resume()
        _ = ready.wait(timeout: .now()+1)
    }
}
