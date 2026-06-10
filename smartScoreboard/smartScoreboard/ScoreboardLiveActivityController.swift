#if os(iOS)
import ActivityKit
import Foundation

@MainActor
final class ScoreboardLiveActivityController {
    static let shared = ScoreboardLiveActivityController()

    private var activeActivityID: String?
    private var lastStateSignature: String?
    private var lastIsGameRunning = false

    private init() {}

    func sync(isGameRunning: Bool, state: ScoreboardLiveActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            lastStateSignature = nil
            lastIsGameRunning = false
            Task { await endAllActivities() }
            return
        }

        let stateSignature = Self.stateSignature(state, isGameRunning: isGameRunning)
        if isGameRunning {
            guard stateSignature != lastStateSignature || !lastIsGameRunning else {
                return
            }
            lastStateSignature = stateSignature
            lastIsGameRunning = true
            Task { await upsertActivity(state: state) }
        } else {
            guard lastIsGameRunning || !Activity<ScoreboardLiveActivityAttributes>.activities.isEmpty else {
                lastStateSignature = stateSignature
                return
            }
            lastStateSignature = stateSignature
            lastIsGameRunning = false
            Task { await endAllActivities(finalState: state) }
        }
    }

    private func upsertActivity(state: ScoreboardLiveActivityAttributes.ContentState) async {
        let content = ActivityContent(state: state, staleDate: state.staleDate)
        if let activity = currentActivity() {
            await activity.update(content)
            activeActivityID = activity.id
            return
        }

        do {
            let activity = try Activity.request(
                attributes: ScoreboardLiveActivityAttributes(activityName: "Smart Scoreboard"),
                content: content,
                pushType: nil
            )
            activeActivityID = activity.id
        } catch {
            activeActivityID = nil
        }
    }

    private func endAllActivities(finalState: ScoreboardLiveActivityAttributes.ContentState? = nil) async {
        let activities = Activity<ScoreboardLiveActivityAttributes>.activities
        for activity in activities {
            if let finalState {
                await activity.end(
                    ActivityContent(state: finalState, staleDate: Date()),
                    dismissalPolicy: .immediate
                )
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        activeActivityID = nil
    }

    private func currentActivity() -> Activity<ScoreboardLiveActivityAttributes>? {
        if let activeActivityID,
           let activity = Activity<ScoreboardLiveActivityAttributes>.activities.first(where: { $0.id == activeActivityID }) {
            return activity
        }
        return Activity<ScoreboardLiveActivityAttributes>.activities.first
    }

    private static func stateSignature(
        _ state: ScoreboardLiveActivityAttributes.ContentState,
        isGameRunning: Bool
    ) -> String {
        [
            isGameRunning ? "running" : "stopped",
            state.statusText,
            state.sportTitle,
            state.homeTeamName,
            state.guestTeamName,
            state.scoreText ?? "",
            state.periodText ?? "",
            timerSignature(state.primaryTimer),
            state.secondaryTimer.map(timerSignature) ?? ""
        ].joined(separator: "|")
    }

    private static func timerSignature(_ timer: ScoreboardLiveActivityTimer) -> String {
        var parts = [
            timer.title,
            timer.mode.rawValue,
            timer.isActive ? "active" : "inactive",
            timer.side?.rawValue ?? ""
        ]

        switch timer.mode {
        case .staticValue:
            parts.append(timer.valueText)
        case .countdown:
            parts.append(timer.rangeEndDate.map(signatureDate) ?? "")
        case .countUp:
            parts.append(timer.rangeStartDate.map(signatureDate) ?? "")
            parts.append(timer.rangeEndDate.map(signatureDate) ?? "")
        }

        return parts.joined(separator: "~")
    }

    private static func signatureDate(_ date: Date) -> String {
        String(Int(date.timeIntervalSince1970.rounded()))
    }
}

@MainActor
extension ScoreboardStore {
    func syncLiveActivityForCurrentState() {
        let now = Date()
        ScoreboardLiveActivityController.shared.sync(
            isGameRunning: isGameRunning && showsLiveActivityWhenTimerRunning,
            state: liveActivityContentState(now: now)
        )
    }

    var nextPrimaryTimerMaintenanceDate: Date? {
        let seconds: Int?
        if isDebatePrepClockRunning {
            switch debateActiveTimer {
            case .prepHome:
                seconds = debatePrepHomeSeconds
            case .prepGuest:
                seconds = debatePrepGuestSeconds
            case .segment:
                seconds = nil
            }
        } else if isClockRunning, usesChessClocks {
            switch activeChessClockSide {
            case .home:
                seconds = homeChessClockSeconds
            case .guest:
                seconds = guestChessClockSeconds
            case .none:
                seconds = nil
            }
        } else if isClockRunning, gameClockMode == .countdown {
            seconds = gameClockSeconds
        } else if isClockRunning {
            seconds = 15 * 60
        } else {
            seconds = nil
        }

        guard let seconds else {
            return nil
        }
        return Date().addingTimeInterval(TimeInterval(max(1, seconds)))
    }

    private func liveActivityContentState(now: Date) -> ScoreboardLiveActivityAttributes.ContentState {
        let timerState = liveActivityTimerState(now: now)
        return ScoreboardLiveActivityAttributes.ContentState(
            statusText: NSLocalizedString(isGameRunning ? "Game Running" : "Game Stopped", comment: ""),
            sportTitle: liveActivitySportTitle,
            homeTeamName: liveActivityTeamName(homeTeamName, fallback: "HOME"),
            guestTeamName: liveActivityTeamName(guestTeamName, fallback: "GUEST"),
            scoreText: supportsScore ? "\(homeScore)-\(guestScore)" : nil,
            periodText: liveActivityPeriodText,
            primaryTimer: timerState.primary,
            secondaryTimer: timerState.secondary,
            staleDate: timerState.staleDate
        )
    }

    private var liveActivitySportTitle: String {
        if isDebateMode {
            return NSLocalizedString(currentDebatePreset.title, comment: "")
        }
        if selectedSport == .custom {
            return currentRules.title
        }
        return NSLocalizedString(currentRules.title, comment: "")
    }

    private var liveActivityPeriodText: String? {
        if isDebateMode {
            return NSLocalizedString(debateSegmentTitle, comment: "")
        }
        guard supportsPeriod else {
            return nil
        }
        return "\(NSLocalizedString(periodShortTitle, comment: "")) \(period)"
    }

    private func liveActivityTeamName(_ name: String, fallback: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? NSLocalizedString(fallback, comment: "") : trimmedName
    }

    private func liveActivityTimerState(now: Date) -> (
        primary: ScoreboardLiveActivityTimer,
        secondary: ScoreboardLiveActivityTimer?,
        staleDate: Date?
    ) {
        if isDebatePrepClockRunning {
            switch debateActiveTimer {
            case .prepHome:
                let timer = liveActivityCountdownTimer(
                    title: "\(sideRoleLabel(for: .home)) \(NSLocalizedString("Prep", comment: ""))",
                    seconds: debatePrepHomeSeconds,
                    now: now,
                    isActive: true,
                    side: .home
                )
                return (timer, nil, timer.rangeEndDate)
            case .prepGuest:
                let timer = liveActivityCountdownTimer(
                    title: "\(sideRoleLabel(for: .guest)) \(NSLocalizedString("Prep", comment: ""))",
                    seconds: debatePrepGuestSeconds,
                    now: now,
                    isActive: true,
                    side: .guest
                )
                return (timer, nil, timer.rangeEndDate)
            case .segment:
                break
            }
        }

        if usesChessClocks {
            let homeTimer = liveActivityCountdownTimer(
                title: sideRoleLabel(for: .home),
                seconds: homeChessClockSeconds,
                now: now,
                isActive: isClockRunning && activeChessClockSide == .home,
                side: .home
            )
            let guestTimer = liveActivityCountdownTimer(
                title: sideRoleLabel(for: .guest),
                seconds: guestChessClockSeconds,
                now: now,
                isActive: isClockRunning && activeChessClockSide == .guest,
                side: .guest
            )
            let activeEndDate = activeChessClockSide == .home ? homeTimer.rangeEndDate : guestTimer.rangeEndDate
            return (homeTimer, guestTimer, isClockRunning ? activeEndDate : nil)
        }

        let timer: ScoreboardLiveActivityTimer
        switch gameClockMode {
        case .countdown:
            timer = liveActivityCountdownTimer(
                title: NSLocalizedString("Clock", comment: ""),
                seconds: gameClockSeconds,
                now: now,
                isActive: isClockRunning,
                side: nil
            )
        case .countUp:
            timer = liveActivityCountUpTimer(
                title: NSLocalizedString("Clock", comment: ""),
                seconds: gameClockSeconds,
                now: now,
                isActive: isClockRunning
            )
        }
        return (timer, nil, timer.rangeEndDate)
    }

    private func liveActivityCountdownTimer(
        title: String,
        seconds: Int,
        now: Date,
        isActive: Bool,
        side: ScoreboardLiveActivitySide?
    ) -> ScoreboardLiveActivityTimer {
        let referenceDate = roundedLiveActivityDate(now)
        let boundedSeconds = max(0, seconds)
        let endDate = referenceDate.addingTimeInterval(TimeInterval(boundedSeconds))
        return ScoreboardLiveActivityTimer(
            title: title,
            valueText: Self.formatGameClock(boundedSeconds),
            mode: isActive ? .countdown : .staticValue,
            rangeStartDate: isActive ? referenceDate : nil,
            rangeEndDate: isActive ? endDate : nil,
            isActive: isActive,
            side: side
        )
    }

    private func liveActivityCountUpTimer(
        title: String,
        seconds: Int,
        now: Date,
        isActive: Bool
    ) -> ScoreboardLiveActivityTimer {
        let referenceDate = roundedLiveActivityDate(now)
        let boundedSeconds = max(0, seconds)
        let startDate = referenceDate.addingTimeInterval(-TimeInterval(boundedSeconds))
        let endDate = referenceDate.addingTimeInterval(TimeInterval(max(1, Self.maxGameClockSeconds - boundedSeconds)))
        return ScoreboardLiveActivityTimer(
            title: title,
            valueText: Self.formatGameClock(boundedSeconds),
            mode: isActive ? .countUp : .staticValue,
            rangeStartDate: isActive ? startDate : nil,
            rangeEndDate: isActive ? endDate : nil,
            isActive: isActive,
            side: nil
        )
    }

    private func roundedLiveActivityDate(_ date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970))
    }
}
#endif
