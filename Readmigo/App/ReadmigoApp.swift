import SwiftUI
import Kingfisher
import GoogleSignIn

@main
struct ReadmigoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var authManager = AuthManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var libraryManager = LibraryManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var browsingHistoryManager = BrowsingHistoryManager.shared
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var readingProgressStore = ReadingProgressStore.shared
    @StateObject private var crashTracking = CrashTrackingService.shared
    @StateObject private var versionManager = VersionManager.shared
    @StateObject private var pushNotificationService = PushNotificationService.shared
    @StateObject private var activityTracker = ActivityTracker.shared

    init() {
        // Initialize crash tracking first
        initializeCrashTracking()

        // Configure image cache
        configureImageCache()

        // Configure app appearance
        configureAppearance()

        // Log app launch
        LoggingService.shared.appLaunch()
    }

    private func configureImageCache() {
        // Configure Kingfisher cache per design document
        let cache = ImageCache.default

        // Memory cache: 50MB
        cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024

        // Disk cache: 200MB (user selected)
        cache.diskStorage.config.sizeLimit = 200 * 1024 * 1024

        // Expiration: 7 days
        cache.diskStorage.config.expiration = .days(7)

        // Clean expired cache on app launch
        cache.cleanExpiredDiskCache()

        LoggingService.shared.info("Image cache configured: 50MB memory, 200MB disk, 7-day TTL")
    }

    private func initializeCrashTracking() {
        // Initialize Sentry for crash tracking
        CrashTrackingService.shared.initializeSentry(
            dsn: "https://5b042f3331ba0d804bec5185f45d2d22@o4510539308400640.ingest.us.sentry.io/4510565261246464"
        )

        // Set app context
        CrashTrackingService.shared.setContext(key: "app", value: [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        ])
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if versionManager.forceUpdateRequired {
                    ForceUpdateView()
                } else {
                    ContentView()
                        .environmentObject(authManager)
                        .environmentObject(themeManager)
                        .environmentObject(libraryManager)
                        .environmentObject(localizationManager)
                        .environmentObject(browsingHistoryManager)
                        .environmentObject(favoritesManager)
                        .environmentObject(readingProgressStore)
                        .environmentObject(pushNotificationService)
                        .onOpenURL { url in
                            GIDSignIn.sharedInstance.handle(url)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .pushNotificationTapped)) { notification in
                            // Handle push notification tap - navigation will be handled by views observing pushNotificationService
                            LoggingService.shared.info("[App] Push notification tapped, feedbackId: \(notification.userInfo?["feedbackId"] ?? "nil")")
                        }
                }
            }
            .preferredColorScheme(themeManager.colorScheme)
            .task {
                await versionManager.checkVersion()
                // Start observing app lifecycle for activity tracking
                activityTracker.startObserving()
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification
            )) { _ in
                activityTracker.updateActivity()
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.didBecomeActiveNotification
            )) { _ in
                activityTracker.updateActivity()
            }
        }
    }

    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Activity Tracker

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
