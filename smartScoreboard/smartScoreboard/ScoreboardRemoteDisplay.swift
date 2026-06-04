import Combine
import Foundation
import SwiftUI
@preconcurrency import MultipeerConnectivity
#if os(iOS) || os(tvOS)
import UIKit
#endif
#if os(macOS)
import SystemConfiguration
#endif

private func localizedRemoteDisplayString(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func localizedRemoteDisplayFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localizedRemoteDisplayString(key), locale: Locale.current, arguments: arguments)
}

nonisolated enum ScoreboardRemoteDisplayHostStatus: Equatable, Sendable {
    case off
    case browsing(displayCount: Int, pairedCount: Int)
    case failed(String)

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .browsing:
            return "Ready"
        case .failed:
            return "Failed"
        }
    }

    var detail: String {
        switch self {
        case .off:
            return "Remote Display pairing is off."
        case .browsing(let displayCount, let pairedCount):
            return "Found \(displayCount) display\(displayCount == 1 ? "" : "s"), \(pairedCount) paired."
        case .failed(let message):
            return message
        }
    }

    var isError: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

nonisolated enum ScoreboardRemoteDisplayReceiverStatus: Equatable, Sendable {
    case waiting
    case paired(String)
    case disconnected(String)
    case failed(String)

    var title: String {
        switch self {
        case .waiting:
            return "Ready to Pair"
        case .paired:
            return "Live"
        case .disconnected:
            return "Disconnected"
        case .failed:
            return "Connection Failed"
        }
    }

    var detail: String {
        switch self {
        case .waiting:
            return "Open Scoreboard settings on the operator device and pair this display."
        case .paired(let name):
            return "Receiving live scoreboard updates from \(name)."
        case .disconnected(let message), .failed(let message):
            return message
        }
    }

    var isLive: Bool {
        if case .paired = self {
            return true
        }
        return false
    }
}

nonisolated enum ScoreboardRemoteDisplayConnectionQuality: String, Equatable, Sendable {
    case connecting
    case live
    case poor
    case unresponsive

    var title: String {
        switch self {
        case .connecting:
            return "Connecting"
        case .live:
            return "Live"
        case .poor:
            return "Poor"
        case .unresponsive:
            return "Unresponsive"
        }
    }
}

nonisolated enum ScoreboardRemoteDisplayDeviceType: String, Codable, Equatable, Sendable {
    case mac
    case ipad
    case appleTV
    case unknown

    static var current: ScoreboardRemoteDisplayDeviceType {
        #if os(tvOS)
        return .appleTV
        #elseif os(macOS)
        return .mac
        #elseif os(iOS)
        return .ipad
        #else
        return .unknown
        #endif
    }

    var title: String {
        switch self {
        case .mac:
            return "Mac"
        case .ipad:
            return "iPad"
        case .appleTV:
            return "Apple TV"
        case .unknown:
            return "Display"
        }
    }

    var systemImage: String {
        switch self {
        case .mac:
            return "desktopcomputer"
        case .ipad:
            return "ipad.landscape"
        case .appleTV:
            return "appletv"
        case .unknown:
            return "display"
        }
    }
}

struct ScoreboardRemoteDisplaySource: Identifiable {
    let peerID: MCPeerID
    let discoveryInfo: [String: String]?

    var id: String { discoveryInfo?["displayID"] ?? peerID.displayName }
    var name: String { discoveryInfo?["name"] ?? peerID.displayName }
    var detail: String { discoveryInfo?["app"] ?? localizedRemoteDisplayString("Scoreboard Remote Display") }
    var deviceType: ScoreboardRemoteDisplayDeviceType {
        discoveryInfo?["deviceType"].flatMap(ScoreboardRemoteDisplayDeviceType.init(rawValue:)) ?? .unknown
    }
    var appVersion: ScoreboardRemoteDisplayAppVersion? {
        ScoreboardRemoteDisplayAppVersion(
            version: discoveryInfo?["appVersion"],
            build: discoveryInfo?["appBuild"]
        )
    }
    var activeHostID: String? { discoveryInfo?["activeHostID"] ?? discoveryInfo?["pairedHostID"] }
    var activeHostName: String? { discoveryInfo?["activeHostName"] ?? discoveryInfo?["pairedHostName"] }
    var pairedHostID: String? { discoveryInfo?["pairedHostID"] }
    var pairedHostName: String? { discoveryInfo?["pairedHostName"] }
    var pairingSetID: String? { discoveryInfo?["pairingSetID"] }

    func isInUseByOtherBoard(currentHostID: String) -> Bool {
        guard let activeHostID, !activeHostID.isEmpty else {
            return false
        }
        return activeHostID != currentHostID
    }
}

nonisolated struct ScoreboardRemoteDisplayConnection: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let quality: ScoreboardRemoteDisplayConnectionQuality
    let latencyMilliseconds: Int?
    let lastHandshakeAgeSeconds: Int?
    let appVersion: ScoreboardRemoteDisplayAppVersion?
    let deviceType: ScoreboardRemoteDisplayDeviceType
    let isMuted: Bool
}

nonisolated struct ScoreboardRemoteDisplayPairingRequest: Codable, Sendable {
    let pairingCode: String?
    let hostID: String
    let hostName: String
    let displayID: String?
    let trustedReconnect: Bool

    init(
        pairingCode: String?,
        hostID: String,
        hostName: String,
        displayID: String?,
        trustedReconnect: Bool
    ) {
        self.pairingCode = pairingCode
        self.hostID = hostID
        self.hostName = hostName
        self.displayID = displayID
        self.trustedReconnect = trustedReconnect
    }

    private enum CodingKeys: String, CodingKey {
        case pairingCode
        case hostID
        case hostName
        case displayID
        case trustedReconnect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pairingCode = try container.decodeIfPresent(String.self, forKey: .pairingCode)
        hostID = try container.decode(String.self, forKey: .hostID)
        hostName = try container.decode(String.self, forKey: .hostName)
        displayID = try container.decodeIfPresent(String.self, forKey: .displayID)
        trustedReconnect = try container.decodeIfPresent(Bool.self, forKey: .trustedReconnect) ?? false
    }
}

nonisolated struct ScoreboardRemoteDisplayControlMessage: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case heartbeat
        case heartbeatAck
        case soundTest
        case soundEffect
        case setMuted
        case disconnect
        case removePairing
    }

    let kind: Kind
    let sequence: UInt64
    let sentAt: TimeInterval
    let hostID: String?
    let hostName: String?
    let displayID: String?
    let displayName: String?
    let pairingSetID: String?
    let appVersion: String?
    let appBuild: String?
    let deviceType: String?
    let isMuted: Bool?
    let soundEffect: String?

    init(
        kind: Kind,
        sequence: UInt64,
        sentAt: TimeInterval,
        hostID: String?,
        hostName: String?,
        displayID: String?,
        displayName: String?,
        pairingSetID: String? = nil,
        appVersion: String? = nil,
        appBuild: String? = nil,
        deviceType: ScoreboardRemoteDisplayDeviceType? = nil,
        isMuted: Bool? = nil,
        soundEffect: ScoreboardSoundEffect? = nil
    ) {
        self.kind = kind
        self.sequence = sequence
        self.sentAt = sentAt
        self.hostID = hostID
        self.hostName = hostName
        self.displayID = displayID
        self.displayName = displayName
        self.pairingSetID = pairingSetID
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.deviceType = deviceType?.rawValue
        self.isMuted = isMuted
        self.soundEffect = soundEffect?.rawValue
    }
}

