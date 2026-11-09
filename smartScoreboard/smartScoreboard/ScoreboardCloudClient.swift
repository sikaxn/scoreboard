import Combine
import Foundation
import Security
import CryptoKit

nonisolated struct ScoreboardCloudMatchContext: Codable, Equatable, Sendable {
    var matchID: UUID
    var runtimeID: UUID
    var ownerDeviceID: String
    var epoch: UInt64
    var name: String
    var hostDeviceID: String? = nil
}

nonisolated struct ScoreboardMatchInvitation: Equatable, Sendable {
    var server: String
    var code: String
    var password: String?
    static func parse(_ value: String) -> Self? {
        guard value.utf8.count <= 4096, let url = URLComponents(string: value), url.user == nil, url.password == nil else { return nil }
        let query = url.queryItems ?? []
        func item(_ name: String) -> String? { let matches = query.filter { $0.name == name }; return matches.count == 1 ? matches.first?.value : nil }
        let code: String, server: String
        if url.scheme == "smartscoreboard", url.host == "join", let value = item("code"), let origin = item("server") { code = value; server = origin }
        else if url.scheme == "https" || url.scheme == "http", url.path.hasPrefix("/join/") {
            code = String(url.path.dropFirst(6))
            var origin = url; origin.path = ""; origin.query = nil; origin.fragment = nil; server = origin.string ?? ""
        } else { return nil }
        guard code.count == 10, code.allSatisfy({ "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains($0) }),
              (try? ScoreboardCloudEndpoint.validate(server)) != nil else { return nil }
        let fragment = URLComponents(string: "?" + (url.percentEncodedFragment ?? ""))?.queryItems ?? []
        let passwords = fragment.filter { $0.name == "password" }
        guard passwords.count <= 1 else { return nil }
        return .init(server: server, code: code, password: passwords.first?.value)
    }
    var url: URL? {
        guard let base = try? ScoreboardCloudEndpoint.validate(server), var components = URLComponents(url: base.appendingPathComponent("join/\(code)"), resolvingAgainstBaseURL: false) else { return nil }
        if let password { var fragment = URLComponents(); fragment.queryItems = [.init(name: "password", value: password)]; components.percentEncodedFragment = fragment.percentEncodedQuery }
        return components.url
    }
}

@MainActor enum ScoreboardDeviceIdentity {
    private static let key: P256.Signing.PrivateKey = {
        #if SCOREBOARD_TESTING
        return P256.Signing.PrivateKey()
        #else
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "smartScoreboard.device-identity", kSecAttrAccount as String: "signing",
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var value: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess, let data = value as? Data,
           let restored = try? P256.Signing.PrivateKey(rawRepresentation: data) { return restored }
        let generated = P256.Signing.PrivateKey()
        var item = query; item.removeValue(forKey: kSecReturnData as String); item.removeValue(forKey: kSecMatchLimit as String)
        item[kSecValueData as String] = generated.rawRepresentation
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        _ = SecItemAdd(item as CFDictionary, nil)
        return generated
        #endif
    }()
    static var publicKey: String { key.publicKey.x963Representation.base64EncodedString() }
    static func sign(_ request: inout URLRequest) throws {
        guard let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
        let timestamp = Int(Date().timeIntervalSince1970), nonce = UUID().uuidString
        let path = components.percentEncodedPath + (components.percentEncodedQuery.map { "?" + $0 } ?? "")
        let text = "\(request.httpMethod ?? "GET")\n\(path)\n\(timestamp)\n\(nonce)"
        struct Proof: Encodable { var timestamp: Int; var nonce: String; var signature: String }
        let proof = Proof(timestamp: timestamp, nonce: nonce, signature: try key.signature(for: Data(text.utf8)).rawRepresentation.base64EncodedString())
        request.setValue(try JSONEncoder().encode(proof).base64EncodedString(), forHTTPHeaderField: "X-Scoreboard-Device-Proof")
    }
}

nonisolated struct ScoreboardCloudMember: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var uid: String
    var name: String
    var role: String
    var requestedControl: Bool
    var connected: Bool? = nil
    var localDeviceID: String? = nil
    var connectionStatus: ScoreboardClientConnectionStatus? = nil
    var devicePublicKey: String? = nil
    var canControl: Bool? = nil
}

nonisolated struct ScoreboardCloudViewer: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var mode: String
}

nonisolated struct ScoreboardCloudSession: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var ownerID: String
    var ownerDeviceID: String
    var hostDeviceID: String?
    var generation: String
    var expiresAt: TimeInterval // Unix milliseconds, matching the relay protocol.
    var members: [ScoreboardCloudMember]
    var hostOnline: Bool
    var persistent: Bool?
    var enabled: Bool?
    var hostLocalID: String?
    var viewers: [ScoreboardCloudViewer]? = nil
    var supportsConnectionDiagnostics: Bool? = nil
    var matchID: UUID? = nil
    var runtimeID: UUID? = nil
    var authorityEpoch: UInt64? = nil
    var invitationCode: String? = nil
    var invitationRevision: String? = nil
    var pendingPublisherGrant: ScoreboardPendingPublisher? = nil
}
nonisolated struct ScoreboardPendingPublisher: Codable, Equatable, Sendable {
    var grantID: String; var targetDeviceID: String; var epoch: UInt64; var runtimeID: UUID
}

nonisolated enum ScoreboardCloudEndpoint {
    static let publicServiceURL = "https://scoreboardcloud.studenttechsupport.com"
    static func publicViewingURL(base: URL, sessionID: String, token: String) -> URL? {
        var url = URLComponents(url: base.appendingPathComponent("views/match.html"), resolvingAgainstBaseURL: false)
        url?.queryItems = [.init(name: "session", value: sessionID)]
        url?.fragment = "view=\(token)"
        return url?.url
    }

    static func isPublicService(_ value: String) -> Bool {
        guard let url = try? validate(value), let publicURL = URL(string: publicServiceURL) else { return false }
        return url.scheme == publicURL.scheme && url.host?.lowercased() == publicURL.host
            && (url.port ?? 443) == 443
    }

    static func validate(_ value: String) throws -> URL {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              url.path.isEmpty || url.path == "/",
              let host = url.host,
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "[::1]"].contains(host)) else {
            throw URLError(.badURL)
        }
        return url
    }
    static func sameService(_ first: String, _ second: String) -> Bool {
        guard let first = try? validate(first), let second = try? validate(second) else { return false }
        return first.scheme?.lowercased() == second.scheme?.lowercased() && first.host?.lowercased() == second.host?.lowercased()
            && (first.port ?? (first.scheme == "https" ? 443 : 80)) == (second.port ?? (second.scheme == "https" ? 443 : 80))
    }
}

nonisolated enum ScoreboardCloudServiceMode: String, CaseIterable, Identifiable, Sendable {
    case publicCloud
    case selfHosted

    var id: String { rawValue }
}

nonisolated struct ScoreboardCloudAccount: Codable, Sendable {
    var id: String; var name: String; var role: String
    var relay: ScoreboardRelayEntitlement? = nil
}
nonisolated struct ScoreboardRelayEntitlement: Codable, Sendable {
    var active: Bool
    var expiresAt: TimeInterval?
    func isValid(at date: Date = Date()) -> Bool { active && (expiresAt.map { $0 > date.timeIntervalSince1970 * 1000 } ?? true) }
    var description: String {
        guard isValid() else { return "No active cloud relay entitlement" }
        return expiresAt.map { "Cloud relay until " + Date(timeIntervalSince1970: $0 / 1000).formatted(date: .abbreviated, time: .omitted) } ?? "Cloud relay · No expiry"
    }
}
nonisolated struct ScoreboardCloudSessionChoice: Codable, Identifiable, Sendable {
    var id: String; var name: String; var expiresAt: TimeInterval
    var hostDeviceID: String?
}
nonisolated struct ScoreboardCloudRegisteredDevice: Decodable, Identifiable, Sendable {
    var key: String; var id: String; var name: String; var access: String; var revoked: Int
}
nonisolated struct ScoreboardCloudEnrollment: Codable, Sendable {
    var kind = "scoreboard.cloud.enrollment.v1"
    var enrollmentID = UUID()
    var serviceURL: String; var token: String; var sessionID: String; var accountID: String
    var hostLocalID: String; var remoteDeviceID: String
    var access: String? = nil
    var devicePublicKey: String? = nil
}

nonisolated struct ScoreboardPublisherGrant: Codable, Sendable {
    var kind = "scoreboard.match.publisher.v1"
    var serviceURL: String; var token: String; var grantID: String; var sessionID: String
    var matchID: UUID; var runtimeID: UUID; var epoch: UInt64
    var hostLocalID: String; var remoteDeviceID: String; var devicePublicKey: String
}

