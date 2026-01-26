import UIKit
import UserNotifications

/// AppDelegate for handling background URL session events and push notifications.
/// SwiftUI apps need an AppDelegate to receive background session callbacks.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Called when a background URL session completes while the app is not running.
    /// This method is required for background downloads to work properly.
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        LoggingService.shared.info("[AppDelegate] Handling background session: \(identifier)")

        BackgroundDownloadService.shared.handleBackgroundSessionEvents(
            identifier: identifier,
            completionHandler: completionHandler
        )
    }

    /// Called when the app finishes launching
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Restore any pending downloads
        BackgroundDownloadService.shared.restoreDownloadsOnLaunch()

        // Set up push notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Request push notification permissions
        PushNotificationService.shared.requestPermission()

        return true
    }

    // MARK: - Push Notification Registration

    /// Called when device token is successfully registered
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        LoggingService.shared.info("[AppDelegate] APNs token received: \(token.prefix(16))...")
        PushNotificationService.shared.handleDeviceToken(token)
    }

    /// Called when push notification registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        LoggingService.shared.error("[AppDelegate] Failed to register for push notifications: \(error.localizedDescription)")
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        PushNotificationService.shared.handleNotificationTap(userInfo: userInfo)
        completionHandler()
    }
}
