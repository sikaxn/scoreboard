import SwiftUI

#if !os(tvOS)
struct ScoreboardControlBoardModePicker: View {
    let sportTitle: String
    let capabilities: ScoreboardControlBoardCapabilities
    let palette: ThemePalette
    @Binding var configuration: ScoreboardControlBoardConfiguration
    @Binding var showsMergedView: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScoreboardControlSheet(title: ScoreboardLocalization.string("Control Board Mode"), subtitle: sportTitle,
                               palette: palette, accessibilityID: "controlBoard.modePicker") {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    card {
                        let modes = capabilities.availableModes
                        ForEach(Array(modes.enumerated()), id: \.element) { index, mode in
                            modeRow(mode)
                            if index < modes.count - 1 { divider.padding(.leading, 48) }
                        }
                    }
                    Text("Saved for this sport on this device. Changing station mode keeps the match and timers running.")
                        .font(.footnote)
                        .foregroundStyle(palette.dashboardMutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                card {
                    Toggle("Show Clock & Score Box", isOn: $configuration.showsCenterSummary)
                        .toggleStyle(.switch)
                        .padding(14)
                        .accessibilityIdentifier("controlBoard.showsSummary")
                    divider.padding(.horizontal, 14)
                    Toggle("Merged View (Beta)", isOn: $showsMergedView)
                        .toggleStyle(.switch)
                        .padding(14)
                        .accessibilityIdentifier("controlBoard.mergedView")
                }

                if configuration.effectiveMode(for: capabilities) != .full,
                   configuration.visibleModules(for: capabilities).contains(where: { $0.hasTeamControls }) {
                    teamSection
                }
                if configuration.mode == .custom { moduleSection }
            }
        } footer: {
            HStack {
                Button { configuration = ScoreboardControlBoardConfiguration() } label: {
                    Text("Reset This Sport")
                        .foregroundStyle(palette.dashboardNeutralButtonText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(palette.dashboardNeutralButton, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("controlBoard.reset")

                Spacer(minLength: 12)

                Button { dismiss() } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.dashboardSuccessButtonText)
                        .frame(minWidth: 64)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(palette.dashboardSuccessButton, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("controlBoard.done")
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(palette.dashboardCardBorder).frame(height: 1)
    }

    private func card<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        ScoreboardControlSheetCard(palette: palette, content: content)
    }

    private func modeRow(_ mode: ScoreboardControlBoardMode) -> some View {
        let isSelected = configuration.effectiveMode(for: capabilities) == mode
        return Button {
            configuration.mode = mode
        } label: {
            HStack(spacing: 12) {
                Image(systemName: modeIcon(mode))
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 22)
                    .foregroundStyle(palette.dashboardMutedText)
                Text(verbatim: ScoreboardLocalization.string(mode.title))
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? palette.dashboardStatusLive : palette.dashboardMutedText)
                    .frame(width: 20)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? palette.dashboardNeutralButton : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("controlBoard.mode.\(mode.rawValue)")
    }

    private var teamSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            card {
                Picker("Teams", selection: $configuration.teams) {
                    ForEach(ScoreboardControlBoardTeams.allCases) { teams in
                        Text(verbatim: ScoreboardLocalization.string(teams.title)).tag(teams)
                    }
                }
                .pickerStyle(.menu)
                .padding(14)
                .accessibilityIdentifier("controlBoard.teams")
            }
            Text("Team selection applies to team panels. Match timers remain shared.")
                .font(.footnote)
                .foregroundStyle(palette.dashboardMutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var moduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom Modules").font(.headline)
            card {
                let modules = configuration.orderedModules(available: capabilities.availableModules)
                ForEach(Array(modules.enumerated()), id: \.element) { index, module in
                    HStack(spacing: 12) {
                        Toggle(isOn: Binding(
                            get: { configuration.enabledModules.contains(module) },
                            set: { enabled in
                                if enabled { configuration.enabledModules.insert(module) }
                                else { configuration.enabledModules.remove(module) }
                            }
                        )) {
                            Text(verbatim: ScoreboardLocalization.string(module.title))
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("controlBoard.module.\(module.rawValue)")

                        HStack(spacing: 6) {
                            moveButton(module, by: -1, isEnabled: index > 0)
                            moveButton(module, by: 1, isEnabled: index < modules.count - 1)
                        }
                    }
                    .padding(12)
                    if index < modules.count - 1 { divider.padding(.horizontal, 12) }
                }
            }
            Text("Choose modules and their order within the team and timer columns. Unavailable sport features stay hidden.")
                .font(.footnote)
                .foregroundStyle(palette.dashboardMutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func moveButton(_ module: ScoreboardControlBoardModule, by offset: Int, isEnabled: Bool) -> some View {
        Button {
            configuration.move(module, by: offset, available: capabilities.availableModules)
        } label: {
            Image(systemName: offset < 0 ? "arrow.up" : "arrow.down")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(palette.dashboardNeutralButton, in: RoundedRectangle(cornerRadius: 8))
                .opacity(isEnabled ? 1 : 0.3)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(ScoreboardLocalization.string(offset < 0 ? "Move Module Up" : "Move Module Down"))
        .accessibilityIdentifier("controlBoard.\(offset < 0 ? "moveUp" : "moveDown").\(module.rawValue)")
    }

    private func modeIcon(_ mode: ScoreboardControlBoardMode) -> String {
        switch mode {
        case .full: "square.grid.2x2"
        case .timer: "timer"
        case .shotClock: "stopwatch"
        case .roster: "person.3"
        case .scoring: "plusminus"
        case .penalties: "hourglass"
        case .custom: "slider.horizontal.3"
        }
    }
}
#endif
