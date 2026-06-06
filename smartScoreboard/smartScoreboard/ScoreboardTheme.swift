import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum ExternalDisplayBackgroundMode: String, Codable, CaseIterable, Identifiable {
    case blurred
    case clear
    case clearUnderBoard
    case smartScoreboard
    case image
    case animatedLogo
    case none

    var id: String { rawValue }

    static let isAnimatedLogoBackgroundEnabled = false

    static var selectableThemeModes: [ExternalDisplayBackgroundMode] {
        allCases.filter { mode in
            mode != .animatedLogo || isAnimatedLogoBackgroundEnabled
        }
    }

    var resolvedForRendering: ExternalDisplayBackgroundMode {
        if self == .animatedLogo, !Self.isAnimatedLogoBackgroundEnabled {
            return .blurred
        }

        return self
    }

    var title: String {
        switch self {
        case .blurred:
            return "Blurred"
        case .clear:
            return "Split Background"
        case .clearUnderBoard:
            return "Through Scoreboard"
        case .smartScoreboard:
            return "Smart Scoreboard"
        case .image:
            return "Photo"
        case .animatedLogo:
            return "Animated Logo"
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
        case .smartScoreboard:
            return "Use the bundled Smart Scoreboard background."
        case .image:
            return "Use a selected photo as the public display background."
        case .animatedLogo:
            if !Self.isAnimatedLogoBackgroundEnabled {
                return "Temporarily disabled; falls back to the blurred background."
            }
            return "Tile the selected background photo as an animated logo pattern."
        case .none:
            return "Leave the external display background unfilled outside the scoreboard."
        }
    }

    var usesSelectedBackgroundPhoto: Bool {
        self == .image || (self == .animatedLogo && Self.isAnimatedLogoBackgroundEnabled)
    }
}

enum ExternalDisplayAnimatedLogoStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case horizontalMarquee
    case diagonalMarquee
    case waveDrift
    case checkerFade

    var id: String { rawValue }

    var title: String {
        switch self {
        case .horizontalMarquee:
            return "Horizontal Marquee"
        case .diagonalMarquee:
            return "Diagonal Marquee"
        case .waveDrift:
            return "Wave Drift"
        case .checkerFade:
            return "Checker Fade"
        }
    }

    var subtitle: String {
        switch self {
        case .horizontalMarquee:
            return "Rows of logos move across the display."
        case .diagonalMarquee:
            return "The logo pattern travels on a slight slope."
        case .waveDrift:
            return "Rows glide with a soft vertical wave."
        case .checkerFade:
            return "Logo tiles fade through a black-and-white checker pattern."
        }
    }
}

enum ExternalDisplayAnimatedLogoBackgroundColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case themeBackground
    case black
    case white
    case homeAccent
    case guestAccent
    case splitAccent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .themeBackground:
            return "Theme"
        case .black:
            return "Black"
        case .white:
            return "White"
        case .homeAccent:
            return "Home Color"
        case .guestAccent:
            return "Guest Color"
        case .splitAccent:
            return "Split Colors"
        }
    }
}

struct ExternalDisplayAnimatedLogoBackgroundFill: View {
    let selection: ExternalDisplayAnimatedLogoBackgroundColor
    let palette: ThemePalette

    var body: some View {
        switch selection {
        case .themeBackground:
            palette.externalDisplayBackground
        case .black:
            Color.black
        case .white:
            Color.white
        case .homeAccent:
            palette.homeAccent
        case .guestAccent:
            palette.guestAccent
        case .splitAccent:
            HStack(spacing: 0) {
                palette.homeAccent
                palette.guestAccent
            }
        }
    }
}

enum ExternalDisplayDateTimeFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case time12Hour
    case time24Hour
    case dateTime12Hour
    case dateTime24Hour

    var id: String { rawValue }

    var title: String {
        switch self {
        case .time12Hour:
            return "12-Hour Time"
        case .time24Hour:
            return "24-Hour Time"
        case .dateTime12Hour:
            return "Date + 12-Hour"
        case .dateTime24Hour:
            return "Date + 24-Hour"
        }
    }

    func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    private var dateFormat: String {
        switch self {
        case .time12Hour:
            return "h:mm a"
        case .time24Hour:
            return "HH:mm"
        case .dateTime12Hour:
            return "MMM d, h:mm a"
        case .dateTime24Hour:
            return "MMM d, HH:mm"
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

struct ExternalDisplayBackgroundImage: Codable, Equatable, Sendable {
    static let minScale: Double = 1
    static let maxScale: Double = 3
    static let minOffset: Double = -1
    static let maxOffset: Double = 1

    var id: String
    var sourceName: String?
    var mimeType: String
    var pixelWidth: Int
    var pixelHeight: Int
    var byteCount: Int
    var updatedAtUnixTime: TimeInterval
    var scale: Double
    var offsetX: Double
    var offsetY: Double
    var data: Data

    init(
        id: String = UUID().uuidString,
        sourceName: String?,
        mimeType: String = "image/jpeg",
        pixelWidth: Int,
        pixelHeight: Int,
        byteCount: Int,
        updatedAtUnixTime: TimeInterval = Date().timeIntervalSince1970,
        scale: Double = 1,
        offsetX: Double = 0,
        offsetY: Double = 0,
        data: Data
    ) {
        self.id = id
        self.sourceName = sourceName
        self.mimeType = mimeType
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteCount = byteCount
        self.updatedAtUnixTime = updatedAtUnixTime
        self.scale = Self.boundedScale(scale)
        self.offsetX = Self.boundedOffset(offsetX)
        self.offsetY = Self.boundedOffset(offsetY)
        self.data = data
    }

    var displayName: String {
        let trimmed = sourceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Selected Photo" : trimmed
    }

    var path: String {
        Self.currentPath
    }

    var versionedPath: String {
        "\(Self.currentPath)/\(id)"
    }

    var legacyVersionedPath: String {
        "\(versionedPath).jpg"
    }

    static var currentPath: String {
        "/api/v1/display/background-image"
    }

    func withPlacement(scale: Double, offsetX: Double, offsetY: Double) -> ExternalDisplayBackgroundImage {
        var image = self
        image.scale = Self.boundedScale(scale)
        image.offsetX = Self.boundedOffset(offsetX)
        image.offsetY = Self.boundedOffset(offsetY)
        image.updatedAtUnixTime = Date().timeIntervalSince1970
        return image
    }

    static func boundedScale(_ value: Double) -> Double {
        min(maxScale, max(minScale, value))
    }

    static func boundedOffset(_ value: Double) -> Double {
        min(maxOffset, max(minOffset, value))
    }
}

struct TeamLogoImage: Codable, Equatable, Sendable {
    var id: String
    var sourceName: String?
    var mimeType: String
    var pixelWidth: Int
    var pixelHeight: Int
    var byteCount: Int
    var updatedAtUnixTime: TimeInterval
    var data: Data

    init(
        id: String = UUID().uuidString,
        sourceName: String?,
        mimeType: String = "image/png",
        pixelWidth: Int,
        pixelHeight: Int,
        byteCount: Int,
        updatedAtUnixTime: TimeInterval = Date().timeIntervalSince1970,
        data: Data
    ) {
        self.id = id
        self.sourceName = sourceName
        self.mimeType = mimeType
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteCount = byteCount
        self.updatedAtUnixTime = updatedAtUnixTime
        self.data = data
    }

    var displayName: String {
        let trimmed = sourceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Team Logo" : trimmed
    }

    func path(for side: TeamSide) -> String {
        Self.currentPath(for: side)
    }

    func versionedPath(for side: TeamSide) -> String {
        "\(Self.currentPath(for: side))/\(id)"
    }

    func legacyVersionedPath(for side: TeamSide) -> String {
        "\(versionedPath(for: side)).png"
    }

    static func currentPath(for side: TeamSide) -> String {
        "/api/v1/teams/\(side.rawValue)/logo"
    }
}

struct EventLogoImage: Codable, Equatable, Sendable {
    var id: String
    var sourceName: String?
    var mimeType: String
    var pixelWidth: Int
    var pixelHeight: Int
    var byteCount: Int
    var updatedAtUnixTime: TimeInterval
    var data: Data

    init(
        id: String = UUID().uuidString,
        sourceName: String?,
        mimeType: String = "image/png",
        pixelWidth: Int,
        pixelHeight: Int,
        byteCount: Int,
        updatedAtUnixTime: TimeInterval = Date().timeIntervalSince1970,
        data: Data
    ) {
        self.id = id
        self.sourceName = sourceName
        self.mimeType = mimeType
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteCount = byteCount
        self.updatedAtUnixTime = updatedAtUnixTime
        self.data = data
    }

    var displayName: String {
        let trimmed = sourceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Event Logo" : trimmed
    }

    var path: String {
        Self.currentPath
    }

    var versionedPath: String {
        "\(Self.currentPath)/\(id)"
    }

    var legacyVersionedPath: String {
        "\(versionedPath).png"
    }

    static var currentPath: String {
        "/api/v1/display/event-logo"
    }
}

nonisolated struct ScoreboardWebAPIBackgroundImage: Codable, Sendable {
    let id: String
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int
    let updatedAtUnixTime: TimeInterval
    let placement: ScoreboardWebAPIBackgroundImagePlacement
    let path: String
    let downloadURLs: [String]
}

nonisolated struct ScoreboardWebAPIBackgroundImagePlacement: Codable, Sendable {
    let scale: Double
    let offsetX: Double
    let offsetY: Double
}

nonisolated struct ScoreboardWebAPITeamLogo: Codable, Sendable {
    let id: String
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int
    let updatedAtUnixTime: TimeInterval
    let path: String
    let downloadURLs: [String]
}

nonisolated struct ScoreboardWebAPIEventLogo: Codable, Sendable {
    let id: String
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int
    let updatedAtUnixTime: TimeInterval
    let path: String
    let downloadURLs: [String]
}

enum ScoreboardDisplayImageError: LocalizedError {
    case unreadableImage
    case compressionFailed
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "The selected image could not be read."
        case .compressionFailed:
            return "The selected image could not be encoded for display."
        case .processingFailed:
            return "The selected image could not be prepared for display."
        }
    }
}

