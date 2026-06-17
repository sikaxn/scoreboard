import Foundation
import UniformTypeIdentifiers

#if ENABLE_CUSTOM_USER_PAGE
struct ScoreboardCustomWebPageHTTPResponse: Sendable {
    let contentType: String
    let body: Data
}

enum ScoreboardCustomWebPageError: LocalizedError {
    case invalidName(String)
    case invalidPath(String)

    var errorDescription: String? {
        switch self {
        case .invalidName(let name):
            return "Invalid file name: \(name)"
        case .invalidPath(let path):
            return "Invalid custom page path: \(path)"
        }
    }
}

enum ScoreboardCustomWebPage {
    private static let directoryName = ScoreboardFileStorage.customWebPageDirectoryName
    private static let indexFilename = "index.html"

    static var userVisibleDirectoryName: String {
        directoryName
    }

    static func rootDirectoryURL(create: Bool = true) throws -> URL {
        let fileManager = FileManager.default
        #if os(iOS)
        let baseDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = baseDirectory.appendingPathComponent(directoryName, isDirectory: true)
        #else
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = baseDirectory.appendingPathComponent(directoryName, isDirectory: true)
        #endif
        if create {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    static func ensureDefaultPageIfNeeded() throws {
        let root = try rootDirectoryURL(create: false)
        guard !FileManager.default.fileExists(atPath: root.path) else {
            return
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let indexURL = root.appendingPathComponent(indexFilename, isDirectory: false)
        try defaultIndexHTML.write(to: indexURL, atomically: true, encoding: .utf8)
    }

    static func deleteAll() throws {
        let root = try rootDirectoryURL(create: false)
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }

    static func response(forHTTPPath path: String) -> ScoreboardCustomWebPageHTTPResponse? {
        guard path == "/user" || path.hasPrefix("/user/") else {
            return nil
        }

        do {
            let requestedURL = try fileURL(forHTTPPath: path)
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: requestedURL.path, isDirectory: &isDirectory) else {
                return nil
            }

            let fileURL = isDirectory.boolValue
                ? requestedURL.appendingPathComponent(indexFilename, isDirectory: false)
                : requestedURL

            var fileIsDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &fileIsDirectory),
                  !fileIsDirectory.boolValue,
                  try isResolvedURLContainedInRoot(fileURL) else {
                return nil
            }

            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true else {
                return nil
            }

            return ScoreboardCustomWebPageHTTPResponse(
                contentType: contentType(for: fileURL),
                body: try Data(contentsOf: fileURL)
            )
        } catch {
            return nil
        }
    }

    private static func fileURL(forHTTPPath path: String) throws -> URL {
        let remainder: String
        if path == "/user" || path == "/user/" {
            remainder = indexFilename
        } else {
            remainder = String(path.dropFirst("/user/".count))
        }

        guard let decoded = remainder.removingPercentEncoding else {
            throw ScoreboardCustomWebPageError.invalidPath(remainder)
        }

        let relativePath = decoded.hasSuffix("/") ? decoded + indexFilename : decoded
        return try url(for: relativePath)
    }

    private static func url(for relativePath: String) throws -> URL {
        let safePath = try safeRelativePath(relativePath)
        var url = try rootDirectoryURL()
        for component in safePath.split(separator: "/").map(String.init) {
            url.appendPathComponent(component)
        }
        guard try isURLContainedInRoot(url) else {
            throw ScoreboardCustomWebPageError.invalidPath(relativePath)
        }
        return url
    }

    private static func safeRelativePath(_ path: String) throws -> String {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !parts.isEmpty else {
            throw ScoreboardCustomWebPageError.invalidPath(path)
        }
        for part in parts {
            _ = try safePathComponent(part)
        }
        return parts.joined(separator: "/")
    }

    private static func safePathComponent(_ component: String) throws -> String {
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != ".",
              trimmed != "..",
              !trimmed.contains("/"),
              !trimmed.contains("\\"),
              !trimmed.contains("\0") else {
            throw ScoreboardCustomWebPageError.invalidName(component)
        }
        return trimmed
    }

    private static func isURLContainedInRoot(_ url: URL) throws -> Bool {
        let root = try rootDirectoryURL()
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }

    private static func isResolvedURLContainedInRoot(_ url: URL) throws -> Bool {
        let root = try rootDirectoryURL().resolvingSymlinksInPath().standardizedFileURL
        let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
        let rootPath = root.path
        let path = resolvedURL.path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }

    private static func contentType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "html", "htm":
            return "text/html; charset=utf-8"
        case "css":
            return "text/css; charset=utf-8"
        case "js", "mjs":
            return "text/javascript; charset=utf-8"
        case "json", "map":
            return "application/json; charset=utf-8"
        case "svg":
            return "image/svg+xml"
        default:
            if let mimeType = UTType(filenameExtension: pathExtension)?.preferredMIMEType {
                if let type = UTType(filenameExtension: pathExtension), type.conforms(to: .text) {
                    return "\(mimeType); charset=utf-8"
                }
                return mimeType
            }
            return "application/octet-stream"
        }
    }

    private static let defaultIndexHTML = """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Smart Scoreboard Custom Page</title>
      <style>
        :root {
          color-scheme: light dark;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          background: #0f172a;
          color: #f8fafc;
        }
        body {
          min-height: 100vh;
          margin: 0;
          display: grid;
          place-items: center;
          padding: 28px;
        }
        main {
          width: min(640px, 100%);
          padding: 32px;
          border: 1px solid rgba(148, 163, 184, 0.28);
          border-radius: 8px;
          background: #111827;
        }
        h1 {
          margin: 0 0 12px;
          font-size: clamp(2.2rem, 7vw, 4.8rem);
          line-height: 1;
          letter-spacing: 0;
        }
        p {
          margin: 0;
          color: #cbd5e1;
          font-size: 1.05rem;
          line-height: 1.55;
        }
      </style>
    </head>
    <body>
      <main>
        <h1>Hello world</h1>
        <p>This is your Smart Scoreboard custom user page. Replace this index.html from Integration > Web API > Custom User Page.</p>
      </main>
    </body>
    </html>
    """
}
#endif