nonisolated struct ScoreboardRemoteDisplayAppVersion: Codable, Equatable, Sendable {
    let version: String
    let build: String

    init?(version: String?, build: String?) {
        let resolvedVersion = version?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedBuild = build?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !resolvedVersion.isEmpty || !resolvedBuild.isEmpty else {
            return nil
        }
        self.version = resolvedVersion
        self.build = resolvedBuild
    }

    static var current: ScoreboardRemoteDisplayAppVersion {
        ScoreboardRemoteDisplayAppVersion(
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        ) ?? ScoreboardRemoteDisplayAppVersion(version: "unknown", build: "unknown")
    }

    var displayText: String {
        if !version.isEmpty, !build.isEmpty {
            return "\(version) (\(build))"
        }
        if !version.isEmpty {
            return version
        }
        return build
    }

    func isMismatch(with other: ScoreboardRemoteDisplayAppVersion = .current) -> Bool {
        version != other.version || build != other.build
    }

    private init(version: String, build: String) {
        self.version = version
        self.build = build
    }
}

nonisolated struct ScoreboardRemoteDisplayTrustedPeer: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let pairingSetID: String?
    let deviceType: ScoreboardRemoteDisplayDeviceType?

    init(
        id: String,
        name: String,
        pairingSetID: String? = nil,
        deviceType: ScoreboardRemoteDisplayDeviceType? = nil
    ) {
        self.id = id
        self.name = name
        self.pairingSetID = pairingSetID
        self.deviceType = deviceType
    }
}

private enum ScoreboardRemoteDisplayIdentity {
    private static let keyPrefix = "com.ironmaple.smartscoreboard."

    static func stableID(forKey key: String) -> String {
        let defaultsKey = "\(keyPrefix)\(key)"
        let defaults = UserDefaults.standard
        if let existingID = defaults.string(forKey: defaultsKey), !existingID.isEmpty {
            return existingID
        }

        let newID = UUID().uuidString
        defaults.set(newID, forKey: defaultsKey)
        return newID
    }

    static func resetStableID(forKey key: String) -> String {
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: "\(keyPrefix)\(key)")
        return newID
    }
}

enum ScoreboardRemoteDisplayDeviceName {
    static var current: String? {
        #if os(iOS) || os(tvOS)
        let name = UIDevice.current.name
        return name.isEmpty ? nil : name
        #elseif os(macOS)
        if let computerName = SCDynamicStoreCopyComputerName(nil, nil) as String?, !computerName.isEmpty {
            return computerName
        }
        if let localizedName = Host.current().localizedName, !localizedName.isEmpty {
            return localizedName
        }
        let hostName = ProcessInfo.processInfo.hostName
        return hostName.isEmpty ? nil : hostName
        #else
        let hostName = ProcessInfo.processInfo.hostName
        return hostName.isEmpty ? nil : hostName
        #endif
    }
}

private enum ScoreboardRemoteDisplayPairingStore {
    private static let trustedDisplaysKey = "com.ironmaple.smartscoreboard.remoteDisplayTrustedDisplays"
    private static let trustedHostsKey = "com.ironmaple.smartscoreboard.remoteDisplayTrustedHosts"
    private static let mutedDisplaysKey = "com.ironmaple.smartscoreboard.remoteDisplayMutedDisplays"

    static func trustedDisplays() -> [ScoreboardRemoteDisplayTrustedPeer] {
        load(key: trustedDisplaysKey)
    }

    static func saveTrustedDisplays(_ peers: [ScoreboardRemoteDisplayTrustedPeer]) {
        save(peers, key: trustedDisplaysKey)
    }

    static func trustedHosts() -> [ScoreboardRemoteDisplayTrustedPeer] {
        load(key: trustedHostsKey)
    }

    static func saveTrustedHosts(_ peers: [ScoreboardRemoteDisplayTrustedPeer]) {
        save(peers, key: trustedHostsKey)
    }

    static func mutedDisplayIDs() -> Set<String> {
        let ids = UserDefaults.standard.stringArray(forKey: mutedDisplaysKey) ?? []
        return Set(ids.filter { !$0.isEmpty })
    }

    static func saveMutedDisplayIDs(_ ids: Set<String>) {
        UserDefaults.standard.set(ids.sorted(), forKey: mutedDisplaysKey)
    }

    private static func load(key: String) -> [ScoreboardRemoteDisplayTrustedPeer] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let peers = try? JSONDecoder().decode([ScoreboardRemoteDisplayTrustedPeer].self, from: data)
        else {
            return []
        }
        return peers.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func save(_ peers: [ScoreboardRemoteDisplayTrustedPeer], key: String) {
        let sortedPeers = peers.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if let data = try? JSONEncoder().encode(sortedPeers) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

@MainActor
final class ScoreboardRemoteDisplayHostService: NSObject, ObservableObject {
    static let serviceType = "scorebrd-tv"
    static let bonjourServiceType = "_scorebrd-tv._tcp"
    static let pairingCodeLength = 4
    private static let heartbeatInterval: TimeInterval = 0.2
    private static let periodicStateSyncInterval: TimeInterval = 1.0

    @Published private(set) var status: ScoreboardRemoteDisplayHostStatus = .off
    @Published private(set) var sources: [ScoreboardRemoteDisplaySource] = []
    @Published private(set) var connectedDisplays: [ScoreboardRemoteDisplayConnection] = []
    @Published private(set) var trustedDisplays: [ScoreboardRemoteDisplayTrustedPeer] = ScoreboardRemoteDisplayPairingStore.trustedDisplays()
    @Published private(set) var mutedDisplayIDs: Set<String> = ScoreboardRemoteDisplayPairingStore.mutedDisplayIDs()

    let hostID = ScoreboardRemoteDisplayIdentity.stableID(forKey: "remoteDisplayHostID")

    private var peerID: MCPeerID?
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?
    private var latestStateData = Data()
    private var invitedPeerIDs = Set<String>()
    private var heartbeatTimer: Timer?
    private var heartbeatSequence: UInt64 = 0
    private var peerHandshakeMetricsByID: [String: PeerHandshakeMetrics] = [:]
    private var pendingTrustedDisplaysByPeerName: [String: ScoreboardRemoteDisplayTrustedPeer] = [:]
    private var lastTrustedInviteAttemptByID: [String: Date] = [:]
    private var currentStateProvider: (() -> Data)?
    private var lastPeriodicStateSyncAt: Date?
    private var peerNamesResettingPairing = Set<String>()

    func start(initialState: Data, displayName: String, currentStateProvider: (() -> Data)? = nil) {
        stop()
        self.currentStateProvider = currentStateProvider
        latestStateData = currentStateProvider?() ?? initialState

        let peerID = MCPeerID(displayName: displayName)
        let session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self

        let browser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: Self.serviceType
        )
        browser.delegate = self

        self.peerID = peerID
        self.session = session
        self.browser = browser
        browser.startBrowsingForPeers()
        startHeartbeatTimer()
        updateBrowsingStatus()
    }

    func stop() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil
        session?.disconnect()
        session?.delegate = nil
        session = nil
        peerID = nil
        sources.removeAll()
        connectedDisplays.removeAll()
        peerHandshakeMetricsByID.removeAll()
        invitedPeerIDs.removeAll()
        pendingTrustedDisplaysByPeerName.removeAll()
        lastTrustedInviteAttemptByID.removeAll()
        currentStateProvider = nil
        lastPeriodicStateSyncAt = nil
        peerNamesResettingPairing.removeAll()
        status = .off
    }

