import Foundation

/// Ownership never moves. Authority moves only through an acknowledged, fenced handoff.
nonisolated struct ScoreboardSessionDescriptor: Codable, Equatable, Sendable {
    var sessionID: UUID
    var epoch: UInt64
    var ownerDeviceID: String
    var ownerHostID: String
    var ownerName: String
    var hostDeviceID: String
    var hostName: String
    var hostAddresses: [String]
    var hostWebAPIStatus: String? = nil
    var hostCompanionEnabled: Bool? = nil
    var logSessionID: UUID? = nil
    var safeToDisconnect: Bool? = nil

    func accepts(_ other: Self) -> Bool {
        sessionID == other.sessionID && ownerDeviceID == other.ownerDeviceID
            && ownerHostID == other.ownerHostID && other.epoch >= epoch
            && (other.epoch != epoch || other.hostDeviceID == hostDeviceID)
    }
}

nonisolated struct ScoreboardSessionCheckpoint: Codable, Sendable {
    var descriptor: ScoreboardSessionDescriptor
    var settings: Data
    var game: ScoreboardGameSnapshot
    var runtime: ScoreboardWebAPIRuntime
    var gameName: String?
    var ownerGameFilename: String? = nil
    var mainDisplayMode: ScoreboardDisplayViewMode
    var pairings: ScoreboardSessionPairingConfiguration
    var allowedControllers: Set<String>
    var webControlEnabled: Bool
    var webControlKey: String
    var log: ScoreboardLogSession
    var capturedAt: TimeInterval
    var gameElapsed: TimeInterval
    var shotElapsed: TimeInterval
    var penaltyElapsed: TimeInterval
    var prepElapsed: TimeInterval
    var pauseElapsed: TimeInterval? = nil
}

nonisolated struct ScoreboardSessionCleanState: Equatable, Sendable {
    var ownerConnected: Bool
    var anyTimerRunning: Bool
    var transferring: Bool
    var revision: UInt64
    var persistedRevision: UInt64
    var acknowledgedRevision: UInt64
    var logCount: Int
    var acknowledgedLogCount: Int

    var isSafeToDisconnect: Bool {
        ownerConnected && !anyTimerRunning && !transferring &&
            revision == persistedRevision && revision == acknowledgedRevision &&
            logCount == acknowledgedLogCount
    }
}

nonisolated struct ScoreboardSessionPeer: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var deviceType: ScoreboardRemoteDisplayDeviceType
    var connected: Bool
    var supportsHosting: Bool
    var controlEnabled: Bool? = nil
    var latencyMilliseconds: Int? = nil
    var lastHandshakeAgeSeconds: Int? = nil
    var appVersion: ScoreboardRemoteDisplayAppVersion? = nil
    var quality: ScoreboardRemoteDisplayConnectionQuality? = nil
    var realtimeTransport: String? = nil
}

nonisolated struct ScoreboardSessionAdministration: Codable, Sendable {
    var action: String
    var displayID: String
    var enabled: Bool? = nil
    var text: String? = nil
    var number: Int? = nil
    var sport: SportType? = nil
    var soundEvent: ScoreboardSoundEvent? = nil
}

nonisolated struct ScoreboardSessionIntegrationSettings: Codable, Sendable {
    var webAPIEnabled: Bool
    var webControlEnabled: Bool
    var webControlKey: String
    var webUpdateMode: ScoreboardWebAPIUpdateMode
    var companionEnabled: Bool
    var companionHost: String
    var companionMode: ScoreboardCompanionMode
    var companionPort: UInt16
    var companionSyncWithSound: Bool
    var companionAssignments: [SportType: [ScoreboardSoundEvent: String]]
    var soundEnabled: Bool
    var soundAssignments: [SportType: [ScoreboardSoundEvent: ScoreboardSoundEffect]]
    var bypassedSoundEvents: [SportType: Set<ScoreboardSoundEvent>]
    var bypassedCompanionEvents: [SportType: Set<ScoreboardSoundEvent>]
    var broadcastControlEnabled: Bool
    var broadcastDisplayCount: Int
    var broadcastModes: [Int: ScoreboardWebAPIBroadcastDisplayMode]
    var customDisplayTitles: [String: String]
    var remoteIndividualControlEnabled: Bool
    var remoteNetworkMode: ScoreboardRemoteDisplayNetworkMode
}

