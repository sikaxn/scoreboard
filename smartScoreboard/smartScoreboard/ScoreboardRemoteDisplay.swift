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
            return "Found \(displayCount) display\(displayCount == 1 ? "" : "s"), \(pairedCount) connected."
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
            return "On the operator device, open Settings > Integration > Remote Display, then enter this display's pairing code."
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

nonisolated enum ScoreboardRemoteDisplayReceiverAdvertisedState: String, Equatable, Sendable {
    case waitingUnpaired
    case waitingPaired
    case running
    case runningPairing
    case awaitingReconnect
    case disconnecting

    var allowsNewPairing: Bool {
        switch self {
        case .waitingUnpaired, .waitingPaired, .runningPairing, .awaitingReconnect, .disconnecting:
            return true
        case .running:
            return false
        }
    }

    var requiresTakeoverWarning: Bool {
        switch self {
        case .waitingPaired, .runningPairing, .awaitingReconnect, .disconnecting:
            return true
        case .waitingUnpaired, .running:
            return false
        }
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
    var receiverState: ScoreboardRemoteDisplayReceiverAdvertisedState {
        if let rawState = discoveryInfo?["receiverState"],
           let state = ScoreboardRemoteDisplayReceiverAdvertisedState(rawValue: rawState) {
            return state
        }
        if activeOperatorID != nil {
            return .running
        }
        if lastActiveOperatorID != nil {
            return .waitingPaired
        }
        return .waitingUnpaired
    }
    var activeOperatorID: String? { discoveryInfo?["activeOperatorID"] ?? discoveryInfo?["activeHostID"] }
    var activeOperatorName: String? { discoveryInfo?["activeOperatorName"] ?? discoveryInfo?["activeHostName"] }
    var lastActiveOperatorID: String? {
        discoveryInfo?["lastActiveOperatorID"]
            ?? discoveryInfo?["pairedOperatorID"]
            ?? discoveryInfo?["pairedHostID"]
    }
    var lastActiveOperatorName: String? {
        discoveryInfo?["lastActiveOperatorName"]
            ?? discoveryInfo?["pairedOperatorName"]
            ?? discoveryInfo?["pairedHostName"]
    }
    var activeHostID: String? { activeOperatorID }
    var activeHostName: String? { activeOperatorName }
    var pairedHostID: String? { lastActiveOperatorID }
    var pairedHostName: String? { lastActiveOperatorName }
    var pairingSetID: String? { discoveryInfo?["pairingSetID"] }
    var allowsNewPairing: Bool {
        if let rawValue = discoveryInfo?["allowsNewPairing"] {
            return rawValue == "true"
        }
        return receiverState.allowsNewPairing
    }
    var requiresTakeoverWarning: Bool {
        if let rawValue = discoveryInfo?["requiresTakeoverWarning"] {
            return rawValue == "true"
        }
        return receiverState.requiresTakeoverWarning
    }

    func isInUseByOtherBoard(currentHostID: String) -> Bool {
        isInUseByOtherOperator(currentOperatorID: currentHostID)
    }

    func isInUseByOtherOperator(currentOperatorID: String) -> Bool {
        guard receiverState == .running, let activeOperatorID, !activeOperatorID.isEmpty else {
            return false
        }
        return activeOperatorID != currentOperatorID
    }

    func needsTakeoverConfirmation(currentOperatorID: String) -> Bool {
        guard allowsNewPairing, requiresTakeoverWarning else {
            return false
        }
        if let activeOperatorID, activeOperatorID == currentOperatorID {
            return false
        }
        if let lastActiveOperatorID, lastActiveOperatorID == currentOperatorID {
            return false
        }
        return true
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

nonisolated struct ScoreboardRemoteDisplayDisconnectNotice: Identifiable, Equatable, Sendable {
    let sequence: UInt64
    let displayID: String
    let displayName: String

    var id: String { "\(displayID)-\(sequence)" }
}

nonisolated struct ScoreboardRemoteDisplayPairingRequest: Codable, Sendable {
    let pairingCode: String?
    let hostID: String
    let hostName: String
    let displayID: String?
    let trustedReconnect: Bool
    let takeoverConfirmed: Bool

    init(
        pairingCode: String?,
        hostID: String,
        hostName: String,
        displayID: String?,
        trustedReconnect: Bool,
        takeoverConfirmed: Bool
    ) {
        self.pairingCode = pairingCode
        self.hostID = hostID
        self.hostName = hostName
        self.displayID = displayID
        self.trustedReconnect = trustedReconnect
        self.takeoverConfirmed = takeoverConfirmed
    }

    private enum CodingKeys: String, CodingKey {
        case pairingCode
        case hostID
        case hostName
        case displayID
        case trustedReconnect
        case takeoverConfirmed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pairingCode = try container.decodeIfPresent(String.self, forKey: .pairingCode)
        hostID = try container.decode(String.self, forKey: .hostID)
        hostName = try container.decode(String.self, forKey: .hostName)
        displayID = try container.decodeIfPresent(String.self, forKey: .displayID)
        trustedReconnect = try container.decodeIfPresent(Bool.self, forKey: .trustedReconnect) ?? false
        takeoverConfirmed = try container.decodeIfPresent(Bool.self, forKey: .takeoverConfirmed) ?? false
    }
}

nonisolated struct ScoreboardRemoteDisplayControlMessage: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case heartbeat
        case heartbeatAck
        case imageRequest
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
    let imageID: String?
    let imagePath: String?

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
        soundEffect: ScoreboardSoundEffect? = nil,
        imageID: String? = nil,
        imagePath: String? = nil
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
        self.imageID = imageID
        self.imagePath = imagePath
    }
}

nonisolated struct ScoreboardRemoteDisplayImageAsset: Equatable, Sendable {
    let id: String
    let path: String
    let mimeType: String
    let data: Data
}

private struct ScoreboardRemoteDisplayImageAssetHeader: Codable, Sendable {
    let id: String
    let path: String
    let mimeType: String
    let byteCount: Int
}

private enum ScoreboardRemoteDisplayImageAssetCodec {
    private static let magic = Data("SSRDIMG1".utf8)

    static func encode(id: String, path: String, mimeType: String, data: Data) -> Data? {
        let header = ScoreboardRemoteDisplayImageAssetHeader(
            id: id,
            path: path,
            mimeType: mimeType,
            byteCount: data.count
        )
        guard let headerData = try? JSONEncoder().encode(header) else {
            return nil
        }

        var headerLength = UInt32(headerData.count).bigEndian
        var payload = Data()
        payload.append(magic)
        withUnsafeBytes(of: &headerLength) { bytes in
            payload.append(contentsOf: bytes)
        }
        payload.append(headerData)
        payload.append(data)
        return payload
    }

    static func decode(_ payload: Data) -> ScoreboardRemoteDisplayImageAsset? {
        let minimumLength = magic.count + 4
        guard payload.count >= minimumLength, payload.prefix(magic.count) == magic else {
            return nil
        }

        let lengthStart = magic.count
        let lengthBytes = payload[lengthStart..<(lengthStart + 4)]
        let headerLength = lengthBytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let headerStart = lengthStart + 4
        let headerEnd = headerStart + Int(headerLength)
        guard headerLength > 0, payload.count >= headerEnd else {
            return nil
        }

        let headerData = payload[headerStart..<headerEnd]
        guard
            let header = try? JSONDecoder().decode(ScoreboardRemoteDisplayImageAssetHeader.self, from: Data(headerData)),
            header.byteCount >= 0
        else {
            return nil
        }

        let imageData = payload[headerEnd..<payload.endIndex]
        guard imageData.count == header.byteCount, !imageData.isEmpty else {
            return nil
        }

        return ScoreboardRemoteDisplayImageAsset(
            id: header.id,
            path: header.path,
            mimeType: header.mimeType,
            data: Data(imageData)
        )
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
    private static let lastActiveOperatorKey = "com.ironmaple.smartscoreboard.remoteDisplayLastActiveOperator"

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

    static func lastActiveOperator() -> ScoreboardRemoteDisplayTrustedPeer? {
        load(key: lastActiveOperatorKey).first
    }

    static func saveLastActiveOperator(_ peer: ScoreboardRemoteDisplayTrustedPeer?) {
        guard let peer else {
            UserDefaults.standard.removeObject(forKey: lastActiveOperatorKey)
            return
        }
        save([peer], key: lastActiveOperatorKey)
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
    @Published private(set) var displayInitiatedDisconnectNotice: ScoreboardRemoteDisplayDisconnectNotice?

    let hostID = ScoreboardRemoteDisplayIdentity.stableID(forKey: "remoteDisplayHostID")

    private let localDisplayID = ScoreboardRemoteDisplayIdentity.stableID(forKey: "remoteDisplayID")
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
    private var currentImageResponsesProvider: (() -> [String: ScoreboardWebAPIImageResponse])?
    private var lastPeriodicStateSyncAt: Date?
    private var peerNamesResettingPairing = Set<String>()
    private var operatorDisconnectedDisplayIDs = Set<String>()
    private var displayInitiatedDisconnectSequence: UInt64 = 0

    func start(
        initialState: Data,
        displayName: String,
        currentStateProvider: (() -> Data)? = nil,
        currentImageResponsesProvider: (() -> [String: ScoreboardWebAPIImageResponse])? = nil
    ) {
        stop()
        self.currentStateProvider = currentStateProvider
        self.currentImageResponsesProvider = currentImageResponsesProvider
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
        currentImageResponsesProvider = nil
        lastPeriodicStateSyncAt = nil
        peerNamesResettingPairing.removeAll()
        operatorDisconnectedDisplayIDs.removeAll()
        displayInitiatedDisconnectNotice = nil
        displayInitiatedDisconnectSequence = 0
        status = .off
    }

    func pair(
        with source: ScoreboardRemoteDisplaySource,
        pairingCode: String,
        takeoverConfirmed: Bool = false
    ) {
        guard let browser, let session else {
            status = .failed(localizedRemoteDisplayString("Remote Display pairing is not running."))
            return
        }

        guard !source.isInUseByOtherOperator(currentOperatorID: hostID) else {
            status = .failed(localizedRemoteDisplayFormat(
                "%@ is in use by %@.",
                source.name,
                source.activeOperatorName ?? localizedRemoteDisplayString("another operator device")
            ))
            return
        }

        guard !source.needsTakeoverConfirmation(currentOperatorID: hostID) || takeoverConfirmed else {
            status = .failed(localizedRemoteDisplayFormat(
                "Confirm before replacing %@ on %@.",
                source.activeOperatorName ?? source.lastActiveOperatorName ?? localizedRemoteDisplayString("another operator device"),
                source.name
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

        operatorDisconnectedDisplayIDs.remove(source.id)
        invitedPeerIDs.insert(source.id)
        let request = ScoreboardRemoteDisplayPairingRequest(
            pairingCode: sanitizedCode,
            hostID: hostID,
            hostName: peerID?.displayName ?? Self.defaultHostName,
            displayID: source.id,
            trustedReconnect: false,
            takeoverConfirmed: takeoverConfirmed
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

    func connectTrustedDisplay(
        _ source: ScoreboardRemoteDisplaySource,
        takeoverConfirmed: Bool = false
    ) {
        guard !source.isInUseByOtherOperator(currentOperatorID: hostID) else {
            status = .failed(localizedRemoteDisplayFormat(
                "%@ is in use by %@.",
                source.name,
                source.activeOperatorName ?? localizedRemoteDisplayString("another operator device")
            ))
            return
        }

        guard isTrustedDisplay(source) else {
            status = .failed(localizedRemoteDisplayFormat("%@ needs a new pairing code.", source.name))
            return
        }

        guard !source.needsTakeoverConfirmation(currentOperatorID: hostID) || takeoverConfirmed else {
            status = .failed(localizedRemoteDisplayFormat(
                "Confirm before replacing %@ on %@.",
                source.activeOperatorName ?? source.lastActiveOperatorName ?? localizedRemoteDisplayString("another operator device"),
                source.name
            ))
            return
        }

        operatorDisconnectedDisplayIDs.remove(source.id)
        inviteTrustedDisplayIfNeeded(source, force: true, takeoverConfirmed: takeoverConfirmed)
    }

    func removeTrustedDisplay(id displayID: String) {
        trustedDisplays.removeAll { $0.id == displayID }
        ScoreboardRemoteDisplayPairingStore.saveTrustedDisplays(trustedDisplays)
        mutedDisplayIDs.remove(displayID)
        ScoreboardRemoteDisplayPairingStore.saveMutedDisplayIDs(mutedDisplayIDs)
        operatorDisconnectedDisplayIDs.remove(displayID)

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

        operatorDisconnectedDisplayIDs.insert(displayID)
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

    private func inviteTrustedDisplayIfNeeded(
        _ source: ScoreboardRemoteDisplaySource,
        force: Bool = false,
        takeoverConfirmed: Bool = false
    ) {
        guard let browser, let session else {
            status = .failed(localizedRemoteDisplayString("Remote Display pairing is not running."))
            return
        }
        guard isTrustedDisplay(source), !source.isInUseByOtherOperator(currentOperatorID: hostID) else {
            return
        }
        guard !source.needsTakeoverConfirmation(currentOperatorID: hostID) || takeoverConfirmed else {
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
            trustedReconnect: true,
            takeoverConfirmed: takeoverConfirmed
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

        operatorDisconnectedDisplayIDs.formUnion(connectedDisplays.map(\.id))
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
        if message.kind == .disconnect {
            handleDisplayInitiatedDisconnect(message, from: peerID)
            return
        }
        if message.kind == .imageRequest {
            handleImageRequest(message, from: peerID)
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

    private func handleImageRequest(_ message: ScoreboardRemoteDisplayControlMessage, from peerID: MCPeerID) {
        guard
            message.hostID == nil || message.hostID == hostID,
            let session,
            session.connectedPeers.contains(peerID),
            let imageID = message.imageID,
            !imageID.isEmpty,
            let imagePath = message.imagePath,
            !imagePath.isEmpty,
            let imageResponse = currentImageResponsesProvider?()[imagePath],
            let payload = ScoreboardRemoteDisplayImageAssetCodec.encode(
                id: imageID,
                path: imagePath,
                mimeType: imageResponse.contentType,
                data: imageResponse.body
            )
        else {
            return
        }

        sendData(payload, to: [peerID], mode: .reliable)
    }

    private func handleDisplayInitiatedDisconnect(_ message: ScoreboardRemoteDisplayControlMessage, from peerID: MCPeerID) {
        let displayID = message.displayID
            ?? peerHandshakeMetricsByID[peerID.displayName]?.displayID
            ?? sourceID(for: peerID)
        let displayName = message.displayName
            ?? peerHandshakeMetricsByID[peerID.displayName]?.displayName
            ?? peerID.displayName

        operatorDisconnectedDisplayIDs.insert(displayID)
        displayInitiatedDisconnectSequence &+= 1
        displayInitiatedDisconnectNotice = ScoreboardRemoteDisplayDisconnectNotice(
            sequence: displayInitiatedDisconnectSequence,
            displayID: displayID,
            displayName: displayName
        )
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
        guard !isLocalReceiverAdvertisement(discoveryInfo: discoveryInfo) else {
            removeLocalReceiverSource(peerID: peerID, discoveryInfo: discoveryInfo)
            return
        }

        let source = ScoreboardRemoteDisplaySource(peerID: peerID, discoveryInfo: discoveryInfo)
        removeResetTrustedDisplayIfNeeded(source)
        if let existingIndex = sources.firstIndex(where: { $0.id == source.id || $0.peerID == peerID }) {
            sources[existingIndex] = source
        } else {
            sources.append(source)
        }
        sources.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        updateBrowsingStatus()
        autoReconnectTrustedDisplayIfNeeded(source)
    }

    private func isLocalReceiverAdvertisement(discoveryInfo: [String: String]?) -> Bool {
        guard discoveryInfo?["role"] == "display" else {
            return false
        }
        return discoveryInfo?["displayID"] == localDisplayID
    }

    private func removeLocalReceiverSource(peerID: MCPeerID, discoveryInfo: [String: String]?) {
        let displayID = discoveryInfo?["displayID"] ?? localDisplayID
        sources.removeAll { $0.peerID == peerID || $0.id == displayID }
        invitedPeerIDs.remove(displayID)
        invitedPeerIDs.remove(peerID.displayName)
        pendingTrustedDisplaysByPeerName.removeValue(forKey: peerID.displayName)
        lastTrustedInviteAttemptByID.removeValue(forKey: displayID)
        peerHandshakeMetricsByID.removeValue(forKey: peerID.displayName)
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

    private func autoReconnectTrustedDisplayIfNeeded(_ source: ScoreboardRemoteDisplaySource) {
        guard
            isTrustedDisplay(source),
            source.lastActiveOperatorID == hostID,
            !source.isInUseByOtherOperator(currentOperatorID: hostID),
            !source.needsTakeoverConfirmation(currentOperatorID: hostID),
            !operatorDisconnectedDisplayIDs.contains(source.id)
        else {
            return
        }

        inviteTrustedDisplayIfNeeded(source)
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
        discoveryInfo.removeValue(forKey: "activeOperatorID")
        discoveryInfo.removeValue(forKey: "activeOperatorName")
        discoveryInfo.removeValue(forKey: "lastActiveOperatorID")
        discoveryInfo.removeValue(forKey: "lastActiveOperatorName")
        discoveryInfo["receiverState"] = ScoreboardRemoteDisplayReceiverAdvertisedState.waitingUnpaired.rawValue
        discoveryInfo["allowsNewPairing"] = "true"
        discoveryInfo["requiresTakeoverWarning"] = "false"

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
        ScoreboardRemoteDisplayDeviceName.current ?? "Smart Scoreboard Operator"
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
    @Published private(set) var imageAssetsByID: [String: ScoreboardRemoteDisplayImageAsset] = [:]

    let displayID = ScoreboardRemoteDisplayIdentity.stableID(forKey: "remoteDisplayID")

    var canDisconnectFromOperator: Bool {
        pairedHostID != nil || lastActiveOperatorID != nil
    }

    func imageData(for id: String?) -> Data? {
        guard let id else {
            return nil
        }
        return imageAssetsByID[id]?.data
    }

    private var peerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var activeConsumerCount = 0
    private var pairingCodeTimer: Timer?
    private var heartbeatMonitorTimer: Timer?
    private var pairingSetID = ScoreboardRemoteDisplayIdentity.stableID(forKey: "remoteDisplayPairingSetID")
    private var pairedHostID: String?
    private var pairedHostName: String?
    private var pairedPeerName: String?
    private var lastActiveOperatorID: String?
    private var lastActiveOperatorName: String?
    private var isPairingScreenVisible = false
    private var isDisconnectingFromOperator = false
    private var isForgettingTrustedHosts = false
    private var requestedImageAssetIDs = Set<String>()
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
        let lastActiveOperator = ScoreboardRemoteDisplayPairingStore.lastActiveOperator()
        lastActiveOperatorID = lastActiveOperator?.id
        lastActiveOperatorName = lastActiveOperator?.name
        status = lastActiveOperator.map {
            .disconnected(localizedRemoteDisplayFormat("Waiting for %@ to reconnect.", $0.name))
        } ?? .waiting
        pairedHostID = nil
        pairedHostName = nil
        pairedPeerName = nil
        isDisconnectingFromOperator = false
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
        pairedPeerName = nil
        isDisconnectingFromOperator = false
        lastHeartbeatAt = nil
        masterClockOffset = nil
        imageAssetsByID.removeAll()
        requestedImageAssetIDs.removeAll()
        status = .disconnected(statusMessage)
    }

    func setPairingScreenVisible(_ isVisible: Bool) {
        guard isPairingScreenVisible != isVisible else {
            return
        }
        isPairingScreenVisible = isVisible
        startOrRefreshAdvertiser()
    }

    func resetPairingCode() {
        pairingCode = Self.makePairingCode()
        startPairingCodeTimer()
    }

    func disconnectFromOperator() {
        let operatorName = pairedHostName ?? lastActiveOperatorName ?? localizedRemoteDisplayString("operator device")
        let message = ScoreboardRemoteDisplayControlMessage(
            kind: .disconnect,
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

        pairedHostID = nil
        pairedHostName = nil
        pairedPeerName = nil
        isDisconnectingFromOperator = true
        lastHeartbeatAt = nil
        masterClockOffset = nil
        status = .disconnected(localizedRemoteDisplayFormat("Disconnected from %@.", operatorName))
        startOrRefreshAdvertiser()

        let sessionToDisconnect = session
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak sessionToDisconnect] in
            sessionToDisconnect?.disconnect()
        }
    }

    func forgetTrustedHosts() {
        isForgettingTrustedHosts = true
        pairingSetID = ScoreboardRemoteDisplayIdentity.resetStableID(forKey: "remoteDisplayPairingSetID")
        notifyConnectedHostsBeforeForgetting()
        trustedHosts.removeAll()
        ScoreboardRemoteDisplayPairingStore.saveTrustedHosts(trustedHosts)
        ScoreboardRemoteDisplayPairingStore.saveLastActiveOperator(nil)
        pairedHostID = nil
        pairedHostName = nil
        pairedPeerName = nil
        lastActiveOperatorID = nil
        lastActiveOperatorName = nil
        isDisconnectingFromOperator = false
        lastHeartbeatAt = nil
        lastReceivedAt = nil
        masterClockOffset = nil
        state = nil
        pairingCode = Self.makePairingCode()
        isMuted = false
        imageAssetsByID.removeAll()
        requestedImageAssetIDs.removeAll()
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

        let staleHostName = pairedHostName ?? lastActiveOperatorName ?? localizedRemoteDisplayString("operator device")
        pairedHostID = nil
        pairedHostName = nil
        pairedPeerName = nil
        isDisconnectingFromOperator = false
        self.lastHeartbeatAt = nil
        masterClockOffset = nil
        status = .disconnected(localizedRemoteDisplayFormat("%@ stopped responding. Waiting for reconnect.", staleHostName))
        startOrRefreshAdvertiser()
    }

    private var advertisedState: ScoreboardRemoteDisplayReceiverAdvertisedState {
        if pairedHostID != nil {
            return isPairingScreenVisible ? .runningPairing : .running
        }
        if isDisconnectingFromOperator, lastActiveOperatorID != nil {
            return .disconnecting
        }
        if state != nil, lastActiveOperatorID != nil {
            return .awaitingReconnect
        }
        if lastActiveOperatorID != nil || !trustedHosts.isEmpty {
            return .waitingPaired
        }
        return .waitingUnpaired
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
        let currentAdvertisedState = advertisedState
        discoveryInfo["receiverState"] = currentAdvertisedState.rawValue
        discoveryInfo["allowsNewPairing"] = currentAdvertisedState.allowsNewPairing ? "true" : "false"
        discoveryInfo["requiresTakeoverWarning"] = currentAdvertisedState.requiresTakeoverWarning ? "true" : "false"
        if let pairedHostID, let pairedHostName {
            discoveryInfo["activeOperatorID"] = pairedHostID
            discoveryInfo["activeOperatorName"] = pairedHostName
            discoveryInfo["activeHostID"] = pairedHostID
            discoveryInfo["activeHostName"] = pairedHostName
        }
        if let lastActiveOperatorID, let lastActiveOperatorName {
            discoveryInfo["lastActiveOperatorID"] = lastActiveOperatorID
            discoveryInfo["lastActiveOperatorName"] = lastActiveOperatorName
            discoveryInfo["pairedOperatorID"] = lastActiveOperatorID
            discoveryInfo["pairedOperatorName"] = lastActiveOperatorName
            discoveryInfo["pairedHostID"] = lastActiveOperatorID
            discoveryInfo["pairedHostName"] = lastActiveOperatorName
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
            pairedPeerName = peerID.displayName
            pairedHostName = peerID.displayName
            if let pairedHostID {
                setLastActiveOperator(id: pairedHostID, name: pairedHostName ?? peerID.displayName)
            }
            isDisconnectingFromOperator = false
            status = .paired(peerID.displayName)
            startOrRefreshAdvertiser()
        case .connecting:
            break
        case .notConnected:
            let previousHostName = pairedHostName ?? lastActiveOperatorName ?? peerID.displayName
            pairedHostID = nil
            pairedHostName = nil
            pairedPeerName = nil
            lastHeartbeatAt = nil
            masterClockOffset = nil
            startOrRefreshAdvertiser()
            if isForgettingTrustedHosts {
                isForgettingTrustedHosts = false
                status = .waiting
            } else if self.state == nil {
                status = lastActiveOperatorName.map {
                    .disconnected(localizedRemoteDisplayFormat("Waiting for %@ to reconnect.", $0))
                } ?? .waiting
            } else {
                status = .disconnected(localizedRemoteDisplayFormat(
                    "%@ disconnected. Waiting for reconnect.",
                    previousHostName
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

        if let imageAsset = ScoreboardRemoteDisplayImageAssetCodec.decode(data) {
            handleImageAsset(imageAsset)
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

        guard acceptsStateUpdate(from: peerID) else {
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            state = decodedState
            lastReceivedAt = Date()
            status = .paired(peerID.displayName)
        }
        requestMissingImagesIfNeeded(for: decodedState, from: peerID)
    }

    private func handleImageAsset(_ asset: ScoreboardRemoteDisplayImageAsset) {
        guard !asset.id.isEmpty, !asset.data.isEmpty else {
            return
        }

        imageAssetsByID[asset.id] = asset
        requestedImageAssetIDs.remove(asset.id)
    }

    private func requestMissingImagesIfNeeded(for state: ScoreboardWebAPIState, from peerID: MCPeerID) {
        if state.display?.backgroundMode == .image, let image = state.display?.backgroundImage {
            requestImageIfNeeded(id: image.id, path: image.path, from: peerID)
        }

        let viewMode = state.display?.resolvedViewMode ?? .scoreboard
        if (viewMode == .scoreboard || viewMode == .eventLogo), let logo = state.display?.eventLogo {
            requestImageIfNeeded(id: logo.id, path: logo.path, from: peerID)
        }

        guard state.display?.showsTeamLogos ?? true else {
            return
        }

        if let logo = state.teams.home.logo {
            requestImageIfNeeded(id: logo.id, path: logo.path, from: peerID)
        }
        if let logo = state.teams.guest.logo {
            requestImageIfNeeded(id: logo.id, path: logo.path, from: peerID)
        }
    }

    private func requestImageIfNeeded(id: String, path: String, from peerID: MCPeerID) {
        guard !id.isEmpty, !path.isEmpty, imageAssetsByID[id] == nil, !requestedImageAssetIDs.contains(id) else {
            return
        }

        requestedImageAssetIDs.insert(id)
        let message = ScoreboardRemoteDisplayControlMessage(
            kind: .imageRequest,
            sequence: 0,
            sentAt: Date().timeIntervalSince1970,
            hostID: pairedHostID,
            hostName: pairedHostName,
            displayID: displayID,
            displayName: self.peerID?.displayName,
            imageID: id,
            imagePath: path
        )
        sendControlMessage(message, to: [peerID], mode: .reliable)
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
        case .imageRequest:
            return
        case .heartbeat:
            break
        case .heartbeatAck:
            return
        }

        guard acceptsHeartbeat(message, from: peerID) else {
            return
        }

        let receivedAt = Date()
        lastHeartbeatAt = receivedAt
        updateMasterClockOffset(from: message, receivedAt: receivedAt)
        let previousHostID = pairedHostID
        let previousHostName = pairedHostName
        pairedHostID = message.hostID
        pairedHostName = message.hostName ?? peerID.displayName
        pairedPeerName = peerID.displayName
        if let hostID = message.hostID {
            let hostName = pairedHostName ?? peerID.displayName
            trustHost(id: hostID, name: hostName)
            setLastActiveOperator(id: hostID, name: hostName)
        }
        isDisconnectingFromOperator = false
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
        pairedPeerName = nil
        isDisconnectingFromOperator = true
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
        let isCurrentHost = message.hostID == nil || message.hostID == pairedHostID
        let isCurrentPeer = pairedPeerName == nil || pairedPeerName == peerID.displayName
        let isThisDisplay = message.displayID == nil || message.displayID == displayID
        return isCurrentHost && isCurrentPeer && isThisDisplay
    }

    private func acceptsHeartbeat(_ message: ScoreboardRemoteDisplayControlMessage, from peerID: MCPeerID) -> Bool {
        let isThisDisplay = message.displayID == nil || message.displayID == displayID
        guard isThisDisplay else {
            return false
        }
        guard let hostID = message.hostID else {
            return pairedHostID == nil || pairedHostName == peerID.displayName
        }
        if let pairedHostID {
            return hostID == pairedHostID && (pairedPeerName == nil || pairedPeerName == peerID.displayName)
        }
        if let lastActiveOperatorID {
            return hostID == lastActiveOperatorID && trustedHosts.contains { $0.id == hostID }
        }
        return trustedHosts.contains { $0.id == hostID }
    }

    private func acceptsStateUpdate(from peerID: MCPeerID) -> Bool {
        guard pairedHostID != nil else {
            return false
        }
        return pairedPeerName == peerID.displayName && session?.connectedPeers.contains(peerID) == true
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
        pairedPeerName = nil
        if message.hostID == lastActiveOperatorID {
            lastActiveOperatorID = nil
            lastActiveOperatorName = nil
            ScoreboardRemoteDisplayPairingStore.saveLastActiveOperator(nil)
        }
        isDisconnectingFromOperator = false
        lastHeartbeatAt = nil
        lastReceivedAt = nil
        masterClockOffset = nil
        state = nil
        isMuted = false
        imageAssetsByID.removeAll()
        requestedImageAssetIDs.removeAll()
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

    private func setLastActiveOperator(id operatorID: String, name operatorName: String) {
        guard !operatorID.isEmpty else {
            return
        }

        lastActiveOperatorID = operatorID
        lastActiveOperatorName = operatorName
        ScoreboardRemoteDisplayPairingStore.saveLastActiveOperator(
            ScoreboardRemoteDisplayTrustedPeer(id: operatorID, name: operatorName)
        )
    }

    private func canAcceptTrustedReconnect(
        receiverState: ScoreboardRemoteDisplayReceiverAdvertisedState,
        isDisplayMatch: Bool,
        isTrustedHost: Bool,
        isCurrentOperator: Bool,
        isLastActiveOperator: Bool,
        hasTakeoverConfirmation: Bool
    ) -> Bool {
        guard isDisplayMatch, isTrustedHost else {
            return false
        }
        switch receiverState {
        case .running:
            return isCurrentOperator
        case .runningPairing:
            return isCurrentOperator || hasTakeoverConfirmation
        case .waitingUnpaired:
            return true
        case .waitingPaired, .awaitingReconnect, .disconnecting:
            return isLastActiveOperator || hasTakeoverConfirmation
        }
    }

    private func canAcceptCodePairing(
        receiverState: ScoreboardRemoteDisplayReceiverAdvertisedState,
        isCodePairing: Bool,
        isCurrentOperator: Bool,
        isLastActiveOperator: Bool,
        hasTakeoverConfirmation: Bool
    ) -> Bool {
        guard isCodePairing else {
            return false
        }
        switch receiverState {
        case .running:
            return isCurrentOperator
        case .runningPairing:
            return isCurrentOperator || hasTakeoverConfirmation
        case .waitingUnpaired:
            return true
        case .waitingPaired, .awaitingReconnect, .disconnecting:
            return isLastActiveOperator || hasTakeoverConfirmation
        }
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
            let isDisplayMatch = request?.displayID == nil || request?.displayID == self.displayID
            let isTrustedHost = requesterHostID.map { hostID in
                self.trustedHosts.contains { $0.id == hostID }
            } ?? false
            let receiverState = self.advertisedState
            let isCurrentOperator = requesterHostID == self.pairedHostID
            let isLastActiveOperator = requesterHostID == self.lastActiveOperatorID
            let hasTakeoverConfirmation = request?.takeoverConfirmed == true
            let isTrustedReconnect = self.canAcceptTrustedReconnect(
                receiverState: receiverState,
                isDisplayMatch: isDisplayMatch,
                isTrustedHost: isTrustedHost,
                isCurrentOperator: isCurrentOperator,
                isLastActiveOperator: isLastActiveOperator,
                hasTakeoverConfirmation: hasTakeoverConfirmation
            )
            let isCodePairing = isDisplayMatch && receivedCode == self.pairingCode
            let canAcceptCodePairing = self.canAcceptCodePairing(
                receiverState: receiverState,
                isCodePairing: isCodePairing,
                isCurrentOperator: isCurrentOperator,
                isLastActiveOperator: isLastActiveOperator,
                hasTakeoverConfirmation: hasTakeoverConfirmation
            )

            guard canAcceptCodePairing || isTrustedReconnect else {
                invitationHandler(false, nil)
                return
            }

            self.pairedHostID = requesterHostID
            self.pairedHostName = request?.hostName ?? peerID.displayName
            self.pairedPeerName = peerID.displayName
            self.isDisconnectingFromOperator = false
            if let requesterHostID {
                let hostName = self.pairedHostName ?? peerID.displayName
                self.trustHost(id: requesterHostID, name: hostName)
                self.setLastActiveOperator(id: requesterHostID, name: hostName)
            }
            if canAcceptCodePairing {
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