// Only public keys enter LAN heartbeat metadata. Each app run keeps its private
// key in memory; the durable account credential itself remains in Keychain.
@MainActor enum ScoreboardCloudEnrollmentCrypto {
    private static let privateKey = P256.KeyAgreement.PrivateKey()
    static var publicKey: String { privateKey.publicKey.x963Representation.base64EncodedString() }
    private struct Envelope: Codable {
        var kind = "scoreboard.cloud.enrollment.sealed.v1"
        var publicKey: Data
        var ciphertext: Data
    }
    private static func context(hostID: String, deviceID: String) -> Data {
        Data("scoreboard.cloud.enrollment.v1|\(hostID)|\(deviceID)".utf8)
    }
    static func seal(_ data: Data, recipient: String, pairingSecret: String, hostID: String, deviceID: String) throws -> Data {
        guard let keyBytes = Data(base64Encoded: recipient), keyBytes.count == 65 else { throw URLError(.cannotDecodeRawData) }
        let recipientKey = try P256.KeyAgreement.PublicKey(x963Representation: keyBytes)
        let ephemeral = P256.KeyAgreement.PrivateKey()
        let secret = try ephemeral.sharedSecretFromKeyAgreement(with: recipientKey)
        let aad = context(hostID: hostID, deviceID: deviceID)
        let key = secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: aad, sharedInfo: Data(pairingSecret.utf8), outputByteCount: 32)
        let encrypted = try AES.GCM.seal(data, using: key, authenticating: aad)
        guard let combined = encrypted.combined else { throw URLError(.badServerResponse) }
        return try JSONEncoder().encode(Envelope(publicKey: ephemeral.publicKey.x963Representation, ciphertext: combined))
    }
    static func isEnvelope(_ data: Data) -> Bool {
        (try? JSONDecoder().decode(Envelope.self, from: data))?.kind == "scoreboard.cloud.enrollment.sealed.v1"
    }
    static func open(_ data: Data, pairingSecret: String, hostID: String, deviceID: String) throws -> Data {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.kind == "scoreboard.cloud.enrollment.sealed.v1" else { throw URLError(.cannotDecodeRawData) }
        let publicKey = try P256.KeyAgreement.PublicKey(x963Representation: envelope.publicKey)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: publicKey)
        let aad = context(hostID: hostID, deviceID: deviceID)
        let key = secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: aad, sharedInfo: Data(pairingSecret.utf8), outputByteCount: 32)
        return try AES.GCM.open(AES.GCM.SealedBox(combined: envelope.ciphertext), using: key, authenticating: aad)
    }
}
nonisolated private struct CloudCredential: Codable {
    var serviceURL: String
    var token: String
    var sessionID: String
    var access: String?
    var accountID: String?
    var hostLocalID: String?
    var remoteSessionID: String?
    var remoteHostLocalID: String?
    var requestControl: Bool? = nil
}

nonisolated private enum CloudKeychain {
    private static let service = "smartScoreboard.cloud-session"
    static func load(account: String = "current") -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: account,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
    static func save(_ data: Data?, account: String = "current") throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: account]
        if let data {
            let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if status == errSecItemNotFound {
                var item = query
                item[kSecValueData as String] = data
                item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw CocoaError(.fileWriteNoPermission) }
            } else if status != errSecSuccess { throw CocoaError(.fileWriteNoPermission) }
        } else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw CocoaError(.fileWriteNoPermission) }
        }
    }
}

@MainActor final class ScoreboardCloudClient: ObservableObject {
    static let shared = ScoreboardCloudClient()
    let receiver = ScoreboardRemoteDisplayReceiver()
    var connectionStatusProvider: (() -> ScoreboardClientConnectionStatus)?
    private var lastReportedConnectionStatus: ScoreboardClientConnectionStatus?
    @Published var cloudEnabled = false {
        didSet {
            preferences.set(cloudEnabled, forKey: "scoreboard.cloudEnabled")
            if !cloudEnabled { suspendConnections(); status = "Cloud is disabled." }
            else if !oldValue { reconnect() }
        }
    }
    private var matchContext: ScoreboardCloudMatchContext?
    var nearbyInvitationChangedHandler: (() -> Void)?
    private var nearbyInvitationTask: Task<Void, Never>?
    private var lastNearbyInvitationSync = Date.distantPast
    private var nearbyInvitationCache: [String: ScoreboardNearbyCloudInvitation] = [:]
    private var loadedNearbyInvitationCache = false
    private var nearbyInvitationCacheKey: String? {
        guard let context = matchContext, let hostID = localHostIDProvider?(),
              let identity = publisherActive ? publisherGrant?.grantID : credential?.accountID,
              let server = try? ScoreboardNearbyCloudInvitation.origin(publisherActive ? (publisherGrant?.serviceURL ?? serviceURL) : (credential?.serviceURL ?? serviceURL))
        else { return nil }
        return "\(server)|\(identity)|\(context.matchID)|\(hostID)"
    }
    var nearbyInvitation: ScoreboardNearbyCloudInvitation? {
        guard canHostProvider?() == true, hasOwnerAccount || publisherActive,
              let key = nearbyInvitationCacheKey else { return nil }
        if !loadedNearbyInvitationCache {
            loadedNearbyInvitationCache = true
            #if !SCOREBOARD_TESTING
            if let data = CloudKeychain.load(account: "nearby-invitations") {
                nearbyInvitationCache = (try? JSONDecoder().decode([String: ScoreboardNearbyCloudInvitation].self, from: data)) ?? [:]
            }
            #endif
        }
        return nearbyInvitationCache[key]
    }
    private func setNearbyInvitation(_ value: ScoreboardNearbyCloudInvitation?, key: String) {
        guard nearbyInvitationCache[key] != value else { return }
        nearbyInvitationCache[key] = value
        #if !SCOREBOARD_TESTING
        try? CloudKeychain.save(JSONEncoder().encode(nearbyInvitationCache), account: "nearby-invitations")
        #endif
        nearbyInvitationChangedHandler?()
    }
    private func syncNearbyInvitation(force: Bool = false) {
        guard isHost, canHostProvider?() == true, let room = session, let credential = transportCredential ?? credential,
              let key = nearbyInvitationCacheKey, let hostID = localHostIDProvider?() else { return }
        _ = nearbyInvitation // Load the host's offline cache before comparing revisions.
        let changed = room.invitationRevision != nearbyInvitationCache[key]?.revision
        if changed { setNearbyInvitation(nil, key: key) }
        guard nearbyInvitationTask == nil, force || changed || Date().timeIntervalSince(lastNearbyInvitationSync) >= 15 else { return }
        lastNearbyInvitationSync = Date()
        let runID = connectionID
        nearbyInvitationTask = Task { [weak self] in
            guard let self else { return }
            defer { nearbyInvitationTask = nil }
            do {
                let input: ScoreboardInvitationVerifierResponse = try await get(base: ScoreboardCloudEndpoint.validate(credential.serviceURL),
                    path: "api/sessions/\(room.id)/nearby-invitation", token: credential.token)
                let verifier: ScoreboardNearbyCloudInvitation?
                if input.enabled, let cached = nearbyInvitationCache[key], cached.revision == input.revision,
                   cached.code == input.code, cached.matchID == input.matchID, cached.passwordSalt == input.salt {
                    verifier = cached
                } else if input.enabled {
                    verifier = try await Task.detached {
                        try ScoreboardInvitationPAKE.makeVerifier(input, server: credential.serviceURL, hostID: hostID)
                    }.value
                } else { verifier = nil }
                guard !Task.isCancelled, connectionID == runID, nearbyInvitationCacheKey == key,
                      input.matchID == nil || input.matchID == matchContext?.matchID,
                      input.revision == nil || input.revision == session?.invitationRevision else { return }
                setNearbyInvitation(verifier, key: key)
            } catch {
                // Connectivity loss preserves the last verified invitation. Explicit
                // credential rejection revokes it; guests never need a cloud call.
                let rejection = error as NSError
                if rejection.domain == "ScoreboardCloud", [401, 403].contains(rejection.code), nearbyInvitationCacheKey == key {
                    setNearbyInvitation(nil, key: key)
                }
            }
        }
    }
    private var isActivatingMatch = false
    @Published var serviceMode: ScoreboardCloudServiceMode {
        didSet { preferences.set(serviceMode.rawValue, forKey: "scoreboard.cloudServiceMode") }
    }
    @Published var selfHostedURL: String {
        didSet { preferences.set(selfHostedURL, forKey: "scoreboard.cloudSelfHostedURL") }
    }
    var serviceURL: String {
        serviceMode == .publicCloud ? ScoreboardCloudEndpoint.publicServiceURL : selfHostedURL
    }
    var connectionServiceName: String {
        serviceMode == .publicCloud ? "Public Cloud (Experimental)" : "Self-hosted · \(URL(string: selfHostedURL)?.host ?? "Not configured")"
    }
    func invitationAvailability(codes: [String]) async throws -> [ScoreboardCloudInvitationStatus] {
        guard cloudEnabled, !codes.isEmpty else { return [] }
        struct Input: Encodable { var codes: [String] }
        struct Result: Decodable { var invitations: [ScoreboardCloudInvitationStatus] }
        let result: Result = try await call(base: ScoreboardCloudEndpoint.validate(serviceURL),
            path: "api/invitations/status", body: Input(codes: Array(Set(codes)).prefix(20).map { $0 }))
        return result.invitations
    }
    private let preferences: UserDefaults
    @Published var hostName: String = "" {
        didSet { preferences.set(hostName, forKey: "scoreboard.cloudHostName") }
    }
    @Published var hostingEnabled: Bool = false {
        didSet {
            guard !isActivatingMatch else { return }
            if let context = matchContext {
                var record = ScoreboardMatchIndex.record(for: context.matchID)
                record.cloudEnabled = hostingEnabled; record.serviceURL = serviceURL
                ScoreboardMatchIndex.save(record)
            }
            if hostingEnabled != oldValue { updateHosting() }
        }
    }
    @Published var cloudFailoverEnabled: Bool = false {
        didSet { preferences.set(cloudFailoverEnabled, forKey: "scoreboard.cloudFailoverEnabled"); if cloudFailoverEnabled { hostReadyHandler?() } }
    }
    @Published private(set) var account: ScoreboardCloudAccount?
    @Published private(set) var sessions: [ScoreboardCloudSessionChoice] = []
    @Published private(set) var registeredDevices: [ScoreboardCloudRegisteredDevice] = []
    @Published private(set) var selectedSessionID = ""
    @Published private(set) var isRemotePairing = false
    var isRemoteRegistration: Bool { credential?.access == "remote" || credential?.access == "participant" }
    var hasAccountRegistration: Bool { credential?.access != nil }
    var hasOwnerAccount: Bool { credential?.access == "owner" }
    var canEnableOnlineSharing: Bool {
        cloudEnabled && hasOwnerAccount && account?.relay?.isValid() == true && (canHostProvider?() == true || canManageMatch)
    }
    var onlineSharingGuidance: String {
        if !cloudEnabled { return "Turn on Enable Cloud to share this match online." }
        if !hasOwnerAccount { return "Sign in with the owner's account to share this match online." }
        guard let account else { return "Refresh Account Access to check cloud relay availability." }
        guard let relay = account.relay else { return "This server does not report relay entitlements. Deploy the matching Cloud Worker update, then refresh account access." }
        guard relay.isValid() else { return "Cloud relay access is missing or expired. On the website, open Administration → Accounts, choose No expiry or Until date for this account, and save relay access. Admin status alone does not grant relay access. Then refresh account access here." }
        if canHostProvider?() != true && !canManageMatch { return "Return to your local scoreboard to share a match. This device is currently following another host or acting as a display." }
        return hostingEnabled ? "Online sharing is enabled for this match." : "Turn on Share This Match Online below. Signing in alone does not enable sharing; new matches start with sharing off."
    }
    var hasMatchPublishingGrant: Bool { publisherGrant != nil }
    var selectedHostLocalID: String? { session?.hostLocalID ?? credential?.hostLocalID }
    var hostReadyHandler: (() -> Void)?
    private var remoteActive = false
    private var remoteAllowsCloud = false
    @Published private(set) var status = "Cloud connection is off."
    @Published private(set) var session: ScoreboardCloudSession?
    @Published private(set) var linkCode: String?
    @Published private(set) var verificationURL: URL?
    @Published private(set) var isConnected = false
    @Published private(set) var isLinked = false
    @Published private(set) var isLinking = false
    var isHost: Bool { session?.hostDeviceID == deviceID && deviceID != nil }
    var isPublishingLocalHost: Bool { isHost && (hostingEnabled || publisherActive) && canHostProvider?() == true }
    var canControl: Bool { ScoreboardRemoteDisplayDeviceType.current.supportsControl && session?.members.first { $0.id == deviceID }?.role == "controller" }
    private(set) var deviceID: String?
    private var credential: CloudCredential?
    private var parkedOwnerCredential: CloudCredential?
    private var publisherGrant: ScoreboardPublisherGrant?
    private var publisherActive = false
    private(set) var preparedPublisherGrant: ScoreboardPublisherGrant?
    private var guestDeviceIDs: [String: String] = [:]
    private var committingPublisher = false
    var canManageMatch: Bool { hasOwnerAccount && session?.ownerID == account?.id }
    private var socket: URLSessionWebSocketTask?
    private var requestSession = URLSession(configuration: .ephemeral)
    private var connectionTask: Task<Void, Never>?
    private var homePauseTask: Task<Void, Never>?
    private var homePausedMatchID: UUID?
    private var linkTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var lastStateAt: Date?
    private var lastPublishAt = Date.distantPast
    private var pendingState: ScoreboardWebAPIState?
    private var publishTask: Task<Void, Never>?
    private var stateProvider: (() -> ScoreboardWebAPIState?)?
    private var imageProvider: (() -> [String: ScoreboardWebAPIImageResponse])?
    private var transportCredential: CloudCredential?
    private var imageSyncTask: Task<Void, Never>?
    private var uploadedImages: [String: String] = [:]
    private var lastImageSyncAt = Date.distantPast
    @Published private(set) var imageSyncError: String?
    private var commentatorProvider: (() -> ScoreboardWebAPICommentatorPayload?)?
    private var commandHandler: ((ScoreboardControlCommand) -> ScoreboardControlResult)?
    private var canHostProvider: (() -> Bool)?
    private var localHostIDProvider: (() -> String)?
    private var connectionID = UUID() {
        didSet {
            imageSyncTask?.cancel(); imageSyncTask = nil; transportCredential = nil
            imageSyncError = nil; lastImageSyncAt = .distantPast
        }
    }
    private var linkRunID = UUID()
    private var pendingRemotePermissions: [String: Bool] = [:]
    private var remotePermissionTasks: [String: Task<Void, Never>] = [:]
    private var acceptedEnrollments = Set<UUID>()

