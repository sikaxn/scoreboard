import Foundation
import Testing

private final class LocalizationTestBundle: NSObject {}

extension ScoreboardTests {
    @Test("Catalog translations preserve format placeholders and use supported flat entries")
    func localizationCatalogAndFormats() throws {
        let catalogURL = try #require(Bundle(for: LocalizationTestBundle.self)
            .url(forResource: "Localizable", withExtension: "xcstrings", subdirectory: "LocalizationCatalog"))
        let catalog = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])
        var checked = 0
        for (key, entry) in strings {
            let expected = try formatSignature(key)
            let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
            for (language, localization) in localizations {
                try #require(Set(localization.keys) == ["stringUnit"], "Unsupported localization variation: \(language): \(key)")
                let unit = try #require(localization["stringUnit"] as? [String: Any])
                let value = try #require(unit["value"] as? String)
                let actual = try formatSignature(value)
                try #require(actual == expected, "Placeholder mismatch: \(language): \(key) → \(value)")
                if !expected.isEmpty {
                    let arguments: [Any] = expected.keys.sorted().map { index in
                        switch expected[index]?.last {
                        case "@": return "Custom 100% %@ 辩论"
                        case "f", "F", "e", "E", "g", "G", "a", "A": return 1.5
                        default: return 3
                        }
                    }
                    #expect(!scoreboardLocalizedFormat(value, arguments: arguments).isEmpty)
                }
                checked += 1
            }
        }
        #expect(checked > 0)
    }

    @Test("Localized formatting supports integer ABI, positional arguments, and percent signs")
    func localizedFormatArguments() {
        let locale = Locale(identifier: "en_US_POSIX")
        #expect(scoreboardLocalizedFormat("%lld blocks · %@ speech time", locale: locale,
            arguments: [3, "04:00"]) == "3 blocks · 04:00 speech time")
        #expect(scoreboardLocalizedFormat("%2$@ / %1$lld", locale: locale,
            arguments: [3, "Custom 100% %@ 辩论"]) == "Custom 100% %@ 辩论 / 3")
        #expect(scoreboardLocalizedFormat("%lld. %@", locale: locale,
            arguments: [1, "Crossfire"]) == "1. Crossfire")
        #expect(ScoreboardLocalization.string("") == "")
        #expect(ScoreboardLocalization.string("Unknown remote 100% %@ 辩论") == "Unknown remote 100% %@ 辩论")
    }

    @Test("Localization bundles resolve English and Chinese and tolerate missing or malformed tables",
          arguments: ["English", "Chinese", "Missing", "Malformed"])
    func localizationBundleLookup(name: String) throws {
        let bundleURL = ScoreboardTestEnvironment.root.appendingPathComponent("\(name).bundle")
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        let language = name == "Chinese" ? "zh-Hans" : "en"
        let resources = bundleURL.appendingPathComponent("\(language).lproj")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": "test.scoreboard.\(name)",
            "CFBundleDevelopmentRegion": language, "CFBundleLocalizations": [language]]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: bundleURL.appendingPathComponent("Info.plist"))
        let expected = name == "Chinese" ? "已连接" : "Connected"
        if name == "English" || name == "Chinese" {
            try PropertyListSerialization.data(fromPropertyList: ["Connected": expected, "Device %@": "Device %@"],
                format: .binary, options: 0).write(to: resources.appendingPathComponent("Localizable.strings"))
        } else if name == "Malformed" {
            try Data("not a property list".utf8).write(to: resources.appendingPathComponent("Localizable.strings"))
        }
        let bundle = try #require(Bundle(path: bundleURL.path))
        let table = ScoreboardLocalization.loadStrings(bundle: bundle)
        if name == "English" || name == "Chinese" {
            #expect(table["Connected"] == expected)
            #expect(table["Device %@"] == "Device %@")
        } else {
            #expect(table.isEmpty)
        }
    }

    private func formatSignature(_ format: String) throws -> [Int: String] {
        let regex = try NSRegularExpression(pattern: #"%%|%(?:(\d+)\$)?[-+#0 ]*(?:\d+)?(?:\.\d+)?(hh|h|ll|l|q|L|z|t|j)?([@diuoxXfFeEgGaAcCsS])"#)
        var result: [Int: String] = [:]
        var sequential = 0
        for match in regex.matches(in: format, range: NSRange(format.startIndex..., in: format)) {
            func group(_ index: Int) -> String {
                guard let range = Range(match.range(at: index), in: format) else { return "" }
                return String(format[range])
            }
            if group(0) == "%%" { continue }
            let index: Int
            if let position = Int(group(1)) { index = position }
            else { sequential += 1; index = sequential }
            let type = group(2) + group(3)
            if let previous = result[index] {
                try #require(previous == type, "Conflicting argument types in \(format)")
            }
            result[index] = type
        }
        return result
    }
}
