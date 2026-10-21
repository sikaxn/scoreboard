import XCTest
import UIKit

@MainActor
final class DisplayLayoutUITests: ScoreboardUITestCase {
    private func rotate(to orientation: UIDeviceOrientation, landscape: Bool) {
        XCUIDevice.shared.orientation = orientation
        waitUntil("The app must adopt the requested iPad layout") {
            let frame = self.mainWindow.frame
            return landscape ? frame.width > frame.height : frame.height > frame.width
        }
    }

    // 57b98ea/f9f89bc/f395c74: settings and merged headers must stay reachable
    // when the actual iPad viewport changes between portrait and landscape.
    func testMergedViewRemainsUsableAcrossPortraitAndLandscape() {
        launch()
        openSettings()
        tap(app.buttons["settings.pane.theme"])
        tap(app.switches["settings.toggle.Merged View (Beta)"])
        returnToBoard()
        addScore(2)
        tap(action("Start Game Clock"))
        for orientation: UIDeviceOrientation in [.portrait, .landscapeRight, .landscapeLeft] {
            rotate(to: orientation, landscape: orientation != .portrait)
            let before = text(clock)
            addScore()
            XCTAssertTrue(app.buttons["Settings"].firstMatch.isHittable)
            waitUntil("Rotation must not stop the match clock") { self.text(self.clock) != before }
        }
        XCTAssertEqual(text(score()), "5")
        tap(action("Pause Game Clock"))
        openSettings()
        returnToBoard()
        XCTAssertEqual(text(score()), "5")
    }

    // 234db78: the real timer must continue while the operator scrolls settings.
    func testScrollingSettingsDoesNotSuspendTheLiveTimer() {
        launch()
        tap(action("Start Game Clock"))
        let before = text(clock)
        openSettings()
        let content = mainWindow.scrollViews.element(boundBy: mainWindow.scrollViews.count - 1)
        for _ in 0..<4 { content.swipeUp() }
        for _ in 0..<4 { content.swipeDown() }
        returnToBoard()
        XCTAssertTrue(action("Pause Game Clock").exists)
        XCTAssertNotEqual(text(clock), before)
        tap(action("Pause Game Clock"))
    }

    func testFullScreenDisplayTracksClockAndReopensWithCurrentScore() {
        launch()
        addScore(3)
        tap(action("Start Game Clock"))
        openLocalDisplay()
        let display = mainWindow.otherElements["display.local-scoreboard"]
        XCTAssertTrue(display.waitForExistence(timeout: 5))
        waitUntil("Full-screen display shows the real game score") {
            self.text(display.staticTexts["public.score.home"]) == "3"
        }
        let publicClock = display.staticTexts["public.clock"]
        let before = text(publicClock)
        waitUntil("Full-screen display's clock updates") { self.text(publicClock) != before }
        rotate(to: .portrait, landscape: false)
        XCTAssertEqual(text(display.staticTexts["public.score.home"]), "3")
        display.tap()
        waitUntil("Tapping the scoreboard returns to the controls") { !display.exists }
        addScore()
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertEqual(text(score()), "4", "Backgrounding must preserve the running event")
        rotate(to: .landscapeLeft, landscape: true)
        openLocalDisplay()
        waitUntil("Reopening the display shows current state without resetting play") {
            self.text(display.staticTexts["public.score.home"]) == "4"
        }
    }

    private func openLocalDisplay() {
        tap(mainWindow.buttons["Local Display"].firstMatch)
        tapMenuAction("Full Screen")
        XCTAssertTrue(mainWindow.otherElements["display.local-scoreboard"].waitForExistence(timeout: 5))
    }

    func testWindowResizeKeepsScoringAndClockUsable() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Windowed Apps requires iPadOS 26 or newer") }
        launch()
        let original = mainWindow.frame
        addScore()
        tap(action("Start Game Clock"))
        let before = text(clock)
        let corner = mainWindow.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
            .withOffset(CGVector(dx: -12, dy: -12))
        corner.press(forDuration: 0.2, thenDragTo: corner.withOffset(CGVector(dx: -300, dy: -160)))
        waitUntil("Dragging the system resize handle must change the app window") {
            self.mainWindow.frame.width < original.width - 100
        }
        addScore()
        XCTAssertEqual(text(score()), "2")
        waitUntil("The real clock must advance in a resized window") { self.text(self.clock) != before }
        maximizeWindow()
        tap(action("Pause Game Clock"))
        openSettings()
        returnToBoard()
        XCTAssertEqual(text(score()), "2")
    }
}
