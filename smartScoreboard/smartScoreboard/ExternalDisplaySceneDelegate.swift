import Foundation
import SwiftUI

#if canImport(UIKit)
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
                .environmentObject(ScoreboardStore.shared)
                .environmentObject(ExternalDisplayState.shared)
        )

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = hostingController
        window.isHidden = false
        self.window = window

        ExternalDisplayState.shared.isConnected = true
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        ExternalDisplayState.shared.isConnected = false
        window = nil
    }
}
#else
@MainActor
final class ExternalDisplaySceneDelegate: NSObject {}
#endif
