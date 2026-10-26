import Foundation

/// Session peers use the owner's logical identity across a physical host transfer.
/// This configuration is installed in memory, without replacing the new host's
/// personal pairing preferences.
nonisolated struct ScoreboardSessionPairingConfiguration: Codable, Sendable {
    var ownerHostID: String
    var peers: [ScoreboardRemoteDisplayTrustedPeer]
    var mutedDisplayIDs: Set<String>
    var displayDirectionsByID: [String: ScoreboardRemoteDisplayDirectionSettings]
    var customDisplayIDsByID: [String: Int]
}

nonisolated enum ScoreboardSessionTransport {
    static let protocolVersion = 1
    // Checkpoints can contain embedded game assets. Log batches remain much
    // smaller and are scheduled separately by the session coordinator.
    static let maximumMessageBytes = 32 * 1_024 * 1_024
}