enum ScoreboardDisplayImageProcessor {
    static func makeBackgroundImage(from data: Data, sourceName: String?) throws -> ExternalDisplayBackgroundImage {
        let cgImage = try downsampleImage(data, maxPixelSize: 1_920)
        let encodedData = try encode(cgImage, type: .jpeg, quality: 0.86)
        return ExternalDisplayBackgroundImage(
            sourceName: sourceName,
            pixelWidth: cgImage.width,
            pixelHeight: cgImage.height,
            byteCount: encodedData.count,
            data: encodedData
        )
    }

    static func makeTeamLogo(from data: Data, sourceName: String?) throws -> TeamLogoImage {
        let downsampledImage = try downsampleImage(data, maxPixelSize: 512)
        let renderedImage = try transparentLogoCanvas(from: downsampledImage)
        let encodedData = try encode(renderedImage, type: .png, quality: nil)
        return TeamLogoImage(
            sourceName: sourceName,
            pixelWidth: renderedImage.width,
            pixelHeight: renderedImage.height,
            byteCount: encodedData.count,
            data: encodedData
        )
    }

    static func makeEventLogo(from data: Data, sourceName: String?) throws -> EventLogoImage {
        let downsampledImage = try downsampleImage(data, maxPixelSize: 512)
        let renderedImage = try transparentLogoCanvas(from: downsampledImage)
        let encodedData = try encode(renderedImage, type: .png, quality: nil)
        return EventLogoImage(
            sourceName: sourceName,
            pixelWidth: renderedImage.width,
            pixelHeight: renderedImage.height,
            byteCount: encodedData.count,
            data: encodedData
        )
    }

    private static func downsampleImage(_ data: Data, maxPixelSize: Int) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            throw ScoreboardDisplayImageError.unreadableImage
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw ScoreboardDisplayImageError.unreadableImage
        }

        return image
    }

    private enum EncodedImageType {
        case jpeg
        case png

        var identifier: CFString {
            switch self {
            case .jpeg:
                return UTType.jpeg.identifier as CFString
            case .png:
                return UTType.png.identifier as CFString
            }
        }
    }

    private static func encode(_ cgImage: CGImage, type: EncodedImageType, quality: Double?) throws -> Data {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, type.identifier, 1, nil) else {
            throw ScoreboardDisplayImageError.compressionFailed
        }

        var properties: [CFString: Any] = [:]
        if let quality {
            properties[kCGImageDestinationLossyCompressionQuality] = quality
        }
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ScoreboardDisplayImageError.compressionFailed
        }

        return mutableData as Data
    }

    private static func transparentLogoCanvas(from cgImage: CGImage) throws -> CGImage {
        let canvasSize = 512
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: canvasSize,
            height: canvasSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw ScoreboardDisplayImageError.processingFailed
        }

        context.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
        context.interpolationQuality = .high
        let sourceSize = CGSize(width: cgImage.width, height: cgImage.height)
        let drawRect = sourceSize.aspectFit(in: CGSize(width: canvasSize, height: canvasSize))
        context.draw(cgImage, in: drawRect)

        guard let output = context.makeImage() else {
            throw ScoreboardDisplayImageError.processingFailed
        }
        return output
    }
}

