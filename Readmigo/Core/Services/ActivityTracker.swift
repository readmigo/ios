import Foundation
import UIKit

/// Service for tracking user activity and updating lastActiveAt
@MainActor
class ActivityTracker: ObservableObject {
    static let shared = ActivityTracker()

    @Published private(set) var lastUpdateTime: Date?
    @Published private(set) var isUpdating = false

    /// Minimum interval between updates (5 minutes)
    private let minimumUpdateInterval: TimeInterval = 5 * 60

    private init() {}

    /// Update user activity
    /// Uses local debouncing to prevent excessive API calls
    func updateActivity() {
        // Check if we recently updated
        if let lastUpdate = lastUpdateTime {
            let elapsed = Date().timeIntervalSince(lastUpdate)
            if elapsed < minimumUpdateInterval {
                // Too soon, skip update
                return
            }
        }

        // Prevent concurrent updates
        guard !isUpdating else { return }

        Task {
            await performUpdate()
        }
    }

    /// Force update activity (bypasses local debouncing)
    func forceUpdate() {
        Task {
            await performUpdate()
        }
    }

    private func performUpdate() async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            try await APIClient.shared.updateActivity()
            lastUpdateTime = Date()
        } catch {
            // Log error but don't throw - activity updates should be silent
            print("❌ Failed to update activity: \(error.localizedDescription)")
        }
    }

    /// Start observing app lifecycle events
    func startObserving() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateActivity()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateActivity()
        }
    }

    /// Stop observing app lifecycle events
    func stopObserving() {
        NotificationCenter.default.removeObserver(self)
    }
}
