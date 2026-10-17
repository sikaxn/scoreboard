import XCTest

@MainActor
extension ScoreboardUITestCase {
    func fixture(_ name: String) throws -> [String: Any] {
        let bundle = Bundle(for: ScoreboardUITestCase.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "EventConfigurations", withExtension: "json", subdirectory: "Fixtures")
                ?? bundle.url(forResource: "EventConfigurations", withExtension: "json"),
            "Missing bundled EventConfigurations.json")
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try XCTUnwrap(catalog[name] as? [String: Any], "Missing UI fixture: \(name)")
    }

    func launchFixture(_ name: String, setup: Bool = false) throws {
        let config = try fixture(name)
        let sport = try XCTUnwrap(config["sport"] as? String)
        let data = try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys])
        app.launchEnvironment["SCOREBOARD_UI_TEST_CONFIGURATION"] = String(decoding: data, as: UTF8.self)
        // A fixture represents an existing saved event. Fresh setup starts
        // with Simple drafts, which can overwrite the preloaded sport before
        // root initialization finishes. Enter its editor through the same
        // Settings action an operator uses for an existing event.
        launch(sport)
        if setup { openSettings() }
    }
}
