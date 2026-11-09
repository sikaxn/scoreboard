import SwiftUI

/// Vector display fonts stay sharp on projectors and in the layout picker.
struct ScoreboardDisplayNumber: View {
    let value: String
    let font: ExternalDisplayFont
    let fontSize: CGFloat
    let color: Color
    var minScale: CGFloat = 0.24
    var weight: Font.Weight = .black

    var body: some View {
        if font == .eightSegment, ScoreboardEightSegmentNumber.supports(value) {
            ScoreboardEightSegmentNumber(value: value, fontSize: fontSize, color: color, minScale: minScale)
        } else if font == .dotMatrix, value.allSatisfy({ Self.glyphs[$0] != nil }) {
            Canvas { context, size in
                let glyphs = value.compactMap { Self.glyphs[$0] }
                let columns = glyphs.reduce(0) { $0 + $1[0].count + 1 } - 1
                guard columns > 0 else { return }
                let pitch = min(size.width / CGFloat(columns), size.height / 7)
                let origin = CGPoint(x: (size.width - CGFloat(columns) * pitch) / 2,
                                     y: (size.height - 7 * pitch) / 2)
                var lit = Path()
                var unlit = Path()
                var offset = 0
                for glyph in glyphs {
                    for (row, pixels) in glyph.enumerated() {
                        for (column, pixel) in pixels.enumerated() {
                            let dot = CGRect(x: origin.x + CGFloat(offset + column) * pitch + pitch * 0.13,
                                             y: origin.y + CGFloat(row) * pitch + pitch * 0.13,
                                             width: pitch * 0.74, height: pitch * 0.74)
                            if pixel == "1" { lit.addEllipse(in: dot) }
                            else { unlit.addEllipse(in: dot) }
                        }
                    }
                    offset += glyph[0].count + 1
                }
                context.fill(unlit, with: .color(color.opacity(0.055)))
                context.addFilter(.shadow(color: color.opacity(0.35), radius: pitch * 0.4))
                context.fill(lit, with: .color(color))
            }
            .frame(minHeight: fontSize * max(0.55, minScale), idealHeight: fontSize * 1.08, maxHeight: fontSize * 1.08)
            .accessibilityRepresentation { Text(value) }
        } else {
            Text(value)
                .font(.system(size: fontSize, weight: weight, design: font == .rounded ? .rounded : .default))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(minScale)
                .allowsTightening(true)
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
    }

    private static let glyphs: [Character: [String]] = [
        "0": ["01110", "11011", "11011", "11011", "11011", "11011", "01110"],
        "1": ["00110", "01110", "00110", "00110", "00110", "00110", "01111"],
        "2": ["01110", "11011", "00011", "00110", "01100", "11000", "11111"],
        "3": ["11110", "00011", "00011", "01110", "00011", "00011", "11110"],
        "4": ["11011", "11011", "11011", "11111", "00011", "00011", "00011"],
        "5": ["11111", "11000", "11000", "11110", "00011", "11011", "01110"],
        "6": ["01110", "11000", "11000", "11110", "11011", "11011", "01110"],
        "7": ["11111", "00011", "00011", "00110", "01100", "01100", "01100"],
        "8": ["01110", "11011", "11011", "01110", "11011", "11011", "01110"],
        "9": ["01110", "11011", "11011", "01111", "00011", "00011", "01110"],
        ":": ["00", "11", "11", "00", "11", "11", "00"],
        ".": ["00", "00", "00", "00", "00", "11", "11"],
        "-": ["000", "000", "000", "111", "000", "000", "000"],
        "+": ["000", "010", "010", "111", "010", "010", "000"],
        " ": ["000", "000", "000", "000", "000", "000", "000"]
    ]
}

/// Uses the same surface treatment for team panels, the clock, and layout previews.
struct ScoreboardDisplayPanel: View {
    let layout: ExternalDisplayLayout
    let fill: Color
    let border: Color
    var accent: Color? = nil
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape.fill(fill)
            .overlay {
                if layout == .broadcast, let accent {
                    LinearGradient(colors: [accent.opacity(0.18), .clear], startPoint: .top, endPoint: .center)
                        .clipShape(shape)
                    Rectangle().fill(accent)
                        .frame(height: 5)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .clipShape(shape)
                }
            }
            .overlay {
                shape.strokeBorder(border, lineWidth: layout == .arena ? 2 : 1)
            }
    }
}

struct ScoreboardDisplayLayoutPreview: View {
    let layout: ExternalDisplayLayout
    let font: ExternalDisplayFont
    let palette: ThemePalette

    var body: some View {
        Group {
            if layout == .venueRoster {
                HStack(spacing: 4) {
                    rosterLines(accent: palette.homeAccent)
                    VStack(spacing: 4) {
                        HStack {
                            previewPanel("HOME", value: "24", accent: palette.homeAccent)
                            previewPanel("GUEST", value: "18", accent: palette.guestAccent)
                        }
                        ScoreboardDisplayNumber(value: "8:00", font: font, fontSize: 15, color: palette.boardPrimaryText)
                    }
                    rosterLines(accent: palette.guestAccent)
                }
            } else if layout == .arena {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        previewPanel("HOME", value: "24", accent: palette.homeAccent)
                        ScoreboardDisplayNumber(value: "2", font: font, fontSize: 13, color: palette.dashboardWarningButton)
                            .frame(width: 12)
                        previewPanel("GUEST", value: "18", accent: palette.guestAccent)
                    }
                    ScoreboardDisplayNumber(value: "8:00", font: font, fontSize: 19, color: palette.boardPrimaryText)
                        .padding(3)
                        .background(palette.externalDisplayBackground.opacity(0.92), in: RoundedRectangle(cornerRadius: 3))
                }
            } else {
                HStack(spacing: 4) {
                    previewPanel("HOME", value: "24", accent: palette.homeAccent)
                    previewPanel("CLOCK", value: "8:00", accent: palette.boardPrimaryText)
                    previewPanel("GUEST", value: "18", accent: palette.guestAccent)
                }
            }
        }
        .padding(7)
        .accessibilityHidden(true)
    }

    private func rosterLines(accent: Color) -> some View {
        VStack(spacing: 5) {
            ForEach(0..<7) { _ in
                HStack(spacing: 2) {
                    Circle().fill(accent).frame(width: 3, height: 3)
                    Rectangle().fill(palette.boardPrimaryText.opacity(0.6)).frame(width: 15, height: 2)
                }
            }
        }
        .padding(3)
        .background(palette.externalDisplayBackground.opacity(0.92))
    }

    private func previewPanel(_ title: String, value: String, accent: Color) -> some View {
        VStack(spacing: 5) {
            Text(ScoreboardLocalization.string(title)).font(.system(size: 5, weight: .heavy)).lineLimit(1)
                .foregroundStyle(palette.boardPrimaryText)
            ScoreboardDisplayNumber(value: value, font: font, fontSize: 17,
                                   color: layout == .broadcast ? palette.boardPrimaryText : accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(3)
        .background {
            ScoreboardDisplayPanel(layout: layout, fill: palette.externalDisplayBackground.opacity(0.92),
                                   border: layout == .arena ? palette.boardPrimaryText.opacity(0.7) : palette.boardPanelBorder,
                                   accent: accent, cornerRadius: layout == .standard ? 7 : 3)
        }
    }
}
