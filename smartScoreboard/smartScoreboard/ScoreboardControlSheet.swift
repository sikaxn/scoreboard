import SwiftUI

#if !os(tvOS)
/// Shared presentation for live-board selectors. Header and actions stay visible
/// while the options scroll, on both Mac and the operator's smaller devices.
struct ScoreboardControlSheet<Content: View, Footer: View>: View {
    let title: String
    let subtitle: String
    let palette: ThemePalette
    let accessibilityID: String
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(verbatim: subtitle)
                    .font(.subheadline)
                    .foregroundStyle(palette.dashboardMutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(accessibilityID).header")

            Rectangle().fill(palette.dashboardCardBorder).frame(height: 1)

            ScrollView {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .frame(maxHeight: .infinity)
            .accessibilityIdentifier("\(accessibilityID).content")

            Rectangle().fill(palette.dashboardCardBorder).frame(height: 1)
            footer().font(.subheadline).padding(16)
        }
        .font(.body)
        .foregroundStyle(palette.dashboardPrimaryText)
        .background(LinearGradient(colors: palette.appDashboardBackground, startPoint: .topLeading, endPoint: .bottomTrailing))
        #if os(macOS)
        .frame(width: 520, height: 640)
        #else
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityID)
    }
}

struct ScoreboardControlSheetCard<Content: View>: View {
    let palette: ThemePalette
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0, content: content)
            .background(palette.dashboardCardBackground, in: RoundedRectangle(cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(palette.dashboardCardBorder))
    }
}
#endif
