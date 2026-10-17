import XCTest

@MainActor
class ScoreboardUITestCase: XCTestCase {
    var app: XCUIApplication!
    var mainWindow: XCUIElement { app.windows.firstMatch }
    var networkDiagnostics: (() -> String)?

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 300
        app = XCUIApplication()
        app.launchEnvironment["SCOREBOARD_UI_TEST_ID"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-ApplePersistenceIgnoreState", "YES"]
        XCUIDevice.shared.orientation = .landscapeLeft
        addUIInterruptionMonitor(withDescription: "Local network access") { alert in
            let allow = alert.buttons["Allow"]
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
    }

    override func tearDownWithError() throws {
        if let app, (testRun?.failureCount ?? 0) > 0, app.state != .notRunning {
            if let networkDiagnostics {
                let diagnostics = XCTAttachment(string: networkDiagnostics())
                diagnostics.name = "Local network peer diagnostics"
                diagnostics.lifetime = .keepAlways
                add(diagnostics)
            }
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "Accessibility hierarchy"
            tree.lifetime = .keepAlways
            add(tree)
            let screenshot = XCTAttachment(screenshot: mainWindow.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        app?.terminate()
        XCUIDevice.shared.orientation = .portrait
        app = nil
        networkDiagnostics = nil
    }

    func launch(_ scenario: String = "basketball") {
        app.launchEnvironment["SCOREBOARD_UI_TEST_SCENARIO"] = scenario
        app.launch()
        app.activate()
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 15))
        if #available(iOS 26.0, *), mainWindow.frame.minX > 1 || mainWindow.frame.minY > 1 {
            maximizeWindow()
        }
    }

