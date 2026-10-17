import Foundation

nonisolated struct ScoreboardControlStatus: Codable, Sendable {
    let webEnabled: Bool
    let remoteEnabled: Bool
    var gameName: String? = nil
    var isSoundEnabled: Bool? = nil
    var mainDisplayMode: ScoreboardDisplayViewMode? = nil
    var customDisplayControlVisible: Bool? = nil
    var customDisplayEnabledIDs: [Int]? = nil
    var customDisplayModes: [Int: ScoreboardWebAPIBroadcastDisplayMode]? = nil
    var session: ScoreboardSessionDescriptor? = nil
    var connectedDeviceCount: Int? = nil
    var disconnectedDeviceCount: Int? = nil
    var ownerConnected: Bool? = nil
    var devices: [ScoreboardSessionPeer]? = nil
}

// Both transports use this contract. Setup and integration configuration are deliberately absent.
nonisolated struct ScoreboardControlCommand: Codable, Sendable {
    var id: UUID = UUID()
    var action: String
    var sport: SportType
    var side: TeamSide?
    var value: Int?
    var text: String?
    var enabled: Bool?
    var playerID: UUID?
    var timerID: UUID?
    var sentAt: TimeInterval?
    var expectedRunning: Bool?
}

nonisolated struct ScoreboardControlResult: Codable, Sendable {
    let id: UUID?
    let success: Bool
    let error: String?
    let message: String?

    static func failure(_ id: UUID? = nil, _ error: String, _ message: String) -> Self {
        Self(id: id, success: false, error: error, message: message)
    }
    var data: Data { (try? JSONEncoder().encode(self)) ?? Data() }
    var statusCode: Int {
        switch error {
        case nil: return 200
        case "disabled": return 403
        case "unauthorized": return 401
        case "unsupported", "stale", "conflict": return 409
        default: return 400
        }
    }
}

