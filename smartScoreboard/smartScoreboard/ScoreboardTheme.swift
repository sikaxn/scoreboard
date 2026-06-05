import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ExternalDisplayBackgroundMode: String, Codable, CaseIterable, Identifiable {
    case blurred
    case clear
    case clearUnderBoard
    case image
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
        case .image:
            return "Photo"
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
        case .image:
            return "Use a selected photo as the external display background."
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

struct ExternalDisplayBackgroundImage: Codable, Equatable, Sendable {
    static let minimumScale = 1.0
    static let maximumScale = 3.0
    static let minimumOffset = -1.0
    static let maximumOffset = 1.0

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

    var path: String {
        Self.path(for: id)
    }

    var displayName: String {
        guard let sourceName, !sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Custom background"
        }
        return sourceName
    }

    init(
        id: String,
        sourceName: String?,
        mimeType: String,
        pixelWidth: Int,
        pixelHeight: Int,
        byteCount: Int,
        updatedAtUnixTime: TimeInterval = Date().timeIntervalSince1970,
        scale: Double = 1.0,
        offsetX: Double = 0,
        offsetY: Double = 0
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
    }

    static func path(for id: String) -> String {
        "/api/v1/display/background-image/\(id).jpg"
    }

    static func boundedScale(_ value: Double) -> Double {
        min(maximumScale, max(minimumScale, value))
    }

    static func boundedOffset(_ value: Double) -> Double {
        min(maximumOffset, max(minimumOffset, value))
    }
}

struct ScoreboardWebAPIBackgroundImage: Codable, Equatable, Sendable {
    let id: String
    let sourceName: String?
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int
    let updatedAtUnixTime: TimeInterval
    let scale: Double
    let offsetX: Double
    let offsetY: Double
    let path: String
    let downloadURLs: [String]

    init(image: ExternalDisplayBackgroundImage, downloadURLs: [String]) {
        id = image.id
        sourceName = image.sourceName
        mimeType = image.mimeType
        pixelWidth = image.pixelWidth
        pixelHeight = image.pixelHeight
        byteCount = image.byteCount
        updatedAtUnixTime = image.updatedAtUnixTime
        scale = image.scale
        offsetX = image.offsetX
        offsetY = image.offsetY
        path = image.path
        self.downloadURLs = downloadURLs
    }
}

enum ExternalDisplayBackgroundImageError: LocalizedError {
    case unreadableImage
    case compressionFailed
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "Choose a valid image file."
        case .compressionFailed:
            return "Scoreboard could not prepare that image for display."
        case .storageUnavailable:
            return "Scoreboard could not save the background image."
        }
    }
}

enum ExternalDisplayBackgroundImageStorage {
    private static let directoryName = "ExternalDisplayBackgrounds"
    private static let maxPixelDimension: CGFloat = 1920
    private static let jpegQuality: CGFloat = 0.78

    struct ProcessedImage {
        let data: Data
        let mimeType: String
        let pixelWidth: Int
        let pixelHeight: Int
    }

    static func makeImage(from sourceData: Data, sourceName: String?) throws -> ExternalDisplayBackgroundImage {
        let processedImage = try processImageData(sourceData)
        let id = UUID().uuidString
        let url = try fileURL(for: id)

        do {
            try ensureDirectoryExists()
            try processedImage.data.write(to: url, options: [.atomic])
        } catch {
            throw ExternalDisplayBackgroundImageError.storageUnavailable
        }

        return ExternalDisplayBackgroundImage(
            id: id,
            sourceName: sourceName,
            mimeType: processedImage.mimeType,
            pixelWidth: processedImage.pixelWidth,
            pixelHeight: processedImage.pixelHeight,
            byteCount: processedImage.data.count
        )
    }

