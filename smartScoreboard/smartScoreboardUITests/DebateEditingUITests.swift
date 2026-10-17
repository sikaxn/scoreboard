import XCTest

@MainActor
final class DebateEditingUITests: ScoreboardUITestCase {
    func testPublicForumRoundWithScoresAndBothPrepClocks() throws {
        try exercisePreset("Public Forum", segments: publicForumSegments, score: true, prep: true, players: false)
    }

    func testLincolnDouglasRoundWithPlayersAndNoPrep() throws {
        try exercisePreset("Lincoln-Douglas", segments: lincolnDouglasSegments, score: false, prep: false, players: true)
    }

    func testPolicyRoundWithScoresPlayersAndPrep() throws {
        try exercisePreset("Policy", segments: policySegments, score: true, prep: true, players: true)
    }

    func testCustomDebateEditsLabelsDurationAndResetConfirmations() throws {
        try beginCustomDebate()
        enter("FORMAT 100% %@", in: settingsField("Format Title"))
        enter("PRO 100%", in: settingsField("First Side"))
        enter("CON %@", in: settingsField("Second Side"))
        setToggle("Enable Score Tracking", to: true)
        setToggle("Enable Player Tracking", to: true)
        setToggle("Player Fouls", to: true)
        setToggle("Player Cards", to: false)
        setToggle("Enable Prep Time", to: true)
        step("Prep Time", by: 1)
        tap(mainWindow.buttons["Open Designer"])
        enter("Speech 100% %@", in: segmentTitleField(0))
        choose("Speaking Side", option: "PRO 100%", in: segmentEditor(0))
        step("Duration", by: 1, in: segmentEditor(0))
        setToggle("Auto Pause At End", to: false, in: segmentEditor(0))
        assertSettingValue("Duration", equals: "04:15", in: segmentEditor(0))
        returnToBoard()
        assertSegment(1, of: 1, title: "Speech 100% %@")
        XCTAssertEqual(text(clock), "04:15")
        XCTAssertEqual(text(mainWindow.staticTexts["live.debate.prep.home"].firstMatch), "02:15")
        exerciseSegmentClock()
        exercisePrepClocks()
        exerciseScores(steps: [1])
        tap(action("Reset Segment"))
        respondToConfirmation("Cancel")
        XCTAssertLessThan(clockSeconds(text(clock)), 255)
        tap(action("Reset Segment"))
        respondToConfirmation("Reset Segment")
        XCTAssertEqual(text(clock), "04:15")
        assertScores(home: 1, guest: 0)
        openDebateSettings()
        assertField("Format Title", equals: "FORMAT 100% %@")
        assertField("First Side", equals: "PRO 100%")
        assertField("Second Side", equals: "CON %@")
        assertToggle("Enable Player Tracking", equals: true)
        assertToggle("Player Fouls", equals: true)
        assertToggle("Player Cards", equals: false)
        assertSettingValue("Prep Time", equals: "02:15")
        tap(mainWindow.buttons["Open Designer"])
        XCTAssertEqual(text(segmentTitleField(0)), "Speech 100% %@")
        assertChoice("Speaking Side", equals: "PRO 100%", in: segmentEditor(0))
        assertToggle("Auto Pause At End", equals: false, in: segmentEditor(0))
        assertSettingValue("Duration", equals: "04:15", in: segmentEditor(0))
    }

    func testCustomDebateDualClockStartsOnHomeAndAllowsSwitching() throws {
        try exerciseDualSegment(startsOn: "home", switching: true)
    }

    func testCustomDebateDualClockStartsOnGuestWithoutSwitching() throws {
        try exerciseDualSegment(startsOn: "guest", switching: false)
    }