nonisolated struct ScoreboardControlOperation: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let parameters: [String]
    let capability: String
    let textChoices: [String]

    init(id: String, title: String, parameters: [String], capability: String) {
        self.id = id
        self.title = title
        self.parameters = parameters
        self.capability = capability
        self.textChoices = Self.textOptions(for: id)
    }

    static let all: [Self] = [
        .init(id: "score.adjust", title: "Score", parameters: ["side", "value"], capability: "supportsScore"),
        .init(id: "score.reset", title: "Reset scores", parameters: [], capability: "supportsScore"),
        .init(id: "period.adjust", title: "Period", parameters: ["value"], capability: "supportsPeriod"),
        .init(id: "period.set", title: "Set period", parameters: ["value"], capability: "supportsPeriod"),
        .init(id: "period.award", title: "Award period", parameters: ["side"], capability: "supportsPeriodWins"),
        .init(id: "period.undo", title: "Undo period win", parameters: [], capability: "supportsPeriodWins"),
        .init(id: "clock.toggle", title: "Start / pause clock", parameters: [], capability: "clock"),
        .init(id: "clock.running", title: "Set clock running", parameters: ["enabled"], capability: "clock"),
        .init(id: "clock.adjust", title: "Adjust clock seconds", parameters: ["value"], capability: "masterClock"),
        .init(id: "clock.reset", title: "Reset clock", parameters: ["value"], capability: "gameClock"),
        .init(id: "shot.toggle", title: "Start / pause shot clock", parameters: [], capability: "supportsShotClock"),
        .init(id: "shot.running", title: "Set shot clock running", parameters: ["enabled"], capability: "supportsShotClock"),
        .init(id: "shot.adjust", title: "Adjust shot seconds", parameters: ["value"], capability: "supportsShotClock"),
        .init(id: "shot.reset", title: "Reset shot clock", parameters: ["value"], capability: "supportsShotClock"),
        .init(id: "shot.activeReset", title: "Reset active shot clock", parameters: [], capability: "supportsShotClock"),
        .init(id: "shot.assign", title: "Assign shot clock", parameters: ["side", "value"], capability: "supportsShotClock"),
        .init(id: "possession.set", title: "Possession", parameters: ["text"], capability: "supportsPossession"),
        .init(id: "serve.set", title: "Serving side", parameters: ["side"], capability: "usesServeTimer"),
        .init(id: "sides.swap", title: "Swap sides", parameters: [], capability: ""),
        .init(id: "player.number", title: "Player number", parameters: ["side", "playerID", "text"], capability: "supportsPlayerTracking"),
        .init(id: "player.name", title: "Player name", parameters: ["side", "playerID", "text"], capability: "supportsPlayerTracking"),
        .init(id: "player.lineup", title: "Active lineup", parameters: ["side", "playerID", "enabled"], capability: "supportsPlayerTracking"),
        .init(id: "player.overlay", title: "Pause player overlay", parameters: [], capability: "supportsPlayerTracking"),
        .init(id: "player.foul", title: "Player fouls", parameters: ["side", "playerID", "value"], capability: "supportsFouls"),
        .init(id: "player.foulsReset", title: "Reset player fouls", parameters: ["side", "playerID"], capability: "supportsFouls"),
        .init(id: "team.playerFoulsReset", title: "Reset team player fouls", parameters: ["side"], capability: "supportsFouls"),
        .init(id: "all.playerFoulsReset", title: "Reset all player fouls", parameters: [], capability: "supportsFouls"),
        .init(id: "player.card", title: "Player card", parameters: ["side", "playerID", "text"], capability: "supportsCards"),
        .init(id: "team.cardsReset", title: "Reset team cards", parameters: ["side"], capability: "supportsCards"),
        .init(id: "all.cardsReset", title: "Reset all cards", parameters: [], capability: "supportsCards"),
        .init(id: "team.foul", title: "Team fouls", parameters: ["side", "value"], capability: "supportsTeamFouls"),
        .init(id: "team.foulsReset", title: "Reset team fouls", parameters: ["side"], capability: "supportsTeamFouls"),
        .init(id: "all.teamFoulsReset", title: "Reset all team fouls", parameters: [], capability: "supportsTeamFouls"),
        .init(id: "substitution.adjust", title: "Substitutions used", parameters: ["side", "value"], capability: "supportsSubstitutions"),
        .init(id: "pause.adjust", title: "Pauses used", parameters: ["side", "value"], capability: "supportsPauses"),
        .init(id: "pause.start", title: "Start team pause", parameters: ["side", "value"], capability: "supportsPauses"),
        .init(id: "pause.official", title: "Start official pause (0 = indefinite)", parameters: ["value"], capability: ""),
        .init(id: "pause.running", title: "Pause / continue pause timer", parameters: ["enabled"], capability: "activePause"),
        .init(id: "pause.cancel", title: "Stop pause", parameters: [], capability: "activePause"),
        .init(id: "chess.switch", title: "Switch chess clock", parameters: [], capability: "usesChessClocks"),
        .init(id: "chess.side", title: "Active chess side", parameters: ["side"], capability: "usesChessClocks"),
        .init(id: "chess.adjust", title: "Adjust chess seconds", parameters: ["side", "value"], capability: "usesChessClocks"),
        .init(id: "chess.reset", title: "Reset chess clocks", parameters: [], capability: "usesChessClocks"),
        .init(id: "debate.segment", title: "Change debate segment", parameters: ["value"], capability: "debate"),
        .init(id: "debate.resetSegment", title: "Reset debate segment", parameters: [], capability: "debate"),
        .init(id: "debate.resetRound", title: "Reset debate round", parameters: [], capability: "debate"),
        .init(id: "debate.prepToggle", title: "Start / pause prep", parameters: ["side"], capability: "prep"),
        .init(id: "debate.prepReset", title: "Reset prep", parameters: ["side"], capability: "prep"),
        .init(id: "debate.prepAdjust", title: "Adjust prep seconds", parameters: ["side", "value"], capability: "prep"),
        .init(id: "debate.return", title: "Return to segment", parameters: ["enabled"], capability: "debate"),
        .init(id: "injury.set", title: "Injury time minutes", parameters: ["value"], capability: "supportsInjuryTime"),
        .init(id: "penalty.add", title: "Add penalty", parameters: ["side", "value", "enabled"], capability: "supportsHockeyPenalties"),
        .init(id: "penalty.remove", title: "Remove penalty", parameters: ["side", "timerID"], capability: "supportsHockeyPenalties"),
        .init(id: "penalty.toggle", title: "Start / pause penalty", parameters: ["side", "timerID"], capability: "supportsHockeyPenalties"),
        .init(id: "penalty.adjust", title: "Adjust penalty seconds", parameters: ["side", "timerID", "value"], capability: "supportsHockeyPenalties"),
        .init(id: "penalty.number", title: "Penalty player number", parameters: ["side", "timerID", "text"], capability: "supportsHockeyPenalties"),
        .init(id: "penalty.name", title: "Penalty player name", parameters: ["side", "timerID", "text"], capability: "supportsHockeyPenalties"),
        .init(id: "penalty.player", title: "Assign penalty player", parameters: ["side", "timerID", "playerID"], capability: "supportsHockeyPenalties"),
        .init(id: "player.clear", title: "Clear player state", parameters: ["side", "playerID"], capability: "supportsPlayerTracking"),
        .init(id: "debate.turn", title: "Debate turn here", parameters: ["side"], capability: "debateDualClock"),
        .init(id: "display.theme", title: "Theme", parameters: ["text"], capability: ""),
        .init(id: "display.mode", title: "Display mode", parameters: ["text"], capability: ""),
        .init(id: "display.direction", title: "External display direction", parameters: ["text"], capability: ""),
        .init(id: "display.broadcast", title: "Broadcast display mode", parameters: ["value", "text"], capability: ""),
        .init(id: "sound.enabled", title: "Sound enabled", parameters: ["enabled"], capability: ""),
        .init(id: "sound.play", title: "Play sound effect", parameters: ["text"], capability: ""),
        .init(id: "game.new", title: "New game", parameters: [], capability: ""),
    ]

    func isAvailable(in state: ScoreboardWebAPIState) -> Bool {
        let r = state.rules
        switch capability {
        case "supportsScore": return r.supportsScore
        case "supportsPeriod": return r.supportsPeriod
        case "supportsPeriodWins": return r.supportsPeriodWins == true
        case "clock": return state.clocks.showsGameClock || r.usesChessClocks
        case "masterClock": return state.clocks.showsGameClock && !r.usesChessClocks
        case "gameClock": return state.debate == nil && state.clocks.showsGameClock && !r.usesChessClocks
        case "supportsShotClock": return r.supportsShotClock
        case "supportsPossession": return r.supportsPossession
        case "usesServeTimer": return r.usesServeTimer == true
        case "supportsPlayerTracking": return r.supportsPlayerTracking && state.players.isPlayerTrackingEnabled
        case "supportsFouls": return r.supportsFouls && state.players.isPlayerTrackingEnabled
        case "supportsCards": return r.supportsCards && state.players.isPlayerTrackingEnabled
        case "supportsTeamFouls": return r.supportsTeamFouls
        case "supportsSubstitutions": return r.supportsSubstitutions
        case "supportsPauses": return r.supportsPauses == true
        case "activePause": return state.clocks.pauseTimer != nil
        case "usesChessClocks": return r.usesChessClocks
        case "debateDualClock": return state.debate != nil && r.usesChessClocks
        case "debate": return state.debate != nil
        case "prep": return state.debate?.prepTimeEnabled == true
        case "supportsInjuryTime": return r.supportsInjuryTime == true
        case "supportsHockeyPenalties": return r.supportsHockeyPenalties
        default: return true
        }
    }
}

