import Combine
import Foundation
import SwiftUI
import Network
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

nonisolated enum ScoreboardRemoteDisplayNetworkMode: String, CaseIterable, Codable, Identifiable, Equatable, Sendable {
    case localNetworkOnly
    case nearbyAndLocalNetwork

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localNetworkOnly:
            return "Same Wi-Fi / LAN"
        case .nearbyAndLocalNetwork:
            return "Nearby + LAN"
        }
    }

    var detail: String {
        switch self {
        case .localNetworkOnly:
            return "Requires the operator and Remote Display devices to be on the same local network."
        case .nearbyAndLocalNetwork:
            return "Uses the local network and also allows Apple peer-to-peer Wi-Fi for nearby devices."
        }
    }

    var includesPeerToPeer: Bool {
        self == .nearbyAndLocalNetwork
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
    let endpoint: NWEndpoint
    let discoveryInfo: [String: String]?

    var displayID: String? {
        guard let displayID = discoveryInfo?["displayID"]?.trimmingCharacters(in: .whitespacesAndNewlines), !displayID.isEmpty else {
            return nil
        }
        return displayID
    }
    var id: String { displayID ?? "endpoint-\(endpoint.debugDescription)" }
    var name: String { discoveryInfo?["name"] ?? localizedRemoteDisplayString("Remote Display") }
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
    let pairingSecret: String?
    let trustedReconnect: Bool
    let takeoverConfirmed: Bool

    init(
        pairingCode: String?,
        hostID: String,
        hostName: String,
        displayID: String?,
        pairingSecret: String?,
        trustedReconnect: Bool,
        takeoverConfirmed: Bool
    ) {
        self.pairingCode = pairingCode
        self.hostID = hostID
        self.hostName = hostName
        self.displayID = displayID
        self.pairingSecret = pairingSecret
        self.trustedReconnect = trustedReconnect
        self.takeoverConfirmed = takeoverConfirmed
    }

    private enum CodingKeys: String, CodingKey {
        case pairingCode
        case hostID
        case hostName
        case displayID
        case pairingSecret
        case trustedReconnect
        case takeoverConfirmed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pairingCode = try container.decodeIfPresent(String.self, forKey: .pairingCode)
        hostID = try container.decode(String.self, forKey: .hostID)
        hostName = try container.decode(String.self, forKey: .hostName)
        displayID = try container.decodeIfPresent(String.self, forKey: .displayID)
        pairingSecret = try container.decodeIfPresent(String.self, forKey: .pairingSecret)
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
    let pairingSecret: String?

    init(
        id: String,
        name: String,
        pairingSetID: String? = nil,
        deviceType: ScoreboardRemoteDisplayDeviceType? = nil,
        pairingSecret: String? = nil
    ) {
        self.id = id
        self.name = name
        self.pairingSetID = pairingSetID
        self.deviceType = deviceType
        self.pairingSecret = pairingSecret
    }
}

nonisolated struct ScoreboardRemoteDisplayDirectionSettings: Codable, Equatable, Sendable {
    var displayDirection: ScoreboardDisplayDirection
    var externalDisplayDirection: ScoreboardDisplayDirection

    static let `default` = ScoreboardRemoteDisplayDirectionSettings(
        displayDirection: .homeLeft,
        externalDisplayDirection: .homeLeft
    )

    func applyingSideSwap(_ areSidesSwapped: Bool) -> ScoreboardRemoteDisplayDirectionSettings {
        ScoreboardRemoteDisplayDirectionSettings(
            displayDirection: displayDirection.applyingSideSwap(areSidesSwapped),
            externalDisplayDirection: externalDisplayDirection.applyingSideSwap(areSidesSwapped)
        )
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
    private static let displayDirectionsKey = "com.ironmaple.smartscoreboard.remoteDisplayDirections"
    private static let displayDirectionModelVersionKey = "com.ironmaple.smartscoreboard.remoteDisplayDirectionModelVersion"
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

    static func displayDirectionsByID() -> [String: ScoreboardRemoteDisplayDirectionSettings] {
        guard
            let data = UserDefaults.standard.data(forKey: displayDirectionsKey),
            let settings = try? JSONDecoder().decode([String: ScoreboardRemoteDisplayDirectionSettings].self, from: data)
        else {
            return [:]
        }
        return settings
    }

    static func saveDisplayDirectionsByID(_ settings: [String: ScoreboardRemoteDisplayDirectionSettings]) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: displayDirectionsKey)
            saveDisplayDirectionModelVersion(ScoreboardStore.displayDirectionModelVersion)
        }
    }

    static func displayDirectionModelVersion() -> Int {
        guard UserDefaults.standard.object(forKey: displayDirectionModelVersionKey) != nil else {
            return 1
        }
        return UserDefaults.standard.integer(forKey: displayDirectionModelVersionKey)
    }

    static func saveDisplayDirectionModelVersion(_ version: Int) {
        UserDefaults.standard.set(version, forKey: displayDirectionModelVersionKey)
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

private enum ScoreboardRemoteDisplayNetworkTransport {
    static func parameters(for mode: ScoreboardRemoteDisplayNetworkMode) -> NWParameters {
        let parameters = NWParameters.tcp
        let webSocket = NWProtocolWebSocket.Options(.version13)
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocket, at: 0)
        parameters.includePeerToPeer = mode.includesPeerToPeer
        return parameters
    }

    static func browserParameters(for mode: ScoreboardRemoteDisplayNetworkMode) -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = mode.includesPeerToPeer
        return parameters
    }

    static func send(_ data: Data, on connection: NWConnection, completion: @escaping (NWError?) -> Void = { _ in }) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "remote-display-message", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed(completion))
    }

    static func discoveryInfo(from result: NWBrowser.Result) -> [String: String]? {
        guard case .bonjour(let txtRecord) = result.metadata else {
            return nil
        }

        var discoveryInfo: [String: String] = [:]
        for (key, _) in txtRecord {
            discoveryInfo[key] = txtRecord[key]
        }
        return discoveryInfo.isEmpty ? nil : discoveryInfo
    }

    static func txtRecordData(from values: [String: String]) -> Data {
        var record = NWTXTRecord()
        for (key, value) in values where !value.isEmpty {
            record[key] = value
        }
        return record.data
    }
}

@MainActor
final class ScoreboardRemoteDisplayHostService: ObservableObject {
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
    @Published private(set) var displayDirectionsByID: [String: ScoreboardRemoteDisplayDirectionSettings] = ScoreboardRemoteDisplayPairingStore.displayDirectionsByID()
    @Published private(set) var displayInitiatedDisconnectNotice: ScoreboardRemoteDisplayDisconnectNotice?

    let hostID = ScoreboardRemoteDisplayIdentity.stableID(forKey: "remoteDisplayHostID")

