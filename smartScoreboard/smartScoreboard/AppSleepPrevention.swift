import Foundation
import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit
#endif

#if os(macOS)
import AppKit
import IOKit.pwr_mgt
#endif

enum AppSleepPreventionReason: Hashable {
    case externalDisplayConnected
    case publicBoardPresented
    case timerRunning
    case localScoreboardVisible
    case operatorRemoteDisplayConnected
    case receiverRemoteDisplayConnected(UUID)
    case remoteScoreboardVisible(UUID)
}

@MainActor
enum AppSleepPrevention {
    private static var activeReasons = Set<AppSleepPreventionReason>()
    private static var isSceneActive = true

    static func setSceneActive(_ isActive: Bool) {
        isSceneActive = isActive
        applyPolicy()
    }

    static func setReason(_ reason: AppSleepPreventionReason, active: Bool) {
        if active {
            activeReasons.insert(reason)
        } else {
            activeReasons.remove(reason)
        }
        applyPolicy()
    }

    private static func applyPolicy() {
        let shouldPreventSleep = !activeReasons.isEmpty
        #if os(iOS) || os(tvOS)
        UIApplication.shared.isIdleTimerDisabled = shouldPreventSleep && isSceneActive
        #endif

        #if os(macOS)
        MacSleepPreventionAssertion.shared.setActive(shouldPreventSleep)
        #endif
    }

}

struct AppSleepSceneActivityReporter: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear {
                AppSleepPrevention.setSceneActive(scenePhase == .active)
            }
            .onChange(of: scenePhase) { _, newPhase in
                AppSleepPrevention.setSceneActive(newPhase == .active)
            }
    }
}

struct ExternalDisplaySleepPolicyReporter: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear(perform: updateExternalDisplayReason)
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIScene.willConnectNotification)) { _ in
                updateExternalDisplayReason()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)) { _ in
                updateExternalDisplayReason()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScene.didActivateNotification)) { _ in
                updateExternalDisplayReason()
            }
            #elseif os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
                updateExternalDisplayReason()
            }
            #endif
    }

    private func updateExternalDisplayReason() {
        AppSleepPrevention.setReason(.externalDisplayConnected, active: Self.hasExternalDisplay)
    }

    private static var hasExternalDisplay: Bool {
        #if os(iOS)
        return UIApplication.shared.openSessions.contains {
            $0.role == .windowExternalDisplayNonInteractive
        }
        #elseif os(macOS)
        return NSScreen.screens.count > 1
        #else
        return false
        #endif
    }
}

#if !os(tvOS)
struct ScoreboardSleepPolicyReporter: ViewModifier {
    @ObservedObject var store: ScoreboardStore
    @ObservedObject var publicBoardState: PublicBoardState

    func body(content: Content) -> some View {
        content
            .onAppear(perform: updateScoreboardReasons)
            .onChange(of: store.isAnyTimerRunning) { _, _ in
                updateScoreboardReasons()
            }
            .onChange(of: store.remoteDisplayConnectedDisplays.isEmpty) { _, _ in
                updateScoreboardReasons()
            }
            .onChange(of: publicBoardState.isPresented) { _, _ in
                updateScoreboardReasons()
            }
    }

    private func updateScoreboardReasons() {
        AppSleepPrevention.setReason(.timerRunning, active: store.isAnyTimerRunning)
        AppSleepPrevention.setReason(.operatorRemoteDisplayConnected, active: !store.remoteDisplayConnectedDisplays.isEmpty)
        AppSleepPrevention.setReason(.publicBoardPresented, active: publicBoardState.isPresented)
    }
}
#endif

extension View {
    func reportsSceneActivityForSleepPolicy() -> some View {
        modifier(AppSleepSceneActivityReporter())
    }

    func reportsExternalDisplaysForSleepPolicy() -> some View {
        modifier(ExternalDisplaySleepPolicyReporter())
    }

    #if !os(tvOS)
    func reportsScoreboardSleepPolicy(
        store: ScoreboardStore,
        publicBoardState: PublicBoardState
    ) -> some View {
        modifier(ScoreboardSleepPolicyReporter(store: store, publicBoardState: publicBoardState))
    }
    #endif
}

#if os(macOS)
private final class MacSleepPreventionAssertion {
    static let shared = MacSleepPreventionAssertion()

    private var assertionIDs: [IOPMAssertionID] = []

    private init() {}

    func setActive(_ isActive: Bool) {
        if isActive {
            acquire()
        } else {
            release()
        }
    }

    private func acquire() {
        guard assertionIDs.isEmpty else { return }
        createAssertion(kIOPMAssertionTypeNoDisplaySleep as CFString)
        createAssertion(kIOPMAssertionTypeNoIdleSleep as CFString)
    }

    private func createAssertion(_ type: CFString) {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Smart Scoreboard is running" as CFString,
            &assertionID
        )

        if result == kIOReturnSuccess {
            assertionIDs.append(assertionID)
        }
    }

    private func release() {
        assertionIDs.forEach { IOPMAssertionRelease($0) }
        assertionIDs.removeAll()
    }

    deinit {
        release()
    }
}
#endif