    init(preferences: UserDefaults = ScoreboardPreferences.current) {
        self.preferences = preferences
        cloudEnabled = preferences.object(forKey: "scoreboard.cloudEnabled") as? Bool ?? preferences.bool(forKey: "scoreboard.cloudHostingEnabled")
        hostName = preferences.string(forKey: "scoreboard.cloudHostName") ?? ScoreboardRemoteDisplayDeviceName.current ?? "Scoreboard Host"
        hostingEnabled = preferences.bool(forKey: "scoreboard.cloudHostingEnabled")
        cloudFailoverEnabled = preferences.bool(forKey: "scoreboard.cloudFailoverEnabled")
        let legacyURL = preferences.string(forKey: "scoreboard.cloudServiceURL") ?? ""
        selfHostedURL = preferences.string(forKey: "scoreboard.cloudSelfHostedURL")
            ?? (ScoreboardCloudEndpoint.isPublicService(legacyURL) ? "" : legacyURL)
        serviceMode = preferences.string(forKey: "scoreboard.cloudServiceMode")
            .flatMap(ScoreboardCloudServiceMode.init(rawValue:))
            ?? (legacyURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ScoreboardCloudEndpoint.isPublicService(legacyURL)
                ? .publicCloud : .selfHosted)
    }

    func selectService(for url: String) {
        if ScoreboardCloudEndpoint.isPublicService(url) {
            serviceMode = .publicCloud
        } else {
            selfHostedURL = url
            serviceMode = .selfHosted
        }
    }

    func activateMatch(_ context: ScoreboardCloudMatchContext) {
        let changed = matchContext?.matchID != context.matchID
        if changed { suspendTransport(); session = nil }
        matchContext = context
        nearbyInvitationChangedHandler?()
        let record = ScoreboardMatchIndex.record(for: context.matchID)
        isActivatingMatch = true
        hostingEnabled = record.cloudEnabled
        isActivatingMatch = false
        if changed, credential != nil, cloudEnabled, hostingEnabled, !remoteActive { reconnect() }
    }

    func authorityDidChange(_ context: ScoreboardCloudMatchContext, isAuthority: Bool) {
        matchContext = context
        nearbyInvitationChangedHandler?()
        let shouldPublish = isAuthority && publisherGrant?.matchID == context.matchID && publisherGrant?.runtimeID == context.runtimeID && publisherGrant?.epoch == context.epoch
        if shouldPublish != publisherActive {
            publisherActive = shouldPublish
            if shouldPublish && cloudEnabled { reconnect() }
            else if !shouldPublish { suspendTransport() }
        }
        commitMatchingPublisher(context)
    }

    func preparePublisher(deviceID: String, name: String, publicKey: String, ownerHostID: String, epoch: UInt64) async throws -> ScoreboardPublisherGrant {
        guard let credential, canManageMatch, let session else { throw URLError(.userAuthenticationRequired) }
        struct Input: Encodable { var deviceID: String; var name: String; var devicePublicKey: String; var epoch: UInt64 }
        struct Result: Decodable { var token: String; var grantID: String; var sessionID: String; var matchID: UUID; var runtimeID: UUID; var epoch: UInt64; var hostLocalID: String }
        let result: Result = try await call(base: ScoreboardCloudEndpoint.validate(credential.serviceURL), path: "api/sessions/\(session.id)/publisher-grants",
            body: Input(deviceID: deviceID, name: name, devicePublicKey: publicKey, epoch: epoch), token: credential.token)
        let grant = ScoreboardPublisherGrant(serviceURL: credential.serviceURL, token: result.token, grantID: result.grantID,
            sessionID: result.sessionID, matchID: result.matchID, runtimeID: result.runtimeID, epoch: result.epoch,
            hostLocalID: ownerHostID, remoteDeviceID: deviceID, devicePublicKey: publicKey)
        preparedPublisherGrant = grant
        return grant
    }

    private func commitMatchingPublisher(_ context: ScoreboardCloudMatchContext) {
        let pending = session?.pendingPublisherGrant ?? preparedPublisherGrant.map {
            ScoreboardPendingPublisher(grantID: $0.grantID, targetDeviceID: $0.remoteDeviceID, epoch: $0.epoch, runtimeID: $0.runtimeID)
        }
        guard !committingPublisher, cloudEnabled, canManageMatch, let credential, let room = session,
              let pending, pending.runtimeID == context.runtimeID, pending.epoch == context.epoch,
              pending.targetDeviceID == context.hostDeviceID else { return }
        committingPublisher = true
        Task { @MainActor [weak self] in
            guard let self else { return }; defer { committingPublisher = false }
            do {
                struct Commit: Encodable { var grantID: String }
                let result: ScoreboardCloudSession = try await call(base: ScoreboardCloudEndpoint.validate(credential.serviceURL),
                    path: "api/sessions/\(room.id)/publisher-grants/commit", body: Commit(grantID: pending.grantID), token: credential.token)
                session = result; preparedPublisherGrant = nil
                if !publisherActive { remoteActive = true; remoteAllowsCloud = true }
                reconnect()
            } catch { status = "Cloud publishing is waiting for owner authorization: \(error.localizedDescription)" }
        }
    }

    @discardableResult func acceptPublisherGrant(_ data: Data, authenticatedHostID: String, localDeviceID: String) -> Bool {
        guard let grant = try? JSONDecoder().decode(ScoreboardPublisherGrant.self, from: data), grant.kind == "scoreboard.match.publisher.v1" else { return false }
        guard grant.remoteDeviceID == localDeviceID, grant.hostLocalID == authenticatedHostID,
              grant.devicePublicKey == ScoreboardDeviceIdentity.publicKey,
              (try? ScoreboardCloudEndpoint.validate(grant.serviceURL)) != nil else { return true }
        publisherGrant = grant
        if !hasOwnerAccount { selectService(for: grant.serviceURL) }
        isLinked = true
        status = cloudEnabled ? "A match-specific publishing grant is ready." : "A publishing grant is ready. Enable Cloud on this device to publish."
        #if !SCOREBOARD_TESTING
        try? CloudKeychain.save(JSONEncoder().encode(grant), account: "publisher")
        #endif
        return true
    }

