import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

private let scoreboardAppName = scoreboardActivityString("Smart Scoreboard")

private func scoreboardActivityString(_ key: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
}

private func scoreboardActivityFormat(_ key: String, _ arguments: Any...) -> String {
    let normalizedArguments = arguments.map { argument -> CVarArg in
        if let string = argument as? String {
            return string as NSString
        }
        if let argument = argument as? CVarArg {
            return argument
        }
        return String(describing: argument) as NSString
    }
    return String(format: scoreboardActivityString(key), locale: Locale.current, arguments: normalizedArguments)
}

@main
struct ScoreboardLiveActivityExtensionBundle: WidgetBundle {
    var body: some Widget {
        ScoreboardLiveActivityWidget()
    }
}

struct ScoreboardLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScoreboardLiveActivityAttributes.self) { context in
            ScoreboardLiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.05, green: 0.06, blue: 0.07))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ScoreboardLiveActivityBrandView(subtitle: context.state.sportTitle, compact: true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ScoreboardLiveActivityRunningBadge(text: context.state.statusText)
                }
                DynamicIslandExpandedRegion(.center) {
                    if context.state.secondaryTimer == nil {
                        ScoreboardLiveActivityPrimaryTimerView(state: context.state, compact: true)
                    } else {
                        ScoreboardLiveActivityModeView(state: context.state, compact: true)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        if let secondaryTimer = context.state.secondaryTimer {
                            ScoreboardLiveActivityTimerPairView(
                                state: context.state,
                                primaryTimer: context.state.primaryTimer,
                                secondaryTimer: secondaryTimer,
                                compact: true
                            )
                        }
                        ScoreboardLiveActivityContextRow(state: context.state, compact: true)
                    }
                }
            } compactLeading: {
                ScoreboardLiveActivityCompactStatusView(state: context.state)
            } compactTrailing: {
                if let secondaryTimer = context.state.secondaryTimer {
                    ScoreboardLiveActivityCompactTimerPairView(
                        primaryTimer: context.state.primaryTimer,
                        secondaryTimer: secondaryTimer
                    )
                } else {
                    ScoreboardLiveActivityCompactTimerView(timer: context.state.primaryTimer)
                }
            } minimal: {
                ScoreboardLiveActivityMinimalStatusView()
            }
        }
    }
}

private struct ScoreboardLiveActivityLockScreenView: View {
    let state: ScoreboardLiveActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                ScoreboardLiveActivityBrandView(subtitle: state.sportTitle, compact: false)
                Spacer(minLength: 10)
                ScoreboardLiveActivityRunningBadge(text: state.statusText)
            }

            if let secondaryTimer = state.secondaryTimer {
                ScoreboardLiveActivityTimerPairView(
                    state: state,
                    primaryTimer: state.primaryTimer,
                    secondaryTimer: secondaryTimer,
                    compact: false
                )
            } else {
                ScoreboardLiveActivityPrimaryTimerView(state: state, compact: false)
                    .frame(maxWidth: .infinity)
            }

            ScoreboardLiveActivityContextRow(state: state, compact: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct ScoreboardLiveActivityBrandView: View {
    let subtitle: String
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 6 : 9) {
            ScoreboardLiveActivityLogoView(size: compact ? 22 : 34)

            VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                Text(scoreboardAppName)
                    .font(compact ? .caption.weight(.black) : .subheadline.weight(.black))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}

private struct ScoreboardLiveActivityLogoView: View {
    let size: CGFloat

    var body: some View {
        Image("ScoreboardIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: max(4, size * 0.18), style: .continuous))
    }
}

private struct ScoreboardLiveActivityCompactStatusView: View {
    let state: ScoreboardLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 2) {
            ScoreboardLiveActivityRunningDot(size: 4)
            ScoreboardLiveActivityLogoView(size: 14)
        }
        .frame(width: 20, height: 14, alignment: .leading)
        .accessibilityLabel(state.statusText)
    }
}

private struct ScoreboardLiveActivityCompactTimerView: View {
    let timer: ScoreboardLiveActivityTimer

    var body: some View {
        HStack(spacing: 2) {
            if timer.isActive {
                ScoreboardLiveActivityRunningDot(size: 4)
            }

            ScoreboardLiveActivityTimerText(timer: timer)
                .font(.system(size: 9, weight: .black, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: 42, height: 14, alignment: .trailing)
        .clipped()
        .foregroundStyle(timer.isActive ? .green : .primary)
        .accessibilityLabel("\(timer.title) \(timer.valueText)")
    }
}

private struct ScoreboardLiveActivityCompactTimerPairView: View {
    let primaryTimer: ScoreboardLiveActivityTimer
    let secondaryTimer: ScoreboardLiveActivityTimer

    var body: some View {
        HStack(alignment: .center, spacing: 1) {
            ScoreboardLiveActivityCompactTimerValueView(timer: primaryTimer)

            Text("/")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))

            ScoreboardLiveActivityCompactTimerValueView(timer: secondaryTimer)
        }
        .frame(width: 58, height: 14, alignment: .trailing)
        .clipped()
        .lineLimit(1)
        .accessibilityLabel("\(primaryTimer.title) \(primaryTimer.valueText), \(secondaryTimer.title) \(secondaryTimer.valueText)")
    }
}

