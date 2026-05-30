import SwiftUI

#if os(macOS)
import AppKit
#endif

struct MacControlBoardWindowView: View {
    var body: some View {
        ContentView()
            .onDisappear {
                #if os(macOS)
                NSApplication.shared.terminate(nil)
                #endif
            }
    }
}
