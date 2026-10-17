import XCTest

@MainActor
final class IntegrationRecoveryUITests: ScoreboardUITestCase {
    // 84d3617: a failed Companion command must be visible without freezing play,
    // and a later event must work after the production endpoint returns.
    func testCompanionDisconnectRecoveryAndOperatorToggle() throws {
        let peer = CompanionPeer()
        networkDiagnostics = { "HTTP methods: \(peer.methods); paths: \(peer.paths)" }
        try peer.start()
        defer { peer.stop() }
        waitUntil("Companion fixture starts") { peer.ready }
        app.launchEnvironment["SCOREBOARD_UI_TEST_COMPANION_PORT"] = String(peer.port)
        launch()
        openIntegration("bitfocusCompanion")
        tap(mainWindow.switches["settings.toggle.Show Companion"])
        tap(mainWindow.buttons["Agree"].firstMatch)
        tap(mainWindow.switches["settings.toggle.Enable Companion"])
        returnToBoard()
        XCTAssertTrue(mainWindow.buttons["Companion On"].waitForExistence(timeout: 5))
        tap(action("Start Game Clock"))
        waitUntil("The real Companion endpoint must receive the clock-start event") { peer.paths.contains("/api/location/1/0/1/press") }
        tap(action("Pause Game Clock"))
        peer.stop()
        addScore()
        let failureDismiss = mainWindow.buttons["Dismiss Companion failure"]
        XCTAssertTrue(failureDismiss.waitForExistence(timeout: 8))
        XCTAssertEqual(text(score()), "1", "A disconnected automation endpoint must not block the score")
        if failureDismiss.exists { tap(failureDismiss) }
        try peer.start()
        waitUntil("Companion fixture reconnects") { peer.ready }
        addScore()
        waitUntil("A subsequent event must reach Companion after reconnecting") { peer.paths.contains("/api/location/1/0/2/press") }
        XCTAssertEqual(text(score()), "2")
        tap(mainWindow.buttons["Companion On"])
        let sent = peer.paths.count
        let suppressed = expectation(description: "Disabled Companion must not send another HTTP request")
        suppressed.isInverted = true
        peer.onRequest = { suppressed.fulfill() }
        addScore()
        XCTAssertEqual(text(score()), "3")
        wait(for: [suppressed], timeout: 0.75)
        XCTAssertTrue(peer.methods.allSatisfy { $0 == "POST" })
        XCTAssertEqual(peer.paths.count, sent, "Companion Off must stop outbound event commands")
    }

    // c8b48ff, cfe761b, 1e3f5de: pairing must survive a dropped client, recover
    // without a new code, and continue publishing the latest match afterwards.
    func testRemoteDisplayPairDisconnectReconnectAndContinueEvent() throws {
        let peer = RemoteDisplayPeer()
        networkDiagnostics = { peer.diagnostics }
        try peer.start()
        defer { peer.stop() }
        waitUntil("Remote display advertises on Bonjour") { peer.ready }
        launch()
        openIntegration("remoteDisplay")
        tap(mainWindow.switches["settings.toggle.Enable Remote Display / Control Pairing"])
        let code = mainWindow.textFields["remote.code.\(peer.id)"]
        XCTAssertTrue(code.waitForExistence(timeout: 15), "The real browser must discover the test client")
        enter(peer.pairingCode, in: code, submit: false)
        let row = mainWindow.otherElements["remote.peer.\(peer.id)"].firstMatch
        tap(row.buttons["Pair"].firstMatch)
        waitUntil("Pairing and live state must reach the client", timeout: 15) { peer.pairingCount > 0 && peer.stateCount > 0 }
        XCTAssertTrue(row.buttons["Disconnect"].waitForExistence(timeout: 10))
        returnToBoard()
        addScore()
        waitUntil("The public client must receive the operator's score") { peer.homeScore == 1 }
        peer.stop()
        XCTAssertTrue(mainWindow.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'disconnect' OR label CONTAINS[c] 'not responding'")).firstMatch.waitForExistence(timeout: 10))
        tap(mainWindow.buttons["Dismiss Remote Display warning"])
        addScore()
        XCTAssertEqual(text(score()), "2", "Local scoring stays responsive while the client is offline")
        let oldPairings = peer.pairingCount
        try peer.start()
        waitUntil("Trusted client must reconnect without another pairing code", timeout: 20) { peer.pairingCount > oldPairings && peer.homeScore == 2 }
        openIntegration("remoteDisplay")
        tap(row.buttons["Disconnect"].firstMatch)
        waitUntil("The operator's disconnect must reach the remote client") { peer.operatorDisconnectCount > 0 }
        waitUntil("Disconnected saved display offers Connect") { row.buttons["Connect"].exists }
        tap(row.buttons["Connect"].firstMatch)
        waitUntil("Explicit Connect restores the saved pairing") { row.buttons["Disconnect"].exists }
        returnToBoard()
        addScore()
        waitUntil("Reconnected client receives current event updates") { peer.homeScore == 3 }
        XCTAssertTrue(peer.errors.isEmpty, "Pairing protocol errors: \(peer.errors)")
    }
}