    func testCustomDebateAddsReordersDeletesAndKeepsFinalSegment() throws {
        try beginCustomDebate()
        tap(mainWindow.buttons["Open Designer"])
        enter("Opening 100%", in: segmentTitleField(0))
        tap(mainWindow.buttons["Add Segment"])
        enter("Checkpoint %@", in: segmentTitleField(1))
        choose("Timer", option: "None", in: segmentEditor(1))
        tap(segmentEditor(1).buttons["Up"])
        XCTAssertEqual(text(segmentTitleField(0)), "Checkpoint %@")
        XCTAssertEqual(text(segmentTitleField(1)), "Opening 100%")
        tap(segmentEditor(0).buttons["Down"])
        XCTAssertEqual(text(segmentTitleField(0)), "Opening 100%")
        tap(segmentEditor(0).buttons["Delete"])
        XCTAssertEqual(text(segmentTitleField(0)), "Checkpoint %@")
        XCTAssertFalse(segmentEditor(0).buttons["Delete"].exists, "The final block cannot be deleted")
        returnToBoard()
        assertSegment(1, of: 1, title: "Checkpoint %@")
        XCTAssertFalse(clock.exists)
        tap(action("Next Segment"))
        assertSegment(1, of: 1, title: "Checkpoint %@")
        tap(action("Previous Segment"))
        assertSegment(1, of: 1, title: "Checkpoint %@")
        openDebateSettings()
        tap(mainWindow.buttons["Open Designer"])
        XCTAssertEqual(text(segmentTitleField(0)), "Checkpoint %@")
        assertChoice("Timer", equals: "None", in: segmentEditor(0))
        XCTAssertFalse(segmentEditor(1).exists)
    }

    func testSimpleDemoRunsUntimedSharedAutomaticAndBothDualSegments() throws {
        try beginCustomDebate()
        tap(mainWindow.buttons["Open Designer"])
        tap(mainWindow.buttons["settings.debate.template.simple-demo"])
        returnToBoard()
        assertSegment(1, of: 6, title: "No Timer Block")
        XCTAssertFalse(clock.exists)
        tap(action("Start Segment Timer"))
        XCTAssertFalse(action("Pause Segment Timer").exists)
        tap(action("Next Segment"))
        assertSegment(2, of: 6, title: "Aff Speech")
        exerciseSegmentClock()
        tap(action("Next Segment"))
        assertSegment(3, of: 6, title: "Neg Speech")
        XCTAssertTrue(action("Pause Segment Timer").waitForExistence(timeout: 5), "Start Paused off must start this segment")
        let running = text(clock)
        waitUntil("The automatic segment must advance") { self.text(self.clock) != running }
        tap(action("Pause Segment Timer"))
        tap(action("Next Segment"))
        assertSegment(4, of: 6, title: "Aff-Led Side Clock")
        exerciseSideClocks(start: "Start Segment Timer", pause: "Pause Segment Timer",
                           switchAction: "Switch Active Side")
        tap(action("Next Segment"))
        assertSegment(5, of: 6, title: "Neg-Led Side Clock")
        exerciseSideClocks(start: "Start Segment Timer", pause: "Pause Segment Timer",
                           switchAction: "Switch Active Side", startsOn: "guest")
        exercisePrepClocks()
        tap(action("Next Segment"))
        assertSegment(6, of: 6, title: "Final Speech")
        tap(action("Next Segment"))
        assertSegment(6, of: 6, title: "Final Speech")
        tap(action("Reset Round"))
        respondToConfirmation("Reset Round")
        assertSegment(1, of: 6, title: "No Timer Block")
        XCTAssertEqual(text(mainWindow.staticTexts["live.debate.prep.home"].firstMatch), "00:30")
        XCTAssertEqual(text(mainWindow.staticTexts["live.debate.prep.guest"].firstMatch), "00:30")
    }

    func testPublicForumTemplateCanBeEditedWithoutChangingBuiltInFormat() throws {
        try exerciseTemplate("public-forum", name: "Public Forum", segments: publicForumSegments)
    }

    func testLincolnDouglasTemplateCanBeEditedWithoutChangingBuiltInFormat() throws {
        try exerciseTemplate("lincoln-douglas", name: "Lincoln-Douglas", segments: lincolnDouglasSegments)
    }

    func testPolicyTemplateCanBeEditedWithoutChangingBuiltInFormat() throws {
        try exerciseTemplate("policy", name: "Policy", segments: policySegments)
    }

    private func beginCustomDebate() throws {
        try launchFixture("debate.custom", setup: true)
        assertDebateSettingsOverview()
    }

