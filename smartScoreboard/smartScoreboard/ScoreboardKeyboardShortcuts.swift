import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

nonisolated private func localizedKeyboardString(_ key: String) -> String {
    guard !key.isEmpty else {
        return ""
    }

    return NSLocalizedString(key, comment: "")
}

nonisolated private func localizedKeyboardFormat(_ key: String, _ arguments: Any...) -> String {
    scoreboardLocalizedFormat(localizedKeyboardString(key), locale: Locale.current, arguments: arguments)
}

nonisolated private func localizedKeyboardText(_ key: String) -> Text {
    Text(verbatim: localizedKeyboardString(key))
}

struct ScoreboardKeyboardShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: Int

    static let command = ScoreboardKeyboardShortcutModifiers(rawValue: 1 << 0)
    static let control = ScoreboardKeyboardShortcutModifiers(rawValue: 1 << 1)
    static let option = ScoreboardKeyboardShortcutModifiers(rawValue: 1 << 2)
    static let shift = ScoreboardKeyboardShortcutModifiers(rawValue: 1 << 3)

    var displaySymbols: String {
        var symbols = ""
        if contains(.command) { symbols += "⌘" }
        if contains(.control) { symbols += "⌃" }
        if contains(.option) { symbols += "⌥" }
        if contains(.shift) { symbols += "⇧" }
        return symbols
    }
}

struct ScoreboardKeyboardShortcut: Codable, Hashable, Sendable {
    var key: String
    var modifiers: ScoreboardKeyboardShortcutModifiers

    init(key: String, modifiers: ScoreboardKeyboardShortcutModifiers = []) {
        self.key = Self.normalizedKey(key)
        self.modifiers = modifiers
    }

    var normalized: ScoreboardKeyboardShortcut? {
        let normalizedKey = Self.normalizedKey(key)
        guard !normalizedKey.isEmpty else {
            return nil
        }
        return ScoreboardKeyboardShortcut(key: normalizedKey, modifiers: modifiers)
    }

    var displayTitle: String {
        modifiers.displaySymbols + (key == " " ? localizedKeyboardString("Space") : key)
    }

    static func normalizedKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if key == " " || trimmed.lowercased() == "space" {
            return " "
        }
        guard let scalar = trimmed.unicodeScalars.first, trimmed.unicodeScalars.count == 1 else {
            return ""
        }
        guard !CharacterSet.controlCharacters.contains(scalar) else {
            return ""
        }
        return String(scalar).uppercased()
    }
}

enum ScoreboardKeyboardShortcutGroup: String, Codable, CaseIterable, Identifiable, Sendable {
    case scoring
    case primaryTimer
    case periodAndSides
    case secondaryTimer
    case chessAndDebate
    case teamTools
    case playerView
    case hockeyPenalties
    case resetActions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scoring:
            return localizedKeyboardString("Scoring")
        case .primaryTimer:
            return localizedKeyboardString("Primary Timer")
        case .periodAndSides:
            return localizedKeyboardString("Period and Sides")
        case .secondaryTimer:
            return localizedKeyboardString("Secondary Timer")
        case .chessAndDebate:
            return localizedKeyboardString("Chess and Debate")
        case .teamTools:
            return localizedKeyboardString("Team Tools")
        case .playerView:
            return localizedKeyboardString("Player View")
        case .hockeyPenalties:
            return localizedKeyboardString("Hockey Penalties")
        case .resetActions:
            return localizedKeyboardString("Reset Actions")
        }
    }

    var systemImage: String {
        switch self {
        case .scoring:
            return "plus.forwardslash.minus"
        case .primaryTimer:
            return "timer"
        case .periodAndSides:
            return "arrow.left.arrow.right"
        case .secondaryTimer:
            return "stopwatch"
        case .chessAndDebate:
            return "person.2.wave.2"
        case .teamTools:
            return "list.bullet.clipboard"
        case .playerView:
            return "person.crop.rectangle.stack"
        case .hockeyPenalties:
            return "exclamationmark.octagon"
        case .resetActions:
            return "arrow.counterclockwise"
        }
    }
}

enum ScoreboardKeyboardShortcutAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case homeScorePrimary
    case homeScoreSecondary
    case homeScoreTertiary
    case homeScoreMinusOne
    case guestScorePrimary
    case guestScoreSecondary
    case guestScoreTertiary
    case guestScoreMinusOne

    case togglePrimaryTimer
    case primaryTimerMinusMinute
    case primaryTimerPlusMinute
    case primaryTimerMinusSecond
    case primaryTimerPlusSecond

    case previousPeriod
    case nextPeriod
    case swapSides
    case homeWinsPeriod
    case guestWinsPeriod
    case undoPeriodWin

    case secondaryTimerPrimary
    case secondaryTimerReset
    case secondaryTimerMinusSecond
    case secondaryTimerPlusSecond
    case homeSecondaryPrimary
    case homeSecondaryAlternate
    case guestSecondaryPrimary
    case guestSecondaryAlternate

    case switchActiveSide
    case homeTurnHere
    case guestTurnHere
    case homeClockMinusMinute
    case homeClockPlusMinute
    case homeClockMinusSecond
    case homeClockPlusSecond
    case guestClockMinusMinute
    case guestClockPlusMinute
    case guestClockMinusSecond
    case guestClockPlusSecond
    case previousDebateSegment
    case nextDebateSegment
    case returnToDebateSegment
    case toggleHomePrep
    case toggleGuestPrep
    case homePrepMinusFifteen
    case homePrepPlusFifteen
    case guestPrepMinusFifteen
    case guestPrepPlusFifteen

    case homeSubstitutionMinus
    case homeSubstitutionPlus
    case guestSubstitutionMinus
    case guestSubstitutionPlus
    case homePauseMinus
    case homePausePlus
    case guestPauseMinus
    case guestPausePlus
    case homeTeamFoulMinus
    case homeTeamFoulPlus
    case guestTeamFoulMinus
    case guestTeamFoulPlus

    case togglePlayersPage

    case homePenaltyTwoMinutes
    case homePenaltyFourMinutes
    case homePenaltyFiveMinutes
    case guestPenaltyTwoMinutes
    case guestPenaltyFourMinutes
    case guestPenaltyFiveMinutes

    case resetPrimaryTimer
    case resetSecondaryTimer
    case zeroScores
    case resetChessClocks
    case resetDebateSegment
    case resetDebateRound
    case resetHomePrep
    case resetGuestPrep
    case resetAllPlayerFouls
    case resetAllTeamFouls
    case resetAllCards

    var id: String { rawValue }

    var group: ScoreboardKeyboardShortcutGroup {
        switch self {
        case .homeScorePrimary, .homeScoreSecondary, .homeScoreTertiary, .homeScoreMinusOne,
             .guestScorePrimary, .guestScoreSecondary, .guestScoreTertiary, .guestScoreMinusOne:
            return .scoring
        case .togglePrimaryTimer, .primaryTimerMinusMinute, .primaryTimerPlusMinute, .primaryTimerMinusSecond, .primaryTimerPlusSecond:
            return .primaryTimer
        case .previousPeriod, .nextPeriod, .swapSides, .homeWinsPeriod, .guestWinsPeriod, .undoPeriodWin:
            return .periodAndSides
        case .secondaryTimerPrimary, .secondaryTimerReset, .secondaryTimerMinusSecond, .secondaryTimerPlusSecond,
             .homeSecondaryPrimary, .homeSecondaryAlternate, .guestSecondaryPrimary, .guestSecondaryAlternate:
            return .secondaryTimer
        case .switchActiveSide, .homeTurnHere, .guestTurnHere,
             .homeClockMinusMinute, .homeClockPlusMinute, .homeClockMinusSecond, .homeClockPlusSecond,
             .guestClockMinusMinute, .guestClockPlusMinute, .guestClockMinusSecond, .guestClockPlusSecond,
             .previousDebateSegment, .nextDebateSegment, .returnToDebateSegment,
             .toggleHomePrep, .toggleGuestPrep, .homePrepMinusFifteen, .homePrepPlusFifteen,
             .guestPrepMinusFifteen, .guestPrepPlusFifteen:
            return .chessAndDebate
        case .homeSubstitutionMinus, .homeSubstitutionPlus, .guestSubstitutionMinus, .guestSubstitutionPlus,
             .homePauseMinus, .homePausePlus, .guestPauseMinus, .guestPausePlus,
             .homeTeamFoulMinus, .homeTeamFoulPlus, .guestTeamFoulMinus, .guestTeamFoulPlus:
            return .teamTools
        case .togglePlayersPage:
            return .playerView
        case .homePenaltyTwoMinutes, .homePenaltyFourMinutes, .homePenaltyFiveMinutes,
             .guestPenaltyTwoMinutes, .guestPenaltyFourMinutes, .guestPenaltyFiveMinutes:
            return .hockeyPenalties
        case .resetPrimaryTimer, .resetSecondaryTimer, .zeroScores, .resetChessClocks,
             .resetDebateSegment, .resetDebateRound, .resetHomePrep, .resetGuestPrep,
             .resetAllPlayerFouls, .resetAllTeamFouls, .resetAllCards:
            return .resetActions
        }
    }

    func title(store: ScoreboardStore) -> String {
        switch self {
        case .homeScorePrimary:
            return scoreTitle(side: .home, slot: 0, store: store)
        case .homeScoreSecondary:
            return scoreTitle(side: .home, slot: 1, store: store)
        case .homeScoreTertiary:
            return scoreTitle(side: .home, slot: 2, store: store)
        case .homeScoreMinusOne:
            return localizedKeyboardFormat("%@ Score -1", store.sideRoleLabel(for: .home))
        case .guestScorePrimary:
            return scoreTitle(side: .guest, slot: 0, store: store)
        case .guestScoreSecondary:
            return scoreTitle(side: .guest, slot: 1, store: store)
        case .guestScoreTertiary:
            return scoreTitle(side: .guest, slot: 2, store: store)
        case .guestScoreMinusOne:
            return localizedKeyboardFormat("%@ Score -1", store.sideRoleLabel(for: .guest))
        case .togglePrimaryTimer:
            return localizedKeyboardString("Toggle Primary Timer")
        case .primaryTimerMinusMinute:
            return localizedKeyboardFormat("%@ -1 Min", localizedKeyboardString("Primary Timer"))
        case .primaryTimerPlusMinute:
            return localizedKeyboardFormat("%@ +1 Min", localizedKeyboardString("Primary Timer"))
        case .primaryTimerMinusSecond:
            return localizedKeyboardFormat("%@ -1 Sec", localizedKeyboardString("Primary Timer"))
        case .primaryTimerPlusSecond:
            return localizedKeyboardFormat("%@ +1 Sec", localizedKeyboardString("Primary Timer"))
        case .previousPeriod:
            return localizedKeyboardFormat("Previous %@", localizedKeyboardString(store.periodTitle))
        case .nextPeriod:
            return localizedKeyboardFormat("Next %@", localizedKeyboardString(store.periodTitle))
        case .swapSides:
            return localizedKeyboardString("Swap Sides")
        case .homeWinsPeriod:
            return localizedKeyboardFormat("%@ Wins Period", store.sideRoleLabel(for: .home))
        case .guestWinsPeriod:
            return localizedKeyboardFormat("%@ Wins Period", store.sideRoleLabel(for: .guest))
        case .undoPeriodWin:
            return localizedKeyboardString("Undo Period Win")
        case .secondaryTimerPrimary:
            return localizedKeyboardFormat("%@ Primary Action", store.secondaryTimerTitle)
        case .secondaryTimerReset:
            return localizedKeyboardFormat("Reset %@", store.secondaryTimerTitle)
        case .secondaryTimerMinusSecond:
            return localizedKeyboardFormat("%@ -1 Sec", store.secondaryTimerTitle)
        case .secondaryTimerPlusSecond:
            return localizedKeyboardFormat("%@ +1 Sec", store.secondaryTimerTitle)
        case .homeSecondaryPrimary:
            return secondaryTimerSideTitle(side: .home, alternate: false, store: store)
        case .homeSecondaryAlternate:
            return secondaryTimerSideTitle(side: .home, alternate: true, store: store)
        case .guestSecondaryPrimary:
            return secondaryTimerSideTitle(side: .guest, alternate: false, store: store)
        case .guestSecondaryAlternate:
            return secondaryTimerSideTitle(side: .guest, alternate: true, store: store)
        case .switchActiveSide:
            return localizedKeyboardString("Switch Active Side")
        case .homeTurnHere:
            return localizedKeyboardFormat("%@ Turn Here", store.sideRoleLabel(for: .home))
        case .guestTurnHere:
            return localizedKeyboardFormat("%@ Turn Here", store.sideRoleLabel(for: .guest))
        case .homeClockMinusMinute:
            return localizedKeyboardFormat("%@ -1 Min", store.sideRoleLabel(for: .home))
        case .homeClockPlusMinute:
            return localizedKeyboardFormat("%@ +1 Min", store.sideRoleLabel(for: .home))
        case .homeClockMinusSecond:
            return localizedKeyboardFormat("%@ -1 Sec", store.sideRoleLabel(for: .home))
        case .homeClockPlusSecond:
            return localizedKeyboardFormat("%@ +1 Sec", store.sideRoleLabel(for: .home))
        case .guestClockMinusMinute:
            return localizedKeyboardFormat("%@ -1 Min", store.sideRoleLabel(for: .guest))
        case .guestClockPlusMinute:
            return localizedKeyboardFormat("%@ +1 Min", store.sideRoleLabel(for: .guest))
        case .guestClockMinusSecond:
            return localizedKeyboardFormat("%@ -1 Sec", store.sideRoleLabel(for: .guest))
        case .guestClockPlusSecond:
            return localizedKeyboardFormat("%@ +1 Sec", store.sideRoleLabel(for: .guest))
        case .previousDebateSegment:
            return localizedKeyboardString("Previous Segment")
        case .nextDebateSegment:
            return localizedKeyboardString("Next Segment")
        case .returnToDebateSegment:
            return localizedKeyboardString("Return to Segment")
        case .toggleHomePrep:
            return localizedKeyboardFormat("Toggle %@ Prep", store.sideRoleLabel(for: .home))
        case .toggleGuestPrep:
            return localizedKeyboardFormat("Toggle %@ Prep", store.sideRoleLabel(for: .guest))
        case .homePrepMinusFifteen:
            return localizedKeyboardFormat("%@ Prep -15 Sec", store.sideRoleLabel(for: .home))
        case .homePrepPlusFifteen:
            return localizedKeyboardFormat("%@ Prep +15 Sec", store.sideRoleLabel(for: .home))
        case .guestPrepMinusFifteen:
            return localizedKeyboardFormat("%@ Prep -15 Sec", store.sideRoleLabel(for: .guest))
        case .guestPrepPlusFifteen:
            return localizedKeyboardFormat("%@ Prep +15 Sec", store.sideRoleLabel(for: .guest))
        case .homeSubstitutionMinus:
            return localizedKeyboardFormat("%@ Substitution -1", store.sideRoleLabel(for: .home))
        case .homeSubstitutionPlus:
            return localizedKeyboardFormat("%@ Substitution +1", store.sideRoleLabel(for: .home))
        case .guestSubstitutionMinus:
            return localizedKeyboardFormat("%@ Substitution -1", store.sideRoleLabel(for: .guest))
        case .guestSubstitutionPlus:
            return localizedKeyboardFormat("%@ Substitution +1", store.sideRoleLabel(for: .guest))
        case .homePauseMinus:
            return localizedKeyboardFormat("%@ Pause -1", store.sideRoleLabel(for: .home))
        case .homePausePlus:
            return localizedKeyboardFormat("%@ Pause +1", store.sideRoleLabel(for: .home))
        case .guestPauseMinus:
            return localizedKeyboardFormat("%@ Pause -1", store.sideRoleLabel(for: .guest))
        case .guestPausePlus:
            return localizedKeyboardFormat("%@ Pause +1", store.sideRoleLabel(for: .guest))
        case .homeTeamFoulMinus:
            return localizedKeyboardFormat("%@ Team Foul -1", store.sideRoleLabel(for: .home))
        case .homeTeamFoulPlus:
            return localizedKeyboardFormat("%@ Team Foul +1", store.sideRoleLabel(for: .home))
        case .guestTeamFoulMinus:
            return localizedKeyboardFormat("%@ Team Foul -1", store.sideRoleLabel(for: .guest))
        case .guestTeamFoulPlus:
            return localizedKeyboardFormat("%@ Team Foul +1", store.sideRoleLabel(for: .guest))
        case .togglePlayersPage:
            return localizedKeyboardString("Toggle Players Page")
        case .homePenaltyTwoMinutes:
            return localizedKeyboardFormat("%@ Penalty 2 Min", store.sideRoleLabel(for: .home))
        case .homePenaltyFourMinutes:
            return localizedKeyboardFormat("%@ Penalty 4 Min", store.sideRoleLabel(for: .home))
        case .homePenaltyFiveMinutes:
            return localizedKeyboardFormat("%@ Penalty 5 Min", store.sideRoleLabel(for: .home))
        case .guestPenaltyTwoMinutes:
            return localizedKeyboardFormat("%@ Penalty 2 Min", store.sideRoleLabel(for: .guest))
        case .guestPenaltyFourMinutes:
            return localizedKeyboardFormat("%@ Penalty 4 Min", store.sideRoleLabel(for: .guest))
        case .guestPenaltyFiveMinutes:
            return localizedKeyboardFormat("%@ Penalty 5 Min", store.sideRoleLabel(for: .guest))
        case .resetPrimaryTimer:
            return localizedKeyboardString("Reset Primary Timer")
        case .resetSecondaryTimer:
            return localizedKeyboardString("Reset Secondary Timer")
        case .zeroScores:
            return localizedKeyboardString("Zero Scores")
        case .resetChessClocks:
            return localizedKeyboardString("Reset Chess Clocks")
        case .resetDebateSegment:
            return localizedKeyboardString("Reset Debate Segment")
        case .resetDebateRound:
            return localizedKeyboardString("Reset Debate Round")
        case .resetHomePrep:
            return localizedKeyboardFormat("Reset %@ Prep", store.sideRoleLabel(for: .home))
        case .resetGuestPrep:
            return localizedKeyboardFormat("Reset %@ Prep", store.sideRoleLabel(for: .guest))
        case .resetAllPlayerFouls:
            return localizedKeyboardString("Reset All Player Fouls")
        case .resetAllTeamFouls:
            return localizedKeyboardString("Reset All Team Fouls")
        case .resetAllCards:
            return localizedKeyboardString("Reset All Cards")
        }
    }

    func isAvailable(
        store: ScoreboardStore,
        isResetInterlockActive: Bool,
        isGameClockResetInterlockActive: Bool
    ) -> Bool {
        switch self {
        case .homeScorePrimary, .guestScorePrimary:
            return shortcutScoreStep(store: store, slot: 0) != nil
        case .homeScoreSecondary, .guestScoreSecondary:
            return shortcutScoreStep(store: store, slot: 1) != nil
        case .homeScoreTertiary, .guestScoreTertiary:
            return shortcutScoreStep(store: store, slot: 2) != nil
        case .homeScoreMinusOne, .guestScoreMinusOne:
            return store.supportsScore
        case .togglePrimaryTimer:
            return store.showsGameClock || store.usesChessClocks || store.isDebateMode
        case .primaryTimerMinusMinute, .primaryTimerPlusMinute, .primaryTimerMinusSecond, .primaryTimerPlusSecond:
            return store.isDebateMode || (store.showsGameClock && !store.usesChessClocks)
        case .previousPeriod:
            return store.supportsPeriod && !store.supportsPeriodWinTracking && !isGameClockResetInterlockActive
        case .nextPeriod:
            return store.supportsPeriod && !store.supportsPeriodWinTracking
        case .swapSides:
            return true
        case .homeWinsPeriod, .guestWinsPeriod:
            return store.supportsPeriodWinTracking && store.periodWinMatchWinner == nil
        case .undoPeriodWin:
            return store.supportsPeriodWinTracking && !store.volleyballSetResults.isEmpty && !isResetInterlockActive
        case .secondaryTimerPrimary, .secondaryTimerReset, .secondaryTimerMinusSecond, .secondaryTimerPlusSecond,
             .homeSecondaryPrimary, .guestSecondaryPrimary:
            return store.supportsShotClock
        case .homeSecondaryAlternate, .guestSecondaryAlternate:
            return store.supportsShotClock && !store.usesServeTimer
        case .switchActiveSide, .homeTurnHere, .guestTurnHere,
             .homeClockMinusMinute, .homeClockPlusMinute, .homeClockMinusSecond, .homeClockPlusSecond,
             .guestClockMinusMinute, .guestClockPlusMinute, .guestClockMinusSecond, .guestClockPlusSecond:
            return store.usesChessClocks
        case .previousDebateSegment, .nextDebateSegment:
            return store.isDebateMode
        case .returnToDebateSegment:
            return store.isDebateMode && store.debateActiveTimer != .segment
        case .toggleHomePrep, .toggleGuestPrep, .homePrepMinusFifteen, .homePrepPlusFifteen,
             .guestPrepMinusFifteen, .guestPrepPlusFifteen, .resetHomePrep, .resetGuestPrep:
            return store.showsDebatePrepTime
        case .homeSubstitutionMinus, .homeSubstitutionPlus, .guestSubstitutionMinus, .guestSubstitutionPlus:
            return store.showsSubstitutionTracking
        case .homePauseMinus, .homePausePlus, .guestPauseMinus, .guestPausePlus:
            return store.showsPauseTracking
        case .homeTeamFoulMinus, .homeTeamFoulPlus, .guestTeamFoulMinus, .guestTeamFoulPlus:
            return store.supportsTeamFouls
        case .togglePlayersPage:
            return store.isPlayerTrackingEnabled
        case .homePenaltyTwoMinutes, .homePenaltyFourMinutes, .homePenaltyFiveMinutes,
             .guestPenaltyTwoMinutes, .guestPenaltyFourMinutes, .guestPenaltyFiveMinutes:
            return store.supportsHockeyPenalties
        case .resetPrimaryTimer:
            return store.showsGameClock && !store.usesChessClocks && !store.isDebateMode && !isGameClockResetInterlockActive
        case .resetSecondaryTimer:
            return store.supportsShotClock
        case .zeroScores:
            return store.supportsScore && !isGameClockResetInterlockActive
        case .resetChessClocks:
            return store.usesChessClocks && !store.isDebateMode && !isResetInterlockActive
        case .resetDebateSegment, .resetDebateRound:
            return store.isDebateMode && !isResetInterlockActive
        case .resetAllPlayerFouls:
            return store.supportsFouls && !isResetInterlockActive
        case .resetAllTeamFouls:
            return store.supportsTeamFouls && !isResetInterlockActive
        case .resetAllCards:
            return store.supportsCards && !isResetInterlockActive
        }
    }

    private func scoreTitle(side: TeamSide, slot: Int, store: ScoreboardStore) -> String {
        let sideLabel = store.sideRoleLabel(for: side)
        if let step = shortcutScoreStep(store: store, slot: slot) {
            return localizedKeyboardFormat("%@ Score +%d", sideLabel, step)
        }
        return localizedKeyboardFormat("%@ Score Slot %d", sideLabel, slot + 1)
    }

    private func secondaryTimerSideTitle(side: TeamSide, alternate: Bool, store: ScoreboardStore) -> String {
        let sideLabel = store.sideRoleLabel(for: side)
        if store.usesServeTimer {
            return localizedKeyboardFormat("%@ Serve Here", sideLabel)
        }
        return localizedKeyboardFormat(alternate ? "%@ Shot 14" : "%@ Shot 24", sideLabel)
    }
}