private struct ScoreboardLiveActivityCompactTimerValueView: View {
    let timer: ScoreboardLiveActivityTimer

    var body: some View {
        ScoreboardLiveActivityTimerText(timer: timer)
            .font(.system(size: 8.5, weight: .black, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .frame(width: 26, height: 14, alignment: .center)
            .foregroundStyle(timer.isActive ? activeColor : .white)
    }

    private var activeColor: Color {
        switch timer.side {
        case .home:
            return Color(red: 0.97, green: 0.38, blue: 0.28)
        case .guest:
            return Color(red: 0.22, green: 0.68, blue: 0.95)
        case nil:
            return .green
        }
    }
}

private struct ScoreboardLiveActivityMinimalStatusView: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScoreboardLiveActivityLogoView(size: 14)

            ScoreboardLiveActivityRunningDot(size: 4)
                .offset(x: 1, y: -1)
        }
        .frame(width: 14, height: 14, alignment: .center)
        .accessibilityLabel(scoreboardActivityString("Game Running"))
    }
}

private struct ScoreboardLiveActivityRunningDot: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: size, height: size)
    }
}

private struct ScoreboardLiveActivityRunningBadge: View {
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            ScoreboardLiveActivityRunningDot(size: 7)
            Text(text)
                .font(.caption.weight(.black))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.green.opacity(0.16))
        )
    }
}

private struct ScoreboardLiveActivityModeView: View {
    let state: ScoreboardLiveActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 1 : 3) {
            Text(state.sportTitle)
                .font(compact ? .caption.weight(.bold) : .subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let periodText = state.periodText {
                Text(periodText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

private struct ScoreboardLiveActivityPrimaryTimerView: View {
    let state: ScoreboardLiveActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 10 : 16) {
            VStack(alignment: .leading, spacing: compact ? 3 : 6) {
                Text(state.primaryTimer.title)
                    .font(compact ? .caption2.weight(.black) : .caption.weight(.black))
                    .foregroundStyle(state.primaryTimer.isActive ? .green : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let periodText = state.periodText {
                    Text(periodText)
                        .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                if let scoreText = state.scoreText {
                    Text(scoreboardActivityFormat("Score %@", scoreText))
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            Spacer(minLength: compact ? 6 : 10)

            ScoreboardLiveActivityTimerText(timer: state.primaryTimer)
                .font(.system(size: compact ? 27 : 48, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.48)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, compact ? 8 : 14)
        .padding(.horizontal, compact ? 12 : 18)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(state.primaryTimer.isActive ? Color.green.opacity(0.18) : Color.white.opacity(0.08))
        )
    }
}

private struct ScoreboardLiveActivityTimerPairView: View {
    let state: ScoreboardLiveActivityAttributes.ContentState
    let primaryTimer: ScoreboardLiveActivityTimer
    let secondaryTimer: ScoreboardLiveActivityTimer
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 6 : 8) {
            if !compact {
                HStack(spacing: 8) {
                    if let periodText = state.periodText {
                        Text(periodText)
                    }
                    if let scoreText = state.scoreText {
                        ScoreboardLiveActivitySeparator()
                        Text(scoreboardActivityFormat("Score %@", scoreText)).monospacedDigit()
                    }
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }

            HStack(spacing: compact ? 8 : 10) {
                ScoreboardLiveActivityTimerCard(timer: primaryTimer, compact: compact)
                ScoreboardLiveActivityTimerCard(timer: secondaryTimer, compact: compact)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
    }
}

private struct ScoreboardLiveActivityTimerCard: View {
    let timer: ScoreboardLiveActivityTimer
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 2 : 4) {
            Text(timer.title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(timer.isActive ? .green : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .center)

            ScoreboardLiveActivityTimerText(timer: timer)
                .font(.system(size: compact ? 18 : 28, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, compact ? 5 : 9)
        .padding(.horizontal, compact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(timer.isActive ? Color.green.opacity(0.18) : Color.white.opacity(0.08))
        )
    }
}

private struct ScoreboardLiveActivityContextRow: View {
    let state: ScoreboardLiveActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            Text("\(state.homeTeamName) vs \(state.guestTeamName)")
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ScoreboardLiveActivitySeparator()

            Text(state.sportTitle)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
    }
}

private struct ScoreboardLiveActivitySeparator: View {
    var body: some View {
        Circle()
            .fill(Color.secondary.opacity(0.55))
            .frame(width: 3, height: 3)
    }
}

private struct ScoreboardLiveActivityTimerText: View {
    let timer: ScoreboardLiveActivityTimer

    var body: some View {
        if let range = timer.dateRange {
            Text(timerInterval: range, countsDown: timer.mode == .countdown)
        } else {
            Text(timer.valueText)
        }
    }
}
