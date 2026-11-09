import Foundation
import Combine

nonisolated struct ScoreboardRecentMatch: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var matchID: UUID?
    var nearbyOwnerID: String?
    var server: String?
    var code: String?
    var usedAt: Date
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
    func record(title: String, matchID: UUID?, nearbyOwnerID: String? = nil, server: String? = nil, code: String? = nil) {
        guard ScoreboardDeviceMode.current == .app else { return }
        let id = matchID?.uuidString ?? "\(server ?? "nearby")|\(code ?? nearbyOwnerID ?? "")"
        var match = matches.first { $0.id == id } ?? .init(id: id, title: title, usedAt: Date())
        match.title = title; match.matchID = matchID; match.usedAt = Date()
        match.nearbyOwnerID = nearbyOwnerID ?? match.nearbyOwnerID
        match.server = server ?? match.server; match.code = code ?? match.code
        matches.removeAll { $0.id == id }; matches.insert(match, at: 0)
        matches = Array(matches.prefix(20)); save()
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