#if !os(tvOS)
struct ScoreboardKeyboardShortcutExecutionContext {
    let store: ScoreboardStore
    let isResetInterlockActive: Bool
    let isGameClockResetInterlockActive: Bool
    let requestGameConfirmation: (GameConfirmationAction) -> Void
    let adjustDebateSegmentTimer: (Int) -> Void
    let handleDebateTurnHere: (TeamSide) -> Void
    let addPenaltyTimer: (TeamSide, Int) -> Void
    let togglePlayersPage: () -> Void

    func perform(_ action: ScoreboardKeyboardShortcutAction) {
        guard action.isAvailable(
            store: store,
            isResetInterlockActive: isResetInterlockActive,
            isGameClockResetInterlockActive: isGameClockResetInterlockActive
        ) else {
            return
        }

        switch action {
        case .homeScorePrimary:
            adjustShortcutScore(for: .home, slot: 0)
        case .homeScoreSecondary:
            adjustShortcutScore(for: .home, slot: 1)
        case .homeScoreTertiary:
            adjustShortcutScore(for: .home, slot: 2)
        case .homeScoreMinusOne:
            store.adjustScore(isHome: true, by: -1)
        case .guestScorePrimary:
            adjustShortcutScore(for: .guest, slot: 0)
        case .guestScoreSecondary:
            adjustShortcutScore(for: .guest, slot: 1)
        case .guestScoreTertiary:
            adjustShortcutScore(for: .guest, slot: 2)
        case .guestScoreMinusOne:
            store.adjustScore(isHome: false, by: -1)
        case .togglePrimaryTimer:
            if store.isDebateMode, store.debateActiveTimer != .segment {
                store.returnToDebateSegmentTimer()
            } else {
                store.toggleClock()
            }
        case .primaryTimerMinusMinute:
            adjustShortcutPrimaryTimer(by: -60)
        case .primaryTimerPlusMinute:
            adjustShortcutPrimaryTimer(by: 60)
        case .primaryTimerMinusSecond:
            adjustShortcutPrimaryTimer(by: -1)
        case .primaryTimerPlusSecond:
            adjustShortcutPrimaryTimer(by: 1)
        case .previousPeriod:
            requestGameConfirmation(.previousPeriod)
        case .nextPeriod:
            store.adjustPeriod(by: 1)
        case .swapSides:
            store.swapSides()
        case .homeWinsPeriod:
            requestGameConfirmation(.awardVolleyballSet(.home))
        case .guestWinsPeriod:
            requestGameConfirmation(.awardVolleyballSet(.guest))
        case .undoPeriodWin:
            requestGameConfirmation(.undoVolleyballSet)
        case .secondaryTimerPrimary:
            performSecondaryTimerPrimaryAction()
        case .secondaryTimerReset:
            requestGameConfirmation(.resetShotClock)
        case .secondaryTimerMinusSecond:
            store.adjustShotClock(by: -1)
        case .secondaryTimerPlusSecond:
            store.adjustShotClock(by: 1)
        case .homeSecondaryPrimary:
            performSecondaryTimerSideAction(.home, alternate: false)
        case .homeSecondaryAlternate:
            performSecondaryTimerSideAction(.home, alternate: true)
        case .guestSecondaryPrimary:
            performSecondaryTimerSideAction(.guest, alternate: false)
        case .guestSecondaryAlternate:
            performSecondaryTimerSideAction(.guest, alternate: true)
        case .switchActiveSide:
            store.switchChessClock()
        case .homeTurnHere:
            setShortcutActiveSide(.home)
        case .guestTurnHere:
            setShortcutActiveSide(.guest)
        case .homeClockMinusMinute:
            store.adjustChessClock(for: .home, by: -60)
        case .homeClockPlusMinute:
            store.adjustChessClock(for: .home, by: 60)
        case .homeClockMinusSecond:
            store.adjustChessClock(for: .home, by: -1)
        case .homeClockPlusSecond:
            store.adjustChessClock(for: .home, by: 1)
        case .guestClockMinusMinute:
            store.adjustChessClock(for: .guest, by: -60)
        case .guestClockPlusMinute:
            store.adjustChessClock(for: .guest, by: 60)
        case .guestClockMinusSecond:
            store.adjustChessClock(for: .guest, by: -1)
        case .guestClockPlusSecond:
            store.adjustChessClock(for: .guest, by: 1)
        case .previousDebateSegment:
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                store.advanceDebateSegment(by: -1)
            }
        case .nextDebateSegment:
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                store.advanceDebateSegment(by: 1)
            }
        case .returnToDebateSegment:
            store.returnToDebateSegmentTimer()
        case .toggleHomePrep:
            store.toggleDebatePrepClock(for: .home)
        case .toggleGuestPrep:
            store.toggleDebatePrepClock(for: .guest)
        case .homePrepMinusFifteen:
            store.adjustDebatePrepClock(for: .home, by: -15)
        case .homePrepPlusFifteen:
            store.adjustDebatePrepClock(for: .home, by: 15)
        case .guestPrepMinusFifteen:
            store.adjustDebatePrepClock(for: .guest, by: -15)
        case .guestPrepPlusFifteen:
            store.adjustDebatePrepClock(for: .guest, by: 15)
        case .homeSubstitutionMinus:
            store.adjustSubstitutionsUsed(for: .home, by: -1)
        case .homeSubstitutionPlus:
            store.adjustSubstitutionsUsed(for: .home, by: 1)
        case .guestSubstitutionMinus:
            store.adjustSubstitutionsUsed(for: .guest, by: -1)
        case .guestSubstitutionPlus:
            store.adjustSubstitutionsUsed(for: .guest, by: 1)
        case .homePauseMinus:
            store.adjustPausesUsed(for: .home, by: -1)
        case .homePausePlus:
            store.adjustPausesUsed(for: .home, by: 1)
        case .guestPauseMinus:
            store.adjustPausesUsed(for: .guest, by: -1)
        case .guestPausePlus:
            store.adjustPausesUsed(for: .guest, by: 1)
        case .homeTeamFoulMinus:
            store.adjustTeamFouls(for: .home, by: -1)
        case .homeTeamFoulPlus:
            store.adjustTeamFouls(for: .home, by: 1)
        case .guestTeamFoulMinus:
            store.adjustTeamFouls(for: .guest, by: -1)
        case .guestTeamFoulPlus:
            store.adjustTeamFouls(for: .guest, by: 1)
        case .togglePlayersPage:
            togglePlayersPage()
        case .homePenaltyTwoMinutes:
            addPenaltyTimer(.home, 120)
        case .homePenaltyFourMinutes:
            addPenaltyTimer(.home, 240)
        case .homePenaltyFiveMinutes:
            addPenaltyTimer(.home, 300)
        case .guestPenaltyTwoMinutes:
            addPenaltyTimer(.guest, 120)
        case .guestPenaltyFourMinutes:
            addPenaltyTimer(.guest, 240)
        case .guestPenaltyFiveMinutes:
            addPenaltyTimer(.guest, 300)
        case .resetPrimaryTimer:
            requestGameConfirmation(.resetClock)
        case .resetSecondaryTimer:
            requestGameConfirmation(.resetShotClock)
        case .zeroScores:
            requestGameConfirmation(.zeroScores)
        case .resetChessClocks:
            requestGameConfirmation(.resetChessClocks)
        case .resetDebateSegment:
            requestGameConfirmation(.resetDebateSegment)
        case .resetDebateRound:
            requestGameConfirmation(.resetDebateRound)
        case .resetHomePrep:
            requestGameConfirmation(.resetDebatePrep(.home))
        case .resetGuestPrep:
            requestGameConfirmation(.resetDebatePrep(.guest))
        case .resetAllPlayerFouls:
            requestGameConfirmation(.resetAllPlayerFouls)
        case .resetAllTeamFouls:
            requestGameConfirmation(.resetAllTeamFouls)
        case .resetAllCards:
            requestGameConfirmation(.resetAllCards)
        }
    }

    private func adjustShortcutScore(for side: TeamSide, slot: Int) {
        guard let step = shortcutScoreStep(store: store, slot: slot) else {
            return
        }
        store.adjustScore(isHome: side == .home, by: step)
    }

    private func adjustShortcutPrimaryTimer(by delta: Int) {
        if store.isDebateMode {
            adjustDebateSegmentTimer(delta)
        } else if store.showsGameClock, !store.usesChessClocks {
            store.adjustClock(by: delta)
        }
    }

    private func performSecondaryTimerPrimaryAction() {
        guard store.supportsShotClock else {
            return
        }

        if store.usesServeTimer || store.isShotClockRunning {
            store.toggleShotClock()
        } else {
            store.resetActiveShotClock()
        }
    }

    private func performSecondaryTimerSideAction(_ side: TeamSide, alternate: Bool) {
        guard store.supportsShotClock else {
            return
        }

        if store.usesServeTimer {
            if !alternate {
                store.setServeTimerSide(side)
            }
        } else {
            store.assignShotClock(to: alternate ? 14 : 24, forHomeTeam: side == .home)
        }
    }

    private func setShortcutActiveSide(_ side: TeamSide) {
        guard store.usesChessClocks else {
            return
        }

        if store.isDebateMode, store.currentDebateSegment?.timerMode == .dualClock {
            handleDebateTurnHere(side)
        } else {
            store.setActiveChessClockSide(side)
        }
    }
}
#endif