    private let localDisplayID = ScoreboardRemoteDisplayIdentity.stableID(forKey: "remoteDisplayID")
    private var displayName = ScoreboardRemoteDisplayDeviceName.current ?? "Smart Scoreboard Operator"
    private var networkMode: ScoreboardRemoteDisplayNetworkMode = .nearbyAndLocalNetwork
    private var browser: NWBrowser?
    private var displayConnectionsByEndpoint: [NWEndpoint: NetworkDisplayConnection] = [:]
    private var latestStateData = Data()
    private var invitedPeerIDs = Set<String>()
    private var heartbeatTimer: Timer?
    private var heartbeatSequence: UInt64 = 0
    private var lastTrustedInviteAttemptByID: [String: Date] = [:]
    private var currentStateProvider: ((String?) -> Data)?
    private var currentImageResponsesProvider: (() -> [String: ScoreboardWebAPIImageResponse])?
    private var lastPeriodicStateSyncAt: Date?
    private var endpointsResettingPairing = Set<NWEndpoint>()
    private var operatorDisconnectedDisplayIDs = Set<String>()
    private var displayInitiatedDisconnectSequence: UInt64 = 0

    func migrateDisplayDirectionsIfNeeded(areSidesSwapped: Bool) {
        guard ScoreboardRemoteDisplayPairingStore.displayDirectionModelVersion() < ScoreboardStore.displayDirectionModelVersion else {
            return
        }

        displayDirectionsByID = displayDirectionsByID.mapValues { settings in
            settings.applyingSideSwap(areSidesSwapped)
        }
        ScoreboardRemoteDisplayPairingStore.saveDisplayDirectionsByID(displayDirectionsByID)
    }

    func start(
        initialState: Data,
        displayName: String,
        networkMode: ScoreboardRemoteDisplayNetworkMode,
        currentStateProvider: ((String?) -> Data)? = nil,
        currentImageResponsesProvider: (() -> [String: ScoreboardWebAPIImageResponse])? = nil
    ) {
        stop()
        self.displayName = displayName
        self.networkMode = networkMode
        self.currentStateProvider = currentStateProvider
        self.currentImageResponsesProvider = currentImageResponsesProvider
        latestStateData = currentStateProvider?(nil) ?? initialState
        startBrowser()
        startHeartbeatTimer()
        updateBrowsingStatus()
    }

    func stop() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        browser?.cancel()
        browser = nil
        for display in displayConnectionsByEndpoint.values {
            display.connection.cancel()
        }
        displayConnectionsByEndpoint.removeAll()
        sources.removeAll()
        connectedDisplays.removeAll()
        invitedPeerIDs.removeAll()
        lastTrustedInviteAttemptByID.removeAll()
        currentStateProvider = nil
        currentImageResponsesProvider = nil
        lastPeriodicStateSyncAt = nil
        endpointsResettingPairing.removeAll()
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
        guard browser != nil else {
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
        let pairingSecret = Self.makePairingSecret()
        let request = ScoreboardRemoteDisplayPairingRequest(
            pairingCode: sanitizedCode,
            hostID: hostID,
            hostName: displayName,
            displayID: source.displayID,
            pairingSecret: pairingSecret,
            trustedReconnect: false,
            takeoverConfirmed: takeoverConfirmed
        )
        let pendingTrustedDisplay = ScoreboardRemoteDisplayTrustedPeer(
            id: source.id,
            name: source.name,
            pairingSetID: source.pairingSetID,
            deviceType: source.deviceType,
            pairingSecret: pairingSecret
        )
        connect(to: source, request: request, pendingTrustedDisplay: pendingTrustedDisplay)
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
        displayDirectionsByID.removeValue(forKey: displayID)
        ScoreboardRemoteDisplayPairingStore.saveDisplayDirectionsByID(displayDirectionsByID)
        operatorDisconnectedDisplayIDs.remove(displayID)

        if let endpoint = connectedEndpoint(forDisplayID: displayID) {
            let message = ScoreboardRemoteDisplayControlMessage(
                kind: .removePairing,
                sequence: heartbeatSequence,
                sentAt: Date().timeIntervalSince1970,
                hostID: hostID,
                hostName: displayName,
                displayID: displayID,
                displayName: nil
            )
            sendControlMessage(message, to: [endpoint])
        }

        updateBrowsingStatus()
    }

    func disconnectDisplay(id displayID: String) {
        guard let endpoint = connectedEndpoint(forDisplayID: displayID) else {
            return
        }

        operatorDisconnectedDisplayIDs.insert(displayID)
        let message = ScoreboardRemoteDisplayControlMessage(
            kind: .disconnect,
            sequence: heartbeatSequence,
            sentAt: Date().timeIntervalSince1970,
            hostID: hostID,
            hostName: displayName,
            displayID: displayID,
            displayName: nil
        )
        sendControlMessage(message, to: [endpoint])
    }

    func sendSoundTest(toDisplayID displayID: String) {
        guard !mutedDisplayIDs.contains(displayID) else {
            status = .failed(localizedRemoteDisplayString("Unmute this Remote Display before running a sound test."))
            return
        }
        guard let endpoint = connectedEndpoint(forDisplayID: displayID) else {
            status = .failed(localizedRemoteDisplayString("Connect the Remote Display before running a sound test."))
            return
        }

        let message = ScoreboardRemoteDisplayControlMessage(
            kind: .soundTest,
            sequence: heartbeatSequence,
            sentAt: Date().timeIntervalSince1970,
            hostID: hostID,
            hostName: displayName,
            displayID: displayID,
            displayName: nil
        )
        sendControlMessage(message, to: [endpoint])
    }

    func sendSoundEffect(_ effect: ScoreboardSoundEffect) {
        guard effect != .none else {
            return
        }

        let targetEndpoints = readyEndpoints.filter { endpoint in
            !mutedDisplayIDs.contains(sourceID(for: endpoint))
        }
        guard !targetEndpoints.isEmpty else {
            return
        }

        let message = ScoreboardRemoteDisplayControlMessage(
            kind: .soundEffect,
            sequence: heartbeatSequence,
            sentAt: Date().timeIntervalSince1970,
            hostID: hostID,
            hostName: displayName,
            displayID: nil,
            displayName: nil,
            soundEffect: effect
        )
        sendControlMessage(message, to: targetEndpoints)
    }

    func setDisplayMuted(id displayID: String, isMuted: Bool) {
        if isMuted {
            mutedDisplayIDs.insert(displayID)
        } else {
            mutedDisplayIDs.remove(displayID)
        }
        ScoreboardRemoteDisplayPairingStore.saveMutedDisplayIDs(mutedDisplayIDs)
        if let endpoint = connectedEndpoint(forDisplayID: displayID) {
            sendMuteState(to: [endpoint], displayID: displayID)
        }
        updateBrowsingStatus()
    }

    func displayDirection(id displayID: String) -> ScoreboardDisplayDirection {
        displayDirectionsByID[displayID]?.displayDirection ?? .homeLeft
    }

    func externalDisplayDirection(id displayID: String) -> ScoreboardDisplayDirection {
        displayDirectionsByID[displayID]?.externalDisplayDirection ?? .homeLeft
    }

    func setDisplayDirection(id displayID: String, direction: ScoreboardDisplayDirection) {
        var settings = displayDirectionsByID[displayID] ?? .default
        settings.displayDirection = direction
        displayDirectionsByID[displayID] = settings
        ScoreboardRemoteDisplayPairingStore.saveDisplayDirectionsByID(displayDirectionsByID)
    }

    func setExternalDisplayDirection(id displayID: String, direction: ScoreboardDisplayDirection) {
        var settings = displayDirectionsByID[displayID] ?? .default
        settings.externalDisplayDirection = direction
        displayDirectionsByID[displayID] = settings
        ScoreboardRemoteDisplayPairingStore.saveDisplayDirectionsByID(displayDirectionsByID)
    }

