import XCTest

@MainActor
final class MatchNavigationUITests: ScoreboardUITestCase {
    func testFileHomeSeparateSettingsAndKioskNavigation() {
        executionTimeAllowance = 180
        launch("setup", opensBoard: false)
        XCTAssertTrue(app.buttons["home.new"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home.open"].exists)
        XCTAssertTrue(app.buttons["home.connect"].exists)
        XCTAssertFalse(app.buttons["home.continue"].exists)
        XCTAssertTrue(app.staticTexts["home.version"].exists)
        XCTAssertTrue(app.staticTexts["home.version"].label.contains("Build"))
        XCTAssertEqual(app.staticTexts["home.cloudStatus"].label, "Cloud · Off")
        capture("File Home before creating a scoreboard")

        tap(app.buttons["home.new"])
        let name = app.textFields["home.newName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        tap(app.buttons["home.create"])
        XCTAssertTrue(app.staticTexts["settings.title.game"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["settings.pane.cloud"].exists)
        XCTAssertFalse(app.buttons["settings.pane.sound"].exists)
        capture("Game Settings contain only file settings")
        returnToBoard()
        addScore(1)
        XCTAssertEqual(text(score()), "1")

        openAppSettings()
        XCTAssertTrue(app.staticTexts["settings.title.general"].exists)
        XCTAssertFalse(app.buttons["settings.pane.game"].exists)
        selectSettingsSection("cloud")
        XCTAssertTrue(app.staticTexts["settings.title.cloud"].exists)
        let enableCloud = app.switches["Enable Cloud"].firstMatch
        XCTAssertTrue(enableCloud.waitForExistence(timeout: 5))
        tap(enableCloud)
        capture("Separate App Settings")
        returnToBoard()
        goHome()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["home.cloudStatus"].label, "Cloud · Not Signed In")
        capture("File Home with a saved scoreboard")
        tap(app.buttons["library.actions"].firstMatch)
        tapMenuAction("Duplicate")
        XCTAssertEqual(app.buttons.matching(identifier: "library.actions").count, 2)

        tap(app.buttons["home.connect"])
        XCTAssertTrue(app.buttons["join.openInvitation"].waitForExistence(timeout: 5))
        tap(app.buttons["join.openInvitation"])
        XCTAssertTrue(app.textFields["join.matchCode"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["join.submit"].isEnabled)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["join.openInvitation"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Done"].tap()
        tap(app.buttons["home.continue"])
        XCTAssertEqual(text(score()), "1")
        goHome()

        tap(app.buttons["home.settings"])
        tapMenuAction("Switch to Kiosk Mode")
        let change = app.buttons["Use Kiosk Mode"].firstMatch
        XCTAssertTrue(change.waitForExistence(timeout: 5))
        change.tap()
        XCTAssertTrue(app.staticTexts["kiosk.mode"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["kiosk.mode"].label, "iPad · Kiosk Mode")
        XCTAssertTrue(app.staticTexts["home.version"].exists)
        XCTAssertEqual(app.staticTexts["home.cloudStatus"].label, "Cloud · Ready to Join")
        XCTAssertFalse(app.buttons["home.new"].exists)
        capture("Shared iPad kiosk home")
        tap(app.buttons["tv.settings"])
        XCTAssertTrue(app.buttons["remote.cloud.selfHosted"].waitForExistence(timeout: 5))
        tap(app.buttons["remote.cloud.selfHosted"])
        XCTAssertTrue(app.textFields["remote.cloud.selfHostedURL"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["kiosk.mode"].waitForExistence(timeout: 5))
    }

    private func goHome() {
        tap(mainWindow.buttons["Settings"].firstMatch)
        tapMenuAction("Home")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: mainWindow.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
