import SwiftUI

/// Defers construction until SwiftUI evaluates this child view's body.
/// Calling a view helper (or wrapping its result in AnyView) still constructs
/// the child on the parent's stack. Deep settings builders exhausted the
/// device's main-thread stack, so keep large sections behind a body boundary.
struct ScoreboardViewBoundary: View {
    private let content: () -> AnyView

    init<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        // Erase the child type without eagerly evaluating its builder. The
        // boundary's type must not expand into ContentView's opaque root chain.
        self.content = { AnyView(content()) }
    }

    var body: AnyView {
        content()
    }
}
