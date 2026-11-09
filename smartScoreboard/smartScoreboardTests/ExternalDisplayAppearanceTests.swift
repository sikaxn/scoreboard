import Foundation
import Testing

extension ScoreboardTests {
    @Test("Game files restore their own theme, layout, and font and survive setup edits")
    func gameFileDisplayAppearance() throws {
        store.setTheme(.sunlight)
        store.setExternalDisplayLayout(.venueRoster)
        store.setExternalDisplayFont(.eightSegment)
        store.externalDisplayBackgroundMode = .clearUnderBoard
        let first = store.currentGameSnapshot()
        let url = ScoreboardTestEnvironment.root.appendingPathComponent("appearance.scoreboard")
        try ScoreboardMatchFiles.write(first, to: url)

        store.setTheme(.night)
        store.setExternalDisplayLayout(.arena)
        store.setExternalDisplayFont(.block)
        let second = store.currentGameSnapshot()
        let decoded = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: Data(contentsOf: url))
        store.applyGameSnapshot(decoded)
        #expect(store.theme == .sunlight)
        #expect(store.externalDisplayLayout == .venueRoster && store.externalDisplayFont == .eightSegment)
        #expect(store.externalDisplayBackgroundMode == .clearUnderBoard)

        let editor = SetupNavigationFixture(store: store)
        editor.loadSetupDraftsFromStore()
        editor.eventNameDraft = "Updated event"
        editor.hasPendingSetupEdits = true
        editor.commitSetupEdits()
        #expect(store.currentGameSnapshot().theme == first.theme)
        #expect(store.currentGameSnapshot().externalDisplayLayout == first.externalDisplayLayout)
        #expect(store.currentGameSnapshot().externalDisplayFont == first.externalDisplayFont)