fileprivate func scoreboardCGImage(from data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
        return nil
    }
    return CGImageSourceCreateImageAtIndex(source, 0, [
        kCGImageSourceShouldCache: false
    ] as CFDictionary)
}

struct ExternalDisplayBackgroundImageView: View {
    let data: Data
    let scale: Double
    let offsetX: Double
    let offsetY: Double

    init(image: ExternalDisplayBackgroundImage) {
        data = image.data
        scale = image.scale
        offsetX = image.offsetX
        offsetY = image.offsetY
    }

    init(data: Data, scale: Double, offsetX: Double, offsetY: Double) {
        self.data = data
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    var body: some View {
        GeometryReader { proxy in
            if let cgImage = scoreboardCGImage(from: data) {
                Image(decorative: cgImage, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(CGFloat(ExternalDisplayBackgroundImage.boundedScale(scale)))
                    .offset(
                        x: CGFloat(ExternalDisplayBackgroundImage.boundedOffset(offsetX)) * proxy.size.width * 0.5,
                        y: CGFloat(ExternalDisplayBackgroundImage.boundedOffset(offsetY)) * proxy.size.height * 0.5
                    )
                    .clipped()
            } else {
                Color.clear
            }
        }
        .clipped()
    }
}

struct SmartScoreboardBackgroundView: View {
    var body: some View {
        Image("SmartScoreboardBackground")
            .resizable()
            .scaledToFill()
            .clipped()
    }
}

struct ExternalDisplayAnimatedLogoBackgroundView: View {
    let data: Data?
    let style: ExternalDisplayAnimatedLogoStyle
    let backgroundColor: ExternalDisplayAnimatedLogoBackgroundColor
    let speed: Int
    let logoSize: Int
    let logoOpacity: Double
    let palette: ThemePalette
    var animates: Bool = true

    private var boundedSpeed: CGFloat {
        CGFloat(max(8, min(180, speed)))
    }

    private var boundedLogoSize: CGFloat {
        CGFloat(max(44, min(240, logoSize)))
    }

    private var boundedLogoOpacity: Double {
        max(0.05, min(0.75, logoOpacity))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ExternalDisplayAnimatedLogoBackgroundFill(selection: backgroundColor, palette: palette)

                if let data, let cgImage = scoreboardCGImage(from: data) {
                    if animates {
                        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                            animatedLogoPattern(
                                cgImage: cgImage,
                                displaySize: proxy.size,
                                date: timeline.date
                            )
                        }
                    } else {
                        animatedLogoPattern(
                            cgImage: cgImage,
                            displaySize: proxy.size,
                            date: Date(timeIntervalSinceReferenceDate: 0)
                        )
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: min(proxy.size.width, proxy.size.height) * 0.10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.16))
                }

                LinearGradient(
                    colors: [.black.opacity(0.26), .clear, .black.opacity(0.30)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func animatedLogoPattern(cgImage: CGImage, displaySize: CGSize, date: Date) -> some View {
        switch style {
        case .horizontalMarquee:
            movingLogoRows(cgImage: cgImage, displaySize: displaySize, date: date, rotationDegrees: 0, wave: false)
        case .diagonalMarquee:
            movingLogoRows(cgImage: cgImage, displaySize: displaySize, date: date, rotationDegrees: -11, wave: false)
                .scaleEffect(1.16)
        case .waveDrift:
            movingLogoRows(cgImage: cgImage, displaySize: displaySize, date: date, rotationDegrees: 0, wave: true)
        case .checkerFade:
            checkerFadeLogoGrid(cgImage: cgImage, displaySize: displaySize, date: date)
        }
    }

    private func movingLogoRows(
        cgImage: CGImage,
        displaySize: CGSize,
        date: Date,
        rotationDegrees: Double,
        wave: Bool
    ) -> some View {
        let logoSize = boundedLogoSize
        let horizontalGap = logoSize * 1.55
        let verticalGap = logoSize * 1.22
        let columnCount = max(4, Int(ceil(displaySize.width / horizontalGap)) + 5)
        let rowCount = max(3, Int(ceil(displaySize.height / verticalGap)) + 4)
        let time = CGFloat(date.timeIntervalSinceReferenceDate)
        let baseOffset = (time * boundedSpeed).truncatingRemainder(dividingBy: horizontalGap)

        return ZStack {
            ForEach(0..<rowCount, id: \.self) { row in
                ForEach(0..<columnCount, id: \.self) { column in
                    let rowDirection: CGFloat = row.isMultiple(of: 2) ? 1 : -1
                    let rowOffset = rowDirection > 0 ? -baseOffset : baseOffset
                    let x = (CGFloat(column) * horizontalGap) - horizontalGap + rowOffset + (row.isMultiple(of: 2) ? 0 : horizontalGap * 0.42)
                    let waveOffset = wave ? sin((time * 0.72) + (CGFloat(column) * 0.85) + CGFloat(row)) * logoSize * 0.22 : 0
                    let y = (CGFloat(row) * verticalGap) - verticalGap + waveOffset

                    logoTile(cgImage: cgImage, size: logoSize, opacity: boundedLogoOpacity)
                        .position(x: x, y: y)
                }
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .rotationEffect(.degrees(rotationDegrees))
    }

    private func checkerFadeLogoGrid(cgImage: CGImage, displaySize: CGSize, date: Date) -> some View {
        let tileSize = boundedLogoSize * 1.30
        let columnCount = max(3, Int(ceil(displaySize.width / tileSize)) + 2)
        let rowCount = max(3, Int(ceil(displaySize.height / tileSize)) + 2)
        let time = date.timeIntervalSinceReferenceDate
        let phaseSpeed = max(0.18, Double(boundedSpeed) / 54.0)

        return ZStack {
            ForEach(0..<rowCount, id: \.self) { row in
                ForEach(0..<columnCount, id: \.self) { column in
                    let isLightTile = (row + column).isMultiple(of: 2)
                    let phase = (sin((time * phaseSpeed) + Double(row + column) * 0.82) + 1) / 2
                    let phaseOpacity = isLightTile ? phase : 1 - phase
                    let logoOpacity = max(0, min(1, boundedLogoOpacity * (0.61 + phaseOpacity * 1.39)))
                    let tileColor = isLightTile
                        ? Color.white.opacity(0.05 + phase * 0.10)
                        : Color.black.opacity(0.16 + phase * 0.22)
                    let x = (CGFloat(column) * tileSize) - (tileSize * 0.5)
                    let y = (CGFloat(row) * tileSize) - (tileSize * 0.5)

                    ZStack {
                        Rectangle()
                            .fill(tileColor)
                        logoTile(cgImage: cgImage, size: tileSize * 0.54, opacity: logoOpacity)
                    }
                    .frame(width: tileSize, height: tileSize)
                    .position(x: x, y: y)
                }
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
    }

    private func logoTile(cgImage: CGImage, size: CGFloat, opacity: Double) -> some View {
        Image(decorative: cgImage, scale: 1, orientation: .up)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .opacity(opacity)
            .shadow(color: .black.opacity(0.30), radius: size * 0.08, x: 0, y: size * 0.02)
    }
}

struct TeamLogoImageView: View {
    let data: Data
    var cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            if let cgImage = Self.cgImage(from: data) {
                Image(decorative: cgImage, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.10), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary)
    }
}

private extension CGSize {
    func aspectFit(in container: CGSize) -> CGRect {
        guard width > 0, height > 0, container.width > 0, container.height > 0 else {
            return .zero
        }

        let ratio = min(container.width / width, container.height / height)
        let fittedSize = CGSize(width: width * ratio, height: height * ratio)
        return CGRect(
            x: (container.width - fittedSize.width) * 0.5,
            y: (container.height - fittedSize.height) * 0.5,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}
