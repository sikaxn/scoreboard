import SwiftUI

struct MacScoreboardWindowView: View {
    @EnvironmentObject private var externalDisplayState: ExternalDisplayState

    var body: some View {
        ExternalScoreboardView()
            .onAppear {
                externalDisplayState.isConnected = true
            }
            .onDisappear {
                externalDisplayState.isConnected = false
            }
    }
}
