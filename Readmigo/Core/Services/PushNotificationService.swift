import Foundation
import UIKit
import UserNotifications

/// Notification for push notification tap events
extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
}

/// Service for handling push notifications
@MainActor
class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()

    @Published var isPermissionGranted = false
    @Published var pendingFeedbackId: String?

    private var deviceToken: String?
    private let tokenKey = "push_notification_token"

    private init() {
        // Load saved token
        deviceToken = UserDefaults.standard.string(forKey: tokenKey)
    }

    // MARK: - Permission

    /// Request push notification permission
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isPermissionGranted = granted

                if granted {
                    LoggingService.shared.info("[Push] Permission granted, registering for remote notifications")
                    UIApplication.shared.registerForRemoteNotifications()
                } else if let error = error {
                    LoggingService.shared.error("[Push] Permission error: \(error.localizedDescription)")
                } else {
                    LoggingService.shared.info("[Push] Permission denied by user")
                }
            }
        }
    }

    // MARK: - Token Handling

    /// Handle device token from APNs
    func handleDeviceToken(_ token: String) {
        deviceToken = token
        UserDefaults.standard.set(token, forKey: tokenKey)

        // Upload token to server
        Task {
            await uploadTokenToServer(token)
        }
    }

    /// Upload token to backend
    private func uploadTokenToServer(_ token: String) async {
        guard let deviceId = await UIDevice.current.identifierForVendor?.uuidString else {
            LoggingService.shared.error("[Push] Cannot get device ID for token upload")
            return
        }

        do {
            try await MessagingService.shared.registerPushToken(token, deviceId: deviceId)
            LoggingService.shared.info("[Push] Token uploaded successfully")
        } catch {
            LoggingService.shared.error("[Push] Failed to upload token: \(error.localizedDescription)")
        }
    }

    // MARK: - Notification Handling

    /// Handle notification tap
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        LoggingService.shared.info("[Push] Notification tapped: \(userInfo)")

        // Check for guest feedback reply
        if let type = userInfo["type"] as? String, type == "guest_feedback_reply",
           let feedbackId = userInfo["feedbackId"] as? String {
            pendingFeedbackId = feedbackId

            // Post notification for navigation
            NotificationCenter.default.post(
                name: .pushNotificationTapped,
                object: nil,
                userInfo: ["feedbackId": feedbackId]
            )
        }
    }

    /// Clear pending navigation
    func clearPendingNavigation() {
        pendingFeedbackId = nil
    }
}
