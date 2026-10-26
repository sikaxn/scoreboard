import Foundation
import Testing

extension ScoreboardTests {
    @Test("Roster CSV preserves commas, quotes, line breaks, and player state")
    func rosterCSVSpecialCharacters() throws {
        let home = TrackedPlayer(number: "7", name: "Lee, \"Captain\"\nJr.", foulCount: 2,
                                 cardStatus: .yellow, isInActiveLineup: true)
        let guest = TrackedPlayer(number: "12", name: "王明", cardStatus: .red)
        let data = ScoreboardRosterCSV.exportData(
            homeRoster: TeamRoster(players: [home]), guestRoster: TeamRoster(players: [guest]))
        let imported = try ScoreboardRosterCSV.importData(data)
        let importedHome = try #require(imported.homeRoster.players.first)
        let importedGuest = try #require(imported.guestRoster.players.first)
        #expect(importedHome.number == "7" && importedHome.name == home.name)
        #expect(importedHome.foulCount == 2 && importedHome.cardStatus == .yellow)
        #expect(importedHome.isInActiveLineup)
        #expect(importedGuest.number == "12" && importedGuest.name == "王明")
        #expect(importedGuest.cardStatus == .red && !importedGuest.isInActiveLineup)
    }

    @Test("Roster CSV rejects invalid player rows", arguments: [
        "invalid,1,7,Home,true,0,none", // invalid side
        "home,0,7,Home,true,0,none", // invalid slot
        "home,1,7,Home,maybe,0,none", // invalid lineup flag
        "home,1,7,Home,true,-1,none", // negative foul count
        "home,1,7,Home,true,0,purple", // invalid card
        "home,1,7,Home" // missing columns
    ])
    func rosterCSVRejectsInvalidRows(row: String) {
        let csv = ScoreboardRosterCSV.header.joined(separator: ",") + "\n" + row
            + "\nguest,1,12,Guest,false,0,none\n"
        #expect(throws: ScoreboardRosterCSVError.self) {
            try ScoreboardRosterCSV.importData(Data(csv.utf8))
        }
    }
}