    func resetServiceSettings() {
        cloudEnabled = false
        disconnect()
        hostingEnabled = false; cloudFailoverEnabled = false
        hostName = ScoreboardRemoteDisplayDeviceName.current ?? "Scoreboard Host"
        serviceMode = .publicCloud
        selfHostedURL = ""
        for key in ["scoreboard.cloudServiceMode", "scoreboard.cloudSelfHostedURL", "scoreboard.cloudServiceURL", "scoreboard.cloudHostName", "scoreboard.cloudHostingEnabled", "scoreboard.cloudFailoverEnabled"] {
            preferences.removeObject(forKey: key)
        }
    }

    func configure(stateProvider: @escaping () -> ScoreboardWebAPIState?,
                   commandHandler: @escaping (ScoreboardControlCommand) -> ScoreboardControlResult,
                   canHost: @escaping () -> Bool,
                   commentatorProvider: (() -> ScoreboardWebAPICommentatorPayload?)? = nil,
                   localHostID: (() -> String)? = nil,
                   imageProvider: (() -> [String: ScoreboardWebAPIImageResponse])? = nil) {
        self.stateProvider = stateProvider
        self.commandHandler = commandHandler
        self.canHostProvider = canHost
        self.commentatorProvider = commentatorProvider
        self.localHostIDProvider = localHostID
        self.imageProvider = imageProvider
        #if !SCOREBOARD_TESTING
        if let data = CloudKeychain.load(account: "publisher") {
            publisherGrant = try? JSONDecoder().decode(ScoreboardPublisherGrant.self, from: data)
        }
        if credential == nil, let data = CloudKeychain.load(),
           let restored = try? JSONDecoder().decode(CloudCredential.self, from: data),
           (try? ScoreboardCloudEndpoint.validate(restored.serviceURL)) != nil {
            credential = restored
            selectService(for: restored.serviceURL)
            isLinked = true
            selectedSessionID = restored.sessionID
            reconnect()
        }
        #endif
    }

