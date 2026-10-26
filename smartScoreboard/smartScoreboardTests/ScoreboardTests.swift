import Foundation
import Testing

/// Compiled only by the macOS test target. Every run gets its own storage and defaults.
nonisolated enum ScoreboardTestEnvironment {
    static let domain = "ScoreboardCoreTests.\(UUID().uuidString)"
    nonisolated(unsafe) static let defaults = UserDefaults(suiteName: domain)!
    static let root: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(domain, isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        atexit {
            try? FileManager.default.removeItem(at: ScoreboardTestEnvironment.root)
            ScoreboardTestEnvironment.defaults.removePersistentDomain(forName: ScoreboardTestEnvironment.domain)
        }
        return url
    }()
}

@Suite("Scoreboard core regressions", .serialized)
@MainActor
struct ScoreboardTests {
    var store: ScoreboardStore { .shared }

    static let peers = [
        ScoreboardRemoteDisplayTrustedPeer(id: "test-mac", name: "Control Mac", deviceType: .mac, pairingSecret: "test-secret-a"),
        ScoreboardRemoteDisplayTrustedPeer(id: "test-ipad", name: "Display iPad", deviceType: .ipad, pairingSecret: "test-secret-b"),
        ScoreboardRemoteDisplayTrustedPeer(id: "test-tv", name: "Apple TV", deviceType: .appleTV, pairingSecret: "test-secret-c")
    ]

    init() {
        _ = ScoreboardTestEnvironment.root
        store.resetToFactoryDefaults()
        store.setSelectedSport(.basketball)
        store.newGame()
        store.isSoundEnabled = false
        store.isCompanionEnabled = false
        store.isRemoteDisplayHostEnabled = false
        store.isWebAPIEnabled = false
        for peer in Self.peers { store.refreshControlTestTrustedDisplay(peer) }
    }

    func cmd(_ action: String, side: TeamSide? = nil, value: Int? = nil, text: String? = nil,
             enabled: Bool? = nil, playerID: UUID? = nil, timerID: UUID? = nil, delay: Double? = nil) -> ScoreboardControlCommand {
        ScoreboardControlCommand(action: action, sport: store.selectedSport, side: side, value: value,
            text: text, enabled: enabled, playerID: playerID, timerID: timerID,
            sentAt: delay.map { Date().timeIntervalSince1970 - $0 })
    }
}
