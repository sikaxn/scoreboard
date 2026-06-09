import SwiftUI

#if os(iOS)
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
            rootView: ExternalDisplayRootView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environmentObject(ScoreboardStore.shared)
                .environmentObject(PublicBoardState.shared)
        )
        hostingController.view.backgroundColor = .black
        hostingController.view.frame = displayBounds(for: windowScene)
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let window = UIWindow(windowScene: windowScene)
        window.frame = displayBounds(for: windowScene)
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
        let bounds = displayBounds(for: windowScene)
        window?.frame = bounds
        window?.rootViewController?.view.frame = bounds
    }

    private func displayBounds(for windowScene: UIWindowScene) -> CGRect {
        windowScene.screen.bounds
    }
}

private struct ExternalDisplayRootView: View {
    @EnvironmentObject private var store: ScoreboardStore
    @EnvironmentObject private var publicBoardState: PublicBoardState

    var body: some View {
        if store.isRemoteDisplayViewerModeEnabled {
            RemoteScoreboardView(
                networkMode: store.remoteDisplayNetworkMode,
                setNetworkMode: {
                    store.setRemoteDisplayNetworkMode($0)
                },
                showsPairingControls: false,
                usesExternalDisplayDirection: true
            )
        } else {
            ExternalScoreboardView()
                .environmentObject(store)
                .environmentObject(publicBoardState)
        }
    }
}
#endif