        store.applyGameSnapshot(second)
        #expect(store.theme == .night)
        #expect(store.externalDisplayLayout == .arena && store.externalDisplayFont == .block)

        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(first)) as? [String: Any])
        for key in ["theme", "externalDisplayLayout", "externalDisplayFont"] { legacy.removeValue(forKey: key) }
        let oldGame = try JSONDecoder().decode(ScoreboardGameSnapshot.self, from: JSONSerialization.data(withJSONObject: legacy))
        store.applyGameSnapshot(oldGame)
        #expect(store.theme == .classic)
        #expect(store.externalDisplayLayout == .standard && store.externalDisplayFont == .rounded)
    }

    @Test("Display layout and font restore independently and older backups keep the original appearance")
    func externalDisplayAppearancePersistence() throws {
        store.setTheme(.sunlight)
        store.externalDisplayBackgroundMode = .clearUnderBoard
        store.setExternalDisplayLayout(.venueRoster)
        store.setExternalDisplayFont(.dotMatrix)
        let saved = try store.exportPersistedStateData()
        store.setExternalDisplayLayout(.broadcast)
        #expect(store.externalDisplayFont == .dotMatrix)
        store.setExternalDisplayFont(.block)
        #expect(store.externalDisplayLayout == .broadcast)
        try store.restorePersistedStateData(saved)
        #expect(store.externalDisplayLayout == .venueRoster)
        #expect(store.externalDisplayFont == .dotMatrix)
        #expect(store.theme == .sunlight)
        #expect(store.externalDisplayBackgroundMode == .clearUnderBoard)

        var legacy = try #require(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        legacy.removeValue(forKey: "externalDisplayLayout")
        legacy.removeValue(forKey: "externalDisplayFont")
        try store.restorePersistedStateData(JSONSerialization.data(withJSONObject: legacy))
        #expect(store.externalDisplayLayout == .standard)
        #expect(store.externalDisplayFont == .rounded)
    }

    @Test("Every layout and font combination reaches remote receivers without changing theme or background",
          arguments: ExternalDisplayLayout.allCases)
    func externalDisplayAppearanceRemotePayload(layout: ExternalDisplayLayout) throws {
        store.setTheme(.night)
        store.externalDisplayBackgroundMode = .clearUnderBoard
        store.setExternalDisplayLayout(layout)
        let receiver = ScoreboardStore.makeRemoteControlStore(receiver: ScoreboardRemoteDisplayReceiver())
        for font in ExternalDisplayFont.allCases {
            store.setExternalDisplayFont(font)
            let state = store.currentRemoteDisplayState(forDisplayID: "test-mac")
            #expect(state.display?.layout == layout)
            #expect(state.display?.font == font)
            let encoded = try JSONEncoder().encode(state.remoteDisplayV2Payload)
            let decoded = try JSONDecoder().decode(ScoreboardWebAPIRemoteDisplayStateV2.self, from: encoded).v1CompatibleState
            #expect(decoded.display?.layout == layout)
            #expect(decoded.display?.font == font)
            #expect(decoded.display?.theme == .night)
            #expect(decoded.display?.backgroundMode == .clearUnderBoard)
            receiver.applyRemoteControlState(decoded)
            #expect(receiver.externalDisplayLayout == layout)
            #expect(receiver.externalDisplayFont == font)

            var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state.display)) as? [String: Any])
            legacy.removeValue(forKey: "layout")
            legacy.removeValue(forKey: "font")
            let oldDisplay = try JSONDecoder().decode(ScoreboardWebAPIDisplay.self, from: JSONSerialization.data(withJSONObject: legacy))
            #expect(oldDisplay.layout == nil && oldDisplay.font == nil)
        }
    }

    @Test("Remote layout and font controls route independently and reject invalid values")
    func externalDisplayAppearanceCommands() {
        store.setRemoteControlAllowed(displayID: "test-mac", isAllowed: true)
        #expect(store.executeControlCommand(cmd("display.layout", text: "broadcast")).success)
        #expect(store.executeControlCommand(cmd("display.font", text: "eightSegment")).success)
        #expect(store.externalDisplayLayout == .broadcast)
        #expect(store.externalDisplayFont == .eightSegment)
        #expect(store.executeControlCommand(cmd("display.layout", text: "invalid")).error == "invalidCommand")
        #expect(store.executeControlCommand(cmd("display.font", text: "invalid")).error == "invalidCommand")
        #expect(store.externalDisplayLayout == .broadcast && store.externalDisplayFont == .eightSegment)

        var routed: [ScoreboardControlCommand] = []
        let proxy = ScoreboardStore.makeRemoteControlStore(receiver: ScoreboardRemoteDisplayReceiver(), sendCommand: { routed.append($0) })
        proxy.applyRemoteControlState(store.currentRemoteDisplayState(forDisplayID: "test-mac"))
        proxy.setExternalDisplayLayout(.arena)
        #expect(routed.last?.action == "display.layout" && routed.last?.text == "arena")
        proxy.setExternalDisplayFont(.block)
        #expect(routed.last?.action == "display.font" && routed.last?.text == "block")
        #expect(proxy.externalDisplayLayout == .broadcast && proxy.externalDisplayFont == .eightSegment,
                "The receiver waits for the host's authoritative update")
    }

    @Test("Venue Roster sends full rosters to display-only receivers")
    func venueRosterDisplayPayload() {
        store.setPlayerTrackingEnabled(true)
        store.setExternalDisplayLayout(.venueRoster)
        let venue = store.currentRemoteDisplayState(forDisplayID: "test-ipad")
        #expect(venue.control?.remoteEnabled == false)
        #expect(venue.players.homeRoster.players.count == store.homeRoster.players.count)
        #expect(venue.players.guestRoster.players.count == store.guestRoster.players.count)
        store.setExternalDisplayLayout(.standard)
        let standard = store.currentRemoteDisplayState(forDisplayID: "test-ipad")
        #expect(standard.players.homeRoster.players.isEmpty)
    }
}
