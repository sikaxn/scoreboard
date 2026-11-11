import Foundation
import Testing
import Combine

nonisolated private final class EulaHTTPFixture: @unchecked Sendable {
    let lock = NSLock()
    private var paths: [String] = []
    private var currentVersion = "0.1"
    private var offline = false
    private var room: ScoreboardCloudSession?
    private var roomError: Int?
    var requests: [String] { lock.withLock { paths } }
    func upgrade() { lock.withLock { currentVersion = "0.2" } }
    func setOffline(_ value: Bool) { lock.withLock { offline = value } }
    func configureRoom(_ value: ScoreboardCloudSession, error: Int? = nil) { lock.withLock { room = value; roomError = error } }
    func response(_ request: URLRequest) throws -> (Int, Data) {
        try lock.withLock {
            let path = request.url!.path
            paths.append(path)
            if offline { throw URLError(.notConnectedToInternet) }
            let value: [String: Any]
            switch path {
            case "/api/eula":
                value = ["version":currentVersion,"title":"Cloud policy","content":"The complete policy text.","publishedAt":0,"placeholder":true]
            case "/api/eula/accept":
                let body = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String:Any]
                guard body?["version"] as? String == currentVersion, request.value(forHTTPHeaderField: "X-Scoreboard-Device-Proof") != nil else {
                    return (409, Data("{\"error\":\"eula_changed\",\"message\":\"Changed\"}".utf8))
                }
                value = ["version":currentVersion,"receipt":"receipt-" + currentVersion,"acceptedAt":Date().timeIntervalSince1970 * 1000]
            default:
                guard request.value(forHTTPHeaderField: "X-Scoreboard-EULA") == "receipt-" + currentVersion else {
                    return (428, Data("{\"error\":\"eula_required\",\"message\":\"Accept updated policy\"}".utf8))
                }
                if let room, path == "/api/sessions" {
                    return (200, try JSONSerialization.data(withJSONObject: ["sessions": [JSONSerialization.jsonObject(with: JSONEncoder().encode(room))]]))
                }
                if let room, path == "/api/sessions/\(room.id)" {
                    if let roomError {
                        return (roomError, Data("{\"message\":\"Device grant expired or revoked\"}".utf8))
                    }
                    guard request.value(forHTTPHeaderField: "Authorization") == "Bearer private-participant-fixture",
                          request.value(forHTTPHeaderField: "X-Scoreboard-Device-Proof") != nil else {
                        return (401, Data("{\"message\":\"Missing device authorization\"}".utf8))
                    }
                    return (200, try JSONEncoder().encode(room))
                }
                value = ["invitations":[]]
            }
            return (200, try! JSONSerialization.data(withJSONObject: value))
        }
    }
}
nonisolated private final class EulaURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var fixture: EulaHTTPFixture?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let fixture = Self.fixture else { client?.urlProtocol(self, didFailWithError: URLError(.unknown)); return }
        var request = request
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var body = Data(), buffer = [UInt8](repeating:0,count:4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer,maxLength:buffer.count)
                if count <= 0 { break }; body.append(buffer, count:count)
            }
            request.httpBody = body
        }
        do {
            let (status, data) = try fixture.response(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

extension ScoreboardTests {
    private func restoredCloudFixture(_ fixture: EulaHTTPFixture, accepted: Bool = true,
                                      participationStorage: ScoreboardCloudSecureStorage? = nil) throws -> (ScoreboardCloudClient, UserDefaults, String) {
        let domain = "CloudRelaunch." + UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: domain))
        let origin = "https://scores.example.test"
        preferences.set(true, forKey: "scoreboard.cloudEnabled")
        preferences.set("selfHosted", forKey: "scoreboard.cloudServiceMode")
        preferences.set(origin, forKey: "scoreboard.cloudSelfHostedURL")
        preferences.set([origin], forKey: "scoreboard.cloudDisclosureServices")
        let receipt = ScoreboardCloudAgreementAcceptance(origin: origin, version: "0.1", receipt: "receipt-0.1", acceptedAt: Date().timeIntervalSince1970 * 1000)
        var acceptanceData = accepted ? try JSONEncoder().encode([origin: receipt]) : nil
        EulaURLProtocol.fixture = fixture
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [EulaURLProtocol.self]
        let cloud = ScoreboardCloudClient(preferences: preferences, requestSession: URLSession(configuration: configuration),
            participationStorage: participationStorage,
            agreementStorage: .init(load: { acceptanceData }, save: { acceptanceData = $0 }))
        return (cloud, preferences, domain)
    }

    @Test("Restored agreement checks never present a loading modal; a changed version still requires acceptance")
    func cloudAgreementSilentRelaunch() async throws {
        let fixture = EulaHTTPFixture()
        let (cloud, preferences, domain) = try restoredCloudFixture(fixture)
        defer { cloud.cloudEnabled = false; preferences.removePersistentDomain(forName: domain) }
        var presentations: [ScoreboardCloudConsentStep?] = []
        let observation = cloud.$cloudConsent.sink { presentations.append($0) }
        defer { observation.cancel() }
        _ = try await cloud.invitationAvailability(codes: ["ABCDEFGHJK"])
        #expect(presentations.allSatisfy { $0 == nil })
        #expect(fixture.requests == ["/api/eula", "/api/invitations/status"])
        fixture.upgrade()
        let (updated, otherPreferences, otherDomain) = try restoredCloudFixture(fixture)
        defer { updated.cloudEnabled = false; otherPreferences.removePersistentDomain(forName: otherDomain) }
        await #expect(throws: (any Error).self) { try await updated.invitationAvailability(codes: ["ABCDEFGHJK"]) }
        guard case .agreement(let document) = updated.cloudConsent else { Issue.record("An updated policy must be reviewed."); return }
        #expect(document.version == "0.2")
    }

    @Test("Offline startup preserves cloud settings and local access, with and without a cached receipt")
    func cloudAgreementOfflineStartup() async throws {
        let fixture = EulaHTTPFixture(); fixture.setOffline(true)
        let (cloud, preferences, domain) = try restoredCloudFixture(fixture)
        defer { cloud.cloudEnabled = false; preferences.removePersistentDomain(forName: domain) }
        var presentations: [ScoreboardCloudConsentStep?] = []
        let observation = cloud.$cloudConsent.sink { presentations.append($0) }
        defer { observation.cancel() }
        await #expect(throws: (any Error).self) { try await cloud.invitationAvailability(codes: ["ABCDEFGHJK"]) }
        #expect(presentations.allSatisfy { $0 == nil })
        #expect(cloud.cloudEnabled && preferences.bool(forKey: "scoreboard.cloudEnabled"))
        fixture.setOffline(false)
        _ = try await cloud.invitationAvailability(codes: ["ABCDEFGHJK"])
        #expect(cloud.cloudConsent == nil && cloud.cloudEnabled)

        fixture.setOffline(true)
        let (pending, pendingPreferences, pendingDomain) = try restoredCloudFixture(fixture, accepted: false)
        defer { pending.cloudEnabled = false; pendingPreferences.removePersistentDomain(forName: pendingDomain) }
        await #expect(throws: (any Error).self) { try await pending.invitationAvailability(codes: ["ABCDEFGHJK"]) }
        #expect(pending.cloudConsent == nil && pending.cloudEnabled)
        pending.retryCloudAgreement()
        for _ in 0..<100 {
            if case .failed = pending.cloudConsent { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard case .failed = pending.cloudConsent else { Issue.record("An explicit offline retry should offer a non-destructive dismissal."); return }
        pending.postponeCloudAgreement()
        #expect(pending.cloudConsent == nil && pending.cloudEnabled)
        fixture.setOffline(false)
        await #expect(throws: (any Error).self) { try await pending.invitationAvailability(codes: ["ABCDEFGHJK"]) }
        guard case .agreement = pending.cloudConsent else { Issue.record("Unaccepted policy cannot be skipped on recovery."); return }
        pending.postponeCloudAgreement()
        #expect(pending.cloudConsent == nil && pending.cloudEnabled)
    }

    @Test("Legacy nearby grants recover cloud metadata, and clearing history stays cleared on refresh")
    func recentCloudLegacyGrantMigration() async throws {
        let fixture = EulaHTTPFixture()
        let (cloud, preferences, domain) = try restoredCloudFixture(fixture)
        defer { cloud.cloudEnabled = false; preferences.removePersistentDomain(forName: domain) }
        let matchID = UUID()
        let grant = ScoreboardCloudEnrollment(serviceURL: "https://scores.example.test", token: "private-participant-fixture", sessionID: "ABCDEFGHJK",
            accountID: "owner", hostLocalID: "mac-host", remoteDeviceID: "joining-device", access: "participant",
            devicePublicKey: ScoreboardDeviceIdentity.publicKey)
        let room = ScoreboardCloudSession(id: grant.sessionID, name: "Court", ownerID: "owner", ownerDeviceID: "mac", hostDeviceID: "mac",
            generation: "generation", expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000,
            members: [], hostOnline: true, hostLocalID: "mac-host", matchID: matchID, invitationCode: "KJHGFEDCBA")
        fixture.configureRoom(room)
        #expect(cloud.acceptEnrollment(try JSONEncoder().encode(grant), authenticatedHostID: "mac-host", localDeviceID: "joining-device"))
        await cloud.refreshSessions()
        let recent = try #require(ScoreboardRecentMatches.shared.matches.first { $0.matchID == matchID })
        #expect(recent.server == grant.serviceURL && recent.cloudSessionID == grant.sessionID && recent.code == room.invitationCode)
        #expect(cloud.hasSavedParticipation(for: recent))
        ScoreboardRecentMatches.shared.removeAll()
        await cloud.refreshSessions()
        #expect(ScoreboardRecentMatches.shared.matches.isEmpty)
        #expect(ScoreboardRecentMatches().matches.isEmpty)
        #expect(cloud.hasSavedParticipation(for: recent), "Clearing history does not revoke device authorization.")
    }

    @Test("A nearby-provisioned device resumes the same cloud match after relaunch without discovery or a saved password")
    func recentCloudGrantRelaunch() async throws {
        let fixture = EulaHTTPFixture()
        var savedGrantData: Data?
        let secureStorage = ScoreboardCloudSecureStorage(load: { savedGrantData }, save: { savedGrantData = $0 })
        let initialDomain = "CloudGrantInitial." + UUID().uuidString
        let initialDefaults = try #require(UserDefaults(suiteName: initialDomain))
        let initial = ScoreboardCloudClient(preferences: initialDefaults, participationStorage: secureStorage)
        defer { initial.disconnect(); initialDefaults.removePersistentDomain(forName: initialDomain) }
        let matchID = UUID()
        let grant = ScoreboardCloudEnrollment(serviceURL: "https://scores.example.test", token: "private-participant-fixture", sessionID: "ABCDEFGHJK",
            accountID: "owner", hostLocalID: "mac-host", remoteDeviceID: "joining-device", access: "participant",
            devicePublicKey: ScoreboardDeviceIdentity.publicKey, matchID: matchID, matchName: "Court")
        #expect(initial.acceptEnrollment(try JSONEncoder().encode(grant), authenticatedHostID: "mac-host", localDeviceID: "joining-device"))
        initial.didPairLocalHost("another-nearby-host")
        initial.leaveGuestMatch()
        let persisted = try #require(savedGrantData)
        #expect(!String(decoding: persisted, as: UTF8.self).contains("password"))
        let recent = ScoreboardRecentMatch(id: matchID.uuidString, title: "Court", matchID: matchID,
            nearbyOwnerID: "mac-owner", server: grant.serviceURL, usedAt: Date(), cloudSessionID: grant.sessionID)
        let room = ScoreboardCloudSession(id: grant.sessionID, name: "Court", ownerID: "owner", ownerDeviceID: "mac", hostDeviceID: "mac",
            generation: "generation", expiresAt: Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000,
            members: [], hostOnline: true, hostLocalID: "mac-host", matchID: matchID)
        fixture.configureRoom(room)
        let (restored, preferences, domain) = try restoredCloudFixture(fixture, participationStorage: secureStorage)
        defer { restored.cloudEnabled = false; preferences.removePersistentDomain(forName: domain) }
        #expect(restored.hasSavedParticipation(for: recent))
        var prepared = false
        #expect(try await restored.resumeRecentMatch(recent, beforeConnect: { _ in prepared = true }))
        restored.setRemoteActive(true, allowsCloud: false)
        #expect(prepared && restored.selectedSessionID == grant.sessionID)
        #expect(fixture.requests == ["/api/eula", "/api/sessions/ABCDEFGHJK"])
        var foreign = recent; foreign.matchID = UUID()
        #expect(!restored.hasSavedParticipation(for: foreign))
        foreign = recent; foreign.server = "https://other.example.test"
        #expect(!restored.hasSavedParticipation(for: foreign))

        var wrongRoom = room; wrongRoom.matchID = UUID()
        fixture.configureRoom(wrongRoom); prepared = false
        await #expect(throws: (any Error).self) { try await restored.resumeRecentMatch(recent, beforeConnect: { _ in prepared = true }) }
        #expect(!prepared)
        fixture.configureRoom(room, error: 403)
        #expect(try await restored.resumeRecentMatch(recent, beforeConnect: { _ in prepared = true }) == false)
        #expect(!prepared && !restored.hasSavedParticipation(for: recent))
        let (afterRevocation, lastPreferences, lastDomain) = try restoredCloudFixture(fixture, participationStorage: secureStorage)
        defer { afterRevocation.cloudEnabled = false; lastPreferences.removePersistentDomain(forName: lastDomain) }
        #expect(!afterRevocation.hasSavedParticipation(for: recent))
    }

    @Test("Cloud agreement acceptance is scoped by service, version, and validity")
    func cloudAgreementScope() {
        let document = ScoreboardCloudAgreement(version:"0.1",title:"Policy",content:"Terms",publishedAt:0,placeholder:true)
        let now = Date()
        let acceptance = ScoreboardCloudAgreementAcceptance(origin:"https://cloud.example.test",version:"0.1",receipt:"signed-receipt",acceptedAt:now.timeIntervalSince1970 * 1000)
        #expect(acceptance.isCurrent(document,origin:acceptance.origin,now:now))
        #expect(!acceptance.isCurrent(document,origin:"https://selfhost.example.test",now:now))
        var changed = document; changed.version = "0.2"
        #expect(!acceptance.isCurrent(changed,origin:acceptance.origin,now:now))
        #expect(!acceptance.isCurrent(document,origin:acceptance.origin,now:now.addingTimeInterval(366 * 86400)))
    }

    @Test("Cloud receipt scope normalizes WebSocket upgrades and HTTP API paths without changing service identity")
    func cloudAgreementNetworkOrigins() throws {
        #expect(try ScoreboardCloudAgreementAcceptance.serviceOrigin(for:URL(string:"wss://cloud.example.test/api/sessions/ABCDEFGHJK/socket")!) == "https://cloud.example.test")
        #expect(try ScoreboardCloudAgreementAcceptance.serviceOrigin(for:URL(string:"https://cloud.example.test/api/sessions/ABCDEFGHJK/assets/home?asset=logo")!) == "https://cloud.example.test")
        #expect(try ScoreboardCloudAgreementAcceptance.serviceOrigin(for:URL(string:"ws://localhost:8787/api/sessions/ABCDEFGHJK/socket")!) == "http://localhost:8787")
        #expect(throws:(any Error).self) { try ScoreboardCloudAgreementAcceptance.serviceOrigin(for:URL(string:"https://user:password@cloud.example.test/api/eula")!) }
    }

    @Test("Enabling cloud shows disclosure before fetching policy; decline keeps cloud off")
    func cloudDisclosureBeforeRequests() {
        let domain = "EulaDisclosure." + UUID().uuidString
        let preferences = UserDefaults(suiteName:domain)!
        defer { preferences.removePersistentDomain(forName:domain) }
        let fixture = EulaHTTPFixture(); EulaURLProtocol.fixture = fixture
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [EulaURLProtocol.self]
        let cloud = ScoreboardCloudClient(preferences:preferences,requestSession:URLSession(configuration:configuration))
        cloud.cloudEnabled = true
        #expect(cloud.cloudConsent == .disclosure)
        #expect(fixture.requests.isEmpty)
        cloud.cancelCloudAgreement()
        #expect(!cloud.cloudEnabled && cloud.cloudConsent == nil)
        #expect(!preferences.bool(forKey:"scoreboard.cloudEnabled"))
        #expect(fixture.requests.isEmpty)
    }

    @Test("Cloud requests wait for explicit acceptance and pause again when the server requires a new version")
    func cloudAgreementRequestGate() async throws {
        let domain = "EulaGate." + UUID().uuidString
        let preferences = UserDefaults(suiteName:domain)!
        defer { preferences.removePersistentDomain(forName:domain) }
        let fixture = EulaHTTPFixture(); EulaURLProtocol.fixture = fixture
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [EulaURLProtocol.self]
        let cloud = ScoreboardCloudClient(preferences:preferences,requestSession:URLSession(configuration:configuration))
        cloud.cloudEnabled = true
        await #expect(throws: (any Error).self) { try await cloud.invitationAvailability(codes:["ABCDEFGHJK"]) }
        #expect(fixture.requests.isEmpty)
        cloud.continueCloudDisclosure()
        for _ in 0..<100 {
            if case .agreement = cloud.cloudConsent { break }
            try await Task.sleep(for:.milliseconds(10))
        }
        guard case .agreement(let document) = cloud.cloudConsent else { Issue.record("The policy should be presented for explicit acceptance."); return }
        #expect(document.version == "0.1")
        #expect(fixture.requests == ["/api/eula"])
        await #expect(throws: (any Error).self) { try await cloud.invitationAvailability(codes:["ABCDEFGHJK"]) }
        #expect(fixture.requests == ["/api/eula"])
        await cloud.acceptCloudAgreement()
        #expect(cloud.cloudConsent == nil)
        _ = try await cloud.invitationAvailability(codes:["ABCDEFGHJK"])
        #expect(fixture.requests.contains("/api/invitations/status"))
        fixture.upgrade()
        await #expect(throws: (any Error).self) { try await cloud.invitationAvailability(codes:["ABCDEFGHJK"]) }
        for _ in 0..<100 {
            if case .agreement(let next) = cloud.cloudConsent, next.version == "0.2" { break }
            try await Task.sleep(for:.milliseconds(10))
        }
        guard case .agreement(let next) = cloud.cloudConsent else { Issue.record("Updated policy should be required."); return }
        #expect(next.version == "0.2")
        #expect(!cloud.isConnected)
        cloud.cancelCloudAgreement()
    }
}