    func pair(with source: ScoreboardRemoteDisplaySource, pairingCode: String) {
        guard let browser, let session else {
            status = .failed(localizedRemoteDisplayString("Remote Display pairing is not running."))
            return
        }

        guard !source.isInUseByOtherBoard(currentHostID: hostID) else {
            status = .failed(localizedRemoteDisplayFormat(
                "%@ is in use by %@.",
                source.name,
                source.activeHostName ?? localizedRemoteDisplayString("another board")
            ))
            return
        }

        let sanitizedCode = Self.sanitizedPairingCode(pairingCode)
        guard sanitizedCode.count == Self.pairingCodeLength else {
            status = .failed(localizedRemoteDisplayFormat(
                "Enter the %d-digit pairing code shown on %@.",
                Self.pairingCodeLength,
                source.name
            ))
            return
        }

        invitedPeerIDs.insert(source.id)
        let request = ScoreboardRemoteDisplayPairingRequest(
            pairingCode: sanitizedCode,
            hostID: hostID,
            hostName: peerID?.displayName ?? Self.defaultHostName,
            displayID: source.id,
            trustedReconnect: false
        )
        pendingTrustedDisplaysByPeerName[source.peerID.displayName] = ScoreboardRemoteDisplayTrustedPeer(
            id: source.id,
            name: source.name,
            pairingSetID: source.pairingSetID,
            deviceType: source.deviceType
        )
        let context = (try? JSONEncoder().encode(request)) ?? Data(sanitizedCode.utf8)
        browser.invitePeer(source.peerID, to: session, withContext: context, timeout: 15)
        lastTrustedInviteAttemptByID[source.id] = Date()
        updateBrowsingStatus()
    }

    func connectTrustedDisplay(_ source: ScoreboardRemoteDisplaySource) {
        guard !source.isInUseByOtherBoard(currentHostID: hostID) else {
            status = .failed(localizedRemoteDisplayFormat(
                "%@ is in use by %@.",
                source.name,
                source.activeHostName ?? localizedRemoteDisplayString("another board")
            ))
            return
        }

        guard isTrustedDisplay(source) else {
            status = .failed(localizedRemoteDisplayFormat("%@ needs a new pairing code.", source.name))
            return
        }

        inviteTrustedDisplayIfNeeded(source, force: true)
    }

    func removeTrustedDisplay(id displayID: String) {
        trustedDisplays.removeAll { $0.id == displayID }
        ScoreboardRemoteDisplayPairingStore.saveTrustedDisplays(trustedDisplays)
        mutedDisplayIDs.remove(displayID)
        ScoreboardRemoteDisplayPairingStore.saveMutedDisplayIDs(mutedDisplayIDs)

        if let peer = connectedPeer(forDisplayID: displayID) {
            let message = ScoreboardRemoteDisplayControlMessage(
                kind: .removePairing,
                sequence: heartbeatSequence,
                sentAt: Date().timeIntervalSince1970,
                hostID: hostID,
                hostName: peerID?.displayName,
                displayID: displayID,
                displayName: nil
            )
            sendControlMessage(message, to: [peer], mode: .reliable)
        }

        updateBrowsingStatus()
    }

    func disconnectDisplay(id displayID: String) {
        guard let peer = connectedPeer(forDisplayID: displayID) else {
            return
        }

        let message = ScoreboardRemoteDisplayControlMessage(
            kind: .disconnect,
            sequence: heartbeatSequence,
            sentAt: Date().timeIntervalSince1970,
            hostID: hostID,
            hostName: peerID?.displayName,
            displayID: displayID,
            displayName: nil
        )
        sendControlMessage(message, to: [peer], mode: .reliable)
    }

    func sendSoundTest(toDisplayID displayID: String) {
        guard !mutedDisplayIDs.contains(displayID) else {
            status = .failed(localizedRemoteDisplayString("Unmute this Remote Display before running a sound test."))
            return
        }
        guard let peer = connectedPeer(forDisplayID: displayID) else {
            status = .failed(localizedRemoteDisplayString("Connect the Remote Display before running a sound test."))
            return
        }

        let message = ScoreboardRemoteDisplayControlMessage(
            kind: .soundTest,
            sequence: heartbeatSequence,
            sentAt: Date().timeIntervalSince1970,
            hostID: hostID,
            hostName: peerID?.displayName,
            displayID: displayID,
            displayName: nil
        )
        sendControlMessage(message, to: [peer], mode: .reliable)
    }

    func sendSoundEffect(_ effect: ScoreboardSoundEffect) {
        guard effect != .none, let session else {
            return
        }

        let targetPeers = session.connectedPeers.filter { peer in
            !mutedDisplayIDs.contains(sourceID(for: peer))
        }
        guard !targetPeers.isEmpty else {
            return
        }

        let message = ScoreboardRemoteDisplayControlMessage(
            kind: .soundEffect,
            sequence: heartbeatSequence,
            sentAt: Date().timeIntervalSince1970,
            hostID: hostID,
            hostName: peerID?.displayName,
            displayID: nil,
            displayName: nil,
            soundEffect: effect
        )
        sendControlMessage(message, to: targetPeers, mode: .reliable)
    }

    func setDisplayMuted(id displayID: String, isMuted: Bool) {
        if isMuted {
            mutedDisplayIDs.insert(displayID)
        } else {
            mutedDisplayIDs.remove(displayID)
        }
        ScoreboardRemoteDisplayPairingStore.saveMutedDisplayIDs(mutedDisplayIDs)
        if let peer = connectedPeer(forDisplayID: displayID) {
            sendMuteState(to: [peer], displayID: displayID)
        }
        updateBrowsingStatus()
    }

    func isTrustedDisplay(_ source: ScoreboardRemoteDisplaySource) -> Bool {
        guard let trustedDisplay = trustedDisplays.first(where: { $0.id == source.id }) else {
            return false
        }
        guard
            let trustedPairingSetID = trustedDisplay.pairingSetID,
            let sourcePairingSetID = source.pairingSetID
        else {
            return true
        }
        return trustedPairingSetID == sourcePairingSetID
    }

