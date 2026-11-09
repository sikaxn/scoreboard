import Foundation
import Testing

extension ScoreboardTests {
    @Test("Recent connections merge nearby and cloud metadata without saving secrets or kiosk history")
    func recentConnectionMetadataIsolation() throws {
        let preferences = ScoreboardPreferences.current, key = "scoreboard.recentJoins.v1"
        let old = preferences.data(forKey: key), mode = preferences.string(forKey: ScoreboardDeviceMode.preferenceKey)
        defer {
            if let old { preferences.set(old, forKey: key) } else { preferences.removeObject(forKey: key) }
            if let mode { preferences.set(mode, forKey: ScoreboardDeviceMode.preferenceKey) } else { preferences.removeObject(forKey: ScoreboardDeviceMode.preferenceKey) }
        }
        preferences.removeObject(forKey: key)
        let recent = ScoreboardRecentMatches(), id = UUID()
        recent.record(title: "Court", matchID: id, nearbyOwnerID: "nearby-host")
        recent.record(title: "Court", matchID: id, server: "https://scores.example.test", code: "ABCDEFGHJK")
        #expect(recent.matches.count == 1)
        #expect(recent.matches[0].nearbyOwnerID == "nearby-host" && recent.matches[0].code == "ABCDEFGHJK")
        let saved = try #require(preferences.data(forKey: key))
        let value = try #require(JSONSerialization.jsonObject(with: saved) as? [[String: Any]])
        #expect(Set(value[0].keys) == ["id", "title", "matchID", "nearbyOwnerID", "server", "code", "usedAt"])
        preferences.set("kiosk", forKey: ScoreboardDeviceMode.preferenceKey)
        recent.record(title: "Kiosk match", matchID: UUID(), nearbyOwnerID: "other-host")
        #expect(preferences.data(forKey: key) == saved)
        recent.remove(id.uuidString)
        #expect(recent.matches.isEmpty)
    }

    @Test("Cloud images use four explicit slots and are discarded with the joined connection")
    func cloudImagesStayWithJoinedSession() throws {
        let data = Data([1, 2, 3])
        store.homeTeamLogoImage = .init(id: "home-logo", sourceName: nil, pixelWidth: 1, pixelHeight: 1, byteCount: data.count, data: data)
        store.guestTeamLogoImage = .init(id: "guest-logo", sourceName: nil, pixelWidth: 1, pixelHeight: 1, byteCount: data.count, data: data)
        store.eventLogoImage = .init(id: "event-logo", sourceName: nil, pixelWidth: 1, pixelHeight: 1, byteCount: data.count, data: data)
        store.externalDisplayBackgroundImage = .init(id: "background-image", sourceName: nil, pixelWidth: 1, pixelHeight: 1, byteCount: data.count, data: data)
        let state = store.currentWebAPIState()
        #expect(Set(state.cloudImageReferences.map(\.slot)) == ["home", "guest", "event", "background"])
        let receiver = ScoreboardRemoteDisplayReceiver()
        receiver.beginCloudConnection { _ in }
        receiver.receiveCloudState(state, controlAllowed: false, hostName: "Host")
        for image in state.cloudImageReferences {
            receiver.receiveCloudImage(.init(id: image.id, path: image.path, mimeType: "image/png", data: data))
            #expect(receiver.imageData(for: image.id) == data)
        }
        receiver.receiveCloudImage(.init(id: "unrelated", path: "/unused", mimeType: "image/png", data: data))
        #expect(receiver.imageData(for: "unrelated") == nil)
        receiver.endCloudConnection()
        #expect(receiver.state == nil && receiver.imageData(for: "home-logo") == nil)
    }
}