    func maximizeWindow() {
        // iPadOS's documented double-tap on the title bar restores full screen.
        mainWindow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: 0, dy: 12)).doubleTap()
        waitUntil("The simulator app window must return to full screen") {
            self.mainWindow.frame.minX < 1 && self.mainWindow.frame.minY < 1
        }
    }

    func waitUntil(_ message: String, timeout: TimeInterval = 12,
                   file: StaticString = #filePath, line: UInt = #line,
                   _ condition: @escaping () -> Bool) {
        if condition() { return }
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, message, file: file, line: line)
    }

    func reveal(_ element: XCUIElement, anchor: XCUIElement? = nil,
                file: StaticString = #filePath, line: UInt = #line) {
        var searchUp = true
        var previousFrames: String?
        var previousDirection: Bool?
        for _ in 0..<16 {
            if app.state != .runningForeground { app.activate() }
            let owner = containingScrollView(element) ?? anchor.flatMap { containingScrollView($0) }
            let viewport = owner?.frame.intersection(mainWindow.frame) ?? mainWindow.frame
            // Asking isHittable for a clipped lazy-grid item can itself fail
            // XCTest. Reveal its frame first, then ask for a hit point.
            if element.exists, fitsViewport(element.frame, viewport), element.isHittable { return }

            if !element.exists, let anchor, anchor.exists,
               anchor.frame.height < viewport.height, fitsViewport(anchor.frame, viewport) {
                XCTFail("Missing control inside its visible container: \(element)", file: file, line: line)
                return
            }
            let content = mainWindow.scrollViews["settings.content"]
            let scrollView = owner ?? (content.exists ? content : mainWindow.scrollViews.firstMatch)
            guard scrollView.exists else {
                XCTFail("No scroll container can reveal: \(element)", file: file, line: line)
                return
            }
            let target = element.exists ? element : (anchor ?? element)
            let hasKnownFrame = target.exists && !target.frame.isEmpty
                && (element.exists || target.frame.height <= scrollView.frame.height
                    || !target.frame.intersects(scrollView.frame))
            var above = hasKnownFrame ? target.frame.minY < scrollView.frame.minY : searchUp
            let frames = scrollFrameSignature(scrollView)
            if frames == previousFrames, above == previousDirection {
                if !hasKnownFrame && searchUp {
                    // An unrealized item may be above the current position.
                    // Search upward to the boundary, then downward once.
                    searchUp = false
                    above = false
                } else {
                    XCTFail("Scrolling stopped making progress while revealing: \(element)", file: file, line: line)
                    return
                }
            }
            previousFrames = frames
            previousDirection = above
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.35 : 0.75))
            let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.75 : 0.35))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
        }
        XCTFail("Control is not reachable: \(element)", file: file, line: line)
    }

    private func containingScrollView(_ element: XCUIElement) -> XCUIElement? {
        guard element.exists else { return nil }
        let key = element.identifier.isEmpty ? element.label : element.identifier
        guard !key.isEmpty else { return nil }
        let container = mainWindow.scrollViews.containing(element.elementType, identifier: key).firstMatch
        return container.exists ? container : nil
    }

    private func fitsViewport(_ frame: CGRect, _ viewport: CGRect) -> Bool {
        guard !frame.isEmpty, !viewport.isEmpty else { return false }
        let visible = frame.intersection(viewport)
        return !visible.isEmpty
            && viewport.contains(CGPoint(x: frame.midX, y: frame.midY))
            && visible.width >= min(frame.width, viewport.width) - 1
            && visible.height >= min(frame.height, viewport.height) - 1
    }

    private func scrollFrameSignature(_ scrollView: XCUIElement) -> String {
        // One hierarchy snapshot per gesture, rather than querying every child.
        // Strip addresses and values so a ticking timer is not mistaken for
        // scroll progress. At a boundary the layout frames stay unchanged.
        scrollView.debugDescription.split(separator: "\n").compactMap { line -> String? in
            let line = String(line)
            guard let start = line.range(of: "{{"),
                  let end = line.range(of: "}}", range: start.lowerBound..<line.endIndex) else { return nil }
            return String(line[start.lowerBound..<end.upperBound])
        }.joined(separator: "|")
    }

    func tap(_ element: XCUIElement, anchor: XCUIElement? = nil,
             file: StaticString = #filePath, line: UInt = #line) {
        if !element.exists { _ = element.waitForExistence(timeout: 0.5) }
        reveal(element, anchor: anchor, file: file, line: line)
        XCTAssertTrue(element.exists, "Missing control: \(element)", file: file, line: line)
        waitUntil("Control must become enabled", file: file, line: line) { element.isEnabled }
        element.tap()
    }

    func enter(_ text: String, in field: XCUIElement, submit: Bool = true) {
        reveal(field)
        XCTAssertTrue(field.isEnabled)
        // A tap beyond the final glyph places the caret at the end even when
        // the field's center would place it in the middle of existing text.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).tap()
        if let value = field.value as? String, !value.isEmpty, value != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
            waitUntil("The existing field value must be cleared before typing", timeout: 3) {
                self.fieldIsEmpty(field)
            }
        }
        field.typeText(text + (submit ? "\n" : ""))
        waitUntil("The text field must contain the replacement value", timeout: 3) {
            guard field.exists else { return false }
            return text.isEmpty ? self.fieldIsEmpty(field)
                : (field.value as? String)?.lowercased() == text.lowercased()
        }
    }

    private func fieldIsEmpty(_ field: XCUIElement) -> Bool {
        guard let value = field.value as? String else { return true }
        return value.isEmpty || value == field.placeholderValue
    }

    func text(_ element: XCUIElement) -> String {
        if element.elementType == .staticText { return element.label }
        return element.value as? String ?? element.label
    }
    func action(_ title: String) -> XCUIElement { mainWindow.buttons["action.\(title)"].firstMatch }
    func score(_ side: String = "home") -> XCUIElement {
        let live = mainWindow.staticTexts["live.score.\(side)"].firstMatch
        return live.exists ? live : mainWindow.staticTexts["public.score.\(side)"].firstMatch
    }
    var clock: XCUIElement {
        let live = mainWindow.staticTexts["live.clock"].firstMatch
        return live.exists ? live : mainWindow.staticTexts["public.clock"].firstMatch
    }

    func addScore(_ amount: Int = 1, side: String = "home") {
        let controls = mainWindow.otherElements["live.controls.\(side)"].firstMatch
        tap(controls.buttons["action.+\(amount)"].firstMatch, anchor: controls)
    }

    func openSettings() {
        tap(mainWindow.buttons["Settings"].firstMatch)
        // A segment, prep, side, or secondary clock can also trigger this warning.
        let confirmation = app.alerts.firstMatch
        let gamePane = mainWindow.buttons["settings.pane.game"]
        waitUntil("Settings or its running-timer confirmation must appear") {
            gamePane.exists || confirmation.exists
        }
        if confirmation.exists {
            tapAlertAction("Open Settings")
        }
        XCTAssertTrue(mainWindow.buttons["settings.pane.game"].waitForExistence(timeout: 10))
    }

    func tapAlertAction(_ title: String) {
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        // SwiftUI can expose a native alert action as Button in its legacy
        // attributes and PopUpButton in its modern attributes. Resolve by
        // label, then tap its coordinate so XCTest does not misclassify the
        // alert as an interruption and automatically press Cancel.
        let action = alert.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 3), "Missing alert action: \(title)")
        XCTAssertTrue(action.isEnabled)
        action.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitUntil("The confirmation must dismiss") { !alert.exists }
    }

    func returnToBoard() {
        tap(mainWindow.buttons.matching(NSPredicate(format: "label IN %@", ["Go to Control Board", "Back to Live Board"])).firstMatch)
        waitUntil("The live board must return for the selected event mode") {
            self.mainWindow.buttons["Settings"].firstMatch.exists
                && !self.mainWindow.buttons["settings.pane.game"].exists
        }
    }

    func openIntegration(_ name: String) {
        openSettings()
        tap(mainWindow.buttons["settings.pane.integration"])
        tap(mainWindow.buttons["settings.integration.\(name)"])
    }
}