    func isTrustedDisplay(id displayID: String) -> Bool {
        trustedDisplays.contains { $0.id == displayID }
    }

    private func inviteTrustedDisplayIfNeeded(_ source: ScoreboardRemoteDisplaySource, force: Bool = false) {
        guard let browser, let session else {
            status = .failed(localizedRemoteDisplayString("Remote Display pairing is not running."))
            return
        }
        guard isTrustedDisplay(source), !source.isInUseByOtherBoard(currentHostID: hostID) else {
            return
        }
        guard !isConnected(to: source) else {
            return
        }
        if !force, let lastAttempt = lastTrustedInviteAttemptByID[source.id], Date().timeIntervalSince(lastAttempt) < 5 {
            return
        }

        let request = ScoreboardRemoteDisplayPairingRequest(
            pairingCode: nil,
            hostID: hostID,
            hostName: peerID?.displayName ?? Self.defaultHostName,
            displayID: source.id,
            trustedReconnect: true
        )
        guard let context = try? JSONEncoder().encode(request) else {
            return
        }

        invitedPeerIDs.insert(source.id)
        lastTrustedInviteAttemptByID[source.id] = Date()
        browser.invitePeer(source.peerID, to: session, withContext: context, timeout: 10)
        updateBrowsingStatus()
    }

    func disconnectDisplays() {
        guard session != nil else {
            connectedDisplays.removeAll()
            status = .off
            return
        }

        session?.disconnect()
        invitedPeerIDs.removeAll()
        connectedDisplays.removeAll()
        peerHandshakeMetricsByID.removeAll()
        pendingTrustedDisplaysByPeerName.removeAll()
        lastPeriodicStateSyncAt = nil
        peerNamesResettingPairing.removeAll()
        status = .browsing(displayCount: sources.count, pairedCount: 0)
    }

    func updateState(_ data: Data) {
        latestStateData = data
        sendState(data, mode: .unreliable)
    }

