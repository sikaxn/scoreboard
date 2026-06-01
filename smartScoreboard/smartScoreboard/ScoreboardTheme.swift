import SwiftUI

enum ExternalDisplayBackgroundMode: String, Codable, CaseIterable, Identifiable {
    case blurred
    case clear
    case clearUnderBoard
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blurred:
            return "Blurred"
        case .clear:
            return "Split Background"
        case .clearUnderBoard:
            return "Through Scoreboard"
        case .none:
            return "No Background"
        }
    }

    var subtitle: String {
        switch self {
        case .blurred:
            return "Use the softened glow treatment on the external display."
        case .clear:
            return "Show a clean red-blue split behind the scoreboard."
        case .clearUnderBoard:
            return "Let the red-blue split show through where the board background is normally black."
        case .none:
            return "Leave the external display background unfilled outside the scoreboard."
        }
    }
}

enum ScoreboardTheme: String, Codable, CaseIterable, Identifiable {
    case classic
    case highContrast
    case night
    case sunlight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic:
            return "Default"
        case .highContrast:
            return "High Contrast"
        case .night:
            return "Night"
        case .sunlight:
            return "Sunlight"
        }
    }

    var subtitle: String {
        switch self {
        case .classic:
            return "Balanced arena lighting with the existing dark scoreboard look."
        case .highContrast:
            return "Sharper contrast and brighter accents for maximum legibility."
        case .night:
            return "Cooler tones and subdued surfaces for darker venues."
        case .sunlight:
            return "Warmer daylight surfaces with bold scoreboard contrast."
        }
    }

    var systemImage: String {
        switch self {
        case .classic:
            return "sparkles.rectangle.stack"
        case .highContrast:
            return "circle.lefthalf.filled"
        case .night:
            return "moon.stars.fill"
        case .sunlight:
            return "sun.max.fill"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .classic:
            return ThemePalette(
                appSetupBackground: [
                    .rgb(0.95, 0.96, 0.98),
                    .rgb(0.91, 0.93, 0.97)
                ],
                appDashboardBackground: [
                    .rgb(0.08, 0.09, 0.14),
                    .rgb(0.16, 0.08, 0.08),
                    .black
                ],
                settingsShellBackground: .white,
                settingsSidebarBackground: .white,
                settingsDetailBackground: .rgb(0.95, 0.96, 0.98),
                settingsCardBackground: .white,
                settingsFieldBackground: .rgb(0.96, 0.97, 0.99),
                settingsPrimaryText: .rgb(0.10, 0.12, 0.18),
                settingsSecondaryText: .rgb(0.41, 0.46, 0.56),
                settingsDivider: .black.opacity(0.08),
                settingsCardBorder: .black.opacity(0.06),
                settingsAccent: .rgb(0.20, 0.47, 0.94),
                settingsAccentText: .white,
                settingsSecondaryButtonBackground: .rgb(0.93, 0.94, 0.97),
                settingsSecondaryButtonText: .rgb(0.10, 0.12, 0.18),
                destructiveTint: .red,
                dashboardCardBackground: .white.opacity(0.06),
                dashboardCardBorder: .white.opacity(0.08),
                dashboardPrimaryText: .white,
                dashboardSecondaryText: .white.opacity(0.72),
                dashboardMutedText: .white.opacity(0.60),
                dashboardSubtleText: .white.opacity(0.68),
                dashboardNeutralButton: .white.opacity(0.14),
                dashboardNeutralButtonText: .white,
                dashboardSuccessButton: .green.opacity(0.72),
                dashboardSuccessButtonText: .white,
                dashboardWarningButton: .orange,
                dashboardWarningButtonText: .white,
                dashboardStatusLive: .green,
                dashboardStatusIdle: .orange,
                externalDisplayBackground: .black,
                boardBackground: [
                    .rgb(0.02, 0.03, 0.05),
                    .rgb(0.04, 0.04, 0.07),
                    .black
                ],
                boardHighlightTop: .white.opacity(0.05),
                boardHighlightBottom: .white.opacity(0.03),
                boardPanelBackground: .white.opacity(0.05),
                boardClockPanelBackground: .white.opacity(0.07),
                boardPanelBorder: .white.opacity(0.08),
                boardPrimaryText: .white,
                boardSecondaryText: .white.opacity(0.42),
                boardBadgeBackground: .white.opacity(0.08),
                boardBadgeBorder: .white.opacity(0.08),
                boardBadgeTitleText: .white.opacity(0.46),
                boardBadgeValueText: .white,
                homeAccent: .rgb(0.97, 0.38, 0.28),
                guestAccent: .rgb(0.22, 0.68, 0.95)
            )
        case .highContrast:
            return ThemePalette(
                appSetupBackground: [
                    .rgb(0.12, 0.12, 0.12),
                    .rgb(0.03, 0.03, 0.03)
                ],
                appDashboardBackground: [
                    .black,
                    .rgb(0.08, 0.08, 0.08),
                    .black
                ],
                settingsShellBackground: .rgb(0.07, 0.07, 0.07),
                settingsSidebarBackground: .rgb(0.03, 0.03, 0.03),
                settingsDetailBackground: .rgb(0.10, 0.10, 0.10),
                settingsCardBackground: .rgb(0.14, 0.14, 0.14),
                settingsFieldBackground: .rgb(0.18, 0.18, 0.18),
                settingsPrimaryText: .white,
                settingsSecondaryText: .white.opacity(0.74),
                settingsDivider: .white.opacity(0.12),
                settingsCardBorder: .white.opacity(0.12),
                settingsAccent: .rgb(0.98, 0.82, 0.18),
                settingsAccentText: .black,
                settingsSecondaryButtonBackground: .rgb(0.20, 0.20, 0.20),
                settingsSecondaryButtonText: .white,
                destructiveTint: .rgb(0.86, 0.18, 0.14),
                dashboardCardBackground: .white.opacity(0.10),
                dashboardCardBorder: .white.opacity(0.16),
                dashboardPrimaryText: .white,
                dashboardSecondaryText: .white.opacity(0.84),
                dashboardMutedText: .white.opacity(0.72),
                dashboardSubtleText: .white.opacity(0.82),
                dashboardNeutralButton: .white.opacity(0.16),
                dashboardNeutralButtonText: .white,
                dashboardSuccessButton: .rgb(0.18, 0.76, 0.34),
                dashboardSuccessButtonText: .black,
                dashboardWarningButton: .rgb(0.98, 0.82, 0.18),
                dashboardWarningButtonText: .black,
                dashboardStatusLive: .rgb(0.26, 0.95, 0.48),
                dashboardStatusIdle: .rgb(0.98, 0.82, 0.18),
                externalDisplayBackground: .black,
                boardBackground: [
                    .black,
                    .rgb(0.07, 0.07, 0.07),
                    .black
                ],
                boardHighlightTop: .white.opacity(0.10),
                boardHighlightBottom: .white.opacity(0.06),
                boardPanelBackground: .white.opacity(0.08),
                boardClockPanelBackground: .white.opacity(0.12),
                boardPanelBorder: .white.opacity(0.18),
                boardPrimaryText: .white,
                boardSecondaryText: .white.opacity(0.70),
                boardBadgeBackground: .white.opacity(0.12),
                boardBadgeBorder: .white.opacity(0.18),
                boardBadgeTitleText: .white.opacity(0.80),
                boardBadgeValueText: .white,
                homeAccent: .rgb(0.96, 0.48, 0.12),
                guestAccent: .rgb(0.12, 0.72, 0.98)
            )
        case .night:
            return ThemePalette(
                appSetupBackground: [
                    .rgb(0.09, 0.11, 0.16),
                    .rgb(0.05, 0.07, 0.11)
                ],
                appDashboardBackground: [
                    .rgb(0.03, 0.05, 0.10),
                    .rgb(0.06, 0.06, 0.15),
                    .rgb(0.01, 0.02, 0.04)
                ],
                settingsShellBackground: .rgb(0.09, 0.12, 0.18),
                settingsSidebarBackground: .rgb(0.06, 0.08, 0.13),
                settingsDetailBackground: .rgb(0.10, 0.13, 0.19),
                settingsCardBackground: .rgb(0.13, 0.17, 0.25),
                settingsFieldBackground: .rgb(0.16, 0.21, 0.30),
                settingsPrimaryText: .rgb(0.93, 0.96, 1.0),
                settingsSecondaryText: .rgb(0.71, 0.77, 0.88),
                settingsDivider: .white.opacity(0.10),
                settingsCardBorder: .white.opacity(0.08),
                settingsAccent: .rgb(0.42, 0.57, 0.98),
                settingsAccentText: .white,
                settingsSecondaryButtonBackground: .rgb(0.18, 0.23, 0.33),
                settingsSecondaryButtonText: .rgb(0.93, 0.96, 1.0),
                destructiveTint: .rgb(0.78, 0.23, 0.31),
                dashboardCardBackground: .white.opacity(0.08),
                dashboardCardBorder: .white.opacity(0.09),
                dashboardPrimaryText: .rgb(0.94, 0.97, 1.0),
                dashboardSecondaryText: .white.opacity(0.74),
                dashboardMutedText: .white.opacity(0.62),
                dashboardSubtleText: .white.opacity(0.72),
                dashboardNeutralButton: .white.opacity(0.15),
                dashboardNeutralButtonText: .white,
                dashboardSuccessButton: .rgb(0.16, 0.70, 0.52),
                dashboardSuccessButtonText: .white,
                dashboardWarningButton: .rgb(0.86, 0.45, 0.28),
                dashboardWarningButtonText: .white,
                dashboardStatusLive: .rgb(0.37, 0.93, 0.69),
                dashboardStatusIdle: .rgb(0.91, 0.57, 0.31),
                externalDisplayBackground: .rgb(0.01, 0.02, 0.04),
                boardBackground: [
                    .rgb(0.01, 0.03, 0.06),
                    .rgb(0.04, 0.05, 0.11),
                    .rgb(0.01, 0.01, 0.04)
                ],
                boardHighlightTop: .white.opacity(0.06),
                boardHighlightBottom: .white.opacity(0.02),
                boardPanelBackground: .white.opacity(0.06),
                boardClockPanelBackground: .white.opacity(0.09),
                boardPanelBorder: .white.opacity(0.09),
                boardPrimaryText: .rgb(0.95, 0.98, 1.0),
                boardSecondaryText: .white.opacity(0.52),
                boardBadgeBackground: .white.opacity(0.10),
                boardBadgeBorder: .white.opacity(0.10),
                boardBadgeTitleText: .white.opacity(0.58),
                boardBadgeValueText: .rgb(0.95, 0.98, 1.0),
                homeAccent: .rgb(0.93, 0.39, 0.42),
                guestAccent: .rgb(0.38, 0.70, 1.0)
            )
        case .sunlight:
            return ThemePalette(
                appSetupBackground: [
                    .rgb(0.99, 0.95, 0.84),
                    .rgb(0.97, 0.88, 0.69)
                ],
                appDashboardBackground: [
                    .rgb(0.24, 0.18, 0.12),
                    .rgb(0.45, 0.29, 0.14),
                    .rgb(0.79, 0.54, 0.16)
                ],
                settingsShellBackground: .rgb(0.99, 0.96, 0.90),
                settingsSidebarBackground: .rgb(0.97, 0.92, 0.82),
                settingsDetailBackground: .rgb(0.98, 0.94, 0.86),
                settingsCardBackground: .rgb(1.0, 0.98, 0.94),
                settingsFieldBackground: .rgb(0.97, 0.93, 0.86),
                settingsPrimaryText: .rgb(0.22, 0.15, 0.08),
                settingsSecondaryText: .rgb(0.48, 0.34, 0.20),
                settingsDivider: .black.opacity(0.08),
                settingsCardBorder: .black.opacity(0.07),
                settingsAccent: .rgb(0.84, 0.42, 0.15),
                settingsAccentText: .white,
                settingsSecondaryButtonBackground: .rgb(0.95, 0.88, 0.75),
                settingsSecondaryButtonText: .rgb(0.22, 0.15, 0.08),
                destructiveTint: .rgb(0.77, 0.25, 0.18),
                dashboardCardBackground: .white.opacity(0.12),
                dashboardCardBorder: .white.opacity(0.12),
                dashboardPrimaryText: .white,
                dashboardSecondaryText: .white.opacity(0.78),
                dashboardMutedText: .white.opacity(0.68),
                dashboardSubtleText: .white.opacity(0.76),
                dashboardNeutralButton: .white.opacity(0.18),
                dashboardNeutralButtonText: .white,
                dashboardSuccessButton: .rgb(0.23, 0.65, 0.35),
                dashboardSuccessButtonText: .white,
                dashboardWarningButton: .rgb(0.90, 0.54, 0.18),
                dashboardWarningButtonText: .white,
                dashboardStatusLive: .rgb(0.47, 0.95, 0.51),
                dashboardStatusIdle: .rgb(1.0, 0.78, 0.27),
                externalDisplayBackground: .rgb(0.16, 0.11, 0.05),
                boardBackground: [
                    .rgb(0.17, 0.11, 0.05),
                    .rgb(0.29, 0.18, 0.07),
                    .rgb(0.10, 0.06, 0.03)
                ],
                boardHighlightTop: .white.opacity(0.08),
                boardHighlightBottom: .white.opacity(0.04),
                boardPanelBackground: .white.opacity(0.08),
                boardClockPanelBackground: .white.opacity(0.11),
                boardPanelBorder: .white.opacity(0.11),
                boardPrimaryText: .white,
                boardSecondaryText: .white.opacity(0.55),
                boardBadgeBackground: .white.opacity(0.10),
                boardBadgeBorder: .white.opacity(0.10),
                boardBadgeTitleText: .white.opacity(0.62),
                boardBadgeValueText: .white,
                homeAccent: .rgb(0.96, 0.49, 0.18),
                guestAccent: .rgb(0.22, 0.65, 0.95)
            )
        }
    }
}

