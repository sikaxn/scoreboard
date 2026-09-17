import SwiftUI

/// Defers construction until SwiftUI evaluates this child view's body.
/// Calling a view helper (or wrapping its result in AnyView) still constructs
/// the child on the parent's stack. Deep settings builders exhausted the
/// device's main-thread stack, so keep large sections behind a body boundary.
struct ScoreboardViewBoundary<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
    }
}
