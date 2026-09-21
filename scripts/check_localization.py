#!/usr/bin/env python3
"""Check catalog format ABI and exercise the app's actual formatter on macOS.

Run with: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/check_localization.py
No app state or localization files are modified.
"""

import json
import argparse
import plistlib
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PLACEHOLDER = re.compile(
    r"%%|%(?:(\d+)\$)?[-+#0 ]*(?:\d+)?(?:\.\d+)?"
    r"(hh|h|ll|l|q|L|z|t|j)?([@diuoxXfFeEgGaAcCsS])"
)


def signature(text):
    result = {}
    sequential = 0
    for match in PLACEHOLDER.finditer(text):
        if match[0] == "%%":
            continue
        if match[1]:
            index = int(match[1])
        else:
            sequential += 1
            index = sequential
        kind = (match[2] or "", match[3])
        if index in result and result[index] != kind:
            raise ValueError(f"Conflicting types for argument {index}: {text!r}")
        result[index] = kind
    return result


def translations(node):
    if isinstance(node, dict):
        if "stringUnit" in node:
            yield node["stringUnit"]["value"]
        for key, value in node.items():
            if key != "stringUnit":
                yield from translations(value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog-only", action="store_true", help="Validate catalog data without compiling or running Swift.")
    args = parser.parse_args()
    catalog = json.loads((ROOT / "smartScoreboard/Localizable.xcstrings").read_text())
    cases = []
    checked = 0
    for key, entry in catalog["strings"].items():
        expected = signature(key)
        for language, localization in entry.get("localizations", {}).items():
            if set(localization) != {"stringUnit"}:
                raise ValueError(f"Dynamic table lookup requires flat stringUnit translations: {language}: {key!r}")
            for value in translations(localization):
                if signature(value) != expected:
                    raise ValueError(f"Placeholder mismatch: {language}: {key!r} -> {value!r}")
                checked += 1
                if expected:
                    cases.append({"format": value, "types": [
                        expected[index][1] for index in range(1, max(expected) + 1)
                    ]})

    print(f"Validated placeholders in {checked} translations.")
    if args.catalog_only:
        return

    # Compile the existing implementation unchanged, avoiding a second copy of
    # the crash-sensitive normalization code in the regression check.
    source = (ROOT / "smartScoreboard/smartScoreboard/ScoreboardStore.swift").read_text()
    formatter = source.split("private enum ScoreboardLocalizedFormatArgumentType", 1)[1]
    formatter = "private enum ScoreboardLocalizedFormatArgumentType" + formatter.split(
        "nonisolated private func localizedStoreString", 1
    )[0]
    harness = r'''
struct FormatCase: Decodable { let format: String; let types: [String] }
let cases = try JSONDecoder().decode([FormatCase].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
for item in cases {
    let arguments: [Any] = item.types.map { type in
        switch type {
        case "@": return "Custom 100% %@ 辩论"
        case "f", "F", "e", "E", "g", "G", "a", "A": return 1.5
        default: return 3
        }
    }
    precondition(!scoreboardLocalizedFormat(item.format, arguments: arguments).isEmpty)
}
let locale = Locale(identifier: "en_US_POSIX")
precondition(scoreboardLocalizedFormat("%lld blocks · %@ speech time", locale: locale, arguments: [3, "04:00"]) == "3 blocks · 04:00 speech time")
precondition(scoreboardLocalizedFormat("%2$@ / %1$lld", locale: locale, arguments: [3, "Custom 100% %@ 辩论"]) == "Custom 100% %@ 辩论 / 3")
precondition(scoreboardLocalizedFormat("%lld. %@", locale: locale, arguments: [1, "Crossfire"]) == "1. Crossfire")
let fixtures = URL(fileURLWithPath: CommandLine.arguments[2])
for (name, expected) in [("English", "Connected"), ("Chinese", "已连接")] {
    let bundle = Bundle(path: fixtures.appendingPathComponent("\(name).bundle").path)!
    let table = ScoreboardLocalization.loadStrings(bundle: bundle)
    precondition(table["Connected"] == expected)
    precondition(table["Device %@"] == "Device %@")
}
let missingBundle = Bundle(path: fixtures.appendingPathComponent("Missing.bundle").path)!
precondition(ScoreboardLocalization.loadStrings(bundle: missingBundle).isEmpty)
let malformedBundle = Bundle(path: fixtures.appendingPathComponent("Malformed.bundle").path)!
precondition(ScoreboardLocalization.loadStrings(bundle: malformedBundle).isEmpty)
precondition(ScoreboardLocalization.string("") == "")
precondition(ScoreboardLocalization.string("Unknown remote 100% %@ 辩论") == "Unknown remote 100% %@ 辩论")
print("Formatter regression checks passed (\(cases.count) translated formats).")
print("Dynamic localization lookup checks passed.")
'''
    with tempfile.TemporaryDirectory(prefix="scoreboard-localization-") as directory:
        directory = Path(directory)
        resolver = (ROOT / "smartScoreboard/smartScoreboard/ScoreboardLocalization.swift").read_text()
        (directory / "main.swift").write_text(resolver + "\n" + formatter + harness)
        (directory / "cases.json").write_text(json.dumps(cases))
        for name, language, translated in [
            ("English", "en", "Connected"), ("Chinese", "zh-Hans", "已连接"),
            ("Missing", "en", None), ("Malformed", "en", None),
        ]:
            bundle = directory / f"{name}.bundle"
            resources = bundle / f"{language}.lproj"
            resources.mkdir(parents=True)
            (bundle / "Info.plist").write_bytes(plistlib.dumps({
                "CFBundleIdentifier": f"test.scoreboard.{name}",
                "CFBundleDevelopmentRegion": language,
                "CFBundleLocalizations": [language],
            }))
            if translated:
                (resources / "Localizable.strings").write_bytes(plistlib.dumps({
                    "Connected": translated, "Device %@": "Device %@",
                }, fmt=plistlib.FMT_BINARY))
            elif name == "Malformed":
                (resources / "Localizable.strings").write_bytes(b"not a property list")
        subprocess.run(["xcrun", "swiftc", str(directory / "main.swift"), "-o", str(directory / "check")], check=True)
        subprocess.run([str(directory / "check"), str(directory / "cases.json"), str(directory)], check=True)


if __name__ == "__main__":
    main()