private func shortcutScoreStep(store: ScoreboardStore, slot: Int) -> Int? {
    guard store.supportsScore else {
        return nil
    }

    let options = store.currentRules.scoreStepOptions
    if options.isEmpty {
        return slot == 0 ? 1 : nil
    }
    guard options.indices.contains(slot) else {
        return nil
    }
    return options[slot]
}

struct KeyboardShortcutSettingsPane: View {
    @ObservedObject var store: ScoreboardStore
    let usesVerticalLayout: Bool
    let primaryColumnWidth: CGFloat
    let sectionSpacing: CGFloat
    let palette: SettingsPalette
    let destructiveTint: Color
    let destructiveText: Color
    let recordingAction: ScoreboardKeyboardShortcutAction?
    let beginRecording: (ScoreboardKeyboardShortcutAction) -> Void
    let cancelRecording: () -> Void
    let clearShortcut: (ScoreboardKeyboardShortcutAction) -> Void
    let resetDefaults: () -> Void
    let isActionAvailable: (ScoreboardKeyboardShortcutAction) -> Bool

    private func actions(for group: ScoreboardKeyboardShortcutGroup) -> [ScoreboardKeyboardShortcutAction] {
        ScoreboardKeyboardShortcutAction.allCases.filter { $0.group == group }
    }

