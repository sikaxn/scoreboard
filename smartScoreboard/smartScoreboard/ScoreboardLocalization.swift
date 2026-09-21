import Foundation

/// Resolves dynamic keys without invoking Foundation's localized-string lookup
/// while a settings or remote-display view is being rendered.
/// Localizable.xcstrings currently contains only flat stringUnit translations.
nonisolated enum ScoreboardLocalization {
    // Immutable, lazily initialized once, and safe to read from network callbacks
    // as well as the main actor. Per-app language changes take effect on relaunch.
    private static let strings: [String: String] = loadStrings(bundle: .main)

    static func string(_ key: String) -> String {
        guard !key.isEmpty else { return "" }
        return strings[key] ?? key
    }

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
