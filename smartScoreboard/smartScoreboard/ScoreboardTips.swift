#if os(iOS) || os(macOS)
import SwiftUI
import TipKit

enum ScoreboardTips {
    static let setup = SetupTip()
    static let liveBoard = LiveBoardTip()
    static let displayPreview = DisplayPreviewTip()
    static let gameState = GameStateTip()
    static let matchControls = MatchControlsTip()
    static let scoreControls = ScoreControlsTip()
    static let shotClockControls = ShotClockControlsTip()
    static let playerShortcut = PlayerShortcutTip()
    static let resetInterlock = ResetInterlockTip()
    static let iPhoneLandscape = IPhoneLandscapeTip()
    static let players = PlayersTip()
    static let filesAndLogs = FilesAndLogsTip()
    static let integrations = IntegrationsTip()
    static let about = AboutTip()

    static let resettableTips: [any Tip] = [
        setup,
        liveBoard,
        displayPreview,
        gameState,
        matchControls,
        scoreControls,
        shotClockControls,
        playerShortcut,
        resetInterlock,
        iPhoneLandscape,
        players,
        filesAndLogs,
        integrations,
        about
    ]

    fileprivate static func localizedText(_ key: String) -> Text {
        Text(LocalizedStringKey(key))
    }

    @available(macOS 26.0, iOS 26.0, macCatalyst 26.0, *)
    static func resetTipEligibility() async {
        for tip in resettableTips {
            await tip.resetEligibility()
        }
    }

    struct ParagraphTip: Tip {
        let id: String
        let titleText: String
        let messageText: String
        let systemImage: String
        var maxDisplayCount = 1

        var title: Text { ScoreboardTips.localizedText(titleText) }
        var message: Text? { ScoreboardTips.localizedText(messageText) }
        var image: Image? { Image(systemName: systemImage) }
        var options: [any TipOption] { Tips.MaxDisplayCount(maxDisplayCount) }
    }

    struct SetupTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Set up the game first") }
        var message: Text? { ScoreboardTips.localizedText("Choose the sport, teams, clock defaults, and tracking options before opening the live control board.") }
        var image: Image? { Image(systemName: "slider.horizontal.3") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }

    struct LiveBoardTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Live controls are saved") }
        var message: Text? { ScoreboardTips.localizedText("Score, clock, period, player, and display changes are autosaved with the current game file.") }
        var image: Image? { Image(systemName: "rectangle.inset.filled.and.person.filled") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }

    struct DisplayPreviewTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Preview the public board") }
        var message: Text? { ScoreboardTips.localizedText("Use preview to check the public scoreboard layout before sending it to a window or external display.") }
        var image: Image? { Image(systemName: "display") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }

    struct GameStateTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Read the live state") }
        var message: Text? { ScoreboardTips.localizedText("The center card mirrors the public scoreboard with scores, active timers, periods, and sport-specific status.") }
        var image: Image? { Image(systemName: "rectangle.grid.2x2") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }

    struct MatchControlsTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Run the clock and period") }
        var message: Text? { ScoreboardTips.localizedText("Start or pause the timer, jog time, swap sides, advance periods, and pause before reset actions.") }
        var image: Image? { Image(systemName: "timer") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }

    struct ScoreControlsTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Operate each side here") }
        var message: Text? { ScoreboardTips.localizedText("Use these controls for score changes, side clocks, team fouls, substitutions, and sport-specific actions.") }
        var image: Image? { Image(systemName: "plus.forwardslash.minus") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }

    struct ShotClockControlsTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Manage the shot clock") }
        var message: Text? { ScoreboardTips.localizedText("Assign possession presets by side, pause or reset the active shot clock, and adjust it one second at a time.") }
        var image: Image? { Image(systemName: "timer.circle") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }

    struct PlayerShortcutTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Open player tracking") }
        var message: Text? { ScoreboardTips.localizedText("Use Players for rosters, fouls, cards, substitutions, active lineups, and player overlays during the game.") }
        var image: Image? { Image(systemName: "person.3") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }

    struct ResetInterlockTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Pause before resetting") }
        var message: Text? { ScoreboardTips.localizedText("Reset buttons stay locked while timers are running so live games are not reset accidentally.") }
        var image: Image? { Image(systemName: "lock.shield") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }

    struct IPhoneLandscapeTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Use landscape on iPhone") }
        var message: Text? { ScoreboardTips.localizedText("The control board is easier to use in landscape mode. Rotate iPhone for wider controls and fewer stacked panels.") }
        var image: Image? { Image(systemName: "iphone.landscape") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }

    struct PlayersTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Player tools follow the sport") }
        var message: Text? { ScoreboardTips.localizedText("When player tracking is enabled, use this screen for rosters, active lineups, fouls, cards, and overlays.") }
        var image: Image? { Image(systemName: "person.3") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }

    struct FilesAndLogsTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Reuse files and review logs") }
        var message: Text? { ScoreboardTips.localizedText("Game files preserve setups and live state. Logs keep a per-run audit trail for review or export.") }
        var image: Image? { Image(systemName: "books.vertical") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }

    struct IntegrationsTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Connect production tools") }
        var message: Text? { ScoreboardTips.localizedText("Remote Display, Web API, and Companion are separate integrations. Selecting one only changes which settings are shown.") }
        var image: Image? { Image(systemName: "network") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }

    struct AboutTip: Tip {
        var title: Text { ScoreboardTips.localizedText("Tips can be turned off") }
        var message: Text? { ScoreboardTips.localizedText("Use About to disable contextual tips, reset TipKit history, or show Getting Started again.") }
        var image: Image? { Image(systemName: "info.circle") }
        var options: [any TipOption] { Tips.MaxDisplayCount(1) }
    }
}

extension View {
    func scoreboardPopoverTip(_ tip: (any Tip)?, isEnabled: Bool, arrowEdge: Edge? = nil) -> some View {
        popoverTip(isEnabled ? tip : nil, arrowEdge: arrowEdge)
    }
}
#endif
