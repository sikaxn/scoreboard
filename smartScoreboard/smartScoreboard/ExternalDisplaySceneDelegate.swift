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
        hostingController.view.frame = windowScene.coordinateSpace.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.coordinateSpace.bounds
        window.rootViewController = hostingController
        window.backgroundColor = .black
        window.isHidden = false
        self.window = window

        PublicBoardState.shared.isPresented = true
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        updateWindowFrame(for: scene)
    }

    func scene(
        _ scene: UIScene,
        didUpdate previousCoordinateSpace: UICoordinateSpace,
        interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
        traitCollection previousTraitCollection: UITraitCollection
    ) {
        updateWindowFrame(for: scene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        PublicBoardState.shared.isPresented = false
        window = nil
    }

    private func updateWindowFrame(for scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let bounds = windowScene.coordinateSpace.bounds
        window?.frame = bounds
        window?.rootViewController?.view.frame = bounds
    }
}
#endif
