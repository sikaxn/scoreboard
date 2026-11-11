import Foundation
import CryptoKit
import CommonCrypto
import SRP

/// A fresh challenge proves both ends still hold the original pairing secret.
/// IDs and the exact join request are authenticated; Bonjour alone grants nothing.
nonisolated enum ScoreboardNearbyReconnect {
    struct Hello: Codable, Sendable {
        var kind = "trusted-reconnect-v1"
        var matchID: UUID
        var hostID: String
        var displayID: String
    }
    struct Challenge: Codable, Sendable { var nonce: Data; var proof: Data }
    struct Response: Codable, Sendable { var request: Data; var proof: Data }
    private struct Context: Encodable {
        var hello: Hello; var nonce: Data; var role: String; var request: Data
    }
    static func challenge(hello: Hello, secret: String) throws -> Challenge {
        let nonce = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        return .init(nonce: nonce, proof: try proof(hello: hello, nonce: nonce, role: "host", request: Data(), secret: secret))
    }
    static func response(to challenge: Challenge, hello: Hello, secret: String, request: Data) throws -> Response {
        guard challenge.nonce.count == 32,
              try verifies(challenge.proof, hello: hello, nonce: challenge.nonce, role: "host", request: Data(), secret: secret) else {
            throw ScoreboardNearbyReconnectError.pairingRequired
        }
        return .init(request: request, proof: try proof(hello: hello, nonce: challenge.nonce, role: "client", request: request, secret: secret))
    }
    static func verify(_ response: Response, challenge: Challenge, hello: Hello, secret: String) throws -> Data {
        guard challenge.nonce.count == 32, response.request.count <= 2048,
              try verifies(response.proof, hello: hello, nonce: challenge.nonce, role: "client", request: response.request, secret: secret) else {
            throw ScoreboardNearbyReconnectError.pairingRequired
        }
        return response.request
    }
    private static func context(hello: Hello, nonce: Data, role: String, request: Data, secret: String) throws -> Data {
        guard hello.kind == "trusted-reconnect-v1", !hello.hostID.isEmpty, !hello.displayID.isEmpty, !secret.isEmpty else {
            throw ScoreboardNearbyReconnectError.pairingRequired
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return try encoder.encode(Context(hello: hello, nonce: nonce, role: role, request: request))
    }
    private static func proof(hello: Hello, nonce: Data, role: String, request: Data, secret: String) throws -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: try context(hello: hello, nonce: nonce, role: role, request: request, secret: secret),
            using: SymmetricKey(data: Data(secret.utf8))))
    }
    private static func verifies(_ proof: Data, hello: Hello, nonce: Data, role: String, request: Data, secret: String) throws -> Bool {
        HMAC<SHA256>.isValidAuthenticationCode(proof, authenticating: try context(hello: hello, nonce: nonce, role: role, request: request, secret: secret),
            using: SymmetricKey(data: Data(secret.utf8)))
    }
}

nonisolated enum ScoreboardNearbyReconnectError: LocalizedError {
    case pairingRequired
    var errorDescription: String? { "The saved pairing could not be verified. Pair again using the host's PIN or confirmation." }
}

/// Only the publishing native host receives this material over its signed cloud connection.
nonisolated struct ScoreboardInvitationVerifierResponse: Decodable, Sendable {
    var enabled: Bool
    var code: String?
    var revision: String?
    var salt: String?
    var hash: String?
    var matchID: UUID?
}

/// A salted SRP verifier, never the match password. Saved in the host's Keychain so
/// LAN guests can authenticate when neither device can reach the cloud.
nonisolated struct ScoreboardNearbyCloudInvitation: Codable, Equatable, Sendable {
    var server: String
    var code: String
    var revision: String
    var matchID: UUID
    var hostID: String
    var passwordSalt: String
    var salt: Data
    var verifier: Data

    var username: String { Self.username(server: server, code: code, matchID: matchID, hostID: hostID) }
    static func username(server: String, code: String, matchID: UUID, hostID: String) -> String {
        "scoreboard-nearby-invitation-v1|\(server)|\(code)|\(matchID.uuidString.lowercased())|\(hostID)"
    }
    static func origin(_ server: String) throws -> String {
        let url = try ScoreboardCloudEndpoint.validate(server)
        guard let host = url.host?.lowercased(), let scheme = url.scheme?.lowercased() else { throw URLError(.badURL) }
        let port = url.port.flatMap { ($0 == 443 && scheme == "https") || ($0 == 80 && scheme == "http") ? nil : $0 }
        return "\(scheme)://\(host.contains(":") ? "[\(host)]" : host)\(port.map { ":\($0)" } ?? "")"
    }
    func matches(server: String?, code: String, matchID: UUID, hostID: String) -> Bool {
        self.code == code && self.matchID == matchID && self.hostID == hostID &&
            (server == nil || (try? Self.origin(server!)) == self.server)
    }
}

nonisolated enum ScoreboardInvitationAuthenticationError: LocalizedError {
    case invalid, changed
    var errorDescription: String? {
        switch self {
        case .invalid: "Unable to authenticate this nearby invitation. Check the match code and password."
        case .changed: "The invitation changed. Ask the host for the current invitation and try again."
        }
    }
}

