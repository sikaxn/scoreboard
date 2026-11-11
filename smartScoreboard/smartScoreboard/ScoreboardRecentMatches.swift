import Foundation
import Combine
import Network

nonisolated struct ScoreboardNearbyMatch: Identifiable, Sendable {
    var id: String
    var matchID: UUID
    var title: String
    var ownerName: String
    var endpoint: NWEndpoint
    var pairingHostID: String? = nil
    var cloudCode: String? = nil
    var cloudServer: String? = nil
    var supportsTrustedReconnect = false
}

nonisolated struct ScoreboardRecentMatch: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var matchID: UUID?
    var nearbyOwnerID: String?
    var server: String?
    var code: String?
    var usedAt: Date
    var cloudSessionID: String? = nil

    /// Discovery may disappear after a relaunch or an interface change. Cloud
    /// eligibility comes from saved metadata, never from a live Bonjour result.
    func preferredRoute(nearbyAvailable: Bool, cloudEnabled: Bool, serviceURL: String,
                        mode: ScoreboardRemoteDisplayNetworkMode) -> ScoreboardRemoteRoute? {
        let cloudAvailable = cloudEnabled && mode.allowsCloud && server.map {
            ScoreboardCloudEndpoint.sameService($0, serviceURL)
        } == true && (code != nil || cloudSessionID != nil)
        if cloudAvailable && (mode == .preferCloud || !nearbyAvailable) { return .cloud }
        if nearbyAvailable && mode.allowsLocalNetwork { return .local }
        return cloudAvailable ? .cloud : nil
    }
}

/// Connection history contains no credentials, received scores, or game files.
@MainActor final class ScoreboardRecentMatches: ObservableObject {
    static let shared = ScoreboardRecentMatches()
    private let key = "scoreboard.recentJoins.v1"
    @Published private(set) var matches: [ScoreboardRecentMatch]
    init() {
        matches = ScoreboardPreferences.current.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([ScoreboardRecentMatch].self, from: $0) } ?? []
    }
    func record(title: String, matchID: UUID?, nearbyOwnerID: String? = nil, server: String? = nil, code: String? = nil,
                cloudSessionID: String? = nil) {
        guard ScoreboardDeviceMode.current == .app else { return }
        let id = matchID?.uuidString ?? "\(server ?? "nearby")|\(code ?? nearbyOwnerID ?? "")"
        var match = matches.first { $0.id == id } ?? .init(id: id, title: title, usedAt: Date())
        match.title = title; match.matchID = matchID; match.usedAt = Date()
        match.nearbyOwnerID = nearbyOwnerID ?? match.nearbyOwnerID
        if let server, let previous = match.server, !ScoreboardCloudEndpoint.sameService(server, previous) {
            match.code = nil; match.cloudSessionID = nil
        }
        match.server = server ?? match.server; match.code = code ?? match.code
        match.cloudSessionID = cloudSessionID ?? match.cloudSessionID
        matches.removeAll { $0.id == id }; matches.insert(match, at: 0)
        matches = Array(matches.prefix(20)); save()
    }
    func recordNearby(_ match: ScoreboardNearbyMatch) {
        record(title: match.title, matchID: match.matchID, nearbyOwnerID: match.id,
            server: match.cloudServer, code: match.cloudCode)
    }
    func remove(_ id: String) { matches.removeAll { $0.id == id }; save() }
    func removeAll() { matches = []; ScoreboardPreferences.current.removeObject(forKey: key) }
    private func save() {
        if let data = try? JSONEncoder().encode(matches) { ScoreboardPreferences.current.set(data, forKey: key) }
    }
}

nonisolated struct ScoreboardCloudInvitationStatus: Decodable, Sendable {
    var code: String
    var available: Bool
    var hostOnline: Bool?
}