struct ThemePalette {
    let appSetupBackground: [Color]
    let appDashboardBackground: [Color]
    let settingsShellBackground: Color
    let settingsSidebarBackground: Color
    let settingsDetailBackground: Color
    let settingsCardBackground: Color
    let settingsFieldBackground: Color
    let settingsPrimaryText: Color
    let settingsSecondaryText: Color
    let settingsDivider: Color
    let settingsCardBorder: Color
    let settingsAccent: Color
    let settingsAccentText: Color
    let settingsSecondaryButtonBackground: Color
    let settingsSecondaryButtonText: Color
    let destructiveTint: Color
    let dashboardCardBackground: Color
    let dashboardCardBorder: Color
    let dashboardPrimaryText: Color
    let dashboardSecondaryText: Color
    let dashboardMutedText: Color
    let dashboardSubtleText: Color
    let dashboardNeutralButton: Color
    let dashboardNeutralButtonText: Color
    let dashboardSuccessButton: Color
    let dashboardSuccessButtonText: Color
    let dashboardWarningButton: Color
    let dashboardWarningButtonText: Color
    let dashboardStatusLive: Color
    let dashboardStatusIdle: Color
    let externalDisplayBackground: Color
    let boardBackground: [Color]
    let boardHighlightTop: Color
    let boardHighlightBottom: Color
    let boardPanelBackground: Color
    let boardClockPanelBackground: Color
    let boardPanelBorder: Color
    let boardPrimaryText: Color
    let boardSecondaryText: Color
    let boardBadgeBackground: Color
    let boardBadgeBorder: Color
    let boardBadgeTitleText: Color
    let boardBadgeValueText: Color
    let homeAccent: Color
    let guestAccent: Color
}