    private func startHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: Self.heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sendHeartbeat()
            }
        }
    }

    private func sendHeartbeat() {
        guard let session, !session.connectedPeers.isEmpty else {
            updateBrowsingStatus()
            return
        }

        heartbeatSequence &+= 1
        let now = Date()
        let message = ScoreboardRemoteDisplayControlMessage(
            kind: .heartbeat,
            sequence: heartbeatSequence,
            sentAt: now.timeIntervalSince1970,
            hostID: hostID,
            hostName: peerID?.displayName,
            displayID: nil,
            displayName: nil,
            appVersion: ScoreboardRemoteDisplayAppVersion.current.version,
            appBuild: ScoreboardRemoteDisplayAppVersion.current.build
        )
        sendControlMessage(message, mode: .unreliable)
        sendPeriodicStateSyncIfNeeded(now: now)
        updateBrowsingStatus()
    }

    private func sendPeriodicStateSyncIfNeeded(now: Date) {
        guard let session, !session.connectedPeers.isEmpty else {
            return
        }
        if let lastPeriodicStateSyncAt, now.timeIntervalSince(lastPeriodicStateSyncAt) < Self.periodicStateSyncInterval {
            return
        }

        lastPeriodicStateSyncAt = now
        sendState(currentStateData(), mode: .reliable)
    }

    private func handleControlMessage(_ message: ScoreboardRemoteDisplayControlMessage, from peerID: MCPeerID) {
        if message.kind == .removePairing {
            handleDisplayRemovedPairing(message, from: peerID)
            return
        }

        guard message.kind == .heartbeatAck else {
            return
        }

        let now = Date()
        if let lastAckSequence = peerHandshakeMetricsByID[peerID.displayName]?.lastAckSequence,
           message.sequence <= lastAckSequence {
            return
        }

        let latency = max(0, now.timeIntervalSince1970 - message.sentAt)
        let displayID = message.displayID ?? peerID.displayName
        let displayName = message.displayName ?? peerID.displayName
        peerHandshakeMetricsByID[peerID.displayName] = PeerHandshakeMetrics(
            displayID: displayID,
            displayName: displayName,
            lastAckAt: now,
            lastAckSequence: message.sequence,
            latency: latency,
            appVersion: ScoreboardRemoteDisplayAppVersion(
                version: message.appVersion,
                build: message.appBuild
            ),
            deviceType: message.deviceType.flatMap(ScoreboardRemoteDisplayDeviceType.init(rawValue:))
                ?? sources.first { $0.peerID == peerID || $0.id == displayID }?.deviceType
                ?? .unknown
        )
        invitedPeerIDs.remove(displayID)
        invitedPeerIDs.remove(peerID.displayName)
        lastTrustedInviteAttemptByID.removeValue(forKey: displayID)

        let pendingTrustedDisplay = pendingTrustedDisplaysByPeerName.removeValue(forKey: peerID.displayName)
        if pendingTrustedDisplay != nil || isTrustedDisplay(id: displayID) {
            let pairingSetID = pendingTrustedDisplay?.pairingSetID
                ?? sources.first { $0.id == displayID }?.pairingSetID
                ?? trustedDisplays.first { $0.id == displayID }?.pairingSetID
            let deviceType = pendingTrustedDisplay?.deviceType
                ?? sources.first { $0.id == displayID }?.deviceType
                ?? message.deviceType.flatMap(ScoreboardRemoteDisplayDeviceType.init(rawValue:))
                ?? trustedDisplays.first { $0.id == displayID }?.deviceType
            trustDisplay(id: displayID, name: displayName, pairingSetID: pairingSetID, deviceType: deviceType)
        }
        sendMuteState(to: [peerID], displayID: displayID)
        updateBrowsingStatus()
    }

    private func handleDisplayRemovedPairing(_ message: ScoreboardRemoteDisplayControlMessage, from peerID: MCPeerID) {
        let displayID = message.displayID
            ?? peerHandshakeMetricsByID[peerID.displayName]?.displayID
            ?? sourceID(for: peerID)
        let displayName = message.displayName
            ?? peerHandshakeMetricsByID[peerID.displayName]?.displayName
            ?? peerID.displayName

        trustedDisplays.removeAll { $0.id == displayID }
        ScoreboardRemoteDisplayPairingStore.saveTrustedDisplays(trustedDisplays)
        mutedDisplayIDs.remove(displayID)
        ScoreboardRemoteDisplayPairingStore.saveMutedDisplayIDs(mutedDisplayIDs)
        peerNamesResettingPairing.insert(peerID.displayName)
        peerHandshakeMetricsByID.removeValue(forKey: peerID.displayName)
        invitedPeerIDs.remove(displayID)
        invitedPeerIDs.remove(peerID.displayName)
        pendingTrustedDisplaysByPeerName.removeValue(forKey: peerID.displayName)
        lastTrustedInviteAttemptByID.removeValue(forKey: displayID)
        updateSourceAfterDisplayReset(
            peerID,
            displayID: displayID,
            displayName: displayName,
            pairingSetID: message.pairingSetID,
            appVersion: message.appVersion,
            appBuild: message.appBuild,
            deviceType: message.deviceType.flatMap(ScoreboardRemoteDisplayDeviceType.init(rawValue:))
        )
        updateBrowsingStatus()
    }

    private func sendControlMessage(
        _ message: ScoreboardRemoteDisplayControlMessage,
        to peers: [MCPeerID]? = nil,
        mode: MCSessionSendDataMode
    ) {
        guard let data = try? JSONEncoder().encode(message) else {
            return
        }
        sendData(data, to: peers, mode: mode)
    }

    private func handleFoundPeer(_ peerID: MCPeerID, discoveryInfo: [String: String]?) {
        let source = ScoreboardRemoteDisplaySource(peerID: peerID, discoveryInfo: discoveryInfo)
        removeResetTrustedDisplayIfNeeded(source)
        if let existingIndex = sources.firstIndex(where: { $0.id == source.id || $0.peerID == peerID }) {
            sources[existingIndex] = source
        } else {
            sources.append(source)
        }
        sources.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        updateBrowsingStatus()
    }

    private func handleLostPeer(_ peerID: MCPeerID) {
        let sourceID = sourceID(for: peerID)
        sources.removeAll { $0.peerID == peerID }
        invitedPeerIDs.remove(sourceID)
        invitedPeerIDs.remove(peerID.displayName)
        updateBrowsingStatus()
    }

    private func handlePeerStateChanged(_ peerID: MCPeerID, state: MCSessionState) {
        switch state {
        case .connected:
            peerHandshakeMetricsByID[peerID.displayName] = PeerHandshakeMetrics(
                displayID: peerID.displayName,
                displayName: peerID.displayName,
                lastAckAt: nil,
                lastAckSequence: nil,
                latency: nil,
                appVersion: sources.first { $0.peerID == peerID }?.appVersion,
                deviceType: sources.first { $0.peerID == peerID }?.deviceType ?? .unknown
            )
        case .notConnected:
            let sourceID = sourceID(for: peerID)
            peerHandshakeMetricsByID.removeValue(forKey: peerID.displayName)
            invitedPeerIDs.remove(sourceID)
            invitedPeerIDs.remove(peerID.displayName)
            pendingTrustedDisplaysByPeerName.removeValue(forKey: peerID.displayName)
            peerNamesResettingPairing.remove(peerID.displayName)
        case .connecting:
            break
        @unknown default:
            break
        }

        updateBrowsingStatus()

        if state == .connected {
            sendState(currentStateData(), to: [peerID], mode: .reliable)
            sendMuteState(to: [peerID])
            sendHeartbeat()
        }
    }

    private func currentStateData() -> Data {
        if let data = currentStateProvider?(), !data.isEmpty {
            latestStateData = data
        }
        return latestStateData
    }

    private func sourceID(for peerID: MCPeerID) -> String {
        if let metrics = peerHandshakeMetricsByID[peerID.displayName] {
            return metrics.displayID
        }
        return sources.first { $0.peerID == peerID }?.id ?? peerID.displayName
    }

    private func connectedPeer(forDisplayID displayID: String) -> MCPeerID? {
        session?.connectedPeers.first { peer in
            peerHandshakeMetricsByID[peer.displayName]?.displayID == displayID
                || sources.first { $0.peerID == peer }?.id == displayID
        }
    }

    private func isConnected(to source: ScoreboardRemoteDisplaySource) -> Bool {
        guard let session else {
            return false
        }
        return session.connectedPeers.contains(source.peerID) && !peerNamesResettingPairing.contains(source.peerID.displayName)
            || connectedDisplays.contains { $0.id == source.id }
    }

    private func updateSourceAfterDisplayReset(
        _ peerID: MCPeerID,
        displayID: String,
        displayName: String,
        pairingSetID: String?,
        appVersion: String?,
        appBuild: String?,
        deviceType: ScoreboardRemoteDisplayDeviceType?
    ) {
        let fallbackInfo = [
            "app": "Smart Scoreboard",
            "role": "display",
            "name": displayName,
            "displayID": displayID
        ]
        var discoveryInfo = sources.first { $0.peerID == peerID || $0.id == displayID }?.discoveryInfo ?? fallbackInfo
        discoveryInfo["name"] = displayName
        discoveryInfo["displayID"] = displayID
        if let appVersion, !appVersion.isEmpty {
            discoveryInfo["appVersion"] = appVersion
        } else {
            discoveryInfo.removeValue(forKey: "appVersion")
        }
        if let appBuild, !appBuild.isEmpty {
            discoveryInfo["appBuild"] = appBuild
        } else {
            discoveryInfo.removeValue(forKey: "appBuild")
        }
        if let pairingSetID {
            discoveryInfo["pairingSetID"] = pairingSetID
        } else {
            discoveryInfo.removeValue(forKey: "pairingSetID")
        }
        if let deviceType {
            discoveryInfo["deviceType"] = deviceType.rawValue
        } else {
            discoveryInfo.removeValue(forKey: "deviceType")
        }
        discoveryInfo.removeValue(forKey: "activeHostID")
        discoveryInfo.removeValue(forKey: "activeHostName")
        discoveryInfo.removeValue(forKey: "pairedHostID")
        discoveryInfo.removeValue(forKey: "pairedHostName")

        let source = ScoreboardRemoteDisplaySource(peerID: peerID, discoveryInfo: discoveryInfo)
        if let index = sources.firstIndex(where: { $0.peerID == peerID || $0.id == displayID }) {
            sources[index] = source
        } else {
            sources.append(source)
        }
        sources.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func removeResetTrustedDisplayIfNeeded(_ source: ScoreboardRemoteDisplaySource) {
        guard
            let sourcePairingSetID = source.pairingSetID,
            let trustedDisplay = trustedDisplays.first(where: { $0.id == source.id }),
            let trustedPairingSetID = trustedDisplay.pairingSetID,
            trustedPairingSetID != sourcePairingSetID
        else {
            return
        }

        trustedDisplays.removeAll { $0.id == source.id }
        ScoreboardRemoteDisplayPairingStore.saveTrustedDisplays(trustedDisplays)
        mutedDisplayIDs.remove(source.id)
        ScoreboardRemoteDisplayPairingStore.saveMutedDisplayIDs(mutedDisplayIDs)
    }

    private func trustDisplay(
        id displayID: String,
        name displayName: String,
        pairingSetID: String?,
        deviceType: ScoreboardRemoteDisplayDeviceType?
    ) {
        guard !displayID.isEmpty else {
            return
        }

        trustedDisplays.removeAll { $0.id == displayID }
        trustedDisplays.append(ScoreboardRemoteDisplayTrustedPeer(
            id: displayID,
            name: displayName,
            pairingSetID: pairingSetID,
            deviceType: deviceType
        ))
        trustedDisplays.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        ScoreboardRemoteDisplayPairingStore.saveTrustedDisplays(trustedDisplays)
    }

    private func updateBrowsingStatus() {
        let connectedPeers = (session?.connectedPeers ?? []).filter { !peerNamesResettingPairing.contains($0.displayName) }
        let now = Date()
        connectedDisplays = connectedPeers
            .map { peerID in
                let metrics = peerHandshakeMetricsByID[peerID.displayName]
                let ackAge = metrics?.lastAckAt.map { now.timeIntervalSince($0) }
                return ScoreboardRemoteDisplayConnection(
                    id: metrics?.displayID ?? peerID.displayName,
                    name: metrics?.displayName ?? peerID.displayName,
                    quality: Self.connectionQuality(lastAckAge: ackAge),
                    latencyMilliseconds: metrics?.latency.map { Int($0 * 1_000) },
                    lastHandshakeAgeSeconds: ackAge.map(Int.init),
                    appVersion: metrics?.appVersion,
                    deviceType: metrics?.deviceType ?? .unknown,
                    isMuted: mutedDisplayIDs.contains(metrics?.displayID ?? peerID.displayName)
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        status = .browsing(
            displayCount: sources.count,
            pairedCount: connectedPeers.count
        )
    }

    private func sendState(_ data: Data, to peers: [MCPeerID]? = nil, mode: MCSessionSendDataMode) {
        sendData(data, to: peers, mode: mode)
    }

    private func sendMuteState(to peers: [MCPeerID], displayID: String? = nil) {
        for peer in peers {
            let resolvedDisplayID = displayID ?? sourceID(for: peer)
            let message = ScoreboardRemoteDisplayControlMessage(
                kind: .setMuted,
                sequence: heartbeatSequence,
                sentAt: Date().timeIntervalSince1970,
                hostID: hostID,
                hostName: peerID?.displayName,
                displayID: resolvedDisplayID,
                displayName: nil,
                isMuted: mutedDisplayIDs.contains(resolvedDisplayID)
            )
            sendControlMessage(message, to: [peer], mode: .reliable)
        }
    }

    private func sendData(_ data: Data, to peers: [MCPeerID]? = nil, mode: MCSessionSendDataMode) {
        guard let session else {
            return
        }

        let targetPeers = peers ?? session.connectedPeers
        guard !targetPeers.isEmpty, !data.isEmpty else {
            return
        }

        do {
            try session.send(data, toPeers: targetPeers, with: mode)
        } catch {
            status = .failed(String(describing: error))
        }
    }

    private static var defaultHostName: String {
        ScoreboardRemoteDisplayDeviceName.current ?? "Smart Scoreboard Host"
    }

    private static func sanitizedPairingCode(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(pairingCodeLength))
    }

    private static func connectionQuality(lastAckAge: TimeInterval?) -> ScoreboardRemoteDisplayConnectionQuality {
        guard let lastAckAge else {
            return .connecting
        }
        if lastAckAge < 3 {
            return .live
        }
        if lastAckAge < 8 {
            return .poor
        }
        return .unresponsive
    }

    private struct PeerHandshakeMetrics {
        let displayID: String
        let displayName: String
        let lastAckAt: Date?
        let lastAckSequence: UInt64?
        let latency: TimeInterval?
        let appVersion: ScoreboardRemoteDisplayAppVersion?
        let deviceType: ScoreboardRemoteDisplayDeviceType
    }
}

extension ScoreboardRemoteDisplayHostService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor [weak self] in
            self?.handleFoundPeer(peerID, discoveryInfo: info)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor [weak self] in
            self?.handleLostPeer(peerID)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor [weak self] in
            self?.status = .failed(String(describing: error))
        }
    }
}