    func beginLink(remote: Bool = false) {
        guard cloudEnabled else { status = "Enable Cloud to sign in or join online."; return }
        guard !isLinked, !isLinking else { return }
        linkTask?.cancel()
        let runID = UUID()
        linkRunID = runID
        isLinking = true
        isRemotePairing = remote
        linkTask = Task { [weak self] in
            guard let self else { return }
            defer { if linkRunID == runID { isLinking = false } }
            do {
                try Task.checkCancellation()
                let base = try ScoreboardCloudEndpoint.validate(serviceURL)
                status = "Preparing sign-in…"
                struct Link: Decodable { let code: String; let deviceToken: String; let verificationURL: URL; let interval: Int }
                let request = LinkRequest(deviceID: receiver.displayID,
                    name: ScoreboardRemoteDisplayDeviceName.current ?? "Scoreboard Device", canHost: canHostProvider?() == true, purpose: remote ? "remote" : "account")
                let link: Link = try await call(base: base, path: "api/device-links", body: request)
                try Task.checkCancellation()
                // Credentials are never sent to a URL returned by the server.
                guard link.verificationURL.scheme == base.scheme, link.verificationURL.host == base.host,
                      link.verificationURL.port == base.port else { throw URLError(.badServerResponse) }
                linkCode = link.code
                verificationURL = link.verificationURL
                status = "Sign in in your browser and approve this device."
                struct Poll: Encodable { let deviceToken: String }
                struct Approval: Decodable { let status: String; let token: String?; let sessionID: String?; let accountID: String?; let access: String? }
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(max(3, min(10, link.interval))))
                    let result: Approval = try await call(base: base, path: "api/device-links/\(link.code)/poll", body: Poll(deviceToken: link.deviceToken))
                    try Task.checkCancellation()
                    if result.status == "approved", let token = result.token {
                        let saved = CloudCredential(serviceURL: base.absoluteString, token: token, sessionID: result.sessionID ?? "", access: result.access, accountID: result.accountID)
                        #if !SCOREBOARD_TESTING
                        try CloudKeychain.save(JSONEncoder().encode(saved))
                        #endif
                        credential = saved
                        selectedSessionID = saved.sessionID
                        isLinked = true
                        linkCode = nil
                        verificationURL = nil
                        reconnect()
                        return
                    }
                }
            } catch is CancellationError { }
            catch {
                guard linkRunID == runID, !Task.isCancelled else { return }
                status = error.localizedDescription; linkCode = nil; verificationURL = nil
            }
        }
    }

    func reconnect() {
        guard cloudEnabled else { status = "Cloud is disabled."; return }
        let publishing = publisherGrant.flatMap { grant -> CloudCredential? in
            guard publisherActive, canHostProvider?() == true, grant.matchID == matchContext?.matchID,
                  grant.runtimeID == matchContext?.runtimeID, grant.epoch == matchContext?.epoch else { return nil }
            return CloudCredential(serviceURL: grant.serviceURL, token: grant.token, sessionID: grant.sessionID,
                access: "publisher", accountID: nil, hostLocalID: grant.hostLocalID)
        }
        guard let credential = publishing ?? credential else {
            if !isLinking { status = "Ready to sign in or join using a cloud code." }
            return
        }
        connectionTask?.cancel()
        heartbeatTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil; isConnected = false; receiver.endCloudConnection()
        let runID = UUID()
        connectionID = runID
        let pendingPause = homePauseTask
        if canHostProvider?() == true { homePausedMatchID = nil }
        connectionTask = Task { [weak self] in
            guard let self else { return }
            await pendingPause?.value
            var attempts = 0
            while !Task.isCancelled && connectionID == runID {
                do {
                    let base = try ScoreboardCloudEndpoint.validate(credential.serviceURL)
                    struct Identity: Decodable { let deviceID: String; let account: ScoreboardCloudAccount }
                    let identity: Identity = try await get(base: base, path: "api/me", token: credential.token)
                    guard !Task.isCancelled, connectionID == runID else { return }
                    deviceID = identity.deviceID
                    if publishing != nil, let owner = self.credential, owner.access == "owner" {
                        let ownerIdentity: Identity = try await get(base: ScoreboardCloudEndpoint.validate(owner.serviceURL), path: "api/me", token: owner.token)
                        guard !Task.isCancelled, connectionID == runID else { return }
                        account = ownerIdentity.account
                    } else { account = identity.account }
                    await refreshSessions()
                    guard !Task.isCancelled, connectionID == runID else { return }
                    let room: ScoreboardCloudSession
                    if credential.access == "publisher" {
                        room = try await get(base: base, path: "api/sessions/\(credential.sessionID)", token: credential.token)
                    } else if credential.access != nil {
                        if remoteActive || isRemoteRegistration {
                            guard remoteActive && remoteAllowsCloud else { status = "Cloud pairing is ready."; return }
                            if sessions.contains(where: { $0.id == self.selectedSessionID && $0.hostDeviceID == identity.deviceID }) {
                                selectedSessionID = ""; session = nil
                            }
                            guard !selectedSessionID.isEmpty else { status = "Choose a host session."; return }
                            struct Join: Encodable { var requestControl: Bool; var canControl: Bool }
                            let supportsControl = ScoreboardRemoteDisplayDeviceType.current.supportsControl
                            room = try await call(base: base, path: "api/sessions/\(selectedSessionID)/join", body: Join(requestControl: supportsControl && (credential.requestControl ?? true), canControl: supportsControl), token: credential.token)
                        } else {
                            guard hostingEnabled else { status = "Signed in. Open Connect Devices on your scoreboard and choose Share This Scoreboard Online."; return }
                            guard canHostProvider?() == true else { status = "This device is not the game host. Return to your local scoreboard or reconnect to the current host."; return }
                            guard account?.relay?.isValid() == true else { status = onlineSharingGuidance; return }
                            guard let context = matchContext else { return }
                            let record = ScoreboardMatchIndex.record(for: context.matchID)
                            guard record.serviceURL == nil || record.serviceURL == credential.serviceURL else {
                                status = "This match uses another cloud server. Connect that account in Cloud settings."; return
                            }
                            struct Host: Encodable { var name: String; var localID: String; var matchID: UUID; var runtimeID: UUID; var epoch: UInt64 }
                            room = try await call(base: base, path: "api/matches", body: Host(name: context.name,
                                localID: localHostIDProvider?() ?? receiver.displayID, matchID: context.matchID,
                                runtimeID: context.runtimeID, epoch: context.epoch), token: credential.token)
                            guard !Task.isCancelled, connectionID == runID else { return }
                            selectedSessionID = room.id
                            var saved = credential; saved.sessionID = room.id; saved.hostLocalID = room.hostLocalID
                            try saveCredential(saved)
                            var updatedRecord = ScoreboardMatchIndex.record(for: context.matchID)
                            updatedRecord.cloudSessionID = room.id; updatedRecord.serviceURL = credential.serviceURL
                            ScoreboardMatchIndex.save(updatedRecord)
                            await refreshSessions()
                        }
                    } else {
                        room = try await get(base: base, path: "api/sessions/\(credential.sessionID)", token: credential.token)
                    }
                    guard !Task.isCancelled, connectionID == runID else { return }
                    if publishing == nil, credential.access != nil, remoteActive || isRemoteRegistration {
                        var saved = credential; saved.sessionID = room.id; saved.hostLocalID = room.hostLocalID
                        saved.remoteSessionID = room.id; saved.remoteHostLocalID = room.hostLocalID
                        try saveCredential(saved)
                    }
                    if room.hostDeviceID == identity.deviceID, canHostProvider?() != true {
                        status = "The game host has changed locally. End this cloud session and link the current host."
                        return
                    }
                    session = room
                    isLinked = true
                    status = "Connecting to \(room.name)…"
                    var components = URLComponents(url: base.appendingPathComponent("api/sessions/\(room.id)/socket"), resolvingAgainstBaseURL: false)!
                    components.scheme = base.scheme == "https" ? "wss" : "ws"
                    var request = URLRequest(url: components.url!)
                    request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
                    try ScoreboardDeviceIdentity.sign(&request)
                    let task = URLSession.shared.webSocketTask(with: request)
                    task.maximumMessageSize = 1_048_576
                    socket = task
                    transportCredential = credential
                    receiver.beginCloudConnection { [weak self] command in self?.sendCommand(command) }
                    task.resume()
                    startHeartbeat(task, runID: runID)
                    while !Task.isCancelled, connectionID == runID {
                        let packet = try await task.receive()
                        guard connectionID == runID, !Task.isCancelled else { return }
                        let data: Data
                        switch packet { case .data(let bytes): data = bytes; case .string(let string): data = Data(string.utf8); @unknown default: continue }
                        guard data.count <= 1_048_576 else { throw URLError(.dataLengthExceedsMaximum) }
                        try handle(data)
                        attempts = 0
                    }
                } catch is CancellationError { return }
                catch {
                    guard connectionID == runID, !Task.isCancelled else { return }
                    isConnected = false
                    heartbeatTask?.cancel()
                    receiver.cloudDisconnected("Cloud connection lost. Waiting to reconnect.")
                    status = "Cloud disconnected: \(error.localizedDescription)"
                    let closeCode = socket?.closeCode.rawValue
                    socket?.cancel(with: .goingAway, reason: nil)
                    if closeCode == 4000 || closeCode == 4001 || (closeCode == 4003 && credential.access == nil) || closeCode == 4004 { return }
                    let failure = error as NSError
                    if failure.domain == "ScoreboardCloud", [401, 403, 404, 410].contains(failure.code) { return }
                    attempts += 1
                    do { try await Task.sleep(for: .seconds(min(15, 1 << min(attempts, 4)))) }
                    catch { return }
                }
            }
        }
    }

    private func saveCredential(_ value: CloudCredential) throws {
        #if !SCOREBOARD_TESTING
        try CloudKeychain.save(JSONEncoder().encode(value))
        #endif
        credential = value
    }

    func cancelLink() {
        linkRunID = UUID(); linkTask?.cancel(); isLinking = false; linkCode = nil; verificationURL = nil
    }

    func pauseHostingForHome() {
        suspendTransport()
        guard cloudEnabled, hostingEnabled, let context = matchContext,
              homePausedMatchID != context.matchID, let credential, hasOwnerAccount,
              let id = session?.id ?? ScoreboardMatchIndex.record(for: context.matchID).cloudSessionID else { return }
        homePausedMatchID = context.matchID
        let previous = homePauseTask
        homePauseTask = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            do {
                struct Publishing: Encodable { var enabled = false }
                let room: ScoreboardCloudSession = try await call(base: ScoreboardCloudEndpoint.validate(credential.serviceURL),
                    path: "api/sessions/\(id)/publishing", body: Publishing(), token: credential.token, timeout: 5)
                if session?.id == id && canHostProvider?() != true { session = room; status = "Online sharing is paused while Home is open." }
            } catch {
                if cloudEnabled && canHostProvider?() != true { status = "Local connections are closed. Could not pause cloud sharing: \(error.localizedDescription)" }
            }
        }
    }

    func joinInvitation(code: String, password: String, server: String, requestControl: Bool, beforeConnect: (() throws -> Void)? = nil) async throws {
        guard cloudEnabled else { throw URLError(.notConnectedToInternet) }
        let base = try ScoreboardCloudEndpoint.validate(server)
        let canControl = ScoreboardRemoteDisplayDeviceType.current.supportsControl
        let requestControl = requestControl && canControl
        struct Join: Encodable { var code: String; var password: String; var name: String; var deviceID: String; var devicePublicKey: String; var requestControl: Bool; var canControl: Bool; var client = "native" }
        struct Joined: Decodable { var token: String; var sessionID: String; var deviceID: String; var session: ScoreboardCloudSession }
        let result: Joined = try await call(base: base, path: "api/invitations/join", body: Join(code: code, password: password,
            name: ScoreboardRemoteDisplayDeviceName.current ?? "Scoreboard", deviceID: ScoreboardRemoteDisplayReceiver.shared.displayID,
            devicePublicKey: ScoreboardDeviceIdentity.publicKey, requestControl: requestControl, canControl: canControl), timeout: 8)
        try Task.checkCancellation()
        try beforeConnect?()
        ScoreboardRemoteConnectionRouter.shared.setJoinTarget(result.session.matchID)
        if let existing = credential, existing.access != "participant" {
            parkedOwnerCredential = existing
            #if !SCOREBOARD_TESTING
            try CloudKeychain.save(JSONEncoder().encode(existing), account: "owner")
            #endif
        }
        suspendTransport()
        let saved = CloudCredential(serviceURL: server, token: result.token, sessionID: result.sessionID, access: "participant",
            accountID: nil, hostLocalID: result.session.hostLocalID, remoteSessionID: result.sessionID,
            remoteHostLocalID: result.session.hostLocalID, requestControl: requestControl)
        try saveCredential(saved); selectService(for: server)
        deviceID = result.deviceID; isLinked = true; selectedSessionID = result.sessionID
        ScoreboardRecentMatches.shared.record(title: result.session.name, matchID: result.session.matchID,
            server: base.absoluteString, code: code)
        remoteActive = true; remoteAllowsCloud = true
        reconnect()
    }

    private var invitationFailoverTask: Task<Void, Never>?
    func prepareInvitationFailover(code: String, password: String, server: String, matchID: UUID, requestControl: Bool) {
        guard cloudEnabled, ScoreboardCloudEndpoint.sameService(server, serviceURL) else { return }
        invitationFailoverTask?.cancel()
        invitationFailoverTask = Task { [weak self] in
            guard let self else { return }
            defer { invitationFailoverTask = nil }
            try? await joinInvitation(code: code, password: password, server: server, requestControl: requestControl,
                beforeConnect: {
                    guard ScoreboardStore.shared.isJoinedMatchActive,
                          ScoreboardRemoteConnectionRouter.shared.joinTarget == matchID else { throw CancellationError() }
                })
        }
    }
    func leaveGuestMatch() {
        invitationFailoverTask?.cancel(); invitationFailoverTask = nil
        guard credential?.access == "participant" else { return }
        suspendTransport(); session = nil; remoteActive = false
        #if !SCOREBOARD_TESTING
        if parkedOwnerCredential == nil, let data = CloudKeychain.load(account: "owner") {
            parkedOwnerCredential = try? JSONDecoder().decode(CloudCredential.self, from: data)
        }
        #endif
        if let owner = parkedOwnerCredential { try? saveCredential(owner); selectService(for: owner.serviceURL); isLinked = true }
        else {
            credential = nil; isLinked = false
            #if !SCOREBOARD_TESTING
            try? CloudKeychain.save(nil)
            #endif
        }
        #if !SCOREBOARD_TESTING
        try? CloudKeychain.save(nil, account: "owner")
        #endif
        parkedOwnerCredential = nil; selectedSessionID = ""; account = nil
    }

    struct ParticipantInvitation: Decodable { var code: String; var url: String; var enabled: Bool }
    func revokeParticipant(memberID: String) async -> Bool {
        guard let credential, let session, canManageMatch else { return false }
        do {
            struct Input: Encodable { var deviceID: String }
            struct Result: Decodable { var success: Bool }
            let _: Result = try await call(base: ScoreboardCloudEndpoint.validate(credential.serviceURL),
                path: "api/sessions/\(session.id)/participants/revoke", body: Input(deviceID: memberID), token: credential.token)
            return true
        } catch { status = error.localizedDescription; return false }
    }
    func makeInvitation(password: String, enabled: Bool = true) async throws -> ParticipantInvitation {
        guard let credential, let session, canManageMatch else { throw URLError(.userAuthenticationRequired) }
        struct Input: Encodable { var enabled: Bool; var password: String }
        let result: ParticipantInvitation = try await call(base: ScoreboardCloudEndpoint.validate(credential.serviceURL), path: "api/sessions/\(session.id)/invitations",
            body: Input(enabled: enabled, password: password), token: credential.token)
        syncNearbyInvitation(force: true)
        return result
    }

    struct ViewerSharing: Decodable { var enabled: Bool; var token: String? }
    func webViewingLink(enabled: Bool, rotate: Bool = false) async throws -> URL? {
        guard let credential, let session, canManageMatch else { throw URLError(.userAuthenticationRequired) }
        struct Input: Encodable { var enabled: Bool; var rotate: Bool }
        let base = try ScoreboardCloudEndpoint.validate(credential.serviceURL)
        let result: ViewerSharing = try await call(base: base, path: "api/sessions/\(session.id)/sharing", body: Input(enabled: enabled, rotate: rotate), token: credential.token)
        guard let token = result.token else { return nil }
        return ScoreboardCloudEndpoint.publicViewingURL(base: base, sessionID: session.id, token: token)
    }

    func setRemoteActive(_ active: Bool, allowsCloud: Bool = true) {
        let changed = remoteActive != active || remoteAllowsCloud != allowsCloud
        if active && !remoteActive, var saved = credential, saved.access == "owner" {
            suspendTransport(); session = nil
            saved.sessionID = saved.remoteSessionID ?? ""; saved.hostLocalID = saved.remoteHostLocalID
            selectedSessionID = saved.sessionID
            do { try saveCredential(saved) } catch { status = error.localizedDescription }
        }
        remoteActive = active
        remoteAllowsCloud = allowsCloud
        if active && !allowsCloud { suspendTransport(); return }
        if changed || (active && socket == nil) { reconnect() }
    }

    private func suspendTransport() {
        connectionID = UUID(); connectionTask?.cancel(); heartbeatTask?.cancel(); publishTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil); socket = nil; isConnected = false
        receiver.endCloudConnection()
    }

    func suspendConnections() {
        cancelLink()
        suspendTransport()
        requestSession.invalidateAndCancel()
        requestSession = URLSession(configuration: .ephemeral)
        remotePermissionTasks.values.forEach { $0.cancel() }
        remotePermissionTasks.removeAll()
        status = "Cloud is disabled."
    }

    private func updateHosting() {
        guard cloudEnabled, let credential else { return }
        if canManageMatch, let room = session {
            let enabled = hostingEnabled
            Task { @MainActor in
                do {
                    struct Publishing: Encodable { var enabled: Bool }
                    let updated: ScoreboardCloudSession = try await call(base: ScoreboardCloudEndpoint.validate(credential.serviceURL),
                        path: "api/sessions/\(room.id)/publishing", body: Publishing(enabled: enabled), token: credential.token)
                    guard session?.id == room.id, hostingEnabled == enabled else { return }
                    session = updated
                    if !enabled && isHost { suspendTransport(); status = "Online sharing is off for this match." }
                    else if enabled { reconnect() }
                } catch { status = "Could not update online sharing: \(error.localizedDescription)" }
            }
        } else if !remoteActive { reconnect() }
    }

    func refreshAccountAccess() async {
        guard cloudEnabled, let credential, hasOwnerAccount else { return }
        do {
            struct Identity: Decodable { var account: ScoreboardCloudAccount }
            let value: Identity = try await get(base: ScoreboardCloudEndpoint.validate(credential.serviceURL), path: "api/me", token: credential.token)
            guard self.credential?.token == credential.token else { return }
            account = value.account
            if hostingEnabled && value.account.relay?.isValid() == true { reconnect() }
            else { status = onlineSharingGuidance }
        } catch { status = error.localizedDescription }
    }

    func refreshSessions() async {
        guard cloudEnabled, let credential else { return }
        do {
            struct Listing: Decodable { var sessions: [ScoreboardCloudSessionChoice] }
            let value: Listing = try await get(base: ScoreboardCloudEndpoint.validate(credential.serviceURL), path: "api/sessions", token: credential.token)
            guard self.credential?.token == credential.token else { return }
            sessions = value.sessions
        } catch { status = error.localizedDescription }
    }

    func refreshDevices() async {
        guard cloudEnabled, let credential, hasOwnerAccount else { return }
        do {
            struct Listing: Decodable { var devices: [ScoreboardCloudRegisteredDevice] }
            let result: Listing = try await get(base: ScoreboardCloudEndpoint.validate(credential.serviceURL), path: "api/devices", token: credential.token)
            if self.credential?.token == credential.token { registeredDevices = result.devices.filter { $0.revoked == 0 } }
        } catch { status = error.localizedDescription }
    }

    func revokeDevice(_ device: ScoreboardCloudRegisteredDevice) async {
        guard let credential, !isRemoteRegistration else { return }
        do {
            struct Revoke: Encodable { var key: String }
            struct Result: Decodable { var success: Bool }
            let _: Result = try await call(base: ScoreboardCloudEndpoint.validate(credential.serviceURL), path: "api/devices/revoke",
                body: Revoke(key: device.key), token: credential.token)
            if device.id == deviceID { disconnect() } else { await refreshDevices() }
        } catch { status = error.localizedDescription }
    }

    @discardableResult func setCloudPermission(memberID: String, allowed: Bool) async -> Bool {
        guard canManageMatch, let credential, let session else { return false }
        do {
            struct Permission: Encodable { var deviceID: String; var allowed: Bool }
            let room: ScoreboardCloudSession = try await call(base: ScoreboardCloudEndpoint.validate(credential.serviceURL),
                path: "api/sessions/\(session.id)/permissions", body: Permission(deviceID: memberID, allowed: allowed), token: credential.token)
            if self.session?.id == room.id { self.session = room }
            return true
        } catch { status = error.localizedDescription; return false }
    }

    func selectSession(_ id: String) {
        guard var saved = credential, sessions.contains(where: { $0.id == id }) else { return }
        suspendTransport()
        selectedSessionID = id; saved.sessionID = id; saved.hostLocalID = nil
        saved.remoteSessionID = id; saved.remoteHostLocalID = nil
        session = nil
        do { try saveCredential(saved); reconnect() } catch { status = error.localizedDescription }
    }

    func didPairLocalHost(_ id: String) {
        guard var saved = credential, saved.hostLocalID != id else { return }
        // Entering a new nearby pairing code is an explicit target change.
        // Clear the old cloud target even when the new host has no internet.
        suspendTransport(); session = nil; selectedSessionID = ""
        saved.sessionID = ""; saved.hostLocalID = id
        saved.remoteSessionID = ""; saved.remoteHostLocalID = id
        do { try saveCredential(saved) } catch { status = error.localizedDescription }
    }

    func approveRemote(code: String) async throws {
        guard let credential, !isRemoteRegistration else { throw URLError(.userAuthenticationRequired) }
        let normalized = code.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        guard normalized.count == 10, normalized.allSatisfy({ "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains($0) }) else { throw URLError(.badURL) }
        struct Empty: Encodable {}
        struct Approved: Decodable { var success: Bool }
        let _: Approved = try await call(base: ScoreboardCloudEndpoint.validate(credential.serviceURL),
            path: "api/device-links/\(normalized)/approve", body: Empty(), token: credential.token)
        status = "Remote device registered. Choose its host session on that device."
    }

    func provisionRemote(id: String, name: String, publicKey: String, controlAllowed: Bool, canControl: Bool = true) async throws -> Data {
        guard cloudFailoverEnabled, canManageMatch, let credential, let session else { throw URLError(.userAuthenticationRequired) }
        struct Enrollment: Encodable { var deviceID: String; var name: String; var devicePublicKey: String; var controlAllowed: Bool; var canControl: Bool }
        struct Grant: Decodable { var token: String; var deviceID: String; var sessionID: String; var hostLocalID: String }
        let grant: Grant = try await call(base: ScoreboardCloudEndpoint.validate(credential.serviceURL), path: "api/sessions/\(session.id)/participants/provision",
            body: Enrollment(deviceID: id, name: name, devicePublicKey: publicKey, controlAllowed: controlAllowed && canControl, canControl: canControl), token: credential.token)
        guestDeviceIDs[id] = grant.deviceID
        return try JSONEncoder().encode(ScoreboardCloudEnrollment(serviceURL: credential.serviceURL, token: grant.token,
            sessionID: grant.sessionID, accountID: session.ownerID, hostLocalID: grant.hostLocalID, remoteDeviceID: id,
            access: "participant", devicePublicKey: publicKey))
    }

    func updateRemotePermission(localID: String, publicKey: String? = nil, allowed: Bool, force: Bool = false) {
        guard canManageMatch, let credential, let account, let session else { return }
        var ids = session.members.filter { member in
            member.localDeviceID == localID && (!allowed || (publicKey != nil && publicKey == member.devicePublicKey))
        }.map(\.id)
        if let id = guestDeviceIDs[localID] { ids.append(id) }
        let legacy = "native:\(account.id):\(localID)"
        if session.members.contains(where: { $0.id == legacy }) { ids.append(legacy) }
        for id in Set(ids) {
            pendingRemotePermissions[id] = allowed
            flushRemotePermission(id, sessionID: session.id, token: credential.token)
        }
    }

    private func flushRemotePermission(_ id: String, sessionID: String, token: String) {
        guard remotePermissionTasks[id] == nil else { return }
        remotePermissionTasks[id] = Task { [weak self] in
            guard let self else { return }
            defer { remotePermissionTasks[id] = nil }
            while !Task.isCancelled, self.credential?.token == token, self.session?.id == sessionID,
                  let allowed = pendingRemotePermissions.removeValue(forKey: id) {
                if !(await setCloudPermission(memberID: id, allowed: allowed)) {
                    if pendingRemotePermissions[id] == nil { pendingRemotePermissions[id] = allowed }
                    return
                }
            }
        }
    }

    @discardableResult func acceptEnrollment(_ data: Data, authenticatedHostID: String, localDeviceID: String) -> Bool {
        guard let grant = try? JSONDecoder().decode(ScoreboardCloudEnrollment.self, from: data),
              grant.kind == "scoreboard.cloud.enrollment.v1" else { return false }
        guard grant.remoteDeviceID == localDeviceID, grant.hostLocalID == authenticatedHostID,
              (try? ScoreboardCloudEndpoint.validate(grant.serviceURL)) != nil else { return true }
        if grant.access == "participant" {
            guard grant.devicePublicKey == ScoreboardDeviceIdentity.publicKey, !acceptedEnrollments.contains(grant.enrollmentID) else { return true }
            do {
                if let existing = credential, existing.access == "owner" {
                    parkedOwnerCredential = existing
                    #if !SCOREBOARD_TESTING
                    try CloudKeychain.save(JSONEncoder().encode(existing), account: "owner")
                    #endif
                }
                try saveCredential(CloudCredential(serviceURL: grant.serviceURL, token: grant.token, sessionID: grant.sessionID,
                    access: "participant", accountID: nil, hostLocalID: grant.hostLocalID))
                acceptedEnrollments.insert(grant.enrollmentID)
                selectService(for: grant.serviceURL); selectedSessionID = grant.sessionID; isLinked = true
                if cloudEnabled && remoteActive && remoteAllowsCloud { reconnect() }
            } catch { status = error.localizedDescription }
            return true
        }
        if credential?.access == "owner" { status = "This device is already signed in as an owner. Choose its remote host from the session picker."; return true }
        // An existing registration cannot silently move to another account or service.
        if let credential, credential.accountID != grant.accountID || credential.serviceURL != grant.serviceURL {
            status = "Cloud pairing belongs to a different account or service. Sign out here before pairing again."; return true
        }
        guard !acceptedEnrollments.contains(grant.enrollmentID) else { return true }
        do {
            try saveCredential(CloudCredential(serviceURL: grant.serviceURL, token: grant.token, sessionID: grant.sessionID,
                access: "remote", accountID: grant.accountID, hostLocalID: grant.hostLocalID))
            acceptedEnrollments.insert(grant.enrollmentID)
            selectService(for: grant.serviceURL); selectedSessionID = grant.sessionID; isLinked = true; cancelLink()
            if remoteActive && remoteAllowsCloud { reconnect() }
            else { status = "Cloud failover is ready. Choose a cloud preference to use it." }
        } catch { status = error.localizedDescription }
        return true
    }

    @discardableResult func acceptEncryptedEnrollment(_ data: Data, pairingSecret: String, authenticatedHostID: String, localDeviceID: String) -> Bool {
        guard ScoreboardCloudEnrollmentCrypto.isEnvelope(data) else { return false }
        if let plaintext = try? ScoreboardCloudEnrollmentCrypto.open(data, pairingSecret: pairingSecret, hostID: authenticatedHostID, deviceID: localDeviceID) {
            if acceptPublisherGrant(plaintext, authenticatedHostID: authenticatedHostID, localDeviceID: localDeviceID) { return true }
            acceptEnrollment(plaintext, authenticatedHostID: authenticatedHostID, localDeviceID: localDeviceID)
        }
        return true
    }

    func disconnect() {
        connectionID = UUID()
        linkRunID = UUID()
        linkTask?.cancel(); connectionTask?.cancel(); heartbeatTask?.cancel(); publishTask?.cancel()
        invitationFailoverTask?.cancel(); invitationFailoverTask = nil
        nearbyInvitationTask?.cancel(); nearbyInvitationTask = nil
        remotePermissionTasks.values.forEach { $0.cancel() }; remotePermissionTasks.removeAll(); pendingRemotePermissions.removeAll()
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        nearbyInvitationCache.removeAll(); loadedNearbyInvitationCache = true
        #if !SCOREBOARD_TESTING
        try? CloudKeychain.save(nil, account: "nearby-invitations")
        #endif
        nearbyInvitationChangedHandler?()
        credential = nil
        parkedOwnerCredential = nil; publisherGrant = nil; publisherActive = false; preparedPublisherGrant = nil
        account = nil; sessions = []; registeredDevices = []; selectedSessionID = ""
        session = nil
        deviceID = nil
        isLinked = false
        isLinking = false
        isConnected = false
        linkCode = nil
        verificationURL = nil
        pendingState = nil
        receiver.endCloudConnection()
        #if !SCOREBOARD_TESTING
        do { try CloudKeychain.save(nil); try CloudKeychain.save(nil, account: "owner"); try CloudKeychain.save(nil, account: "publisher") }
        catch { status = "Disconnected. The saved cloud credential could not be removed from Keychain."; return }
        #endif
        status = "Cloud connection is off. Local play continues."
    }

    // Coalesce app changes to at most 5 snapshots/second. A periodic snapshot
    // keeps stopped games alive without sending commands or running game logic.
    func publish(_ state: ScoreboardWebAPIState) {
        guard isHost, isConnected, session?.enabled != false else { return }
        synchronizeImages(state)
        pendingState = state
        guard publishTask == nil else { return }
        publishTask = Task { [weak self] in
            guard let self else { return }
            let delay = max(0, 0.2 - Date().timeIntervalSince(lastPublishAt))
            do { try await Task.sleep(for: .seconds(delay)) } catch { publishTask = nil; return }
            defer { publishTask = nil }
            guard let state = pendingState, isHost, session?.enabled != false, let generation = session?.generation else { return }
            pendingState = nil
            lastPublishAt = Date()
            send(Frame(type: "state", generation: generation, state: state))
        }
    }

    private func publishCommentator() {
        guard isHost, isConnected, session?.enabled != false, let generation = session?.generation,
              let payload = commentatorProvider?() else { return }
        send(Frame(type: "commentator", generation: generation, commentator: payload.limited(to: 120)))
    }

    private func startHeartbeat(_ task: URLSessionWebSocketTask, runID: UUID) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self, weak task] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self, let task, connectionID == runID else { return }
                reportConnectionStatus()
                if isHost {
                    syncNearbyInvitation()
                    guard let state = stateProvider?() else {
                        task.cancel(with: .goingAway, reason: nil)
                        status = "The local game host changed. Re-link the current host to a new cloud session."
                        return
                    }
                    publish(state)
                    publishCommentator()
                } else if lastStateAt.map({ Date().timeIntervalSince($0) > 15 }) ?? true {
                    receiver.cloudDisconnected("Waiting for the game host. Local play continues on that device.")
                }
                do {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        task.sendPing { error in
                            if let error { continuation.resume(throwing: error) }
                            else { continuation.resume() }
                        }
                    }
                } catch { task.cancel(with: .goingAway, reason: nil); return }
            }
        }
    }

    private func handle(_ data: Data) throws {
        let frame = try JSONDecoder().decode(Incoming.self, from: data)
        if frame.type == "session", let room = frame.session {
            let newlyConnected = !isConnected
            session = room
            syncNearbyInvitation(force: newlyConnected)
            isConnected = true
            reportConnectionStatus(force: newlyConnected)
            status = room.enabled == false ? "Online sharing is paused for this match." : (isHost ? "Hosting \(room.name) through the cloud." : "Connected to \(room.name).")
            if let context = matchContext { commitMatchingPublisher(context) }
            if !isHost {
                receiver.setCloudControlAllowed(canControl && room.hostOnline)
                if !room.hostOnline { receiver.cloudDisconnected("Waiting for the game host to reconnect.") }
            } else if let state = stateProvider?() {
                publish(state); publishCommentator()
                if newlyConnected {
                    if let credential {
                        for id in pendingRemotePermissions.keys { flushRemotePermission(id, sessionID: room.id, token: credential.token) }
                    }
                    hostReadyHandler?()
                }
            }
        } else if frame.type == "client-connection", let memberID = frame.memberID,
                  let connectionStatus = frame.connectionStatus,
                  let index = session?.members.firstIndex(where: { $0.id == memberID }) {
            session?.members[index].connectionStatus = connectionStatus
        } else if frame.type == "state", let state = frame.state, !isHost {
            lastStateAt = Date()
            receiver.receiveCloudState(state, controlAllowed: canControl, hostName: session?.name ?? "Cloud host")
            synchronizeImages(state)
        } else if frame.type == "command", isHost, frame.generation == session?.generation,
                  let command = frame.command, let clientID = frame.clientID, let requestID = frame.requestID {
            let result = canHostProvider?() == true ? commandHandler?(command) ?? .failure(command.id, "disabled", "Host unavailable.")
                : .failure(command.id, "conflict", "This device is no longer the game host.")
            send(Frame(type: "result", generation: session?.generation, clientID: clientID, requestID: requestID, result: result))
            if let state = stateProvider?() { publish(state) }
        } else if frame.type == "result", let result = frame.result { receiver.receiveCloudResult(result) }
        else if frame.type == "error" { status = frame.message ?? "Cloud request failed." }
    }

    private func reportConnectionStatus(force: Bool = false) {
        guard isConnected, session?.supportsConnectionDiagnostics == true, let status = connectionStatusProvider?(),
              force || status != lastReportedConnectionStatus else { return }
        lastReportedConnectionStatus = status
        send(Frame(type: "client-connection", connectionStatus: status))
    }

    private func synchronizeImages(_ state: ScoreboardWebAPIState) {
        guard imageSyncTask == nil, isConnected, let credential = transportCredential, let room = session,
              Date().timeIntervalSince(lastImageSyncAt) >= 5 else { return }
        let host = isHost, runID = connectionID
        let images = state.cloudImageReferences.filter { image in
            host ? uploadedImages[image.slot] != "\(room.id)|\(room.generation)|\(image.id)" : receiver.imageData(for: image.id) == nil
        }
        guard !images.isEmpty else { return }
        lastImageSyncAt = Date()
        let responses = host ? imageProvider?() ?? [:] : [:]
        imageSyncTask = Task { [weak self] in
            guard let self else { return }
            defer { if connectionID == runID { imageSyncTask = nil } }
            do {
                let base = try ScoreboardCloudEndpoint.validate(credential.serviceURL)
                for image in images {
                    try Task.checkCancellation()
                    guard connectionID == runID else { return }
                    var components = URLComponents(url: base.appendingPathComponent("api/sessions/\(room.id)/assets/\(image.slot)"), resolvingAgainstBaseURL: false)!
                    components.queryItems = [.init(name: "asset", value: image.id)]
                    var request = URLRequest(url: components.url!)
                    request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
                    if host {
                        guard let response = responses[image.path] else { continue }
                        guard response.body.count <= 8 * 1024 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
                        request.httpMethod = "POST"; request.httpBody = response.body
                        request.setValue(response.contentType, forHTTPHeaderField: "Content-Type")
                    }
                    try ScoreboardDeviceIdentity.sign(&request)
                    let (data, response) = try await requestSession.data(for: request)
                    guard connectionID == runID, !Task.isCancelled else { return }
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count <= 8 * 1024 * 1024 else { throw URLError(.badServerResponse) }
                    if host { uploadedImages[image.slot] = "\(room.id)|\(room.generation)|\(image.id)" }
                    else {
                        receiver.receiveCloudImage(.init(id: image.id, path: image.path,
                            mimeType: http.mimeType ?? "image/png", data: data))
                    }
                }
                imageSyncError = nil
            } catch {
                if !Task.isCancelled, connectionID == runID { imageSyncError = "Some cloud images could not be synchronized. Retrying…" }
            }
        }
    }

    private func sendCommand(_ input: ScoreboardControlCommand) {
        guard canControl, isConnected, session?.hostOnline == true,
              lastStateAt.map({ Date().timeIntervalSince($0) < 15 }) == true else {
            receiver.receiveCloudResult(.failure(input.id, "disconnected", "The host is unavailable.")); return
        }
        // The host applies at arrival time. Cross-device wall clocks are not
        // trusted for delay compensation on this first cloud protocol.
        var command = input
        if command.matchID == nil { command.matchID = receiver.state?.game.matchID }
        command.sentAt = nil
        send(Frame(type: "command", command: command))
    }

    private func send(_ frame: Frame) {
        guard let socket, let data = try? JSONEncoder().encode(frame), data.count <= 1_048_576,
              let string = String(data: data, encoding: .utf8) else {
            status = "Cloud message is too large or could not be encoded."; return
        }
        Task { [weak self] in
            do { try await socket.send(.string(string)) }
            catch { self?.status = "Cloud send failed: \(error.localizedDescription)"; socket.cancel(with: .goingAway, reason: nil) }
        }
    }

    private func get<Result: Decodable>(base: URL, path: String, token: String) async throws -> Result {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await response(request)
    }
    private func call<Input: Encodable, Result: Decodable>(base: URL, path: String, body: Input, token: String? = nil, timeout: TimeInterval = 60) async throws -> Result {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.timeoutInterval = timeout
        request.httpMethod = "POST"
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await response(request)
    }
    private func response<Result: Decodable>(_ request: URLRequest) async throws -> Result {
        guard cloudEnabled else { throw URLError(.cancelled) }
        var request = request
        try ScoreboardDeviceIdentity.sign(&request)
        let (data, response) = try await requestSession.data(for: request)
        guard cloudEnabled else { throw URLError(.cancelled) }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(Failure.self, from: data))?.message ?? "Cloud request failed."
            throw NSError(domain: "ScoreboardCloud", code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
        return try JSONDecoder().decode(Result.self, from: data)
    }

    nonisolated private struct LinkRequest: Encodable { var deviceID: String; var name: String; var canHost: Bool; var purpose: String }
    nonisolated private struct Failure: Decodable { var message: String }
    nonisolated private struct Incoming: Decodable {
        var type: String
        var session: ScoreboardCloudSession?
        var state: ScoreboardWebAPIState?
        var command: ScoreboardControlCommand?
        var clientID: String?
        var requestID: String?
        var generation: String?
        var result: ScoreboardControlResult?
        var message: String?
        var memberID: String?
        var connectionStatus: ScoreboardClientConnectionStatus?
    }
    nonisolated private struct Frame: Encodable {
        var type: String
        var generation: String? = nil
        var state: ScoreboardWebAPIState? = nil
        var command: ScoreboardControlCommand? = nil
        var clientID: String? = nil
        var requestID: String? = nil
        var result: ScoreboardControlResult? = nil
        var commentator: ScoreboardWebAPICommentatorPayload? = nil
        var connectionStatus: ScoreboardClientConnectionStatus? = nil
    }
}