    var body: some View {
        Group {
            if usesVerticalLayout {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    overviewColumn
                    assignmentsColumn
                }
            } else {
                HStack(alignment: .top, spacing: sectionSpacing) {
                    overviewColumn
                        .frame(width: primaryColumnWidth, alignment: .topLeading)
                    assignmentsColumn
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onDisappear(perform: cancelRecording)
    }

    private var overviewColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let recordingAction {
                recordingCard(action: recordingAction)
            }

            guidanceCard(
                title: "Live Board Only",
                message: "Keyboard shortcuts only run from the live control board while settings, alerts, sheets, and text entry are closed.",
                systemImage: "keyboard.badge.ellipsis"
            )

            guidanceCard(
                title: "Default Shortcuts",
                message: "Safe default shortcuts cover the primary timer, basic scoring, secondary timer control, home/guest secondary-timer assignment, and player-page navigation. Reset-style actions stay unassigned until you choose them.",
                systemImage: "checkmark.shield"
            )

            settingsCard(title: "Reset Actions") {
                Button(role: .destructive, action: resetDefaults) {
                    Label(localizedKeyboardString("Reset Defaults"), systemImage: "arrow.counterclockwise")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(destructiveText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(destructiveTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(localizedKeyboardString("Reset Defaults"))
            }
        }
    }

    private var assignmentsColumn: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            ForEach(ScoreboardKeyboardShortcutGroup.allCases) { group in
                let groupActions = actions(for: group)
                if !groupActions.isEmpty {
                    shortcutGroupSection(group: group, actions: groupActions)
                }
            }
        }
    }

    private func guidanceCard(title: String, message: String, systemImage: String) -> some View {
        settingsCard(title: title) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 28)

                localizedKeyboardText(message)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func recordingCard(action: ScoreboardKeyboardShortcutAction) -> some View {
        settingsCard(title: "Recording Shortcut") {
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: localizedKeyboardFormat("Press a hardware key combination for %@.", action.title(store: store)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: cancelRecording) {
                    Label(localizedKeyboardString("Cancel"), systemImage: "xmark.circle")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(palette.secondaryButtonText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(palette.secondaryButtonBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(localizedKeyboardString("Cancel"))
            }
        }
    }

    private func shortcutGroupSection(
        group: ScoreboardKeyboardShortcutGroup,
        actions: [ScoreboardKeyboardShortcutAction]
    ) -> some View {
        settingsCard(title: group.title) {
            LazyVStack(spacing: 0) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    shortcutRow(action)

                    if index < actions.count - 1 {
                        divider
                    }
                }
            }
        } headerIcon: {
            Image(systemName: group.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 24)
        }
    }

    @ViewBuilder
    private func shortcutRow(_ action: ScoreboardKeyboardShortcutAction) -> some View {
        let isRecording = recordingAction == action
        let isAvailable = isActionAvailable(action)
        let shortcut = store.keyboardShortcut(for: action)

        if usesVerticalLayout {
            VStack(alignment: .leading, spacing: 12) {
                shortcutTitleBlock(action: action, isAvailable: isAvailable)
                shortcutControls(action: action, shortcut: shortcut, isRecording: isRecording)
            }
            .padding(.vertical, 12)
        } else {
            HStack(alignment: .center, spacing: 14) {
                shortcutTitleBlock(action: action, isAvailable: isAvailable)
                Spacer(minLength: 12)
                shortcutControls(action: action, shortcut: shortcut, isRecording: isRecording)
            }
            .padding(.vertical, 12)
        }
    }

    private func shortcutTitleBlock(action: ScoreboardKeyboardShortcutAction, isAvailable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: action.title(store: store))
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: localizedKeyboardString(isAvailable ? "Available" : "Unavailable for Current Game"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isAvailable ? palette.accent : palette.secondaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    isAvailable ? palette.accent.opacity(0.13) : palette.fieldBackground,
                    in: Capsule()
                )
        }
    }

    private func shortcutControls(
        action: ScoreboardKeyboardShortcutAction,
        shortcut: ScoreboardKeyboardShortcut?,
        isRecording: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: shortcut?.displayTitle ?? localizedKeyboardString("Unassigned"))
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .foregroundStyle(shortcut == nil ? palette.secondaryText : palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 104, alignment: .center)
                .padding(.vertical, 9)
                .background(palette.fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                if isRecording {
                    cancelRecording()
                } else {
                    beginRecording(action)
                }
            } label: {
                Label(
                    localizedKeyboardString(isRecording ? "Cancel" : "Record"),
                    systemImage: isRecording ? "xmark.circle.fill" : "keyboard"
                )
                .font(.callout.weight(.semibold))
                .foregroundStyle(isRecording ? destructiveText : palette.accentText)
                .frame(minWidth: 92)
                .padding(.vertical, 9)
                .padding(.horizontal, 12)
                .background(
                    isRecording ? destructiveTint : palette.accent,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .help(localizedKeyboardString(isRecording ? "Cancel" : "Record"))

            Button {
                clearShortcut(action)
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(shortcut == nil ? palette.secondaryText : destructiveText)
                    .frame(width: 38, height: 38)
                    .background(
                        shortcut == nil ? palette.fieldBackground : destructiveTint,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(shortcut == nil)
            .opacity(shortcut == nil ? 0.46 : 1)
            .help(localizedKeyboardString("Clear"))
        }
        .frame(maxWidth: usesVerticalLayout ? .infinity : nil, alignment: .trailing)
    }

    private func settingsCard<Content: View, HeaderIcon: View>(
        title: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder headerIcon: () -> HeaderIcon
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                headerIcon()
                localizedKeyboardText(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            content()
        }
        .padding(16)
        .background(palette.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(palette.cardBorder)
        )
    }

    private func settingsCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        settingsCard(title: title, content: content) {
            EmptyView()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.divider)
            .frame(height: 1)
    }
}