    static func makeImage(from embeddedImage: ScoreboardGameEmbeddedImage) throws -> ExternalDisplayBackgroundImage {
        guard embeddedImage.isRestorable(expectedMimeType: "image/jpeg") else {
            throw ExternalDisplayBackgroundImageError.storageUnavailable
        }

        let id = UUID().uuidString
        try restoreImage(id: id, data: embeddedImage.data)
        return ExternalDisplayBackgroundImage(
            id: id,
            sourceName: embeddedImage.sourceName,
            mimeType: embeddedImage.mimeType,
            pixelWidth: embeddedImage.pixelWidth,
            pixelHeight: embeddedImage.pixelHeight,
            byteCount: embeddedImage.data.count,
            updatedAtUnixTime: embeddedImage.updatedAtUnixTime,
            scale: embeddedImage.scale ?? 1,
            offsetX: embeddedImage.offsetX ?? 0,
            offsetY: embeddedImage.offsetY ?? 0
        )
    }

    static func imageData(for image: ExternalDisplayBackgroundImage?) -> Data? {
        guard let image else {
            return nil
        }
        return imageData(forID: image.id)
    }

    static func imageData(forID id: String) -> Data? {
        guard isValidImageID(id), let url = try? fileURL(for: id) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    static func removeImage(id: String) {
        guard isValidImageID(id), let url = try? fileURL(for: id) else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    static func restoreImage(id: String, data: Data) throws {
        guard isRestorableImage(id: id, data: data) else {
            throw ExternalDisplayBackgroundImageError.storageUnavailable
        }

        do {
            try ensureDirectoryExists()
            try data.write(to: try fileURL(for: id), options: [.atomic])
        } catch {
            throw ExternalDisplayBackgroundImageError.storageUnavailable
        }
    }

    static func isRestorableImage(id: String, data: Data) -> Bool {
        isValidImageID(id) && !data.isEmpty
    }

    static func removeAllImages(except retainedID: String? = nil) {
        guard let directoryURL = try? directoryURL() else {
            return
        }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in urls {
            if let retainedID, url.lastPathComponent == "\(retainedID).jpg" {
                continue
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func imageID(fromWebAPIPath path: String) -> String? {
        let prefix = "/api/v1/display/background-image/"
        guard path.hasPrefix(prefix), path.hasSuffix(".jpg") else {
            return nil
        }

        let start = path.index(path.startIndex, offsetBy: prefix.count)
        let end = path.index(path.endIndex, offsetBy: -4)
        let id = String(path[start..<end])
        return isValidImageID(id) ? id : nil
    }

    private static func directoryURL() throws -> URL {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ExternalDisplayBackgroundImageError.storageUnavailable
        }

        let bundleDirectory = Bundle.main.bundleIdentifier ?? "smartScoreboard"
        return applicationSupportURL
            .appendingPathComponent(bundleDirectory, isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func fileURL(for id: String) throws -> URL {
        guard isValidImageID(id) else {
            throw ExternalDisplayBackgroundImageError.storageUnavailable
        }
        return try directoryURL().appendingPathComponent("\(id).jpg", isDirectory: false)
    }

    private static func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: directoryURL(),
            withIntermediateDirectories: true
        )
    }

    private static func isValidImageID(_ id: String) -> Bool {
        guard !id.isEmpty else {
            return false
        }
        return id.range(of: #"^[A-Za-z0-9-]+$"#, options: .regularExpression) != nil
    }

    private static func scaledPixelSize(width: Int, height: Int) -> CGSize {
        let sourceWidth = max(CGFloat(width), 1)
        let sourceHeight = max(CGFloat(height), 1)
        let scale = min(1, maxPixelDimension / max(sourceWidth, sourceHeight))
        return CGSize(
            width: max(1, (sourceWidth * scale).rounded()),
            height: max(1, (sourceHeight * scale).rounded())
        )
    }

    #if canImport(UIKit)
    private static func processImageData(_ data: Data) throws -> ProcessedImage {
        guard let sourceImage = UIImage(data: data) else {
            throw ExternalDisplayBackgroundImageError.unreadableImage
        }

        let sourceScale = max(sourceImage.scale, 1)
        let pixelWidth = Int((sourceImage.size.width * sourceScale).rounded())
        let pixelHeight = Int((sourceImage.size.height * sourceScale).rounded())
        let targetSize = scaledPixelSize(width: pixelWidth, height: pixelHeight)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let renderedImage = renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let jpegData = renderedImage.jpegData(compressionQuality: jpegQuality) else {
            throw ExternalDisplayBackgroundImageError.compressionFailed
        }

        return ProcessedImage(
            data: jpegData,
            mimeType: "image/jpeg",
            pixelWidth: Int(targetSize.width.rounded()),
            pixelHeight: Int(targetSize.height.rounded())
        )
    }
    #elseif canImport(AppKit)
    private static func processImageData(_ data: Data) throws -> ProcessedImage {
        guard let sourceImage = NSImage(data: data) else {
            throw ExternalDisplayBackgroundImageError.unreadableImage
        }

        let representation = sourceImage.representations.max {
            ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh)
        }
        let pixelWidth = max(representation?.pixelsWide ?? Int(sourceImage.size.width.rounded()), 1)
        let pixelHeight = max(representation?.pixelsHigh ?? Int(sourceImage.size.height.rounded()), 1)
        let targetSize = scaledPixelSize(width: pixelWidth, height: pixelHeight)
        let renderedImage = NSImage(size: targetSize)

        renderedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        sourceImage.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        renderedImage.unlockFocus()

        guard
            let tiffData = renderedImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let jpegData = bitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: jpegQuality]
            )
        else {
            throw ExternalDisplayBackgroundImageError.compressionFailed
        }

        return ProcessedImage(
            data: jpegData,
            mimeType: "image/jpeg",
            pixelWidth: Int(targetSize.width.rounded()),
            pixelHeight: Int(targetSize.height.rounded())
        )
    }
    #else
    private static func processImageData(_ data: Data) throws -> ProcessedImage {
        _ = data
        throw ExternalDisplayBackgroundImageError.unreadableImage
    }
    #endif
}

struct ExternalDisplayBackgroundImageView: View {
    let data: Data?
    let scale: Double
    let offsetX: Double
    let offsetY: Double

    init(data: Data?, scale: Double, offsetX: Double, offsetY: Double) {
        self.data = data
        self.scale = ExternalDisplayBackgroundImage.boundedScale(scale)
        self.offsetX = ExternalDisplayBackgroundImage.boundedOffset(offsetX)
        self.offsetY = ExternalDisplayBackgroundImage.boundedOffset(offsetY)
    }

    init(image: ExternalDisplayBackgroundImage?) {
        self.init(
            data: ExternalDisplayBackgroundImageStorage.imageData(for: image),
            scale: image?.scale ?? 1,
            offsetX: image?.offsetX ?? 0,
            offsetY: image?.offsetY ?? 0
        )
    }

    init(image: ScoreboardWebAPIBackgroundImage?, data: Data?) {
        self.init(
            data: data,
            scale: image?.scale ?? 1,
            offsetX: image?.offsetX ?? 0,
            offsetY: image?.offsetY ?? 0
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let platformImage = makePlatformImage() {
                    platformImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(CGFloat(scale), anchor: .center)
                        .offset(
                            x: CGFloat(offsetX) * proxy.size.width * 0.5,
                            y: CGFloat(offsetY) * proxy.size.height * 0.5
                        )
                } else {
                    Color.clear
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    private func makePlatformImage() -> Image? {
        guard let data else {
            return nil
        }

        #if canImport(UIKit)
        guard let image = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else {
            return nil
        }
        return Image(nsImage: image)
        #else
        return nil
        #endif
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

    func path(for side: TeamSide) -> String {
        Self.path(for: side, id: id)
    }

    var displayName: String {
        guard let sourceName, !sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Team logo"
        }
        return sourceName
    }

    init(
        id: String,
        sourceName: String?,
        mimeType: String,
        pixelWidth: Int,
        pixelHeight: Int,
        byteCount: Int,
        updatedAtUnixTime: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.sourceName = sourceName
        self.mimeType = mimeType
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteCount = byteCount
        self.updatedAtUnixTime = updatedAtUnixTime
    }

    static func path(for side: TeamSide, id: String) -> String {
        "/api/v1/teams/\(side.rawValue)/logo/\(id).png"
    }
}

struct ScoreboardWebAPITeamLogo: Codable, Equatable, Sendable {
    let id: String
    let sourceName: String?
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int
    let updatedAtUnixTime: TimeInterval
    let path: String
    let downloadURLs: [String]

    init(side: TeamSide, image: TeamLogoImage, downloadURLs: [String]) {
        id = image.id
        sourceName = image.sourceName
        mimeType = image.mimeType
        pixelWidth = image.pixelWidth
        pixelHeight = image.pixelHeight
        byteCount = image.byteCount
        updatedAtUnixTime = image.updatedAtUnixTime
        path = image.path(for: side)
        self.downloadURLs = downloadURLs
    }
}

enum TeamLogoImageError: LocalizedError {
    case unreadableImage
    case compressionFailed
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "Choose a valid team logo image."
        case .compressionFailed:
            return "Scoreboard could not prepare that logo for display."
        case .storageUnavailable:
            return "Scoreboard could not save the team logo."
        }
    }
}

enum TeamLogoImageStorage {
    private static let directoryName = "TeamLogos"
    private static let outputPixelSize = 512

    struct ProcessedImage {
        let data: Data
        let mimeType: String
        let pixelWidth: Int
        let pixelHeight: Int
    }

    static func makeImage(from sourceData: Data, sourceName: String?) throws -> TeamLogoImage {
        let processedImage = try processImageData(sourceData)
        let id = UUID().uuidString
        let url = try fileURL(for: id)

        do {
            try ensureDirectoryExists()
            try processedImage.data.write(to: url, options: [.atomic])
        } catch {
            throw TeamLogoImageError.storageUnavailable
        }

        return TeamLogoImage(
            id: id,
            sourceName: sourceName,
            mimeType: processedImage.mimeType,
            pixelWidth: processedImage.pixelWidth,
            pixelHeight: processedImage.pixelHeight,
            byteCount: processedImage.data.count
        )
    }

    static func makeImage(from embeddedImage: ScoreboardGameEmbeddedImage) throws -> TeamLogoImage {
        guard embeddedImage.isRestorable(expectedMimeType: "image/png") else {
            throw TeamLogoImageError.storageUnavailable
        }

        let id = UUID().uuidString
        try restoreImage(id: id, data: embeddedImage.data)
        return TeamLogoImage(
            id: id,
            sourceName: embeddedImage.sourceName,
            mimeType: embeddedImage.mimeType,
            pixelWidth: embeddedImage.pixelWidth,
            pixelHeight: embeddedImage.pixelHeight,
            byteCount: embeddedImage.data.count,
            updatedAtUnixTime: embeddedImage.updatedAtUnixTime
        )
    }

    static func imageData(for image: TeamLogoImage?) -> Data? {
        guard let image else {
            return nil
        }
        return imageData(forID: image.id)
    }

    static func imageData(forID id: String) -> Data? {
        guard isValidImageID(id), let url = try? fileURL(for: id) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    static func removeImage(id: String) {
        guard isValidImageID(id), let url = try? fileURL(for: id) else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    static func restoreImage(id: String, data: Data) throws {
        guard isRestorableImage(id: id, data: data) else {
            throw TeamLogoImageError.storageUnavailable
        }

        do {
            try ensureDirectoryExists()
            try data.write(to: try fileURL(for: id), options: [.atomic])
        } catch {
            throw TeamLogoImageError.storageUnavailable
        }
    }

    static func isRestorableImage(id: String, data: Data) -> Bool {
        isValidImageID(id) && !data.isEmpty
    }

    static func removeAllImages(except retainedIDs: Set<String> = []) {
        guard let directoryURL = try? directoryURL() else {
            return
        }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in urls {
            if retainedIDs.contains(url.deletingPathExtension().lastPathComponent) {
                continue
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func logoRequest(fromWebAPIPath path: String) -> (side: TeamSide, id: String)? {
        let prefix = "/api/v1/teams/"
        let marker = "/logo/"
        guard path.hasPrefix(prefix), path.hasSuffix(".png") else {
            return nil
        }

        let restStart = path.index(path.startIndex, offsetBy: prefix.count)
        let rest = String(path[restStart...])
        guard let markerRange = rest.range(of: marker) else {
            return nil
        }

        let sideRawValue = String(rest[..<markerRange.lowerBound])
        let idWithExtension = String(rest[markerRange.upperBound...])
        let id = String(idWithExtension.dropLast(4))
        guard let side = TeamSide(rawValue: sideRawValue), isValidImageID(id) else {
            return nil
        }
        return (side, id)
    }

    private static func directoryURL() throws -> URL {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw TeamLogoImageError.storageUnavailable
        }

        let bundleDirectory = Bundle.main.bundleIdentifier ?? "smartScoreboard"
        return applicationSupportURL
            .appendingPathComponent(bundleDirectory, isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func fileURL(for id: String) throws -> URL {
        guard isValidImageID(id) else {
            throw TeamLogoImageError.storageUnavailable
        }
        return try directoryURL().appendingPathComponent("\(id).png", isDirectory: false)
    }

    private static func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: directoryURL(),
            withIntermediateDirectories: true
        )
    }

    private static func isValidImageID(_ id: String) -> Bool {
        guard !id.isEmpty else {
            return false
        }
        return id.range(of: #"^[A-Za-z0-9-]+$"#, options: .regularExpression) != nil
    }

    private static func aspectFitRect(sourceSize: CGSize, in targetSize: CGSize) -> CGRect {
        let widthRatio = targetSize.width / max(sourceSize.width, 1)
        let heightRatio = targetSize.height / max(sourceSize.height, 1)
        let scale = min(widthRatio, heightRatio)
        let fittedSize = CGSize(
            width: max(1, sourceSize.width * scale),
            height: max(1, sourceSize.height * scale)
        )
        return CGRect(
            x: (targetSize.width - fittedSize.width) / 2,
            y: (targetSize.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    #if canImport(UIKit)
    private static func processImageData(_ data: Data) throws -> ProcessedImage {
        guard let sourceImage = UIImage(data: data) else {
            throw TeamLogoImageError.unreadableImage
        }

        let targetSize = CGSize(width: outputPixelSize, height: outputPixelSize)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let renderedImage = renderer.image { _ in
            sourceImage.draw(in: aspectFitRect(sourceSize: sourceImage.size, in: targetSize))
        }

        guard let pngData = renderedImage.pngData() else {
            throw TeamLogoImageError.compressionFailed
        }

        return ProcessedImage(
            data: pngData,
            mimeType: "image/png",
            pixelWidth: outputPixelSize,
            pixelHeight: outputPixelSize
        )
    }
    #elseif canImport(AppKit)
    private static func processImageData(_ data: Data) throws -> ProcessedImage {
        guard let sourceImage = NSImage(data: data) else {
            throw TeamLogoImageError.unreadableImage
        }

        let targetSize = CGSize(width: outputPixelSize, height: outputPixelSize)
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: outputPixelSize,
                pixelsHigh: outputPixelSize,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bitmapFormat: [],
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else {
            throw TeamLogoImageError.compressionFailed
        }

        bitmap.size = targetSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(origin: .zero, size: targetSize))
        context.imageInterpolation = .high
        sourceImage.draw(
            in: aspectFitRect(sourceSize: sourceImage.size, in: targetSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw TeamLogoImageError.compressionFailed
        }

        return ProcessedImage(
            data: pngData,
            mimeType: "image/png",
            pixelWidth: outputPixelSize,
            pixelHeight: outputPixelSize
        )
    }
    #else
    private static func processImageData(_ data: Data) throws -> ProcessedImage {
        _ = data
        throw TeamLogoImageError.unreadableImage
    }
    #endif
}

struct TeamLogoImageView: View {
    let data: Data?
    var cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            if let platformImage = makePlatformImage() {
                platformImage
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private func makePlatformImage() -> Image? {
        guard let data else {
            return nil
        }

        #if canImport(UIKit)
        guard let image = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else {
            return nil
        }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }
}