extension ScoreboardWebAPIState {
    nonisolated func cloudControlPayload(allowed: Bool) -> ScoreboardWebAPIState {
        var state = self
        let c = control
        state.control = ScoreboardControlStatus(webEnabled: false, remoteEnabled: allowed,
            gameName: c?.gameName, isSoundEnabled: c?.isSoundEnabled, mainDisplayMode: c?.mainDisplayMode,
            customDisplayControlVisible: c?.customDisplayControlVisible, customDisplayEnabledIDs: c?.customDisplayEnabledIDs,
            customDisplayModes: c?.customDisplayModes, session: c?.session,
            connectedDeviceCount: c?.connectedDeviceCount, disconnectedDeviceCount: c?.disconnectedDeviceCount,
            ownerConnected: c?.ownerConnected, devices: c?.devices)
        return state
    }
}

nonisolated enum ScoreboardRemoteRoute: Equatable, Sendable {
    case local, cloud
    static func choose(mode: ScoreboardRemoteDisplayNetworkMode, localFresh: Bool, cloudFresh: Bool,
                       sameHost: Bool, current: Self, hasPendingCommand: Bool,
                       targetMatchID: UUID? = nil, localMatchID: UUID? = nil, cloudMatchID: UUID? = nil) -> Self {
        let localFresh = localFresh && (targetMatchID == nil || localMatchID == targetMatchID)
        let cloudFresh = cloudFresh && (targetMatchID == nil || cloudMatchID == targetMatchID)
        let sameHost = targetMatchID != nil && !cloudFresh ? true : sameHost
        guard mode.allowsCloud else { return .local }
        if hasPendingCommand { return current }
        if mode == .cloudOnly { return .cloud }
        if !sameHost { return .cloud }
        if mode == .preferCloud { return cloudFresh ? .cloud : .local }
        return localFresh && sameHost ? .local : cloudFresh ? .cloud : .local
    }
}

