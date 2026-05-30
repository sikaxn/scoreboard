import SwiftUI

@main
struct SmartScoreboardApp: App {
    @StateObject private var store = ScoreboardStore.shared
    @StateObject private var externalDisplayState = ExternalDisplayState.shared

    var body: some Scene {
        #if os(macOS)
        Window("Control Board", id: "control-board") {
            ContentView()
                .environmentObject(store)
                .environmentObject(externalDisplayState)
        }
        .defaultSize(width: 1480, height: 920)

        Window("Public Scoreboard", id: "public-scoreboard") {
            MacScoreboardWindowView()
                .environmentObject(store)
                .environmentObject(externalDisplayState)
        }
        .defaultSize(width: 1380, height: 820)
        #else
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(externalDisplayState)
        }
        #endif
    }
}