struct SettingsPalette {
    let shellBackground: Color
    let sidebarBackground: Color
    let detailBackground: Color
    let cardBackground: Color
    let fieldBackground: Color
    let primaryText: Color
    let secondaryText: Color
    let divider: Color
    let cardBorder: Color
    let accent: Color
    let accentText: Color
    let secondaryButtonBackground: Color
    let secondaryButtonText: Color
}

extension ThemePalette {
    func settingsPalette(for theme: ScoreboardTheme, colorScheme: ColorScheme) -> SettingsPalette {
        guard theme == .classic, colorScheme == .dark else {
            return SettingsPalette(
                shellBackground: settingsShellBackground,
                sidebarBackground: settingsSidebarBackground,
                detailBackground: settingsDetailBackground,
                cardBackground: settingsCardBackground,
                fieldBackground: settingsFieldBackground,
                primaryText: settingsPrimaryText,
                secondaryText: settingsSecondaryText,
                divider: settingsDivider,
                cardBorder: settingsCardBorder,
                accent: settingsAccent,
                accentText: settingsAccentText,
                secondaryButtonBackground: settingsSecondaryButtonBackground,
                secondaryButtonText: settingsSecondaryButtonText
            )
        }

        return SettingsPalette(
            shellBackground: .rgb(0.07, 0.08, 0.11),
            sidebarBackground: .rgb(0.04, 0.05, 0.08),
            detailBackground: .rgb(0.09, 0.10, 0.14),
            cardBackground: .rgb(0.13, 0.14, 0.19),
            fieldBackground: .rgb(0.16, 0.18, 0.24),
            primaryText: .rgb(0.95, 0.96, 0.99),
            secondaryText: .rgb(0.70, 0.74, 0.82),
            divider: .white.opacity(0.10),
            cardBorder: .white.opacity(0.08),
            accent: settingsAccent,
            accentText: .white,
            secondaryButtonBackground: .rgb(0.18, 0.20, 0.27),
            secondaryButtonText: .rgb(0.95, 0.96, 0.99)
        )
    }
}

private extension Color {
    static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red, green: green, blue: blue)
    }
}