@MainActor final class ScoreboardRemoteConnectionRouter: ObservableObject {
    static let shared = ScoreboardRemoteConnectionRouter()
    @Published private(set) var route: ScoreboardRemoteRoute = .local
    private var consumers = 0
    private var timer: Timer?
    private var expectedMatchID: UUID?
    var joinTarget: UUID? { expectedMatchID }
    func setJoinTarget(_ matchID: UUID?) {
        expectedMatchID = matchID
        local.bindJoinedMatch(matchID); cloud.receiver.bindJoinedMatch(matchID)
        refresh()
    }
    private var mode: ScoreboardRemoteDisplayNetworkMode = .nearbyAndLocalNetwork
    private let local = ScoreboardRemoteDisplayReceiver.shared
    private let cloud = ScoreboardCloudClient.shared
    var receiver: ScoreboardRemoteDisplayReceiver { route == .cloud ? cloud.receiver : local }

    private init() {
        local.connectionStatusProvider = { [weak self] in self?.connectionStatus ?? .init(active: nil, available: []) }
        cloud.connectionStatusProvider = { [weak self] in self?.connectionStatus ?? .init(active: nil, available: []) }
    }

    var connectionStatus: ScoreboardClientConnectionStatus {
        let active: ScoreboardConnectionInfo?
        let hostID: String?
        if local.isHostingSession || cloud.isPublishingLocalHost {
            active = .local; hostID = cloud.session?.hostLocalID ?? local.displayID
        } else if consumers > 0 {
            active = receiver.connectionInfo
            hostID = route == .cloud ? cloud.selectedHostLocalID : local.connectedHostID
        } else if local.hasActiveConsumers {
            // A session owner can follow a delegated host without opening the
            // remote-display UI or acquiring this router.
            active = local.connectionInfo; hostID = local.connectedHostID
        } else {
            active = nil; hostID = nil
        }
        var available = local.availableConnections
        if cloud.isConnected { available.append(.cloud) }
        return .init(active: active?.normalized, available: available.map(\.normalized), activeHostID: hostID)
    }