    private func openDebateSettings() {
        openSettings()
        assertDebateSettingsOverview()
    }

    private func assertDebateSettingsOverview(file: StaticString = #filePath, line: UInt = #line) {
        // The sidebar's Game Setup button also exists inside the designer.
        // Check the overview itself before searching a long segment editor
        // for controls that belong on a different page.
        let preset = mainWindow.descendants(matching: .any)
            .matching(identifier: "settings.picker.Preset").firstMatch
        XCTAssertTrue(preset.waitForExistence(timeout: 5),
                      "Reopening Debate settings must show Game Setup, outside the designer", file: file, line: line)
    }

    private func exercisePreset(_ name: String, segments: [(String, Int)], score: Bool, prep: Bool, players: Bool) throws {
        if name == "Public Forum" {
            // Keep a built-in-format editing journey; other format sequences
            // preload their configuration instead of repeating these inputs.
            try beginCustomDebate()
            choose("Preset", option: name)
            enter("PRO 100%", in: settingsField("First Side"))
            enter("CON %@", in: settingsField("Second Side"))
            setToggle("Enable Score Tracking", to: score)
            setToggle("Enable Player Tracking", to: players)
            setToggle("Enable Prep Time", to: prep)
            returnToBoard()
        } else {
            let id = name.lowercased().replacingOccurrences(of: " ", with: "-")
            try launchFixture("debate.\(id)")
        }
        assertSegment(1, of: segments.count, title: segments[0].0)
        exerciseSegmentClock()
        if score { exerciseScores(steps: [1]) }
        else { XCTAssertFalse(sideAction("+1").exists) }
        if prep { exercisePrepClocks() }
        else { XCTAssertFalse(sideAction("Use Prep").exists) }

        tap(action("Previous Segment"))
        assertSegment(1, of: segments.count)
        for index in 1..<segments.count {
            XCTContext.runActivity(named: "\(name), segment \(index + 1): \(segments[index].0)") { _ in
                tap(action("Next Segment"))
                assertSegment(index + 1, of: segments.count, title: segments[index].0)
                XCTAssertEqual(clockSeconds(text(clock)), segments[index].1)
                XCTAssertTrue(action("Start Segment Timer").exists)
            }
        }
        tap(action("Next Segment"))
        assertSegment(segments.count, of: segments.count)
        tap(action("Previous Segment"))
        assertSegment(segments.count - 1, of: segments.count, title: segments[segments.count - 2].0)
        openDebateSettings()
        assertChoice("Preset", equals: name)
        assertField("First Side", equals: "PRO 100%")
        assertField("Second Side", equals: "CON %@")
        assertToggle("Enable Score Tracking", equals: score)
        assertToggle("Enable Player Tracking", equals: players)
        if players {
            assertToggle("Player Fouls", equals: name == "Policy")
            assertToggle("Player Cards", equals: true)
        }
        assertToggle("Enable Prep Time", equals: prep)
        returnToBoard()
        assertSegment(segments.count - 1, of: segments.count, title: segments[segments.count - 2].0)
    }

    private func exerciseSegmentClock() {
        XCTAssertTrue(clock.waitForExistence(timeout: 5))
        let before = text(clock)
        tap(action("Start Segment Timer"))
        waitUntil("The debate speech clock must advance") { self.clock.exists && self.text(self.clock) != before }
        tap(action("Pause Segment Timer"))
        XCTAssertTrue(action("Start Segment Timer").exists)
    }

    private func exercisePrepClocks() {
        for side in ["home", "guest"] {
            let other = side == "home" ? "guest" : "home"
            let prep = mainWindow.staticTexts["live.debate.prep.\(side)"].firstMatch
            let otherPrep = mainWindow.staticTexts["live.debate.prep.\(other)"].firstMatch
            let initial = text(prep)
            let waiting = text(otherPrep)
            tapSide("Use Prep", side: side)
            waitUntil("\(side) prep must run independently") { self.text(prep) != initial }
            XCTAssertEqual(text(otherPrep), waiting)
            tapSide("Pause Prep", side: side)
            let paused = clockSeconds(text(prep))
            tapSide("+15s", side: side)
            XCTAssertEqual(clockSeconds(text(prep)), paused + 15)
            tapSide("-15s", side: side)
            XCTAssertEqual(clockSeconds(text(prep)), paused)
            tap(action("Return to Segment Timer"))
            XCTAssertTrue(action("Start Segment Timer").exists)
        }
    }