extension ScoreboardRemoteDisplayHostService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor [weak self] in
            self?.handlePeerStateChanged(peerID, state: state)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor [weak self] in
            guard let message = try? JSONDecoder().decode(ScoreboardRemoteDisplayControlMessage.self, from: data) else {
                return
            }
            self?.handleControlMessage(message, from: peerID)
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}

@MainActor
final class ScoreboardRemoteDisplayReceiver: NSObject, ObservableObject {
    static let shared = ScoreboardRemoteDisplayReceiver()

    @Published private(set) var status: ScoreboardRemoteDisplayReceiverStatus = .waiting
    @Published private(set) var state: ScoreboardWebAPIState?
    @Published private(set) var lastReceivedAt: Date?
    @Published private(set) var lastHeartbeatAt: Date?
    @Published private(set) var masterClockOffset: TimeInterval?
    @Published private(set) var pairingCode: String = ScoreboardRemoteDisplayReceiver.makePairingCode()
    @Published private(set) var trustedHosts: [ScoreboardRemoteDisplayTrustedPeer] = ScoreboardRemoteDisplayPairingStore.trustedHosts()
    @Published private(set) var isMuted = false

    let displayID = ScoreboardRemoteDisplayIdentity.stableID(forKey: "remoteDisplayID")

    private var peerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var activeConsumerCount = 0
    private var pairingCodeTimer: Timer?
    private var heartbeatMonitorTimer: Timer?
    private var pairingSetID = ScoreboardRemoteDisplayIdentity.stableID(forKey: "remoteDisplayPairingSetID")
    private var pairedHostID: String?
    private var pairedHostName: String?
    private var isForgettingTrustedHosts = false
    private let soundTestPlayer = BuzzerPlayer()

    func acquire(displayName: String? = nil) {
        activeConsumerCount += 1
        start(displayName: displayName)
    }

    func release() {
        activeConsumerCount = max(0, activeConsumerCount - 1)
        if activeConsumerCount == 0 {
            stopAdvertising(statusMessage: localizedRemoteDisplayString("Remote Display stopped."))
        }
    }

    func start(displayName: String? = nil) {
        guard advertiser == nil else {
            return
        }

        pairingCode = Self.makePairingCode()
        status = .waiting
        pairedHostID = nil
        pairedHostName = nil
        lastHeartbeatAt = nil
        masterClockOffset = nil

        let peerID = MCPeerID(displayName: displayName ?? Self.defaultDisplayName())
        let session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self

        self.peerID = peerID
        self.session = session
        startOrRefreshAdvertiser()
        startPairingCodeTimer()
        startHeartbeatMonitorTimer()
    }

    func stop() {
        activeConsumerCount = 0
        stopAdvertising(statusMessage: localizedRemoteDisplayString("Remote Display stopped."))
    }

    private func stopAdvertising(statusMessage: String) {
        pairingCodeTimer?.invalidate()
        pairingCodeTimer = nil
        heartbeatMonitorTimer?.invalidate()
        heartbeatMonitorTimer = nil
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil
        session?.disconnect()
        session?.delegate = nil
        session = nil
        peerID = nil
        pairedHostID = nil
        pairedHostName = nil
        lastHeartbeatAt = nil
        masterClockOffset = nil
        status = .disconnected(statusMessage)
    }

    func resetPairingCode() {
        pairingCode = Self.makePairingCode()
        startPairingCodeTimer()
    }

