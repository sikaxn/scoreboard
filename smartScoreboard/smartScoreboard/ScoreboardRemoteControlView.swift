#if !os(tvOS)
import SwiftUI

// The standard app board operates on a mirror whose mutations go to the main device.
// Local/merged display navigation stays in ContentView; no second control UI exists.
struct ScoreboardRemoteControlView: View {
    @ObservedObject var receiver: ScoreboardRemoteDisplayReceiver
    var showConnection: () -> Void
    @StateObject private var board: ScoreboardStore

    init(receiver: ScoreboardRemoteDisplayReceiver, showConnection: @escaping () -> Void) {
        self.receiver = receiver
        self.showConnection = showConnection
        _board = StateObject(wrappedValue: ScoreboardStore.makeRemoteControlStore(receiver: receiver))
    }

    var body: some View {
        ContentView(remoteControlBoard: true, remoteReceiver: receiver, returnToRemoteControl: showConnection)
            .environmentObject(board)
            .environmentObject(PublicBoardState.shared)
    }
}
#endif
