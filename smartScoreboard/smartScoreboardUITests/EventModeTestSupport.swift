import XCTest

/// Shared UI operations. These helpers use real controls and observe rendered
/// values. Launch fixtures preload saved setup; actions after launch use the UI.
@MainActor
extension ScoreboardUITestCase {
    func settingsField(_ title: String, plain: Bool = false) -> XCUIElement {
        mainWindow.textFields["field.settings-\(plain ? "plain-text-entry" : "text-entry")-\(title)-"].firstMatch
    }

    func beginSetup(_ sport: String, event: String? = nil) {
        launch("setup")
        tap(mainWindow.buttons["settings.sport.\(sport)"])
        enter(event ?? "\(sport) Final 100% %@", in: settingsField("Event Name", plain: true))
        enter("Home 100%", in: settingsField("Home Team"))
        enter("Guest %@", in: settingsField("Guest Team"))
    }

    func assertField(_ title: String, equals expected: String, plain: Bool = false,
                     file: StaticString = #filePath, line: UInt = #line) {
        let field = settingsField(title, plain: plain)
        reveal(field, file: file, line: line)
        XCTAssertEqual(text(field).lowercased(), expected.lowercased(), title, file: file, line: line)
    }

    func toggle(_ title: String, in container: XCUIElement? = nil) -> XCUIElement {
        (container ?? mainWindow).switches["settings.toggle.\(title)"].firstMatch
    }

    func setToggle(_ title: String, to enabled: Bool, in container: XCUIElement? = nil) {
        let control = toggle(title, in: container)
        reveal(control, anchor: container)
        if text(control) != (enabled ? "1" : "0") {
            // SwiftUI exposes a wide wrapper and the actual switch thumb.
            // The wrapper's center can be blank space rather than the switch.
            let thumb = control.switches.firstMatch
            tap(thumb.exists ? thumb : control, anchor: control)
            waitUntil("\(title) must change to \(enabled)", timeout: 3) {
                self.text(control) == (enabled ? "1" : "0")
            }
        }
        assertToggle(title, equals: enabled, in: container)
    }

    func assertToggle(_ title: String, equals enabled: Bool, in container: XCUIElement? = nil,
                      file: StaticString = #filePath, line: UInt = #line) {
        let control = toggle(title, in: container)
        reveal(control, anchor: container, file: file, line: line)
        XCTAssertEqual(text(control), enabled ? "1" : "0", title, file: file, line: line)
    }

    func choose(_ title: String, option: String, in container: XCUIElement? = nil) {
        let scope = container ?? mainWindow
        // Reveal before deciding its style: a lazy offscreen segmented picker
        // may not exist in the accessibility tree yet.
        let picker = scope.descendants(matching: .any).matching(identifier: "settings.picker.\(title)").firstMatch
        reveal(picker, anchor: container)
        if picker.elementType == .segmentedControl {
            tap(picker.buttons[option].firstMatch, anchor: picker)
        } else {
            tap(picker, anchor: container)
            let item = app.buttons[option].firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 5), "Missing \(title) option: \(option)")
            // Native iPad menu rows can advertise a legacy Button type while
            // resolving to a Cell. A coordinate tap avoids that XCTest mismatch.
            item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    func assertChoice(_ title: String, equals option: String, in container: XCUIElement? = nil,
                      file: StaticString = #filePath, line: UInt = #line) {
        let scope = container ?? mainWindow
        let picker = scope.descendants(matching: .any).matching(identifier: "settings.picker.\(title)").firstMatch
        reveal(picker, anchor: container, file: file, line: line)
        if picker.elementType == .segmentedControl {
            XCTAssertTrue(picker.buttons[option].isSelected, title, file: file, line: line)
        } else {
            XCTAssertTrue((picker.label + " " + text(picker)).contains(option), title, file: file, line: line)
        }
    }

    func step(_ title: String, by delta: Int, in container: XCUIElement? = nil) {
        let stepper = (container ?? mainWindow).steppers["settings.stepper.\(title)"].firstMatch
        reveal(stepper, anchor: container)
        for _ in 0..<abs(delta) {
            let direction = delta > 0 ? "Increment" : "Decrement"
            tap(stepper.buttons["settings.stepper.\(title)-\(direction)"].firstMatch, anchor: stepper)
        }
    }

    func assertSettingValue(_ title: String, equals value: String, in container: XCUIElement? = nil,
                            file: StaticString = #filePath, line: UInt = #line) {
        let element = (container ?? mainWindow).staticTexts["settings.value.\(title)"].firstMatch
        reveal(element, anchor: container, file: file, line: line)
        XCTAssertEqual(text(element), value, title, file: file, line: line)
    }