extension View {
    func scoreboardKeyboardShortcuts(
        isEnabled: Bool,
        assignments: [ScoreboardKeyboardShortcutAction: ScoreboardKeyboardShortcut],
        recordingAction: Binding<ScoreboardKeyboardShortcutAction?>,
        recordShortcut: @escaping (ScoreboardKeyboardShortcutAction, ScoreboardKeyboardShortcut) -> Void,
        performAction: @escaping (ScoreboardKeyboardShortcutAction) -> Void
    ) -> some View {
        modifier(ScoreboardKeyboardShortcutModifier(
            isEnabled: isEnabled,
            assignments: assignments,
            recordingAction: recordingAction,
            recordShortcut: recordShortcut,
            performAction: performAction
        ))
    }
}

private struct ScoreboardKeyboardShortcutModifier: ViewModifier {
    let isEnabled: Bool
    let assignments: [ScoreboardKeyboardShortcutAction: ScoreboardKeyboardShortcut]
    @Binding var recordingAction: ScoreboardKeyboardShortcutAction?
    let recordShortcut: (ScoreboardKeyboardShortcutAction, ScoreboardKeyboardShortcut) -> Void
    let performAction: (ScoreboardKeyboardShortcutAction) -> Void

    func body(content: Content) -> some View {
        content
            .background(
                ScoreboardKeyboardShortcutPlatformHost(
                    isEnabled: isEnabled,
                    assignments: assignments,
                    recordingAction: $recordingAction,
                    recordShortcut: recordShortcut,
                    performAction: performAction
                )
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
            )
    }
}

