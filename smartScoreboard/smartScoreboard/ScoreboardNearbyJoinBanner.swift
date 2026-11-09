import SwiftUI

/// Uses the Companion notice treatment without blocking the control board.
struct ScoreboardNearbyJoinBanner: View {
    @EnvironmentObject private var store: ScoreboardStore
    @ObservedObject private var nearby = ScoreboardNearbyMatchService.shared
    let request: ScoreboardNearbyMatchService.Approval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = request.remainingSeconds(at: context.date)
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.title3.weight(.bold)).foregroundStyle(tint)
                        .frame(width: 46, height: 46).background(foreground.opacity(0.94), in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Nearby Join Request").font(.title3.bold())
                        Text("\(request.name) wants to join \(store.currentMatchTitle).")
                            .font(.callout.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    ZStack {
                        Circle().stroke(foreground.opacity(0.25), lineWidth: 3)
                        Circle().trim(from: 0, to: min(1, Double(seconds) / 60))
                            .stroke(foreground, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                        Text(seconds, format: .number).font(.caption.bold()).monospacedDigit()
                    }.frame(width: 42, height: 42)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Time remaining")
                        .accessibilityValue("\(seconds) seconds")
                        .accessibilityIdentifier("nearby.approvalCountdown")
                }
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    Button("Decline") { nearby.decline(request) }
                        .accessibilityIdentifier("nearby.decline")
                    Button(request.requestsControl ? "Allow as Controller" : "Allow as Display") { nearby.approve(request) }
                        .accessibilityIdentifier("nearby.allow").disabled(seconds == 0)
                }
                .buttonStyle(NearbyApprovalButtonStyle(tint: tint, background: foreground))
            }
            .foregroundStyle(foreground).padding(18).frame(maxWidth: 720, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(foreground.opacity(0.35), lineWidth: 1.5) }
            .shadow(color: tint.opacity(0.35), radius: 24, y: 10)
            .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
            .accessibilityIdentifier("nearby.approvalBanner")
        }
    }
    private var tint: Color { store.theme.palette.settingsAccent }
    private var foreground: Color { store.theme.palette.settingsAccentText }
}

private struct NearbyApprovalButtonStyle: ButtonStyle {
    var tint: Color
    var background: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.bold()).foregroundStyle(tint)
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(background.opacity(configuration.isPressed ? 0.76 : 0.96), in: Capsule())
    }
}

private struct NearbyJoinNotificationModifier: ViewModifier {
    @ObservedObject private var nearby = ScoreboardNearbyMatchService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let request = nearby.approvals.first {
                ScoreboardNearbyJoinBanner(request: request).padding(20).frame(maxWidth: .infinity)
                    .transition(.move(edge: .top).combined(with: .opacity)).zIndex(100)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.84), value: nearby.approvals.first?.expiresAt)
    }
}

extension View {
    func scoreboardNearbyJoinNotifications() -> some View { modifier(NearbyJoinNotificationModifier()) }
}
