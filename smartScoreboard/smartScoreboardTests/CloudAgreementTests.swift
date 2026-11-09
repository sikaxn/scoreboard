import Foundation
import Testing

nonisolated private final class EulaHTTPFixture: @unchecked Sendable {
    let lock = NSLock()
    private var paths: [String] = []
    private var currentVersion = "0.1"
    var requests: [String] { lock.withLock { paths } }
    func upgrade() { lock.withLock { currentVersion = "0.2" } }
    func response(_ request: URLRequest) -> (Int, Data) {
        lock.withLock {
            let path = request.url!.path
            paths.append(path)
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
        let (status, data) = fixture.response(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

extension ScoreboardTests {
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