/// CPU-heavy password derivation and SRP arithmetic stay off the UI actor.
/// Each connection owns a fresh exchange; no ephemeral keys are reused.
actor ScoreboardInvitationPAKE {
    struct Challenge: Codable, Sendable {
        var salt: Data
        var passwordSalt: String
        var publicKey: Data
        var revision: String
    }
    private let client = SRPClient(configuration: SRPConfiguration<SHA256>(.N3072))
    private let server = SRPServer(configuration: SRPConfiguration<SHA256>(.N3072))
    private var keys: SRPKeyPair?
    private var peerKey: SRPKey?
    private var secret: SRPKey?
    private var proof: [UInt8]?
    private var encryptionKey: SymmetricKey?
    private var associatedData = Data()
    private var consumed = false
    private var verificationAttempted = false

    static func makeVerifier(_ input: ScoreboardInvitationVerifierResponse, server: String, hostID: String) throws -> ScoreboardNearbyCloudInvitation {
        guard input.enabled, let code = input.code, let revision = input.revision,
              let salt = input.salt, let hash = input.hash, hash.count == 64,
              let matchID = input.matchID else { throw ScoreboardInvitationAuthenticationError.invalid }
        let origin = try ScoreboardNearbyCloudInvitation.origin(server)
        let username = ScoreboardNearbyCloudInvitation.username(server: origin, code: code, matchID: matchID, hostID: hostID)
        let result = SRPClient(configuration: SRPConfiguration<SHA256>(.N3072))
            .generateSaltAndVerifier(username: username, password: hash)
        return .init(server: origin, code: code, revision: revision, matchID: matchID, hostID: hostID,
            passwordSalt: salt, salt: Data(result.salt), verifier: Data(result.verifier.bytes))
    }

    func beginClient() throws -> Data {
        guard keys == nil else { throw ScoreboardInvitationAuthenticationError.invalid }
        let pair = client.generateKeys(); keys = pair
        return Data(pair.public.bytes)
    }
    func beginServer(clientKey: Data, invitation: ScoreboardNearbyCloudInvitation) throws -> Challenge {
        guard keys == nil, clientKey.count == 384, invitation.verifier.count == 384 else { throw ScoreboardInvitationAuthenticationError.invalid }
        let pair = server.generateKeys(verifier: SRPKey(invitation.verifier))
        let peer = SRPKey(clientKey)
        let shared = try server.calculateSharedSecret(clientPublicKey: peer, serverKeys: pair, verifier: SRPKey(invitation.verifier))
        keys = pair; peerKey = peer; secret = shared
        setEncryptionKey(shared, username: invitation.username, revision: invitation.revision)
        return .init(salt: invitation.salt, passwordSalt: invitation.passwordSalt,
            publicKey: Data(pair.public.bytes), revision: invitation.revision)
    }
    func clientProof(challenge: Challenge, password: String, username: String) throws -> Data {
        guard let keys, secret == nil, challenge.publicKey.count == 384, challenge.salt.count == 32,
              (1...100).contains(challenge.passwordSalt.utf8.count), challenge.revision.utf8.count <= 100,
              (6...72).contains(password.utf16.count) else { throw ScoreboardInvitationAuthenticationError.invalid }
        let hash = try Self.passwordHash(password, salt: challenge.passwordSalt)
        let peer = SRPKey(challenge.publicKey)
        let shared = try client.calculateSharedSecret(username: username, password: hash, salt: Array(challenge.salt), clientKeys: keys, serverPublicKey: peer)
        let proof = client.calculateClientProof(username: username, salt: Array(challenge.salt), clientPublicKey: keys.public, serverPublicKey: peer, sharedSecret: shared)
        secret = shared; peerKey = peer; self.proof = proof
        setEncryptionKey(shared, username: username, revision: challenge.revision)
        return Data(proof)
    }
    func verifyClient(_ proof: Data, invitation: ScoreboardNearbyCloudInvitation) throws -> Data {
        guard let keys, let peerKey, let secret, !verificationAttempted, proof.count == 32 else { throw ScoreboardInvitationAuthenticationError.invalid }
        verificationAttempted = true // A connection gets one attempt.
        let answer = try server.verifyClientProof(proof: Array(proof), username: invitation.username,
            salt: Array(invitation.salt), clientPublicKey: peerKey, serverPublicKey: keys.public, sharedSecret: secret)
        self.proof = Array(proof)
        return Data(answer)
    }
    func verifyServerAndSeal(_ serverProof: Data, payload: Data) throws -> Data {
        guard let keys, let secret, let proof, let encryptionKey, serverProof.count == 32, !consumed else { throw ScoreboardInvitationAuthenticationError.invalid }
        consumed = true
        try client.verifyServerProof(serverProof: Array(serverProof), clientProof: proof, clientPublicKey: keys.public, sharedSecret: secret)
        return try AES.GCM.seal(payload, using: encryptionKey, authenticating: associatedData).combined!
    }
    func open(_ payload: Data) throws -> Data {
        guard proof != nil, let encryptionKey, !consumed, payload.count <= 4096 else { throw ScoreboardInvitationAuthenticationError.invalid }
        consumed = true
        return try AES.GCM.open(AES.GCM.SealedBox(combined: payload), using: encryptionKey, authenticating: associatedData)
    }
    private func setEncryptionKey(_ secret: SRPKey, username: String, revision: String) {
        associatedData = Data("\(username)|\(revision)".utf8)
        encryptionKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: secret.bytes),
            salt: Data(), info: associatedData, outputByteCount: 32)
    }
    static func passwordHash(_ password: String, salt: String) throws -> String {
        let bytes = Array(password.utf8), saltBytes = Array(salt.utf8)
        guard !bytes.isEmpty, !saltBytes.isEmpty else { throw ScoreboardInvitationAuthenticationError.invalid }
        var result = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeBytes { passwordBuffer in
            saltBytes.withUnsafeBytes { saltBuffer in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), passwordBuffer.baseAddress!.assumingMemoryBound(to: CChar.self), bytes.count,
                    saltBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self), saltBytes.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 100_000, &result, result.count)
            }
        }
        guard status == kCCSuccess else { throw ScoreboardInvitationAuthenticationError.invalid }
        return result.map { String(format: "%02x", $0) }.joined()
    }
}
