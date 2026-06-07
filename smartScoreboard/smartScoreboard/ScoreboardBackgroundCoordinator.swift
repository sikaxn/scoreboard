#if os(iOS)
import BackgroundTasks
import Foundation
import UIKit

@MainActor
final class ScoreboardBackgroundCoordinator {
    static let shared = ScoreboardBackgroundCoordinator()

    static let maintenanceTaskIdentifier = "IronMaple.smartScoreboard.timer-maintenance"

    private var isRegistered = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    func register() {
        guard !isRegistered else {
            return
        }

        isRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.maintenanceTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                self.handle(task)
            }
        }
    }

    func handleAppDidBecomeActive(store: ScoreboardStore) {
        endBackgroundRuntime()
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.maintenanceTaskIdentifier)
        store.resumeFromBackgroundRuntime()
    }

    func handleAppDidEnterBackground(store: ScoreboardStore) {
        store.prepareForBackgroundRuntime()
        scheduleMaintenanceIfNeeded(store: store)

        guard store.isGameRunning else {
            store.suspendWebAPIForAppLifecycle()
            endBackgroundRuntime()
            return
        }

        beginBackgroundRuntime(store: store)
    }

    private func handle(_ task: BGTask) {
        scheduleMaintenanceIfNeeded(store: .shared)

        task.expirationHandler = {
            Task { @MainActor in
                ScoreboardStore.shared.expireBackgroundWebAPIGrace()
                task.setTaskCompleted(success: false)
            }
        }

        ScoreboardStore.shared.performBackgroundTimerMaintenance()
        task.expirationHandler = nil
        task.setTaskCompleted(success: true)
    }

    private func scheduleMaintenanceIfNeeded(store: ScoreboardStore) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.maintenanceTaskIdentifier)
        guard store.isGameRunning else {
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: Self.maintenanceTaskIdentifier)
        request.earliestBeginDate = store.nextPrimaryTimerMaintenanceDate ?? Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func beginBackgroundRuntime(store: ScoreboardStore) {
        guard backgroundTaskID == .invalid else {
            return
        }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Scoreboard Game Runtime") { [weak self] in
            Task { @MainActor in
                guard let self else {
                    return
                }
                store.expireBackgroundWebAPIGrace()
                self.endBackgroundRuntime()
            }
        }
    }

    private func endBackgroundRuntime() {
        guard backgroundTaskID != .invalid else {
            return
        }

        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}
#endif