    func forgetTrustedHosts() {
        isForgettingTrustedHosts = true
        pairingSetID = ScoreboardRemoteDisplayIdentity.resetStableID(forKey: "remoteDisplayPairingSetID")
        notifyConnectedHostsBeforeForgetting()
        trustedHosts.removeAll()
        ScoreboardRemoteDisplayPairingStore.saveTrustedHosts(trustedHosts)
        pairedHostID = nil
        pairedHostName = nil
        lastHeartbeatAt = nil
        lastReceivedAt = nil
        masterClockOffset = nil
        state = nil
        pairingCode = Self.makePairingCode()
        isMuted = false
        soundTestPlayer.stop()
        status = .waiting
        startPairingCodeTimer()
        startOrRefreshAdvertiser()
        disconnectAfterPairingResetNotice()
    }

    private func notifyConnectedHostsBeforeForgetting() {
        let message = ScoreboardRemoteDisplayControlMessage(
            kind: .removePairing,
            sequence: 0,
            sentAt: Date().timeIntervalSince1970,
            hostID: pairedHostID,
            hostName: pairedHostName,
            displayID: displayID,
            displayName: peerID?.displayName,
            pairingSetID: pairingSetID,
            appVersion: ScoreboardRemoteDisplayAppVersion.current.version,
            appBuild: ScoreboardRemoteDisplayAppVersion.current.build,
            deviceType: ScoreboardRemoteDisplayDeviceType.current
        )
        sendControlMessage(message, mode: .reliable)
    }

    private func disconnectAfterPairingResetNotice() {
        let sessionBeingReset = session
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak sessionBeingReset] in
            guard let self, self.isForgettingTrustedHosts else {
                return
            }
            if self.session === sessionBeingReset {
                sessionBeingReset?.disconnect()
            }
            self.isForgettingTrustedHosts = false
        }
    }

    private func startPairingCodeTimer() {
        pairingCodeTimer?.invalidate()
        pairingCodeTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.rotatePairingCodeIfNeeded()
            }
        }
    }

    private func rotatePairingCodeIfNeeded() {
        guard session?.connectedPeers.isEmpty != false else {
            return
        }
        pairingCode = Self.makePairingCode()
    }

    private func startHeartbeatMonitorTimer() {
        heartbeatMonitorTimer?.invalidate()
        heartbeatMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.markStaleHostIfNeeded()
            }
        }
    }

    private func markStaleHostIfNeeded() {
        guard
            pairedHostID != nil,
            let lastHeartbeatAt,
            Date().timeIntervalSince(lastHeartbeatAt) >= 8
        else {
            return
        }

        let staleHostName = pairedHostName ?? localizedRemoteDisplayString("Remote Display host")
        pairedHostID = nil
        pairedHostName = nil
        self.lastHeartbeatAt = nil
        masterClockOffset = nil
        status = .disconnected(localizedRemoteDisplayFormat("%@ stopped responding. Waiting for reconnect.", staleHostName))
        startOrRefreshAdvertiser()
    }

    private func startOrRefreshAdvertiser() {
        guard let peerID else {
            return
        }

        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil

        var discoveryInfo = [
            "app": "Smart Scoreboard",
            "role": "display",
            "name": peerID.displayName,
            "displayID": displayID,
            "pairingSetID": pairingSetID,
            "appVersion": ScoreboardRemoteDisplayAppVersion.current.version,
            "appBuild": ScoreboardRemoteDisplayAppVersion.current.build,
            "deviceType": ScoreboardRemoteDisplayDeviceType.current.rawValue
        ]
        if let pairedHostID, let pairedHostName {
            discoveryInfo["activeHostID"] = pairedHostID
            discoveryInfo["activeHostName"] = pairedHostName
            discoveryInfo["pairedHostID"] = pairedHostID
            discoveryInfo["pairedHostName"] = pairedHostName
        }

        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: ScoreboardRemoteDisplayHostService.serviceType
        )
        advertiser.delegate = self
        self.advertiser = advertiser
        advertiser.startAdvertisingPeer()
    }

    private func handlePeerStateChanged(_ peerID: MCPeerID, state: MCSessionState) {
        switch state {
        case .connected:
            pairedHostName = peerID.displayName
            status = .paired(peerID.displayName)
            startOrRefreshAdvertiser()
        case .connecting:
            break
        case .notConnected:
            pairedHostID = nil
            pairedHostName = nil
            lastHeartbeatAt = nil
            masterClockOffset = nil
            startOrRefreshAdvertiser()
            if isForgettingTrustedHosts {
                isForgettingTrustedHosts = false
                status = .waiting
            } else if self.state == nil {
                status = .waiting
            } else {
                status = .disconnected(localizedRemoteDisplayFormat(
                    "%@ disconnected. Waiting for Remote Display to reconnect.",
                    peerID.displayName
                ))
            }
        @unknown default:
            break
        }
    }

    private func handleReceivedData(_ data: Data, from peerID: MCPeerID) {
        guard !data.isEmpty else {
            return
        }

        if let message = try? JSONDecoder().decode(ScoreboardRemoteDisplayControlMessage.self, from: data) {
            handleControlMessage(message, from: peerID)
            return
        }

        let decoder = JSONDecoder()
        guard let decodedState = try? decoder.decode(ScoreboardWebAPIState.self, from: data) else {
            status = .failed(localizedRemoteDisplayString("Received an unreadable Remote Display update."))
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            state = decodedState
            lastReceivedAt = Date()
            status = .paired(peerID.displayName)
        }
    }

    private func handleControlMessage(_ message: ScoreboardRemoteDisplayControlMessage, from peerID: MCPeerID) {
        guard !isForgettingTrustedHosts else {
            return
        }

        switch message.kind {
        case .removePairing:
            handleRemovePairing(message, from: peerID)
            return
        case .disconnect:
            handleDisconnect(message, from: peerID)
            return
        case .setMuted:
            handleSetMuted(message, from: peerID)
            return
        case .soundTest:
            handleSoundTest(message, from: peerID)
            return
        case .soundEffect:
            handleSoundEffect(message, from: peerID)
            return
        case .heartbeat:
            break
        case .heartbeatAck:
            return
        }

        let receivedAt = Date()
        lastHeartbeatAt = receivedAt
        updateMasterClockOffset(from: message, receivedAt: receivedAt)
        let previousHostID = pairedHostID
        let previousHostName = pairedHostName
        pairedHostID = message.hostID
        pairedHostName = message.hostName ?? peerID.displayName
        if let hostID = message.hostID {
            trustHost(id: hostID, name: pairedHostName ?? peerID.displayName)
        }
        status = .paired(pairedHostName ?? peerID.displayName)
        if previousHostID != pairedHostID || previousHostName != pairedHostName {
            startOrRefreshAdvertiser()
        }

        let response = ScoreboardRemoteDisplayControlMessage(
            kind: .heartbeatAck,
            sequence: message.sequence,
            sentAt: message.sentAt,
            hostID: message.hostID,
            hostName: message.hostName,
            displayID: displayID,
            displayName: self.peerID?.displayName,
            appVersion: ScoreboardRemoteDisplayAppVersion.current.version,
            appBuild: ScoreboardRemoteDisplayAppVersion.current.build,
            deviceType: ScoreboardRemoteDisplayDeviceType.current
        )
        sendControlMessage(response, to: [peerID], mode: .unreliable)
    }

    private func handleDisconnect(_ message: ScoreboardRemoteDisplayControlMessage, from peerID: MCPeerID) {
        guard acceptsControlMessage(message, from: peerID) else {
            return
        }

        let hostName = message.hostName ?? pairedHostName ?? peerID.displayName
        pairedHostID = nil
        pairedHostName = nil
        lastHeartbeatAt = nil
        masterClockOffset = nil
        status = .disconnected(localizedRemoteDisplayFormat("%@ disconnected this Remote Display.", hostName))
        session?.disconnect()
        startOrRefreshAdvertiser()
    }

    private func handleSetMuted(_ message: ScoreboardRemoteDisplayControlMessage, from peerID: MCPeerID) {
        guard acceptsControlMessage(message, from: peerID) else {
            return
        }

        isMuted = message.isMuted ?? false
        if isMuted {
            soundTestPlayer.stop()
        }
    }

    private func handleSoundTest(_ message: ScoreboardRemoteDisplayControlMessage, from peerID: MCPeerID) {
        guard acceptsControlMessage(message, from: peerID), !isMuted else {
            return
        }

        soundTestPlayer.play(.whistle)
    }

    private func handleSoundEffect(_ message: ScoreboardRemoteDisplayControlMessage, from peerID: MCPeerID) {
        guard
            acceptsControlMessage(message, from: peerID),
            !isMuted,
            let rawEffect = message.soundEffect,
            let effect = ScoreboardSoundEffect(rawValue: rawEffect),
            effect != .none
        else {
            return
        }

        soundTestPlayer.play(effect)
    }

    private func acceptsControlMessage(_ message: ScoreboardRemoteDisplayControlMessage, from peerID: MCPeerID) -> Bool {
        let isTrustedSender = message.hostID.map { hostID in
            trustedHosts.contains { $0.id == hostID }
        } ?? false
        let isCurrentHost = message.hostID == nil || message.hostID == pairedHostID || isTrustedSender
        let isThisDisplay = message.displayID == nil || message.displayID == displayID
        return isCurrentHost && isThisDisplay
    }

    private func handleRemovePairing(_ message: ScoreboardRemoteDisplayControlMessage, from peerID: MCPeerID) {
        let isTrustedSender = message.hostID.map { hostID in
            trustedHosts.contains { $0.id == hostID }
        } ?? false

        guard
            message.hostID == nil
                || message.hostID == pairedHostID
                || isTrustedSender
        else {
            return
        }

        if let hostID = message.hostID {
            trustedHosts.removeAll { $0.id == hostID }
            ScoreboardRemoteDisplayPairingStore.saveTrustedHosts(trustedHosts)
        }
        pairedHostID = nil
        pairedHostName = nil
        lastHeartbeatAt = nil
        lastReceivedAt = nil
        masterClockOffset = nil
        state = nil
        isMuted = false
        soundTestPlayer.stop()
        status = .disconnected(localizedRemoteDisplayFormat(
            "%@ removed this display. Pair again to reconnect.",
            message.hostName ?? peerID.displayName
        ))
        session?.disconnect()
        pairingCode = Self.makePairingCode()
        startPairingCodeTimer()
        startOrRefreshAdvertiser()
    }

    private func sendControlMessage(
        _ message: ScoreboardRemoteDisplayControlMessage,
        to peers: [MCPeerID]? = nil,
        mode: MCSessionSendDataMode
    ) {
        guard let session, let data = try? JSONEncoder().encode(message) else {
            return
        }
        let targetPeers = peers ?? session.connectedPeers
        guard !targetPeers.isEmpty else {
            return
        }
        try? session.send(data, toPeers: targetPeers, with: mode)
    }

    private func updateMasterClockOffset(
        from message: ScoreboardRemoteDisplayControlMessage,
        receivedAt: Date
    ) {
        let measuredOffset = message.sentAt - receivedAt.timeIntervalSince1970
        guard measuredOffset.isFinite else {
            return
        }

        if let currentOffset = masterClockOffset {
            masterClockOffset = (currentOffset * 0.8) + (measuredOffset * 0.2)
        } else {
            masterClockOffset = measuredOffset
        }
    }

    private static func defaultDisplayName() -> String {
        ScoreboardRemoteDisplayDeviceName.current ?? "\(Self.appDisplayName) Display"
    }

    private static func makePairingCode() -> String {
        String(format: "%04d", Int.random(in: 0...9999))
    }

    private static var appDisplayName: String {
        "Smart Scoreboard"
    }

    private func trustHost(id hostID: String, name hostName: String) {
        guard !hostID.isEmpty else {
            return
        }

        trustedHosts.removeAll { $0.id == hostID }
        trustedHosts.append(ScoreboardRemoteDisplayTrustedPeer(id: hostID, name: hostName))
        trustedHosts.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        ScoreboardRemoteDisplayPairingStore.saveTrustedHosts(trustedHosts)
    }
}

