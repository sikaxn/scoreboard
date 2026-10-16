import Foundation

/// Resolves dynamic keys without invoking Foundation's localized-string lookup
/// while a settings or remote-display view is being rendered.
/// Localizable.xcstrings currently contains only flat stringUnit translations.
nonisolated enum ScoreboardLocalization {
    // Immutable, lazily initialized once, and safe to read from network callbacks
    // as well as the main actor. Per-app language changes take effect on relaunch.
    private static let strings: [String: String] = loadStrings(bundle: .main)
    static let usesSimplifiedChinese = Bundle.main.preferredLocalizations.first?.hasPrefix("zh-Hans") == true

    static func string(_ key: String) -> String {
        guard !key.isEmpty else { return "" }
        return strings[key] ?? key
    }

    /// Session messages can arrive from a host using another language. Keep
    /// protocol text intact and localize it where it is presented, including
    /// device names and nested error details in the known message formats.
    static func remoteSessionMessage(_ message: String) -> String {
        localizedRemoteSessionMessage(message, depth: 0)
    }

    private static func localizedRemoteSessionMessage(_ message: String, depth: Int) -> String {
        if let translated = strings[message] { return translated }
        guard depth < 3 else { return message }
        for template in remoteSessionMessageTemplates {
            let parts = template.components(separatedBy: "%@")
            guard parts.count == 2, message.hasPrefix(parts[0]), message.hasSuffix(parts[1]),
                  message.count >= parts[0].count + parts[1].count else { continue }
            let argument = String(message.dropFirst(parts[0].count).dropLast(parts[1].count))
            let translated = localizedRemoteSessionMessage(argument, depth: depth + 1)
            return String(format: string(template), locale: Locale.current, translated as NSString)
        }
        return message
    }

    private static let remoteSessionMessageTemplates = [
        "Session authority could not be restored: %@",
        "Resuming host handoff to %@…",
        "Could not delete the hosted match: %@",
        "Could not recover this session: %@",
        "Session recovery could not be saved: %@",
        "Connected to %@.",
        "Waiting for %@ to connect…",
        "Host transfer failed; this device is still hosting. %@",
        "Could not resume the previous host: %@",
        "Preparing %@…",
        "Could not prepare the session: %@",
        "Cannot save incoming host handoff: %@",
        "Handoff is fenced; waiting to retry delivery to %@.",
        "Activating %@…",
        "Could not fence old host: %@",
        "Cannot activate host: %@",
        "Log synchronization will retry: %@",
        "Could not save the host's match copy: %@",
        "Host recovery failed: %@",
        "Could not remove the old host's match copy: %@"
    ]

    static func loadStrings(bundle: Bundle) -> [String: String] {
        guard let resourceURL = bundle.resourceURL else { return [:] }
        let developmentLanguage = bundle.developmentLocalization ?? "en"
        let preferredLanguage = bundle.preferredLocalizations.first ?? developmentLanguage
        var result: [String: String] = [:]
        var loadedLanguages = Set<String>()

        // More specific translations override the development-language fallback.
        for language in ["Base", developmentLanguage, preferredLanguage] {
            guard loadedLanguages.insert(language).inserted else { continue }
            let url = resourceURL
                .appendingPathComponent("\(language).lproj", isDirectory: true)
                .appendingPathComponent("Localizable.strings")
            guard let data = try? Data(contentsOf: url),
                  let table = try? PropertyListSerialization.propertyList(
                    from: data, options: [], format: nil
                  ) as? [String: String] else { continue }
            result.merge(table) { _, translated in translated }
        }
        return result
    }
}
