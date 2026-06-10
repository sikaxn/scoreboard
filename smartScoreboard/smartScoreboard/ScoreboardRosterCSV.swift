import Foundation

enum ScoreboardRosterCSVError: LocalizedError {
    case invalidUTF8
    case emptyFile
    case invalidHeader
    case malformedRow(Int)
    case invalidSide(String, Int)
    case invalidSlot(String, Int)
    case invalidBoolean(String, Int)
    case invalidFoulCount(String, Int)
    case invalidCardStatus(String, Int)
    case missingSide(TeamSide)

    var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "Roster CSV must be valid UTF-8 text."
        case .emptyFile:
            return "Roster CSV is empty."
        case .invalidHeader:
            return "Roster CSV header must be side,slot,number,name,isInActiveLineup,foulCount,cardStatus."
        case .malformedRow(let row):
            return "Roster CSV row \(row) does not have the expected number of columns."
        case .invalidSide(let value, let row):
            return "Roster CSV row \(row) has an invalid side value: \(value)."
        case .invalidSlot(let value, let row):
            return "Roster CSV row \(row) has an invalid slot value: \(value)."
        case .invalidBoolean(let value, let row):
            return "Roster CSV row \(row) has an invalid active lineup value: \(value)."
        case .invalidFoulCount(let value, let row):
            return "Roster CSV row \(row) has an invalid foul count: \(value)."
        case .invalidCardStatus(let value, let row):
            return "Roster CSV row \(row) has an invalid card status: \(value)."
        case .missingSide(let side):
            return "Roster CSV must include at least one \(side.rawValue) player row."
        }
    }
}

struct ImportedRosterCSV {
    var rosterSize: Int
    var homeRoster: TeamRoster
    var guestRoster: TeamRoster
}

enum ScoreboardRosterCSV {
    static let header = ["side", "slot", "number", "name", "isInActiveLineup", "foulCount", "cardStatus"]

    static func exportData(homeRoster: TeamRoster, guestRoster: TeamRoster) -> Data {
        var rows = [header]
        rows.append(contentsOf: exportRows(for: .home, roster: homeRoster))
        rows.append(contentsOf: exportRows(for: .guest, roster: guestRoster))
        let text = rows.map { $0.map(escapedField).joined(separator: ",") }.joined(separator: "\n") + "\n"
        return Data(text.utf8)
    }

    static func importData(_ data: Data) throws -> ImportedRosterCSV {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ScoreboardRosterCSVError.invalidUTF8
        }

        let rows = try parseRows(text)
            .filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        guard let headerRow = rows.first else {
            throw ScoreboardRosterCSVError.emptyFile
        }

        var normalizedHeader = headerRow.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let firstHeader = normalizedHeader.first {
            normalizedHeader[0] = firstHeader.replacingOccurrences(of: "\u{feff}", with: "")
        }
        guard normalizedHeader == header else {
            throw ScoreboardRosterCSVError.invalidHeader
        }

        var sideRows: [TeamSide: [Int: TrackedPlayer]] = [.home: [:], .guest: [:]]
        var maxSlot = 0

        for (offset, row) in rows.dropFirst().enumerated() {
            let rowNumber = offset + 2
            guard row.count == header.count else {
                throw ScoreboardRosterCSVError.malformedRow(rowNumber)
            }

            let sideValue = row[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let side = TeamSide(rawValue: sideValue) else {
                throw ScoreboardRosterCSVError.invalidSide(row[0], rowNumber)
            }

            let slotValue = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let slot = Int(slotValue), slot > 0 else {
                throw ScoreboardRosterCSVError.invalidSlot(row[1], rowNumber)
            }

            let active = try parseBoolean(row[4], rowNumber: rowNumber)
            let foulCountValue = row[5].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let foulCount = Int(foulCountValue), foulCount >= 0 else {
                throw ScoreboardRosterCSVError.invalidFoulCount(row[5], rowNumber)
            }

            let cardStatusValue = row[6].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let cardStatus = PlayerCardStatus(rawValue: cardStatusValue) else {
                throw ScoreboardRosterCSVError.invalidCardStatus(row[6], rowNumber)
            }

            sideRows[side]?[slot] = TrackedPlayer(
                number: row[2],
                name: row[3],
                foulCount: foulCount,
                cardStatus: cardStatus,
                isInActiveLineup: active
            )
            maxSlot = max(maxSlot, slot)
        }

        guard !(sideRows[.home] ?? [:]).isEmpty else {
            throw ScoreboardRosterCSVError.missingSide(.home)
        }
        guard !(sideRows[.guest] ?? [:]).isEmpty else {
            throw ScoreboardRosterCSVError.missingSide(.guest)
        }

        let rosterSize = max(
            ScoreboardStore.minRosterSize,
            min(ScoreboardStore.maxRosterSize, maxSlot)
        )

        return ImportedRosterCSV(
            rosterSize: rosterSize,
            homeRoster: roster(from: sideRows[.home] ?? [:], size: rosterSize),
            guestRoster: roster(from: sideRows[.guest] ?? [:], size: rosterSize)
        )
    }

    private static func exportRows(for side: TeamSide, roster: TeamRoster) -> [[String]] {
        roster.players.enumerated().map { index, player in
            [
                side.rawValue,
                "\(index + 1)",
                player.number,
                player.name,
                player.isInActiveLineup ? "true" : "false",
                "\(player.foulCount)",
                player.cardStatus.rawValue
            ]
        }
    }

    private static func roster(from playersBySlot: [Int: TrackedPlayer], size: Int) -> TeamRoster {
        let players = (1...size).map { slot in
            if var player = playersBySlot[slot] {
                player = TrackedPlayer(
                    number: player.number,
                    name: player.name,
                    foulCount: player.foulCount,
                    cardStatus: player.cardStatus,
                    isInActiveLineup: player.isInActiveLineup
                )
                return player
            }

            return TrackedPlayer(
                number: "\(slot)",
                isInActiveLineup: slot <= ScoreboardStore.defaultDisplayLineupSize
            )
        }
        return TeamRoster(players: players)
    }

    private static func escapedField(_ value: String) -> String {
        let needsQuotes = value.contains(",") ||
            value.contains("\"") ||
            value.contains("\n") ||
            value.contains("\r")
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }

    private static func parseBoolean(_ value: String, rowNumber: Int) throws -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1", "yes":
            return true
        case "false", "0", "no":
            return false
        default:
            throw ScoreboardRosterCSVError.invalidBoolean(value, rowNumber)
        }
    }

    private static func parseRows(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if isInQuotes {
                if character == "\"" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\"" {
                        field.append("\"")
                        index = nextIndex
                    } else {
                        isInQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    isInQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                case "\r":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                        index = nextIndex
                    }
                default:
                    field.append(character)
                }
            }

            index = text.index(after: index)
        }

        if isInQuotes {
            throw ScoreboardRosterCSVError.malformedRow(rows.count + 1)
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }
}
