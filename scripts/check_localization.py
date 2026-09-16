#!/usr/bin/env python3
"""Check catalog format ABI and exercise the app's actual formatter on macOS.

Run with: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/check_localization.py
No app state or localization files are modified.
"""

import json
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
    catalog = json.loads((ROOT / "smartScoreboard/Localizable.xcstrings").read_text())
    cases = []
    checked = 0
    for key, entry in catalog["strings"].items():
        expected = signature(key)
        for language, localization in entry.get("localizations", {}).items():
            for value in translations(localization):
                if signature(value) != expected:
                    raise ValueError(f"Placeholder mismatch: {language}: {key!r} -> {value!r}")
                checked += 1
                if expected:
                    cases.append({"format": value, "types": [
                        expected[index][1] for index in range(1, max(expected) + 1)
                    ]})

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
print("Formatter regression checks passed (\(cases.count) translated formats).")
'''
    with tempfile.TemporaryDirectory(prefix="scoreboard-localization-") as directory:
        directory = Path(directory)
        (directory / "main.swift").write_text("import Foundation\n" + formatter + harness)
        (directory / "cases.json").write_text(json.dumps(cases))
        subprocess.run(["xcrun", "swiftc", str(directory / "main.swift"), "-o", str(directory / "check")], check=True)
        subprocess.run([str(directory / "check"), str(directory / "cases.json")], check=True)
    print(f"Validated placeholders in {checked} translations.")


if __name__ == "__main__":
    main()
