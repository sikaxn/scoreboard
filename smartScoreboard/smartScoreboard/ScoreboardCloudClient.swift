import Combine
import Foundation
import Security
import CryptoKit

nonisolated struct ScoreboardCloudMember: Codable, Identifiable, Sendable {
    var id: String
    var uid: String
    var name: String
    var role: String
    var requestedControl: Bool
}

nonisolated struct ScoreboardCloudSession: Codable, Sendable {
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
}

nonisolated enum ScoreboardCloudEndpoint {
    static let publicServiceURL = "https://scoreboardcloud.studenttechsupport.com"

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
}

nonisolated enum ScoreboardCloudServiceMode: String, CaseIterable, Identifiable, Sendable {
    case publicCloud
    case selfHosted

    var id: String { rawValue }
}

nonisolated struct ScoreboardCloudAccount: Codable, Sendable {
    var id: String; var name: String; var role: String
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
}

nonisolated private enum CloudKeychain {
    private static let service = "smartScoreboard.cloud-session"
    static func load() -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "current",
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
    static func save(_ data: Data?) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: "current"]
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
    @Published var serviceMode: ScoreboardCloudServiceMode {
        didSet { preferences.set(serviceMode.rawValue, forKey: "scoreboard.cloudServiceMode") }
    }
    @Published var selfHostedURL: String {
        didSet { preferences.set(selfHostedURL, forKey: "scoreboard.cloudSelfHostedURL") }
    }
    var serviceURL: String {
        serviceMode == .publicCloud ? ScoreboardCloudEndpoint.publicServiceURL : selfHostedURL
    }
    private let preferences: UserDefaults
    @Published var hostName: String = "" {
        didSet { preferences.set(hostName, forKey: "scoreboard.cloudHostName") }
    }
    @Published var hostingEnabled: Bool = false {
        didSet { preferences.set(hostingEnabled, forKey: "scoreboard.cloudHostingEnabled"); if hostingEnabled != oldValue { updateHosting() } }
    }
    @Published var cloudFailoverEnabled: Bool = false {
        didSet { preferences.set(cloudFailoverEnabled, forKey: "scoreboard.cloudFailoverEnabled"); if cloudFailoverEnabled { hostReadyHandler?() } }
    }
    @Published private(set) var account: ScoreboardCloudAccount?
    @Published private(set) var sessions: [ScoreboardCloudSessionChoice] = []
    @Published private(set) var registeredDevices: [ScoreboardCloudRegisteredDevice] = []
    @Published private(set) var selectedSessionID = ""
    @Published private(set) var isRemotePairing = false
    var isRemoteRegistration: Bool { credential?.access == "remote" }
    var hasAccountRegistration: Bool { credential?.access != nil }
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
    var canControl: Bool { session?.members.first { $0.id == deviceID }?.role == "controller" }
    private(set) var deviceID: String?
    private var credential: CloudCredential?
    private var socket: URLSessionWebSocketTask?
    private var connectionTask: Task<Void, Never>?
    private var linkTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var lastStateAt: Date?
    private var lastPublishAt = Date.distantPast
    private var pendingState: ScoreboardWebAPIState?
    private var publishTask: Task<Void, Never>?
    private var stateProvider: (() -> ScoreboardWebAPIState?)?
    private var commentatorProvider: (() -> ScoreboardWebAPICommentatorPayload?)?
    private var commandHandler: ((ScoreboardControlCommand) -> ScoreboardControlResult)?
    private var canHostProvider: (() -> Bool)?
    private var localHostIDProvider: (() -> String)?
    private var connectionID = UUID()
    private var linkRunID = UUID()
    private var pendingRemotePermissions: [String: Bool] = [:]
    private var remotePermissionTasks: [String: Task<Void, Never>] = [:]
    private var acceptedEnrollments = Set<UUID>()

    init(preferences: UserDefaults = ScoreboardPreferences.current) {
        self.preferences = preferences
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

    func resetServiceSettings() {
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
                   localHostID: (() -> String)? = nil) {
        self.stateProvider = stateProvider
        self.commandHandler = commandHandler
        self.canHostProvider = canHost
        self.commentatorProvider = commentatorProvider
        self.localHostIDProvider = localHostID
        #if !SCOREBOARD_TESTING
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
        guard let credential else { return }
        connectionTask?.cancel()
        heartbeatTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil; isConnected = false; receiver.endCloudConnection()
        let runID = UUID()
        connectionID = runID
        connectionTask = Task { [weak self] in
            guard let self else { return }
            var attempts = 0
            while !Task.isCancelled && connectionID == runID {
                do {
                    let base = try ScoreboardCloudEndpoint.validate(credential.serviceURL)
                    struct Identity: Decodable { let deviceID: String; let account: ScoreboardCloudAccount }
                    let identity: Identity = try await get(base: base, path: "api/me", token: credential.token)
                    guard !Task.isCancelled, connectionID == runID else { return }
                    deviceID = identity.deviceID
                    account = identity.account
                    await refreshSessions()
                    guard !Task.isCancelled, connectionID == runID else { return }
                    let room: ScoreboardCloudSession
                    if credential.access != nil {
                        if remoteActive || isRemoteRegistration {
                            guard remoteActive && remoteAllowsCloud else { status = "Cloud pairing is ready."; return }
                            if sessions.contains(where: { $0.id == selectedSessionID && $0.hostDeviceID == identity.deviceID }) {
                                selectedSessionID = ""; session = nil
                            }
                            guard !selectedSessionID.isEmpty else { status = "Choose a host session."; return }
                            struct Join: Encodable { var requestControl = true }
                            room = try await call(base: base, path: "api/sessions/\(selectedSessionID)/join", body: Join(), token: credential.token)
                        } else {
                            guard hostingEnabled, canHostProvider?() == true else { status = "Account connected. Cloud hosting is off."; return }
                            struct Host: Encodable { var name: String; var localID: String }
                            room = try await call(base: base, path: "api/host-session", body: Host(name: hostName, localID: localHostIDProvider?() ?? receiver.displayID), token: credential.token)
                            guard !Task.isCancelled, connectionID == runID else { return }
                            selectedSessionID = room.id
                            var saved = credential; saved.sessionID = room.id; saved.hostLocalID = room.hostLocalID
                            try saveCredential(saved)
                            await refreshSessions()
                        }
                    } else {
                        room = try await get(base: base, path: "api/sessions/\(credential.sessionID)", token: credential.token)
                    }
                    guard !Task.isCancelled, connectionID == runID else { return }
                    if credential.access != nil, remoteActive || isRemoteRegistration {
                        var saved = credential; saved.sessionID = room.id; saved.hostLocalID = room.hostLocalID
                        saved.remoteSessionID = room.id; saved.remoteHostLocalID = room.hostLocalID
                        try saveCredential(saved)
                    }
                    if room.hostDeviceID == identity.deviceID, canHostProvider?() != true {
                        status = "The game host has changed locally. End this cloud session and link the current host."
                        return
                    }
                    session = room
                    status = "Connecting to \(room.name)…"
                    var components = URLComponents(url: base.appendingPathComponent("api/sessions/\(room.id)/socket"), resolvingAgainstBaseURL: false)!
                    components.scheme = base.scheme == "https" ? "wss" : "ws"
                    var request = URLRequest(url: components.url!)
                    request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
                    let task = URLSession.shared.webSocketTask(with: request)
                    task.maximumMessageSize = 1_048_576
                    socket = task
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

    private func updateHosting() {
        guard !remoteActive, let credential else { return }
        if !hostingEnabled, let session, isHost {
            Task {
                struct Publishing: Encodable { var enabled = false }
                let _: ScoreboardCloudSession? = try? await call(base: ScoreboardCloudEndpoint.validate(credential.serviceURL),
                    path: "api/sessions/\(session.id)/publishing", body: Publishing(), token: credential.token)
                if hostingEnabled && !remoteActive { reconnect() }
            }
            suspendTransport(); status = "Cloud hosting is off."
        } else { reconnect() }
    }

    func refreshSessions() async {
        guard let credential else { return }
        do {
            struct Listing: Decodable { var sessions: [ScoreboardCloudSessionChoice] }
            let value: Listing = try await get(base: ScoreboardCloudEndpoint.validate(credential.serviceURL), path: "api/sessions", token: credential.token)
            guard self.credential?.token == credential.token else { return }
            sessions = value.sessions
        } catch { status = error.localizedDescription }
    }

    func refreshDevices() async {
        guard let credential, !isRemoteRegistration else { return }
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
        guard isHost, let credential, let session else { return false }
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

    func provisionRemote(id: String, name: String, controlAllowed: Bool) async throws -> Data {
        guard cloudFailoverEnabled, hostingEnabled, isHost, let credential, let session else { throw URLError(.userAuthenticationRequired) }
        struct Enrollment: Encodable { var deviceID: String; var name: String; var controlAllowed: Bool; var sessionID: String }
        struct Grant: Decodable { var token: String; var accountID: String; var sessionID: String; var hostLocalID: String }
        let grant: Grant = try await call(base: ScoreboardCloudEndpoint.validate(credential.serviceURL), path: "api/devices/enroll",
            body: Enrollment(deviceID: id, name: name, controlAllowed: controlAllowed, sessionID: session.id), token: credential.token)
        return try JSONEncoder().encode(ScoreboardCloudEnrollment(serviceURL: credential.serviceURL, token: grant.token,
            sessionID: grant.sessionID, accountID: grant.accountID, hostLocalID: grant.hostLocalID, remoteDeviceID: id))
    }

    func updateRemotePermission(localID: String, allowed: Bool, force: Bool = false) {
        guard isHost, let credential, let account, let session else { return }
        let id = "native:\(account.id):\(localID)"
        guard force || remotePermissionTasks[id] != nil || session.members.contains(where: { $0.id == id }) else { return }
        pendingRemotePermissions[id] = allowed
        flushRemotePermission(id, sessionID: session.id, token: credential.token)
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
            acceptEnrollment(plaintext, authenticatedHostID: authenticatedHostID, localDeviceID: localDeviceID)
        }
        return true
    }

    func disconnect() {
        connectionID = UUID()
        linkRunID = UUID()
        linkTask?.cancel(); connectionTask?.cancel(); heartbeatTask?.cancel(); publishTask?.cancel()
        remotePermissionTasks.values.forEach { $0.cancel() }; remotePermissionTasks.removeAll(); pendingRemotePermissions.removeAll()
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        credential = nil
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
        do { try CloudKeychain.save(nil) }
        catch { status = "Disconnected. The saved cloud credential could not be removed from Keychain."; return }
        #endif
        status = "Cloud connection is off. Local play continues."
    }

    // Coalesce app changes to at most 5 snapshots/second. A periodic snapshot
    // keeps stopped games alive without sending commands or running game logic.
    func publish(_ state: ScoreboardWebAPIState) {
        guard isHost, isConnected else { return }
        pendingState = state
        guard publishTask == nil else { return }
        publishTask = Task { [weak self] in
            guard let self else { return }
            let delay = max(0, 0.2 - Date().timeIntervalSince(lastPublishAt))
            do { try await Task.sleep(for: .seconds(delay)) } catch { publishTask = nil; return }
            defer { publishTask = nil }
            guard let state = pendingState, isHost, let generation = session?.generation else { return }
            pendingState = nil
            lastPublishAt = Date()
            send(Frame(type: "state", generation: generation, state: state))
        }
    }

    private func publishCommentator() {
        guard isHost, isConnected, let generation = session?.generation,
              let payload = commentatorProvider?() else { return }
        send(Frame(type: "commentator", generation: generation, commentator: payload.limited(to: 120)))
    }

    private func startHeartbeat(_ task: URLSessionWebSocketTask, runID: UUID) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self, weak task] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self, let task, connectionID == runID else { return }
                if isHost {
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
            isConnected = true
            status = isHost ? "Hosting \(room.name) through the cloud." : "Connected to \(room.name)."
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
        } else if frame.type == "state", let state = frame.state, !isHost {
            lastStateAt = Date()
            receiver.receiveCloudState(state, controlAllowed: canControl, hostName: session?.name ?? "Cloud host")
        } else if frame.type == "command", isHost, frame.generation == session?.generation,
                  let command = frame.command, let clientID = frame.clientID, let requestID = frame.requestID {
            let result = canHostProvider?() == true ? commandHandler?(command) ?? .failure(command.id, "disabled", "Host unavailable.")
                : .failure(command.id, "conflict", "This device is no longer the game host.")
            send(Frame(type: "result", generation: session?.generation, clientID: clientID, requestID: requestID, result: result))
            if let state = stateProvider?() { publish(state) }
        } else if frame.type == "result", let result = frame.result { receiver.receiveCloudResult(result) }
        else if frame.type == "error" { status = frame.message ?? "Cloud request failed." }
    }

    private func sendCommand(_ input: ScoreboardControlCommand) {
        guard canControl, isConnected, session?.hostOnline == true,
              lastStateAt.map({ Date().timeIntervalSince($0) < 15 }) == true else {
            receiver.receiveCloudResult(.failure(input.id, "disconnected", "The host is unavailable.")); return
        }
        // The host applies at arrival time. Cross-device wall clocks are not
        // trusted for delay compensation on this first cloud protocol.
        var command = input
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
    private func call<Input: Encodable, Result: Decodable>(base: URL, path: String, body: Input, token: String? = nil) async throws -> Result {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "POST"
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await response(request)
    }
    private func response<Result: Decodable>(_ request: URLRequest) async throws -> Result {
        let (data, response) = try await URLSession.shared.data(for: request)
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
                       sameHost: Bool, current: Self, hasPendingCommand: Bool) -> Self {
        guard mode.allowsCloud else { return .local }
        if hasPendingCommand { return current }
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
    private var mode: ScoreboardRemoteDisplayNetworkMode = .nearbyAndLocalNetwork
    private let local = ScoreboardRemoteDisplayReceiver.shared
    private let cloud = ScoreboardCloudClient.shared
    var receiver: ScoreboardRemoteDisplayReceiver { route == .cloud ? cloud.receiver : local }

    func acquire(mode: ScoreboardRemoteDisplayNetworkMode) {
        consumers += 1
        if consumers == 1 {
            local.acquire(networkMode: mode)
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
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
        let sameHost = cloud.selectedSessionID.isEmpty || (cloud.selectedHostLocalID != nil && cloud.selectedHostLocalID == local.connectedHostID)
        // Never fall back to a different game simply because it is nearby.
        let eligibleLocal = localFresh && (!mode.allowsCloud || sameHost)
        let selected = ScoreboardRemoteRoute.choose(mode: mode, localFresh: eligibleLocal, cloudFresh: cloudFresh,
            sameHost: sameHost, current: route,
            hasPendingCommand: local.pendingControlCommandID != nil || cloud.receiver.pendingControlCommandID != nil)
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