@MainActor
extension ScoreboardStore {
    func executeControlCommand(_ command: ScoreboardControlCommand, remote: Bool = false) -> ScoreboardControlResult {
        func fail(_ code: String, _ message: String) -> ScoreboardControlResult {
            .failure(command.id, code, message)
        }
        guard isSessionAuthority else { return fail("disabled", "This device is not the session host.") }
        guard command.sport == selectedSport else { return fail("conflict", "The sport changed. Refresh state before controlling.") }
        guard let operation = ScoreboardControlOperation.all.first(where: { $0.id == command.action }) else {
            return fail("invalidCommand", "Unknown operation.")
        }
        guard operation.isAvailable(in: currentWebAPIState()) else { return fail("unsupported", "Operation unavailable for the current game.") }
        for parameter in operation.parameters {
            let exists: Bool
            switch parameter {
            case "side": exists = command.side != nil
            case "value": exists = command.value != nil
            case "text": exists = command.text != nil
            case "enabled": exists = command.enabled != nil
            case "playerID": exists = command.playerID != nil
            case "timerID": exists = command.timerID != nil
            default: exists = false
            }
            guard exists else { return fail("invalidCommand", "Missing parameter: \(parameter).") }
        }
        if let value = command.value, abs(Double(value)) > 86400 { return fail("invalidCommand", "Value must be between -86400 and 86400.") }
        if let text = command.text, text.count > 200 { return fail("invalidCommand", "Text is too long.") }
        let side = command.side ?? .home
        switch command.action {
        case "pause.start", "pause.official":
            guard pauseTimer == nil else { return fail("conflict", "Cancel the current pause before starting another.") }
            guard let duration = command.value, duration >= 0,
                  duration <= Self.maxGameClockSeconds else { return fail("invalidCommand", "Invalid pause duration.") }
            if command.action == "pause.start" {
                guard supportsPauseTracking, pausesRemaining(for: side) > 0 else { return fail("conflict", "This team has no pauses remaining.") }
            }
        case "pause.running":
            guard let seconds = pauseTimer?.remainingSeconds, seconds > 0 else {
                return fail("conflict", "Only an unfinished countdown can be paused or continued.")
            }
        default: break
        }
        // No transport may restart play while a pause overlay is active.
        if pauseTimer != nil {
            let startsTimer: Bool
            switch command.action {
            case "clock.toggle", "shot.toggle", "debate.prepToggle", "penalty.toggle", "chess.switch", "chess.side", "debate.turn", "shot.assign", "serve.set", "debate.return": startsTimer = true
            case "clock.running", "shot.running", "penalty.add": startsTimer = command.enabled == true
            default: startsTimer = false
            }
            if startsTimer { return fail("conflict", "Cancel the pause before restarting play.") }
        }
        if command.action == "period.award", periodWinMatchWinner != nil {
            return fail("conflict", "This match already has a winner.")
        }
        if command.action == "period.undo", volleyballSetResults.isEmpty {
            return fail("conflict", "There is no period win to undo.")
        }
        if let id = command.playerID, !trackedPlayers(for: side).contains(where: { $0.id == id }) {
            return fail("invalidCommand", "Player no longer exists on this team.")
        }
        if let id = command.timerID, !(side == .home ? homePenaltyTimers : guestPenaltyTimers).contains(where: { $0.id == id }) {
            return fail("invalidCommand", "Penalty no longer exists on this team.")
        }
        // Validate all enum inputs before any mutation or timer compensation.
        let text = command.text ?? ""
        switch command.action {
        case "player.card": guard PlayerCardStatus(rawValue: text) != nil else { return fail("invalidCommand", "Use none, yellow or red.") }
        case "possession.set": guard PossessionDirection(rawValue: text) != nil else { return fail("invalidCommand", "Use none, home or guest.") }
        case "display.theme": guard ScoreboardTheme(rawValue: text) != nil else { return fail("invalidCommand", "Unknown theme.") }
        case "display.mode": guard ScoreboardDisplayViewMode(rawValue: text) != nil else { return fail("invalidCommand", "Unknown display mode.") }
        case "display.direction": guard ScoreboardDisplayDirection(rawValue: text) != nil else { return fail("invalidCommand", "Use homeLeft or guestLeft.") }
        case "display.broadcast":
            guard isCustomDisplayControlVisible, let id = command.value, customDisplayEnabledDisplayIDs.contains(id), ScoreboardWebAPIBroadcastDisplayMode(rawValue: text) != nil else { return fail("unsupported", "Invalid or disabled broadcast display.") }
        case "sound.play": guard ScoreboardSoundEffect(rawValue: text) != nil else { return fail("invalidCommand", "Unknown sound effect.") }
        case "clock.reset", "shot.reset", "shot.assign", "penalty.add", "period.set", "injury.set":
            guard (command.value ?? 0) >= 0 else { return fail("invalidCommand", "Value must be nonnegative.") }
        default: break
        }
        var age: TimeInterval = 0
        if remote {
            guard let sentAt = command.sentAt, sentAt.isFinite else { return fail("stale", "Clock synchronization is required.") }
            age = Date().timeIntervalSince1970 - sentAt
            guard age >= -0.1, age <= 2 else { return fail("stale", "Command arrived too late. Check the connection and try again.") }
            age = max(0, age)
        }
        reconcileRunningTimersWithWallClock()
        switch command.action {
        case "clock.reset", "score.reset":
            guard !isGameClockInterlockActive else { return fail("conflict", "Pause the game clock before resetting.") }
        case "chess.reset", "debate.resetSegment", "debate.resetRound", "debate.prepReset", "period.undo",
             "player.clear", "player.foulsReset", "team.playerFoulsReset", "all.playerFoulsReset", "team.foulsReset", "all.teamFoulsReset",
             "team.cardsReset", "all.cardsReset":
            guard !isResetInterlockActive else { return fail("conflict", "Pause timers before resetting.") }
        case "period.adjust":
            guard (command.value ?? 0) >= 0 || !isGameClockInterlockActive else { return fail("conflict", "Pause the game clock before moving to a previous period.") }
        default: break
        }
        if remote, let expected = command.expectedRunning {
            let running: Bool
            if command.action.hasPrefix("pause.") { running = pauseTimer?.isRunning == true }
            else if command.action.hasPrefix("shot.") { running = isShotClockRunning }
            else if command.action.hasPrefix("penalty.") {
                running = (homePenaltyTimers + guestPenaltyTimers).first { $0.id == command.timerID }?.isRunning ?? false
            } else if command.action == "debate.prepToggle" {
                let target: DebateActiveTimer = side == .home ? .prepHome : .prepGuest
                running = debateActiveTimer == target && isDebatePrepClockRunning
            } else { running = isClockRunning }
            guard running == expected else { return fail("conflict", "Timer state changed. Refresh before trying again.") }
        }
        var timing = beginRemoteTimerOperation(command, delay: age)
        let previousPenaltyIDs = Set((homePenaltyTimers + guestPenaltyTimers).map(\.id))
        let value = command.value ?? 0
        let enabled = command.enabled ?? false
        switch command.action {
        case "score.adjust": adjustScore(isHome: side == .home, by: value)
        case "score.reset": resetScores()
        case "period.adjust": adjustPeriod(by: value)
        case "period.set": setPeriod(value)
        case "period.award": awardPeriod(to: side)
        case "period.undo": undoLastPeriodWin()
        case "clock.toggle": toggleClock()
        case "clock.running": if isClockRunning != enabled { toggleClock() }
        case "clock.adjust": adjustClock(by: value)
        case "clock.reset": resetClock(to: value)
        case "shot.toggle": toggleShotClock()
        case "shot.running": if isShotClockRunning != enabled { toggleShotClock() }
        case "shot.adjust": adjustShotClock(by: value)
        case "shot.reset": resetShotClock(to: value)
        case "shot.activeReset": resetActiveShotClock()
        case "shot.assign": assignShotClock(to: value, forHomeTeam: side == .home)
        case "possession.set": setPossessionDirection(PossessionDirection(rawValue: text)!, autoStartShotClock: enabled)
        case "serve.set": setServeTimerSide(side)
        case "sides.swap": swapSides()
        case "player.number": updateTrackedPlayerNumber(text, for: side, playerID: command.playerID!)
        case "player.name": updateTrackedPlayerName(text, for: side, playerID: command.playerID!)
        case "player.lineup": setPlayerActiveLineup(enabled, for: side, playerID: command.playerID!)
        case "player.overlay": togglePlayerOverlayPaused()
        case "player.foul": adjustFoulCount(for: side, playerID: command.playerID!, by: value)
        case "player.foulsReset": resetFouls(for: side, playerID: command.playerID!)
        case "team.playerFoulsReset": resetFouls(for: side)
        case "all.playerFoulsReset": resetAllPlayerFouls()
        case "player.card": setCardStatus(PlayerCardStatus(rawValue: text)!, for: side, playerID: command.playerID!)
        case "team.cardsReset": resetCards(for: side)
        case "all.cardsReset": resetAllPlayerCards()
        case "team.foul": adjustTeamFouls(for: side, by: value)
        case "team.foulsReset": resetTeamFouls(for: side)
        case "all.teamFoulsReset": resetAllTeamFouls()
        case "substitution.adjust": adjustSubstitutionsUsed(for: side, by: value)
        case "pause.adjust": adjustPausesUsed(for: side, by: value)
        case "pause.start": startPause(for: side, seconds: value)
        case "pause.official": startPause(seconds: value)
        case "pause.running": setPauseTimerRunning(enabled)
        case "pause.cancel": cancelPause()
        case "chess.switch": switchChessClock()
        case "chess.side": setActiveChessClockSide(side)
        case "chess.adjust": adjustChessClock(for: side, by: value)
        case "chess.reset": resetChessClocks()
        case "debate.segment": advanceDebateSegment(by: value)
        case "debate.resetSegment": resetDebateCurrentSegment()
        case "debate.resetRound": resetDebateRound()
        case "debate.prepToggle": toggleDebatePrepClock(for: side)
        case "debate.prepReset": resetDebatePrepClock(for: side)
        case "debate.prepAdjust": adjustDebatePrepClock(for: side, by: value)
        case "debate.return": returnToDebateSegmentTimer(resume: enabled)
        case "injury.set": setPendingInjuryTimeMinutes(value)
        case "penalty.add": addPenaltyTimer(for: side, seconds: value, player: command.playerID.flatMap { id in trackedPlayers(for: side).first { $0.id == id } }, startsRunning: enabled)
        case "penalty.remove": removePenaltyTimer(for: side, timerID: command.timerID!)
        case "penalty.toggle": togglePenaltyTimer(for: side, timerID: command.timerID!)
        case "penalty.adjust": adjustPenaltyTimer(for: side, timerID: command.timerID!, by: value)
        case "penalty.number": updatePenaltyTimerPlayerNumber(text, for: side, timerID: command.timerID!)
        case "penalty.name": updatePenaltyTimerPlayerName(text, for: side, timerID: command.timerID!)
        case "penalty.player": assignPenaltyTimerPlayer(trackedPlayers(for: side).first { $0.id == command.playerID! }!, for: side, timerID: command.timerID!)
        case "player.clear": clearTrackedPlayerState(for: side, playerID: command.playerID!)
        case "debate.turn": turnDebateClockHere(side)
        case "display.theme": theme = ScoreboardTheme(rawValue: text)!
        case "display.mode": publicDisplayViewMode = ScoreboardDisplayViewMode(rawValue: text)!
        case "display.direction": externalDisplayDirection = ScoreboardDisplayDirection(rawValue: text)!
        case "display.broadcast": setWebAPIBroadcastDisplayMode(ScoreboardWebAPIBroadcastDisplayMode(rawValue: text)!, for: value)
        case "sound.enabled": setSoundEnabled(enabled)
        case "sound.play": playControlSound(ScoreboardSoundEffect(rawValue: text)!)
        case "game.new": newGame()
        default: return fail("invalidCommand", "Unknown operation.")
        }
        if command.action == "penalty.add" {
            timing.penaltyID = (homePenaltyTimers + guestPenaltyTimers).first { !previousPenaltyIDs.contains($0.id) }?.id
        }
        finishRemoteTimerOperation(timing, delay: age)
        return ScoreboardControlResult(id: command.id, success: true, error: nil, message: nil)
    }
}

extension ScoreboardControlOperation {
    nonisolated static func textOptions(for action: String) -> [String] {
        switch action {
        case "player.card": return ["none", "yellow", "red"]
        case "possession.set": return ["none", "home", "guest"]
        case "display.direction": return ["homeLeft", "guestLeft"]
        case "display.theme": return ScoreboardTheme.allCases.map(\.rawValue)
        case "display.mode": return ScoreboardDisplayViewMode.allCases.map(\.rawValue)
        case "display.broadcast": return ScoreboardWebAPIBroadcastDisplayMode.allCases.map(\.rawValue)
        case "sound.play": return ScoreboardSoundEffect.allCases.map(\.rawValue)
        default: return []
        }
    }
}