private struct ScoreboardKeyboardShortcutPlatformHost: View {
    let isEnabled: Bool
    let assignments: [ScoreboardKeyboardShortcutAction: ScoreboardKeyboardShortcut]
    @Binding var recordingAction: ScoreboardKeyboardShortcutAction?
    let recordShortcut: (ScoreboardKeyboardShortcutAction, ScoreboardKeyboardShortcut) -> Void
    let performAction: (ScoreboardKeyboardShortcutAction) -> Void

    var body: some View {
        #if os(macOS)
        MacKeyboardShortcutHost(
            isEnabled: isEnabled,
            assignments: assignments,
            recordingAction: $recordingAction,
            recordShortcut: recordShortcut,
            performAction: performAction
        )
        #elseif os(iOS)
        IOSKeyboardShortcutHost(
            isEnabled: isEnabled,
            assignments: assignments,
            recordingAction: $recordingAction,
            recordShortcut: recordShortcut,
            performAction: performAction
        )
        #else
        EmptyView()
        #endif
    }
}

private extension ScoreboardKeyboardShortcutPlatformHost {
    func handle(_ shortcut: ScoreboardKeyboardShortcut) -> Bool {
        guard let normalizedShortcut = shortcut.normalized else {
            return false
        }

        if let action = recordingAction {
            recordShortcut(action, normalizedShortcut)
            recordingAction = nil
            return true
        }

        guard isEnabled else {
            return false
        }

        guard let action = ScoreboardKeyboardShortcutAction.allCases.first(where: {
            assignments[$0]?.normalized == normalizedShortcut
        }) else {
            return false
        }

        performAction(action)
        return true
    }
}

