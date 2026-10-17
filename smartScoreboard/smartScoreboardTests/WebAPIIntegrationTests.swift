import Foundation
import Testing

extension ScoreboardTests {
    @Test("HTTP catalog, authentication, duplicate commands, validation, and key revocation", .timeLimit(.minutes(1)))
    func webAPIHTTPIntegration() async throws {
        store.isWebControlEnabled = true
        store.isWebAPIEnabled = true
        defer { store.setWebAPIEnabled(false) }
        for _ in 0..<100 {
            if store.webAPIStatus.isRunning { break }
            if case .failed = store.webAPIStatus { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let port = try #require({ () -> UInt16? in
            guard case .running(let port, _, _) = store.webAPIStatus else { return nil }
            return port
        }(), "The test HTTP listener must start on an OS-assigned port: \(store.webAPIStatus)")
        func request(_ path: String, body: Data? = nil, key: String? = nil) async throws -> (Int, Data) {
            var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)" + path)!)
            request.timeoutInterval = 4
            if let body { request.httpMethod = "POST"; request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
            if let key { request.setValue(key, forHTTPHeaderField: "X-API-Key") }
            let (data, response) = try await URLSession.shared.data(for: request)
            return ((response as! HTTPURLResponse).statusCode, data)
        }
        let catalogResponse = try await request("/api/v2/control/operations")
        #expect(catalogResponse.0 == 200, "operation catalog HTTP")
        let catalog = try JSONDecoder().decode([ScoreboardControlOperation].self, from: catalogResponse.1)
        #expect(catalog.count == ScoreboardControlOperation.all.count, "HTTP shared catalog")
        #expect(catalog.first { $0.id == "sound.play" }!.textChoices.contains("whistle"), "catalog choices")
        let command = cmd("score.adjust", side: .home, value: 1)
        let body = try JSONEncoder().encode(command)
        let key = store.webControlAPIKey
        let missing = try await request("/api/v2/control", body: body)
        #expect(missing.0 == 401, "missing key HTTP")
        let wrong = try await request("/api/v2/control", body: body, key: "WRONGKEY01234567")
        #expect(wrong.0 == 401, "wrong key HTTP")
        let before = store.homeScore
        let applied = try await request("/api/v2/control", body: body, key: key.lowercased())
        #expect(applied.0 == 200 && store.homeScore == before + 1, "case insensitive key HTTP")
        let retry = try await request("/api/v2/control", body: body, key: key)
        #expect(retry.0 == 200 && store.homeScore == before + 1, "HTTP duplicate")
        let malformed = try await request("/api/v2/control", body: Data("{".utf8), key: key)
        #expect(malformed.0 == 400, "malformed JSON HTTP")
        var wrongSport = cmd("score.adjust", side: .home, value: 1); wrongSport.sport = .soccer
        let mismatch = try await request("/api/v2/control", body: try JSONEncoder().encode(wrongSport), key: key)
        #expect(mismatch.0 == 409, "sport conflict HTTP")
        store.isWebControlEnabled = false
        let disabled = try await request("/api/v2/control", body: body, key: key)
        #expect(disabled.0 == 403, "control disabled HTTP")
        store.isWebControlEnabled = true
        store.resetWebControlAPIKey()
        #expect(store.webControlAPIKey.count == 16 && store.webControlAPIKey.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }, "key format")
        let revoked = try await request("/api/v2/control", body: body, key: key)
        #expect(revoked.0 == 401, "reset key revokes HTTP")
        let newKey = try await request("/api/v2/control", body: body, key: store.webControlAPIKey.lowercased())
        #expect(newKey.0 == 200, "new key HTTP")
    }
}
