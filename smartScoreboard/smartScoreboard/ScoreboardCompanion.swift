import Foundation
import Network

private func localizedCompanionString(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func localizedCompanionFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localizedCompanionString(key), locale: Locale.current, arguments: arguments)
}

nonisolated enum ScoreboardCompanionMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case tcp
    case udp
    case http

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tcp:
            return "TCP"
        case .udp:
            return "UDP"
        case .http:
            return "HTTP"
        }
    }

    var defaultPort: UInt16 {
        switch self {
        case .tcp, .udp:
            return 16759
        case .http:
            return 8000
        }
    }
}

nonisolated struct ScoreboardCompanionLocation: Equatable, Hashable, Sendable {
    var page: Int
    var row: Int
    var column: Int

    init?(rawValue: String) {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedValue = trimmedValue.replacingOccurrences(of: ":", with: "/")
        let parts = normalizedValue.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let page = Int(parts[0]),
              let row = Int(parts[1]),
              let column = Int(parts[2]),
              page > 0,
              row >= 0,
              column >= 0
        else {
            return nil
        }

        self.page = page
        self.row = row
        self.column = column
    }

    var rawValue: String {
        "\(page)/\(row)/\(column)"
    }

    var pressCommand: String {
        "LOCATION \(rawValue) PRESS"
    }

    var tcpPressCommand: String {
        "\(pressCommand)\n"
    }

    var httpPressPath: String {
        "/api/location/\(page)/\(row)/\(column)/press"
    }

    static func validationMessage(for rawValue: String) -> String? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        guard ScoreboardCompanionLocation(rawValue: trimmedValue) != nil else {
            return localizedCompanionString("Enter page:row:column. Page must be 1 or higher; row and column must be 0 or higher.")
        }

        return nil
    }
}

nonisolated enum ScoreboardCompanionSendError: LocalizedError, Equatable, Sendable {
    case missingHost
    case invalidPort
    case invalidLocation
    case permissionDenied
    case timedOut
    case httpStatus(Int)
    case network(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .missingHost:
            return localizedCompanionString("Enter the Companion IP address or host.")
        case .invalidPort:
            return localizedCompanionString("Enter a Companion port from 1 to 65535.")
        case .invalidLocation:
            return localizedCompanionString("Enter a valid Companion location in page:row:column format.")
        case .permissionDenied:
            return localizedCompanionString("Local network access is blocked for Scoreboard.")
        case .timedOut:
            return localizedCompanionString("The Companion command timed out.")
        case .httpStatus(let statusCode):
            return localizedCompanionFormat("Companion returned HTTP %d.", statusCode)
        case .network(let message), .failed(let message):
            return message
        }
    }
}

nonisolated struct ScoreboardCompanionFailureNotice: Equatable, Identifiable, Sendable {
    let id: UUID
    let message: String
    let detail: String

    init(detail: String) {
        id = UUID()
        message = localizedCompanionString("Companion command send failed")
        self.detail = detail
    }
}

nonisolated final class ScoreboardCompanionService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.ironmaple.smartscoreboard.companion", qos: .utility)
    private let timeout: TimeInterval = 3
    private let urlSession: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        urlSession = URLSession(configuration: configuration)
    }

    func sendPress(
        host rawHost: String,
        port: UInt16,
        mode: ScoreboardCompanionMode,
        location: ScoreboardCompanionLocation,
        completion: @escaping @Sendable (Result<Void, ScoreboardCompanionSendError>) -> Void
    ) {
        let host = Self.normalizedHost(rawHost)
        guard !host.isEmpty else {
            completion(.failure(.missingHost))
            return
        }
        guard port > 0 else {
            completion(.failure(.invalidPort))
            return
        }

        switch mode {
        case .tcp, .udp:
            queue.async {
                self.sendNetworkPress(host: host, port: port, mode: mode, location: location, completion: completion)
            }
        case .http:
            queue.async {
                self.sendHTTPPress(host: host, port: port, location: location, completion: completion)
            }
        }
    }

    private func sendNetworkPress(
        host: String,
        port: UInt16,
        mode: ScoreboardCompanionMode,
        location: ScoreboardCompanionLocation,
        completion: @escaping @Sendable (Result<Void, ScoreboardCompanionSendError>) -> Void
    ) {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            completion(.failure(.invalidPort))
            return
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: endpointPort,
            using: mode == .tcp ? .tcp : .udp
        )
        let payload = Data((mode == .tcp ? location.tcpPressCommand : location.pressCommand).utf8)
        var isComplete = false
        var timeoutWorkItem: DispatchWorkItem?

        func complete(_ result: Result<Void, ScoreboardCompanionSendError>) {
            guard !isComplete else {
                return
            }
            isComplete = true
            timeoutWorkItem?.cancel()
            completion(result)
            connection.cancel()
        }

        let workItem = DispatchWorkItem {
            complete(.failure(.timedOut))
        }
        timeoutWorkItem = workItem

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(
                    content: payload,
                    contentContext: .defaultMessage,
                    isComplete: true,
                    completion: .contentProcessed { error in
                        if let error {
                            complete(.failure(Self.error(for: error)))
                        } else {
                            complete(.success(()))
                        }
                    }
                )
            case .waiting(let error), .failed(let error):
                complete(.failure(Self.error(for: error)))
            default:
                break
            }
        }

        queue.asyncAfter(deadline: .now() + timeout, execute: workItem)
        connection.start(queue: queue)
    }

    private func sendHTTPPress(
        host: String,
        port: UInt16,
        location: ScoreboardCompanionLocation,
        completion: @escaping @Sendable (Result<Void, ScoreboardCompanionSendError>) -> Void
    ) {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = Int(port)
        components.path = location.httpPressPath

        guard let url = components.url else {
            completion(.failure(.network(localizedCompanionString("Enter a valid Companion HTTP host."))))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout

        let task = urlSession.dataTask(with: request) { _, response, error in
            if let error {
                completion(.failure(Self.error(for: error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.failed(localizedCompanionString("Companion returned an invalid HTTP response."))))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.httpStatus(httpResponse.statusCode)))
                return
            }

            completion(.success(()))
        }
        task.resume()
    }

    private static func normalizedHost(_ rawHost: String) -> String {
        var host = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedHost = host.lowercased()
        if (lowercasedHost.hasPrefix("http://") || lowercasedHost.hasPrefix("https://")),
           let url = URL(string: host),
           let parsedHost = url.host {
            host = parsedHost
        }
        if let pathStart = host.firstIndex(of: "/") {
            host = String(host[..<pathStart])
        }
        return host
    }

    private static func error(for error: Error) -> ScoreboardCompanionSendError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timedOut
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .dnsLookupFailed:
                return .network(urlError.localizedDescription)
            default:
                break
            }
        }

        if let nwError = error as? NWError {
            switch nwError {
            case .posix(let code):
                switch code {
                case .EACCES, .EPERM:
                    return .permissionDenied
                case .ETIMEDOUT:
                    return .timedOut
                default:
                    break
                }
            default:
                break
            }
        }

        let description = error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription
        let lowercasedDescription = description.lowercased()
        if lowercasedDescription.contains("denied") ||
            lowercasedDescription.contains("policy") ||
            lowercasedDescription.contains("localnetwork") ||
            lowercasedDescription.contains("local network") {
            return .permissionDenied
        }
        if lowercasedDescription.contains("timed out") || lowercasedDescription.contains("timeout") {
            return .timedOut
        }
        return .network(description)
    }
}
