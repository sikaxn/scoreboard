import Foundation
import Network
import Testing

@Suite("Remote Display QR pairing")
@MainActor
struct RemoteDisplayPairingCodeTests {
    private let displayID = "5E941023-DB7E-4F4C-A2B5-8AB97B6954EF"

    @Test("Pairing QR round trip preserves leading zeroes")
    func roundTrip() throws {
        let code = ScoreboardRemoteDisplayPairingCode(displayID: displayID, pairingCode: "0042")
        #expect(try #require(ScoreboardRemoteDisplayPairingCode(scannedValue: code.encodedValue)) == code)
    }

    @Test("Reject unrelated, ambiguous, and malformed QR codes")
    func rejectsInvalidCodes() {
        let valid = ScoreboardRemoteDisplayPairingCode(displayID: displayID, pairingCode: "1234").encodedValue
        let invalid = [
            "1234", "https://example.com", valid.replacingOccurrences(of: "v=1", with: "v=2"),
            valid + "&code=5678", valid + "&host=192.168.1.1", valid + "#fragment",
            valid.replacingOccurrences(of: "code=1234", with: "code=123"),
            valid.replacingOccurrences(of: "code=1234", with: "code=12345"),
            valid.replacingOccurrences(of: "code=1234", with: "code=abcd"),
            valid.replacingOccurrences(of: "code=1234", with: "code=１２３４"),
            valid.replacingOccurrences(of: displayID, with: "unknown"),
            valid.replacingOccurrences(of: "//pair?", with: "//pair/other?"),
            valid.replacingOccurrences(of: "//pair?", with: "//user@pair?"),
            valid.replacingOccurrences(of: "//pair?", with: "//pair:80?"),
            String(repeating: "x", count: 513)
        ]
        for value in invalid {
            #expect(ScoreboardRemoteDisplayPairingCode(scannedValue: value) == nil, "Unexpected pairing QR: \(value)")
        }
    }

    @Test("Scanning resolves only a matching discovered display")
    func requiresDiscoveredDisplay() {
        let code = ScoreboardRemoteDisplayPairingCode(displayID: displayID, pairingCode: "1234")
        let other = source(displayID: UUID().uuidString)
        let matching = source(displayID: displayID.lowercased())
        #expect(code.discoveredSource(in: []) == nil)
        #expect(code.discoveredSource(in: [other]) == nil)
        #expect(code.discoveredSource(in: [other, matching])?.id == matching.id)
        #expect(code.discoveredSource(in: [source(displayID: nil)]) == nil)
    }

    private func source(displayID: String?) -> ScoreboardRemoteDisplaySource {
        ScoreboardRemoteDisplaySource(
            endpoint: .service(name: "Test Display", type: "_scorebrd-tv._tcp", domain: "local.", interface: nil),
            discoveryInfo: displayID.map { ["displayID": $0, "name": "Test Display"] }
        )
    }
}
