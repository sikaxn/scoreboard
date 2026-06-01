import SwiftUI

@main
struct SmartScoreboardApp: App {
    @StateObject private var store = ScoreboardStore.shared
    @StateObject private var publicBoardState = PublicBoardState.shared

    var body: some Scene {
        #if os(macOS)
        Window("Control Board", id: "control-board") {
            ContentView()
                .environmentObject(store)
                .environmentObject(publicBoardState)
        }
        .defaultSize(width: 1280, height: 820)

        Window("Public Scoreboard", id: "public-scoreboard") {
            ExternalScoreboardView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environmentObject(store)
                .environmentObject(publicBoardState)
                .onAppear {
                    publicBoardState.isPresented = true
                }
                .onDisappear {
                    publicBoardState.isPresented = false
                }
        }
        .defaultSize(width: 960, height: 540)
        .windowStyle(.hiddenTitleBar)
        #else
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(publicBoardState)
        }
        #endif
    }
}
