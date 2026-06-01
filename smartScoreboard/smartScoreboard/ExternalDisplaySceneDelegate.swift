import SwiftUI

#if canImport(UIKit) && !os(macOS)
import UIKit

@MainActor
final class ExternalDisplaySceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let hostingController = UIHostingController(
            rootView: ExternalScoreboardView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environmentObject(ScoreboardStore.shared)
                .environmentObject(PublicBoardState.shared)
        )
        hostingController.view.backgroundColor = .black
        hostingController.view.frame = sceneBounds(for: windowScene)
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let window = UIWindow(windowScene: windowScene)
        window.frame = sceneBounds(for: windowScene)
        window.rootViewController = hostingController
        window.backgroundColor = .black
        window.isHidden = false
        self.window = window

        PublicBoardState.shared.isPresented = true
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        updateWindowFrame(for: windowScene)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        didUpdate previousCoordinateSpace: UICoordinateSpace,
        interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
        traitCollection previousTraitCollection: UITraitCollection
    ) {
        updateWindowFrame(for: windowScene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        PublicBoardState.shared.isPresented = false
        window = nil
    }

    private func updateWindowFrame(for windowScene: UIWindowScene) {
        let bounds = sceneBounds(for: windowScene)
        window?.frame = bounds
        window?.rootViewController?.view.frame = bounds
    }

    private func sceneBounds(for windowScene: UIWindowScene) -> CGRect {
        if #available(iOS 26.0, *) {
            return windowScene.effectiveGeometry.coordinateSpace.bounds
        } else {
            return windowScene.coordinateSpace.bounds
        }
    }
}
#endif