    func acquire(mode: ScoreboardRemoteDisplayNetworkMode) {
        consumers += 1
        if consumers == 1 {
            local.acquire(networkMode: mode)
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
        }
        updateMode(mode)
    }
    func release() {
        consumers = max(0, consumers - 1)
        if consumers == 0 {
            timer?.invalidate(); timer = nil; local.release(); cloud.setRemoteActive(false); route = .local
        }
    }
    func updateMode(_ value: ScoreboardRemoteDisplayNetworkMode) {
        mode = value; local.updateNetworkMode(value)
        if consumers > 0 { cloud.setRemoteActive(!local.isHostingSession, allowsCloud: value.allowsCloud) }
        refresh()
    }
    func refresh() {
        if local.isHostingSession { if route != .local { route = .local }; return }
        let localFresh = local.status.isLive && local.lastReceivedAt.map { Date().timeIntervalSince($0) < 5 } == true
        let cloudFresh = cloud.receiver.status.isLive && cloud.receiver.lastReceivedAt.map { Date().timeIntervalSince($0) < 15 } == true
        let sameIdentity = cloud.session?.matchID == nil || cloud.session?.matchID == local.state?.game.matchID
        let sameHost = cloud.selectedSessionID.isEmpty || (sameIdentity && cloud.selectedHostLocalID != nil && cloud.selectedHostLocalID == local.connectedHostID)
        // Never fall back to a different game simply because it is nearby.
        let eligibleLocal = localFresh && (expectedMatchID != nil || !mode.allowsCloud || sameHost)
        let selected = ScoreboardRemoteRoute.choose(mode: mode, localFresh: eligibleLocal, cloudFresh: cloudFresh,
            sameHost: sameHost, current: route,
            hasPendingCommand: local.pendingControlCommandID != nil || cloud.receiver.pendingControlCommandID != nil,
            targetMatchID: expectedMatchID, localMatchID: local.state?.game.matchID, cloudMatchID: cloud.receiver.state?.game.matchID)
        if selected != route { route = selected }
    }
}

nonisolated enum ScoreboardPairingLink: Equatable, Sendable {
    case nearby(deviceID: String, code: String)
    case cloud(code: String, origin: String)
    static func nearbyURL(deviceID: String, code: String) -> String {
        var url = URLComponents(); url.scheme = "smartscoreboard"; url.host = "pair"
        url.queryItems = [.init(name: "device", value: deviceID), .init(name: "code", value: code)]
        return url.string ?? ""
    }
    static func parse(_ text: String) -> Self? {
        guard text.utf8.count <= 2048, let url = URLComponents(string: text),
              url.user == nil, url.password == nil else { return nil }
        let values = url.queryItems ?? []
        func value(_ name: String) -> String? {
            let matches = values.filter { $0.name == name }; return matches.count == 1 ? matches[0].value : nil
        }
        if url.scheme == "smartscoreboard", url.host == "pair", let device = value("device"),
           !device.isEmpty, device.utf8.count <= 100, let code = value("code"), code.count == 4, code.allSatisfy(\.isNumber) {
            return .nearby(deviceID: device, code: code)
        }
        if let code = value("link"), code.count == 10, code.allSatisfy({ "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains($0) }),
           var base = url.url {
            base.deleteLastPathComponent()
            var origin = URLComponents(url: base, resolvingAgainstBaseURL: false)
            origin?.path = ""; origin?.query = nil; origin?.fragment = nil
            if let address = origin?.string, (try? ScoreboardCloudEndpoint.validate(address)) != nil {
                return .cloud(code: code, origin: address)
            }
        }
        return nil
    }
}
