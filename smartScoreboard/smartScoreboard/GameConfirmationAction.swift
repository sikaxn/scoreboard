import Foundation

enum GameConfirmationAction: Identifiable {
    case openSettings
    case awardVolleyballSet(TeamSide)
    case undoVolleyballSet
    case previousPeriod
    case resetClock
    case resetShotClock
    case zeroScores
    case resetChessClocks
    case resetDebateSegment
    case resetDebateRound
    case resetDebatePrep(TeamSide)
    case resetAllPlayerFouls
    case resetAllTeamFouls
    case resetAllCards
    case resetSidePlayerFouls(TeamSide)
    case resetSideTeamFouls(TeamSide)
    case resetSideCards(TeamSide)
    case clearPlayerState(TeamSide, UUID)
    case clearPenalty(TeamSide, UUID)
    case resetSoundSettings

    var id: String {
        switch self {
        case .openSettings:
            return "openSettings"
        case .awardVolleyballSet(let side):
            return "awardVolleyballSet-\(side.rawValue)"
        case .undoVolleyballSet:
            return "undoVolleyballSet"
        case .previousPeriod:
            return "previousPeriod"
        case .resetClock:
            return "resetClock"
        case .resetShotClock:
            return "resetShotClock"
        case .zeroScores:
            return "zeroScores"
        case .resetChessClocks:
            return "resetChessClocks"
        case .resetDebateSegment:
            return "resetDebateSegment"
        case .resetDebateRound:
            return "resetDebateRound"
        case .resetDebatePrep(let side):
            return "resetDebatePrep-\(side.rawValue)"
        case .resetAllPlayerFouls:
            return "resetAllPlayerFouls"
        case .resetAllTeamFouls:
            return "resetAllTeamFouls"
        case .resetAllCards:
            return "resetAllCards"
        case .resetSidePlayerFouls(let side):
            return "resetSidePlayerFouls-\(side.rawValue)"
        case .resetSideTeamFouls(let side):
            return "resetSideTeamFouls-\(side.rawValue)"
        case .resetSideCards(let side):
            return "resetSideCards-\(side.rawValue)"
        case .clearPlayerState(let side, let playerID):
            return "clearPlayerState-\(side.rawValue)-\(playerID.uuidString)"
        case .clearPenalty(let side, let timerID):
            return "clearPenalty-\(side.rawValue)-\(timerID.uuidString)"
        case .resetSoundSettings:
            return "resetSoundSettings"
        }
    }

}