    func isTrustedDisplay(_ source: ScoreboardRemoteDisplaySource) -> Bool {
        guard let trustedDisplay = trustedDisplays.first(where: { $0.id == source.id }),
              trustedDisplay.pairingSecret?.isEmpty == false else {
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
        trustedDisplays.contains { $0.id == displayID && $0.pairingSecret?.isEmpty == false }
    }

    func disconnectDisplays() {
        guard !displayConnectionsByEndpoint.isEmpty else {
            connectedDisplays.removeAll()
            status = .off
            return
        }

        operatorDisconnectedDisplayIDs.formUnion(connectedDisplays.map(\.id))
        for display in displayConnectionsByEndpoint.values {
            display.connection.cancel()
        }
        displayConnectionsByEndpoint.removeAll()
        invitedPeerIDs.removeAll()
        connectedDisplays.removeAll()
        lastPeriodicStateSyncAt = nil
        endpointsResettingPairing.removeAll()
        status = .browsing(displayCount: sources.count, pairedCount: 0)
    }

    func updateState(_ data: Data) {
        latestStateData = data
        sendCurrentState()
    }

    private func startBrowser() {
        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: Self.bonjourServiceType, domain: nil),
            using: ScoreboardRemoteDisplayNetworkTransport.browserParameters(for: networkMode)
        )
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.handleBrowserResults(results)
            }
        }
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleBrowserStateChanged(state)
            }
        }
        self.browser = browser
        browser.start(queue: .main)
    }

    private func handleBrowserStateChanged(_ state: NWBrowser.State) {
        switch state {
        case .failed(let error):
            status = .failed(String(describing: error))
        case .cancelled:
            break
        case .ready, .setup, .waiting:
            updateBrowsingStatus()
        @unknown default:
            break
        }
    }

    private func handleBrowserResults(_ results: Set<NWBrowser.Result>) {
        sources = results.compactMap { result -> ScoreboardRemoteDisplaySource? in
            let discoveryInfo = ScoreboardRemoteDisplayNetworkTransport.discoveryInfo(from: result)
            guard !isLocalReceiverAdvertisement(discoveryInfo: discoveryInfo) else {
                return nil
            }
            return ScoreboardRemoteDisplaySource(endpoint: result.endpoint, discoveryInfo: discoveryInfo)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        for source in sources {
            removeResetTrustedDisplayIfNeeded(source)
            autoReconnectTrustedDisplayIfNeeded(source)
        }
        updateBrowsingStatus()
    }

    private func connect(
        to source: ScoreboardRemoteDisplaySource,
        request: ScoreboardRemoteDisplayPairingRequest,
        pendingTrustedDisplay: ScoreboardRemoteDisplayTrustedPeer?
    ) {
        if let existingEndpoint = existingConnectionEndpoint(for: source),
           var existing = displayConnectionsByEndpoint[existingEndpoint] {
            existing.pendingPairingRequest = request
            existing.pendingTrustedDisplay = pendingTrustedDisplay
            displayConnectionsByEndpoint[existingEndpoint] = existing
            if existing.isReady {
                sendPendingPairingRequest(to: existingEndpoint)
                sendCurrentState(to: [existingEndpoint])
                sendMuteState(to: [existingEndpoint])
                sendHeartbeat()
            }
            return
        }

        let connection = NWConnection(
            to: source.endpoint,
            using: ScoreboardRemoteDisplayNetworkTransport.parameters(for: networkMode)
        )
        displayConnectionsByEndpoint[source.endpoint] = NetworkDisplayConnection(
            endpoint: source.endpoint,
            connection: connection,
            displayID: source.id,
            displayName: source.name,
            appVersion: source.appVersion,
            deviceType: source.deviceType,
            pendingPairingRequest: request,
            pendingTrustedDisplay: pendingTrustedDisplay
        )
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleConnectionStateChanged(state, endpoint: source.endpoint)
            }
        }
        connection.start(queue: .main)
        updateBrowsingStatus()
    }

    private func handleConnectionStateChanged(_ state: NWConnection.State, endpoint: NWEndpoint) {
        guard var display = displayConnectionsByEndpoint[endpoint] else {
            return
        }
        switch state {
        case .ready:
            display.isReady = true
            displayConnectionsByEndpoint[endpoint] = display
            startReceiving(from: endpoint)
            sendPendingPairingRequest(to: endpoint)
            sendCurrentState(to: [endpoint])
            sendMuteState(to: [endpoint])
            sendHeartbeat()
        case .failed(let error):
            displayConnectionsByEndpoint.removeValue(forKey: endpoint)
            status = .failed(String(describing: error))
        case .cancelled:
            displayConnectionsByEndpoint.removeValue(forKey: endpoint)
        case .waiting(let error):
            status = .failed(String(describing: error))
        case .setup, .preparing:
            break
        @unknown default:
            break
        }
        updateBrowsingStatus()
    }

    private func sendPendingPairingRequest(to endpoint: NWEndpoint) {
        guard var display = displayConnectionsByEndpoint[endpoint],
              let request = display.pendingPairingRequest,
              let data = try? JSONEncoder().encode(request) else {
            return
        }
        display.pendingPairingRequest = nil
        displayConnectionsByEndpoint[endpoint] = display
        sendData(data, to: [endpoint])
    }

    private func startReceiving(from endpoint: NWEndpoint) {
        guard var display = displayConnectionsByEndpoint[endpoint], !display.isReceiving else {
            return
        }
        display.isReceiving = true
        displayConnectionsByEndpoint[endpoint] = display
        receiveNextMessage(from: endpoint)
    }

    private func receiveNextMessage(from endpoint: NWEndpoint) {
        guard let connection = displayConnectionsByEndpoint[endpoint]?.connection else {
            return
        }
        connection.receiveMessage { [weak self] data, _, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if error != nil {
                    self.displayConnectionsByEndpoint.removeValue(forKey: endpoint)
                    self.updateBrowsingStatus()
                    return
                }
                if let data, !data.isEmpty {
                    self.handleReceivedData(data, from: endpoint)
                }
                self.receiveNextMessage(from: endpoint)
            }
        }
    }

    private func handleReceivedData(_ data: Data, from endpoint: NWEndpoint) {
        guard let message = try? JSONDecoder().decode(ScoreboardRemoteDisplayControlMessage.self, from: data) else {
            return
        }
        handleControlMessage(message, from: endpoint)
    }

    private func handleControlMessage(_ message: ScoreboardRemoteDisplayControlMessage, from endpoint: NWEndpoint) {
        if message.kind == .removePairing {
            handleDisplayRemovedPairing(message, from: endpoint)
            return
        }
        if message.kind == .disconnect {
            handleDisplayInitiatedDisconnect(message, from: endpoint)
            return
        }
        if message.kind == .imageRequest {
            handleImageRequest(message, from: endpoint)
            return
        }

        guard message.kind == .heartbeatAck else {
            return
        }

        let now = Date()
        if let lastAckSequence = displayConnectionsByEndpoint[endpoint]?.lastAckSequence,
           message.sequence <= lastAckSequence {
            return
        }

        let latency = max(0, now.timeIntervalSince1970 - message.sentAt)
        let displayID = message.displayID ?? sourceID(for: endpoint)
        let displayName = message.displayName ?? displayConnectionsByEndpoint[endpoint]?.displayName ?? localizedRemoteDisplayString("Remote Display")
        var display = displayConnectionsByEndpoint[endpoint]
        display?.displayID = displayID
        display?.displayName = displayName
        display?.lastAckAt = now
        display?.lastAckSequence = message.sequence
        display?.latency = latency
        display?.appVersion = ScoreboardRemoteDisplayAppVersion(
            version: message.appVersion,
            build: message.appBuild
        )
        display?.deviceType = message.deviceType.flatMap(ScoreboardRemoteDisplayDeviceType.init(rawValue:))
            ?? sources.first { $0.endpoint == endpoint || $0.id == displayID }?.deviceType
            ?? .unknown
        invitedPeerIDs.remove(displayID)
        lastTrustedInviteAttemptByID.removeValue(forKey: displayID)

        let pendingTrustedDisplay = display?.pendingTrustedDisplay
        display?.pendingTrustedDisplay = nil
        if let display {
            displayConnectionsByEndpoint[endpoint] = display
        }

        if pendingTrustedDisplay != nil || isTrustedDisplay(id: displayID) {
            let pairingSecret = pendingTrustedDisplay?.pairingSecret
                ?? trustedDisplays.first { $0.id == displayID }?.pairingSecret
            let pairingSetID = pendingTrustedDisplay?.pairingSetID
                ?? sources.first { $0.id == displayID }?.pairingSetID
                ?? trustedDisplays.first { $0.id == displayID }?.pairingSetID
            let deviceType = pendingTrustedDisplay?.deviceType
                ?? sources.first { $0.id == displayID }?.deviceType
                ?? message.deviceType.flatMap(ScoreboardRemoteDisplayDeviceType.init(rawValue:))
                ?? trustedDisplays.first { $0.id == displayID }?.deviceType
            trustDisplay(id: displayID, name: displayName, pairingSetID: pairingSetID, deviceType: deviceType, pairingSecret: pairingSecret)
        }
        sendMuteState(to: [endpoint], displayID: displayID)
        updateBrowsingStatus()
    }

    private func handleImageRequest(_ message: ScoreboardRemoteDisplayControlMessage, from endpoint: NWEndpoint) {
        guard
            message.hostID == nil || message.hostID == hostID,
            displayConnectionsByEndpoint[endpoint]?.isReady == true,
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

        sendData(payload, to: [endpoint])
    }

    private func handleDisplayInitiatedDisconnect(_ message: ScoreboardRemoteDisplayControlMessage, from endpoint: NWEndpoint) {
        let displayID = message.displayID
            ?? displayConnectionsByEndpoint[endpoint]?.displayID
            ?? sourceID(for: endpoint)
        let displayName = message.displayName
            ?? displayConnectionsByEndpoint[endpoint]?.displayName
            ?? localizedRemoteDisplayString("Remote Display")

        operatorDisconnectedDisplayIDs.insert(displayID)
        displayInitiatedDisconnectSequence &+= 1
        displayInitiatedDisconnectNotice = ScoreboardRemoteDisplayDisconnectNotice(
            sequence: displayInitiatedDisconnectSequence,
            displayID: displayID,
            displayName: displayName
        )
        updateBrowsingStatus()
    }

    private func handleDisplayRemovedPairing(_ message: ScoreboardRemoteDisplayControlMessage, from endpoint: NWEndpoint) {
        let displayID = message.displayID
            ?? displayConnectionsByEndpoint[endpoint]?.displayID
            ?? sourceID(for: endpoint)
        let displayName = message.displayName
            ?? displayConnectionsByEndpoint[endpoint]?.displayName
            ?? localizedRemoteDisplayString("Remote Display")

        trustedDisplays.removeAll { $0.id == displayID }
        ScoreboardRemoteDisplayPairingStore.saveTrustedDisplays(trustedDisplays)
        mutedDisplayIDs.remove(displayID)
        ScoreboardRemoteDisplayPairingStore.saveMutedDisplayIDs(mutedDisplayIDs)
        displayDirectionsByID.removeValue(forKey: displayID)
        ScoreboardRemoteDisplayPairingStore.saveDisplayDirectionsByID(displayDirectionsByID)
        endpointsResettingPairing.insert(endpoint)
        displayConnectionsByEndpoint.removeValue(forKey: endpoint)
        invitedPeerIDs.remove(displayID)
        lastTrustedInviteAttemptByID.removeValue(forKey: displayID)
        updateSourceAfterDisplayReset(
            endpoint,
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
        to endpoints: [NWEndpoint]? = nil
    ) {
        guard let data = try? JSONEncoder().encode(message) else {
            return
        }
        sendData(data, to: endpoints)
    }

    private func isLocalReceiverAdvertisement(discoveryInfo: [String: String]?) -> Bool {
        guard discoveryInfo?["role"] == "display" else {
            return false
        }
        return discoveryInfo?["displayID"] == localDisplayID
    }

    private func sourceID(for endpoint: NWEndpoint) -> String {
        if let display = displayConnectionsByEndpoint[endpoint] {
            return display.displayID
        }
        return sources.first { $0.endpoint == endpoint }?.id ?? "endpoint-\(endpoint.debugDescription)"
    }

    private func connectedEndpoint(forDisplayID displayID: String) -> NWEndpoint? {
        displayConnectionsByEndpoint.first { endpoint, display in
            display.displayID == displayID || sources.first { $0.endpoint == endpoint }?.id == displayID
        }?.key
    }

    private func existingConnectionEndpoint(for source: ScoreboardRemoteDisplaySource) -> NWEndpoint? {
        if displayConnectionsByEndpoint[source.endpoint] != nil {
            return source.endpoint
        }
        return displayConnectionsByEndpoint.first { _, display in
            display.displayID == source.id
                || display.pendingTrustedDisplay?.id == source.id
                || sources.first { $0.endpoint == display.endpoint }?.id == source.id
        }?.key
    }

    private func isConnected(to source: ScoreboardRemoteDisplaySource) -> Bool {
        if let endpoint = existingConnectionEndpoint(for: source),
           displayConnectionsByEndpoint[endpoint]?.isReady == true,
           !endpointsResettingPairing.contains(endpoint) {
            return true
        }
        return connectedDisplays.contains { $0.id == source.id }
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

    private func inviteTrustedDisplayIfNeeded(
        _ source: ScoreboardRemoteDisplaySource,
        force: Bool = false,
        takeoverConfirmed: Bool = false
    ) {
        guard browser != nil else {
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
        guard let trustedDisplay = trustedDisplays.first(where: { $0.id == source.id }),
              let pairingSecret = trustedDisplay.pairingSecret,
              !pairingSecret.isEmpty else {
            return
        }

        let request = ScoreboardRemoteDisplayPairingRequest(
            pairingCode: nil,
            hostID: hostID,
            hostName: displayName,
            displayID: source.displayID,
            pairingSecret: pairingSecret,
            trustedReconnect: true,
            takeoverConfirmed: takeoverConfirmed
        )

        invitedPeerIDs.insert(source.id)
        lastTrustedInviteAttemptByID[source.id] = Date()
        connect(to: source, request: request, pendingTrustedDisplay: trustedDisplay)
        updateBrowsingStatus()
    }

    private func updateSourceAfterDisplayReset(
        _ endpoint: NWEndpoint,
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
        var discoveryInfo = sources.first { $0.endpoint == endpoint || $0.id == displayID }?.discoveryInfo ?? fallbackInfo
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

        let source = ScoreboardRemoteDisplaySource(endpoint: endpoint, discoveryInfo: discoveryInfo)
        if let index = sources.firstIndex(where: { $0.endpoint == endpoint || $0.id == displayID }) {
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
        displayDirectionsByID.removeValue(forKey: source.id)
        ScoreboardRemoteDisplayPairingStore.saveDisplayDirectionsByID(displayDirectionsByID)
    }

    private func trustDisplay(
        id displayID: String,
        name displayName: String,
        pairingSetID: String?,
        deviceType: ScoreboardRemoteDisplayDeviceType?,
        pairingSecret: String?
    ) {
        guard !displayID.isEmpty, pairingSecret?.isEmpty == false else {
            return
        }

        trustedDisplays.removeAll { $0.id == displayID }
        trustedDisplays.append(ScoreboardRemoteDisplayTrustedPeer(
            id: displayID,
            name: displayName,
            pairingSetID: pairingSetID,
            deviceType: deviceType,
            pairingSecret: pairingSecret
        ))
        trustedDisplays.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        ScoreboardRemoteDisplayPairingStore.saveTrustedDisplays(trustedDisplays)
    }

    private func updateBrowsingStatus() {
        let now = Date()
        connectedDisplays = displayConnectionsByEndpoint.values
            .filter { $0.isReady && !endpointsResettingPairing.contains($0.endpoint) }
            .map { display in
                let ackAge = display.lastAckAt.map { now.timeIntervalSince($0) }
                return ScoreboardRemoteDisplayConnection(
                    id: display.displayID,
                    name: display.displayName,
                    quality: Self.connectionQuality(lastAckAge: ackAge),
                    latencyMilliseconds: display.latency.map { Int($0 * 1_000) },
                    lastHandshakeAgeSeconds: ackAge.map(Int.init),
                    appVersion: display.appVersion,
                    deviceType: display.deviceType,
                    isMuted: mutedDisplayIDs.contains(display.displayID)
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        status = .browsing(
            displayCount: sources.count,
            pairedCount: connectedDisplays.count
        )
    }

    private var readyEndpoints: [NWEndpoint] {
        displayConnectionsByEndpoint.values
            .filter { $0.isReady && !endpointsResettingPairing.contains($0.endpoint) }
            .map(\.endpoint)
    }

    private func currentStateData(forDisplayID displayID: String?) -> Data {
        if let data = currentStateProvider?(displayID), !data.isEmpty {
            if displayID == nil {
                latestStateData = data
            }
            return data
        }
        return latestStateData
    }

    private func sendCurrentState(to endpoints: [NWEndpoint]? = nil) {
        let targetEndpoints = endpoints ?? readyEndpoints
        guard !targetEndpoints.isEmpty else {
            return
        }

        for endpoint in targetEndpoints {
            let displayID = sourceID(for: endpoint)
            queueStateData(currentStateData(forDisplayID: displayID), to: endpoint)
        }
    }

    private func queueStateData(_ data: Data, to endpoint: NWEndpoint) {
        guard !data.isEmpty, var display = displayConnectionsByEndpoint[endpoint], display.isReady else {
            return
        }
        if display.isSendingState {
            display.pendingStateData = data
            displayConnectionsByEndpoint[endpoint] = display
            return
        }

        display.isSendingState = true
        displayConnectionsByEndpoint[endpoint] = display
        sendData(data, to: [endpoint]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleStateSendCompleted(to: endpoint)
            }
        }
    }

    private func handleStateSendCompleted(to endpoint: NWEndpoint) {
        guard var display = displayConnectionsByEndpoint[endpoint] else {
            return
        }
        display.isSendingState = false
        let pendingStateData = display.pendingStateData
        display.pendingStateData = nil
        displayConnectionsByEndpoint[endpoint] = display
        if let pendingStateData {
            queueStateData(pendingStateData, to: endpoint)
        }
    }

    private func sendMuteState(to endpoints: [NWEndpoint], displayID: String? = nil) {
        for endpoint in endpoints {
            let resolvedDisplayID = displayID ?? sourceID(for: endpoint)
            let message = ScoreboardRemoteDisplayControlMessage(
                kind: .setMuted,
                sequence: heartbeatSequence,
                sentAt: Date().timeIntervalSince1970,
                hostID: hostID,
                hostName: displayName,
                displayID: resolvedDisplayID,
                displayName: nil,
                isMuted: mutedDisplayIDs.contains(resolvedDisplayID)
            )
            sendControlMessage(message, to: [endpoint])
        }
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
        let targetEndpoints = readyEndpoints
        guard !targetEndpoints.isEmpty else {
            updateBrowsingStatus()
            return
        }

        heartbeatSequence &+= 1
        let sentAt = Date().timeIntervalSince1970
        for endpoint in targetEndpoints {
            let message = ScoreboardRemoteDisplayControlMessage(
                kind: .heartbeat,
                sequence: heartbeatSequence,
                sentAt: sentAt,
                hostID: hostID,
                hostName: displayName,
                displayID: sourceID(for: endpoint),
                displayName: nil
            )
            sendControlMessage(message, to: [endpoint])
        }

        let now = Date()
        if lastPeriodicStateSyncAt == nil || now.timeIntervalSince(lastPeriodicStateSyncAt ?? now) >= Self.periodicStateSyncInterval {
            lastPeriodicStateSyncAt = now
            sendCurrentState(to: targetEndpoints)
        }
        updateBrowsingStatus()
    }

    private func sendData(_ data: Data, to endpoints: [NWEndpoint]? = nil, completion: ((NWError?) -> Void)? = nil) {
        let targetEndpoints = endpoints ?? readyEndpoints
        guard !targetEndpoints.isEmpty, !data.isEmpty else {
            completion?(nil)
            return
        }

        for endpoint in targetEndpoints {
            guard let connection = displayConnectionsByEndpoint[endpoint]?.connection else {
                continue
            }
            ScoreboardRemoteDisplayNetworkTransport.send(data, on: connection) { error in
                completion?(error)
            }
        }
    }

    private static var defaultHostName: String {
        ScoreboardRemoteDisplayDeviceName.current ?? "Smart Scoreboard Operator"
    }

    private static func sanitizedPairingCode(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(pairingCodeLength))
    }

    private static func makePairingSecret() -> String {
        "\(UUID().uuidString)-\(UUID().uuidString)"
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

    private struct NetworkDisplayConnection {
        let endpoint: NWEndpoint
        let connection: NWConnection
        var displayID: String
        var displayName: String
        var isReady = false
        var isReceiving = false
        var lastAckAt: Date?
        var lastAckSequence: UInt64?
        var latency: TimeInterval?
        var appVersion: ScoreboardRemoteDisplayAppVersion?
        var deviceType: ScoreboardRemoteDisplayDeviceType
        var pendingPairingRequest: ScoreboardRemoteDisplayPairingRequest?
        var pendingTrustedDisplay: ScoreboardRemoteDisplayTrustedPeer?
        var isSendingState = false
        var pendingStateData: Data?
    }
}

@MainActor
final class ScoreboardRemoteDisplayReceiver: ObservableObject {
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

    private var displayName = ScoreboardRemoteDisplayDeviceName.current ?? "Smart Scoreboard Display"
    private var networkMode: ScoreboardRemoteDisplayNetworkMode = .nearbyAndLocalNetwork
    private var listenerNetworkMode: ScoreboardRemoteDisplayNetworkMode?
    private var listener: NWListener?
    private var connectionsByID: [ObjectIdentifier: NWConnection] = [:]
    private var pairedConnection: NWConnection?
    private var activeConsumerCount = 0
    private var pairingCodeTimer: Timer?
    private var heartbeatMonitorTimer: Timer?
    private var pairingSetID = ScoreboardRemoteDisplayIdentity.stableID(forKey: "remoteDisplayPairingSetID")
    private var pairedHostID: String?
    private var pairedHostName: String?
    private var lastActiveOperatorID: String?
    private var lastActiveOperatorName: String?
    private var isPairingScreenVisible = false
    private var isDisconnectingFromOperator = false
    private var isForgettingTrustedHosts = false
    private var requestedImageAssetIDs = Set<String>()
    private var failedPairingAttemptsByHostID: [String: [Date]] = [:]
    private let soundTestPlayer = BuzzerPlayer()

    func acquire(displayName: String? = nil, networkMode: ScoreboardRemoteDisplayNetworkMode = .nearbyAndLocalNetwork) {
        activeConsumerCount += 1
        start(displayName: displayName, networkMode: networkMode)
    }

    func release() {
        activeConsumerCount = max(0, activeConsumerCount - 1)
        if activeConsumerCount == 0 {
            stopAdvertising(statusMessage: localizedRemoteDisplayString("Remote Display stopped."))
        }
    }

    func updateNetworkMode(_ networkMode: ScoreboardRemoteDisplayNetworkMode) {
        guard self.networkMode != networkMode else {
            return
        }
        self.networkMode = networkMode
        if listener != nil {
            startOrRefreshListener(recreate: true)
        }
    }

    func start(displayName: String? = nil, networkMode: ScoreboardRemoteDisplayNetworkMode = .nearbyAndLocalNetwork) {
        if listener != nil {
            updateNetworkMode(networkMode)
            return
        }

        self.displayName = displayName ?? Self.defaultDisplayName()
        self.networkMode = networkMode
        pairingCode = Self.makePairingCode()
        let lastActiveOperator = ScoreboardRemoteDisplayPairingStore.lastActiveOperator()
        lastActiveOperatorID = lastActiveOperator?.id
        lastActiveOperatorName = lastActiveOperator?.name
        status = lastActiveOperator.map {
            .disconnected(localizedRemoteDisplayFormat("Waiting for %@ to reconnect.", $0.name))
        } ?? .waiting
        pairedHostID = nil
        pairedHostName = nil
        pairedConnection = nil
        isDisconnectingFromOperator = false
        lastHeartbeatAt = nil
        masterClockOffset = nil

        startOrRefreshListener()
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
        listener?.cancel()
        listener = nil
        listenerNetworkMode = nil
        for connection in connectionsByID.values {
            connection.cancel()
        }
        connectionsByID.removeAll()
        pairedConnection = nil
        pairedHostID = nil
        pairedHostName = nil
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
        startOrRefreshListener()
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
            displayName: displayName,
            pairingSetID: pairingSetID,
            appVersion: ScoreboardRemoteDisplayAppVersion.current.version,
            appBuild: ScoreboardRemoteDisplayAppVersion.current.build,
            deviceType: ScoreboardRemoteDisplayDeviceType.current
        )
        sendControlMessage(message)

        pairedHostID = nil
        pairedHostName = nil
        let connectionToDisconnect = pairedConnection
        pairedConnection = nil
        isDisconnectingFromOperator = true
        lastHeartbeatAt = nil
        masterClockOffset = nil
        status = .disconnected(localizedRemoteDisplayFormat("Disconnected from %@.", operatorName))
        startOrRefreshListener()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak connectionToDisconnect] in
            connectionToDisconnect?.cancel()
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
        pairedConnection = nil
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
        startOrRefreshListener()
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
            displayName: displayName,
            pairingSetID: pairingSetID,
            appVersion: ScoreboardRemoteDisplayAppVersion.current.version,
            appBuild: ScoreboardRemoteDisplayAppVersion.current.build,
            deviceType: ScoreboardRemoteDisplayDeviceType.current
        )
        sendControlMessage(message)
    }

    private func disconnectAfterPairingResetNotice() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, self.isForgettingTrustedHosts else {
                return
            }
            for connection in self.connectionsByID.values {
                connection.cancel()
            }
            self.connectionsByID.removeAll()
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
        guard pairedConnection == nil else {
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
        pairedConnection = nil
        isDisconnectingFromOperator = false
        self.lastHeartbeatAt = nil
        masterClockOffset = nil
        status = .disconnected(localizedRemoteDisplayFormat("%@ stopped responding. Waiting for reconnect.", staleHostName))
        startOrRefreshListener()
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

    private func currentListenerService() -> NWListener.Service {
        var discoveryInfo = [
            "app": "Smart Scoreboard",
            "role": "display",
            "name": displayName,
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

        return NWListener.Service(
            name: displayName,
            type: ScoreboardRemoteDisplayHostService.bonjourServiceType,
            domain: nil,
            txtRecord: ScoreboardRemoteDisplayNetworkTransport.txtRecordData(from: discoveryInfo)
        )
    }

    private func startOrRefreshListener(recreate: Bool = false) {
        if let listener, !recreate, listenerNetworkMode == networkMode {
            listener.service = currentListenerService()
            return
        }

        listener?.cancel()
        listener = nil
        listenerNetworkMode = nil

        do {
            let listener = try NWListener(using: ScoreboardRemoteDisplayNetworkTransport.parameters(for: networkMode))
            listener.service = currentListenerService()
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleNewConnection(connection)
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleListenerStateChanged(state)
                }
            }
            self.listener = listener
            listenerNetworkMode = networkMode
            listener.start(queue: .main)
        } catch {
            status = .failed(String(describing: error))
        }
    }

    private func handleListenerStateChanged(_ state: NWListener.State) {
        switch state {
        case .failed(let error):
            status = .failed(String(describing: error))
        case .cancelled, .ready, .setup, .waiting:
            break
        @unknown default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connectionsByID[ObjectIdentifier(connection)] = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let connection else { return }
            Task { @MainActor [weak self] in
                self?.handleConnectionStateChanged(state, connection: connection)
            }
        }
        connection.start(queue: .main)
    }

    private func handleConnectionStateChanged(_ state: NWConnection.State, connection: NWConnection) {
        switch state {
        case .ready:
            receiveNextMessage(from: connection)
        case .failed, .cancelled:
            removeConnection(connection)
        case .waiting, .setup, .preparing:
            break
        @unknown default:
            break
        }
    }

    private func removeConnection(_ connection: NWConnection) {
        connectionsByID.removeValue(forKey: ObjectIdentifier(connection))
        guard pairedConnection === connection else {
            return
        }

        let previousHostName = pairedHostName ?? lastActiveOperatorName ?? localizedRemoteDisplayString("operator device")
        pairedHostID = nil
        pairedHostName = nil
        pairedConnection = nil
        lastHeartbeatAt = nil
        masterClockOffset = nil
        startOrRefreshListener()
        if isForgettingTrustedHosts {
            isForgettingTrustedHosts = false
            status = .waiting
        } else if state == nil {
            status = lastActiveOperatorName.map {
                .disconnected(localizedRemoteDisplayFormat("Waiting for %@ to reconnect.", $0))
            } ?? .waiting
        } else {
            status = .disconnected(localizedRemoteDisplayFormat(
                "%@ disconnected. Waiting for reconnect.",
                previousHostName
            ))
        }
    }

    private func receiveNextMessage(from connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            guard let connection else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if error != nil {
                    self.removeConnection(connection)
                    return
                }
                if let data, !data.isEmpty {
                    self.handleReceivedData(data, from: connection)
                }
                if self.connectionsByID[ObjectIdentifier(connection)] != nil {
                    self.receiveNextMessage(from: connection)
                }
            }
        }
    }

    private func handleReceivedData(_ data: Data, from connection: NWConnection) {
        guard !data.isEmpty else {
            return
        }

        if let request = pairingRequest(from: data) {
            handlePairingRequest(request, from: connection)
            return
        }

        if let imageAsset = ScoreboardRemoteDisplayImageAssetCodec.decode(data) {
            handleImageAsset(imageAsset)
            return
        }

        if let message = try? JSONDecoder().decode(ScoreboardRemoteDisplayControlMessage.self, from: data) {
            handleControlMessage(message, from: connection)
            return
        }

        let decoder = JSONDecoder()
        guard let decodedState = try? decoder.decode(ScoreboardWebAPIState.self, from: data) else {
            status = .failed(localizedRemoteDisplayString("Received an unreadable Remote Display update."))
            return
        }

        guard acceptsStateUpdate(from: connection) else {
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            state = decodedState
            lastReceivedAt = Date()
            status = .paired(pairedHostName ?? localizedRemoteDisplayString("operator device"))
        }
        requestMissingImagesIfNeeded(for: decodedState, from: connection)
    }

    private func handlePairingRequest(_ request: ScoreboardRemoteDisplayPairingRequest, from connection: NWConnection) {
        let requesterHostID = request.hostID
        let hostName = request.hostName
        let isDisplayMatch = request.displayID == nil || request.displayID == displayID
        let trustedHost = trustedHosts.first { $0.id == requesterHostID }
        let hasPairingSecret = request.pairingSecret?.isEmpty == false
        let isTrustedHost = request.trustedReconnect
            && hasPairingSecret
            && trustedHost?.pairingSecret == request.pairingSecret
        let receiverState = advertisedState
        let isCurrentOperator = requesterHostID == pairedHostID
        let isLastActiveOperator = requesterHostID == lastActiveOperatorID
        let hasTakeoverConfirmation = request.takeoverConfirmed
        let canAcceptTrustedReconnect = canAcceptTrustedReconnect(
            receiverState: receiverState,
            isDisplayMatch: isDisplayMatch,
            isTrustedHost: isTrustedHost,
            isCurrentOperator: isCurrentOperator,
            isLastActiveOperator: isLastActiveOperator,
            hasTakeoverConfirmation: hasTakeoverConfirmation
        )
        let isCodePairing = hasPairingSecret
            && isDisplayMatch
            && !isPairingRateLimited(hostID: requesterHostID)
            && request.pairingCode == pairingCode
        let canAcceptCodePairing = canAcceptCodePairing(
            receiverState: receiverState,
            isCodePairing: isCodePairing,
            isCurrentOperator: isCurrentOperator,
            isLastActiveOperator: isLastActiveOperator,
            hasTakeoverConfirmation: hasTakeoverConfirmation
        )

        guard canAcceptCodePairing || canAcceptTrustedReconnect else {
            recordFailedPairingAttempt(hostID: requesterHostID)
            connection.cancel()
            return
        }

        clearFailedPairingAttempts(hostID: requesterHostID)
        if let pairedConnection, pairedConnection !== connection {
            pairedConnection.cancel()
        }
        pairedHostID = requesterHostID
        pairedHostName = hostName
        pairedConnection = connection
        isDisconnectingFromOperator = false
        trustHost(id: requesterHostID, name: hostName, pairingSecret: request.pairingSecret)
        setLastActiveOperator(id: requesterHostID, name: hostName, pairingSecret: request.pairingSecret)
        if canAcceptCodePairing {
            pairingCode = Self.makePairingCode()
        }
        status = .paired(hostName)
        startOrRefreshListener()
    }

    private func handleImageAsset(_ asset: ScoreboardRemoteDisplayImageAsset) {
        guard !asset.id.isEmpty, !asset.data.isEmpty else {
            return
        }

        imageAssetsByID[asset.id] = asset
        requestedImageAssetIDs.remove(asset.id)
    }

    private func requestMissingImagesIfNeeded(for state: ScoreboardWebAPIState, from connection: NWConnection) {
        let backgroundMode = (state.display?.backgroundMode ?? .blurred).resolvedForRendering
        if backgroundMode == .image, let image = state.display?.backgroundImage {
            requestImageIfNeeded(id: image.id, path: image.path, from: connection)
        }

        let viewMode = state.display?.resolvedViewMode ?? .scoreboard
        if (viewMode == .scoreboard || viewMode == .eventLogo), let logo = state.display?.eventLogo {
            requestImageIfNeeded(id: logo.id, path: logo.path, from: connection)
        }

        guard state.display?.showsTeamLogos ?? true else {
            return
        }

        if let logo = state.teams.home.logo {
            requestImageIfNeeded(id: logo.id, path: logo.path, from: connection)
        }
        if let logo = state.teams.guest.logo {
            requestImageIfNeeded(id: logo.id, path: logo.path, from: connection)
        }
    }

    private func requestImageIfNeeded(id: String, path: String, from connection: NWConnection) {
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
            displayName: displayName,
            imageID: id,
            imagePath: path
        )
        sendControlMessage(message, to: [connection])
    }

    private func handleControlMessage(_ message: ScoreboardRemoteDisplayControlMessage, from connection: NWConnection) {
        guard !isForgettingTrustedHosts else {
            return
        }

        switch message.kind {
        case .removePairing:
            handleRemovePairing(message, from: connection)
            return
        case .disconnect:
            handleDisconnect(message, from: connection)
            return
        case .setMuted:
            handleSetMuted(message, from: connection)
            return
        case .soundTest:
            handleSoundTest(message, from: connection)
            return
        case .soundEffect:
            handleSoundEffect(message, from: connection)
            return
        case .imageRequest:
            return
        case .heartbeat:
            break
        case .heartbeatAck:
            return
        }

        guard acceptsHeartbeat(message, from: connection) else {
            return
        }

        let receivedAt = Date()
        lastHeartbeatAt = receivedAt
        updateMasterClockOffset(from: message, receivedAt: receivedAt)
        let previousHostID = pairedHostID
        let previousHostName = pairedHostName
        pairedHostID = message.hostID
        pairedHostName = message.hostName ?? localizedRemoteDisplayString("operator device")
        pairedConnection = connection
        if let hostID = message.hostID {
            let hostName = pairedHostName ?? localizedRemoteDisplayString("operator device")
            let pairingSecret = trustedHosts.first { $0.id == hostID }?.pairingSecret
            trustHost(id: hostID, name: hostName, pairingSecret: pairingSecret)
            setLastActiveOperator(id: hostID, name: hostName, pairingSecret: pairingSecret)
        }
        isDisconnectingFromOperator = false
        status = .paired(pairedHostName ?? localizedRemoteDisplayString("operator device"))
        if previousHostID != pairedHostID || previousHostName != pairedHostName {
            startOrRefreshListener()
        }

        let response = ScoreboardRemoteDisplayControlMessage(
            kind: .heartbeatAck,
            sequence: message.sequence,
            sentAt: message.sentAt,
            hostID: message.hostID,
            hostName: message.hostName,
            displayID: displayID,
            displayName: displayName,
            appVersion: ScoreboardRemoteDisplayAppVersion.current.version,
            appBuild: ScoreboardRemoteDisplayAppVersion.current.build,
            deviceType: ScoreboardRemoteDisplayDeviceType.current
        )
        sendControlMessage(response, to: [connection])
    }

    private func handleDisconnect(_ message: ScoreboardRemoteDisplayControlMessage, from connection: NWConnection) {
        guard acceptsControlMessage(message, from: connection) else {
            return
        }

        let hostName = message.hostName ?? pairedHostName ?? localizedRemoteDisplayString("operator device")
        pairedHostID = nil
        pairedHostName = nil
        pairedConnection = nil
        isDisconnectingFromOperator = true
        lastHeartbeatAt = nil
        masterClockOffset = nil
        status = .disconnected(localizedRemoteDisplayFormat("%@ disconnected this Remote Display.", hostName))
        connection.cancel()
        startOrRefreshListener()
    }

    private func handleSetMuted(_ message: ScoreboardRemoteDisplayControlMessage, from connection: NWConnection) {
        guard acceptsControlMessage(message, from: connection) else {
            return
        }

        isMuted = message.isMuted ?? false
        if isMuted {
            soundTestPlayer.stop()
        }
    }

    private func handleSoundTest(_ message: ScoreboardRemoteDisplayControlMessage, from connection: NWConnection) {
        guard acceptsControlMessage(message, from: connection), !isMuted else {
            return
        }

        soundTestPlayer.play(.whistle)
    }

    private func handleSoundEffect(_ message: ScoreboardRemoteDisplayControlMessage, from connection: NWConnection) {
        guard
            acceptsControlMessage(message, from: connection),
            !isMuted,
            let rawEffect = message.soundEffect,
            let effect = ScoreboardSoundEffect(rawValue: rawEffect),
            effect != .none
        else {
            return
        }

        soundTestPlayer.play(effect)
    }

    private func acceptsControlMessage(_ message: ScoreboardRemoteDisplayControlMessage, from connection: NWConnection) -> Bool {
        let isCurrentHost = message.hostID == nil || message.hostID == pairedHostID
        let isCurrentConnection = pairedConnection == nil || pairedConnection === connection
        let isThisDisplay = message.displayID == nil || message.displayID == displayID
        return isCurrentHost && isCurrentConnection && isThisDisplay
    }

    private func acceptsHeartbeat(_ message: ScoreboardRemoteDisplayControlMessage, from connection: NWConnection) -> Bool {
        let isThisDisplay = message.displayID == nil || message.displayID == displayID
        guard isThisDisplay else {
            return false
        }
        guard let hostID = message.hostID else {
            return pairedHostID == nil || pairedConnection === connection
        }
        if let pairedHostID {
            return hostID == pairedHostID && (pairedConnection == nil || pairedConnection === connection)
        }
        if let lastActiveOperatorID {
            return hostID == lastActiveOperatorID && trustedHosts.contains { $0.id == hostID }
        }
        return trustedHosts.contains { $0.id == hostID }
    }

    private func acceptsStateUpdate(from connection: NWConnection) -> Bool {
        guard pairedHostID != nil else {
            return false
        }
        return pairedConnection === connection
    }

    private func handleRemovePairing(_ message: ScoreboardRemoteDisplayControlMessage, from connection: NWConnection) {
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
        pairedConnection = nil
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
            message.hostName ?? localizedRemoteDisplayString("operator device")
        ))
        connection.cancel()
        pairingCode = Self.makePairingCode()
        startPairingCodeTimer()
        startOrRefreshListener()
    }

    private func sendControlMessage(
        _ message: ScoreboardRemoteDisplayControlMessage,
        to connections: [NWConnection]? = nil
    ) {
        guard let data = try? JSONEncoder().encode(message) else {
            return
        }
        let targetConnections = connections ?? pairedConnection.map { [$0] } ?? []
        guard !targetConnections.isEmpty else {
            return
        }
        for connection in targetConnections {
            ScoreboardRemoteDisplayNetworkTransport.send(data, on: connection)
        }
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

    private func trustHost(id hostID: String, name hostName: String, pairingSecret: String?) {
        guard !hostID.isEmpty, pairingSecret?.isEmpty == false else {
            return
        }

        trustedHosts.removeAll { $0.id == hostID }
        trustedHosts.append(ScoreboardRemoteDisplayTrustedPeer(id: hostID, name: hostName, pairingSecret: pairingSecret))
        trustedHosts.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        ScoreboardRemoteDisplayPairingStore.saveTrustedHosts(trustedHosts)
    }

    private func setLastActiveOperator(id operatorID: String, name operatorName: String, pairingSecret: String?) {
        guard !operatorID.isEmpty else {
            return
        }

        lastActiveOperatorID = operatorID
        lastActiveOperatorName = operatorName
        ScoreboardRemoteDisplayPairingStore.saveLastActiveOperator(
            ScoreboardRemoteDisplayTrustedPeer(id: operatorID, name: operatorName, pairingSecret: pairingSecret)
        )
    }

    private func pairingRequest(from data: Data?) -> ScoreboardRemoteDisplayPairingRequest? {
        guard let data else {
            return nil
        }
        guard
            let request = try? JSONDecoder().decode(ScoreboardRemoteDisplayPairingRequest.self, from: data),
            request.pairingSecret?.isEmpty == false,
            request.pairingCode != nil || request.trustedReconnect
        else {
            return nil
        }
        return request
    }

    private func isPairingRateLimited(hostID: String) -> Bool {
        let cutoff = Date().addingTimeInterval(-60)
        let recentAttempts = (failedPairingAttemptsByHostID[hostID] ?? []).filter { $0 >= cutoff }
        failedPairingAttemptsByHostID[hostID] = recentAttempts
        return recentAttempts.count >= 5
    }

    private func recordFailedPairingAttempt(hostID: String) {
        let cutoff = Date().addingTimeInterval(-60)
        var attempts = (failedPairingAttemptsByHostID[hostID] ?? []).filter { $0 >= cutoff }
        attempts.append(Date())
        failedPairingAttemptsByHostID[hostID] = attempts
    }

    private func clearFailedPairingAttempts(hostID: String) {
        failedPairingAttemptsByHostID.removeValue(forKey: hostID)
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