    private func exerciseDualSegment(startsOn side: String, switching: Bool) throws {
        try beginCustomDebate()
        tap(mainWindow.buttons["Open Designer"])
        choose("Timer", option: "Dual", in: segmentEditor(0))
        choose("Starting Side", option: side == "home" ? "Aff" : "Neg", in: segmentEditor(0))
        setToggle("Allow Side Switching", to: switching, in: segmentEditor(0))
        choose("Speaking Side", option: side == "home" ? "Neg" : "Aff", in: segmentEditor(0))
        returnToBoard()
        assertSegment(1, of: 1)
        XCTAssertEqual(action("Switch Active Side").exists, switching)
        exerciseSideClocks(start: "Start Segment Timer", pause: "Pause Segment Timer",
                           switchAction: "Switch Active Side", startsOn: side, canSwitch: switching)
        openDebateSettings()
        tap(mainWindow.buttons["Open Designer"])
        assertChoice("Timer", equals: "Dual", in: segmentEditor(0))
        assertChoice("Starting Side", equals: side == "home" ? "Aff" : "Neg", in: segmentEditor(0))
        assertChoice("Speaking Side", equals: side == "home" ? "Neg" : "Aff", in: segmentEditor(0))
        assertToggle("Allow Side Switching", equals: switching, in: segmentEditor(0))
        // Leaving Dual must remove its side-switch options and clear them.
        choose("Timer", option: "Master", in: segmentEditor(0))
        XCTAssertFalse(toggle("Allow Side Switching", in: segmentEditor(0)).exists)
        choose("Timer", option: "Dual", in: segmentEditor(0))
        assertChoice("Starting Side", equals: "Aff", in: segmentEditor(0))
        assertToggle("Allow Side Switching", equals: false, in: segmentEditor(0))
    }

    private func exerciseTemplate(_ id: String, name: String, segments: [(String, Int)]) throws {
        try beginCustomDebate()
        tap(mainWindow.buttons["Open Designer"])
        tap(mainWindow.buttons["settings.debate.template.\(id)"])
        enter("Edited 100% %@", in: segmentTitleField(0))
        returnToBoard()
        assertSegment(1, of: segments.count, title: "Edited 100% %@")
        openDebateSettings()
        choose("Preset", option: name)
        returnToBoard()
        assertSegment(1, of: segments.count, title: segments[0].0)
        openDebateSettings()
        choose("Preset", option: "Custom Debate")
        returnToBoard()
        assertSegment(1, of: segments.count, title: "Edited 100% %@")
        openDebateSettings()
        tap(mainWindow.buttons["Open Designer"])
        XCTAssertEqual(text(segmentTitleField(0)), "Edited 100% %@")
    }

    private var publicForumSegments: [(String, Int)] { [
        ("Aff Constructive", 240), ("Neg Constructive", 240), ("Crossfire", 180),
        ("Aff Rebuttal", 240), ("Neg Rebuttal", 240), ("Aff Summary", 120),
        ("Neg Summary", 120), ("Grand Crossfire", 180), ("Aff Final Focus", 120), ("Neg Final Focus", 120)
    ] }
    private var lincolnDouglasSegments: [(String, Int)] { [
        ("Aff Constructive", 360), ("Neg Cross-Ex", 180), ("Neg Constructive", 420),
        ("Aff Cross-Ex", 180), ("Aff Rebuttal", 240), ("Neg Rebuttal", 360), ("Aff Rebuttal 2", 180)
    ] }
    private var policySegments: [(String, Int)] { [
        ("1AC", 480), ("Cross-Ex", 180), ("1NC", 480), ("Cross-Ex", 180),
        ("2AC", 480), ("Cross-Ex", 180), ("2NC", 480), ("Cross-Ex", 180), ("1NR", 300),
        ("1AR", 300), ("2NR", 300), ("2AR", 300)
    ] }
}