#if os(macOS)
private struct MacKeyboardShortcutHost: NSViewRepresentable {
    let isEnabled: Bool
    let assignments: [ScoreboardKeyboardShortcutAction: ScoreboardKeyboardShortcut]
    @Binding var recordingAction: ScoreboardKeyboardShortcutAction?
    let recordShortcut: (ScoreboardKeyboardShortcutAction, ScoreboardKeyboardShortcut) -> Void
    let performAction: (ScoreboardKeyboardShortcutAction) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(host: self)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.installMonitorIfNeeded()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.host = self
        context.coordinator.installMonitorIfNeeded()
    }

    final class Coordinator {
        var host: MacKeyboardShortcutHost
        private var monitor: Any?

        init(host: MacKeyboardShortcutHost) {
            self.host = host
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func installMonitorIfNeeded() {
            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else {
                    return event
                }
                return handle(event) ? nil : event
            }
        }

        private func handle(_ event: NSEvent) -> Bool {
            guard !event.isARepeat, let shortcut = ScoreboardKeyboardShortcut(event: event) else {
                return false
            }

            return host.platformHost.handle(shortcut)
        }
    }

    private var platformHost: ScoreboardKeyboardShortcutPlatformHost {
        ScoreboardKeyboardShortcutPlatformHost(
            isEnabled: isEnabled,
            assignments: assignments,
            recordingAction: $recordingAction,
            recordShortcut: recordShortcut,
            performAction: performAction
        )
    }
}

private extension ScoreboardKeyboardShortcut {
    init?(event: NSEvent) {
        guard let key = event.charactersIgnoringModifiers else {
            return nil
        }
        self.init(
            key: key,
            modifiers: ScoreboardKeyboardShortcutModifiers(event.modifierFlags)
        )
        guard normalized != nil else {
            return nil
        }
    }
}

private extension ScoreboardKeyboardShortcutModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        var modifiers: ScoreboardKeyboardShortcutModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        self = modifiers
    }
}
#endif

#if os(iOS)
private struct IOSKeyboardShortcutHost: UIViewRepresentable {
    let isEnabled: Bool
    let assignments: [ScoreboardKeyboardShortcutAction: ScoreboardKeyboardShortcut]
    @Binding var recordingAction: ScoreboardKeyboardShortcutAction?
    let recordShortcut: (ScoreboardKeyboardShortcutAction, ScoreboardKeyboardShortcut) -> Void
    let performAction: (ScoreboardKeyboardShortcutAction) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(host: self)
    }

    func makeUIView(context: Context) -> KeyboardShortcutCaptureView {
        let view = KeyboardShortcutCaptureView(frame: .zero)
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: KeyboardShortcutCaptureView, context: Context) {
        context.coordinator.host = self
        uiView.coordinator = context.coordinator

        if isEnabled || recordingAction != nil {
            uiView.becomeFirstResponder()
        } else {
            uiView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject {
        var host: IOSKeyboardShortcutHost

        init(host: IOSKeyboardShortcutHost) {
            self.host = host
        }

        func handle(_ shortcut: ScoreboardKeyboardShortcut) -> Bool {
            host.platformHost.handle(shortcut)
        }
    }

    private var platformHost: ScoreboardKeyboardShortcutPlatformHost {
        ScoreboardKeyboardShortcutPlatformHost(
            isEnabled: isEnabled,
            assignments: assignments,
            recordingAction: $recordingAction,
            recordShortcut: recordShortcut,
            performAction: performAction
        )
    }
}

private final class KeyboardShortcutCaptureView: UIView {
    weak var coordinator: IOSKeyboardShortcutHost.Coordinator?

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key,
                  let shortcut = ScoreboardKeyboardShortcut(key: key) else {
                continue
            }

            if coordinator?.handle(shortcut) == true {
                return
            }
        }

        super.pressesBegan(presses, with: event)
    }
}

private extension ScoreboardKeyboardShortcut {
    init?(key: UIKey) {
        self.init(
            key: key.charactersIgnoringModifiers,
            modifiers: ScoreboardKeyboardShortcutModifiers(key.modifierFlags)
        )
        guard normalized != nil else {
            return nil
        }
    }
}

private extension ScoreboardKeyboardShortcutModifiers {
    init(_ flags: UIKeyModifierFlags) {
        var modifiers: ScoreboardKeyboardShortcutModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.alternate) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        self = modifiers
    }
}
#endif