    func controls(_ side: String = "home") -> XCUIElement {
        // Merged View wraps the full team card in the station column, whose
        // accessibility identifier replaces the card's original identifier.
        mainWindow.otherElements.matching(NSPredicate(format: "identifier IN %@", [
            "live.controls.\(side)", "station.team.\(side)"
        ])).firstMatch
    }

    func sideAction(_ title: String, side: String = "home") -> XCUIElement {
        controls(side).buttons["action.\(title)"].firstMatch
    }

    func tapSide(_ title: String, side: String = "home") {
        tap(sideAction(title, side: side), anchor: controls(side))
    }

    func metric(_ title: String) -> XCUIElement {
        mainWindow.staticTexts["live.metric.\(title)"].firstMatch
    }

    func assertScores(home: Int, guest: Int, file: StaticString = #filePath, line: UInt = #line) {
        waitUntil("Independent team scores must be \(home)-\(guest)", file: file, line: line) {
            self.score().exists && self.score("guest").exists
                && self.text(self.score()) == "\(home)" && self.text(self.score("guest")) == "\(guest)"
        }
    }

    func exerciseScores(steps: [Int]) {
        // A correction at zero must clamp to zero. Check both sides and every
        // configured score step, rather than just the first +1 button.
        tapSide("-1")
        assertScores(home: 0, guest: 0)
        var total = 0
        for amount in steps {
            addScore(amount)
            total += amount
            assertScores(home: total, guest: total - amount)
            addScore(amount, side: "guest")
            assertScores(home: total, guest: total)
        }
        tapSide("-1", side: "guest")
        assertScores(home: total, guest: total - 1)
        for amount in [2, 3] where !steps.contains(amount) {
            XCTAssertFalse(sideAction("+\(amount)").exists, "Unconfigured score buttons must be hidden")
        }
    }

    func respondToConfirmation(_ button: String) {
        tapAlertAction(button)
    }

    func exerciseSharedClock(countsUp: Bool = false) {
        XCTAssertTrue(clock.waitForExistence(timeout: 5))
        let before = clockSeconds(text(clock))
        tap(action("Start Game Clock"))
        waitUntil("The real \(countsUp ? "count-up" : "countdown") clock must advance") {
            guard self.clock.exists else { return false }
            let current = self.clockSeconds(self.text(self.clock))
            return countsUp ? current > before : current < before
        }
        tap(action("Pause Game Clock"))
        let paused = text(clock)
        tap(action("+1 Sec"))
        XCTAssertEqual(clockSeconds(text(clock)), clockSeconds(paused) + 1)
        tap(action("-1 Sec"))
        XCTAssertEqual(text(clock), paused)
    }

    func sideClock(_ side: String) -> XCUIElement {
        mainWindow.staticTexts["live.chess.\(side)"].firstMatch
    }

    func exerciseSideClocks(start: String = "Start Active Clock", pause: String = "Pause Active Clock",
                            switchAction: String = "Switch Turn", startsOn side: String = "home",
                            canSwitch: Bool = true) {
        let other = side == "home" ? "guest" : "home"
        XCTAssertTrue(sideClock(side).waitForExistence(timeout: 5))
        let initial = text(sideClock(side))
        let waiting = text(sideClock(other))
        tap(action(start))
        waitUntil("Only the active side clock must advance") { self.text(self.sideClock(side)) != initial }
        XCTAssertEqual(text(sideClock(other)), waiting)
        if canSwitch {
            tap(action(switchAction))
            let stopped = text(sideClock(side))
            waitUntil("Switching turns must advance the other side clock") { self.text(self.sideClock(other)) != waiting }
            XCTAssertEqual(text(sideClock(side)), stopped)
        }
        tap(action(pause))
        XCTAssertTrue(action(start).exists)
    }

    func clockSeconds(_ value: String) -> Int {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        XCTAssertTrue(parts.count == 2 || parts.count == 3, "Expected a clock, got \(value)")
        return parts.reduce(0) { $0 * 60 + $1 }
    }

    func segmentEditor(_ index: Int) -> XCUIElement {
        mainWindow.otherElements["settings.debate.segment.\(index)"].firstMatch
    }

    func segmentTitleField(_ index: Int) -> XCUIElement {
        segmentEditor(index).textFields.firstMatch
    }

    func assertSegment(_ position: Int, of count: Int, title: String? = nil,
                       file: StaticString = #filePath, line: UInt = #line) {
        let indicator = mainWindow.staticTexts["live.debate.position"].firstMatch
        reveal(indicator, file: file, line: line)
        XCTAssertEqual(text(indicator), "Segment \(position)/\(count)", file: file, line: line)
        if let title {
            XCTAssertEqual(text(mainWindow.staticTexts["live.debate.controls.title"].firstMatch), title,
                           file: file, line: line)
        }
    }
}