extension ScoreboardRemoteDisplayReceiver: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self, let session = self.session else {
                invitationHandler(false, nil)
                return
            }

            let request = self.pairingRequest(from: context)
            let receivedCode = request?.pairingCode ?? context.flatMap { String(data: $0, encoding: .utf8) }
            let requesterHostID = request?.hostID
            let isAlreadyPairedByOtherHost = self.pairedHostID != nil
                && requesterHostID != self.pairedHostID
            let isDisplayMatch = request?.displayID == nil || request?.displayID == self.displayID
            let isTrustedHost = requesterHostID.map { hostID in
                self.trustedHosts.contains { $0.id == hostID }
            } ?? false
            let isTrustedReconnect = request?.trustedReconnect == true
                && isDisplayMatch
                && isTrustedHost
            let isCodePairing = isDisplayMatch && receivedCode == self.pairingCode

            guard (isCodePairing || isTrustedReconnect), !isAlreadyPairedByOtherHost else {
                invitationHandler(false, nil)
                return
            }

            self.pairedHostID = requesterHostID
            self.pairedHostName = request?.hostName ?? peerID.displayName
            if let requesterHostID {
                self.trustHost(id: requesterHostID, name: self.pairedHostName ?? peerID.displayName)
            }
            if isCodePairing {
                self.pairingCode = Self.makePairingCode()
            }
            self.startOrRefreshAdvertiser()
            invitationHandler(true, session)
        }
    }

    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.status = .failed(String(describing: error))
        }
    }
}

private extension ScoreboardRemoteDisplayReceiver {
    func pairingRequest(from context: Data?) -> ScoreboardRemoteDisplayPairingRequest? {
        guard let context else {
            return nil
        }
        return try? JSONDecoder().decode(ScoreboardRemoteDisplayPairingRequest.self, from: context)
    }
}

extension ScoreboardRemoteDisplayReceiver: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor [weak self] in
            self?.handlePeerStateChanged(peerID, state: state)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor [weak self] in
            self?.handleReceivedData(data, from: peerID)
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}