nonisolated struct ScoreboardSessionMessage: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case requestHost, prepare, prepared, commit, committed, abort, error
        case settings, game, administration, peers, logRequest, logBatch, logAck
        case snapshot, snapshotAck
    }
    var kind: Kind
    var id: UUID = UUID()
    var descriptor: ScoreboardSessionDescriptor
    var targetID: String? = nil
    var checkpoint: ScoreboardSessionCheckpoint? = nil
    var settings: Data? = nil
    var integrationSettings: ScoreboardSessionIntegrationSettings? = nil
    var game: ScoreboardGameSnapshot? = nil
    var visualFields: Set<String>? = nil
    var gameName: String? = nil
    var administration: ScoreboardSessionAdministration? = nil
    var peers: [ScoreboardSessionPeer]? = nil
    var pairingConfiguration: ScoreboardSessionPairingConfiguration? = nil
    var allowedControllers: Set<String>? = nil
    var webControlEnabled: Bool? = nil
    var webControlKey: String? = nil
    var cursor: ScoreboardSessionLogCursor? = nil
    var batch: ScoreboardSessionLogBatch? = nil
    var detail: String? = nil
    var syncRevision: UInt64? = nil
}

/// A delegated host's working copy lives outside the owner's document directory.
/// It is removed only after another authority has accepted the match, or after
/// the owner has durably acknowledged a stopped, clean match.
/// tvOS may also purge its cache after the app exits.
@MainActor enum ScoreboardHostedMatchStorage {
    static func directory(for sessionID: UUID) -> URL {
        ScoreboardSessionRecovery.url.deletingLastPathComponent()
            .appendingPathComponent("Hosted", isDirectory: true)
            .appendingPathComponent(sessionID.uuidString, isDirectory: true)
    }

    static func gameURL(for sessionID: UUID) -> URL {
        directory(for: sessionID).appendingPathComponent("match.scoreboardgame")
    }

    static func logURL(for sessionID: UUID) -> URL {
        directory(for: sessionID).appendingPathComponent("match.scoreboardlog")
    }

    static func checkpointURL(for sessionID: UUID) -> URL {
        directory(for: sessionID).appendingPathComponent("checkpoint.json")
    }

    static func save(_ checkpoint: ScoreboardSessionCheckpoint) throws {
        let sessionID = checkpoint.descriptor.sessionID
        let directory = directory(for: sessionID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(checkpoint.game).write(to: gameURL(for: sessionID), options: .atomic)
        let logEncoder = JSONEncoder()
        logEncoder.dateEncodingStrategy = .iso8601
        try logEncoder.encode(checkpoint.log).write(to: logURL(for: sessionID), options: .atomic)
        try JSONEncoder().encode(checkpoint).write(to: checkpointURL(for: sessionID), options: .atomic)
    }

    static func load(sessionID: UUID) throws -> ScoreboardSessionCheckpoint? {
        let url = checkpointURL(for: sessionID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let checkpoint = try JSONDecoder().decode(ScoreboardSessionCheckpoint.self, from: Data(contentsOf: url))
        guard checkpoint.descriptor.sessionID == sessionID else { return nil }
        if let log = try loadLog(sessionID: sessionID) {
            if log.sessionID == checkpoint.log.sessionID,
               log.entries.count >= checkpoint.log.entries.count,
               zip(checkpoint.log.entries, log.entries).allSatisfy({ $0.id == $1.id }) {
                var recovered = checkpoint
                recovered.log = log
                return recovered
            }
        }
        return checkpoint
    }

    static func loadLog(sessionID: UUID) throws -> ScoreboardLogSession? {
        let url = logURL(for: sessionID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let log = try decoder.decode(ScoreboardLogSession.self, from: Data(contentsOf: url))
        return log
    }

    static func remove(sessionID: UUID) throws {
        let directory = directory(for: sessionID)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }
}

/// Stored before committing authority. A fenced source cannot resume game logic,
/// including after process termination or a lost final acknowledgement.
nonisolated struct ScoreboardSessionRecovery: Codable, Sendable {
    enum Role: String, Codable, Sendable { case host, follower, prepared, fenced }
    var role: Role
    var descriptor: ScoreboardSessionDescriptor
    var checkpoint: ScoreboardSessionCheckpoint?
    var transferID: UUID?

    static var url: URL {
        #if os(tvOS)
        // tvOS rejects writes to Documents and Application Support. Its app
        // cache is writable while the match runs, but can be purged after exit.
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        #else
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #endif
        return base.appendingPathComponent("smartScoreboard/Session/authority.json")
    }

    func save(to url: URL = Self.url) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    static func load(from url: URL = Self.url) throws -> Self? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}
